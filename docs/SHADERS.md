# Shaders

Candidate shaders for the polish pass, ranked by how much they change the picture for the work they cost. Nothing here is in the game yet. The only custom shaders in code today are `characters/body_skin.gdshader` and `characters/body_cavity.gdshader` (hit holes); every other surface is a `StandardMaterial3D`.

All ten shaders below compile and draw on Godot 4.7 Compatibility (desktop OpenGL 3.3). None has run inside the game, in a headset, or on a Quest.

![Bench: sky, grain ground, muzzle flash, trail, skin, outline, sway, matcap, dithered puff](shaders/bench.png)

Left to right: muzzle flash, bullet trail, skin with edge light, skin with outline, world surface, matcap metal. Above them a dithered puff. Behind them the sky with six bands, and the grain on the ground. The iris and hurt vignette: [`shaders/bench_overlay.png`](shaders/bench_overlay.png).

Status: [`FEATURES.md`](FEATURES.md) · Systems: [`ARCHITECTURE.md`](ARCHITECTURE.md) · Art direction: [`design/README.md`](design/README.md)

## What the renderer allows

`project.godot` sets `gl_compatibility` for every platform, so Quest 3, PCVR, and flat all run the same shaders. That decides most of this list.

| Works | Does not work, or costs too much on Quest |
|---|---|
| `spatial` shaders with custom `vertex()`, `fragment()`, `light()` | Decals (not in Compatibility) |
| `sky` shaders | SSAO, SSR, SDFGI, volumetric fog (not in Compatibility) |
| `next_pass` and `material_overlay` | Reading the screen or depth (`hint_screen_texture`, `hint_depth_texture`): forces a full-frame copy per eye |
| Additive and alpha blending, `discard` | Glow and other full-screen post passes |
| Depth fog on the `Environment` (already on) | Large areas of alpha blending close to the eye |
| Global shader uniforms | `CompositorEffect` (needs a RenderingDevice renderer) |

So the list holds no heat haze, no screen-space outline, no soft particles, and no color grade that reads the frame. Each effect below is drawn on the mesh itself.

The look to hit is already written down: low-poly PSX, nearest-sampled textures, a character that reads as a silhouette and two or three flat colors at duel range, and Steel Ball Run's loud flat color (`.claude/skills/gunslinger-taste/SKILL.md`).

## The list

Ordered by return. "Wiring" is the code outside the shader.

