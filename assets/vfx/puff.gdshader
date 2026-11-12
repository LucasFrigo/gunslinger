shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Draw pass for a GPUParticles3D on a QuadMesh: a lumpy puff that erodes with age through
// a 4x4 ordered dither. Opaque pass, so no sorting and no blending.
// The particle color tints it; its alpha is the starting density.

const mat4 BAYER = mat4(
		vec4(0.0, 8.0, 2.0, 10.0),
		vec4(12.0, 4.0, 14.0, 6.0),
		vec4(3.0, 11.0, 1.0, 9.0),
		vec4(15.0, 7.0, 13.0, 5.0));

uniform float lumps = 3.0;
uniform float lump_depth = 0.18;

varying float age;
varying float spin;

void vertex() {
	spin = INSTANCE_CUSTOM.x;
	age = INSTANCE_CUSTOM.y;
	mat4 world = mat4(
			normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = 1.0 - lump_depth * (0.5 + 0.5 * sin(atan(p.y, p.x) * lumps + spin));
	float density = (1.0 - length(p) / edge) * COLOR.a * (1.0 - age) * 2.0;
	ivec2 cell = ivec2(mod(FRAGCOORD.xy, 4.0));
	if (density < (BAYER[cell.x][cell.y] + 0.5) / 16.0) {
		discard;
	}
	ALBEDO = COLOR.rgb;
}
