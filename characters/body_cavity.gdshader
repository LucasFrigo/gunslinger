shader_type spatial;
render_mode cull_front;
// `next_pass` of the body skin while it has holes. Draws the body's back faces only
// behind a hole: the view ray's far hit on the hole sphere is the bowl floor, written to
// DEPTH so it sits inside the cut. Front faces outside every hole occlude this pass, so
// the bowl shows only through the cut. A floor point above the skin (the sphere's cap in
// the air, seen at a grazing angle or from a light), or a sphere that reaches past the
// back face (a thin limb), shades the back face as flesh at its own depth instead:
// never daylight through the body, and never a bowl in front of the skin.

const int HOLE_CAP = 8;

uniform vec4 rim_color : source_color = vec4(0.62, 0.16, 0.13, 1.0);
uniform vec4 core_color : source_color = vec4(0.24, 0.02, 0.02, 1.0);
uniform float roughness_amount = 0.6;
uniform float clip_radius = 0.0;
// Share of the radius the center sits out of the skin, along the lift.
uniform float cut_lift = 0.3;
// xyz world center, w radius. Same data as the skin pass.
uniform vec4 holes[HOLE_CAP];
// xyz world outward lift (against the shot), w 1 when known.
uniform vec4 hole_lifts[HOLE_CAP];
uniform int hole_count = 0;

void fragment() {
	if (clip_radius > 0.0 && length(VERTEX) < clip_radius) {
		discard;
	}
	vec3 dir = normalize(VERTEX);
	float frag_t = length(VERTEX);
	float best_t = frag_t;
	vec3 best_c = vec3(0.0);
	float share = 1.0;
	bool hit = false;
	for (int i = 0; i < HOLE_CAP; i++) {
		if (i >= hole_count) {
			break;
		}
		vec3 c = (VIEW_MATRIX * vec4(holes[i].xyz, 1.0)).xyz;
		float r = holes[i].w;
		float b = dot(dir, c);
		float h = b * b - (dot(c, c) - r * r);
		if (h < 0.0) {
			continue;
		}
		float half_chord = sqrt(h);
		float far_t = b + half_chord;
		// Behind the camera, or wholly behind this back face.
		if (far_t <= 0.0 || b - half_chord >= frag_t) {
			continue;
		}
		hit = true;
		if (far_t >= best_t) {
			continue;
		}
		if (hole_lifts[i].w > 0.5) {
			vec3 lift = (VIEW_MATRIX * vec4(hole_lifts[i].xyz, 0.0)).xyz;
			if (dot(dir * far_t - c, lift) > -cut_lift * r) {
				continue;
			}
		}
		best_t = far_t;
		best_c = c;
		share = half_chord / r;
	}
	if (!hit) {
		discard;
	}
	if (best_t < frag_t) {
		vec3 p = dir * best_t;
		vec4 clip = PROJECTION_MATRIX * vec4(p, 1.0);
		float ndc_z = clip.z / clip.w;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		DEPTH = ndc_z * 0.5 + 0.5;
#else
		DEPTH = ndc_z;
#endif
		NORMAL = normalize(best_c - p);
		ALBEDO = mix(rim_color.rgb, core_color.rgb, clamp(share, 0.0, 1.0));
	} else {
		DEPTH = FRAGCOORD.z;
		ALBEDO = core_color.rgb;
	}
	ROUGHNESS = roughness_amount;
}
