shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A QuadMesh at the muzzle, billboarded. `life` runs 1 -> 0 over the flash; `seed` is a
// random angle per shot so two shots never show the same star.

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform float spikes = 5.0;
uniform float seed = 0.0;
uniform float life = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float star = 0.5 + 0.5 * cos(a * spikes + seed);
	star = mix(star, 0.5 + 0.5 * cos(a * spikes * 2.0 - seed * 1.7), 0.3);
	float reach = mix(0.3, 1.0, star) * life;
	float body = 1.0 - smoothstep(reach * 0.75, reach, r);
	float core = 1.0 - smoothstep(0.0, 0.4 * life, r);
	ALBEDO = mix(edge_color.rgb, core_color.rgb, core);
	ALPHA = body;
}
