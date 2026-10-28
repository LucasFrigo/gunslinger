# Shaders

Candidate shaders for the polish pass, ranked by how much they change the picture for the work they cost. Section 5 (sky) is in the game as `scenarios/sky_western.gdshader`, section 4 (bullet trail) as `weapons/bullet_trail.gdshader`, section 6 (dithered puff) as `assets/vfx/puff.gdshader`, section 7 (outline) as `characters/body_outline.gdshader`, section 8 (world surface) as `assets/shaders/world_surface.gdshader`, and section 10 (screen overlay) as `ui/screen_overlay.gdshader`; for the rest, [`FEATURES.md`](FEATURES.md) says what has landed. `characters/body_skin.gdshader` and `characters/body_cavity.gdshader` (hit holes) predate this list; every other surface is a `StandardMaterial3D` unless a row says otherwise.

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
| 4 | [Bullet trail](#4-bullet-trail) | White-hot core, soft edge, thinning tail | UVs on the ribbon, material swap in `weapons/bullet_trail.gd` (shipped) | Tiny |
| 5 | [Sky](#5-sky) | A poster sun, cel clouds, optional flat bands | `scenarios/time_of_day.gd` and two autotest checks | Small |
| 6 | [Dithered puff](#6-dithered-puff) | Smoke and dust become lumpy puffs that erode, not shrinking spheres | Swap the draw pass in the smoke and dust scenes | Small. Check in a headset |
| 7 | [Outline](#7-outline) | An ink line around each duelist | A welded `Outline` child per part in `characters/dummy_body.gd` (shipped) | Draws each body twice |
| 8 | [World surface](#8-world-surface) | Banded light, grain on flat-color ground and walls, wind sway | Material swap over every scenario GLB | Small per pixel, large in reach |
| 9 | [Matcap metal](#9-matcap-metal) | The revolver gets a sheen | Material swap on the revolver mesh, one gradient texture | Tiny |
| 10 | [Screen overlay](#10-screen-overlay) | Iris wipe, and a vignette on a hit | One quad on the current camera (shipped) | One blended full-screen pass while visible |
| 11 | [Spin effect](#11-spin-effect) | A smear wedge under tapering ink arcs behind the twirling barrel | One static quad child of the revolver (built, untuned) | Tiny, one 0.5 m quad while twirling. Measure |

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

**Shipped.** Owner: `weapons/muzzle_flash.gdshader`, wired in `WeaponBase._muzzle_flash()` / `make_muzzle_flash_quad()` and `ImpactFeedback._spawn_draw_warmup`.

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

**Shipped.** Owner: `characters/body_skin.gdshader`, `characters/body_cavity.gdshader`, and `assets/shaders/world_surface.gdshader` include it. `band_low` / `band_soft` are shader globals (`project.godot` `[shader_globals]`, pushed by `GameManager`; F3 **Ragdoll / gore**), so skin, hands, bowl, and the world share one value. Gibs and the gun stay smooth.

A custom `light()` that turns the smooth diffuse falloff into two steps. A flat-shaded low-poly face lands wholly in one band, so the shadow edge follows the facets. Every lit shader below includes it, so the whole frame shares one lighting model.

`assets/shaders/toon_light.gdshaderinc`:

```glsl
// Two-step diffuse shared by every lit surface. A flat-shaded low-poly face lands wholly
// in one band, so the terminator follows the facets.
// Declared in project.godot [shader_globals]; GameManager pushes F3 `band_low` / `band_soft`,
// so skin, hands, cavity, and the world share one value.
global uniform float band_soft;
// Share of the light the first band lets through.
global uniform float band_low;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_soft, ndl) * band_low
			+ smoothstep(0.5, 0.5 + band_soft, ndl) * (1.0 - band_low);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
```

- **Watch:** it drops specular, which suits the matte look. A surface that still uses `StandardMaterial3D` (gibs, the dropped gun) keeps smooth light and sits a little out of place beside the banded world.

### 3. Skin edge light and hit flash

**Shipped.** Owner: `characters/body_skin.gdshader`, `DummyBody.flash()` / `_apply_edge()` (`characters/dummy_body.gd`), `TimeOfDay.set_edge` (`scenarios/time_of_day.gd`).

Two additions to `characters/body_skin.gdshader`. The edge light brightens the silhouette where the surface turns away from the eye, which keeps a grey mannequin readable against orange fog at 22 m. `flash` blinks the body white on a hit.

```glsl
// Declared in project.godot [shader_globals]; TimeOfDay.set_edge writes it.
global uniform vec4 edge_light : source_color;
uniform float edge_power = 3.0;
uniform float edge_strength = 0.35;
// 1 on the hit frame, tweened to 0.
uniform float flash = 0.0;

	// ...end of fragment(), after ROUGHNESS:
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_power);
	EMISSION = edge_light.rgb * rim * edge_strength + vec3(flash);
```

- **Wire:** `DummyBody.flash(clip_t)` sets the skin's `flash` to 1 and tweens it to 0 over `FLASH_TIME` (0.1 s, real time). It runs on every accepted hit, kills included, whether or not the hit cut a hole: `DuelistAI` and `Player.take_bullet_hit` in a solo duel, `DuelManager._mp_chunk` on every peer in a lobby (the RPC goes out with bone -1 for an empty cut).
- **Replay:** `flash` logs `clip_t`; `chunks_replay_begin` / `chunks_replay_at` re-fire each logged hit inside the clip. `reset_chunks` clears the log.
- **Sun color:** `edge_light` is one global. `ScenarioBase._ready` sets it to the authored Sun's color (the warm default `TimeOfDay.EDGE_DEFAULT` where there is no Sun, as in the Saloon); `TimeOfDay.apply` follows the time-of-day sun.
- **Tuning:** F3 `edge_strength` and `edge_power` (`GameManager.tuning`); no Settings row.
- **Hands:** they use a copy of the skin material with `edge_strength` 0 and are never flashed. The hit-hole bowl (`body_cavity.gdshader`) keeps no rim and does not flash, so a hole reads dark for the 0.1 s blink.
- **Test:** `chunks`, `ragdoll`. Headless does not compile shaders, so these cover the wiring; the look needs a flat run and a headset.

### 4. Bullet trail

**Shipped.** Owner: `weapons/bullet_trail.gdshader`, `BulletTrail` (`weapons/bullet_trail.gd`). The game's shader differs from the sketch below: `blend_premul_alpha` with a `solid` uniform (0 additive, 1 alpha mix) that `TimeOfDay` sets per sample (`trail_solid`), width 0.035 m from F3 `trail_width`, F3 `trail_tail_share`.

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
- **Shipped:** the shader is the one above, used as written. Decisions: cover is rolled once per load in 0.25–0.5; the tint is the keyframe `light_color` 40% toward white; the clouds drift at `cloud_speed` 0.01 deck units/s in a random direction per load (local only), which makes the engine re-render the radiance cubemap each frame, so measure it on the Quest. Fallback ladder if it costs too much: lower `Sky.radiance_size` and use realtime processing, then `cloud_speed = 0` on Quest only. `scenarios/sky_clouds.tres` is an external resource on purpose, so `ScenarioBase._detach_environment`'s `duplicate(true)` shares it instead of regenerating the noise. F3 **Sky** has `cloud_cover`, `cloud_speed`, `sun_radius`.

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

- **Wire:** `muzzle_smoke.tscn`, `world_dust.tscn`, `barrel_smoke.tscn`, and `engine_smoke.tscn` swap the `SphereMesh` draw pass for a `QuadMesh` of size 1 with this material, so the process material's `scale_min`/`scale_max` is the puff diameter in metres. A `scale_curve` takes it from 0.6 to 1.0 of that size over life, and `angle_min`/`angle_max` 0–360 vary `spin`. `engine_smoke.tscn` is the looping one: world-space, no shadow, `preprocess` = `lifetime`. Leave the chip, shard, and coin cues as meshes.
- **Warmup:** covered. `VfxCatalog.spawn_for_compile` draws every cue.
- **Shipped:** the shader is the one above, used as written. Diameters in metres: muzzle smoke 0.06–0.12, world dust 0.04–0.08, barrel wisp 0.06–0.14, each on the 0.6 → 1.0 curve; `lumps` and `lump_depth` keep their defaults. The VR fallback below is not wired; the Quest look is on `RELEASE_TODOS`.
- **Watch:** the dither is fixed to each eye's pixels, so the two eyes get unrelated patterns. In a headset that can read as sparkle. This is the one shader here most likely to need a VR fallback: if it sparkles, keep the lumpy shape and write `ALPHA = density` in place of the `discard`.

### 7. Outline

**Shipped.** Owner: `characters/body_outline.gdshader`, wired in `DummyBody._make_part` / `_apply_material` / `_apply_outline` and `BodyChunks` (`outline_material_new`, `_refresh`, `spawn_for_compile`). The weld and the `Outline` child live in `characters/outline_hull.gd`, shared with the held objects below.

An inverted hull: each part drawn a second time, back faces only, pushed out along the normal, in ink. It is the closest thing to manga line art that needs no screen read.

`characters/body_outline.gdshader`:

```glsl
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
```

- **Wire:** not `material_overlay`. `dummy.glb` is flat-shaded: 824 of its 983 distinct positions carry differing normals, so a hull pushed along `NORMAL` cracks open at almost every edge. `OutlineHull.weld` builds a copy of each part mesh (body, head, hands) with the normals summed across coincident positions (quantized to 0.1 mm) and normalized, once per process beside the `intact` parts. `_make_part` adds it as an `Outline` child of the part, on the same skin and skeleton, shadows off, same layers; the child follows its part's visibility (shelved body, hidden head) and `set_body_render_layers` sets its layer. The skin's `next_pass` stays the cavity.
- **Materials:** body and head share one ink material (`clip_radius` is the skin's, `FP_CLIP_RADIUS` on the local first-person body); the hands wear their own with `hole_count` 0 and no clip. `BodyChunks._refresh` pushes `holes` / `hole_count` to the body ink next to the skin, so the hull is discarded inside each hit hole. No `flash` (the ink stays dark on a hit) and no `fog_disabled` (the hull is fogged like the skin).
- **Tuning:** F3 **Ragdoll / gore** `outline_enabled` (0 hides every outline child) and `outline_width` (default 0.004, up to 0.02). Always on otherwise: no Settings row.
- **Warmup:** the probe in `BodyChunks.spawn_for_compile` carries an `Outline` child with the hole set, so the hull compiles with the hole branch.
- **Watch:** a hole's rim shows a line beyond the discard sphere only as far as the hull has been pushed out (about 5 cm at 14 m); grazing angles and the hands at arm's length are the places to check. Gibs and the dropped gun get no line.
- **Test:** `chunks` (outline children, weld, holes on the ink, knobs, clip, warmup probe), `ragdoll` (children ride the corpse). Headless does not compile the shader: the look is on `RELEASE_TODOS`.
- **Held objects (decided 2026-10-18):** the revolver, the four offhand props, the practice bottle, and casings and cartridges wear the same shader and ink through `OutlineHull.attach_model`. Unskinned, so no skeleton; `hole_count` and `clip_radius` stay 0. Two shared materials, one for gun and props, one for brass, each `width` from F3 `object_outline_width` (0.0015, about a third of the body's), `near` 0.3, `far` 6 for hand range. The vertex step is in model space and every one of these GLBs is scale 1 (checked in the glTF nodes), so the width needs no compensation. The weld handles every surface merged (the cigarette has two) and drops UVs and vertex colours (the blaster carries `COLOR_0` / `COLOR_1`). Intact bottle only: `shatter` hides the model and its line goes with it, the `glass_shatter` particles stay plain. Brass: newest 12 pieces within 6 m, bullets skipped. Always on; F3 `outline_enabled` hides these lines too. Perf fallback if Quest 3 shows a cost: trim ammo, then offhand props, then the gun, by constants or F3 only.
- **Watch (objects):** the hull on a hand-held prop may clip the camera near plane at the close grip; coin and cigarette may read as a solid blob at 0.0015; the PSX blaster's atlas-split faces may show seams. A matcap on the revolver (section 9) would share the blaster mesh with its hull: the hull is a child, so the matcap goes on the host's material and this line stays on the child.
- **Warmup (objects):** `BodyChunks.spawn_for_compile` adds one unskinned probe with an `Outline` child on the gun material.
- **Test (objects):** `load` (`_object_outline_ok`, `_ammo_outline_ok`: children, shader, welded vertex counts, the drum under `CylinderPivot`, the 12-line cap and the 6 m range), `props` (the remote avatar's coin has its line), `chunks` (`object_outline_width` and `outline_enabled` push-and-restore, the object warmup probe).

### 8. World surface

**Shipped.** Owner: `assets/shaders/world_surface.gdshader`, `assets/shaders/world_surface_import.gd`, `assets/shaders/world_grain.tres`, `ScenarioBase._push_wind` / `_pulse_wind`. One shader for every static scenario surface (29 scenario GLBs). It keeps each material's flat color, lights it with the bands, and adds one grain lookup projected along the face's dominant axis, so a flat-color wall or a sand plain gets texture without painted art. A surface whose GLB carries a hand-painted image (`tex/<glb>.png`, 256×256, one per GLB) shows it in place of the flat color; with no image it keeps the flat color. The self-lit names (`M_Flame`, `M_LampGlass`: the Saloon chandelier's flames and glass) draw exactly their color, unlit, and cast no shadow. The shared trim sheet (`assets/textures/trim_sheet.png`) is paused behind `USE_TRIM_SHEET` in the import script. Wind bends plants and hay and swings signs and awnings.

`assets/shaders/world_surface.gdshader`:

```glsl
shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/toon_light.gdshaderinc"

global uniform float grain_strength_mult;
global uniform float grain_scale_mult;
global uniform float sheet_mix;          // 1: the trim sheet is the albedo, 0: the flat color (sheet paused: no effect)
global uniform float wind_ambient;
global uniform float wind_gust;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness_amount = 1.0;
uniform sampler2D grain_tex : filter_nearest, repeat_enable, hint_default_white;
uniform sampler2D sheet_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform bool use_sheet = false;          // paused: the importer's USE_TRIM_SHEET switch is off
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_disable, hint_default_white;
uniform bool use_albedo_tex = false;     // set by the importer: the glTF material has a base color image
uniform bool self_lit = false;           // set by the importer on M_Flame / M_LampGlass: unlit, exactly its color
uniform float grain_scale = 0.35;        // tiles per metre
uniform float grain_strength = 0.0;
uniform float grain_fade_near = 15.0;    // grain fades to 0 between these view distances
uniform float grain_fade_far = 45.0;
uniform bool grain_local = true;         // model space, so a moving piece carries its grain
uniform float sway_amount = 0.0;         // bend in metres at full wind (plants, hay)
uniform float sway_speed = 1.3;
uniform float sway_height = 1.0;
uniform float hinge_amount = 0.0;        // radians at full wind (signs, awnings)
uniform vec3 hinge_origin = vec3(0.0);
uniform vec3 hinge_axis = vec3(1.0, 0.0, 0.0);

varying vec3 grain_pos;
varying vec3 grain_normal;
varying float view_dist;

void vertex() {
	// grain_pos / grain_normal from VERTEX / NORMAL (grain_local) or the world transform.
	// wind = wind_ambient + wind_gust; swing = two sines keyed off MODEL_MATRIX[3] * wind.
	// sway_amount: VERTEX.x += swing * sway_amount * bend^2, bend = clamp(VERTEX.y / sway_height).
	// hinge_amount: rotate VERTEX and NORMAL about hinge_axis through hinge_origin by swing * hinge_amount.
	// view_dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z
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
	ROUGHNESS = roughness_amount;
	if (self_lit) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = base;
	} else {
		ALBEDO = base * (1.0 + grain * 2.0 * grain_strength * grain_strength_mult * fade * flat_k);
	}
}
```

The `vertex()` body is abbreviated above; the file is the source of truth.

- **Deviations from the sketch:** `cull_disabled`, not `cull_back` (every GLB material is `doubleSided`, and thin plants, awnings, and signs are single slabs that would vanish). `grain_local` defaults to true on every imported material, so the belt needs no code. The painted image is read by `UV` only where `use_albedo_tex` is set. A GLB embeds an image only when its `tex/<glb>.png` exists (otherwise every material is `baseColorFactor` plus roughness); the importer reads it from the glTF material. The shared sheet path (`use_sheet`) is paused. No metal and no specular, so iron, brass, boiler, and mirror render as lit albedo, lighter and matte. Grain strength and scale take the globals `grain_strength_mult` / `grain_scale_mult` (F3 **World**) and fade to 0 between 15 m and 45 m (`grain_fade_near` / `grain_fade_far`) so far ground does not shimmer under nearest sampling. `band_low` / `band_soft` are globals. Wind comes from the globals `wind_ambient` (0.3 x the arena's `gust_strength` x `sway_scale`, 0 where the arena has no wind) and `wind_gust` (a 1.8 s pulse per gust, the length of the dust sweep); bend amplitude is `sway_amount * (wind_ambient + wind_gust)`.
- **Self-lit path:** `self_lit` writes `ALBEDO` 0 and `EMISSION` = the base color (the flat color, or the painted texel when `use_albedo_tex` is set), with no grain. Every light term in `toon_light.gdshaderinc`, the ambient, and the shadowed chandelier's extra pass multiply the albedo, so they add nothing; `SPECULAR` 0 drops the environment's specular term. Under the scenes' linear tonemap (exposure 1, no glow or adjustments) the pixel is the material's sRGB color exactly, fog aside. Checked in a flat Saloon run (Compatibility, Godot 4.7): a quad wearing each imported material, outside every light's range, read #FFD966 (255, 217, 102) for `M_Flame` and #FFF0C8 (255, 240, 200) for `M_LampGlass`, and the chandelier's south shade read (255, 240, 200) on the screen, against (94, 82, 63) with `self_lit` switched off. It casts no light: the `Chandelier` OmniLight3D does the lighting (decision F27 in `docs/design/scenarios/saloon.md`).
- **Hinge path:** a sign or awning is a rigid slab in building space, where bending by `VERTEX.y` does nothing useful. The import script gives the four nodes `Sign`, `PorchSign` (about the top edge, along the board's long axis), `Canopy`, and `ShedAwning` (about the wall-side edge, along the wall) their own material with `hinge_origin` / `hinge_axis` from the mesh box and `hinge_amount` 0.035 rad (about 2 degrees; up to 3 degrees at the sine peaks). The wall side is a per-node table in the script, not a centroid test: the awning post's beam runs from the post to the wall, so the nearest box edge to the module's centroid is the wrong one.
- **Import:** `world_surface_import.gd` is `import_script/path` in each scenario `.glb.import`. Godot 4.7 runs it on a scene that already holds `MeshInstance3D`s, so it swaps materials on the `ArrayMesh` (`ImporterMeshInstance3D` is gone by then). The color and roughness come from each GLB's own material, because `M_Wood` and the other names repeat across GLBs with different colors. Grain by name: sand, dirt, rock, and cap 0.2; wood, plank, roof, car, floor, bar, trim, masonry, and whitewash 0.12; everything else (metals, glass, cloth, hide, cacti, scrub, hay) 0. Sway: `M_Yucca`, `M_Scrub`, `M_ScrubDry`, `M_Hay` at 0.03 m, `sway_height` the mesh height in 10 cm steps; cacti stay rigid. Each GLB owns copies of its materials named `<base>__<glb>` (`M_Wood__bld_bank`); the importer drops the suffix (`get_slice("__", 0)`) before every name lookup (grain, sway, tiling), and ground and rock keep their shared names. A material with a vertex color, normal map, emission, or transparency is skipped with `push_warning`; none exist (glow comes from the name, never from glTF emission). Self-lit by name (`SELF_LIT`): `M_Flame` and `M_LampGlass` get `self_lit` and grain 0, and a `MeshInstance3D` whose surfaces are all self-lit gets `cast_shadow` off (each glowing material is its own mesh, rule 26). A material whose glTF base color has an image (a painted GLB) gets `use_albedo_tex` and `albedo_tex` (the image re-built with a mip chain), with grain off and sway kept. With `USE_TRIM_SHEET` true, a surface whose mesh has UVs and whose material is not tiling (`M_Sand`, `M_SandFar`, `M_Dirt`, `M_DirtFar`, `M_Rock`, `M_RockDark`, `M_Cap`, `M_CapDark`) would get `use_sheet` and `sheet_tex` instead; it is false now because the strip UVs were replaced. Surfaces with the same color, roughness, grain, sway, sheet flag, and image share one material. After changing the script or a `.import`, reimport: `godot --headless --path . --import` (the editor does it on focus; a stale `.godot/` shows as a `StandardMaterial3D` failure in `load`).
- **Grain texture:** `assets/shaders/world_grain.tres`, a 128 px seamless value-noise `NoiseTexture2D` (frequency 0.15). External on purpose, like `sky_clouds.tres`, so `ScenarioBase._detach_environment`'s `duplicate(true)` shares it.
- **Train Rooftop belt:** `grain_local` is on everywhere, and the belt takes only cactus plants (rigid), so nothing slides or sways.
- **Trim sheet (paused):** nothing in game uses the sheet while `USE_TRIM_SHEET` is false, so `sheet_mix` has no effect. The text below is how it works when switched back on. `sheet_mix` replaces the Base Color with the sheet on sheet surfaces (decision 2 in [`TEXTURING.md`](TEXTURING.md)) and scales grain by `1 - sheet_mix`; 0 is the old look exactly. No distance fade: mipmaps only (`trim_sheet.png.import`: Lossless, mipmaps on, `detect_3d/compress_to=0`), the sheet builder (`dev/build_trim_sheet.py`) repeats each cell's outer 4 px and each strip's top and bottom 4 rows so far mips do not bleed a neighbour. The sheet is 512×1024. One extra texture read per sheet fragment; not timed on a Quest yet.
- **Tuning:** F3 **World** `grain_strength_mult`, `grain_scale_mult`, `sheet_mix` (no effect while the sheet is paused), `sway_scale`; `band_low` / `band_soft` stay in **Ragdoll / gore** and now move the whole frame. Persisted with the rest of `GameManager.tuning`.
- **Test:** `load` asserts every scenario surface wears the shader (the five scenes, belt pieces included), `grain_local`, sway only on plants and hay, hinge only on the four slabs, `use_sheet` and `sheet_tex` exactly where the mesh has UVs and the material is not tiling while `USE_TRIM_SHEET` is on (none while it is off), and a `use_albedo_tex` surface has UVs, an `albedo_tex`, no sheet, and a non-tiling material (zero are fine until a PNG exists), `self_lit` exactly on the importer's `SELF_LIT` names (which must be `M_Flame` and `M_LampGlass`; at least one surface, the Saloon chandelier's two) and `cast_shadow` off exactly on the meshes whose surfaces are all self-lit, bare collision proxies, and the wind globals (0 in the Saloon, following `gust_strength` and `sway_scale` elsewhere). Headless does not compile shaders; a flat run of Canyon, Main Street, the practice hub, Train Rooftop, and the Saloon compiled and drew with no errors. Not yet seen in a headset or on a Quest (`RELEASE_TODOS`).

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

**Shipped.** Owner: `ScreenOverlay` (`autoload/screen_overlay.gd`), `ui/screen_overlay.gdshader` (the shader below, verbatim). One quad follows the current camera instead of one per camera, `render_priority` 100. The iris is wired to `KillCam`; the vignette to `Player._apply_nonfatal` and `play_death_feedback`; both are gated by Settings **Screen effects** and tuned by F3 `hurt_limb` / `hurt_torso` / `hurt_kill` / `iris_time`. The iris radius is tweened with a quadratic ease (`TRANS_QUAD`) so it spends its 0.3 s inside the visible field rather than out at 4. Not yet drawn in a headset (`RELEASE_TODOS`).

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

### 11. Spin effect

**Built; look and Quest cost not yet checked.** Owner: `weapons/spin_fx.gdshader`, `SpinFx` (`weapons/spin_fx.gd`, a child node of `weapons/revolver/revolver.tscn`). Roadmap 2.1 (done). Blur and Lines were built as two candidates and are now drawn together in one pass; F3 `spin_fx_mode` is 0 Off / 1 On (default On).

One static 0.5 m `QuadMesh` in the plane the blaster turns in (normal along the gun's X), centred on `SpinPivot`. It never rebuilds a mesh and has no ribbon side vector to flip. The script hides it unless `spin_fx_mode` is not 0, the gun `is_twirling()`, and the visual turn rate (`twirl_speed`) is at least 4 rad/s; it reaches full strength at 14 rad/s. The shader reads polar coordinates of the quad UV: `head_angle` is the barrel tip (the gun's `twirl_angle` plus the rest angle of `Muzzle` from the pivot), `omega` is the signed visual rate, and the trail sits behind the head for `omega x window` radians (capped under one turn).

- **Smear:** a pale wedge that fades from the head toward its tail, weighted toward the barrel-tip radius and cut off inside the drum and outside the muzzle. `unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled`, as in `bullet_trail.gdshader`.
- **Ink arcs:** three concentric unbroken strokes (the outline ink `0.07, 0.05, 0.04`) drawn over the smear. Width and opacity taper to a point at the tail, and the edge is pixel-aware (`fwidth`, never under ~0.75 px). The first version used dashes and a fixed-width edge: the dash gaps sat at the same angles on every ring and read as holes, and sub-pixel strokes shimmered. The loop is a fixed three iterations.
- **Compatibility:** no screen or depth read, no unbounded loop, one transparent quad.
- **Warmup:** `ImpactFeedback._spawn_draw_warmup` draws a quad on `SpinFx.make_material()`; headless skips it.
- **Watch:** the plane is edge-on to a flat first-person camera that sits level with the gun, so the effect may read thin there. Judge it in a flat run in the practice hub, then a headset. Measure Quest 3 frame time with the effect on and off.

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
7. **World surface swap:** at import. Shipped.
8. **Flat mode:** same look as VR. No flat-only pass.
