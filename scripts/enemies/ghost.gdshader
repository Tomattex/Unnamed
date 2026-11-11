shader_type spatial;
// Espectros: casi transparentes en el centro y brillantes en los bordes, con
// la textura original apenas marcada y un pulso suave. fade lo apaga al morir.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 ghost_color : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float fade = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 tex = texture(albedo_texture, UV).rgb;
	float detail = dot(tex, vec3(0.3, 0.59, 0.11));
	float pulse = 0.85 + 0.15 * sin(TIME * 2.5 + VERTEX.y * 0.01);
	ALBEDO = ghost_color.rgb * (0.45 + detail * 0.8) + vec3(rim * 0.35);
	ALPHA = clamp(0.18 + rim * 0.75, 0.0, 1.0) * pulse * fade;
}
