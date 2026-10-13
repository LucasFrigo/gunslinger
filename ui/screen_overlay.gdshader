shader_type spatial;
render_mode unshaded, depth_test_disabled, skip_vertex_transform, cull_disabled, shadows_disabled;
// A 2x2 QuadMesh parented to the camera, drawn over each eye without reading the screen.
// `iris` is the open radius as the tangent of the angle off the eye's forward axis
// (1 is 45 degrees; 0 is shut). `hurt` 0..1 pulls a tinted vignette in from the edge.

uniform vec4 ink : source_color = vec4(0.03, 0.02, 0.02, 1.0);
uniform float iris = 4.0;
uniform float iris_soft = 0.01;
uniform vec4 hurt_color : source_color = vec4(0.55, 0.05, 0.03, 0.8);
uniform float hurt = 0.0;
uniform float hurt_inner = 0.45;
uniform float hurt_outer = 1.1;

varying vec2 off_axis;

void vertex() {
	// Each eye's projection is off-center; measure from where its forward axis lands.
	vec2 center = -PROJECTION_MATRIX[2].xy;
	off_axis = (VERTEX.xy - center) / vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]);
	float z = PROJECTION_MATRIX[2][2] < 0.0 ? 0.0 : 1.0;
	POSITION = vec4(VERTEX.xy, z, 1.0);
}

void fragment() {
	float r = length(off_axis);
	float shut = smoothstep(iris, iris + iris_soft, r);
	float vignette = smoothstep(hurt_inner, hurt_outer, r) * hurt * hurt_color.a;
	ALBEDO = mix(hurt_color.rgb, ink.rgb, shut);
	ALPHA = max(shut, vignette);
}
