shader_type spatial;

// Destello en estrella en la punta del arma: aparece justo cuando la franja
// del sheen (enchant_overlay.gdshader, mismo periodo y desfase) llega a la
// punta, gira un poco y se apaga. Siempre de frente a la camara.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D star_texture : source_color, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.5;
uniform float sheen_period = 3.2;
uniform float time_offset = 0.0;

const float SWEEP_SHARE = 0.4;
// Momento del ciclo en que la franja pasa por la punta (along = 1).
const float AT_TIP = SWEEP_SHARE * (1.25 / 1.5);

varying float v_flash;

void vertex() {
	float t = TIME + time_offset;
	float phase = fract(t / sheen_period);
	float d = (phase - AT_TIP) / 0.035;
	v_flash = exp(-d * d);
	// Crece y gira mientras dura el destello.
	float angle = t * 2.5;
	mat2 spin = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	VERTEX.xy = spin * VERTEX.xy * (0.25 + 0.75 * v_flash);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 star = texture(star_texture, UV);
	ALBEDO = color.rgb * star.rgb * star.a * strength * v_flash;
}
