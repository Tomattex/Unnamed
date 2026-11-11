shader_type canvas_item;

// Fondo del menu del juego: lo que queda atras (el mundo y el HUD) borroso,
// oscurecido, tirando a sepia y con viñeta. amount va de 0 (se ve normal) a
// 1 (menu abierto) para entrar con una transicion.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 sharp = texture(screen_texture, SCREEN_UV).rgb;
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, 3.2).rgb;
	vec3 color = mix(sharp, blurred, amount);
	float gray = dot(color, vec3(0.3, 0.59, 0.11));
	color = mix(color, gray * vec3(1.08, 0.94, 0.76), 0.5 * amount);
	vec2 d = (UV - 0.5) * vec2(1.3, 1.0);
	float vignette = smoothstep(0.95, 0.2, length(d));
	color *= mix(1.0, mix(0.18, 0.5, vignette), amount);
	COLOR = vec4(color, 1.0);
}
