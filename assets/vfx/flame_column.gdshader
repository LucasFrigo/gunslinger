shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// One flame column (the oil field's lit `Flame_*` anchors, `FlameColumn`): a unit QuadMesh whose
// node scale is (width, height, 1), turned about its vertical axis to face the camera, with a
// procedural body in hard flat bands, white core, yellow, orange, dark-red rim, rolling upward
// and narrowing to a ragged top under its plume. Opaque cut-out: no blend, no dither, no glow.
// Fogged on the same distance ramp as `M_Smoke` (`world_smoke.gdshader`): no fog inside
// `smoke_fog_near`, the fog color past `smoke_fog_far`. Past that the column is plum against a bright
// horizon band, so it also melts: from `melt_near` to `melt_far` metres from the camera the whole body
// shrinks onto its mouth (same hard cut-out, no blend, no dither) and is gone by `melt_far`, short of the
// belt's 384 m wrap, so nothing pops at one.

global uniform float smoke_fog_near;
global uniform float smoke_fog_far;
global uniform vec4 smoke_fog_color : source_color;

uniform vec4 core_color : source_color = vec4(1.0, 0.953, 0.82, 1.0);
uniform vec4 yellow_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec4 orange_color : source_color = vec4(1.0, 0.45, 0.07, 1.0);
uniform vec4 rim_color : source_color = vec4(0.5, 0.1, 0.03, 1.0);
// Band edges on the heat value (1 hot, 0 cold): core above `core_at`, yellow above `yellow_at`, ...
uniform float core_at = 0.7;
uniform float yellow_at = 0.45;
uniform float orange_at = 0.2;
// Metres of a noise cell per metre of base width, and how fast the body rolls up, in metres a second.
uniform float cell_per_width = 0.35;
uniform float roll_speed = 9.0;
// Per-column phase so two columns never roll in step.
uniform float seed = 0.0;
// Lean toward world -x at the top, as a share of the height (rest plus the wind gust).
uniform float lean = 0.05;
// The quad is this much wider than the base, so the lean and the ragged edge have room.
uniform float width_slack = 1.5;
// The melt (see the header): scale 1 up to `melt_near`, 0 from `melt_far`, metres from the camera.
uniform float melt_near = 320.0;
uniform float melt_far = 370.0;

varying vec2 quad;
varying vec2 size_m;
varying float view_dist;
varying float col_dist;

void vertex() {
	size_m = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	quad = vec2(VERTEX.x + 0.5, VERTEX.y);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(1e-5, 0.0, 0.0));
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	// Shear the top toward world -x: a local offset along right and along the quad's normal.
	float t = clamp(VERTEX.y, 0.0, 1.0);
	float push = lean * size_m.y * t * t;
	VERTEX.x += -right.x * push / size_m.x;
	VERTEX.z += -to_cam.x * push;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(to_cam, 0.0), MODEL_MATRIX[3])
			* mat4(
			vec4(size_m.x, 0.0, 0.0, 0.0),
			vec4(0.0, size_m.y, 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	col_dist = length(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// The melt shrinks the whole column toward its mouth: read the quad at 1 / scale, so the shape and the
	// noise scale together.
	float scale = 1.0 - smoothstep(melt_near, melt_far, col_dist);
	if (scale <= 0.002) {
		discard;
	}
	float h = quad.y / scale;
	// Across the column in units of the base's half width: -1 to 1 at the base.
	float p = (quad.x - 0.5) * 2.0 * width_slack / scale;
	float cell = size_m.x / width_slack * cell_per_width;
	vec2 at = vec2(p * size_m.x / width_slack * 0.5, h * size_m.y) / cell;
	float roll = (TIME * roll_speed) / cell;
	float n1 = vnoise(vec2(at.x, at.y - roll) + seed);
	float n2 = vnoise(vec2(at.x * 2.1 + 7.0, at.y * 2.1 - roll * 1.6) + seed * 1.7);
	float n = n1 * 0.65 + n2 * 0.35;
	// Half width of the body: the base's, narrowing to a point. The noise tears the edge and the top.
	// Narrow foot, billowing out to the full base width around half the height, then pinching to the top.
	float rise = mix(0.55, 1.12, smoothstep(0.0, 0.45, h));
	float cap = 1.0 - pow(smoothstep(0.68, 1.0, h), 1.5);
	float body = rise * cap;
	float foot = 0.85 + 0.15 * smoothstep(0.0, 0.06, h);
	float n3 = vnoise(vec2(at.x * 4.3 + 3.0, at.y * 3.1 - roll * 2.3) + seed * 2.9);
	float edge = body * foot * (0.9 + 0.5 * (n - 0.5) + 0.3 * (n3 - 0.5));
	float reach = abs(p) / max(edge, 0.001);
	float top = 0.9 + 0.1 * n1 - 0.08 * hash(vec2(floor(at.x * 0.5), 3.0 + seed));
	if (reach > 1.0 || h > top || h < 0.0) {
		discard;
	}
	// Hot toward the axis and the base, torn by the noise.
	float heat = (1.0 - reach) * 1.0 + (n - 0.5) * 0.5 - h * 0.5 + 0.05;
	vec3 color = rim_color.rgb;
	if (heat > core_at) {
		color = core_color.rgb;
	} else if (heat > yellow_at) {
		color = yellow_color.rgb;
	} else if (heat > orange_at) {
		color = orange_color.rgb;
	}
	float haze = smoothstep(smoke_fog_near, smoke_fog_far, view_dist);
	ALBEDO = mix(color, smoke_fog_color.rgb, haze);
}
