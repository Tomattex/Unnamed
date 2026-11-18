shader_type spatial;

// Haz de luz vertical sobre los items buenos tirados en el piso: fuerte abajo,
// se apaga hacia arriba y a los costados, con vetas que suben despacio. Gira
// solo alrededor del eje vertical para mirar siempre a la camara.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float time_offset = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME + time_offset;
	// UV.y = 0 arriba y 1 abajo.
	float height = pow(UV.y, 2.2);
	float across = 1.0 - smoothstep(0.0, 1.0, abs(UV.x - 0.5) * 2.0);
	float core = pow(across, 3.0);
	float streaks = 0.75 + 0.25 * sin(UV.y * 26.0 + t * 3.0 + sin(UV.x * 9.0) * 2.0);
	float flicker = 0.9 + 0.1 * sin(t * 5.3);
	ALBEDO = color.rgb * (across * 0.45 + core * 0.9) * height * streaks * flicker * strength;
}
