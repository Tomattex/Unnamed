shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Glifo del marcador de clic (scripts/player/click_marker.gd): un circulo
// magico con una banda de runas que gira, una estrella de seis puntas
// adentro (dos triangulos que giran al reves), una onda que se cierra al
// clickear, cuatro flechas que llegan desde afuera y un punto que late. Todo
// se dibuja aca, sobre un plano en el piso; un halo oscuro debajo lo separa
// del pasto o de la arena clara.

uniform vec4 tint : source_color = vec4(0.42, 1.0, 0.58, 1.0);
// Segundos desde el clic (la entrada dura ENTRY).
uniform float age = 10.0;
// Transparencia general (la llegada lo apaga de a poco).
uniform float fade = 1.0;

const float ENTRY = 0.35;
// Banda de runas (radios en el plano, de -1 a 1).
const float BAND_IN = 0.5;
const float BAND_OUT = 0.64;
const float RUNES = 16.0;

float ring(float r, float radius, float width) {
	return smoothstep(width, 0.0, abs(r - radius));
}

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

// Distancia de p al segmento ab.
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Una runa inventada: un palo y dos o tres trazos que salen de el, segun la
// celda. c va de 0 a 1 en cada eje (x a lo largo del anillo, y hacia afuera).
float rune(vec2 c, float seed) {
	float h = hash(seed);
	float d = segment(c, vec2(0.5, 0.12), vec2(0.5, 0.88));
	if (fract(h * 2.0) > 0.5) d = min(d, segment(c, vec2(0.5, 0.88), vec2(0.8, 0.6)));
	if (fract(h * 4.0) > 0.5) d = min(d, segment(c, vec2(0.5, 0.5), vec2(0.2, 0.28)));
	if (fract(h * 8.0) > 0.5) d = min(d, segment(c, vec2(0.5, 0.62), vec2(0.8, 0.36)));
	if (fract(h * 16.0) > 0.5) d = min(d, segment(c, vec2(0.2, 0.88), vec2(0.5, 0.6)));
	if (fract(h * 32.0) > 0.6) d = min(d, segment(c, vec2(0.2, 0.12), vec2(0.8, 0.12)));
	return smoothstep(0.1, 0.03, d);
}

// Borde de un triangulo equilatero de radio r0 girado angle.
float triangle_edge(vec2 p, float angle, float r0, float width) {
	float s = sin(angle);
	float c = cos(angle);
	p = mat2(vec2(c, s), vec2(-s, c)) * p;
	float d = -1e3;
	for (int i = 0; i < 3; i++) {
		float a = float(i) * TAU / 3.0 + PI * 0.5;
		d = max(d, dot(p, vec2(cos(a), sin(a))));
	}
	return smoothstep(width, 0.0, abs(d - r0 * 0.5));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float k = clamp(age / ENTRY, 0.0, 1.0);
	float ease = 1.0 - pow(1.0 - k, 3.0);

	// Bordes de la banda y las runas entre ellos, girando despacio.
	float edges = ring(r, BAND_IN, 0.012) + ring(r, BAND_OUT, 0.016);
	float turn = (a + TIME * 0.35) / TAU * RUNES;
	vec2 cell = vec2(fract(turn), (r - BAND_IN) / (BAND_OUT - BAND_IN));
	float runes = 0.0;
	if (cell.y > 0.0 && cell.y < 1.0) {
		runes = rune(vec2(0.5 + (cell.x - 0.5) * 1.6, cell.y), mod(floor(turn), RUNES)) * 0.9;
	}
	// Estrella de seis puntas adentro, mas tenue.
	float star = (triangle_edge(p, TIME * 0.5, 0.86, 0.02) + triangle_edge(p, PI - TIME * 0.5, 0.86, 0.02)) * 0.8;
	star *= smoothstep(BAND_IN, BAND_IN - 0.04, r);
	float inner_ring = ring(r, 0.2, 0.01) * 0.35;
	// Onda del clic: se cierra desde afuera hasta el centro.
	float shock = ring(r, mix(1.0, 0.2, ease), 0.07) * (1.0 - k) * 1.6;

	// Flechas: llegan desde afuera y despues respiran un poco.
	float arrow_r = mix(0.98, 0.7, ease) + sin(TIME * 4.5) * 0.02 * k;
	float arrows = 0.0;
	for (int i = 0; i < 4; i++) {
		float angle = float(i) * PI * 0.5 + PI * 0.25;
		vec2 dir = vec2(cos(angle), sin(angle));
		vec2 q = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x)));
		float side = abs(q.y);
		// 0 en el borde de adelante de la "V" (la punta mira al centro) y
		// crece hacia atras: la flecha es la franja gruesa detras de ese borde.
		float edge = (q.x - arrow_r) - side * 1.15;
		float body = smoothstep(-0.025, 0.0, edge) * smoothstep(0.1, 0.07, edge);
		arrows += body * step(side, 0.12) * step(arrow_r - 0.02, q.x);
	}

	float core = smoothstep(0.08, 0.0, r) * (0.65 + 0.35 * sin(TIME * 6.0));
	float shape = clamp(edges + runes + star + inner_ring + shock + arrows + core, 0.0, 1.0);
	// Luz suave: en el centro y sobre la banda de runas.
	float glow = exp(-r * r * 9.0) * 0.25 + ring(r, (BAND_IN + BAND_OUT) * 0.5, 0.2) * 0.1;
	float halo = ring(r, (BAND_IN + BAND_OUT) * 0.5, 0.16) * 0.4 + smoothstep(0.85, 0.2, r) * 0.1;

	// Por encima de 1 en lo mas fuerte: con el brillo del ambiente prendido
	// (glow del Environment) el glifo larga un poco de luz.
	vec3 bright = tint.rgb * (1.1 + shape * 0.9) + vec3(shape * shape * 0.4);
	ALBEDO = mix(tint.rgb * 0.08, bright, clamp(shape * 1.6 + glow * 2.2, 0.0, 1.0));
	float pop = smoothstep(0.0, 0.06, age);
	ALPHA = clamp(max(shape, halo) + glow, 0.0, 1.0) * smoothstep(1.0, 0.9, r) * fade * pop * tint.a;
}
