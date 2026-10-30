shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// `M_Smoke` surfaces (the oil field's plumes), written into the GLBs by `world_surface_import.gd`.
// Drawn exactly its own color, no light, no shadow, and fogged on a distance ramp instead of the
// scene's exponential fog: none inside `smoke_fog_near`, the fog color past `smoke_fog_far`,
// smooth between. `fog_disabled` is a static render mode, so this cannot be a path inside
// `world_surface.gdshader` without un-fogging every other world surface. The flame cue
// (`assets/vfx/flame_column.gdshader`) reads the same three globals.
// Declared in project.godot [shader_globals]; `LaneGlow` writes the color with the fog flicker.

global uniform float smoke_fog_near;
global uniform float smoke_fog_far;
global uniform vec4 smoke_fog_color : source_color;

uniform vec4 albedo : source_color = vec4(1.0);

varying float view_dist;

void vertex() {
	view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float haze = smoothstep(smoke_fog_near, smoke_fog_far, view_dist);
	ALBEDO = mix(albedo.rgb, smoke_fog_color.rgb, haze);
}
