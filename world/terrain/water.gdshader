shader_type spatial;
// Agua de los rios, el mar y los charcos del pantano (world/build_world.gd).
// Barata para el renderizador Mobile: sin texturas ni lectura de profundidad,
// solo ondas con senos que corren en el sentido del agua.
// UV.x va de una orilla (0) a la otra (1); UV.y avanza a lo largo del agua.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.07, 0.2, 0.24);
uniform vec3 shallow_color : source_color = vec3(0.18, 0.4, 0.42);
uniform vec3 foam_color : source_color = vec3(0.86, 0.9, 0.88);
// Que tan rapido corre (rios) o se mueve (mar y charcos).
uniform float flow_speed = 0.35;
uniform float wave_strength = 1.0;
// Ancho de la espuma de la orilla (en UV.x).
uniform float foam_width = 0.09;
// false = espuma solo en UV.x = 0 (la orilla del mar).
uniform bool foam_both_sides = true;
uniform float opacity = 0.86;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * flow_speed;
	vec2 p = world_pos.xz / 260.0;
	float along = UV.y * 6.0;
	float r1 = sin(p.x * 1.3 + along * 1.7 - t * 9.0) * 0.5 + 0.5;
	float r2 = sin(p.y * 1.9 - p.x * 0.6 + along * 0.9 + t * 4.3) * 0.5 + 0.5;
	float r3 = sin((p.x + p.y) * 3.1 - t * 6.0) * 0.5 + 0.5;
	float ripple = r1 * r2 * 0.7 + r3 * 0.3;

	float edge = foam_both_sides ? min(UV.x, 1.0 - UV.x) : UV.x;
	float foam = 1.0 - smoothstep(0.0, foam_width, edge + (ripple - 0.5) * foam_width * 0.6);
	float depth = smoothstep(0.0, 0.35, edge);

	vec3 color = mix(shallow_color, deep_color, depth * 0.8);
	color += vec3(0.05, 0.07, 0.07) * (ripple - 0.4) * wave_strength;
	color = mix(color, foam_color, foam * 0.75);

	ALBEDO = color;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	vec2 tilt = vec2(r1 - 0.5, r2 - 0.5) * 0.35 * wave_strength;
	NORMAL_MAP = normalize(vec3(0.5 + tilt.x, 0.5 + tilt.y, 1.0));
	NORMAL_MAP_DEPTH = 0.6;
	ALPHA = mix(opacity, 1.0, foam * 0.6);
}
