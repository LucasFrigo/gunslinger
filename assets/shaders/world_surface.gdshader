shader_type spatial;
render_mode cull_disabled;
// Every static scenario surface, written into the GLBs by `world_surface_import.gd`: the
// flat color, banded light, one grain lookup projected along the face's dominant axis, the
// GLB's hand-painted albedo image on surfaces that have one (the trim sheet is paused), and
// wind. `cull_disabled` because the GLBs ship every material double-sided: plants, awnings,
// and signs are single slabs that would vanish otherwise.
#include "res://assets/shaders/toon_light.gdshaderinc"

// Declared in project.godot [shader_globals]. GameManager pushes the grain multipliers (F3
// World); ScenarioBase writes the wind and leaves both 0 where an arena has none.
// `sheet_mix` blends the trim sheet over the flat color: 1 is the sheet, 0 the old look.
global uniform float grain_strength_mult;
global uniform float grain_scale_mult;
global uniform float sheet_mix;
global uniform float wind_ambient;
global uniform float wind_gust;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness_amount = 1.0;
uniform sampler2D grain_tex : filter_nearest, repeat_enable, hint_default_white;
// Trim sheet, read through UV. Set by the importer on surfaces that have UVs and are not
// tiling ground or rock. Grain fades out as the sheet fades in.
uniform sampler2D sheet_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform bool use_sheet = false;
// The hand-painted 256x256 image of one GLB, read through UV and replacing the flat color.
// Set by the importer on surfaces whose glTF material has a base color image. Clamped, so an
// island never reads the opposite edge; no grain on it.
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_disable, hint_default_white;
uniform bool use_albedo_tex = false;
// Tiles per metre.
uniform float grain_scale = 0.35;
uniform float grain_strength = 0.0;
// The grain fades out between these view distances, so far ground does not shimmer.
uniform float grain_fade_near = 15.0;
uniform float grain_fade_far = 45.0;
// Model space, so a piece that moves (the train rooftop belt) carries its grain with it.
uniform bool grain_local = true;
// Bend in metres at full wind, pinned at the mesh origin. Plants and hay.
uniform float sway_amount = 0.0;
uniform float sway_speed = 1.3;
// Model-space height at which the bend reaches full strength.
uniform float sway_height = 1.0;
// Rigid slabs (signs, awnings): their vertices sit in building space, so a bend by height
// does nothing. Radians about `hinge_axis` through `hinge_origin` (model space) at full
// wind; 0 is off.
uniform float hinge_amount = 0.0;
uniform vec3 hinge_origin = vec3(0.0);
uniform vec3 hinge_axis = vec3(1.0, 0.0, 0.0);

varying vec3 grain_pos;
varying vec3 grain_normal;
varying float view_dist;

void vertex() {
	if (grain_local) {
		grain_pos = VERTEX;
		grain_normal = NORMAL;
	} else {
		grain_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		grain_normal = mat3(MODEL_MATRIX) * NORMAL;
	}
	float wind = wind_ambient + wind_gust;
	if (wind > 0.0 && (sway_amount > 0.0 || hinge_amount > 0.0)) {
		// Phase keys off the instance origin so neighbours do not move together.
		vec3 origin = MODEL_MATRIX[3].xyz;
		float phase = origin.x * 0.7 + origin.z * 1.3;
		float t = TIME * sway_speed;
		float swing = (sin(t + phase) + 0.5 * sin(t * 2.3 + phase * 1.7)) * wind;
		if (sway_amount > 0.0) {
			float bend = clamp(VERTEX.y / sway_height, 0.0, 1.0);
			VERTEX.x += swing * sway_amount * bend * bend;
		}
		if (hinge_amount > 0.0) {
			vec3 axis = normalize(hinge_axis);
			float angle = swing * hinge_amount;
			float c = cos(angle);
			float s = sin(angle);
			vec3 p = VERTEX - hinge_origin;
			VERTEX = hinge_origin + p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c);
			NORMAL = NORMAL * c + cross(axis, NORMAL) * s + axis * dot(axis, NORMAL) * (1.0 - c);
		}
	}
	view_dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec3 facing = abs(grain_normal);
	vec2 grain_uv = grain_pos.xz;
	if (facing.y < max(facing.x, facing.z)) {
		grain_uv = facing.x > facing.z ? grain_pos.zy : grain_pos.xy;
	}
	float fade = 1.0 - smoothstep(grain_fade_near, grain_fade_far, view_dist);
	float grain = texture(grain_tex, grain_uv * grain_scale * grain_scale_mult).r - 0.5;
	vec3 base = albedo.rgb;
	float flat_k = 1.0;
	if (use_albedo_tex) {
		base = texture(albedo_tex, UV).rgb;
		flat_k = 0.0;
	} else if (use_sheet) {
		base = mix(albedo.rgb, texture(sheet_tex, UV).rgb, sheet_mix);
		flat_k = 1.0 - sheet_mix;
	}
	ALBEDO = base * (1.0 + grain * 2.0 * grain_strength * grain_strength_mult * fade * flat_k);
	ROUGHNESS = roughness_amount;
}
