shader_type spatial;
render_mode cull_back;
// Body and head parts of a DummyBody (hands keep the solid material). Each hit hole
// (`BodyChunks`) is a world sphere: skin inside it is discarded, skin just outside it
// takes the rim stain. `clip_radius` > 0 drops the first-person neck cavity.

const int HOLE_CAP = 8;
// The rim stain fades out at this share of the hole radius.
const float RIM_SHARE = 1.25;

uniform vec4 albedo : source_color = vec4(0.62, 0.60, 0.58, 1.0);
uniform float roughness_amount = 0.9;
uniform float clip_radius = 0.0;
uniform vec4 rim_color : source_color = vec4(0.62, 0.16, 0.13, 1.0);
// xyz world center, w radius.
uniform vec4 holes[HOLE_CAP];
uniform int hole_count = 0;

void fragment() {
	if (clip_radius > 0.0 && length(VERTEX) < clip_radius) {
		discard;
	}
	vec3 color = albedo.rgb;
	if (hole_count > 0) {
		vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float stain = 0.0;
		for (int i = 0; i < HOLE_CAP; i++) {
			if (i >= hole_count) {
				break;
			}
			float r = holes[i].w;
			float d = distance(world, holes[i].xyz);
			if (d < r) {
				discard;
			}
			stain = max(stain, 1.0 - smoothstep(r, r * RIM_SHARE, d));
		}
		color = mix(color, rim_color.rgb, stain);
	}
	ALBEDO = color;
	ROUGHNESS = roughness_amount;
}
