shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// The ink line of a DummyBody part: its welded outline mesh (back faces only) pushed out
// along the averaged normal. `width` is metres of line per metre of view distance, so the
// line holds its screen size from `near` to `far`, then thins. Takes the skin's hit holes so
// the hull is cut where the skin is; `clip_radius` > 0 drops the first-person neck cavity.

const int HOLE_CAP = 8;

uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.04, 1.0);
uniform float width = 0.004;
uniform float near = 1.0;
uniform float far = 14.0;
uniform float clip_radius = 0.0;
// xyz world center, w radius.
uniform vec4 holes[HOLE_CAP];
uniform int hole_count = 0;

void vertex() {
	float dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * width * clamp(dist, near, far);
}

void fragment() {
	if (clip_radius > 0.0 && length(VERTEX) < clip_radius) {
		discard;
	}
	if (hole_count > 0) {
		vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		for (int i = 0; i < HOLE_CAP; i++) {
			if (i >= hole_count) {
				break;
			}
			if (distance(world, holes[i].xyz) < holes[i].w) {
				discard;
			}
		}
	}
	ALBEDO = ink.rgb;
}