| # | Shader | What changes on screen | Wiring | Quest cost |
|---|---|---|---|---|
| 1 | [Muzzle flash](#1-muzzle-flash) | A shot shows a star at the muzzle. Today it is only a light | One quad and a tween in `weapons/weapon_base.gd` | Tiny |
| 2 | [Banded light](#2-banded-light) | Faceted two-tone shading on everything that includes it | None. It is an include | None |
| 3 | [Skin edge light and hit flash](#3-skin-edge-light-and-hit-flash) | Duelists separate from the fog; a hit blinks white | A few lines in `characters/body_skin.gdshader`, one tween | Tiny |
| 4 | [Bullet trail](#4-bullet-trail) | White-hot core, soft edge, thinning tail | UVs on the ribbon, material swap in `weapons/bullet_trail.gd` | Tiny |
| 5 | [Sky](#5-sky) | A poster sun, cel clouds, optional flat bands | `scenarios/time_of_day.gd` and two autotest checks | Small |
| 6 | [Dithered puff](#6-dithered-puff) | Smoke and dust become lumpy puffs that erode, not shrinking spheres | Swap the draw pass in the smoke and dust scenes | Small. Check in a headset |
| 7 | [Outline](#7-outline) | An ink line around each duelist | `material_overlay` in `characters/dummy_body.gd` | Draws each body twice |
| 8 | [World surface](#8-world-surface) | Banded light, grain on flat-color ground and walls, wind sway | Material swap over every scenario GLB | Small per pixel, large in reach |
| 9 | [Matcap metal](#9-matcap-metal) | The revolver gets a sheen | Material swap on the revolver mesh, one gradient texture | Tiny |
| 10 | [Screen overlay](#10-screen-overlay) | Iris wipe, and a vignette on a hit | One quad on each camera | One blended full-screen pass while visible |

Start with 1 to 4. They touch four files, need no art, and none of them changes how a scene is built. 5 and 8 change the whole frame; the choices made for them are under [Decided](#decided).

## How to build one

1. **Put the file beside its owner.** `characters/body_skin.gdshader` sits with the script that drives it. Do the same: `weapons/muzzle_flash.gdshader`, `scenarios/sky_western.gdshader`. Shared code goes in `assets/shaders/` as a `.gdshaderinc`.
2. **Write it as a `ShaderMaterial` on a test mesh first.** Use the mesh lab (`dev/mesh_lab/mesh_lab.tscn`) or a throwaway scene. Do not start by wiring it into gameplay. Headless runs do not compile shaders, so an autotest pass says nothing about one.
3. **Keep the fragment cheap.** One or two texture lookups. No loop without a fixed cap (`HOLE_CAP` in the skin shader is the model). Move work to `vertex()` when the result can be interpolated. Prefer the opaque pass with `discard` to alpha blending.
4. **Drive it from code through uniforms.** `material.set_shader_parameter("life", 1.0)` and a tween. A value every material shares (wind, a slow-mo tint) is a global uniform: declare it in Project Settings → Shader Globals and set it with `RenderingServer.global_shader_parameter_set`.
5. **Register it for boot warmup.** A shader compiles the first time it draws, and that hitch is [BUG-010](BUGS.md). Anything that first appears in combat must draw once under `ImpactFeedback._spawn_draw_warmup` (`autoload/impact_feedback.gd`). A cue in `VfxCatalog` is covered already; a new mesh or material needs a line there.
6. **Check it in flat, then PCVR, then Quest.** Flat (`--flat`) is the fast loop. In the headset look for three things: the effect matches in both eyes, it does not shimmer when the head moves, and a billboard does not tilt as the head rolls.
7. **Measure on the Quest.** Compare frame time with the effect on and off. An effect that covers the view (sky, world surface, overlay) is the one to measure; a 30 cm quad is not.
8. **Run the suites that touch what changed.** `load` after a scenario or sky change, `chunks` and `ragdoll` after the skin, `duel` after the weapon.
9. **Write it down when it ships.** A row in `FEATURES.md`, a `CHANGELOG.md` line under `[Unreleased]`, and a note in `ARCHITECTURE.md` if a material's owner changed.

## The shaders

### 1. Muzzle flash

`WeaponBase._muzzle_flash()` (`weapons/weapon_base.gd`) spawns an `OmniLight3D` for 0.08 s and nothing else, so the shot has no visible flash. This adds a billboarded quad with a procedural star.

`weapons/muzzle_flash.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A QuadMesh at the muzzle, billboarded. `life` runs 1 -> 0 over the flash; `seed` is a
// random angle per shot so two shots never show the same star.

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform float spikes = 5.0;
uniform float seed = 0.0;
uniform float life = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float star = 0.5 + 0.5 * cos(a * spikes + seed);
	star = mix(star, 0.5 + 0.5 * cos(a * spikes * 2.0 - seed * 1.7), 0.3);
	float reach = mix(0.3, 1.0, star) * life;
	float body = 1.0 - smoothstep(reach * 0.75, reach, r);
	float core = 1.0 - smoothstep(0.0, 0.4 * life, r);
	ALBEDO = mix(edge_color.rgb, core_color.rgb, core);
	ALPHA = body;
}
```

- **Wire:** in `_muzzle_flash()`, add a `MeshInstance3D` with a `QuadMesh` (about 0.3 m) at `get_muzzle().position`, set `seed` to `randf() * TAU`, tween `life` from 1 to 0 over the same 0.08 s, free it with the light.
- **Warmup:** add the same quad to `_spawn_draw_warmup`, next to the existing muzzle light.
- **Watch:** a billboard faces the viewer, so the shooter sees a star and a bystander sees the same star, never a cone. A second quad along the barrel would give the side view.

### 2. Banded light

A custom `light()` that turns the smooth diffuse falloff into two steps. A flat-shaded low-poly face lands wholly in one band, so the shadow edge follows the facets. Every lit shader below includes it, so the whole frame shares one lighting model.

`assets/shaders/toon_light.gdshaderinc`:

```glsl
// Two-step diffuse shared by every lit surface. A flat-shaded low-poly face lands wholly
// in one band, so the terminator follows the facets.
uniform float band_soft = 0.03;
// Share of the light the first band lets through.
uniform float band_low = 0.65;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_soft, ndl) * band_low
			+ smoothstep(0.5, 0.5 + band_soft, ndl) * (1.0 - band_low);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
```

- **Watch:** it drops specular, which suits the matte look. A surface that still uses `StandardMaterial3D` keeps smooth light and will look out of place beside one that includes this, so it pays off most once [World surface](#8-world-surface) is in.

### 3. Skin edge light and hit flash

Two additions to `characters/body_skin.gdshader`. The edge light brightens the silhouette where the surface turns away from the eye, which keeps a grey mannequin readable against orange fog at 22 m. `flash` blinks the body white on a hit.

Add the include under `render_mode`, the uniforms with the others, and the last two lines at the end of `fragment()`:

```glsl
#include "res://assets/shaders/toon_light.gdshaderinc"

// Back-light on the silhouette edge, so a duelist reads against the fog at range.
uniform vec4 edge_light : source_color = vec4(1.0, 0.75, 0.5, 1.0);
uniform float edge_power = 3.0;
uniform float edge_strength = 0.35;
// 1 on the hit frame, tweened to 0.
uniform float flash = 0.0;

	// ...end of fragment(), after ROUGHNESS:
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_power);
	EMISSION = edge_light.rgb * edge * edge_strength + vec3(flash);
```

- **Wire:** `DummyBody` owns `_skin_material`. A `flash()` method there tweens the uniform from 1 to 0 over about 0.1 s; call it where the body takes a hit.
- **Better:** set `edge_light` from the scenario's sun color so the rim matches the time of day. `TimeOfDay.apply` already has that color.
- **Watch:** `rim_color` is taken; it is the hole stain. Hands use `DummyBody.solid_material`, not this shader, so they get neither effect until they move to it. Give `body_cavity.gdshader` the same include or the wound will be lit differently from the skin around it.
- **Test:** `chunks`, `ragdoll`.

### 4. Bullet trail

`BulletTrail` (`weapons/bullet_trail.gd`) draws a 2 cm unshaded ribbon in one flat color and fades its alpha. This gives it a hot core, a soft edge, and a tail that thins out.

`weapons/bullet_trail.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Ribbon from `BulletTrail`. UV.x runs across the strip, UV.y from the tail (0) to the
// bullet (1). White-hot core, tinted edge, tail thinning out.

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float fade = 1.0;
uniform float tail_share = 0.35;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float core = smoothstep(0.5, 0.9, across);
	ALBEDO = mix(tint.rgb, vec3(1.0), core);
	ALPHA = across * smoothstep(0.0, tail_share, UV.y) * fade;
}
```

- **Wire:** the ribbon has no UVs today. In `_rebuild_ribbon`, call `surface_set_uv(Vector2(0.0, v))` and `surface_set_uv(Vector2(1.0, v))` before the two vertices, with `v = float(i) / float(count - 1)`. `make_material` returns a `ShaderMaterial`; the fade line in `_process` sets `fade` in place of `albedo_color`.
- **Warmup:** `_spawn_draw_warmup` already draws a ribbon through `BulletTrail.make_material`. Give that ribbon UVs too.
- **Watch:** with a soft edge the ribbon looks thinner than 2 cm. Raise `WIDTH` to about 0.035 to compensate. Additive blending disappears against a bright noon sky; if it does, switch `blend_add` to `blend_mix`.

### 5. Sky

Replaces `ProceduralSkyMaterial`. It reproduces that material's gradient, so the fog still meets `ground_horizon` and the canyon's far edge stays hidden, and adds a hard sun disc with a halo, cel clouds from a noise texture, and optional flat bands.

`scenarios/sky_western.gdshader`:

```glsl
shader_type sky;
// Same gradient as ProceduralSkyMaterial (so the fog still meets `ground_horizon`), plus
// a hard sun disc, a halo, optional flat bands, and cel clouds. No TIME: an animated sky
// re-renders the radiance map every frame.

uniform vec3 sky_top : source_color = vec3(0.25, 0.15, 0.3);
uniform vec3 sky_horizon : source_color = vec3(0.95, 0.5, 0.25);
uniform float sky_curve = 0.15;
uniform vec3 ground_bottom : source_color = vec3(0.72, 0.4, 0.2);
uniform vec3 ground_horizon : source_color = vec3(0.95, 0.55, 0.28);
uniform float ground_curve = 0.02;
// 0 leaves the gradient smooth. 5 to 8 gives poster bands.
uniform float bands = 0.0;
// Radians. The real sun is 0.0046; a poster sun is 0.05 to 0.12.
uniform float sun_radius = 0.015;
uniform float sun_halo = 0.35;
uniform sampler2D cloud_tex : filter_linear, repeat_enable, hint_default_black;
uniform float cloud_cover = 0.35;
uniform float cloud_scale = 0.25;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.78, 0.62);

void sky() {
	float angle = acos(clamp(EYEDIR.y, -1.0, 1.0));
	float up = 1.0 - angle / (PI * 0.5);
	float sky_mix = clamp(1.0 - pow(1.0 - max(up, 0.0), 1.0 / sky_curve), 0.0, 1.0);
	if (bands > 0.0) {
		sky_mix = floor(sky_mix * bands + 0.5) / bands;
	}
	vec3 color = mix(sky_horizon, sky_top, sky_mix);
	if (EYEDIR.y < 0.0) {
		float down = clamp(1.0 - pow(1.0 + min(up, 0.0), 1.0 / ground_curve), 0.0, 1.0);
		color = mix(ground_horizon, ground_bottom, down);
	} else if (!AT_CUBEMAP_PASS) {
		// A flat deck far overhead, faded out before it reaches the horizon line.
		vec2 deck = EYEDIR.xz / (EYEDIR.y + 0.12) * cloud_scale + cloud_offset;
		float cloud = step(1.0 - cloud_cover, texture(cloud_tex, deck).r);
		color = mix(color, cloud_color, cloud * smoothstep(0.03, 0.2, EYEDIR.y) * 0.85);
		if (LIGHT0_ENABLED) {
			float sun = acos(clamp(dot(LIGHT0_DIRECTION, EYEDIR), -1.0, 1.0));
			float halo = 1.0 - smoothstep(sun_radius, sun_radius + sun_halo, sun);
			color += LIGHT0_COLOR * halo * halo * 0.25;
			color = mix(color, LIGHT0_COLOR * LIGHT0_ENERGY, 1.0 - step(sun_radius, sun));
		}
	}
	COLOR = color;
}
```

- **Wire:** `TimeOfDay.apply` casts the sky material to `ProceduralSkyMaterial` and returns when the cast fails, which would also skip the fog recolor. It has to set shader parameters instead. The uniform names match its keyframe keys (`sky_top`, `sky_horizon`, `ground_bottom`, `ground_horizon`) for that reason. `dev/autotest.gd` makes the same cast in two places.
- **Per scene:** carry each scene's curve over. Canyon sets `ground_curve = 0.12`; Main Street, the practice hub, and Train Rooftop set `sky_curve = 0.08`.
- **Clouds:** `cloud_tex` is a seamless `NoiseTexture2D`, made in the inspector. `cloud_offset` can be random per load so each duel has its own sky. Tie `cloud_color` to the sun color.
- **Watch:** clouds and sun are left out of the cubemap pass, so ambient light stays as it is now. The bench screenshot uses `bands = 6`, `sun_radius = 0.07`, and `cloud_cover = 0.45`; the game keeps the smooth gradient and the small sun. Saloon has no sky and is unaffected.
- **Test:** `load`, then F3 to scrub the time of day.

### 6. Dithered puff

The smoke and dust cues draw small unshaded spheres with alpha blending (`assets/vfx/muzzle_smoke.tscn`). This draws a quad that erodes through an ordered dither as the particle ages. It lands in the opaque pass: no sorting, no blending, and the stipple is the PSX look.

`assets/vfx/puff.gdshader`:

```glsl
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
```

- **Wire:** in `muzzle_smoke.tscn` and `world_dust.tscn`, swap the `SphereMesh` draw pass for a `QuadMesh` with this material. A quad needs to be about twice the sphere's diameter to read the same size. Set an angle range on the process material so `spin` varies. Leave the chip, shard, and coin cues as meshes.
- **Warmup:** covered. `VfxCatalog.spawn_for_compile` draws every cue.
- **Watch:** the dither is fixed to each eye's pixels, so the two eyes get unrelated patterns. In a headset that can read as sparkle. This is the one shader here most likely to need a VR fallback: if it sparkles, keep the lumpy shape and write `ALPHA = density` in place of the `discard`.

### 7. Outline

An inverted hull: the body drawn a second time, back faces only, pushed out along the normal, in ink. It is the closest thing to manga line art that needs no screen read.

`characters/body_outline.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// `material_overlay` on the body and head meshes: the back faces pushed out along the
// normal, in ink. `width` is metres of line per metre of view distance, so the line holds
// its screen size out to `far`, then thins.

uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.04, 1.0);
uniform float width = 0.004;
uniform float near = 1.0;
uniform float far = 14.0;
uniform float clip_radius = 0.0;

void vertex() {
	float dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * width * clamp(dist, near, far);
}

void fragment() {
	if (clip_radius > 0.0 && length(VERTEX) < clip_radius) {
		discard;
	}
	ALBEDO = ink.rgb;
}
```

- **Wire:** set it as `material_overlay` on the body, head, and hand meshes in `DummyBody._apply_material`. The skin's `next_pass` is taken by the cavity, so the overlay slot is the free one, and it works over the hands' solid material too. Pass the same `clip_radius` as the skin on the local first-person body.
- **Warmup:** add it to the probe in `BodyChunks.spawn_for_compile`.
- **Watch:** it needs smooth normals. Where a mesh has split normals at a hard edge the hull cracks open. A hit hole shows the hull's inside through the cut wherever the cavity pass does not cover it; check a holed body from several angles before keeping it. Gibs and the dropped gun get no line unless they are given one.
- **Test:** `chunks`, `ragdoll`.

### 8. World surface

One shader for every static scenario surface. It keeps the flat color or the nearest-sampled atlas, lights it with the bands, and adds one grain lookup projected along the face's dominant axis, so a flat-color wall or a sand plain gets texture without UVs or painted art. `sway_amount` bends a mesh in the wind.

`assets/shaders/world_surface.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back;
#include "res://assets/shaders/toon_light.gdshaderinc"
// Every static scenario surface: flat color or a nearest-sampled atlas, banded light,
// and one grain lookup projected along the face's dominant axis, so no mesh needs UVs
// for it. `sway_amount` > 0 bends the mesh in the wind, pinned at its origin.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform sampler2D grain_tex : filter_nearest, repeat_enable, hint_default_white;
// Tiles per metre.
uniform float grain_scale = 0.35;
uniform float grain_strength = 0.0;
// Model space, for pieces that move (the train rooftop belt).
uniform bool grain_local = false;
uniform float roughness_amount = 1.0;
uniform float sway_amount = 0.0;
uniform float sway_speed = 1.3;
// Model-space height at which the sway reaches full strength.
uniform float sway_height = 1.0;

varying vec3 grain_pos;
varying vec3 grain_normal;

void vertex() {
	if (sway_amount > 0.0) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float phase = origin.x * 0.7 + origin.z * 1.3;
		float bend = clamp(VERTEX.y / sway_height, 0.0, 1.0);
		float gust = sin(TIME * sway_speed + phase) + 0.5 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
		VERTEX.x += gust * sway_amount * bend * bend;
	}
	if (grain_local) {
		grain_pos = VERTEX;
		grain_normal = NORMAL;
	} else {
		grain_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		grain_normal = mat3(MODEL_MATRIX) * NORMAL;
	}
}

void fragment() {
	vec3 facing = abs(grain_normal);
	vec2 grain_uv = grain_pos.xz;
	if (facing.y < max(facing.x, facing.z)) {
		grain_uv = facing.x > facing.z ? grain_pos.zy : grain_pos.xy;
	}
	float grain = texture(grain_tex, grain_uv * grain_scale).r - 0.5;
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb * (1.0 + grain * 2.0 * grain_strength);
	ROUGHNESS = roughness_amount;
}
```

- **Wire:** this is the expensive one. Scenario art arrives as GLBs with their own `StandardMaterial3D`s. An import script on each scenario GLB copies every material's `albedo_color` and `albedo_texture` into a `ShaderMaterial` once, at import.
- **Grain:** `grain_tex` is a seamless `NoiseTexture2D`. Keep `grain_strength` at 0 until one is assigned. About 0.15 to 0.25 reads as sand or weathered board.
- **Sway:** set `sway_amount` (about 0.03) only on plants, signs, and cloth. It keys its phase off the object's position, so a piece on the Train Rooftop belt would change phase as it scrolls; leave the belt's cacti at 0. The belt also needs `grain_local`, or the grain slides across the moving pieces.
- **Watch:** it ignores vertex colors, normal maps, and transparency. Check what the GLB materials use before swapping, and skip any material that uses one of those.
- **Test:** `load`, then walk each scenario.

### 9. Matcap metal

Compatibility has no reflections to give a metallic surface, so metal renders as dark grey. A matcap looks a highlight up by the view-space normal instead. The revolver is 30 cm from the player's eyes for the whole game, which makes it the best-placed surface in the project.

`weapons/revolver/matcap_metal.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back;
// The revolver. The atlas stays nearest-sampled; a view-space matcap adds the sheen that
// Compatibility has no reflections to give. Grey texels count as metal, saturated ones
// (the wood grip) do not, so the atlas needs no mask.

uniform sampler2D albedo_tex : source_color, filter_nearest, hint_default_white;
uniform sampler2D matcap_tex : source_color, filter_linear, hint_default_black;
uniform float sheen = 0.8;
uniform float roughness_amount = 0.5;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float high = max(base.r, max(base.g, base.b));
	float low = min(base.r, min(base.g, base.b));
	float metal = 1.0 - smoothstep(0.08, 0.25, high - low);
	vec2 cap = NORMAL.xy * vec2(0.5, -0.5) + 0.5;
	ALBEDO = base;
	ROUGHNESS = roughness_amount;
	EMISSION = texture(matcap_tex, cap).rgb * metal * sheen * base;
}
```

- **Wire:** a material override on the PSX blaster mesh, with `albedo_tex` set to its atlas (`assets/models/weapons/wpn_psx_blaster_PSX_Blaster_Atlas.png`). `matcap_tex` is a radial `GradientTexture2D`, white off-center fading to black; no painted art.
- **Watch:** the metal mask is a guess from saturation. It works if the atlas paints metal grey and wood brown; look at the atlas first, and if it fails, replace the three `metal` lines with a mask texture. Add the banded include if the gun should match the world.

### 10. Screen overlay

A quad on the camera that draws over each eye without reading the frame. It does two jobs: an iris wipe (the circle that closes on the last frame of a cartoon western) and a vignette that pulls in from the edge on a hit. It could stand in for the black fade (`XRToolsFade`) and the red flash (`Hud.flash_red`).

`ui/screen_overlay.gdshader`:

```glsl
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
```

- **Wire:** a `MeshInstance3D` with a 2×2 `QuadMesh` under each camera (flat, VR, kill cam, death cam). Give it a large `extra_cull_margin`, because the shader moves the quad and the engine would otherwise cull it by its real position. Hide the node while `iris` is open and `hurt` is 0, so it costs nothing in normal play.
- **Watch:** the vertex function follows `addons/godot-xr-tools/effects/vignette.gdshader`, which is how that addon handles each eye's off-center projection. It has only been drawn on a flat camera here. It must draw after the world and before any UI that should stay visible; set a render priority.

## Not now

- **Heat haze, water refraction, soft particles, screen-space outline.** Each reads the screen or the depth buffer.
- **Glow and bloom.** A full-screen post pass. The muzzle flash and the trail fake it with additive color.
- **PSX vertex snap and affine texture warp.** On a flat screen it is the look. In stereo the snapping differs per eye and the world wobbles as the head moves. Flat-only at most.
- **Bullet-hole decals.** Compatibility has no `Decal`. A hole would be a small alpha-tested quad on the surface, which is a feature, not a shader.
- **A color grade over the frame.** It needs a screen read. Grade through the sun, sky, and fog colors that `TimeOfDay` already sets.

## Decided

Settled on 2026-10-12. Items 1 to 8 and 10 are on [`Roadmap.md`](../Roadmap.md); 9 (matcap metal) is not queued.

1. **Banded light:** everywhere. Characters take it first; the world follows with the world surface shader.
2. **Sky gradient:** smooth (`bands = 0`).
3. **Sun:** small, a bright dot with a halo.
4. **Outline:** every body and the local hands.
5. **Smoke and dust:** dithered in flat and VR.
6. **Screen overlay:** the iris replaces the black fade and the vignette replaces the red flash.
7. **World surface swap:** at import.
8. **Flat mode:** same look as VR. No flat-only pass.
