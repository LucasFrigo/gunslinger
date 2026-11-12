shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled;
// Spin effect from `SpinFx`: one quad in the plane the blaster turns in, centered on the spin
// pivot. UV is polar here: the angle behind `head_angle` (the barrel tip) and the radius from
// the pivot. A soft smear wedge sits under a few ink arcs that taper to a point behind the
// barrel (the "blur" and "lines" candidates, now drawn together).

// Barrel tip angle in the quad plane (rad, counter-clockwise from the barrel direction).
uniform float head_angle = 0.0;
// Signed visual turn rate (rad/s). The sign picks which side of the head the trail sits on.
uniform float omega = 0.0;
// Seconds of motion the trail covers; wedge length is omega * window, capped below a turn.
uniform float window = 0.045;
// 0..1 overall strength (slow turns fade out).
uniform float fade = 1.0;
// Half the quad edge (m), so radius can be read in metres.
uniform float half_size = 0.25;
// Radius of the barrel tip from the pivot (m).
uniform float tip_radius = 0.19;
// Arc half width at the head (m). Never drawn thinner than ~0.75 px, so it can't shimmer.
uniform float line_width = 0.0042;
uniform vec4 blur_tint : source_color = vec4(0.93, 0.87, 0.75, 1.0);
uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.04, 1.0);

const float TAU_F = 6.28318530718;

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
	float r = length(p) * half_size;
	float dir = omega < 0.0 ? -1.0 : 1.0;
	float behind = mod((head_angle - atan(p.y, p.x)) * dir, TAU_F);
	float span = min(abs(omega) * window, TAU_F * 0.85);
	float t = behind / max(span, 0.001);

	// Smear wedge, brightest near the barrel tip.
	float wedge = (1.0 - t) * step(t, 1.0);
	float tip = exp(-pow((r - tip_radius) / 0.055, 2.0));
	float body = smoothstep(0.05, 0.09, r) * (1.0 - smoothstep(0.2, 0.23, r));
	float ab = wedge * wedge * body * mix(0.3, 1.0, tip) * 0.6;

	// Ink arcs: unbroken strokes whose width and opacity taper to nothing at the tail. The edge
	// is pixel-aware (fwidth), so a stroke far away or edge-on thins out evenly instead of
	// breaking up into patches.
	float px = max(fwidth(r), 0.0001);
	float ai = 0.0;
	for (int i = 0; i < 3; i++) {
		float radius = tip_radius - 0.045 * float(i);
		float len = 1.0 - 0.28 * float(i);
		float u = clamp(t / len, 0.0, 1.0);
		float taper = 1.0 - u;
		float half_w = max(line_width * mix(0.25, 1.0, taper), px * 0.75);
		float arc = 1.0 - smoothstep(half_w - px, half_w + px, abs(r - radius));
		ai = max(ai, arc * smoothstep(0.0, 0.5, taper) * step(t, len));
	}

	ab *= fade;
	ai *= fade;
	ALBEDO = ink.rgb * ai + blur_tint.rgb * ab * (1.0 - ai);
	ALPHA = ai + ab * (1.0 - ai);
}
