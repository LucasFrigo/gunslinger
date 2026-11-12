shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled;
// Ribbon from `BulletTrail`. UV.x runs across the strip, UV.y from the tail (0) to the
// bullet (1). White-hot core, tinted edge, tail thinning out.

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float fade = 1.0;
uniform float tail_share = 0.35;
// 0 adds light (pure additive), 1 mixes like plain alpha. TimeOfDay raises it at noon so
// the ribbon stays visible against a bright sky.
uniform float solid = 0.3;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float core = smoothstep(0.5, 0.9, across);
	float a = across * smoothstep(0.0, max(tail_share, 0.001), UV.y) * fade;
	ALBEDO = mix(tint.rgb, vec3(1.0), core) * a;
	ALPHA = a * solid;
}
