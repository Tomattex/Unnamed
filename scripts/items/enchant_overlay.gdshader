shader_type spatial;

// Brillo de encantamiento: va como pasada extra (material_overlay) sobre las
// mallas del arma, del escudo, del casco o del cuerpo, asi no toca los
// materiales del modelo. Suma luz: un borde del color de la rareza (fresnel),
// una franja que barre el objeto de punta a punta cada tanto (el "sheen") y un
// pulso suave. Ver scripts/items/enchant_fx.gd.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.45, 0.62, 1.0, 1.0);
uniform vec4 sheen_color : source_color = vec4(1.0);
uniform float rim_strength = 0.0;
uniform float rim_power = 2.4;
// Tinte parejo de todo el objeto (como si estuviera cargado de magia).
uniform float base_glow = 0.0;
uniform float sheen_strength = 0.0;
// Ancho de la franja, en partes del largo del objeto.
uniform float sheen_width = 0.14;
// Segundos entre una pasada y la siguiente (la franja tarda SWEEP_SHARE de eso).
uniform float sheen_period = 3.2;
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 2.4;
// Cuanto del pulso llena las caras de frente (el resto va en el borde).
uniform float pulse_fill = 0.35;
uniform float time_offset = 0.0;
// Eje del objeto en el espacio de la malla: along = dot(VERTEX - origin, axis)
// da 0 en un extremo y 1 en la punta; tilt inclina la franja.
uniform vec3 axis_origin = vec3(0.0);
uniform vec3 axis_scale = vec3(0.0, 1.0, 0.0);
uniform vec3 tilt_scale = vec3(0.0);

// Parte del ciclo que tarda la franja en recorrer el objeto (el resto, quieto).
const float SWEEP_SHARE = 0.4;

varying float v_along;

void vertex() {
	vec3 rel = VERTEX - axis_origin;
	v_along = dot(rel, axis_scale) + dot(rel, tilt_scale);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float t = TIME + time_offset;
	float sweep = fract(t / sheen_period) / SWEEP_SHARE;
	float center = mix(-0.25, 1.25, sweep);
	float band = sweep < 1.0 ? 1.0 - smoothstep(0.0, sheen_width, abs(v_along - center)) : 0.0;
	band *= band;
	float pulse = 0.5 + 0.5 * sin(t * pulse_speed);
	vec3 color = glow_color.rgb * (rim * rim_strength + base_glow + pulse * pulse_strength * (pulse_fill + rim));
	// La franja brilla mas en los bordes y en las caras que miran a la camara.
	color += sheen_color.rgb * band * sheen_strength * (0.55 + 0.45 * facing + rim);
	ALBEDO = color;
}
