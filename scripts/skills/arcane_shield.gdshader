shader_type spatial;

// Burbuja de los escudos (Escudo Arcano, Piel de Piedra): brillo en el borde
// (fresnel), una trama de energia que corre despacio y bandas que suben.
// Aditivo y sin luz: con el renderizador Mobile no hay transparencia por nodo,
// asi que se apaga con intensity.
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.6, 0.5, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
// Trama (ruido celular sin costuras).
uniform sampler2D pattern : filter_linear_mipmap, repeat_enable;
// Cuanto se ve la trama adentro (la piedra es mas opaca y quieta).
uniform float pattern_strength = 0.35;
uniform float flow_speed = 1.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	vec2 uv = UV * vec2(5.0, 2.5);
	float cells = texture(pattern, uv + vec2(TIME * 0.03, TIME * 0.09) * flow_speed).r;
	float cells2 = texture(pattern, uv * 1.7 - vec2(TIME * 0.05, TIME * 0.04) * flow_speed).r;
	float web = smoothstep(0.55, 0.9, max(cells, cells2));
	float bands = smoothstep(0.75, 1.0, sin(UV.y * 34.0 - TIME * 4.0 * flow_speed) * 0.5 + 0.5);
	float glow = rim * 1.4 + web * pattern_strength * (0.35 + rim) + bands * 0.08 * (0.3 + rim);
	ALBEDO = mix(color.rgb, vec3(1.0), rim * 0.35) * glow;
	ALPHA = clamp(glow, 0.0, 1.0) * intensity;
}
