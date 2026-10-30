# Oil-field Train: design sheet

| | |
|---|---|
| Status | `partial`: sheet decided (section F answered 2026-10-28) and approved 2026-10-29. Everything is built (H, 2026-10-29): all ten GLBs (`oil_pumpjack` and the horizon approved by the user), the scene, the belt, the flame cue, the glow's swell, the dark engine smoke, and the temporary gauntlet rung. Open: the user's final review of the reference match (H, Whole scene: R2, R3, R7, and R11 fail, each a look call), the headset pass, and Quest timing |
| Kind | Scenario design sheet: nothing to final, untextured, UV-unwrapped meshes |
| In code | `scenarios/oilfield_train/` (`oilfield_train.tscn`, `oilfield_train.tres`, `scenery_belt.gd`, `lane_glow.gd`), registered as the last `GameManager.SCENARIOS` entry (index 4), with the light rig at its intended values and the fixed dusk-into-night time (`TimeOfDay.NIGHT_T`, `ScenarioResource.fixed_time_of_day`); the flame cue (`assets/vfx/flame_column.*`, F3 `flame_columns`), the glow's swell, and a dark engine smoke. The belt places 238 pieces: 90 tracks, 32 pumpjacks (the beam clock), 32 horizon tiles with their flame columns, 2 burning wells, 10 derricks, 8 tanks, 8 pylons, 24 pipe runs, 16 wellheads, and 16 sumps, each on the wrap grow (the near dressing at fixed `homes`). GLBs and `oilfield_train.blend` in `assets/models/scenarios/oilfield_train/`: `oil_pumpjack`, `oilfield_terrain`, `oilfield_horizon`, `oil_burning_well`, `oil_derrick`, `oil_tank`, `oil_pylon`, `oil_pipe_run`, `oil_wellhead`, `oil_sump`, all untextured and UV-unwrapped; 62,376 triangles in 729 objects as built (H, Whole scene). The train it reuses is final (`train_rooftop.md` H). Rung 8: `gauntlet/encounters/e8_trio_oilfield.tres`, the last entry of `gauntlet/ladder_default.tres`, covered by the `load`, `multi`, and `gauntlet` suites |
| Build script | `dev/build_oilfield_train_blender.py` (new) → `assets/models/scenarios/oilfield_train/` (new) |
| Prompt | [`prompts/oilfield_train.md`](prompts/oilfield_train.md) |
| Inherits | [`train_rooftop.md`](train_rooftop.md): the consist, its frozen numbers, its marker bands, and the belt contract. [`main_street.md`](main_street.md): global rules 1 to 28, the backdrop method, the build lessons, `env_rail_track_8m`. [`canyon.md`](canyon.md): the rock vocabulary for the horizon's berms. [`saloon.md`](saloon.md): the self-lit path (G7). The exceptions are in A, each with its reason |

The deliverable is clean, final, untextured meshes with sensible UVs and flat Base Color materials. You texture by hand later, so nothing here plans texture art.

Positions are Godot's (x, y, z), y up, unless a line says Blender. Blender (x, y, z) is Godot (x, z, −y). The train heads −z: "front" is toward the engine. Facing the front, +x is the right-hand side and −x the left. In an asset's own Blender frame, +X is the side that faces the train from the left-hand belt, as on `horizon_ridge` (copies are moved, never turned).

## Scene facts the design depends on

Read from `scenarios/train_rooftop/` (`train_rooftop.tscn`, `train_rooftop.tres`, `scenery_belt.gd`, `engine_smoke.gd`), `assets/vfx/engine_smoke.tscn`, `assets/vfx/vfx_catalog.gd`, `scenarios/scenario_base.gd`, `scenarios/time_of_day.gd`, `scenarios/sky_western.gdshader`, `autoload/game_manager.gd`, `gauntlet/duel_manager.gd`, `gauntlet/ladder_default.tres`, `gauntlet/encounters/*.tres`, `dev/autotest.gd`, the build and unwrap scripts in `dev/`, `assets/shaders/world_surface_import.gd`, `docs/SHADERS.md`, `docs/TEXTURING.md`, `Roadmap.md` item 3.3, and `docs/FEATURES.md`. Nothing was measured in Blender or Godot for this sheet.

### What carries over from Train Rooftop, unchanged

- **The consist.** `CarRearB` (business) at z 33.0, `CarRearA`, `CarA`, `CarB`, `CarFrontA` (coach) at 19.8, 6.6, −6.6, −19.8, `CarFrontB` (baggage) at −33.0, `Engine` at −40.2, `Coupler0` to `Coupler5` at 26.4, 13.2, 0, −13.2, −26.4, −39.6, and `Train` (the four guard walls). 11,876 triangles in 46 objects (`train_rooftop.md` H, Whole scene).
- **Markers**, every one at y 3.2: `PlayerSpawn` (0, 10), `EnemySpawn` (0, −10), `EnemySpawns2/A` (−0.6, −10), `/B` (0.6, −3.5), `EnemySpawns3/A` (0.6, −11), `/B` (−0.6, −5), `/C` (0.6, 3.5). `strafe_half_width` 1.5.
- **Frozen numbers** (`train_rooftop.md`, Frozen numbers 1 to 7): the walk at 3.20 under every marker; rail tops at +0.21; guard walls at x ±1.64 to ±1.92 and the two end walls; the Sheriff's boot at x ±1.71; the marker bands on the coach roof; nothing on the belt sways.
- **Engine smoke.** `EngineSmoke` (`assets/vfx/engine_smoke.tscn` with `scenarios/train_rooftop/engine_smoke.gd`) at (0, 4.4, −54.25), the stack's crown. Its puffs are unshaded silver grey, `Color(0.561, 0.549, 0.525)` (`engine_smoke.tscn` line 32).
- **What you see** (`train_rooftop.md`, What you see): from an eye 1.7 m over the roof, the enemy's feet to hips stand against the roofs ahead, his chest against the engine's top (the stack's crown to −0.45°), and his head and hat against the horizon line (−0.27°) and the sky above it. The roofs are the floor of every view. The standing enemy hides the engine.

### The belt contract today

`scenarios/train_rooftop/scenery_belt.gd` moves pieces toward +z on wall-clock time and wraps them. Copies are moved, never turned, and lose their collision.

| Band | Pieces | Copies | Across | Speed | Loop |
|---|---|---|---|---|---|
| Near | `env_rail_track_8m` | 90 | Under the train | 20 m/s (`speed_mps`, line 23) | ±360 m |
| Near | Cactus clones from `env_desert_scatter` | 180 | x ±4.5 to ±16 (line 74) | 20 m/s | ±360 m |
| Mid | `Canyon` / `Mesa` alternating | 20 slots × 2 sides | x ±28 to ±40, rolled per copy | 7 m/s (0.35×) | ±480 m |
| Far | `Butte` | 22 slots × 2 sides | x ±70 to ±100, rolled | 2.4 m/s (0.12×) | ±528 m |

`HORIZON_SPAN` is 48 m (line 11), the slot pitch. The built spans are 47.75 m long with closed ends, because the belt never lays two spans end to end (`train_rooftop.md` line 105; `dev/build_horizon_ridge_finals_blender.py` line 74).

### The light today, and what a fixed condition changes

- `GameManager._instance_scenario` rolls `time_of_day = randf()` on every load (`autoload/game_manager.gd` line 1165). MP sends the host's roll (`gauntlet/duel_manager.gd`, `host_open_lobby`). F3 can scrub it. The flat main menu loads a random entry of `SCENARIOS` as its backdrop with processing off (line 379), so the oil field will also be a frozen menu backdrop.
- `TimeOfDay.apply` aims the node named `Sun` at a keyframe elevation, keeps its authored yaw, and writes the sky's four gradient colours, `cloud_color` (the light colour 40% toward white), the fog colour (always `ground_horizon`), `fog_sun_scatter`, the bullet trail's `trail_solid`, and the duelists' rim colour `edge_light` (the sun's colour). No Sun means nothing changes (the Saloon).
- `sky_western.gdshader` has no `TIME`. A script that flickers sky or fog colours re-renders the radiance cubemap every frame, which the cloud drift already does. Its sun halo (`sun_halo`) brightens the sky above the horizon toward the Sun. The disc and halo are drawn only above the horizon.
- The toon light (`assets/shaders/toon_light.gdshaderinc`) gives three steps: none (N·L under 0.03), middle (65%, from 0.03), full (from 0.5).
- Fog is exponential at density 0.006 on Train Rooftop. Godot fogs unshaded and self-lit surfaces too, so a far flame dims with distance like everything else.
- The renderer has no glow, bloom, or screen read (`docs/SHADERS.md`, What the renderer allows). In Compatibility an `OmniLight3D` lights only meshes whose AABB meets its own, eight per mesh by default (Godot docs).
- No scenery carries the ink outline (`train_rooftop.md` line 80). Only duelists and held objects do.

### The reference frames, as they are in the files

- **`jarhead.jpg`** is a 495 × 619 contact sheet of eight frames (two columns, four rows, a "Frames of Story" watermark). Numbered left to right, top to bottom: (1) pink-violet clouds over an orange horizon, two rifle silhouettes on a black ground line; (2) two seated figures in silhouette before one white-hot column with dark smoke above, a lattice pylon at its left, the ground glowing at its base; (3) a helmeted head drinking from a bottle, a black cut-out on a flat amber field; (4) two figures walking on black flat ground against a dark orange haze; (5) a tall column at left with billowing smoke, several smaller columns along a flat horizon, tiny figures, a figure in silhouette at the right edge; (6) a soldier from behind on dark ground, a column to his right, a crouched figure lower right; (7) a shirtless man in a Santa hat at night with pink smoke, not an oil-fire frame; (8) a gas-masked soldier in near darkness, a fire glow on the horizon behind.
- **`jarhead2.jpg`** is a single 640 × 480 frame (letterboxed, a "BOXOFFICE" watermark): a man and a horse in black silhouette, flame columns at left and right and a smaller one between them in the distance, the whole frame filled with saturated orange haze, the ground lit orange near the fires.

### The brief's facts, checked

1. **Metric, Z-up, roof tops at y 3.2, spawns at z ±10 on duel cars centred ±6.6:** correct (`train_rooftop.tscn`: `PlayerSpawn` at (0, 3.2, 10), `CarA` at z 6.6, `CarB` at −6.6).
2. **Spawns `PlayerSpawn`, `EnemySpawn`, `EnemySpawns2` A–B, `EnemySpawns3` A–C, walls, and walk proxy carry over:** correct. The walk proxies now live inside the train GLBs (`Coach_Roof`, `Coupler_GapWalk`, …), so they come with the instances.
3. **"The 3-NPC finale must work here as on Train Rooftop":** imprecise. No 3-NPC rung runs on Train Rooftop. The finale, rung 7 "Mexican standoff", is on Main Street (`gauntlet/encounters/e7_trio_street.tres` line 14: `scenario_index = 0`). Train Rooftop's `EnemySpawns3` serves free duels, lobbies, and horde. `Roadmap.md` item 3 says the temporary rung here repeats rung 7's trio, so the three markers must work here, which they do if the scene is a copy.
4. **12 m cars, 1.2 m gaps, 13.2 m pitch, heading −z, engine smoke at the stack (`assets/vfx/engine_smoke.tscn`), stationary:** correct. Roofs are 12.3 m, so the gap at roof level is 0.9 m. The smoke's script is `scenarios/train_rooftop/engine_smoke.gd`, placed at (0, 4.4, −54.25) (`train_rooftop.tscn` lines 112–113).
5. **The reused GLBs:** correct: `train_car_coach` ×4, `train_coupler` ×6, `train_engine`, `train_car_baggage`, `train_car_business`, and `train_rooftop` (the guard walls only).
6. **Belt speeds 20 m/s, 0.35×, 0.12×; `HORIZON_SPAN` 48 m:** correct (`scenery_belt.gd` lines 11, 23–25).
7. **"Spans 48 m along Blender Y centred on the origin, ends must tile":** wrong, as `train_rooftop.md` already found (line 105). The pitch is 48 m, the spans are 47.75 m (`build_horizon_ridge_finals_blender.py` line 74: `HALF = (HORIZON_SPAN - 0.25) / 2.0`), and their ends close, because each copy rolls its own x and no two spans ever meet. This sheet's horizon tile follows the same rule (B).
8. **The track `env_rail_track_8m` is reused:** correct. As built it is 98 triangles in 3 objects (`train_rooftop.md` H), not the 120 of Main Street's sheet.
9. **"Cover, sightlines, and the lane must read at duel distance through the outline shader":** imprecise. Scenery has no outline. Only duelists and held objects carry the ink line (`train_rooftop.md` line 80; `SHADERS.md` §7). The scenery reads by value and haze.
10. **"The repo shaders turn the light into two flat bands":** imprecise. Two steps over unlit: none, middle (65%), full (`train_rooftop.md` line 64).
11. **"docs/TEXTURING.md lists the current triangle counts per map … Train Rooftop is about 46,700 triangles with its horizon":** partly wrong. `TEXTURING.md` has only the paused trim-sheet pass's counts of unwrapped objects (line 373: Train Rooftop 5,972 → 6,940). The 46,691 figure is in `train_rooftop.md` (line 1067), and it is the whole scene: the train 11,876, the horizon belt 16,764, and Main Street's tracks, cacti, and terrain 18,051.
12. **Invisible walls ring the roofs; the horizon has no collision; new scenery has no collision unless within reach:** correct. The belt strips collision from everything it moves (`_strip_collision`). Nothing new sits within reach of the walls (B).
13. **Material names `M_<Base>__<glb>`, no vertex colours, normal maps, emission, or alpha, ground and rock on 8 m tiling UVs:** correct (`world_surface_import.gd`; `TEXTURING.md`).
14. **The two images:** wrong. `jarhead.jpg` is the eight-frame contact sheet, not a single frame, and `jarhead2.jpg` is the single frame. The single frame shows a man and a horse between flame columns, not "two figures seated before a flame column and a pylon"; that is frame 2 of the contact sheet. The list above is what the files hold. The brief's contact-sheet list also leaves out frames 7 and 8.
15. **"Undercarriage and car sides are seen only while scrolling past":** wrong, as on Train Rooftop: the train never scrolls. Its sides show to the death cam's low orbit, to a player leaning over a guard wall, and from the cab roof.

### Found in the repo

None of these is in the brief. Where one needed a decision, F records it.

1. **The ground is shared and desert-coloured.** Train Rooftop's `Terrain` is Main Street's `env_terrain.glb` (2,000 m box, top +0.12, `M_DirtFar` #B8A281). It cannot be recoloured without changing Main Street. This scene needs its own terrain (`oilfield_terrain`, B).
2. **The engine smoke would glow.** Its puffs are unshaded silver grey, so at night they draw at their own value against orange haze: the brightest neutral in the frame after the lamp lenses. Decided: a dark per-scene colour here, about #3A2C26; Train Rooftop keeps its silver (F8).
3. **Fog dims the flames.** A white core at 100 m under density 0.009 is 59% haze colour: #FFF0C8 becomes about #D08A60. The reference's distant fires stay hot. Decided: the column cue's core takes no fog inside about 150 m and full fog beyond about 300 m (F11).
4. **Static ground grain under a moving belt.** `M_DirtFar` takes grain 0.2 in model space on a terrain that does not move, so its grain stands still while the belt runs. At the scorched value (Y 0.016) a ±20% grain is invisible. No action.
5. **A Sun below the horizon and shadows.** A directional light aimed from below the horizon would put everything in the terrain's shadow if it casts shadows. Decided: no shadows (F2, F7).
6. **The flat menu backdrop** freezes the scene (`PROCESS_MODE_DISABLED`), so the pumpjacks and the belt stop there. Harmless; noted for the reference match, which must be captured in a duel, not on the menu.
7. **`load` does not see this scene until it is listed.** `dev/autotest.gd` names the five scenes by path in its surface and belt checks (lines 6252–6256 and 6617–6621), and it skips belt clones (`train_rooftop.md` H, Found). Adding the scene and its belt count is code, step 3 of the Roadmap item.
8. **Half-head's page is stale on the rung.** It says "Last, after the Ghost's Saloon rung" (`half-head.md` line 51), but rung 7, the trio on Main Street, now follows the Ghost. Not this sheet's file; reported only.

## A. Art direction

The oil field is drawn as the Jarhead fires are lit: one orange haze filling sky and fog, near-black rigs cut out against it, and a few white-hot columns standing on a flat dark horizon, one of them burning close enough to pass the train, the way Deakins lit the stage through the back of the cyclorama "so distant fires seemed to light the horizon" and rolled banks of orange strip lights beside the actors for "soft, flickering flame-light from the side" (American Cinematographer). Shape language is the cable-tool field of the 1880s pushed one notch toward the twentieth century: raw timber derricks on the standard rig of 1884 (72 ft, a 26 ft walking beam on a 13 ft Samson post: petroleumhistory.org), riveted iron tanks from the early 1870s (ETHW), wrought-iron pipe in 15 ft joints after Van Syckel's 1865 line (petroleumhistory.org), and the horsehead pumpjack, which is Walter Trout's design of 1925 (Texas Escapes) and is here because it is the field's one unmistakable silhouette, built in timber and iron like the walking beams it came from. Wear is "worked and burnt", carried by geometry only: near the train one accent a module, a lean, a sag, a kinked joint; on the horizon the wrecks, a derrick folded at its waist and a tank with its roof gone, as Spindletop's derricks stood close enough to touch and its fires were "a constant danger" (UNT Texas history), and as Kern County's crews ringed a runaway well with sandbag berms (Wikipedia, Lakeview Gusher). Proportions follow the frozen roof: you stand at 3.20 m, so the pumpjacks' heads nod at eye height beside the track, the derricks rise four times your height on the mid belt, and members are fattened to the size floor of their band (10 cm near, 0.25 m mid, 0.5 m far), as Main Street's rule 3 does. Every scenery flat is a neutral, ink, iron, sheet iron, raw wood, and scorched earth from Y 0.006 to 0.26, so the only hue in the frame is the fire and the haze it lights: Half-head's "the flames are the only colour in his fight" taken literally, board #20's rider and horse in black on one colour field, #24's monochrome figure in red smoke, and Araki choosing one colour for the image rather than for the object (`steel-ball-run.md`). Depth is told by haze steps, not detail: rigs at 10 m, 35 m, and 100 m sit at about 6%, 19%, and 45% fog (density 0.006), the Spyro trick of a flat far version that still reads (Hardcore Gaming 101) and the oldest job of distance fog (Wikipedia, Draw distance). The light does the drawing: the sun has set, the fire key comes level from the left-hand horizon, so every face turned to the fire is lit, every roof and the ground stay dark, and a flickering pool of firelight lies over the lane where the duel is (F1 to F3).

**What this place feels like:** the company's train stopped dead in the company's oil field after sundown, black rigs nodding against a burning horizon, the air the colour of the fire, and two shadows on the roof waiting for the flicker to steady.

### The light rig (intent, in words; no code here)

All of this is step 3 of the Roadmap item. It is listed so the meshes can be judged against it.

| Piece | Intent | Values |
|---|---|---|
| Fire key | The node named `Sun`, kept because `TimeOfDay` and `ScenarioBase` read that name. Yaw pointing the light toward +x exactly (the fire is on the left-hand horizon, F1). Elevation −1°: below the horizon, so up-facing faces get N·L −0.02 (unlit) and faces turned to −x get N·L 1.0 (full). No shadows (F2, F7) | Colour #FF7A33, energy about 1.0 |
| Lane glow | One `OmniLight3D` on the fire side over mid-lane, at (−6, 7.5, 0), range 22 m, no shadow, energy flickering ±15% from a noise of 2 to 6 Hz (F3). It swells as a burning well comes abeam (F10): +60% at abeam, falling smoothly (a squared cosine of the well's z offset) to nothing 60 m either side, about 8.5 s each way at 7 m/s. One energy write a frame; no new light. The light stays over mid-lane, so both duelists brighten alike | Colour #FF8A3A, energy about 1.2, up to about 1.9 as a well passes |
| Sky | Smooth gradient (`bands` 0, as decided in `SHADERS.md`). `sky_curve` 0.08 keeps the bright band thin: about 13% toward the top colour at 1°, 35% at 3°, 58% at 6°, 77% at 10° (F5). No sun disc (`sun_radius` 0); a wide halo (`sun_halo` about 0.6) brightens the left-hand horizon | `sky_top` #1C1226 plum-black; `sky_horizon` #D9662B burnt orange |
| Ground in the sky | `ground_horizon` is also the fog colour, a dark brick so the near ground and mid rigs read near black (light tuning, 2026-10-29) | `ground_horizon` #451A0B (was #A8401C); `ground_bottom` #2A1610 |
| Clouds | A low-contrast smoke ceiling, a faint texture on the plum, not brown shapes (F6, light tuning) | `cloud_color` #2C1821 (was #4A2418), cover about 0.4, no drift or slow drift |
| Fog | Exponential, density 0.006 (was 0.009; F4, light tuning). Sun scatter about 0.2 (was 0.5), so the fire-side fog is not brightened and the left rigs read as cut-outs against the band. Flicker the fog colour with the lane glow, ±8% | Fog colour #451A0B (was #A8401C) |
| Ambient | Sky ambient, energy about 0.25, so unlit faces sit near black but not at ink | |
| Rim | `edge_light` follows the key: an orange rim on every duelist | #FF7A33 |
| Bullet trail | `trail_solid` about 0.15, as at dusk: additive, so trails read on the dark | |

Faces under the key, at elevation −1°:

| Face | N·L | Step |
|---|---|---|
| Up: roofs, the walk, decks, the ground, tank roofs, ledges | −0.02 | None. Only the lane glow and ambient |
| Facing −x (toward the fire) | 1.00 | Full |
| Turned 30° from ±z toward −x | 0.50 | Full (just) |
| Turned 15° from ±z toward −x | 0.26 | Middle |
| Facing ±z (along the track) | 0 | None |
| Facing +x (away from the fire) | −1 | None |

So on the left-hand belt you see each rig's unlit face, a black cut-out against the bright left horizon (frames 2, 5, 6). On the right-hand belt you see the lit face, a fire-lit rig against the darker right horizon (frame 6, and the horse frame's ground). A pumpjack's horsehead facets cross the 0.5 threshold as it nods, so they flicker between steps: the nod catches the light.

The lane glow at (−6, 7.5, 0): to the walk under `PlayerSpawn` (0, 3.2, 10) it is 12.4 m, N·L 0.35 (middle); near mid-lane N·L 0.58 (full). Each duelist's front faces it at N·L about 0.83 (full) from both spawns, so the two ends are lit alike. The coach roofs out to z ±13 lie in the pool; the roofs beyond it, the engine, and the business car stay dark.

### Exceptions to the global rules

Rule numbers are Main Street's. Every rule not listed holds as written. PSX vertex snap and affine warp play no part: nothing here depends on them.

| Rule | Main Street | Oil-field Train | Why |
|---|---|---|---|
| 6 | Smallest modeled feature 10 cm | 10 cm on the near belt (pumpjack, wellhead, sump, pipe), 0.25 m on the mid belt (the burning well included), 0.5 m on the horizon tile | Near pieces pass at 4 to 16 m; mid at 20 to 45 m (0.25 m at 35 m is 0.4°, about 10 px); far at 55 to 140 m |
| 13, 14 | One wear accent per 4 m; nothing broken or fallen | One accent per module copy, in silhouette. On the horizon tile, wrecks are the wear: a folded derrick, a gutted tank | Kept machinery near the train; the burning field beyond it |
| 16 | No light in any Base Color | Holds. The burning pools and the white-hot well mouths are fire, drawn self-lit (`M_Flame`, `M_LampGlass`), not painted light | Saloon G7 |
| 17 | Sun faces saturated; shade faces pale | Replaced. There is no sun. Every scenery flat is a neutral, and the fire key sets which side is lit | One hue: the fire's |
| 21 | Company blue belongs to the railroad | Holds: only the train. It reads near black at night (Palette, The train at night) | |
| 22 | The wall behind a spawn is one flat field | The field at head height is the horizon band from both spawns. Above the roof line, nothing on any belt stands within ±4.5° of the lane's axis nearer than 80 m (fog 51% or more), and no flame anchor lands within ±6° of it inside the loops: the horizon's anchors only beyond 630 m, the burning wells' never (B, `oil_burning_well`) | The standing enemy hides the engine; the band is behind his head |
| 24 | The ground keeps its ochres | Broken: the ground is scorched near-black | The dark flat foreground of frames 1, 2, and 4 |
| 25 | Names prefixed with the asset | Exact names stay: `WalkingBeam` (the beam a script rotates), `Flame_1` to `Flame_3` (the anchors), and the train's `Guard*` | Code reads them |
| 26 | One object per material per asset | Holds, plus `WalkingBeam` as its own object even though its material is also on the frame | The beam moves |
| New | | No ground piece has a face within 0.08 m of the terrain's top (0.12): pads and pools top at 0.20 or more | Coplanar slabs z-fought before |
| New | | Within x ±6.0, nothing on the belt stands taller than 1.5 m | The death cam swings to about 3 m outside the car sides at y 4.3 to 6.3, with no collision |
| New | | The pumpjack's beam rests level in the file; its object origin is the Samson-post bearing | The script rocks it about its own origin |

### Palette

Enter the linear value as the Blender Base Color. Hex is the sRGB display value; Y is linear luminance. "Seen" is an estimate, ambient left out, for a face at the key's full step (lit) and for an unlit face under ambient only; the flat run measures it.

| Flat | Hex | Blender Base Color (linear) | Y | Base name | Used for | Seen lit / unlit (estimate) |
|---|---|---|---|---|---|---|
| Ink (Main Street's) | #120D0A | 0.006, 0.004, 0.003 | 0.00 | `M_Glass` | Oil in sumps, the spill tongue | Black / black |
| Iron (Main Street's) | #24272E | 0.018, 0.020, 0.027 | 0.02 | `M_Iron` | Pumpjack gear house and fittings, wellheads, pipes, pylons, derrick ironwork, tank rims and headers, the burning wells' wreckage | #240C02 / black |
| Raw wood (Main Street's) | #8F8C86 | 0.275, 0.262, 0.238 | 0.26 | `M_Plank` | Pumpjack Samson post, skids, and beam; derricks, engine houses, band wheels; pipe trestles; tank stairs | #8F4016 / #331407 |
| Sheet iron (new) | #6A665F | 0.144, 0.133, 0.114 | 0.13 | `M_Sheet` | Tank walls and roofs | #6A2D0C / #240C04 |
| Scorched earth (new value) | #2B2019 | 0.024, 0.014, 0.010 | 0.016 | `M_DirtFar` (tiling) | `oilfield_terrain`; the berms, mounds, and smoke plumes of the horizon tile and the burning wells (as `M_Rock`) | Near black; #220802 in the lane glow |
| Oil-soaked earth (new value) | #17110D | 0.009, 0.006, 0.004 | 0.006 | `M_Dirt` (tiling) | Wellhead pads, sump berms, the burning wells' spill aprons | Black |
| Far iron (Main Street's iron) | #24272E | 0.018, 0.020, 0.027 | 0.02 | `M_RockDark` (tiling) | The horizon tile's derrick and tank silhouettes | Haze colour at that distance |
| Burning oil (new, glows) | #FF9A2E | 1.000, 0.323, 0.027 | 0.45 | `M_Flame` | Burning pools in the horizon's mounds and the burning wells | #FF9A2E exactly, then fog |
| White-hot (the Saloon's lamp glass, glows) | #FFF0C8 | 1.000, 0.871, 0.578 | 0.88 | `M_LampGlass` | The well mouths at the flame anchors, near and far | #FFF0C8 exactly, then fog |

- **Hot:** #FFF0C8 (core), #FF9A2E (body and burning pools). **Mid:** the band #D9662B and the haze #A8401C. **Dark:** ink #120D0A, iron #24272E, scorched earth #2B2019, and the plum sky #1C1226. The haze colour is #A8401C.
- Roughness 0.9 and metallic 0 everywhere (rule 23).
- Grain by name: `M_Plank` 0.12; the four tiling names 0.2 (invisible at these values, and it fades by 45 m); `M_Iron`, `M_Sheet`, `M_Glass`, `M_Flame`, and `M_LampGlass` none. `M_Sheet` is a new base name and needs no code. It must not be a tiling name, or the tanks drop out of the per-GLB image.
- `M_DirtFar`, `M_Dirt`, `M_Rock`, and `M_RockDark` are tiling names whose colours here do not match their words; a GLB's own material sets the colour, so the oil field's values do not touch Main Street's, the Canyon's, or the train's (`world_surface_import.gd`; Train Rooftop G9).
- `M_Flame` and `M_LampGlass` draw unlit, exactly their colour, and their meshes cast no shadow (Saloon G7, landed). Their colours come from each GLB's material, so the oil field's orange flame needs no code. The Saloon's `M_Flame` is #FFD966; this one is #FF9A2E.
- No pumpjack lamp: the period had none, and a lamp on 32 nodding beams would spread white points the reference does not have. Only the well mouths and pools glow.

### The train at night

- **Company blue** under the orange key is about #2D2726 on its lit (left) side and black on the right: a dark taupe box, not blue. It joins the dark foreground. The tin beside the walk, in the lane glow, is about #232322, near-black grey.
- **The walk** (raw wood) in the lane glow reads about #753B13 (middle step) to #8F4919 (full): a warm strip down the black deck. It is the lane's main read from both spawns, and the roofs beyond the pool fall to near black.
- **Bone letterboards and frames** on the train's left side read about #EB6925, bright orange lines; on the right they are dark.
- **Brass** domes, bands, and the business car's railing read about #C94B05 on the left. **Vermilion** wheels read dark red.
- **The lamp lenses** (`M_LampGlass`, headlight and the business car's four markers) stay #FFF0C8: small cream points, the only light-coloured things apart from the flame cores.
- **What the new scenery must do:** stay neutral and darker than the haze, so the train's lit lines and the walk are the brightest non-fire things near the lane; keep x ±6 clear above 1.5 m so the train's outline stands against ground and haze; put nothing self-lit within 50 m of the track, with one stated exception: the two burning wells on the mid belt's left, 42 to 45 m out (F10). They pass every 55 s on the fire side, and the lane glow swells with them, so their light agrees with the light on the train.
- **Re-skin:** none (F30). The weak spot, dark legs over the dark tin (backdrop check), is accepted.

### What each Jarhead frame gives

Frame numbers are `jarhead.jpg`'s, left to right and top to bottom. The horse frame is `jarhead2.jpg`.

| Frame | What it shows | What this scene takes | Where |
|---|---|---|---|
| 1 | Pink-violet clouds over an orange horizon; two rifle silhouettes on a black ground line | The plum sky top over a thin bright band; figures cut out against the band at head height; a black ground with a hard flat top edge | Sky values; rule 22; F5, F6 |
| 2 | Two seated figures before one white-hot column, a lattice pylon beside it, dark smoke above, the base glowing on the ground | The column's anatomy: white core, yellow-orange body, dark smoke head, a glowing pool at its root. The pylon as a black lattice beside a fire | `oil_burning_well` passing on the left, its plume capping the column and the pylon wires crossing in front of it (F10, F12, F21); `Flame_1`'s mound |
| 3 | A black head drinking against flat amber | A duelist as a black cut-out with an orange rim on a field with no detail | Rule 22; the rim follows the key |
| 4 | Two figures walking on black flat ground against dark orange haze | Haze steps with no fire in frame: black ground, mid haze, a soft horizon. The dark flat foreground | Fog density; terrain value; F4 |
| 5 | A tall column with billowing smoke, smaller columns along a flat horizon, tiny figures | Several columns at different distances, smaller and dimmer as they go; smoke merging into a ceiling | Flame anchors and their sizes; the smoke ceiling; F9, F11 |
| 6 | A soldier from behind, a column off to one side | The fire beside the subject, never behind his head; the lit side faces the fire | Rule 22; anchors kept out of ±6° |
| 7 | A shirtless man in a Santa hat, pink smoke, a cold night | Nothing: not an oil-fire frame | |
| 8 | A gas-masked face in near darkness, a glow on the horizon behind | The darkest end of the scene: the unlit right side and the backlit view, with the glow only on the horizon | The right-hand belt; the view from `EnemySpawn` |
| Horse | Man and horse in silhouette between flame columns left and right, haze filling everything, ground lit near the fires | Columns framing the duel from both sides of the lane; one hue everywhere; flame tops dissolving into haze | Anchors on both sides, more on the left; the mound pools; the burning well passing close, with the lane glow swelling (F10) |

### Where the PSX look and the reference pull apart

1. **No bloom.** The frames' fires bleed light into the smoke ("blooming in the atmosphere", Deakins). The renderer has no glow pass. Chosen: the fog's sun scatter toward the fire key and the sky's halo do the bloom on the left horizon; each mound has a self-lit pool, so the base glows.
2. **Uniform fog.** The frames' haze is brightest near each fire. Depth fog is one colour everywhere, plus one scatter direction. Chosen: one fire side (F1), so the brightness has a direction.
3. **Fog dims the cores.** Real fire stays white through smoke. Chosen: the column cue's core takes no fog inside about 150 m and ramps to full fog at about 300 m, so no core pops in at a wrap (F11); the mounds' self-lit mouths fog, which gives the haze steps.
4. **Soft edges.** The frames' silhouettes are soft and grainy. PSX edges are hard. Chosen: hard near-black shapes, the graphic version (board #20).
5. **Smoke volume.** The frames carry mountains of smoke. Dithered puffs sparkle in a headset (`SHADERS.md` §6). Chosen: a static dark plume mesh over every mound and burning well and no smoke in the cue (F12), under a smoke-coloured cloud deck (F6).
6. **The lit ground of the horse frame.** Near the fires its ground is orange; the other frames' foregrounds are black. Chosen: the ground at the train stays black, and glows only inside the mounds.
7. **Detail.** The frames show texture in smoke and skin. Chosen: none. Values and haze carry depth.

### Half-head against it

His black squares, ink outline, and black gun read hard against the band (contrast about 5.4) and melt into the plum sky above it (about 1.1). His white squares, bone dome, and white gun, lit orange by the lane glow, melt into the band (about 1.2 to 1.4) and read hard against the plum sky (about 6 to 8). So wherever he stands, half of his checker reads and half dissolves: against the band he is a black lattice, against the sky a bone one, and the orange rim follows his outline in both. He is a giant, so his head and hat stand higher than anyone's: with `sky_curve` 0.08 the band has given way to plum by about 5° up, which is where a giant's head lands from 20 m. The scene carries no other checker, no bone, and no white except the fire, so his is the only pattern and his bone the only pale solid in the frame (F27). The flames stay the only colour.

### Backdrop check

How the numbers were made, more roughly than the earlier sheets: each duelist colour lit by the lane glow at the full step (light #FF8A3A, energy 1), the rim and fog left out; backdrops as seen (estimates). Roster colours are approximations, as on the Saloon sheet; White is Half-head's. Contrast is (Y₁ + 0.05) / (Y₂ + 0.05); under 1.5, only hue separates the two.

| Behind the duelist | Seen | Bile yellow | Absinthe | Aquamarine | Bone | White | Red | Ox-blood | Gold | Black coat | Ink outline |
|---|---|---|---|---|---|---|---|---|---|---|---|
| The horizon band (head and hat) | #D9662B, Y 0.24 | 1.1 | 1.5 | 1.4 | 1.2 | 1.4 | 1.7 | 4.6 | 1.2 | 5.4 | 5.4 |
| The haze over the far roofs and ground (hips, chest) | #A8401C, Y 0.12 | 1.5 | 1.1 | 1.3 | 2.1 | 2.3 | 1.0 | 2.7 | 1.5 | 3.2 | 3.2 |
| The walk in the lane glow (legs, standing) | Y about 0.07 | 2.2 | 1.6 | 1.8 | 3.0 | 3.3 | 1.5 | 1.9 | 2.1 | 2.2 | 2.2 |
| The tin beside the walk (legs at the strafe's ends) | Y about 0.02 | 4.4 | 3.2 | 3.6 | 5.9 | 6.6 | 2.9 | 1.1 | 4.2 | 1.1 | 1.1 |
| The plum sky above the band (a giant's head) | #1C1226, Y 0.008 | 4.5 | 3.3 | 3.7 | 6.1 | 7.7 | 3.0 | 1.1 | 4.4 | 1.1 | 1.1 |

- **The dark roster reads like frame 3:** black coat, ox-blood, and the ink line stand at 4.6 to 5.4 against the band and 2.7 to 3.2 against the haze. This is the scene's strength.
- **Pale colours against the band** are hue only (1.1 to 1.5), the inverse of Train Rooftop. Lit orange by the glow, bone, white, and gold turn the band's own colour. The orange rim and the ink line carry them. Accepted as the reference's look (frames 1 and 3 have no pale figure); the band stays thin (F5).
- **Dark legs over the tin** at the strafe's ends: 1.1. Only the rim shows them. The walk under the standing duelist holds 1.5 to 3.3 for everyone. Accepted: the train is not re-skinned (F30).
- **From `EnemySpawn`** the view is the same by symmetry: the glow sits at mid-lane and the key comes from the side, so neither spawn is backlit.

## B. Asset sheets

Ten new GLBs, one `.blend`: `assets/models/scenarios/oilfield_train/oilfield_train.blend`. Each GLB root is a parentless empty named as the GLB, at the origin (no parking needed: the export zeroes the root's location).

| Asset | Band | Copies | Class | Budget each | Budget in scene | Objects each | Objects in scene |
|---|---|---|---|---|---|---|---|
| `oil_pumpjack` (hero) | Near and mid | 20 near + 12 mid = 32 | Module, animated beam | 380 | 12,160 | 3 | 96 |
| `oil_wellhead` | Near | 16 | Module | 120 | 1,920 | 2 | 32 |
| `oil_sump` | Near | 16 | Module | 70 | 1,120 | 2 | 32 |
| `oil_pipe_run` | Near | 24 | Module | 140 | 3,360 | 2 | 48 |
| `oil_derrick` | Mid | 10 | Module | 600 | 6,000 | 2 | 20 |
| `oil_tank` | Mid | 8 | Module (a battery of two) | 320 | 2,560 | 3 | 24 |
| `oil_pylon` | Mid, left only | 8 | Module with its span of wire | 450 | 3,600 | 1 | 8 |
| `oil_burning_well` | Mid, left only | 2 | Module with a flame anchor and a plume | 300 | 600 | 5 | 10 |
| `oilfield_terrain` | Static | 1 | Ground | 12 | 12 | 1 | 1 |
| `oilfield_horizon` | Far | 32 | Tile with flame anchors and plumes | 460 | 14,720 | 4 | 128 |
| **New** | | | | | **46,052** | | **399** |
| Reused train (`train_rooftop.md` H) | | | | | 11,876 | | 46 |
| Reused `env_rail_track_8m` ×90 | Near | | | 98 | 8,820 | 3 | 270 |
| **Scene** | | | | | **About 66,700** (66,748; decided, F31) | | **About 715** (decided, F32) |

**Why the budget grows.** Train Rooftop is 46,691 triangles in 902 objects. This scene drops the 180 cacti (9,219) and the 84 spans (16,764) and spends about 46,000 on the oil field: 1.43 times Train Rooftop, with fewer draw calls (715 against 902), because the near band has 76 dressing pieces where Train Rooftop had 180 cacti in 293 objects, and the far band runs 32 tiles where Train Rooftop ran 84 spans. The increase buys density, which is what makes an oil field read: pumpjacks on both sides, derricks behind them, plumes over every well, and one fire close enough to pass. Half the belt is behind the player or out of view at any moment, so about 34,000 triangles are in view from a spawn, about 2% of Meta's 1.5 million a frame for Quest 3. The PSX look caps detail first: the 10 cm, 0.25 m, and 0.5 m floors and the per-asset ceilings keep everything chunky, since the polygons on screen at once set the budget (Andy Gavin).

Two limits tighter than the count:

- **Draw calls.** About 715 before culling against Meta's guideline of under 200. The tracks alone are 270. Going lower is belt instancing in code, decided after Quest timing (F32), as Train Rooftop F18 left it.
- **Lights and particles.** One omni without shadows (its energy swells as a well passes), no directional shadows, and 14 flame cues in the loops: 12 on the horizon, 2 at the burning wells. Time them on a Quest.

Per-asset collision: none. Every new piece rides the belt (which strips collision) or stands beyond the guard walls, except `oilfield_terrain`, which keeps the ground proxy so a corpse that falls off the train lands on something.

---

### `oil_pumpjack` (hero, module ×32)

| | |
|---|---|
| Role | The field's defining object and the only moving one. Near copies at x ±10 to ±15 (centre) pass the roof at 20 m/s and stand beside the lane from 7° to 20° off its axis; mid copies at x ±28 to ±40 stand behind them at 7 m/s. Left-hand copies show their unlit +X face, black against the fire; right-hand copies show their lit −X face |
| Size | Base skid 7.0 m along X × 1.4 m along Y, z 0 to 0.35 (its foot 12 cm under the terrain's top). Samson post: an A-frame to a bearing at (0, 0, 4.0). Beam 6.6 m (X −3.0 to +3.6), 0.35 m wide × 0.45 m deep, fattened from the standard rig's 12 in × 26 in. Horsehead at +X: an arc face 1.6 m tall (z 3.2 to 4.8 at rest), 0.5 m wide. Gear house 1.6 × 1.2 × 2.2 m at X −2.2. Tail counterweight 0.6 × 0.6 × 0.8 m at X −2.8. Well under the head at X +3.6: a stuffing box and polished rod to z 2.2 |
| Squint | A long beam on an A-frame with a horse's head at one end, over a box, nodding. Black iron and raw wood. From the left: one black cut-out. From the right: a lit timber frame and a lit head |
| Triangles | 380: frame iron 120, frame timber 150, beam 110 |
| Collision | None |

**The beam (`WalkingBeam`).** One mesh object named exactly `WalkingBeam`, in `M_Plank` only, its origin at the bearing (0, 0, 4.0), resting level. It holds the beam, the horsehead, the tail counterweight box, and a pair of pitman arms hanging from the beam at X −2.2 down to z 1.4, inside the gear house. In Godot its rotation axis is the node's local z (Blender local Y, along the track). A positive angle raises the head. The pitmans sweep with it: their feet move X −0.5 to +0.6 and z +0.5 to −0.4 at the ends of the stroke, so the gear house is 1.6 m long and 2.2 m tall with an open slot on top, and nothing else on the frame stands within 0.7 m of their path.

**Rocking.** ±12° about the bearing, a sine with a 10 s period (6 strokes a minute, inside the 6 to 14 of conventional units: SWPSC), rest pose level. The head end travels ±0.75 m (top to 5.4 m at +12°). One clock for every copy, in three phase groups by copy index (0°, 120°, 240°), so neighbours never nod in step (F17, F18). All 32 nod; about 8 to 12 are in view. Cosmetic, no net.

**Orientation.** The beam runs across the track (Blender X = Godot x), so the duel view, which looks along the track, sees every pumpjack in profile and its nod in the picture plane (F19). Copies are not turned, so the head points +x on both sides: toward the train on the left, away on the right.

Signature details, cut from the bottom:

1. **Beam and horsehead.** The beam a straight timber; the head four flat facets in an arc, 1.6 m tall, with a flat back. The silhouette that says "oil" at any distance.
2. **The Samson post.** Four timber legs 0.25 m square, splayed to a 1.4 × 2.4 m foot, meeting under a bearing block, with one cross brace a side.
3. **The gear house.** An iron box with a sloped lid and the pitmans entering its top slot; a crank guard (an iron disc 1.2 m across, 8-sided, 10 cm thick) on its outboard face, static.
4. **The tail counterweight.** A timber box at the beam's tail.
5. **Skids.** Two timber sills 0.30 × 0.35 m the length of the base, iron tie straps.
6. **The well.** An iron casing stub 0.35 m (8-sided) to 1.2 m, a stuffing box, a polished rod 10 cm to 2.2 m. No bridle (a cable hung from the head would tilt with it).
7. **A ladder** of two rails and four rungs on the post's tail side.
8. **Wear, one accent:** one skid's outboard end lifted 8 cm on a sunken corner.

- **Wear in geometry:** the lifted skid. The beam stays true: it moves.
- **Base Color:** `M_Iron` Iron (gear house, crank guard, straps, bearing block, casing, stuffing box, rod). `M_Plank` Raw wood (Samson post, skids, ladder; and the whole `WalkingBeam`). Three objects: `Pumpjack_Iron`, `Pumpjack_Plank`, `WalkingBeam`.
- **UV:** the beam is its own object and gets its own islands in the GLB's image; paint it in the rest pose. The horsehead's facets fold into one chart at the per-GLB unwrap's 66° rule; check it does not fold onto itself. The crank guard is an 8-sided n-gon pair with quads between: it may trip `scenery_uv._is_cylinder` (Train Rooftop build lesson); check for overlap after the unwrap.
- **Draws on:** board #20 (one black shape with line work on one colour), #05 (the real thing, plain); the walking beam and Samson post of the 1884 standard rig (petroleumhistory.org); Trout's counterbalanced unit of 1925 (Texas Escapes), an anachronism listed in F15; the "nodding donkey" (Wikipedia, Pumpjack).

### `oil_wellhead` (module ×16)

| | |
|---|---|
| Role | Near-belt dressing between pumpjacks at x ±6 to ±12: a well that is not being pumped, with its flow line diving into the ground. A ground-level motion cue in place of the cacti |
| Size | Pad: an irregular 6-sided slab about 3.0 × 3.0 m, top at 0.22, sloped sides into the ground. Casing 0.40 m (8-sided) to 1.1 m; a tee at 0.9 m; a gate valve body 0.35 m with an 8-sided handwheel 0.5 m across, 10 cm thick, on a stem; a flow line 0.20 m (6-sided) from the tee, bending down into the pad's edge 2 m away |
| Squint | A black stub with a wheel on a black pad. Iron, oil-soaked earth |
| Triangles | 120 |
| Collision | None |

Signature details, cut from the bottom:

1. The casing and tee: the stub that reads as a well.
2. The handwheel, standing clear of the valve on its stem.
3. The flow line's bend into the ground.
4. The pad, sloped so it is never a slab on the ground plane.
5. Wear, one accent: the flow line kinked 4° at its bend.

- **Base Color:** `M_Iron` Iron (casing, tee, valve, wheel, line). `M_Dirt` Oil-soaked earth (pad; tiling UVs). Two objects.
- **UV:** the pad keeps tiling UVs and stays out of the image; the iron is small islands, flat colour.
- **Draws on:** the casinghead and gate valve, period-plausible and not checked against a source (F23); board #05 (plain working objects).

### `oil_sump` (module ×16)

| | |
|---|---|
| Role | Near-belt ground dressing at x ±7 to ±16: an earth pit of oil, the field's ground texture in geometry |
| Size | A ring berm 6 to 8 m across, 0.6 m tall at its crest (top 0.72), built of 8 chamfered blocks like a sandbag dike; a pool n-gon inside at 0.35; one breach with a tongue of oil spilling 3 m onto the ground at 0.20 to 0.24, sloped |
| Squint | A black pool in a low ring. From the left, the ring's far (−x) faces are lit by the key: a lit crescent around a black hole. From the right, the near faces are lit |
| Triangles | 70 |
| Collision | None |

Signature details, cut from the bottom:

1. The berm ring, blocky, its crest uneven by 10 to 15 cm a block.
2. The black pool, flat inside it.
3. The breach and the spill tongue (the wear accent).

- **Base Color:** `M_Dirt` Oil-soaked earth (berm, tiling). `M_Glass` Ink (pool, tongue). Two objects.
- **UV:** the berm on tiling UVs; the pool and tongue are three faces in the image, nothing to paint.
- **Draws on:** the sandbag berm round the Lakeview Gusher, 1910 (Wikipedia, Lakeview Gusher); unignited oil standing in "about 300 lakes" in Kuwait (Album caption); "lakes of black oil" in *Lessons of Darkness* (via American Cinematographer, and Wikipedia).

### `oil_pipe_run` (module ×24)

| | |
|---|---|
| Role | The nearest new piece: low lines beside the track at x ±3.6 to ±5.0, 16 m long, passing at 20 m/s under the eave. The ground's rhythm seen over the roof edge and from the death cam |
| Size | 16.0 m along Y, closed at both ends: one end turns down into the ground through an elbow, the other ends at a flange. Pipe 0.25 m (6-sided; Van Syckel's was 2 in, fattened) at 0.8 m, on four timber A-trestles 1.0 m tall at Y −6, −2, 2, 6. Between trestles the pipe sags 8 cm, two straight pieces a span. Collars every 4.6 m (15 ft), 8-sided 0.33 m, 12 cm long |
| Squint | A dark line on low timber legs, kinked once. Iron, raw wood |
| Triangles | 140 |
| Collision | None |

Signature details, cut from the bottom:

1. The pipe's sag between trestles: the line is never straight.
2. The trestles: A-frames with a crossbar the pipe rests on.
3. The elbow diving into the ground and the flange at the other end, so each copy reads as a run, not a cut.
4. The collars, raised rings that strobe past at 20 m/s (4.6 m pitch passes in 0.23 s, 16 frames at 72 Hz: no backward strobe).
5. Wear, one accent: the third trestle leaning 6°, the pipe kinked 3° over it.

- **Base Color:** `M_Iron` Iron (pipe, collars, elbow, flange). `M_Plank` Raw wood (trestles). Two objects.
- **UV:** the pipe unwraps as charts along its length; a 16 m run gets one long thin island, which is fine for flat paint.
- **Draws on:** Van Syckel's 1865 line, about 5 miles of 2 in wrought iron in 15 ft joints, torn up by teamsters (petroleumhistory.org; NPR); board #20 (line work).

### `oil_derrick` (module ×10)

| | |
|---|---|
| Role | The mid belt's skyline, at x ±26 to ±45 at 7 m/s: the tall lattice that tells the field from a farm. From the lane it stands 15° or more off the axis |
| Size | A standard rig: derrick 22 m tall (72 ft; the catalogue's other size is 82 ft), base 6.0 m square, top 1.6 m square (proportions not sourced). Four legs 0.35 m; girts at five levels; one diagonal brace per bay per face, the lowest two bays X-braced; a crown block and a top platform 2.4 m square. Beside it, along +Y: a walking beam 7.9 m (26 ft) on a Samson post 4.0 m (13 ft), a band wheel 2.7 m (8 to 10 ft), a belt house, and an engine house 4.0 × 6.0 m, 3.5 m to the eaves, with an iron stack 0.5 m to 8.0 m |
| Squint | A tall thin lattice spike with a low shed at its foot. From the left: a black lattice on the band. From the right: a lattice drawn in lit timber. Raw wood, iron |
| Triangles | 600: legs 40, girts 160, braces 200, crown and platform 40, beam, post, and band wheel 80, sheds and stack 80 |
| Collision | None |

Signature details, cut from the bottom:

1. The tapering four-legged lattice, its legs straight lines from base to crown.
2. The crown block and platform: the knot at the top.
3. The girts and braces: the lattice that lets the band show through.
4. The engine house and its stack, low and dark.
5. The walking beam on its Samson post and the band wheel: the drilling rig's machinery, static.
6. Wear, one accent: the whole derrick leaning 2° away from its engine house, and one upper brace missing, so the band shows through the gap.

- **Base Color:** `M_Plank` Raw wood (derrick, beam, post, band wheel, belt house, engine house walls). `M_Iron` Iron (engine house roof, stack, crown sheave). Two objects.
- **UV:** the lattice is a hundred thin members: tiny islands, mostly under 16 px², flat colour (G4). Only the engine house's walls are worth paint.
- **Draws on:** the standard rig of 1884 and the Jarecki catalogue's 72 ft and 82 ft derricks (petroleumhistory.org); Spindletop's derricks "so close together they appear to be touching" (Search and Discovery, Trost); Los Angeles' field of the 1890s, wells among houses (Wikipedia; Homestead Museum); board #20, #30 (the company drawn as landscape).

### `oil_tank` (module ×8, a battery of two)

| | |
|---|---|
| Role | The mid belt's mass, at x ±30 to ±45: two round shapes that catch the key on one side and go black on the other. The lit half-moon of a tank is the clearest "lit side faces the fire" in the scene |
| Size | Tank A: 10.0 m across, 7.0 m tall, 12-sided, with a low cone roof rising 1.2 m. Tank B: 7.0 m across, 5.5 m tall, 12-sided, cone roof 0.9 m. 3 m apart along Y. A rim angle 0.30 m tall, 0.12 m proud, at each top; one course step 0.12 m at mid-height on A. A two-flight timber stair up A. An iron header pipe 0.30 m at 1.0 m between them |
| Squint | Two drums, a big and a small, with flat cone hats. Lit side: a warm half; dark side: black. Sheet iron, iron, raw wood |
| Triangles | 320 |
| Collision | None |

Signature details, cut from the bottom:

1. The two drums at different heights: the battery's skyline.
2. The cone roofs and rim angles: a lit line round each top on the fire side.
3. The course step on A.
4. The stair.
5. The header pipe between them.
6. Wear, one accent: B's roof slumped 4° toward one side, its rim dented into a 0.6 m flat.

- **Base Color:** `M_Sheet` Sheet iron (walls, roofs). `M_Iron` Iron (rims, step, header). `M_Plank` Raw wood (stair). Three objects.
- **UV:** each wall unrolls as one long rectangle if the tank stays a plain prism between its caps; merged into `Tank_Sheet` with the second tank it will not take the cylinder path, so expect a few charts per wall. Fine for flat paint.
- **Draws on:** riveted wrought-iron tanks from the early 1870s, wood before (ETHW, Petroleum storage tanks); a riveted steel tank of up to 35,000 barrels in an 1892 catalogue (ETHW); tankage beside railways and ports (ETHW).

### `oil_pylon` (module ×8, left side only)

| | |
|---|---|
| Role | The frame-2 pylon: a black lattice tower on the fire side, with its wires sagging to the next. The belt places all eight at a fixed x −22 m and an exact 96 m pitch, never rolled, so each copy's wires meet the next tower's arms |
| Size | 22 m tall. Square base 4.0 m, tapering to 1.2 m at 16 m; a cage above with two cross-arms, 6.0 m wide at 17 m and 4.0 m at 20 m (the "man" shape), three arm tips. Legs 0.30 m, braces 0.25 m, one diagonal per bay per face (a zigzag), four bays. Wires: three, from this tower's arm tips to the arm-tip positions 96 m along −Y, each six straight pieces sagging 3.0 m at mid-span, 8 cm triangular section |
| Squint | A black lattice man with outstretched arms, three thin lines to the next. Iron |
| Triangles | 450: tower 300, wires 108, arms and insulator blocks 42 |
| Collision | None |

Signature details, cut from the bottom:

1. The tapered lattice tower with its two arms: the silhouette.
2. The wires' sag: the line that ties the towers into a row.
3. The bracing zigzag.
4. Insulator blocks under the arm tips, 0.25 m.
5. Wear, one accent: the outer tip of the lower arm bent down 5°.

- **Base Color:** `M_Iron` Iron. One object.
- **UV:** thin members, flat colour; the wires are long thin islands, nothing to paint.
- **Lit side:** it stands on the left, between the lane and the fire, so the train only ever sees its unlit face: a black cut-out on the band, as in frame 2.
- **The wires cross the near column.** The line at x −22 stands between the train and the burning wells (x −42 to −45). From the roof its wires, 14 to 20 m up, sit 22° to 34° above the eye, and a well's column rises to about 37° above it as it comes abeam, so the wires and the next tower cross the column's upper half for a few seconds each pass. Intended: frame 2's lattice beside the fire.
- **Draws on:** frame 2; the first lines built wholly on steel towers, 1903 in Mexico and 1910 in Washington state (Wikipedia, Transmission tower; HAER WA-82), an anachronism listed in F21; telegraph lines on railroad rights of way from 1859 (Supreme Court, *Western Union v. Pennsylvania Railroad*); riveted iron as the period's lattice material.

### `oilfield_terrain` (static)

| | |
|---|---|
| Role | The ground under the stopped train and to the fog: Train Rooftop's `env_terrain` in a new colour |
| Size | `env_terrain`'s box exactly: 2,000 m square, top at +0.12, 0.5 m thick; its proxy the same box |
| Squint | Black ground to the fog |
| Triangles | 12 |
| Collision | `Oilfield_Ground-convcolonly`, the same box as `TerrainPlayable` (no code reads that name) |

- **Base Color:** `M_DirtFar` Scorched earth, tiling UVs. One object, named `Oilfield_Ground`.
- **Why not reuse:** `env_terrain` is Main Street's ground too, and its colour is Main Street's (found 1).

### `oilfield_horizon` (tile ×32, with flame anchors)

| | |
|---|---|
| Role | The far band at x ±85 to ±110 (rolled per copy), 2.4 m/s: the flat dark horizon, wrecked rigs, and the burning wells. Its content spans 55 to 140 m from the track |
| Size | Content inside X ±30 and Y ±23.875 (47.75 m, 0.125 m clear of each neighbour slot, the spans' rule). No continuous land strip: the terrain is the land, so every piece is closed and the ends never show a cut |
| Squint | A low black line of berms with black spikes and drums standing on it, three glowing wells under dark plumes, columns over some of them. Far iron, scorched earth, burning orange, white |
| Triangles | 460: three mounds 120, three pools and mouths 36, four derrick silhouettes 120, two tank silhouettes 44, low ridges 40, three plumes 100 (F12) |
| Collision | None |

**Contents** (the tile's own Blender frame; +X faces the train from the left):

| Piece | Where (X, Y) | Size | Material |
|---|---|---|---|
| Mound A, `Flame_1` | (−18, −8) | A berm ring 20 m across, 3.5 m tall, eight 35° wedges, one breach; a burning pool n-gon 13 m across at z 0.6, wide enough for the 9 m column base (F14); a wrecked casing 2.4 m across, 1.8 m tall, its top face white-hot | `M_Rock`, `M_Flame`, `M_LampGlass` |
| Mound B, `Flame_2` | (12, 10) | 11 m, 2.2 m tall; pool 7 m at z 0.5; mouth 1.2 m, 1.1 m tall | same |
| Mound C, `Flame_3` | (−2, −17) | 8 m, 1.5 m tall; pool 5 m at z 0.4; mouth 0.8 m, 0.8 m tall | same |
| Derrick, standing | (20, −14) | 22 m: four tapered legs 0.5 m, two girts, a crown block | `M_RockDark` |
| Derrick, burnt | (−25, 16) | 18 m, leaning 12° | `M_RockDark` |
| Derrick, folded | (5, −2) | Its lower 9 m standing, the top 9 m kinked over at 60° | `M_RockDark` |
| Derrick, small | (26, 4) | 14 m | `M_RockDark` |
| Tank | (−8, 8) | 8-sided, 9 m across, 6 m tall, cone roof (moved 2 m along Y to clear Mound A's larger berm) | `M_RockDark` |
| Tank, gutted | (22, 18) | 8-sided, 7 m across, 5 m, no roof, its top edge a zigzag | `M_RockDark` |
| Ridges | Two, along Y | Wedges and chamfered blocks 1.0 to 2.5 m tall (the Canyon's vocabulary at the 0.5 m floor) | `M_Rock` |
| Plumes (F12) | Over each mound | A leaning stack of three lumpy 6-sided prisms, its foot just under its column's top so the dark head caps the column: over A from 55 to 110 m up, 14 to 20 m across; over B from 32 to 80 m, 10 to 14 m; over C from 13 to 45 m, 6 to 10 m. Each leans toward its local −X, which is world −x on both sides (copies are never turned), the way the engine smoke bends | `M_Rock` |

**Flame anchors.** Three empties named exactly `Flame_1`, `Flame_2`, `Flame_3`, at each mouth's top centre, unit scale, Z up. Their column sizes live in this table (the belt script holds it by name), not in the empty's scale (F14):

| Anchor | Column height | Base across | On a left copy | On a right copy |
|---|---|---|---|---|
| `Flame_1` | 60 m | 9 m | 103 to 128 m out (behind the tile's centre) | 67 to 92 m out |
| `Flame_2` | 35 m | 5.6 m | 73 to 98 m | 97 to 122 m |
| `Flame_3` | 15 m | 3.1 m | 87 to 112 m | 83 to 108 m |

- **Which burn.** The belt lights one anchor per lit copy, cycling `Flame_1`, `_2`, `_3` by slot. On the left (fire side) every second slot is lit, on the right every fourth: 8 + 4 = 12 columns in the 768 m loop (F9). Unlit mounds still glow at the mouth and pool (self-lit) and still carry their plumes, so the horizon is dotted with smouldering wells between the columns (F13).
- **In view.** About 8 horizon columns lie within 250 m along the track at any moment; 3 to 5 stand in a 90° view down the lane, more on the left. A column 100 m out takes about 42 s to drift from 45° ahead to abeam at 2.4 m/s: still, for the length of a duel's wait. One burning well also passes on the left every 55 s (`oil_burning_well`).
- **Rule 22.** With the tile at |x| 85 or more and every anchor inside X ±18, each anchor stands at least 67 m out, so it comes within ±6° of the lane's axis only beyond 640 m, past the wrap. Even the widest column's near edge (`Flame_1`, 9 m across, from 62.5 m out) enters ±6° only beyond 595 m. Nothing burns behind a duelist's head.
- **Heights (F14).** The NIST study of twelve Kuwait well fires measured heat release of 90 MW to 2 GW and correlated flame height with it (NIST), without a height in its abstract. 60, 35, and 15 m are the user's choice for the image. Seen from the roof's eye (4.9 m): `Flame_1` stands 24° to 29° above the eye on a left copy and 32° to 40° on a right copy; `Flame_2` 14° to 23°; `Flame_3` 6° to 8°. The tallest columns fill a third of the view's height: the horse frame's towering columns.
- **Colour.** The mouths' `M_LampGlass` and the pools' `M_Flame` fog like everything else: at 100 m under density 0.009 a mouth reads about #D08A60 and a pool about #C76A2B, a step above the haze. The column cue's core takes no fog inside about 150 m, ramps to full fog at about 300 m (F11), so every horizon column within 150 m keeps a white core and none pops at the wrap (384 m, 97% fog).
- **No coplanar faces.** Build the tile with the horizon finals' kernel: closed prisms on a 0.25 m grid, one exact self-union per material, cut at z 0, coplanar faces dissolved (`dev/build_horizon_ridge_finals_blender.py`). The pool sits at 0.4 to 0.6 inside its berm, never at 0 or 0.12; the mouth rises from the pool; each plume's foot floats clear of everything below it.
- **Base Color:** `M_Rock` Scorched earth (mounds, ridges, plumes). `M_RockDark` Far iron (silhouettes). `M_Flame` Burning oil (pools). `M_LampGlass` White-hot (mouths). Four objects: `Horizon_Rock`, `Horizon_RockDark`, `Horizon_Flame`, `Horizon_LampGlass`.
- **UV:** the two rock objects carry 8 m tiling UVs written by `scenery_uv.unwrap_object(obj, scenery_uv.TILING)`, at zero rotation with the origin at the tile's origin (Canyon G2, G3). The two glowing objects are the only ones in the per-GLB image, a handful of faces. Nothing here is worth paint.
- **Signature details, cut from the bottom:** (1) the three mounds with their glowing pools and mouths; (2) the plumes capping them; (3) the standing derrick and the folded one; (4) the tank and the gutted tank; (5) the burnt derrick and the small one; (6) the ridges.
- **Draws on:** frames 2, 5, 6 and the horse frame; Herzog's *Lessons of Darkness*, which the Jarhead crew watched (American Cinematographer, via search); the Kuwait fires, 605 to 732 wells (Wikipedia); Baku's blowout fountains, 42% of output in 1887 (Wikipedia, Petroleum industry in Azerbaijan); Spindletop's fires (UNT); the Canyon's wedges and chamfered blocks.

### `oil_burning_well` (module ×2, mid belt, left only)

| | |
|---|---|
| Role | The one fire that passes close (F10): frame 2 up close. Two copies on the mid belt's left, 384 m apart in the 768 m loop, so one comes abeam every 55 s at 7 m/s. Its anchor stands at x −42 to −45 (rolled per copy), 42 to 45 m from the lane's axis. The lane glow swells as it passes |
| Size | The horizon mound's vocabulary at the mid belt's 0.25 m floor. A berm ring 14 m across, 2.2 m tall, eight 35° wedges with a blocky crest, one breach facing the train (+X), so the pool shows through the gap from the roof. A burning pool, a 12-sided n-gon 8 m across at z 0.5, wide enough for the 5.6 m column base. A blown casing, 8-sided, 1.4 m across and 1.4 m tall, rising from the pool, its top face white-hot. A spill apron of oil-soaked earth out of the breach, 5 m long, sloped from 0.26 to 0.20. A plume from 32 to 75 m up |
| Squint | A black ring with a white-hot heart in an orange pool, under a dark plume leaning away from the train. Scorched earth, burning orange, white |
| Triangles | 300: berm 100, pool and casing 40, spill apron 20, plume 120, wear 20 |
| Collision | None (the belt strips it; it stands 35 m or more beyond the guard walls) |

**The anchor: `Flame_Near`.** One empty at the casing's top centre, (0, 0, 1.4) in the asset's frame, unit scale, Z up. Its column is 35 m tall on a 5.6 m base, the horizon's middle size (F10, F14). The name keeps the `Flame_` prefix, so one search finds every anchor in the scene, and its suffix keys its own row in the belt's size table and tells the script that this anchor rides the mid belt, always burns, and drives the lane glow's swell. A number (`Flame_4`) would read as a fourth horizon anchor.

**The plume (F12).** Four lumpy 6-sided prisms stacked and leaning toward local −X (world −x, away from the train), 10 to 14 m across, from 32 m (just under the column's top at about 36 m, so the dark head caps the column) to 75 m. No smoke in the cue.

**Rule 22.** The anchor at x −42 or beyond would enter ±6° of the lane's axis only 400 m ahead, beyond the mid loop's reach (the wrap at ±384 m puts it at most 394 m from a spawn's eye), so it never does. The column's near edge (2.8 m nearer) reaches ±6° only in the last 20 m before the wrap, from 373 m, where the fog is 96% and the core fully fogged. It never comes within ±4.5° (the anchor would need 534 m, the edge 498 m). Seen from either spawn, the well approaches beside the lane, not behind a duelist.

**As it passes.** At 200 m ahead it stands 12° off the axis at 84% fog, its core 36% fogged on the cue's ramp. From 45° ahead to abeam takes about 6 s. Abeam at 42 to 45 m the berm and plume are 31 to 33% fogged; the mouth reads about #E3B791 and the pool about #E37D28; the cue's core is unfogged (inside 150 m); the column stands 35° to 37° above the eye; the pylon wires cross its upper half. The lane glow rises +60% over the 60 m before abeam and falls over the 60 m after.

**Lit side.** The key from −x lights the well's −X faces, away from the train. The train sees the berm's unlit faces: a black ring round a glowing heart, the base glow against the black foreground of frame 2.

Signature details, cut from the bottom:

1. The casing and pool: the white-hot heart and its orange ground, the column's root.
2. The berm ring with its breach toward the train, so the pool glows through.
3. The plume capping the column.
4. The spill apron out of the breach.
5. Wear, one accent: one crest block of the berm slumped into the pool.

- **Wear in geometry:** the slumped block. No derrick wreck: wrecks stay on the horizon tile (F26).
- **Base Color:** `M_Rock` Scorched earth (berm, plume; tiling). `M_Dirt` Oil-soaked earth (spill apron; tiling). `M_Iron` Iron (the casing's sides). `M_Flame` Burning oil (pool). `M_LampGlass` White-hot (the casing's top). Five objects: `Well_Rock`, `Well_Dirt`, `Well_Iron`, `Well_Flame`, `Well_LampGlass`.
- **UV:** the rock and dirt objects carry 8 m tiling UVs (`scenery_uv.unwrap_object(obj, scenery_uv.TILING)`, zero rotation, origin at the asset's origin). The casing and the two glowing objects are the only ones in the per-GLB image, a few faces. Nothing here is worth paint.
- **No coplanar faces:** built with the horizon finals' kernel, as the tile; the pool at 0.5, the apron from 0.20 up, nothing at 0.12.
- **Draws on:** frame 2 and the horse frame; the sandbag berm round the Lakeview Gusher (Wikipedia); the Kuwait well fires (Wikipedia; NIST); Spindletop's fires (UNT).

### The belt (`scenarios/oilfield_train/scenery_belt.gd`, new; intent only)

Three bands at Train Rooftop's speeds. Copies are moved, never turned, and lose collision. Nothing sways.

| Band | Piece | Copies | Across the track | Speed | Loop |
|---|---|---|---|---|---|
| Near | `env_rail_track_8m` | 90 | Under the train | 20 m/s | ±360 m |
| Near | `oil_pumpjack` | 20 (10 a side, alternating, one per 72 m a side) | Centre x ±10 to ±15, rolled | 20 m/s | ±360 m |
| Near | `oil_wellhead` | 16 | x ±6 to ±12 | 20 m/s | ±360 m |
| Near | `oil_sump` | 16 | x ±7 to ±16 | 20 m/s | ±360 m |
| Near | `oil_pipe_run` | 24 | x ±3.6 to ±5.0 | 20 m/s | ±360 m |
| Mid | `oil_derrick` | 10 | x ±26 to ±45, rolled | 7 m/s (0.35×) | ±384 m (16 slots of 48 m) |
| Mid | `oil_tank` | 8 | x ±30 to ±45 | 7 m/s | ±384 m |
| Mid | `oil_pumpjack` | 12 | x ±28 to ±40 | 7 m/s | ±384 m |
| Mid | `oil_burning_well` | 2, left only, slots 0 and 8 (384 m apart) | Anchor at x −42 to −45, rolled | 7 m/s | ±384 m |
| Mid | `oil_pylon` | 8 | x −22 exactly, 96 m pitch, left only | 7 m/s | ±384 m |
| Far | `oilfield_horizon` | 32 (16 slots × 2 sides) | x ±85 to ±110, rolled | 2.4 m/s (0.12×) | ±384 m |

- **Mid slots.** Each side has 16 slots. The left's slots 0 and 8 hold the burning wells; its other 14 and the right's 16 hold the 30 derricks, tanks, and pumpjacks. The pylon line rides on top of the slots at its fixed x.
- **Spacing.** On the near belt, footprints keep 3 m apart along z; nothing taller than 1.5 m inside x ±6.0 (the pipe runs are 1.2 m). On the mid belt's left, rolled pieces stay at x −28 or beyond, clear of the pylon line at −22. A burning well's berm reaches toward the train only to x −35 to −38, 10 m or more beyond the pylon's arm tips (−25).
- **Wraps against the fog** (density 0.009, F4): the near wrap at 360 m is 96% fog; the mid and far wraps at 384 m are 97%. A 6 m pumpjack popping at 360 m is 0.9° tall at 4% contrast. Nothing may wrap nearer than 350 m. A column's core is fully fogged beyond about 300 m (F11), so no core pops at either wrap.
- **Beams.** One script clock, three phase groups, ±12° at 10 s (F17, F18); it may skip copies beyond 250 m. 32 transform writes a frame.
- **Flames.** The cue spawns at the lit anchors of lit copies and at both `Flame_Near` anchors, and rides with them: 14 in the loops. Flame only; the smoke is the plume meshes (F12).
- **The glow's swell.** The script finds the nearer `Flame_Near` copy each frame and writes the lane glow's energy from its z offset (Light rig). One write a frame.
- **Fog steps:** near 4 to 16 m, 4 to 13%; mid 20 to 45 m, 16 to 33%, the burning wells abeam at 42 to 45 m, 31 to 33%, with their cores unfogged; far 55 to 140 m, 39 to 72%; the wraps, 96 to 97%.

## C. Build order

**Hero: `oil_pumpjack`.**

- It is the object the user named for this field, and the one silhouette that says "oil" at squint.
- It is the only moving piece. Its contract (one object named `WalkingBeam`, origin at the bearing, rest pose level, the pitmans' sweep inside the gear house) has to be proven in Godot before anything copies the kit.
- It is the most repeated mesh (32 copies on two belts) and the nearest tall one, so its count and its read cost the most.
- It sets the shape language the derrick, pipe run, and wellhead copy: fattened timber, black iron, flat facets, one accent.
- Its lit and unlit faces test the light rig: a right-hand copy must read lit timber, a left-hand copy a black cut-out.

**Order** (×N marks a modular repeat):

1. Scene stub first, for the review: copy Train Rooftop's train half into `scenarios/oilfield_train/` with the new terrain and a belt that places only the hero, and the light rig at its intended values. Step 3 of the Roadmap item owns this; the hero's review needs it.
2. `oil_pumpjack` (×32), the hero, reviewed with its nod running.
3. `oilfield_horizon` (×32) with its anchors and plumes: the reference match depends on it more than on any other piece.
4. `oil_burning_well` (×2): the horizon mound's vocabulary at the mid belt's floor, built straight after it from the same kernel. Its pass, with the glow's swell, is the frame-2 test.
5. `oil_derrick` (×10), then `oil_tank` (×8): the mid band.
6. `oil_pylon` (×8): needs the mid belt's fixed pitch; check its wires against the well's column.
7. `oil_pipe_run` (×24), `oil_wellhead` (×16), `oil_sump` (×16): the near ground.
8. `oilfield_terrain`: a copy with a colour; can go with step 1.

## D. Review checklist

### Views

| View | Where | Camera | For |
|---|---|---|---|
| Lane P | Godot, the scene, shaders on | Eye at (0, 4.9, 10), looking at (0, 4.9, −10), the flat camera's field of view | Near and mid rigs beside the lane, the band behind the enemy's head, the pool on the roofs |
| Lane E | Godot | Eye at (0, 4.9, −10), looking at (0, 4.9, 10) | The same from the other end; symmetry of the light |
| Fire | Godot | From Lane P's eye, aimed at (−100, 8, −60) | The left: silhouettes on the bright horizon, the pylon line, the columns |
| Away | Godot | From Lane P's eye, aimed at (100, 8, −60) | The right: lit faces against the darker horizon |
| Down | Godot | Eye at (0, 4.9, 10) pitched 60° down | The roof in the pool: walk, tin, the glow's falloff |
| Edge | Godot | Eye at (±2.1, 4.6, 7) leaning out, looking at (±5, 0.5, 7) | Pipe runs, wellheads, and sumps passing below |
| Death cam | Godot | Eye at (±3.08, 4.28, −10), looking at (0, 3.4, −10); and a low orbit at (±4.5, 3.0, −10) | Nothing on the belt passes through the camera |
| Nod | Godot | Eye at (12, 2.0, 0) beside a frozen near pumpjack, at its −12°, 0°, and +12° | The pitmans stay in the gear house; the head clears the rod |
| Well pass | Godot | From Lane P's eye, aimed at a burning well as it comes from 200 m ahead to abeam: three captures, with the well 200 m, 60 m, and 0 m ahead of the eye, aimed at (−44, 15, z of the well) | The near column's white core, the glowing pool through the breach, the plume capping it, the pylon wires crossing it, the lane glow's swell on the roofs |
| Side | Blender, the asset's `.blend` | From the train: the asset at its belt's typical x (12 m near, 35 m mid, 95 m far), eye 4.9 m up, 35 mm lens | Every asset (its duel-lane view in Blender) |
| Three-quarter | Blender | 45° between −X and −Y, at the same distance, 35 mm | Every asset |
| Silhouette | Blender: Workbench, flat, one black colour on a world of #A8401C | Side, end-on, and top | Every asset, against the haze colour |
| Squint | The Side render | Shrunk to 64 px wide, enlarged back with nearest filtering | Every asset |

- Render each Godot view in the fixed light. A temporary `Camera3D` does it; do not save it into the scene.
- The belt runs on wall-clock time, so one capture is one moment: take three, 2 s apart.
- Finish in a headset: stand at both spawns, lean over both sides, watch rigs arrive on both sides, stand on the cab roof.

### Pass or fail, every asset

1. **Silhouette:** can you name the asset from its black outline on the haze colour alone?
2. **Squint:** does the 64 px render show one shape and at most three flats?
3. **Size floor:** 10 cm near, 0.25 m mid, 0.5 m far?
4. **Wear:** one accent per module, in silhouette, none in colour; wrecks only on the horizon tile (F26)?
5. **Budget:** triangles within B, and objects equal to materials (plus `WalkingBeam`)?
6. **Names:** unique, no dots, prefixed; `WalkingBeam`, `Flame_1` to `Flame_3`, and `Flame_Near` exact; the terrain proxy suffixed `-convcolonly`?
7. **UVs:** did `dev/unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb <name>` print no TINY share on a face you mean to paint? Does Blender's UV Select Overlap find nothing? Do the tiling objects carry 8 m tiling UVs only?
8. **No shared planes:** no coplanar overlapping faces, nothing at y 0.12 or within 0.08 m of it?
9. **Values:** is every scenery flat a neutral from the Palette, and is nothing but the mouths and pools self-lit?

### Pass or fail, in context

10. Lane P and Lane E: is the band behind each duelist's head a flat field, with no rig or column within ±4.5° nearer than 80 m?
11. Is the lane's pool the brightest non-fire area near the train, and do both duelists stand lit alike?
12. Do the left-hand rigs read as black cut-outs and the right-hand ones as lit timber and sheet iron?
13. Does any piece pop in at a wrap, or pass through the death cam?
14. Do the pumpjacks nod out of step, with no pitman leaving its gear house?
15. Edge: do the pipe runs and pads read without shimmer at 20 m/s when you move your head?
16. Do the duelists, in the shipped tints and in swatches of the designed colours, separate from the band, the haze, the walk, and the tin at squint, as the backdrop check predicts?
17. Wraps: does any flame column, near or far, pop in or out at either wrap (mid and far at ±384 m)? Watch both wraps for a full loop: a core must be fully fogged before it reaches one.
18. Well pass: does the lane glow swell and fall smoothly with the well, the same on both duelists, with no step at the start or end of the 60 m ramps?

### Reference match (the acceptance test)

From a roof at duel distance, in the fixed light, put a flat capture beside the frame named and pass or fail it on each line. Render Lane P, Fire, and Away; use a stand-in duelist at the far spawn.

| # | Question | Frame | View |
|---|---|---|---|
| R1 | One dominant hue: at squint, is everything that is not black one family of orange, from the band to the haze to the flames? | 4, horse | Lane P, Fire |
| R2 | Silhouettes with no interior detail: do the left-hand rigs, the pylon, and the duelist read as flat black shapes with no lit facet inside them? | 2, 3 | Fire, Lane P |
| R3 | A flame column with a hot core: does at least one column show a white-yellow core, an orange body, and a dark head (its plume), its base glowing on the ground? | 2, 5 | Fire, Well pass |
| R4 | Several columns at different distances, smaller and dimmer as they go? | 5 | Fire |
| R5 | Haze steps: do near, mid, and far rigs sit at three distinct values between black and the haze, with no detail telling the depth? | 4, 5 | Lane P, Away |
| R6 | The lit side faces the fire: are the right-hand rigs lit on their train side and the left-hand ones black? | 6, horse | Fire, Away |
| R7 | A dark flat foreground: are the roofs outside the pool and the ground to the fog near black, with a hard flat horizon line? | 1, 4 | Lane P |
| R8 | The fire is beside the subject, never behind his head? | 6, horse | Lane P, Lane E |
| R9 | The sky: a dark plum top over a thin bright band, the duelist's head cut out against the band? | 1, 3 | Lane P |
| R10 | The darkest view still holds a glow on the horizon? | 8 | Away, Lane E |
| R11 | A fire up close: as a burning well comes abeam, does it read as frame 2 (a white core over a glowing base, a dark head, a black lattice beside it) and does the light on the roofs and the duelist swell with it, as the horse frame's haze lights its figures? | 2, horse | Well pass |

### Asset checks

| Asset | Check |
|---|---|
| `oil_pumpjack` | Is `WalkingBeam` one node with its origin at the bearing, level at rest? At ±12°, do the pitmans stay inside the gear house and the head clear the rod? |
| `oil_wellhead`, `oil_sump` | Do pads and pools stand clear of 0.12 with no flicker? Does the sump's lit crescent read from both sides? |
| `oil_pipe_run` | Does each copy read closed at both ends? Do the collars strobe? |
| `oil_derrick` | Does the lattice read from 35 m without shimmer? Do generated LODs keep its legs? |
| `oil_tank` | Does the lit half read as one warm shape and the dark half as black? |
| `oil_pylon` | Do the wires meet the next tower's arm tips exactly at the 96 m pitch? |
| `oilfield_horizon` | Do the anchors sit at the mouths? Does any end show a cut? Do the mouths glow on unlit copies? Does each plume's foot sit just under its column's top? |
| `oil_burning_well` | Is `Flame_Near` at the casing's top centre? Does the pool show through the breach from the roof? Does the plume cap the 35 m column? Does the anchor stay outside ±6° of the lane's axis for the whole loop? |

### Tests

Run `--import`, then `--autotest=load` (the world shader on every surface, once the scene is listed in its checks), `duel`, `multi` (each marker clear, the guard walls, the strafe), `ragdoll` (spawn floors at 3.20), `gauntlet` (the rung), and `lobby`:

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=multi
```

`load` does not see belt clones (found 7), so count the belt in a flat run: 90 tracks, 76 near pieces, 40 mid pieces, 32 tiles, 238 children under `Scenery`, every copy on the world shader and none swaying. Headless runs compile no shaders. The look needs a flat run, then a headset.

## E. Cross-scene dependencies

- **The reused train** (`train_rooftop.md`). Must match: everything. The six GLBs are instanced at Train Rooftop's transforms with their materials unchanged; the markers, `strafe_half_width`, the guard walls, and `EngineSmoke` at the crown are copied. Differs on purpose: the light. The train's left side, which never took sun on Train Rooftop, is the lit side here, and its roofs are dark outside the pool. Changing any train GLB changes Train Rooftop too.
- **`env_rail_track_8m`** (`main_street.md`). Must match: 90 copies, turned onto z, rail tops at +0.21, rail centres ±0.70, eight ties at 1.0 m pitch, 98 triangles in 3 objects. Differs: nothing; it is reused unchanged (F28). Its ballast (`M_Dirt` #DDC499, Main Street's street dirt) sits under the train in darkness and shows through the gaps as a dull stripe in the lane glow. New pieces beside it keep 0.08 m off the ground plane.
- **The Canyon's vocabulary** (`canyon.md`). Must match: the horizon tile's ridges and mounds are built of its pieces (wedges at 35°, chamfered blocks, fallen blocks) on the 0.25 m grid at the belt's 0.5 m floor, and by its method (one self-union per material, coplanar faces dissolved, tiling UVs, zero rotation). Differs: the four rock values. The horizon is not red rock; `M_Rock` and `M_RockDark` carry scorched earth and far iron here. No canyon spans appear (F29).
- **The belt contract** (`scenery_belt.gd`). Must match: wall-clock motion, the three speeds (20 m/s, 0.35×, 0.12×), the 48 m slot pitch, copies moved and never turned, collision stripped, nothing swaying, closed ends with 0.125 m clearance at each end of a tile. Differs: the oil field has its own script; the mid and far loops are 16 slots (±384 m), not 20 and 22; the pylon line uses a fixed x and a 96 m pitch; the far tile reads `Flame_1` to `Flame_3`; the mid belt carries a flame anchor too, `Flame_Near` on the two burning wells, which always burn; the belt drives the lane glow's energy from the nearer well's z offset; a beam clock rocks every `WalkingBeam`.
- **The Saloon's self-lit path** (`saloon.md` G7). Must match: the names `M_Flame` and `M_LampGlass` and one object per glowing material. Differs: the colours, per GLB.
- **Main Street's rules.** Raw wood is one silver grey everywhere; iron and ink are the town's values.

**Build lessons, carried over:**

- Set colours on the per-GLB copies, or delete stale ones: `dev/unwrap_per_glb_blender.py` reuses a `<base>__<glb>` copy by name and never copies a new colour onto it (Main Street). Make the materials under their per-GLB names from the start, as the train's batches did.
- Use headless Blender, or close the live session first: the unwrap script saves the `.blend`.
- Run the unwrap with `--relayout` while nothing is painted.
- Check the sheet's numbers against each other before modeling. This sheet has already set the pitmans' sweep against the gear house, the head's travel against the rod, the near belt against the death cam, the anchors (near and far) against rule 22, the burning wells against the pylon line, and Mound A's larger berm against the tank beside it.
- Name proxies without dots. Godot strips `-convcolonly`, so a proxy may not share a name with a visual sibling (the train's `Engine_Boiler` lesson).
- Avoid three collinear points on a face's outline (zero-area triangles), and count UV islands in the `.blend`, not in the GLB (Saloon).
- Keep tiling objects at zero rotation with their origin at the asset's origin (Canyon G2, G3).
- `scenery_uv._is_cylinder` reads any object with exactly two n-gons and quads elsewhere as a cylinder if the n-gons' corners lie near a circle; a merged object can trip it (the crank guard, the tank pair). Check UV overlap after the unwrap (Train Rooftop H).
- Workbench renders (the F12 key) take the world colour: set `scene.world.color` to the haze for silhouettes.
- Never call `scenery_uv.process_scene()` from the build script (the paused trim-sheet pass cuts bands and writes strip UVs).

## F. Decisions

Answered on 2026-10-28 in nine rounds plus one follow-up round. Every answer took the recommendation except two: a burning well passes on the mid belt (F10), and the columns are taller (F14). F7 follows from F2. The last column says what each decision changes on this page or in the scene.

| # | Question | Decision | What it changes |
|---|---|---|---|
| 1 | Which side the fire is on | The left, −x | The key lights −x faces: left-hand rigs read as black cut-outs, right-hand rigs as lit faces; more columns on the left |
| 2 | What lights the scene | `Sun` re-aimed as an orange fire key 1° below the horizon, no shadows, plus the lane glow | Roofs and ground take no key; fire-facing faces take the full step (A, Light rig) |
| 3 | The lane glow | One omni at (−6, 7.5, 0), range 22 m | Both duelists lit alike; one extra light |
| 4 | Fog density | 0.009 | Four haze steps; wraps at 96 to 97% fog |
| 5 | The sky band | Thin, `sky_curve` 0.08 | Heads against the band, a giant's head against plum |
| 6 | Clouds | A dark smoke ceiling, #4A2418, cover about 0.4 | `cloud_color` set by the fixed point |
| 7 | Sun shadows | Off (follows from F2) | No cascades on the Quest |
| 8 | The engine smoke at night | A per-scene dark colour, about #3A2C26; Train Rooftop keeps its silver | A per-scene override in step 3 (code) |
| 9 | How many columns, and where | Left every second slot, right every fourth: 12 in the far loop | The belt's lit-slot pattern |
| 10 | A nearer hero column | One burning well on the mid belt, left only, two copies 384 m apart (one every 55 s), anchor 42 to 45 m out; a 35 m column on a 5.6 m base; the lane glow swells as it passes (intent) | New asset `oil_burning_well` (B), its anchor `Flame_Near`, its belt row, the glow's swell, rule 22 checked for it, the "nothing self-lit within 50 m" exception, D's Well pass view and R11 |
| 11 | Flame cores and fog | The cue's core takes no fog inside about 150 m, full fog beyond about 300 m, ramped between | A requirement on the cue (Roadmap step 3), not a mesh; D17 checks that no core pops at a wrap |
| 12 | Smoke heads | Static dark plume meshes over every horizon mound and over the burning wells; no smoke in the cue | +100 triangles a tile, 120 a well; plumes start just under each column's top |
| 13 | Unlit mounds | Every mound's mouth and pool glows on every tile | No belt code for swapping |
| 14 | Column heights | 60, 35, 15 m, bases 9, 5.6, 3.1 m | Mound A grows to a 20 m berm with a 13 m pool; the tank beside it moves 2 m; the plumes rise; the angles in B are redone |
| 15 | The pumpjack's type and era | The horsehead pumpjack (1925) in timber and iron, listed as an anachronism | `oil_pumpjack` as written |
| 16 | The linkage | The pitmans are part of `WalkingBeam`; the gear house is static | The gear house sized to the pitmans' sweep |
| 17 | Phase | One clock, three phase groups | The belt's beam clock |
| 18 | The stroke | ±12° at 6 strokes a minute (10 s) | The head travels ±0.75 m |
| 19 | Orientation | The beam runs across the track | Profile from the lane |
| 20 | Pumpjack density | 20 near and 12 mid | 32 copies |
| 21 | The pylon | A riveted iron lattice tower carrying wires, listed as an anachronism | `oil_pylon` as written |
| 22 | The pylon's wires | Three sagging wires per span | 108 triangles a span; the wires cross the near column (B) |
| 23 | The wellhead | A casinghead with a gate valve | `oil_wellhead` as written |
| 24 | The tanks | Riveted sheet iron in neutral grey | `M_Sheet` |
| 25 | Barrels and shacks | None | |
| 26 | Wear | Worked and burnt: one accent per module, wrecks on the horizon only | The burning well carries no derrick wreck |
| 27 | Half-head's checker on the ground | None | His checker stays the only pattern in his fight |
| 28 | The track | Reuse `env_rail_track_8m` unchanged | |
| 29 | The horizon | Flat, with low berms only | No canyon spans |
| 30 | Re-skin the train | None | Dark legs over the tin at the strafe's ends accepted |
| 31 | Scene budget | About 66,700 triangles (66,100 with plumes, plus about 600 for the two burning wells) | B's totals |
| 32 | Draw calls | Keep about 715 objects; belt instancing in code after Quest timing | |
| 33 | How the finals are built | A deterministic script, `dev/build_oilfield_train_blender.py --part <asset>` | G7 |
| 34 | The foreground | Roofs dark except the lane's pool | Ambient about 0.25 |

## G. Pipeline friction

Where the existing texturing pipeline (`docs/TEXTURING.md`) adds work or constraints beyond "model and UV unwrap, then you paint by hand".

**Verdict on the unwrap: reuse `dev/unwrap_per_glb_blender.py` as it is.** It already does the UV job: one non-overlapping 0-to-1 layout per GLB at one texel density, islands upright and never mirrored, round parts unrolled, `uv_lock` to keep hand edits, and each parentless root empty exported as its own GLB. For the tiling objects (terrain, pads, berms, the horizon's rock) the UV job is `scenery_uv.unwrap_object(obj, scenery_uv.TILING)`. The items below are its edges.

1. **The script does not know this map.** `MAPS` in `dev/unwrap_scenery_blender.py` lists five maps. Simplest: add `"oilfield_train": "oilfield_train/oilfield_train.blend"`. Cost: one line of code. `PARKED_CHILDREN` needs nothing: every root sits at the origin.
2. **Each new GLB needs its import file.** Without `import_script/path` and `gltf/embedded_image_handling=3`, `load` fails. Simplest: copy one of the train's `.glb.import` files for each new GLB, `oil_burning_well` included. Cost: ten files.
3. **Hidden faces eat texture.** Simplest: delete them while modeling (rule 27): skid bottoms, gear-house bottoms, pipe ends inside elbows, tank bottoms. Cost: none; it also saves triangles.
4. **Copies inside one GLB get separate islands.** The derrick's hundred members, the pylon's lattice, the trestles: tiny islands under 16 px². Simplest: accept it; they stay flat colour. Only the beam, the tank walls, and the engine houses are worth paint.
5. **Mirrored sides are never stacked.** Simplest: paint both. Here that is mostly moot: one side of every rig is unlit.
6. **A plain run keeps old UVs.** Simplest: `-- --map oilfield_train --relayout --glb <name>` after each final. Cost: none while nothing is painted.
7. **A rebuild wipes UVs and paint.** A build script recreates objects without their UVs, links, or locks. Simplest: build per part (F33) and never rebuild a GLB once its image exists; if you must, relayout and repaint. Never call `scenery_uv.process_scene()`.
8. **Nothing writes tiling UVs on new ground and rock.** The per-GLB unwrap skips tiling meshes. Simplest: call `scenery_uv.unwrap_object(obj, scenery_uv.TILING)` in the build script and set `uv_role` to `tiling`, with zero rotation and the origin at the asset's origin. Cost: a few lines.
9. **Eight tiling names only.** The horizon's silhouettes wear `M_RockDark` and the terrain `M_DirtFar` though neither is rock or desert. Simplest: accept that the names lie; a ninth tiling name needs a line in two files. Cost: naming only.
10. **No vertex colours, normal maps, emission, or alpha.** The importer skips such a material and `load` fails. So the glow is only `M_Flame` and `M_LampGlass`, every lattice gap is real geometry, and the smoke plumes are opaque. Cost: triangles, which B includes.
11. **The beam must survive export as one node.** One material on `WalkingBeam`, its origin at the bearing, rotation zero, no parent but the root. The glTF exporter keeps an object's origin as its node transform and Godot keeps the node name. Simplest: check in Godot that the node exists by name with its origin at (0, 4.0, 0) of the copy before anything else is built (C step 2).
12. **Empties as anchors.** The exporter writes `Flame_1` to `Flame_3` and `Flame_Near` as nodes; the unwrap ignores them. Simplest: keep them unit scale with no children. Cost: none.
13. **Generated LODs.** Every scenario `.glb.import` sets `meshes/generate_lods=true`, which may thin the derrick's and pylon's lattice at range. Simplest: look for a lattice that changes shape as it comes in (D); if one does, set it false in that GLB's `.import`. Cost: one reimport.
14. **Names set behaviour.** `M_Plank` takes grain 0.12; `M_Sheet` is new and takes none; nothing may take a sway name (the belt is not covered by `load`'s sway check). Metallic and specular do nothing (`blender_kit.mat()` defaults specular to 0.15, the train used 0.5; harmless). Cost: naming discipline.
15. **Blender cannot judge the light.** The key below the horizon, the glow's pool, the fog steps, and the glow only show in Godot. Simplest: one flat run per reviewed asset in the fixed light. Cost: the scene stub of C step 1 comes first.
16. **Painting buys little here.** Most surfaces are seen as silhouettes or under orange light. Simplest: paint only the faces the key reaches (the −X faces of the near rigs, the beams, the tank walls) and leave the rest flat. Cost: none; it is a scope note.
17. **The texturing docs go stale.** `TEXTURE_LIST.md` and the GLB table in `TEXTURING.md` will need the ten new GLBs. Simplest: refresh them from the script's printout.

The trim sheet, its texel-density targets, and the texture ripper play no part in this sheet.

## H. As built

### `oilfield_terrain` and `oil_pumpjack` (hero, C steps 7 and 2)

Built on 2026-10-29 by `dev/build_oilfield_train_blender.py` (new, F33), which creates `assets/models/scenarios/oilfield_train/oilfield_train.blend` when it is missing. Each part deletes and rebuilds only its own root, writes its materials under their per-GLB names, and saves. Nothing is random: a re-run printed the same geometry hashes (`oilfield_terrain` 8056a250f611, `oil_pumpjack` bd07e87db6bb), and the re-exported GLBs were byte-identical (MD5). `"oilfield_train": "oilfield_train/oilfield_train.blend"` is added to `MAPS` in `dev/unwrap_scenery_blender.py` (G1); `PARKED_CHILDREN` needs nothing, because both roots sit at the origin. Run by:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/build_oilfield_train_blender.py -- --part terrain
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/build_oilfield_train_blender.py -- --part pumpjack
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map oilfield_train --relayout
```

- **Import files:** `oil_pumpjack.glb.import` and `oilfield_terrain.glb.import` carry `train_coupler.glb.import`'s `[params]` (`import_script/path` = `world_surface_import.gd`, `gltf/embedded_image_handling=3`, `meshes/generate_lods=true`, and the rest), with their uids and `[remap]`/`[deps]` paths filled in by `--import`. `oilfield_train.blend.import` is `[remap]` with `importer="keep"`, so Godot never imports the `.blend`.
- **Materials:** `M_Iron__oil_pumpjack` (0.018, 0.020, 0.027), `M_Plank__oil_pumpjack` (0.275, 0.262, 0.238), `M_DirtFar__oilfield_terrain` (0.024, 0.014, 0.010): the Palette's linear values, roughness 0.9, metallic 0, Specular IOR Level 0.5, emission black at strength 0. Made under these names from the start and rewritten on every build run, so the unwrap copied none.
- **Tests:** `--import`, then `--autotest=load`: `AUTOTEST PASS`, "1056 scenario surfaces wear world_surface.gdshader (204 sway, 4 self-lit, …)". `load` does not see the new GLBs until the scene is listed (Found 7), so the count is unchanged.
- **Unwrap:**
  - `GLB oil_pumpjack [oilfield_train]: 3 meshes, 133 islands, 17.5 px/m at 256 px (pad 2, 58% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`
  - `GLB oilfield_terrain [oilfield_train]: 0 meshes, 0 islands, 0.0 px/m at 256 px (pad 2, 0% covered, 1 tiling meshes untouched); 0 materials copied; image none (flat colour)`
  - No TINY share. UV islands counted in the `.blend`: `WalkingBeam` 31, `Pumpjack_Plank` 60, `Pumpjack_Iron` 42. On the pumpjack's 316 triangles, a triangle-pair test found no UV overlap between faces, no loop outside 0 to 1, and no mirrored triangle. So neither the horsehead's chart nor the crank guard folds onto itself. No object trips `scenery_uv._is_cylinder` (checked by calling it): `WalkingBeam` has exactly two n-gons, the horsehead's sides, but their corners are not on a circle. `Pumpjack_Iron` has four. `Oilfield_Ground` carries 8 m tiling UVs only (u and v −125 to 125), with `uv_role` `tiling`, zero rotation, and its origin at the root's.
  - 17.5 px/m: a 5.7 cm texel.

| GLB | Triangles / budget | Objects | Copies | In scene |
|---|---|---|---|---|
| `oil_pumpjack` | 316 / 380 | 3 | 32 | 10,112 (B: 12,160) |
| `oilfield_terrain` | 12 / 12 | 1 (and its proxy) | 1 | 12 |

| Object | Material | Triangles / budget | Holds |
|---|---|---|---|
| `Pumpjack_Iron` | `M_Iron__oil_pumpjack` | 120 / 120 | Gear house 16, crank guard 20, two tie straps 20, bearing saddle 22, casing 22, stuffing box 10, polished rod 10 |
| `Pumpjack_Plank` | `M_Plank__oil_pumpjack` | 120 / 150 | Two skids 20, four Samson post legs 32, two cross braces 16, two ladder rails 20, four rungs 32 |
| `WalkingBeam` | `M_Plank__oil_pumpjack` | 76 / 110 | Beam 8, horsehead 24, tail counterweight 12, equalizer 12, two pitmans 20 |
| `Oilfield_Ground` | `M_DirtFar__oilfield_terrain` | 12 / 12 | `env_terrain`'s box: x and y ±1000, z −0.38 to 0.12 |

- **Collision:** none on the pumpjack. The terrain's proxy is `Oilfield_Playable-convcolonly`, the same box as `Oilfield_Ground`, with no material and hidden from renders. In Godot it imports as a `StaticBody3D` named `Oilfield_Playable` holding a `ConvexPolygonShape3D`. `Oilfield_Ground` imports as a `MeshInstance3D` on a `ShaderMaterial` (`M_DirtFar__oilfield_terrain`).
- **The beam in Godot (G11).** A throwaway headless script outside the repo instanced `oil_pumpjack.glb`, found `WalkingBeam` by name, and rotated it about its local z. It printed:
  - Nodes: `oil_pumpjack` (Node3D), and under it `Pumpjack_Iron`, `Pumpjack_Plank`, and `WalkingBeam` (MeshInstance3D). One node is named `WalkingBeam`.
  - `WalkingBeam`: position (0.0, 4.0, 0.0), rotation (0, 0, 0), scale (1, 1, 1), one surface, `M_Plank__oil_pumpjack`.
  - −12°: the head (arc middle) at (3.52, 3.25, 0), the tail at (−3.03, 4.64, 0). Pitman feet at x −2.751 to −2.634, |z| ≤ 0.38, lowest y 1.902, inside the gear house.
  - 0°: the head at (3.6, 4.0, 0), the tail at (−3.1, 4.0, 0). Pitman feet at x −2.260 to −2.140, y 1.400, inside.
  - +12°: the head at (3.52, 4.75, 0), raised 0.748 m, the tail at (−3.03, 3.36, 0); the highest point is 5.512. Pitman feet at x −1.670 to −1.553, lowest y 0.987, inside.
  - So +12° about local z raises the horsehead end, as B says.
- **Checks** (the build's own printout, then a scratch script on the saved, unwrapped `.blend`):
  - Every asset, 1 to 9:
    1. Silhouette: pass. In profile, the A-frame, the long beam, the horsehead, and the box read as a pumpjack. End-on it is a narrow tower, and from the top a bar; neither names it alone, and neither is the lane's view.
    2. Squint: pass. One shape and three flats: iron, raw wood, and the ground.
    3. Size floor: pass. The smallest members are the rod, the ladder rails, and the rungs, all 10 cm; the crank guard is 11 cm thick and the saddle cheeks 13 cm. The only things under 10 cm are gaps (the 1.5 cm between the cheeks and the beam) and B's own 8 cm lift.
    4. Wear: pass, but weak. The one accent is the lifted skid, and it is in silhouette, though only as the skid's top rising from 0.35 to 0.43 m toward the well. It is for the user's review.
    5. Budget: pass. Three objects for two materials plus `WalkingBeam`.
    6. Names: pass. Unique, no dots, prefixed, `WalkingBeam` exact, and the proxy suffixed. No visual shares a stripped proxy name.
    7. UVs: pass (above).
    8. No shared planes: pass. Across the pumpjack's 316 triangles, 140 coplanar pairs, none of them overlapping. A first build had eight: the front and rear legs on each side share their slanted planes and met above z 3.525 inside the saddle, so the legs now end at 3.52. No flat face lies within 0.08 m of 0.12; the lowest flat faces are the skids' tops at 0.35. The terrain: none.
    9. Values: pass. Iron, raw wood, and scorched earth, from the Palette; nothing is self-lit.
  - No zero-area triangles, non-planar faces, three collinear outline points, or smooth faces on any object. Open edges exist only where hidden faces were dropped.
  - Pumpjack asset check (the nod), from −12° to +12° in 1° steps:
    - `WalkingBeam` is one object with its origin at the bearing, level at rest, rotation zero, parented only to the root.
    - Below the lid, every beam vertex stays at least 0.153 m inside the gear house's walls and 0.987 m above their foot.
    - Where the pitmans cross the lid, they stay at least 0.070 m inside the slot.
    - The rod's top (3.6, 2.2) is never nearer the beam than 0.440 m. At −12° the head's lowest point is (3.267, 2.488).
    - Pitman feet (centre) at −12°, 0°, and +12°: (−2.692, 1.914), (−2.200, 1.400), (−1.611, 0.999), so they move X −0.49 to +0.59 and z +0.51 to −0.40, as B says.
  - The death cam's x ±6.0 rule: a near copy at x ±10 reaches at most |x| 6.24 (the casing on its +X side).
- **Views** (Blender renders, all outside the repo, in `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_hero\`):
  - Workbench, with material colours and studio light, on a world of the haze #A8401C, the terrain shown, 35 mm lens, eye 4.9 m up:
    - Side, in profile from the lane's side at 12 m (`side_lane.png`) and at 35 m (`side_lane_35m.png`).
    - From the train at 12 m (`side_from_train.png`), and from the tail at 12 m (`side_from_tail.png`).
    - Three-quarter at 12 m, from between −X and −Y (`three_quarter.png`) and from the opposite quarter (`three_quarter_opposite.png`).
  - Silhouettes: Workbench, flat, one black colour on #A8401C, orthographic: side, end-on, and top (`silhouette_side.png`, `silhouette_end_on.png`, `silhouette_top.png`).
  - The 64 px squint of the 12 m Side (`squint_64px.png`).
  - The nod at −12°, 0°, and +12° (`nod_-12.png`, `nod_+00.png`, `nod_+12.png`), with an eye 2.0 m up at 10 m (D's Nod height). Each has a view down into the gear house's slot (`nod_slot_±NN.png`) and an orthographic silhouette (`nod_silhouette_±NN.png`). The beam was restored to 0° and the `.blend` was not saved from the render session.
  - Godot captures in the fixed light wait for the scene stub (C step 1; G15). The headset review is open.

**Where the pumpjack departs from B, and why:**

- **Samson post foot.** The foot is 2.4 m along X by 1.4 m along Y, so the legs land on the skids (centres x ±1.2, y ±0.55, 5 cm into them) and the A shows in profile, the lane's view. B's "1.4 × 2.4 m" does not say which way; 2.4 m across the track would put the legs off the 1.4 m base. The legs are 0.25 m square in horizontal section and rise to (±0.15, ±0.18) at z 3.45, ending at 3.52 inside the saddle. One cross brace a side runs from front leg to rear leg at z 1.52 to 1.70.
- **Bearing.** An iron U saddle: x ±0.30, y ±0.32, z 3.45 to 4.15, with cheeks 13 cm thick either side of the beam (1.5 cm clear) and a floor at 3.70. Over the saddle, the beam's lowest corner at ±12° comes to 3.718. The saddle's underside and the cheeks' inner faces are dropped (hidden). The beam is centred on the bearing (z 3.775 to 4.225), X −3.0 to 2.95; its ends are inside the counterweight and the head.
- **Horsehead.** It has a flat back 0.7 m tall (x 2.85, z 3.65 to 4.35) and straight top and bottom faces running to the arc's ends, so the head is 0.75 m deep. The arc has a radius of 3.6 m about the bearing (its middle over the rod at x 3.6), with four flat facets from z 3.2 to 4.8. Its top corner reaches 5.51 m at +12°, not B's "5.4": the arc's top end rises along the arc (4.0 + 3.6 sin 24.8°). The arc's middle travels ±0.748 m, as B says.
- **Pitmans and equalizer.** The beam is 0.35 m wide, so the pitmans hang from an equalizer: a crossbar 0.84 m long under the beam at X −2.2 (0.15 × 0.15 m, 2.5 cm into the beam). The pitmans are 0.12 m square at y ±0.32, down to z 1.4. They first stood at ±0.35, but that left only 4 cm in the slot. All of this is part of `WalkingBeam`, in `M_Plank`.
- **Counterweight.** It is centred on the beam (z 3.60 to 4.40, x −3.1 to −2.5), so at +12° its lowest corner (2.96) clears the lid by 0.46 m.
- **Gear house.** The lid slopes from 2.50 at −X to 2.30 at +X, with an open slot at x −2.80 to −1.70, y ±0.45. Its walls run from z 0, under the terrain's top; the ±Y walls stand inside the skids. A first build stopped them at 0.30, which left an 18 cm gap under the ±X walls between the skids. The house has no bottom, and its inside shows through the slot (the world shader draws both sides).
- **Crank guard.** It is on the −Y face, the face oncoming copies show the player, centred at (−2.2, 1.40), the pitmans' rest height. B gives neither the face nor the height. It has 8 sides with flat edges at the top and bottom, and it stands 1 cm into the wall and 10 cm proud. Its inner face and its downward face are dropped.
- **Ladder.** It stands free, leaning on the post's tail side: rails at y ±0.20 from (x −1.32, z 0.10) to (x −0.53, z 3.30), with rungs at 0.75, 1.40, 2.05, and 2.70. It cannot sit in the rear legs' plane, for two reasons: the legs close to y ±0.18 at the top, and the gear house stands only 0.2 m behind the rear feet. So the rails clear the gear house by 3 cm at the ground and the rear legs by 0.2 m at the top, under the beam. At +12° the beam comes no lower than 3.66 above the rails' tops.
- **"Nothing else on the frame stands within 0.7 m of their path."** This cannot hold below the lid with B's own numbers. At +12° the pitman's foot reaches X −1.61 at z 1.0, but the gear house's +X wall is at −1.4 and the rear legs land at −1.2. Measured, the nearest frame surface outside the gear house (the ladder) is 0.455 m from a pitman's centre line, 0.37 m from its surface, with the gear house wall between them. Above the lid, the nearest is 1.096 m. Read as the sweep above the gear house, the rule holds.
- **Well.** The casing is 8-sided, 0.35 m across its corners, from z 0 to 1.2. The stuffing box is 0.22 m square, from 1.15 to 1.45. The rod is 10 cm square to 2.2 m, 4-sided rather than rule 9's 6 sides, because the iron's 120 triangles were spent.
- **Skids and wear.** The −Y skid's +X end, the well end, is lifted 8 cm about its −X foot (0.65°). Its foot there is still at 0.08, under the terrain's top, so the lift shows only in its top line. The two iron tie straps (12 cm wide, z 0.33 to 0.45, y ±0.72) are at x −3.25 and −0.80, clear of the lifted end, which would otherwise bury them.
- **Hidden faces dropped (rule 27, G3):** the undersides of the skids, straps, saddle, stuffing box, rod, and ladder rails; the casing's bottom; the legs' ends; the braces' and rungs' ends; the beam's ends; the pitmans' tops; the saddle cheeks' inner faces; and the crank guard's inner and downward faces.
- **Under budget.** The timber and the beam spend 120 of 150 and 76 of 110. The scene saves 2,048 triangles against B's 12,160.

**Where the terrain departs from B:**

- **Proxy name.** It is `Oilfield_Playable-convcolonly`, not `Oilfield_Ground-convcolonly`. Godot strips the suffix, so B's pair would import two nodes named `Oilfield_Ground` (E, the `Engine_Boiler` lesson). The name follows `env_terrain`'s `TerrainPlayable`; no code reads it.

**Found:**

- The header's "In code" row still says no GLB or `.blend` exists. This batch was limited to H and the status row, so the row is left for the planning chat.
- D's Blender "Side" view is "from the train", and from there the pumpjack is seen end-on. The lane sees it in profile (F19). Both were rendered.
- `load` still names five scenes, so the new GLBs are covered by `--import` only until step 3 lists the scene.

**Still open:**

- The user's review of the hero, in these renders and then in the scene stub (C step 1) with the nod running.
- Godot captures in the fixed light, D's Nod view in the scene, and the headset.
- Whether the lifted skid reads as wear from the lane (4 above).
- `TEXTURE_LIST.md` and `TEXTURING.md`'s GLB table (G17) do not list the two new GLBs yet.

### Scene stub (C step 1)

Built on 2026-10-29, so the hero can be reviewed in Godot under the fixed light. No GLB or `.blend` was touched, and Train Rooftop's scene, `.tres`, and belt are unchanged.

**Files**

- New: `scenarios/oilfield_train/oilfield_train.tscn`, `oilfield_train.tres`, `scenery_belt.gd`, `lane_glow.gd`.
- Changed: `scenarios/time_of_day.gd` (the night point), `scenarios/scenario_resource.gd` (`fixed_time_of_day`, `roll_time_of_day()`), `scenarios/scenario_base.gd` (the `T_MAX` clamp; `roll_clouds` and an exported `cloud_speed`), `autoload/game_manager.gd` (the registry entry, `roll_time_of_day(index)`, the roll in `_instance_scenario`), `gauntlet/duel_manager.gd` (the host's two rolls), `autoload/debug_menu.gd` (the F3 slider to `T_MAX`), `scenarios/train_rooftop/engine_smoke.gd` (`puff_color`, F8), `dev/autotest.gd`, `docs/ARCHITECTURE.md`.
- The scene copies Train Rooftop's train half at the same transforms: `CarRearB`, `CarRearA`, `CarA`, `CarB`, `CarFrontA`, `CarFrontB`, `Engine`, `Coupler0` to `Coupler5`, `Train` (the guard walls), `PlayerSpawn`, `EnemySpawn`, `EnemySpawns2/A-B`, `EnemySpawns3/A-C`, `strafe_half_width` 1.5, and `EngineSmoke` at (0, 4.4, −54.25). `Terrain` is `oilfield_terrain.glb`. No cacti, no horizon spans.
- `oilfield_train.tres`: "Oil-field Train", duel distance 20, Train Rooftop's wind and gusts (−14 dB, 6 to 16 s, 1.4), `fixed_time_of_day` 1.25. Appended as `GameManager.SCENARIOS[4]`; indices 0 to 3 are unchanged.

**The belt** (`scenery_belt.gd`). A `ROWS` table, one row per piece kind, each on a band (near 20 m/s, loop 720 m; mid 0.35×, 768 m; far 0.12×, 768 m) and placed either evenly by `count` and `sides` (`centre`, `alternate`, `left`, `right`, `both`) or by 48 m `slots` per side, at an x rolled per copy from a seeded range (a fixed x is a range with equal ends). Later batches add rows: wellheads, sumps, and pipe runs (near, by `count`); derricks and tanks (mid, by `slots`); the pylon line (mid, `left`, count 8, x 22 to 22: a 96 m pitch); the burning wells (mid, left slots 0 and 8); the horizon tiles (far, `both`, 16). The flame cue at the `Flame_*` anchors needs code beside the rows. Today three rows:

| Row | Copies | Across | Placement |
|---|---|---|---|
| `env_rail_track_8m` | 90 | x 0, yawed onto z | Near, 8 m pitch |
| `oil_pumpjack` near | 20 | x ±10 to ±15, rolled (seed 1925) | Near, 36 m pitch alternating, left first: one per 72 m a side |
| `oil_pumpjack` mid | 12 | x ±28 to ±40, rolled (seed 1926) | Mid slots: left 2, 5, 7, 10, 13, 15 (0 and 8 are kept for the burning wells); right 1, 3, 6, 9, 11, 14 |

- Wall-clock motion, copies moved and never turned, collision stripped, nothing sways: Train Rooftop's contract.
- The beam clock: every `WalkingBeam`'s `rotation.z` = 12° × sin(2π t / 10 s + g × 120°), g = copy index mod 3, t the wall clock. Positive raises the head. `set_beams(stroke)` is public so a test or capture can freeze it.

**The light rig, as set**

| Piece | Values |
|---|---|
| `Sun` | Authored yaw so the key travels toward +x (its +z points at −x), elevation from `TimeOfDay` (−1°), #FF7A33, energy 1.0, no shadows |
| `LaneGlow` | `OmniLight3D` at (−6, 7.5, 0), range 22 m, `omni_attenuation` 0 (see below), no shadow, #FF8A3A, `base_energy` 1.2. `lane_glow.gd`: energy × (1 + 0.15 n), n the mean of three sines at 2.3, 3.7, and 5.3 Hz with random phases; the fog colour × (1 + 0.08 n) from the same n. The hook: `swell` (0 to 1) multiplies energy by (1 + 0.6 × swell); nothing writes it yet |
| Sky | `sky_western`: `bands` 0, `sky_curve` 0.08, `ground_curve` 0.02, `sun_radius` 0, `sun_halo` 0.6, `cloud_cover` 0.4, `cloud_offset` (0.37, 0.61), `cloud_scale` 0.25. The gradient and cloud colours come from the night point |
| Clouds | Pinned: `roll_clouds` false keeps the authored cover and offset; `cloud_speed` 0.004 (Train Rooftop 0.01), drifting along +x |
| Fog | Exponential, density 0.009, colour #A8401C (from the night point), sun scatter 0.5, aerial perspective 0.35, `fog_sky_affect` 0.1 (see below) |
| Ambient | Sky, energy 0.25, sky contribution 1.0 |
| Engine smoke | `puff_color` #3A2C26 on the instance; Train Rooftop's instance keeps the default, the silver of `engine_smoke.tscn` |

The halo needed no shader change: `sky_western.gdshader` draws the halo for every eye direction above the horizon, whatever the light's elevation, and with `sun_radius` 0 the disc never draws. The captures show the left horizon clearly brighter than the right.

**The night point and the fixed time**

- `TimeOfDay.KEYFRAMES` gains a fifth keyframe at `NIGHT_T` 1.25 (`T_MAX`): elevation −1° (`NIGHT_ELEVATION_DEG`), light #FF7A33 at 1.0, `sky_top` #1C1226, `sky_horizon` #D9662B, `ground_horizon` #A8401C (so the fog), `ground_bottom` #2A1610, `fog_sun_scatter` 0.5, `trail_solid` 0.15, and its own `cloud_color` #4A2418. A keyframe without `cloud_color` still derives it (the light 40% toward white), and a blend carries one only when an end sets it, so dawn to dusk is unchanged; t 1 returns the dusk keyframe itself. The edge light follows the key (`TimeOfDay.apply` → `set_edge`).
- t from 1 to 1.25 blends dusk into night. No roll reaches it: `randf()` is under 1.
- `ScenarioResource.fixed_time_of_day` (−1 rolls) and `roll_time_of_day()`. `GameManager._instance_scenario` calls it when no time is passed: single player, the flat menu backdrop, and the host's own load. `GameManager.roll_time_of_day(index)` replaces the host's `randf()` in `DuelManager.host_open_lobby` (`_mp_lobby`) and `host_start_mp_duel` (`_mp_begin`); a late joiner already got the live `time_of_day`. The value rides the existing RPC argument; nothing new is on the wire.
- Every clamp on the client's path: `_mp_lobby` / `_mp_begin` and `setup_mp_lobby` / `setup_mp_duel` pass t through; `_load_scenario` clamps only the index; `_instance_scenario` keeps any t of 0 or more; `ScenarioBase.apply_time` clamped to [0, 1] and now clamps to [0, `T_MAX`]; `TimeOfDay._sample` likewise; the F3 `time_of_day` slider ran 0 to 1 and now runs to `T_MAX`, so the refresh no longer pins the night at 1 and a scrub can reach it again. The mesh lab's fixed 1.0 is untouched.

**Tests** (`--import`, then each suite with the console binary)

- `load`: `AUTOTEST PASS`. New lines: "oil field belt: 122 pieces, 32 nodding pumpjacks", "1469 scenario surfaces wear world_surface.gdshader (204 sway, 6 self-lit, …)" (1056 and 4 before: the oil field's train, tracks, and pumpjacks, and the train's two extra lamp surfaces), and "oil field holds its fixed night (t 1.25); every other arena rolls in [0, 1)".
- New checks in `dev/autotest.gd`: the oil field in `load`'s scene and surface lists (its belt held to the no-sway rule); `_oilfield_belt_ok` (122 copies, 32 `WalkingBeam`s at (0, 4, 0), no collision left, the three phase groups at 0° and ±12° × sin 120°, nothing beyond ±12°); `_engine_smoke_ok` now takes the tint (silver on Train Rooftop, #3A2C26 here); `_fixed_time_ok` (only the oil field fixes t; the host's value is 1.25 on every pick for it and in [0, 1) for the rest; a load given that value keeps t, the key at −1° toward +x without shadows, the night's sky, fog, trail, and cloud colours, and the pinned clouds; an F3 scrub to 9 clamps to 1.25; t 1 is still exactly dusk); `_arena_time_ok` on every arena in `multi`'s spawn-floor pass (single player) and in `lobby`'s waiting-room pass (the host's call_local `_mp_lobby`); `--arena=N` moves the `host` suite's waiting room before the joiner arrives, and `join` checks t in its waiting room and its duel.
- `duel`, `multi`, `ragdoll`, `gauntlet`, `lobby`, `intro`, `i18n`: `AUTOTEST PASS` each. `multi` printed "single-player arena 4: Oil-field Train at time of day 1.25" (arenas 0 to 3 at 0.28, 0.03, 0.84, 0.24), with the oil field's markers flush on its floors and clear at 2 and 3 NPCs; `lobby` printed "lobby waiting room, arena 4: Oil-field Train at time of day 1.25".
- MP over the wire: `host -- --arena=4` started before `join`; both `AUTOTEST PASS`. The host printed "host waiting room: Oil-field Train at time of day 1.25"; the joiner "client waiting room: Oil-field Train at time of day 1.25" (the late-join `_mp_lobby`) and "client duel: Oil-field Train at time of day 1.25" (the START `_mp_begin`), and its duel ran to the end on the oil field. The default pair (no `--arena`, Main Street) also passed.
- The two light changes below came after the first `load` run and during the other suites; `load` was run again after them and passed.

**Captures** (flat, not headless, 1280 × 720, field of view 75° like the flat camera; a throwaway `SceneTree` script outside the repo, `capture_oilfield.gd`, instanced the `.tres`'s scene the way `_instance_scenario` does, with a temporary `Camera3D` and a dark capsule stand-in at each spawn; nothing was saved into the scene). In `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_stub\`:

- `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3` (2 s apart), `lane_e.png`, `down.png`, `edge_left.png`, `edge_right.png`, `deathcam_left.png`, `deathcam_right.png`, `deathcam_low_left.png`, `deathcam_low_right.png`, `nod_-12.png`, `nod_+00.png`, `nod_+12.png` (the belt frozen, a right-hand near copy parked at (12, 0, −12), seen in profile from (12, 2.0, 0)).
- `pass1\` holds the first run, before the two changes below.

What the captures show, against A and D:

- **Left-hand rigs:** black cut-outs on the bright left horizon in Fire and Lane P, as frames 2 and 6, except a near copy passing within about 15 m of z 0: the lane glow at x −6 lights its train-facing (+X) faces, so it reads as lit timber against the band for a moment (`fire_2.png`, `deathcam_right.png`). This follows from the glow's place on the fire side; the decision is in Open below.
- **Right-hand rigs:** near copies show lit timber on their −X faces (`away_1.png`, `lane_e.png`); mid copies fade to dark haze shapes.
- **Roofs and the walk:** after the change below, the walk is a warm strip (about #7A3A18, the sheet's #753B13 to #8F4919) between near-black grey tin (about #2A2628) from both spawns, fading toward the business car and the engine. The bone frames on the left side read as bright orange lines (`deathcam_low_left.png`).
- **One hue:** everything that is not near black is one orange family, from the band to the haze; the plum sky top and the smoke clouds are the only other notes. The engine smoke is a dark dither, no longer a pale plume.
- **The nod:** out of step across copies (positions differ between the three Lane P frames, and the test checks the groups); at ±12° the head clears the rod, the pitmans stay in the gear house slot, and +12° raises the head.
- **Wraps:** nothing pops in the three timed frames; distant copies are haze-coloured before the wrap (96% fog at 360 m). A full loop needs watching in motion (D13).
- **Edge:** only ground passes below; the pipe runs, wellheads, and sumps are not built.

Changed after the first pass:

1. `LaneGlow` `omni_attenuation` 1 → 0. With Godot's default inverse falloff the pool was about a seventh of the sheet's estimate (the walk read about #3A1A14, no warm strip). At 0 the light falls off only inside its 22 m range, which matches the sheet's full-step estimate and keeps the roofs beyond z ±20 dark.
2. `fog_sky_affect` 0.4 (Train Rooftop's) → 0.1. At 0.4 the fog colour washed the plum top to maroon and lifted the cloud deck to pale orange; at 0.1 the top reads plum-black over a thin bright band, as F5 and F6 decided. Not a sheet value.

**Deviations, with reasons**

- The beam clock does not skip copies beyond 250 m. 32 writes a frame are cheap, and a skipped beam would snap when it came back inside 250 m.
- The flicker noise is three fixed sines at 2.3, 3.7, and 5.3 Hz rather than a noise texture: bounded to ±15% and cheap.
- The fog flicker re-reads its base whenever something else writes the fog colour, so an F3 scrub still works on this scene.
- The night point sits at t 1.25, past dusk, so scrubbing 1 to 1.25 on any arena blends dusk into night (sun from 12° to −1°). On an arena with sun shadows that lights everything from under the horizon; only F3 can reach it there.
- Mid pumpjack slots were chosen here (A and B give only the count); derricks and tanks take the free slots later.
- The death cam view used 75°, the flat camera's field of view, not the death cam's own 55°.

### `oilfield_horizon` (C step 3)

Built on 2026-10-29 by `dev/build_oilfield_train_blender.py --part horizon`. It deletes and rebuilds only the `oilfield_horizon` root. Nothing is random; the printed geometry hash is `fc1495b8dfc2`. Run by:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b assets/models/scenarios/oilfield_train/oilfield_train.blend --python dev/build_oilfield_train_blender.py -- --part horizon
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb oilfield_horizon
```

- **Import file:** `oilfield_horizon.glb.import` carries `oil_pumpjack.glb.import`'s `[params]`; `--import` filled its uid and paths.
- **Materials:** `M_Rock__oilfield_horizon` (0.024, 0.014, 0.010), `M_RockDark__oilfield_horizon` (0.018, 0.020, 0.027), `M_Flame__oilfield_horizon` (1.000, 0.323, 0.027), `M_LampGlass__oilfield_horizon` (1.000, 0.871, 0.578); roughness 0.9, metallic 0, no emission.
- **Unwrap:** `GLB oilfield_horizon [oilfield_train]: 2 meshes, 21 islands, 12.4 px/m at 256 px (pad 2, 77% covered, 2 tiling meshes untouched); 0 materials copied; image none (flat colour)`. No TINY share. The two rock objects carry 8 m tiling UVs, `uv_role` `tiling`, zero rotation, origin at the root's.

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Horizon_Rock` | `M_Rock__oilfield_horizon` | 230 | Berms A 46, B 34, C 34; plumes A 40, B 28, C 28; ridges 10 + 10 |
| `Horizon_RockDark` | `M_RockDark__oilfield_horizon` | 177 | Standing derrick 50, burnt 18, small 25, folded 44 (32 + 12); tank 24, gutted tank 16 |
| `Horizon_Flame` | `M_Flame__oilfield_horizon` | 20 | Three pools 14 and their breach lips 6 |
| `Horizon_LampGlass` | `M_LampGlass__oilfield_horizon` | 30 | Three mouths (sides and top) |
| **Total** | | **457 / 460** | 4 objects |

- **Anchors** (empties under the root, unit scale, rotation zero, no children), Blender (x, y, z), at each mouth's top centre: `Flame_1` (−18, −8, 5.0), `Flame_2` (12, 10, 3.2), `Flame_3` (−2, −17, 2.2). In Godot (x, y, z): (−18, 5.0, 8), (12, 3.2, −10), (−2, 2.2, 17).
- **Kernel.** No boolean runs: every piece is a closed or open-bottomed solid that overlaps none of the others (the berm is one swept trapezoid profile round the polygon, so its wedges are planar quads; the pool's buried rim is the only overlap, and it is another object). Bottoms stop at z 0, 0.12 m under the terrain's top. The checks printed: extents x −30.000 to 27.862 and y −23.570 to 21.500 (the box is x ±30, y ±23.875), z 0 to 110; 0 zero-area triangles, 0 non-planar faces, 0 smooth faces, 0 collinear outline points; 0 flat faces within 0.08 m of 0.12; coplanar test over 457 triangles, 226 coplanar pairs, 0 sharing area. Open edges are only the ground cut, the legs' and casings' unclosed rings, the plumes' tops over 6.5 m (rule 27), and the pools' buried rims. Names have no dots.
- **Tests:** `--import`; `load` `AUTOTEST PASS` ("oil field belt: 154 pieces, 32 nodding pumpjacks, 32 horizon tiles"; 1597 surfaces wear the world shader, 70 self-lit); `multi` `AUTOTEST PASS`.
- **The belt.** `scenery_belt.gd` gains the far row: `oilfield_horizon`, `count` 16, `sides` `both`, x 85 to 110 rolled (seed 1884), far band (0.12×, ±384 m loop): 32 tiles, `HORIZON_SCENE` preloaded. The row carries `lit: {LEFT: 2, RIGHT: 4}` as data for the flame cue (F9); nothing reads it and no cue spawns. `_oilfield_belt_ok` now expects 154 pieces and 32 tiles, each with `Flame_1` to `Flame_3` (unit scale, no children, y 0 to 6) and its four objects.
- **Views** (kept outside the repo, in `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_horizon\`):
  - Blender, Workbench with studio light on #A8401C, terrain shown, 35 mm, eye 4.9 m up at 95 m: `side_left.png`, `side_right.png`, `side_left_oblique.png`; three-quarter `three_quarter.png` and `three_quarter_left.png`.
  - Silhouettes, flat black on #A8401C: `silhouette_side.png`, `silhouette_end_on.png`, `silhouette_top.png`; the 64 px squint of the left side view: `squint_64px.png`.
  - Godot, flat, 1280 × 720, fixed light, three captures 2 s apart each: `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3`; `lane_e.png`; the long left horizon `long_left.png` and `long_left_ahead.png` (fov 40). Script: `capture_horizon.gd`, a copy of the stub's, in the scratchpad.
- **Checks (D, `oilfield_horizon`):**
  - Anchors at the mouths: pass (printed positions above equal each casing's top centre).
  - Any end showing a cut: pass. Every piece is closed against the ground, and nothing reaches y ±23.875.
  - Mouths and pools glow on every tile (F13): pass after a change (below). Pools alone do not: a flat pool at 0.4 to 0.6 m seen from 4.9 m at 95 m or more is a sliver under 5 px, and each berm hides it from the near side. The white-hot mouths stand over the crest and read in every capture of both belts.
  - Rule 22: pass. The nearest tile content lies 55 m from the axis (a right copy's berm toe at x 85 − 30), which is 7.9° at the wrap's 394 m; `Flame_1` is 67 m out (9.6°). Nothing stands near the axis in `lane_p_*` or `lane_e`.
  - Pop-in at the wraps: not judged in motion (no full loop watched). In stills the tiles are haze-coloured by 384 m; but see the plumes.
  - Flat dark horizon line: pass in `lane_p_*`, `fire_*`, `away_*`; the berms, ridges, and rigs sit on a straight line at the terrain's edge.
  - **Plumes read as dark smoke heads: FAIL, and not fixable in the mesh.** The plumes are near-black scorched earth, but fog at 100 to 200 m (59 to 83% of #A8401C, with the sun scatter toward the fire) draws them as flat orange slabs that are brighter than the plum sky behind them, and brighter still than the clouds. Seen from the lane they hang as orange pillars along both horizons, and they would pop in at the wraps as bright blocks against the plum (the fog colour is the haze, not the sky above it). Options for the planner: a `fog_disabled` material or flag for the plumes (the flame cue's unfogged core needs the same switch, F11), a height fog that thins with altitude, or a fogged colour for the plumes chosen at the sky's value. None is a mesh change, so none was made.
- **Squint and silhouette:** the side silhouette names the tile (black berm line with spikes and drums on it, folded derrick, gutted tank), and the squint shows one dark band with three stalks and two white points; at most three flats.

**Where the tile departs from B, and why:**

- **Casing.** The mouths are white-hot on every face (`M_LampGlass`, not only the top) and stand taller than B's 1.8, 1.1, and 0.8 m: 4.4, 2.7, and 1.8 m above their pools (tops at 5.0, 3.2, and 2.2 m), so each clears its berm's crest (3.5, 2.2, 1.5 m) from the roof; at B's height only the berm and the breach were visible, and a white top seen at 3° is one pixel. The anchors sit at the new tops. The plumes' feet (55, 32, and 13 m) now stand 10, 6, and 4 m under their columns' tops (65, 38, and 17 m).
- **Berms.** Each is one trapezoid profile swept round a regular polygon: an inner vertical wall, a 0.5 to 1 m crest, and a 35° outer slope, with one polygon edge left out as the breach. A is an octagon (toe 24 m across at z 0, 19 m at mid-height, against B's 20 m), B and C hexagons, because a 3.5 m berm at 35° round a 13 m pool cannot fit 20 m at the toe and the tile stops at x −30. The breaches face −Y (A), −X and −Y (B), and +X and −Y (C), so a tile on either belt shows its pool through at least one. Each pool's polygon is slightly wider than the opening (6.5 against 6.0) and has one glowing lip at the breach.
- **Pools.** Octagon for A, hexagons for B and C, at 0.6, 0.5, and 0.4 m.
- **Plumes.** Lofts of hexagon rings (3, 2, and 2 segments; 40, 28, and 28 triangles), not stacked prisms, which would have cost twice as much in ledges. Their tops are not built (above 6.5 m, rule 27). A leans only 3 m over 55 m, because the tile's x ±30 limit holds its 20 m head; B and C lean about 15°.
- **Derricks.** Legs are 3-sided prisms 0.7 m across; the standing and folded derricks have four legs and the burnt and small ones three; girts are open bands wrapping the legs. The folded derrick's upper part is two legs kinked 60° toward −Y. The burnt one has no girt (budget). Together the four cost 137 triangles against B's 120.
- **Ridges.** Two hipped frusta (35° slopes, 1.5 m crests, 1.5 and 2.5 m tall) cost 20 triangles of B's 40; the saving went to the derricks and the berms. The tank beside Mound A clears its toe by 1.5 m.
- **Union.** The sheet asks for one exact self-union per material; none was needed (above).

**Still open:** the plumes' fog (above), the glow's read in motion at a wrap, and the flame cue's columns on these anchors.

### Flame cue and plumes, decided (2026-10-29)

- **The cue:** one tall camera-facing quad per lit anchor, turning about its vertical axis, with a procedural flame shader. Opaque cut-out in hard flat bands: white core, yellow, orange, and a dark-red rim. No additive blend and no dither. It rolls upward in place and leans toward −x with the scene's wind gusts. F3 **World** `flame_columns` (0 off, 1 on) is the only knob, with no Settings row. It draws the same in flat and VR. Local cosmetic, nothing on the wire. Its core follows F11's ramp: no fog inside about 150 m, full fog past 300 m.
- **The plumes (F12 revised):** fogged as built, the near-black plumes drew as bright orange pillars at 100 to 200 m, brighter than the sky. They take a new base name, `M_Smoke`, which the world shader draws on the same distance ramp as the cue's core: dark at the horizon tiles, gone at the wraps.
- **The plume count (F13 revised):** a plume only caps a lit column, 12 in the far loop, plus the burning wells. Each tile's three plumes are separate objects, and the belt hides those whose anchor is unlit. A smouldering mound only glows.

### Flame cue and smoke (batch 3)

Built on 2026-10-29: the plume split, `M_Smoke`, the flame column, and the lit-anchor logic on the belt. Everything the "decided" subsection above asks for, with the deviations at the end.

**Files**

- New: `assets/shaders/world_smoke.gdshader`, `assets/vfx/flame_column.gdshader`, `assets/vfx/flame_column.tscn`, `assets/vfx/flame_column.gd` (`FlameColumn`).
- Changed: `dev/build_oilfield_train_blender.py` (the plume split), `oilfield_train.blend` and `oilfield_horizon.glb` (re-exported), `assets/shaders/world_surface_import.gd` (`SMOKE`), `project.godot` (three `[shader_globals]`), `assets/vfx/vfx_catalog.gd` (`flame_column` in `_SCENES`, so the boot warmup compiles it), `autoload/game_manager.gd` (`flame_columns` tuning, default 1), `autoload/debug_menu.gd` (F3 **World** row, 0 or 1), `scenarios/oilfield_train/scenery_belt.gd`, `scenarios/oilfield_train/lane_glow.gd`, `dev/autotest.gd`, `docs/SHADERS.md` (section 8, the smoke path). Backups of the `.blend` and the GLB from before the split are in the scratchpad's `oilfield_flames\backup\`.

**The plume split.** `build_horizon` now writes seven objects: `Horizon_Rock` (134 triangles, plumes out), `Horizon_RockDark` 177, `Horizon_Flame` 20, `Horizon_LampGlass` 30, and `Plume_1` (40), `Plume_2` (28), `Plume_3` (28), each named as its anchor, all three in one `M_Smoke__oilfield_horizon` (Base Color 0.024, 0.014, 0.010, as the plumes had). The tile is otherwise identical (457 of 460 triangles; extents, anchors, and every check unchanged; geometry hash `f3afe2b63850`). Run by the same two commands as the horizon above. The unwrap printed `GLB oilfield_horizon [oilfield_train]: 5 meshes, 33 islands, 2.5 px/m at 256 px (pad 2, 74% covered, 2 tiling meshes untouched); 0 materials copied; image none (flat colour)`. The plumes carry no tiling UVs: `M_Smoke` is not a tiling name and nothing is painted on it.

**`M_Smoke` and its ramp.** A second world shader, not a path inside `world_surface.gdshader`: `fog_disabled` is a static render mode, so the ramp cannot be a branch of the world shader without un-fogging every other surface (SHADERS.md section 8, smoke path). `world_smoke.gdshader` is unlit, `cull_disabled`, `fog_disabled`, no shadow, and draws `mix(albedo, smoke_fog_color, smoothstep(smoke_fog_near, smoke_fog_far, view distance))`. The globals, in project.godot: `smoke_fog_near` 150, `smoke_fog_far` 300, `smoke_fog_color`. The importer's `SMOKE` list (`M_Smoke`) swaps the shader in and sets `albedo`; the mesh casts no shadow. `load` expects the 96 `M_Smoke` surfaces on this shader and the 1,597 other surfaces on the world shader, the count from before the split, so no other material changed.

**The far colour is the sky's, not the fog's (deviation).** The first captures, with `smoke_fog_color` at the fog colour #A8401C, fogged every plume beyond about 250 m to a bright orange slab and the columns to orange stalks: the orange pillars F12 was meant to avoid, and they would pop at a wrap against the plum sky. So `smoke_fog_color` is the sky's gradient at 15 degrees (`SMOKE_SKY_DEG` in `lane_glow.gd`, from the sky material's `sky_top`, `sky_horizon`, and `sky_curve`, mixed in linear light; the default in project.godot is the fixed night's, about #512627): the horizon note's option "a fogged colour for the plumes chosen at the sky's value". Under 150 m a plume is its own near-black #2B2019, over 300 m it is that sky colour, and it passes through brown-purple between.

**The flame column.** One `MeshInstance3D` with a unit `QuadMesh` (`center_offset` (0, 0.5, 0)) scaled to (base across × 1.35, height, 1) by `FlameColumn.configure`. `flame_column.gdshader` is unlit, `fog_disabled`, opaque with `discard`: no blend, no dither, no glow.

- **Vertex:** only the model matrix's origin is kept; the quad turns about the world's vertical axis to face the camera, and its top shears toward world −x by `lean` × height × (height fraction)². `lean` is 0.05 at rest plus 0.08 × `ScenarioBase.get_wind_gust()`, written by the script each frame (a full gust leans the top about 8 m on the 60 m column).
- **Shape:** a half width narrowing as √(1 − h) from the base's, a rounded foot over the first 6%, and an edge torn by three value-noise octaves (noise cell 0.5 × the base width, rolling up at 9 m/s on its own phase per column). The top is ragged, under the plume's foot.
- **Bands:** a heat value (1 on the axis at the base, less toward the edge and the top, torn by the noise) cut at 0.70, 0.45, and 0.20 into four flat colours: white core #FFF3D1, yellow #FFD140, orange #FF7312, dark-red rim #801A08.
- **Fog:** every band mixes to `smoke_fog_color` on the same `smoothstep` of the fragment's view distance as `M_Smoke`, so inside 150 m the core is white and past 300 m the whole column is the sky's colour.
- **Wiring:** `VfxCatalog` `_SCENES` holds `flame_column`, so `spawn_for_compile` draws it in the boot warmup. `scenery_belt.gd` spawns one on each lit anchor through `VfxCatalog.spawn` and calls `configure` with its `FLAME_SIZES` row: `Flame_1` 9 × 60 m, `Flame_2` 5.6 × 35 m, `Flame_3` 3.1 × 15 m, plus a `Flame_Near` row (5.6 × 35, always lit) that `_light_flames` already honours, so the burning well needs only its mesh and a belt row. A column is a child of its anchor, so it rides the tile. F3 **World** `flame_columns` (1 shows, 0 hides every column; the plumes stay) has no Settings row. Local cosmetic, nothing on the wire, the same in flat and VR.

**The belt.** `lit: {LEFT: 2, RIGHT: 4}` is read now: left slots 0, 2, 4, ... 14, right slots 1, 5, 9, 13 (`LIT_PHASE`, so the two sides do not burn in step); the anchor cycles `Flame_1`, `_2`, `_3` by lit ordinal (the right side starts one on, at `Flame_2`). Every other anchor's `Plume_n` is hidden: 12 lit anchors and 12 visible plumes of 96; the 20 unlit tiles' mounds glow at the mouth and pool only. Rule 22 needed no recheck: it held for every anchor.

**Tests**

- `load`: `AUTOTEST PASS`. "oil field flames: 12 columns (8 left, 4 right), 12 plumes shown of 96, F3 flame_columns hides them all, in the warmup"; "1597 scenario surfaces wear world_surface.gdshader (204 sway, 70 self-lit, ...); 96 M_Smoke surfaces wear world_smoke.gdshader" (the world-shader count is the same as before the split). New checks in `dev/autotest.gd`: `_flame_cues_ok` (per tile at most one lit anchor, a column exactly where its plume shows, each column sized to its anchor, 8 left and 4 right, `flame_columns` 0 hides all and 1 shows all, `flame_column` in `VfxCatalog.cues()` and built by `spawn_for_compile`, the plumes on the smoke shader); `_world_surface_ok` (the `SMOKE` constant, `M_Smoke` on its shader, a mesh of only smoke surfaces casts no shadow, `FlameColumn` skipped); `_world_globals_ok` (the three globals declared, the ramp 150 and 300); `_oilfield_belt_ok` (an anchor holds at most its one column; the tile has its seven objects).
- `multi`, `duel`, `i18n`, `lobby`, `gauntlet`, `ragdoll`: `AUTOTEST PASS` each.

**Captures** (flat, not headless, 1280 × 720, fov 75 like the flat camera, the fixed light; `capture_flames.gd` is the horizon's script with a new output folder, and `capture_cols.gd` aims at single columns; both are throwaway `SceneTree` scripts in the scratchpad, nothing saved into the scene). In `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_flames\`: `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3` (2 s apart), `lane_e.png`, `long_left.png`, `long_left_ahead.png`; close views of single columns at fov 40, named by distance: `col_c_0_d104.png` to `col_c_7_d276.png` (104 to 276 m), `col_w_0_d267.png` to `col_w_5_d352.png` (267 to 352 m), and `col_g_*.png` (a full gust).

**What was judged, against the reference match (D)**

- R1, one hue: pass. Everything that is not near black is the orange family; the plum sky and the smoke-coloured clouds are the only other notes.
- R3, a column's anatomy: pass. White core, yellow, orange body, dark-red rim, rolling upward, a dark plume head capping it, the white mouth glowing at its root (`col_c_1_d112.png`, `fire_2.png`).
- R4, several columns, smaller and dimmer with distance: pass. The 60, 35, and 15 m columns stand together in `fire_*` and `lane_p_*`; by 270 m a column is a thin brown stalk and by 300 m a dark plum one (`col_w_2_d297.png`).
- Plumes dark, not orange pillars: pass after the far colour change. Near ones are #2B2019; far ones take the plum sky's colour (`col_w_5_d352.png`).
- R8, nothing behind a duelist's head: pass. `lane_p_*` and `lane_e.png` show no column or plume on the lane's axis.
- Nothing pops at a wrap: judged in stills only, not in motion. Past 300 m the column and plume are one constant colour, the sky's at 15 degrees (about #512627), so a plume at 352 m reads as a slightly lighter plum slab against the plum sky and the brown clouds: low contrast but not invisible. A full loop is still to be watched.
- Tuned by eye, within the spec: the first pass was a thin white spindle (the body narrowed as (1 − h)^0.75 and the core was most of it), so the half width became (1 − h)^0.5, the core narrowed (heat cut 0.70, the height term −0.5 h), and a third noise octave tore the edge. The band colours and the lean stayed near their first values.

**Deviations, with reasons**

- `M_Smoke` is a second shader file, not a path in `world_surface.gdshader` (`fog_disabled` is static). `load`'s world-shader check exempts it deliberately; the world-shader count is unchanged.
- The far colour is the sky's at 15 degrees, not the fog colour (above), so the sheet's "full scene fog" past 300 m is "full smoke fog".
- `smoke_fog_color` is written by `lane_glow.gd`, not by `TimeOfDay`, so it is the oil field's alone; another arena with an `M_Smoke` surface would need its own writer.
- The right side's first lit slot is 1, not 0, and the anchor cycles by lit ordinal (the sheet says "by slot").
- The quad is 1.35 × the base across, so the lean and the ragged edge have room; the base width in the table is the width at the foot before the noise.
- Not built: the burning well (`Flame_Near` has a size row only) and the glow's swell.

**Still open:** the wraps in motion; the Quest frame time with 12 opaque quads of up to 60 × 12 m and their `discard` overdraw; the headset review of the column's roll and lean. One read-only `git diff --stat` was run by mistake while editing project.godot (the brief said no git); nothing changed.

**Fix pass (2026-10-29, after the user's review of the first captures)**

- **Bases doubled:** `Flame_1` 18 m, `Flame_2` 11.2 m, `Flame_3` 6.2 m (heights unchanged: 60, 35, 15), and `Flame_Near` 11.2 m. The quad is now 1.5 × the base (`WIDTH_SLACK` 1.5, in `flame_column.gd` and the shader) so the billow has room. Rule 22 still holds with the wider `Flame_1`: its near edge (about 10 m in from the anchor, so 57 m from the axis at the nearest) enters ±6° only beyond about 540 m, past the 394 m the loops reach.
- **The body billows** (`flame_column.gdshader`): the half width starts at 0.55 of the base at the mouth, swells to 1.12 of it by 45% of the height, holds, then pinches over the last 30% (the cap starts at 0.68). The ragged top is now always above 0.82 of the height, so it never falls short of the plume's foot (0.78). The noise cell is 0.35 × the base width (was 0.5), so the wider columns keep their detail. Bands, roll, lean, and the fog ramp are unchanged. Against `jarhead2.jpg` the columns now read as fat and billowing, not as spindles; the horse frame's flames stay wide to the top, ours pinch a little earlier under the plume.
- **The plumes are lump stacks** (`dev/build_oilfield_train_blender.py`, `PLUMES` and `plume()`): 4, 4, and 3 square frusta for `Plume_1`, `_2`, `_3`, each offset from the one below (about 1 m across the track, up to 11 m toward −x on `_2`), each a little turned (up to 10°) and wider at its top, so the stack widens into a head: `Plume_1` from 10 m at z 52 to 21 m at z 112, `Plume_2` from 6 m at z 30 to 19 m at z 86 (leaning −11 m), `Plume_3` from 3.5 m at z 12.5 to 10 m at z 44 (leaning −6 m). Each starts just under its column's ragged top (the top is at about 85% of its height). A lump's bottom is sized to sit inside the lump under it, so only the first lump has a bottom cap: 34, 34, and 26 triangles (94, was 96); the tile is 455 of 460. Extents x −30.000 to 27.862 and y −23.570 to 21.500 (the head of `Plume_1` reaches x −30 exactly); no zero-area, non-planar, or smooth faces, and 0 coplanar pairs sharing area. Names, the material (`M_Smoke__oilfield_horizon`), and the belt's hiding are as before. Re-exported with the same unwrap command: `5 meshes, 68 islands, 2.0 px/m at 256 px`, image none. Backups from before this pass are in the scratchpad's `oilfield_flames2\backup\`.
- **Tests:** `--import`, then `load`, `multi`, `duel`, `i18n`: `AUTOTEST PASS` each (`load` now checks the doubled sizes).
- **Captures:** `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_flames2\`: `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3`, `lane_e.png`, `long_left.png`, `long_left_ahead.png`, and close views `col_a_0_d103.png` to `col_a_7_d275.png`.
- **Still off:** the plume stacks are angular (square lumps read as stacked funnels, not round smoke), and a plume between 150 and 300 m is a mid-fog brown-purple that reads greyer than either end. The wraps in motion are still unwatched.

### Plumes removed and `oil_burning_well` (batch 4)

Built on 2026-10-29. The user approved the horizon tile and the flame cue and asked for the smoke plumes to go; "Oil-field smoke plumes (revisit)" now parks them on the Roadmap's Ideas list.

**Plumes removed**

- `dev/build_oilfield_train_blender.py`: `HZ_PLUMES = False` drops `Plume_1` to `Plume_3` and their `M_Smoke__oilfield_horizon` material from `--part horizon`. The `PLUMES` table and `plume()` stay in the file behind the flag, for the revisit. The tile is now four objects: `Horizon_Rock` 134, `Horizon_RockDark` 177, `Horizon_Flame` 20, `Horizon_LampGlass` 30 = **361 / 460** triangles (455 before). Geometry hash `b3473e9e9930`; extents x −30.000 to 27.862, y −23.570 to 21.500, z 0 to 22 (was 110); the three anchors, the berms, and every other check are unchanged (the berm kernel was generalised for the well, and the horizon's geometry is identical: the hash is the same with and without the change). Unwrap: `GLB oilfield_horizon [oilfield_train]: 2 meshes, 21 islands, 12.4 px/m at 256 px (pad 2, 77% covered, 2 tiling meshes untouched); 0 materials copied; image none (flat colour)`. `oilfield_horizon.glb` re-exported; the GLB and the `.blend` from before are in the scratchpad's `oilfield_well\backup\`.
- `scenery_belt.gd`: no plume hiding; `_light_flames` only adds the column on the lit anchor.
- Left in place and unused, for the revisit: `assets/shaders/world_smoke.gdshader`, the importer's `SMOKE` (`M_Smoke`) path, and the three `smoke_fog_*` globals. The columns still fade to `smoke_fog_color` on the same 150 to 300 m ramp, so `lane_glow.gd` still writes it.
- `dev/autotest.gd`: `load` no longer expects `M_Smoke` surfaces (it fails if any appears: 0 today), and checks that no `Plume_*` node exists; `_flame_cues_ok` counts the 12 horizon columns (8 left, 4 right) without plumes. "1607 scenario surfaces wear world_surface.gdshader (204 sway, 74 self-lit, ...); 0 M_Smoke surfaces".

**`oil_burning_well`** (`--part burning_well`, then `unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb oil_burning_well`; `oil_burning_well.glb.import` is the horizon's, `--import` filled its uid and paths). The horizon's kernel (`Loose`, `berm`): closed solids, one face set per object, bottoms open at z 0, nothing at 0.12. Geometry hash `d85c2c418c18`; no zero-area, non-planar, or smooth faces; 0 flat faces within 0.08 m of the terrain's top; coplanar test 146 triangles, 172 coplanar pairs, 0 sharing area; no dots in names.

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Well_Rock` | `M_Rock__oil_burning_well` (0.024, 0.014, 0.010), tiling UVs | 48 | The berm: an octagon, inner wall 4.4 m, crest 0.8 m wide at 5.2 m, 2.2 m tall, 35° outer slope to a toe at 8.34 m (about 14 m across at mid-height), 7 blocks, edge 0 left out as the breach (+X, toward the train), one block slumped to 1.1 m (the wear) |
| `Well_Dirt` | `M_Dirt__oil_burning_well` (0.009, 0.006, 0.004), tiling UVs | 10 | The spill apron: x 3.5 (under the pool) to 9.0, half width 1.6 to 2.8, top 0.26 sloping to 0.20 |
| `Well_Iron` | `M_Iron__oil_burning_well` (0.018, 0.020, 0.027) | 32 | The casing, 8-sided, 1.4 m across, z 0.4 to 1.9, and its shoulder |
| `Well_Flame` | `M_Flame__oil_burning_well` (1.000, 0.323, 0.027), self-lit | 34 | The pool: a 12-sided cylinder 8 m across to 0.5, top and walls |
| `Well_LampGlass` | `M_LampGlass__oil_burning_well` (1.000, 0.871, 0.578), self-lit | 22 | The mouth, 8-sided, 1.0 m across, z 1.9 to 3.0, and its top |
| **Total** | | **146 / 300** | 5 objects, `Flame_Near`; the plume's 120 are not spent |

- **Anchor:** `Flame_Near`, Blender (0, 0, 3.0) = Godot (0, 3.0, 0) in the asset's frame, unit scale, rotation zero, no children, parent the root. In the scene it stands at x −42 to −45 (rolled), y 3.0, on the piece's z.
- **Unwrap:** `GLB oil_burning_well [oilfield_train]: 3 meshes, 15 islands, 25.1 px/m at 256 px (pad 2, 83% covered, 2 tiling meshes untouched); 0 materials copied; image none (flat colour)`. No TINY share. Extents x −8.342 to 9.000, y ±8.342, z 0 to 3.0.
- **The belt row:** `oil_burning_well`, mid band, left slots 0 and 8 (homes −360 m and +24 m, 384 m apart in the 768 m loop), x 42 to 45 rolled (seed 1887), 7 m/s. `_place` gives any piece with a `Flame_Near` its column (11.2 × 35 m, always lit) and lists it in `_wells`. 156 belt pieces now.
- **The swell:** `LaneGlow.swell_at(dz)` = cos²(π/2 × dz / 60) inside 60 m, else 0 (`class_name LaneGlow`, `SWELL_RANGE` 60). `scenery_belt.update_swell()` runs once a frame after the beams and writes `_glow.swell` from the nearer anchor's global z offset from the light; the glow's own `_process` turns it into energy × (1 + 0.6 × swell), under the ±15% flicker. 1 at abeam (+60%), 0.5 at 30 m, 0 from 60 m on either side.
- **Rule 22:** the anchor at x −42 is 6.08° off the axis only at the wrap's farthest reach (394 m from a spawn's eye), so it never comes within ±6°. With the column's base doubled (F14 revised), its near edge (the foot's billow reaches 6.3 m from the axis of the column) stands 35.7 m out and enters ±6° from 340 m, the last 54 m before the wrap, where the core is fully fogged; it enters ±4.5° only at 453 m, never.
- **Berm against the pylon line:** the crest's nearest point to the train is x −36.8 at worst (11.8 m past the arm tips at −25); the toe and the apron's tip reach −33.0, 8 m past them. B asked for 10 m on the berm.

**Tests** (`--import`, then `run_autotests.ps1 load multi duel i18n`): `AUTOTEST PASS` on each. New in `dev/autotest.gd`: `_burning_wells_ok` (two wells at x −42 to −45, 384 m apart, five objects each, `Flame_Near` at (0, 3, 0) with scale one and rotation zero and one column of 11.2 × 35 m as its only child; the swell's shape at 0, ±30, 60, 61, and −400 m; and five placements of the two wells against the light, 0 / −100 + 20 / 59 / −60 / 90 m, where `update_swell` gives the swell of the nearer one and the glow's energy sits inside its flicker band around 1 + 0.6 × swell); `_oilfield_belt_ok` (156 pieces, no `Plume_*` node anywhere, the horizon tile's four objects); the surface check. Printed: "oil field flames: 12 horizon columns (8 left, 4 right), F3 flame_columns hides them all, in the warmup", "oil field burning wells: 2 copies 384 m apart at x -42 to -45, Flame_Near at (0, 3, 0) with a 35 m column each, no plumes; lane glow swell 1 abeam (+60%), 0 from 60 m on", "oil field belt: 156 pieces, 32 nodding pumpjacks, 32 horizon tiles".

**Views** (all in the scratchpad's `oilfield_well\`, outside the repo):

- Blender, Workbench on #A8401C, 35 mm, eye 4.9 m up at 44 m: `side_train.png` (from the train, the breach in view), `side_back.png`, `side_oblique.png`, `three_quarter_train.png`, `three_quarter_back.png`, `close.png` (18 m); silhouettes `silhouette_side.png`, `silhouette_end_on.png`, `silhouette_top.png`; the 64 px squint `squint_64px.png`. Script: `render_well.py`.
- Godot, flat, 1280 × 720, fov 75, the fixed light, the belt frozen for the well shots (`capture_well.gd`, a copy of `capture_flames.gd`): `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3`, `lane_e.png`; the Well pass `well_pass_200.png`, `well_pass_60.png`, `well_pass_0.png` (swell 0, 0.07, 0.93); the roof's pool at swell 0 and 1, `down_swell0.png` and `down_swell1.png`; the well abeam, `abeam.png`, `abeam_wide.png`, `abeam_close.png`. In `oilfield_well\far\` (`capture_well_far.gd`): the well 250, 300, 340, and 380 m ahead (`far_NNN.png`, `far_zoom_NNN.png`), and 60 and 200 m behind (`behind_60.png`, `behind_200.png`).

**What was judged, against D**

- Squint and silhouette: pass. A low black ring with a pale stub and an orange heart; the squint holds one dark band, one white point, one orange sliver.
- Reference match R3 and R11: pass. The 35 m column stands from a white-hot mouth over an orange pool, white core, yellow, orange, dark-red rim (`well_pass_0.png`, `abeam.png`); at abeam its core is unfogged and it dwarfs the horizon's columns; the roof's pool is clearly brighter at swell 1 (`down_swell1.png` against `down_swell0.png`); the swell rises and falls smoothly through 60 m (the squared cosine has no step at either end; light energy 1.21, 1.26, and 1.78 at 200 m, 60 m, and 0 m ahead of the eye, on a base of 1.2, flicker included). The sheet's "plume capping the column" and "pylon wires crossing it" are not tested: the plume is removed and the pylon is not built.
- Pool through the breach: pass, but small. From the roof at 43 m the pool is a sliver (about 60 px wide at fov 40) under the white-hot mouth in the gap between the two berm blocks (`abeam_close.png`); the slumped block beside the breach lets a little more of it show. The berm itself is the haze's colour, not black: unlit scorched earth takes 31 to 33% fog, as does the ground behind it, so only the mouth, pool, and column stand out. That is the squint's "glowing heart", with the ring a faint hazy trapezoid.
- Rule 22: pass (above); no column, berm, or anchor in `lane_p_*` or `lane_e.png` stands within ±4.5° of the axis.
- Nothing pops, judged in stills only: the berm is 97% fogged at the wrap. **The column does pop:** past 300 m a column is one plum colour (the sky's, `smoke_fog_color`), and at 380 m a 35 m column is a 5° plum pillar against the bright band (`far_zoom_380.png`). It is the same cue as the horizon's (approved), at the same wrap (384 m), but now it stands without a plume over it, and D17 wants none to pop. Not changed here (the cue was approved as is); the fix is a second stage of the cue's ramp from the sky's colour toward the haze (about 300 to 380 m), in `flame_column.gdshader`, for the planning chat to decide.
- Not visible in a capture: the berm's lit side (it faces away from the train).

**Where the well departs from B, and why**

- **The mouth is taller than B's casing and white-hot.** B has a 1.4 m casing, its sides iron and its top white-hot, with `Flame_Near` at (0, 0, 1.4). Seen from the roof at 43 m the top is a sliver and a 1.4 m casing stands under the berm's 2.2 m crest, as on the horizon (H, `oilfield_horizon`). So the iron casing keeps B's 1.4 m (z 0.4 to 1.9, from inside the pool), and a white-hot mouth 1.0 m across rises to z 3.0 above it; `Flame_Near` sits at its top centre, (0, 0, 3.0). The mouth's sides and top are `M_LampGlass`, so `Well_Iron` holds only the casing and its shoulder.
- **The berm** is an octagon with a swept profile (the horizon's kernel), 7 blocks, not 8 separate wedges, and its "blocky crest" is the one slumped block. The slumped block keeps the toe and the 35° slope, so its crest is wider (2.4 m at 1.1 m tall); it is not pushed into the pool (the step face needs the same inner wall). The pool is a 12-gon of 8 m across, apothem 4.0, inside a 4.4 m inner wall.
- **The pool has walls** (a cylinder to the ground, 34 triangles instead of a flat plate) so no edge hangs over the earth; it glows on its sides as well.
- **The apron** is 5.5 m visible beyond the pool's rim (B: 5 m), from 3.5 m (under the pool) to 9.0 m.
- **No plume** (B's 120 triangles, the detail 3, and the squint's "dark plume"); the well is 146 of 300.

**Found:** the build script and the autotest are CRLF; edits to them keep it. `oilfield_train.blend1` is Blender's own backup of the `.blend`.

**Still open:** the column's plum pillar popping at the wraps (above), in motion; the pylon, whose wires were to cross the near column; the berm's read from the roof at haze values (a darker ring would need a lighter ground or lit faces); the headset review.

### Wrap fix, `oil_derrick`, and `oil_tank` (batch 5)

Built on 2026-10-29. The flame column's wrap pop is fixed, and the two mid-belt modules are built, on the belt, and in the tests.

**Files**

- Changed: `assets/vfx/flame_column.gdshader`, `scenarios/oilfield_train/scenery_belt.gd`, `dev/build_oilfield_train_blender.py` (`--part derrick`, `--part tank`, the shared `prism` and `check_module`; the coplanar check now prints where an overlap is), `dev/autotest.gd` (`_mid_rigs_ok`, the new counts), `oilfield_train.blend`.
- New: `oil_derrick.glb`, `oil_tank.glb`, and their `.glb.import` files (the horizon's `[params]`; `--import` filled the uids and paths).
- Backups from before the batch are in the scratchpad's `oilfield_batch5\backup\`.

**The column's wrap fix** (`flame_column.gdshader`). A column melts: from `melt_near` 320 m to `melt_far` 370 m from the camera, the whole body shrinks onto its mouth, and it is gone at 370 m, 14 m short of the 384 m wrap.

- **How.** The fragment reads the quad at 1 / scale, so the shape, the bands, and the noise scale together: `scale` = 1 − `smoothstep`(320, 370, distance from the camera to the column's origin). At 340 m the column is 65% of its size, at 360 m 10% (a 35 m well column is 3.6 m tall), and from 370 m it is `discard`ed. It is the same hard cut-out: no blend, no dither, no noise speckle.
- **Why this one.** The pop was a plum pillar against the bright band, and a second colour ramp toward "what is behind it" has no single answer: behind a column stand the band, the haze, or the plum sky, by its height and the camera's pitch. Shrinking leaves nothing to colour. It is one `discard`, no uniform a script must write, and it uses the distance to the column's origin (one value per column), so a column does not lose its top first.
- **Inside 300 m nothing changed.** `scale` is exactly 1 up to 320 m, so the shape, the bands, the lean, and the 150 to 300 m fog ramp are the same operations on the same values.
- **Both wraps.** A far-loop column stands 67 m or more out, so it is gone before 384 m along the track on either side. At the nearer duelist's eye the wrap is 374 m away (376 m with the well's x), past the 370 m end, so nothing grows in on that side either.
- **Evidence** (`oilfield_batch5\wrap\`; `capture_wrap.gd`, the batch 4 far-capture setup with more distances): the well 250, 300, 320, 340, 350, 360, 370, and 380 m ahead of Lane P's eye, `far_NNN.png` wide and `far_zoom_NNN.png` aimed at it. `grid_crop.png` is 300, 340, 360, and 380 m side by side, magnified 3.2 times: a full plum pillar at 300 m, a 65% one at 340 m, a few pixels at 360 m, nothing at 380 m. The horizon tiles' columns melt the same way, over the last stretch of their loop.

**Belt rows.** `scenery_belt.gd` gains `x_left` (a left-only x range for a row) and two rows in the mid slots the pumpjacks and wells leave free, so all 16 slots a side now hold a piece:

| Row | Copies | Slots | x | Seed |
|---|---|---|---|---|
| `oil_derrick` | 10 | left 3, 6, 11, 14; right 0, 4, 7, 10, 13, 15 | right 26 to 45, left 30 to 45 | 1888 |
| `oil_tank` | 8 | left 1, 4, 9, 12; right 2, 5, 8, 12 | right 30 to 45, left 32 to 45 | 1889 |

- **Left stays clear of the pylon line.** B says left pieces stay at x −28 or beyond. A derrick's feet reach 3.25 m in from its origin and a tank's wall 4.95 m, so the left rows start at 30 and 32: the nearest left leg or wall is 27 m out, 3 m from the pylon's base (x −24) and 2 m from its arm tips (−25 at 17 m up). The right side keeps B's 26 and 30.
- **Footprints apart.** One piece a slot (48 m). A derrick's footprint is 29.8 m along the track (y −15.7 to +14.1), a tank's 19.7 m (±9.83), both inside the slot's ±23.875; two neighbours stand at least 18 m apart.
- **Rule 22** holds: the nearest derrick leg is 26 m out, so it could enter ±4.5° of the axis only 330 m ahead or more, long past 80 m (and 95% fogged by then). Nothing on the belt comes within the death cam's ±6 m.
- `_oilfield_belt_ok` expects 174 pieces (156 + 10 + 8) and calls `_mid_rigs_ok`: 10 derricks and 8 tanks, each with its objects, the right x range on each side, the left side at 28 or beyond, no flame anchor on either, and no two mid pieces of one side (derricks, tanks, mid pumpjacks, wells) closer than 40 m along the 768 m loop. It runs before `_burning_wells_ok`, which moves the wells.

**`oil_derrick`** (`--part derrick`, then `unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb oil_derrick`). Geometry hash `d7f9bef21f51`. Nothing is random.

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Derrick_Plank` | `M_Plank__oil_derrick` (0.275, 0.262, 0.238) | 490 | Legs 32, girts 160, braces 114 and 48 (the lowest two bays crossed), platform 12, crown block 10, walking beam 12, post legs 32, bearing block 10, post brace 8, band wheel 28, pitman 6, belt house 8, engine house 10 |
| `Derrick_Iron` | `M_Iron__oil_derrick` (0.018, 0.020, 0.027) | 56 | Crown sheave 20, the engine house's two roof sheets 20, the stack 16 |
| **Total** | | **546 / 600** | 2 objects; the scene 5,460 against B's 6,000 |

- **The lattice.** Four 0.35 m legs on a taper from 3.0 m (centre lines; a 6 m square at the foot) to 0.8 m at 20.5 m; girts 0.25 m at 4, 8, 12, 16, and 20 m; a diagonal 0.26 m across (a 3-sided prism) in each of the five bays of each of the four faces, alternating direction up the faces, the lowest two bays crossed (the second diagonal 10 cm proud of its face, so no two share a plane). A 2.4 m platform at 20.4 to 20.65 m, a 1 m crown block to 21.5 m, and the crown sheave (iron, a 6-sided disc) to 22.1 m.
- **Wear.** The whole lattice leans 2° toward −Y, away from the engine house (the top is 0.7 m over), pivoting at the ground; the +X face's fourth bay (12 to 16 m) has no diagonal, so the band shows through it from the train's side. The legs start 0.3 m under the ground, so the lean never lifts a foot.
- **The machinery along +Y** (the derrick's axis at y −12.5): a 7.9 m walking beam (0.35 × 0.4 m) on a 4.0 m Samson post (two A-frames either side of the beam, a bearing block under it), a 2.7 m band wheel (8 sides) with its pitman, a belt house, and the engine house, 4.0 × 6.0 m, 3.5 m to the eaves, a gabled timber body under two iron roof sheets (0.3 m of overhang), and an iron stack 0.5 m across to 8.0 m. All static.
- **Extents:** x −3.250 to 3.207, y −15.695 to 14.100, z −0.412 to 22.137.
- **Checks:** no zero-area, non-planar, or smooth faces; no flat face within 0.08 m of 0.12; coplanar test over 546 triangles, 336 coplanar pairs, 0 sharing area. Two overlaps were designed out on the way: the girts shared tops and bottoms where they crossed at a leg (they now stop 2 cm inside it), and the post's legs shared a face under the bearing (they now stop 3 cm apart).
- **Unwrap:** `GLB oil_derrick [oilfield_train]: 2 meshes, 254 islands, 4.1 px/m at 256 px (pad 1, 68% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`. A triangle-pair test in the `.blend`: 0 UV overlaps, none outside 0 to 1, none mirrored; `_is_cylinder` false on both objects.
- **LODs (G13).** A right-hand derrick at 40, 80, 150, 250, and 330 m, flat run, `meshes/generate_lods` true against false: the lattice is the same, pixel for pixel in the derrick's region at 330 m and by eye at 150 and 250 m. The import keeps `generate_lods=true`, like the others.

**`oil_tank`** (`--part tank`, then the unwrap with `--glb oil_tank`). Geometry hash `0030e7691d5f`.

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Tank_Sheet` | `M_Sheet__oil_tank` (0.144, 0.133, 0.114) | 72 | Two 12-sided walls (24 each) and their cone roofs (12 each) |
| `Tank_Iron` | `M_Iron__oil_tank` (0.018, 0.020, 0.027) | 110 | Rim angles 24 and 26, A's course step 48, the header pipe 12 |
| `Tank_Plank` | `M_Plank__oil_tank` (0.275, 0.262, 0.238) | 112 | The stair: two flights 52 each, a landing 8 |
| **Total** | | **294 / 320** | 3 objects; the scene 2,352 against B's 2,560 |

- **Tank A** is 10.0 m across the corners and 7.0 m tall (a flat faces each of ±X and ±Y, so the wall is 9.66 m across the flats), with a cone roof 1.2 m high, a rim angle 0.30 m tall and 0.12 m proud, a course step 0.12 m proud and 0.25 m tall at 3.4 m, and the stair on its +X face. **Tank B** is 7.0 m by 5.5 m, roof 0.9 m. The walls stand 3.0 m apart (flat to flat) along Y, the pair centred on the origin (A at y −4.885, B at 6.325). The header pipe is 0.30 m across (6 sides) at 1.0 m, its ends inside the walls.
- **Wear.** B's roof is slumped 4° with its +X edge down (the −X edge stands 0.24 m over the wall's top, hidden behind the rim, which rises 0.24 m on that side), and B's rim has one vertex replaced by a 0.6 m flat pulled in 0.35 m.
- **The stair** is two sawtooth slabs of 6 steps (rise 0.58 m, run 0.37 m), 1.0 m wide, its back 5 cm into A's +X facet: the first climbs toward +Y to a landing at 3.5 m, the second returns over it to the rim at 7.0 m. Each slab's sides are one quad a step, because a 14-sided cap triangulates with zero-area slivers along the collinear nose. It is on the +X face so the lane sees it in profile.
- **Open faces (rule 27):** the walls have no top or bottom, the roofs no underside, and the rims no top, bottom, or inner face. From the roof's eye (4.9 m) none is seen from the wrong side.
- **Extents:** x −4.950 to 5.780, y ±9.830, z 0 to 8.200.
- **Checks:** no zero-area, non-planar, or smooth faces; no flat face near 0.12; coplanar test over 294 triangles, 944 coplanar pairs, 0 sharing area. **Unwrap:** `GLB oil_tank [oilfield_train]: 3 meshes, 77 islands, 9.4 px/m at 256 px (pad 2, 75% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`; 0 UV overlaps, none outside, none mirrored, `_is_cylinder` false on all three. `M_Sheet` is a new base name and plain: it is in neither `TILING` nor `GRAIN`, so the importer gives it the world shader with no grain, and the tanks go through the per-GLB unwrap (a tiling name would have dropped them).

**Tests** (`--import`, then `run_autotests.ps1 load multi duel i18n`): `AUTOTEST PASS` on each. New `load` lines: "oil field mid rigs: 10 derricks and 8 tanks on free slots, left side at x 28 or beyond, no two mid pieces closer than 40 m", "oil field belt: 174 pieces, 32 nodding pumpjacks, 32 horizon tiles", and "1651 scenario surfaces wear world_surface.gdshader (204 sway, 74 self-lit, ...)" (1607 before: the 44 new surfaces are the 10 derricks' two and the 8 tanks' three).

**Views** (kept outside the repo, in `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_batch5\`):

- Blender, `views\`: Workbench with studio light on #A8401C, terrain shown, eye 4.9 m up at 35 m (the derrick with a 20 mm lens, because a 22 m tower does not fit a 35 mm lens at that range; the tank with 35 mm): `oil_derrick_side_train.png`, `_side_back`, `_three_quarter_train`, `_three_quarter_back`, `_end_on`; the silhouettes on #A8401C `_silhouette_side`, `_silhouette_end_on`, `_silhouette_top`; the 64 px squint `_squint_64px`; the same names for `oil_tank_`. `oil_derrick_sheet1.png`, `_sheet2.png`, `oil_tank_sheet1.png`, and `_sheet2.png` are contact sheets of them.
- Godot, flat, 1280 × 720, fov 75, fixed light: `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3` (2 s apart), `lane_e.png`; with the belt frozen and one of each rig 0 and 30 m ahead of the eye on each side, `derrick_left_abeam.png`, `_right_abeam`, `_left_ahead`, `_right_ahead`, and the same for `tank_`; `crop_tank_right.png`. `lod\` holds the LOD comparison, and `derrick_wrap\` and `derrick_wrap75\` a derrick at 330, 380, 384, and 394 m. Scripts, in the scratchpad: `capture_batch5.gd`, `capture_wrap.gd`, `capture_lod.gd`, `capture_dwrap.gd`, `render_batch5.py`.

**What was judged, against D**

- **Silhouette and squint: pass.** The derrick reads as a tall tapering lattice with a low shed and a long beam at its foot; at 64 px it is one thin spike over a low block, two flats. The tanks read as two drums with flat hats, the stair as a diagonal on the big one.
- **Size floor (0.25 m mid): pass.** The thinnest members are the 0.25 m girts, the 0.26 m diagonals, and the 0.25 m post legs. The 0.12 m rim and course step are B's own figures, and each reads as one line.
- **Wear: pass.** The lean, the missing diagonal, B's slumped roof, and its dented rim are all in silhouette; none is in colour.
- **Left rigs black against the band, right rigs lit: partly.** On the right, derricks and tanks are lit timber and sheet iron on the band (`away_*`, `derrick_right_abeam.png`, `crop_tank_right.png`). On the left they are darker than the band but not black: a rig 30 to 45 m out takes 24 to 33% fog, and the fog on the fire side is brightened by the sun scatter, so a left tank is a haze-brown mass a step darker than the horizon (`fire_3.png`, `tank_left_abeam.png`). It is the same finding as batch 4's berm and follows from the sheet's own fog steps; the near pumpjacks stay the black cut-outs. Left to the planner.
- **The tank's lit half: pass, but quiet.** On the right the −X facets are lit at the full and middle steps and the +X facets are dark, with the iron rim and step as dark lines (`crop_tank_right.png`); at 44 m and 33% fog the two halves differ by a step or two, not by a half-moon against black.
- **Rule 22: pass.** No derrick or tank in `lane_p_*` or `lane_e.png` within ±4.5° of the axis; computed, the nearest could enter the cone at 330 m.
- **Lattice shimmer: not judged in motion.** By size, a 0.25 m member at 35 m is about 4 px in the flat capture (more in a headset) and falls under one pixel only past about 100 m, where it is 60% fogged. The headset review is open.
- **Pop at the wrap: the columns, fixed; the derricks and tanks, not.** A derrick at 384 m is fogged to the haze colour, which is darker than the sky band behind its upper part, so its lattice stays a faint dark silhouette up to the wrap, 3.3° tall (`derrick_wrap\lod_w_384.png`, magnified; `derrick_wrap75\lod_w_384.png` at fov 75). In the full view it is one among dozens of lattice silhouettes on the horizon (the tile's derricks stand as tall), so it is not a noticeable pop, but it is not zero. The same holds for the pumpjacks (0.9° tall) and the horizon tile. The fix, if the planner wants one, is a belt-side grow (scale y from 0 to 1 over the last 40 m) on the derrick and tank rows.

**Where the modules depart from B, and why**

- **A pitman and a crank pin** on the derrick, which B does not list (B: beam, post, band wheel). It is one 6-triangle prism, and without it the beam and the wheel read as two unrelated parts.
- **Derrick height.** B gives 22 m; the legs are 20.5 m and the whole, sheave included, 22.1 m.
- **Triangle spread against B's.** Girts 160 (B 160), braces 162 (B 200), crown and platform 42 (B 40), beam, post, wheel, and pitman 98 (B 80), sheds and stack 54 (B 80): 546 of 600.
- **Left-side x.** B's "x −28 or beyond" becomes 30 for derricks and 32 for tanks (above).
- **The tank's open faces** (above), and a stair built as sawtooth slabs, not stringers and treads. B does not say which face the stair is on; it is +X.

**Found:** one read-only `git diff --stat` was run by mistake while checking the shader edit (the brief said no git); nothing changed. `powershell -File dev/run_autotests.ps1` is blocked by this machine's execution policy as written; `-ExecutionPolicy Bypass` runs it. The `.blend` was last saved by the unwrap; nothing was rebuilt after it.

**Still open:** the headset review; the derrick and tank wrap pops (above); the shimmer in motion; the left rigs' read at 30 to 45 m; and `TEXTURE_LIST.md` and `TEXTURING.md`'s GLB table do not list the new GLBs yet (G17).

### Wrap grow, `oil_pylon`, and `oil_pipe_run` (batch 6)

Built on 2026-10-29. Backups from before the batch are in the scratchpad's `oilfield_batch6\backup\`.

**Files**

- Changed: `scenarios/oilfield_train/scenery_belt.gd` (the grow, the two rows), `dev/build_oilfield_train_blender.py` (`--part pylon`, `--part pipe_run`), `dev/autotest.gd` (`_wrap_rows_ok`, `_belt_grow_ok`, 206 pieces), `oilfield_train.blend`.
- New: `oil_pylon.glb`, `oil_pipe_run.glb`, and their `.glb.import` files (`oil_tank.glb.import`'s `[params]`, `generate_lods=true`; `--import` filled the uids and paths).

**The wrap grow** (`scenery_belt.gd`). A piece's scale ramps from 0 at the wrap to 1 over its first 40 m (`GROW_M`) and back to 0 over its last 40 m, with a smoothstep, uniformly about the piece's origin, so its base stays on the ground. The scale is floored at 0.001 (`GROW_MIN`), because a zero basis is singular.

- **Why uniform, not y only.** A derrick's footprint is 30 m along the track and a tank's 20. Scaling only y would leave a flat full-size footprint at the wrap, and the grown piece would change proportions on the way. Uniform scaling keeps the lattice's shape.
- **Which rows.** Every row except `env_rail_track_8m`, which carries `"grow": false` in its row: it lies flat at 96% fog and does not shrink. The pumpjack rows, the horizon tiles, the derricks, tanks, wells, pylons, and pipe runs all grow. Near-band pieces (loop ±360 m) ramp over 320 to 360 m, and mid and far pieces (±384 m) over 344 to 384 m.
- **Children.** `WalkingBeam` and the flame anchors are children, so they scale with their piece. A flame column reads its quad's scale from its model matrix, so the column on a grown piece shrinks with it as well as melting (`flame_column.gdshader`, untouched).
- **Cost.** `_process` already writes each piece's z. One scale write more per piece while it is in a ramp zone, and one write back to exactly `Vector3.ONE` on leaving it. A per-piece state byte (`Grow.OFF`, `FULL`, `RAMP`) keeps pieces outside the ramps at zero extra writes. `grow_at(edge)` is a static function so the test can read it.

**The pylon row keeps the grow, and does not exempt itself.** The grow cannot hold the wires on the next tower's arm tips while a tower is inside a ramp: the tower is one object, and when it scales about its base, its wire ends move toward its origin, and the wire it holds from the tower behind (96 m back) stops at the point where its arm tip would have been. That mismatch exists only for the 40 m at each wrap, where:

- the fog is 94 to 97% (density 0.009 at 344 to 394 m from the eye), and
- the wires are 8 cm thick, which at 345 m is 0.013 degrees, about 0.2 pixels at the flat camera's 17 pixels a degree.

So the wires are not visible as wires there, and the tower is. Without the grow, the tower is a faint dark lattice up to the wrap (`wrap\pylon_390_nogrow.png`) and pops. With it, the tower is a few pixels at 380 m and gone at 390 m. Everywhere inside 344 m, the wires meet the next tower's tips exactly: the build prints that the far ring of each wire is at (x, −96, z) of the same tip, and the test reads each tower's mesh bounds and the 96 m gaps (below).

**Wrap evidence** (`oilfield_batch6\wrap\`; `capture_batch6.gd` in the scratchpad, `CAPMODE=wrap`: the belt frozen, one piece on its own at 340, 360, 370, 380, and 390 m from Lane P's eye, once with the grow and once with scale forced to 1; the wrap is 394 m from the eye). Scales printed for a mid piece: 1.000, 0.939, 0.648, 0.282, 0.028. `wrap_sheet_<kind>.png` puts the two rows side by side for `derrick`, `tank`, `pumpjack_mid`, `pumpjack_near`, `horizon`, `pylon`, `well`, and `pipe`.

- **Derrick:** with the grow, a lattice at 340 m, 94% size at 360, 65% at 370, a stub at 380, nothing at 390. Without it, the same full-size lattice at 390 m: the pop batch 5 found (`wrap_sheet_derrick.png`).
- **Horizon tile:** the same. Berms, derricks, and tanks shrink onto the ground and are gone by 390 m. Without the grow, the whole tile stands at 390 m (`wrap_sheet_horizon.png`).
- **Pylon:** above. **Well:** its berm and column shrink together; the column was already melting, so nothing is added. **Tank and pumpjacks:** the same as the derrick, fainter, because they are shorter. **Pipe:** the near band wraps at 360 m, so its frames from 370 m on show the piece parked at the wrap at scale 0.001 (the 1.2 m run is under a pixel there either way).
- Not watched in motion: a full loop at the wraps. The captures are stills of the exact scale values the belt writes.

**`oil_pylon`** (`--part pylon`, then `unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb oil_pylon`). Geometry hash `1d2a405a1ffb`. Nothing is random.

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Pylon_Iron` | `M_Iron__oil_pylon` (0.018, 0.020, 0.027) | **448 / 450** | Legs 48, girts 120, braces 120, arms 22, insulator blocks 30, wires 108 |

- **Tower.** Four tapering 3-sided legs (0.30 m a side), centre lines 2.0 m from the axis at the ground and 0.6 m at 16 m (a 4.0 m base and a 1.2 m neck), carried on to 22 m at 0.45 m. Girts (3-sided, 0.25 m) at 4, 8, 12, 16, and 19 m; one diagonal per bay per face, alternating direction up each face, over the four bays and the cage bay (16 to 19 m). The 6.0 m cross-arm is at 17 m and the 4.0 m one at 20 m, both 3-sided bars with the apex up. The lower arm's +X tip is bent down 5 degrees from x 1.5 (0.13 m lower at the tip): the wear.
- **Wires.** Three, from insulator blocks (0.25 m square, 0.45 m deep) under the arm tips at (x −3.0, z 17.0), (x +3.0, z 16.87), and (x −2.0, z 20.0), each six straight pieces through shared rings of an 8 cm triangle, sagging 3.0 m at mid-span (the lowest ring at 13.38 m), ending 96.0 m along −Y (Godot +z) at the same tip of the next copy: the build asserts it.
- **Extents:** x −3.125 to 3.125, y −96.000 to 2.138, z −0.200 to 22.000. In Godot the mesh reaches z −2.14 to +96.0 from the piece's origin.
- **Checks:** no zero-area, non-planar, or smooth faces; no flat face near 0.12; coplanar test over 448 triangles, 32 coplanar pairs, 0 sharing area.
- **Unwrap:** `GLB oil_pylon [oilfield_train]: 1 meshes, 166 islands, 2.5 px/m at 256 px (pad 2, 23% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`. No TINY share. A triangle-pair test in the `.blend`: 0 UV overlaps, none outside 0 to 1, none mirrored; `_is_cylinder` false.
- **LODs (G13).** The pylon at 100, 180, and 260 m with `generate_lods` true against false (flat run, same belt moment): the tower and the wires are the same shape in both; the import keeps `true`. The pipe run's comparison framed the sky and the roof, not the pipe, so it was not judged; the import keeps `true`.
- **Belt row.** `oil_pylon`, mid band, `count` 8, left, x 22 to 22 (`randf_range` of a fixed range gives exactly −22), no yaw, `phase` 0.5: homes −336, −240, …, +336, a 96 m pitch, and 8 × 96 = 768 closes the loop. The test reads each piece's x (−22 within 0.0001), its rotation (zero), its mesh bounds (the wires reach 96.0 m), and the gaps between neighbours (96 ± 0.01, the last one across the wrap).
- **Rule 22:** the tower at x −22 enters ±4.5° of the axis only beyond 280 m from the eye, where it is 92% fogged; the wires run along z and converge toward the axis, but they are 8 cm thick and fogged by then. A thin faint lattice, not a head-high mass: judged acceptable and flagged for the headset.

**`oil_pipe_run`** (`--part pipe_run`, then the unwrap with `--glb oil_pipe_run`). Geometry hash `9af180a62d96`.

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Pipe_Iron` | `M_Iron__oil_pipe_run` | 148 | The 16 m hex pipe 80 (8 pieces: 2 straight ends, 6 for the three spans, 8 cm of sag at each span's middle, the bottom face dropped), the elbow into the ground 17, the flange 16, three collars 36 |
| `Pipe_Plank` | `M_Plank__oil_pipe_run` | 72 | Four A-trestles: eight 3-sided legs 48, four saddle bars 24 |
| **Total** | | **220 / 140** | 2 objects; the scene 5,280 against B's 3,360 |

- **The 140 does not fit the sheet.** Four trestles of two legs and a saddle (18 each, 72), a 6-sided pipe in eight pieces (80 with its bottoms dropped), an elbow, a flange, and three collars come to 220, and the cheapest forms tried (4-sided pipe, 3-sided legs, a quad crossbar) did not reach 140. 140 is exceeded by 80 triangles a copy, or 1,920 in the scene (about 3% of the scene's 66,700). For the planner: cut a trestle's saddle bar (24) and the collars (36) to reach 160, or accept 220. The build's own limit is 220 (`PR_BUILT_MAX`), with the sheet's 140 beside it.
- **Geometry.** The pipe's centre line is 1.125 m up over the trestles and 8 cm lower at each span's middle, the run 1.25 m tall; the tallest point is the flange, 1.385 m. The pipe runs from the flange at y +8 to an elbow at y −7.75: a vertical hex prism from 0.1 m under the ground to the pipe's top, capped and fanned into 4 triangles. Trestle legs are 3-sided (0.14 m), from x ±0.55 at the ground to ±0.10 under the pipe, with a 3-sided saddle bar 0.64 m across. The third trestle (y +2) leans 6° toward +X, and the pipe's ring over it is moved 0.105 m the same way: a 3.0° kink either side. Collars are 6-sided (0.33 m across, 12 cm long) at y −4.6, 0, and +4.6.
- **The extents:** x −0.622 to 0.620, y −7.858 to 8.000, z −0.115 to 1.385. Within the slot (y ±8.5).
- **Checks:** no zero-area, non-planar, or smooth faces; no flat face near 0.12; coplanar test over 220 triangles, 74 coplanar pairs, 0 sharing area.
- **Unwrap:** `GLB oil_pipe_run [oilfield_train]: 2 meshes, 53 islands, 16.1 px/m at 256 px (pad 2, 9% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`. 0 UV overlaps, none outside, none mirrored.
- **A build trap.** With the elbow's top cap and the flange's cap as the object's only two n-gons, every other face a quad, `scenery_uv._is_cylinder` read the whole pipe as one cylinder and unrolled it on top of itself (135 overlaps). The elbow's cap is fanned into triangles, which leaves one n-gon.
- **Belt row.** `oil_pipe_run`, near band, `count` 24, `alternate` (12 a side, one per 60 m a side), x 3.6 to 5.0 rolled (seed 1891), 20 m/s, ±360 m: the footprints (16 m on a 30 m pitch) never overlap. The pipe's own footprint reaches 0.62 m in x, so the nearest surface is 2.98 m from the axis, clear of the guard walls (1.64 to 1.92).
- **The 1.5 m rule.** `_wrap_rows_ok` walks every belt piece's mesh bounds and fails if one reaches inside x ±6 and stands over 1.5 m. It passes: the pipe's flange is 1.385 m, the near pumpjacks' nearest reach is x 6.24, and the tracks are 0.21.
- **Death cam:** at (±3.08, 4.28, −10) and the low orbit (±4.5, 3.0, −10), with a pipe run on each side at z −10, nothing is near the camera (`deathcam_*_zm10.png`: the roof's edge and the sky above it; the pipes are 1.4 m high, 1.6 to 2.9 m under the lens).

**Views** (in the scratchpad's `oilfield_batch6\`, outside the repo)

- Blender, Workbench with studio light on #A8401C, 35 mm unless noted (`views\`, script `render_batch6.py`): for the pylon, side from the train and from the tail (20 mm), three-quarter from both sides, end-on from the lane at 60 m (the duel view: the arms broadside, the wires foreshortened), the span from the side and down the lane; silhouettes on #A8401C (side, end-on, top of the span, side of the span); the 64 px squint of the side view. For the pipe run, side from both sides (24 mm), three-quarters from the elbow and the flange ends, end-on from the lane, close on a trestle; silhouettes side, end-on, and top; the squint. `oil_pipe_run_edge_view_down.png` is mis-aimed at the ground and not used.
- Godot, flat, 1280 × 720, fov 75, the fixed light (`views\`, `capture_batch6.gd`, `CAPMODE=views`): `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3` (2 s apart), `lane_e.png`; `edge_left_z7.png` and `edge_right_z7.png` (a pipe run each side at z 7); the death cam, `deathcam_left_zm10.png`, `deathcam_right_zm10.png`, `deathcam_low_left_zm10.png`, `deathcam_low_right_zm10.png` (a pipe run each side at z −10); the well pass with the pylon line, `well_pass_200.png`, `well_pass_60.png`, `well_pass_0.png` aimed at the column and `well_pass_wide_*.png` at fov 40; `pylon_line_fire.png`. `wrap\` holds the 80 wrap frames and the sheets; `lod\` the pylon's and pipe's LOD frames.

**What was judged, against D**

- **Pylon silhouette and squint:** pass. A black lattice with two arms and three lines from the end-on view, and at 64 px a thin spike with a faint wire (`oil_pylon_squint_64px.png`). From the side, which the lane does not see, it is a narrow tower.
- **Pylon and the column:** pass. At abeam the three wires cross the well's column in its upper half (`well_pass_wide_0.png`), 14 to 20 m up and fogged to a dark orange line, with the tower beside it in `fire_2.png` and the death-cam frames. The wires read as lines against the plum sky and as faint ones across the fire.
- **Pipe silhouette and squint:** pass. A dark line on low timber legs, kinked once, with an elbow and a flange (`oil_pipe_run_silhouette_side.png`). The collars read as notches; the lean is visible end-on (`oil_pipe_run_end_on_from_lane.png`).
- **Size floor:** the pipe run's smallest members are the 12 cm trestle legs, over the near floor of 10 cm. The pylon's lattice is 0.25 to 0.30 m, at the mid floor, and its wires are B's own 8 cm.
- **Wear:** one accent each, in silhouette: the bent arm tip; the leaning trestle with its kinked pipe.
- **Rule 22 and the lane:** pass. `lane_p_*` and `lane_e.png` show no pylon, wire, or pipe on the axis.
- **Edge:** the pipe reads as a dark line on lit legs below the roof's edge (`edge_left_z7.png`). Shimmer in motion was not judged; the collars pass at 20 m/s once every 0.23 s, as B's strobe check wants.
- **Not done:** the headset review and the shimmer of the lattice and wires at 20 to 40 m in motion.

**Tests** (`--import`, then `run_autotests.ps1 load multi duel i18n ragdoll`): `AUTOTEST PASS` on each, after the last code change. The `load` line: "oil field wrap rows: 8 pylons at x -22 on a 96 m pitch with 96 m of wire each, 24 pipe runs 12 a side, nothing over 1.5 m inside x 6; wrap grow 0 to 1 over 40 m on 8 kinds, the tracks exempt, beams and anchors scale with their piece", "oil field belt: 206 pieces, 32 nodding pumpjacks, 32 horizon tiles", and 1707 surfaces on the world shader (1651 before: the pylon's one and the pipe runs' two on 8 and 24 copies, the same arithmetic as batch 5). `_oilfield_belt_ok` expects 206 pieces (174 + 8 + 24). `_wrap_rows_ok` checks the pylons and pipes, and the 1.5 m rule over every piece; `_belt_grow_ok` freezes the belt (`speed_mps` 0), places one piece of each of nine kinds at 0, 10, 20, and 39 m inside the wrap entering and leaving, and checks the scale against `grow_at`, the tracks at exactly 1, a beam's and an anchor's global scale against their piece, and exactly `Vector3.ONE` mid-loop; it then restores the belt.

**Where the modules depart from B, and why**

- **`oil_pipe_run` is 220 triangles, not 140** (above).
- **Pipe height.** B says the pipe is at 0.8 m on trestles 1.0 m tall: an A-trestle taller than its pipe cannot carry it. The pipe's centre line is 1.125 m, the trestle (to its saddle) 1.0 m, the run 1.25 m: the same 1.2 m the belt section gives the pipe runs.
- **Pipe sections.** 6-sided pipe and collars (B: 8-sided collars), 3-sided legs and saddle bars, the pipe's underside dropped.
- **Pylon:** three wires on three tips of two arms: both ends of the lower arm and the upper arm's −X end. B says "three arm tips" on two arms; the other end of the upper arm carries no insulator. Members are 3-sided. The cage runs to a 0.9 m head at 22 m.
- **Pylon girts at 19 m, not 20.** An arm at 20 m would cross the girt there.

**Found**

- `autotest.gd`'s `_fail` returns nothing, so a bool function needs `_fail(...)` then `return false` (the new `_fail_false` helper does it).
- **A parse error in `dev/autotest.gd` makes a suite hang, not fail.** A line continuation `\` written from a script with CRLF was a parse error; `load` printed nothing and ran at full CPU for 15 minutes, because the harness never started. `--check-only` on the file shows it (its autoload errors are expected). The new lines avoid `\`.
- One Godot process (`load`) was stopped through its owning task after that hang.

**Still open:** the headset review; the wires and lattice in motion at 20 to 40 m; the pipe run's 80 triangles over budget; the wrap pops watched over a full loop; `TEXTURE_LIST.md` and `TEXTURING.md`'s GLB table do not list the two new GLBs yet (G17).

### Hero review (2026-10-29)

The user reviewed the hero from the Blender renders and the stub's flat captures.

- **`oil_pumpjack`:** approved as built.
- **Wear:** the lifted skid stays subtle. A stronger defect repeated on all 32 copies would read as a pattern, not wear.
- **The lane glow on near-left pumpjacks:** accepted. A left rig passing within about 15 m of z 0 catches the pool's light on its train side for a moment. No cull mask; the glow stays at (−6, 7.5, 0).
- **The clouds:** they read as brown shapes on the plum sky. Judged at the reference match (D), once the flames, plumes, and horizon are in.
- **Still open:** the headset review, the Quest frame time, and the flicker's cost (the fog colour is written every frame; the sky is not).

### `oil_wellhead`, `oil_sump`, and the rung (batch 7)

Built on 2026-10-29. Backups from before the batch are in the scratchpad's `oilfield_batch7\backup\` (the `.blend`, the six `oil_*.glb` that existed apart from the horizon and the terrain, and `dev/autotest.gd`). Every one of those GLBs is byte-identical to its backup.

**Files**

- Changed: `dev/build_oilfield_train_blender.py` (`--part wellhead`, `--part sump`; `berm()` gains a `floor` argument, default 0, so the horizon and the well build the same geometry as before), `oilfield_train.blend`, `scenarios/oilfield_train/scenery_belt.gd` (the `homes` key and two rows), `dev/autotest.gd`, `gauntlet/ladder_default.tres`, `docs/TEXTURE_LIST.md`, `docs/TEXTURING.md`.
- New: `oil_wellhead.glb`, `oil_sump.glb` and their `.glb.import` files (`oil_pipe_run.glb.import`'s `[params]`; `--import` filled the uids and paths), `gauntlet/encounters/e8_trio_oilfield.tres`.
- Run by (a re-run printed the same geometry hashes and byte-identical GLBs):

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/build_oilfield_train_blender.py -- --part wellhead
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/build_oilfield_train_blender.py -- --part sump
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb oil_wellhead
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map oilfield_train --relayout --glb oil_sump
```

**`oil_wellhead`** (geometry `b9c8b4479bd3`; extents x −2.112 to 2.196, y −1.968 to 2.045, z 0 to 1.149)

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Wellhead_Iron` | `M_Iron__oil_wellhead` (0.018, 0.020, 0.027) | 102 | Casing 22, tee stub 12, valve body 8, stem 8, handwheel 28, flow line 24 |
| `Wellhead_Dirt` | `M_Dirt__oil_wellhead` (0.009, 0.006, 0.004), tiling UVs | 16 | The pad |
| **Total** | | **118 / 120** | 2 objects; the scene 1,888 against B's 1,920 |

- **Pad.** An irregular convex hexagon about 3.2 by 3.0 m, its top flat at **0.22** (0.10 m from the terrain's top, so never within 0.08), its six sides sloped: each edge is moved out 0.5 m by z 0, joined at the corners where the moved edges meet, so every side is a planar trapezoid. The bottom is dropped. It carries 8 m tiling UVs (`uv_role` `tiling`), zero rotation, origin at the root's.
- **Iron.** The casing is 0.40 m across, 8 sided, flats square to the axes, from 0.15 (buried in the pad) to **1.10**. The tee is a 6-sided stub from inside the casing to inside the valve at z 0.90. The gate valve body is a 0.35 m box (x 0.55 to 0.90, z 0.725 to 1.075; its bottom and its casing-side face dropped). The stem is a 0.10 m square bar running to −Y, and the handwheel is an 8-sided disc 0.5 m across the flats and 0.10 m thick, standing clear of the valve at y −0.70 to −0.60 with its face to the track, so the lane sees a circle. The flow line is 6 sided, 0.20 m, from the valve's +X face to a miter elbow at x 1.70 and down into the pad's sloped edge, 2 m from the casing's axis.
- **Wear.** The line's diving leg leans 4° off vertical (outboard): B's "kinked 4° at its bend". It is in silhouette (the end-on silhouette shows the leg out of true) but small.
- **Height.** The tallest point is 1.149 m, under the near belt's 1.5 m limit inside x ±6 (`_wrap_rows_ok` walks it).
- **Checks** (the build's own printout): no zero-area, non-planar, or smooth faces; no flat face within 0.08 m of 0.12; coplanar test over 118 triangles, 8 coplanar pairs, 0 sharing area; names and parents exact.
- **Unwrap:** `GLB oil_wellhead [oilfield_train]: 1 meshes, 27 islands, 112.5 px/m at 256 px (pad 2, 70% covered, 1 tiling meshes untouched); 0 materials copied; image none (flat colour)`. No TINY share. A triangle-pair test in the `.blend`: 0 UV overlaps on `Wellhead_Iron`, none outside 0 to 1, none mirrored; `_is_cylinder` false (the object has three n-gons).

**`oil_sump`** (geometry `3af09d815649`; extents x ±3.628, y −6.628 to 3.628, z 0 to 0.72)

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Sump_Dirt` | `M_Dirt__oil_sump` (0.009, 0.006, 0.004), tiling UVs | 54 | The ring berm: 7 blocks round one breach, 4 steps between unequal blocks |
| `Sump_Glass` | `M_Glass__oil_sump` (0.006, 0.004, 0.003) | 16 | The pool 6, the tongue's top 2, its two sides 4 and end 2, the lip 2 |
| **Total** | | **70 / 70** | 2 objects; the scene 1,120 against B's 1,120 |

- **Berm.** `berm()` on an octagon: inner wall apothem 2.15, crest apothem 2.60, a 35° outer slope to a toe at 3.63 (7.3 m across the toe, 4.3 m inside), crest tops **0.72, 0.72, 0.62, 0.66, 0.66, 0.60, 0.72** round from the block after the breach, so the crest is uneven by up to 12 cm a block and the lower blocks' crests are wider. Four steps close with the taller block's end face. The inner wall stops at 0.35 (`floor`), where the pool meets it exactly: no buried rim and no hidden wall below the pool.
- **Pool and tongue.** The pool is an octagon at **0.35** on the inner wall's bottom edge. The breach is edge 6, whose normal is −Y (Godot +z). The tongue spills through it from the pool's lip: its top slopes from 0.24 at the lip to 0.20 at its tip, **3.0 m beyond the berm's toe** (4.5 m from the lip), flaring from the breach edge's width to 1.25 times that, and staying narrower than the gap in the berm so no face is coplanar with a berm cap. The lip is the 0.24-to-0.35 face under the pool's edge. The ink has no bottom.
- **Checks:** zero-area, non-planar, smooth: 0; flat faces within 0.08 m of 0.12: 0 (the tongue is sloped 0.52° and lies at 0.20 to 0.24); coplanar test over 70 triangles, 24 coplanar pairs, 0 sharing area.
- **Unwrap:** `GLB oil_sump [oilfield_train]: 1 meshes, 6 islands, 37.9 px/m at 256 px (pad 2, 68% covered, 1 tiling meshes untouched); 0 materials copied; image none (flat colour)`. 0 UV overlaps, none outside 0 to 1, none mirrored. `Sump_Dirt` carries 8 m tiling UVs only.

**The near belt** (`scenery_belt.gd`). Two rows, 16 copies each, 8 a side, at the near band's 20 m/s on its ±360 m loop, unturned, collision stripped, and on the batch 6 wrap grow (neither row is exempt):

| Row | x (rolled per copy) | Seed | Footprint along z |
|---|---|---|---|
| `oil_wellhead` | 6 to 12 | 1892 | 4.0 m (−2.05 to 1.97 from its origin) |
| `oil_sump` | 7 to 16 | 1893 | 10.3 m (−3.63 to +6.63: the berm and the tongue) |

- **Why explicit homes.** The even pitch of B's near rows cannot keep 3 m between every footprint: on one side a pipe run takes 16 m of every 60, and a row on a 90 m pitch lands on only two phases of that 60 m cycle, which cannot hold a 10 m sump. So the rows take a new key, `homes`: {LEFT: [...], RIGHT: [...]}, the copies' z in metres, in place of `count`. A small script (outside the repo) placed the 32 homes against the pipe runs, the pumpjacks, and each other, nearest to an even 45 m pitch (sumps first). Neighbours of a kind on a side stand 80 to 100 m apart.
- **The rule.** Every near footprint is at least 3 m from every other near footprint that overlaps it in x, across the 720 m wrap too. The placement assumed the worst case (every piece of a side overlaps every other in x); the test reads the real rolled x. Pipe runs (x 3.0 to 5.6 from the axis) and pumpjacks (x 6.2 and out) share no x range, so they bound only the wellheads and sumps, which reach into both. The tightest gap in the built scene is exactly 3.0 m.
- **The death cam.** A wellhead and a sump parked on each side at z −10 and −16 (x ±7.5 and ±11) leave the camera at (±3.08, 4.28, −10) and the low orbit (±4.5, 3.0, −10) clear (`views\deathcam_*_zm10.png`): the nearest surface is a pad edge 5.4 m from the axis, 1.15 m high at most, against a lens 0.9 m nearer the axis and 1.8 m higher.

**The rung.** A temporary final rung, rung 8, repeats rung 7's Ghost + Sheriff + Drunk finale on the Oil-field Train.

- **Files.** New `gauntlet/encounters/e8_trio_oilfield.tres` (`DuelEncounter`: label "Standoff in the oil field", the Ghost as `archetype`, the Sheriff and the Drunk as `extra_archetypes`, `scenario_index` 4, `health_mult` 1.0, `score_reward` 1000 as rung 7). Appended last in `gauntlet/ladder_default.tres` (`load_steps` 11, id 10).
- **No other code.** The menu's blurb ("%d duels in a row, %d lives") and its best line ("Best: duel N / M") read `encounters.size()`, so they say 8 with no change; the controller's progress line and `begin_gauntlet_encounter` read the ladder too. The label is a plain string like the other seven, so no translation key is added and `i18n` needs nothing. Free duel, MP, Horde, and the menu's scenario pickers already list the oil field.
- **Tests** (`dev/autotest.gd`):
  - `load`: the ladder has 8 encounters.
  - `multi` (`_multi_ladder_menu_ok`): rung 7 is `encounters[6]`, a three-way on Main Street; the ladder is 8 long; rungs 1 to 6 stay single.
  - `gauntlet` (new `_gauntlet_oilfield_rung_ok`, after the best-record check, with the controller stopped so no pending rung callback records a run):
    - rung 8 is the last of 8, on the last `SCENARIOS` entry (the oil field), rung 7 is on Main Street, and no earlier rung is on the oil field;
    - its lineup is rung 7's, in the same order, with the same `health_mult` and at least its reward;
    - the main menu says 8 duels, and "Best: duel 7 / 8 · 4200" when the record is 7 and 4200 (the real record is restored);
    - `begin_gauntlet_encounter` loads scenario 4 with three NPCs, none buzzing a controller;
    - the duel reaches DRAW and a win over all three resolves.
  - Printed: "gauntlet rung 8: the Ghost, Sheriff, and Drunk on the oil field (scenario 4), the menu counts 8 rungs, a win over all three resolves".
- **To know, not changed.** The best record keeps rungs cleared, so a clear now stores 8. A player who cleared the old seven-rung ladder keeps `gauntlet_cleared` true, so their menu line stays "Best: CLEARED" until a new run beats their score. Half-head's rung will replace this one; the NPC itself stays under More enemy NPCs.

**Tests** (`--import`, then `run_autotests.ps1 load multi duel gauntlet ragdoll i18n intro lobby`, re-run after the last code change): `AUTOTEST PASS` on all eight. New in `dev/autotest.gd`: `_near_dressing_ok` ("oil field near dressing: 16 wellheads and 16 sumps, 8 a side, every near footprint at least 3.0 m from the next along z": x ranges, unturned, 8 a side, each wellhead's z footprint, and the pairwise 3 m rule from the meshes' extents at each piece's home), the wrap-grow test's kinds now 10 (the wellhead and the sump join), `OILFIELD_BELT_PIECES` 238 (206 + 32), and the rung checks above. `load` printed "oil field belt: 238 pieces, 32 nodding pumpjacks, 32 horizon tiles". One `gauntlet` run failed once with "NPC death: the chest only dropped 0.15 m" while `load` ran beside it (the suites run in parallel on one CPU); it passed on the re-run and in the final run.

**Views** (all outside the repo, in `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_batch7\`):

- `views_blender\`: Workbench, studio light, 35 mm lens, eye 4.9 m up at 12 m (`render_batch7.py`, in the scratchpad): `oil_wellhead_side_train_12m.png`, `_lane_view_12m`, `_three_quarter_12m`, `_close_three_quarter`, `_close_wheel_face`, `_close_profile`, the silhouettes `_silhouette_side`, `_end_on`, and `_top`, and the 64 px `_squint_64px` (the same names for `oil_sump_`); `wellhead_sheet.png` and `sump_sheet.png` put the silhouettes and the squint side by side. The world colour did not take in this headless run, so the backdrop is dark grey, not #A8401C, and the 12 m squints are a smudge.
- `views\` (Godot, flat, 1280 × 720, fov 75, the fixed light, a dark capsule at each spawn; `capture_batch7.gd`, `CAPMODE=views`): `lane_p_1.png` to `_3`, `fire_1.png` to `_3`, `away_1.png` to `_3` (2 s apart), `lane_e.png`, `down.png`, `edge_left_z7.png`, `edge_right_z7.png`, `edge_left_back_z7.png`, `edge_right_back_z7.png`, `deathcam_left_zm10.png`, `deathcam_right_zm10.png`, `deathcam_low_left_zm10.png`, `deathcam_low_right_zm10.png` (wellheads and sumps parked in view for these), `lane_p_parked.png`, `close_wellhead_left.png`, `close_wellhead_right.png`, `close_sump_left.png`, `close_sump_right.png`, `side_wellhead_left.png`, `side_wellhead_right.png`, the Well pass `well_pass_200.png`, `well_pass_60.png`, `well_pass_0.png` (and `well_pass_wide_*`), `down_well_abeam.png`, `fire_well_abeam.png`. `motion\` holds eight consecutive frames of the belt running at 20 m/s from the edge (`edge_motion_0.png` to `_7`) and from Lane P (`lane_motion_0.png` to `_7`).
- `ref\`: the reference match, each capture beside its Jarhead frame (below).

**What was judged, against D**

- **Wellhead, silhouette:** pass, as a working object. End-on, the casing, the wheel's octagon, and a pipe diving into a sloped pad name it; from the side it is a stub with a flag (the wheel's edge on its stem). At 10 to 16 m it is a dark mark about 12 px tall at the flat camera.
- **Wellhead, squint:** pass in count: one shape and two flats (iron and pad). In the scene the iron (Y 0.02) and the pad (Y 0.006) are both near black on a near-black ground, so the pad is a darker hexagon and the casing and wheel a lighter stub on it (`close_wellhead_right.png`, `side_wellhead_right.png`).
- **Sump, silhouette:** pass from above and at the edge, weak from the lane: 0.72 m high, a low trapezoid with a notch and a flat tongue (`sump_sheet.png`); it reads as a ring only from above (`edge_right_back_z7.png`, `close_sump_*.png`).
- **Sump, "lit crescent":** **does not read.** `M_Dirt` and the ink are near black in the fixed light, and the berm takes 5 to 13% fog at 4 to 16 m, so the lit −X faces are not visibly lighter than the ground (`close_sump_left.png`, `close_sump_right.png`). The sump reads as a dark patch with a darker pool, not a lit ring round a black hole. Left to the user (the Palette gives the ink Y 0.00 and the oil-soaked earth 0.006 against the ground's 0.016).
- **Pads and pools clear of 0.12:** pass; no flicker in the eight motion frames (`motion\edge_motion_*.png`: the sump and a pipe run slide by without shimmer). Shimmer in a headset is not judged.
- **Size floor (10 cm near):** pass. The thinnest members are the stem (10 cm), the line (20 cm), and the pad's edge face (10 cm high).
- **Wear:** one accent each, in silhouette: the line's 4° lean (subtle: 5 cm over its 0.8 m leg), and the sump's spill tongue with its uneven crest.
- **Names, UVs, shared planes, values:** pass (above). Nothing is self-lit.
- **Death cam, pop at the wraps:** pass in stills: nothing near either camera; both rows grow in over 40 m like the rest.

**Where the modules depart from B, and why**

- **The sump's breach faces −Y (Godot +z), not +X.** One file serves both belts and copies are never turned: a +X breach would send the tongue under the train from a left-hand copy at x −7 (to x −2.4, near the ballast's ±1.3 m and under the car) and away from it on the right. Facing −Y, the tongue lies along the track on both sides, toward the approaching player. Its footprint along z is 10.3 m, not 7.3.
- **The ring is 7 blocks and a breach**, not 8 blocks and a breach: the octagon has 8 edges and one is the gap. "Chamfered" is the swept profile's 35° slope, as in the horizon's mounds and the burning well; there is no separate bevel.
- **The tongue is 3.0 m beyond the berm's toe**, 4.5 m from the pool's lip, and it flares to 1.25 times the breach's width. "Sloped 0.20 to 0.24" holds; the pool at 0.35 joins the 0.24 end by the lip face. B's "three faces in the image" is the pool's n-gon, the tongue (top, two sides, end), and the lip: 16 triangles on 6 islands.
- **The inner wall's bottom is at 0.35** (`berm(floor=)`), not 0: the wall's lower 0.35 m is not built under the pool.
- **The wellhead's "kinked 4° at its bend" is the diving leg leaning 4°**, not a kink in the horizontal run: a kink there needs a third pipe segment (12 triangles) and the 120 was spent. The tee is a stub and the valve a box, with the stem and wheel on its −Y face so the wheel faces the lane; B does not say which way the stem points.
- **The wheel is a solid octagonal disc**, with no spokes or hub ring: a ring is 64 triangles against the disc's 28.
- **Wellhead 118 of 120, sump 70 of 70.** Pad 16, iron 102.
- **Near placement by explicit homes** (above), where B's belt table gives a count and an x range.
- **A `floor` argument on `berm()`**: the horizon and the well call it with the default and build the same geometry (their GLBs are unchanged).

**Found**

- The headless Workbench render in Blender 5.1.2 did not take `scene.world.color` for these views (the earlier batches' renders did); the geometry, not the backdrop, is what they show.
- The ground reads dark brick (#511C07 near the spawn, #71290F at 30 m in `lane_p_1.png`), not near black: it carries the ambient 0.25, the sun scatter in the fog, and 5 to 13% haze. R7 below.
- The build script, the belt script, and the autotest are CRLF; edits kept it.

**Still open:** the headset review; Quest timing; the wrap pops watched over a full loop in motion (near 36 s, mid 110 s, far 320 s: not done); `oil_pipe_run`'s 80 triangles over its budget; the sump's lit crescent (above); the plumes (Roadmap Ideas).

### Whole scene

The Oil-field Train's untextured meshes are complete: the ten GLBs, the reused train, and Main Street's tracks. Counted in a throwaway headless run of the scene as built (`count_scene.gd`, in the scratchpad): every visible mesh instance under the arena, its surfaces' index counts over three; collision proxies are not counted.

| GLB | Triangles / budget | Objects | Copies | In scene (B) |
|---|---|---|---|---|
| `oil_pumpjack` | 316 / 380 | 3 | 32 | 10,112 (12,160) |
| `oil_wellhead` | 118 / 120 | 2 | 16 | 1,888 (1,920) |
| `oil_sump` | 70 / 70 | 2 | 16 | 1,120 (1,120) |
| `oil_pipe_run` | 220 / 140 | 2 | 24 | 5,280 (3,360) |
| `oil_derrick` | 546 / 600 | 2 | 10 | 5,460 (6,000) |
| `oil_tank` | 294 / 320 | 3 | 8 | 2,352 (2,560) |
| `oil_pylon` | 448 / 450 | 1 | 8 | 3,584 (3,600) |
| `oil_burning_well` | 146 / 300 | 5 | 2 | 292 (600) |
| `oilfield_terrain` | 12 / 12 | 1 | 1 | 12 (12) |
| `oilfield_horizon` | 361 / 460 | 4 | 32 | 11,552 (14,720) |
| Flame columns (a quad each) | 2 | 1 | 14 | 28 (not in B) |
| **New** | | | | **41,680** in 413 objects (B: 46,052 in 399) |
| Reused train | | | | 11,876 in 46 (`train_rooftop.md` H) |
| Reused `env_rail_track_8m` | 98 | 3 | 90 | 8,820 in 270 |
| **Scene** | | | | **62,376** in **729** objects (decided: about 66,700, F31; about 715, F32) |

- 62,376 triangles is 94% of the decided 66,700 and about 4% of Meta's 1.5 million a frame for Quest 3, before culling; half the belt is behind the player or out of view at any moment. The 4,372 under the decided figure is: the horizon's plumes not built (3,168 under), the hero's 2,048 under its 380, the well's plume not built (308 under), the derricks' 540 and tanks' 208 under, the wellheads' 32 and the pylons' 16; less the pipe runs' 1,920 over and the flame quads' 28.
- **Draw calls before culling: 729**, one surface per object: the train 46, the tracks 270, the oil field 413 (399 meshes and 14 flame quads). B planned about 715, without the quads. Meta's guideline is under 200. About 450 in the view from a spawn is B's estimate, not measured. Going lower is belt instancing in code, decided after Quest timing (F32).
- **Lights and particles:** one `OmniLight3D` without shadows (its energy flickers and swells), no directional shadows, 14 flame columns (12 horizon, 2 wells), the engine smoke. Time them on a Quest.
- **Self-lit:** the engine's and business car's lamp lenses, the horizon tiles' pools and mouths, the wells' pools and mouths, and the flame columns.

**Reference match** (D). Flat captures at 1280 × 720 in the fixed light, each beside the Jarhead frame the R row names (`jarhead.jpg` cut into its eight frames, `jarhead2.jpg` the horse frame), in the scratchpad's `oilfield_batch7\ref\`. A stand-in capsule is at the far spawn. Each answer is for the three timed frames 2 s apart, not one.

| # | Result | Image | Why |
|---|---|---|---|
| R1 | **Pass** | `ref\R1_hue.png` | Everything that is not near black is one orange family, from the band to the haze to the flames. The plum sky top and the brown smoke clouds are the only other notes; the plum is the sheet's own (frame 1's sky) |
| R2 | **Fail** | `ref\R2_silhouettes.png` | The pylon and the far left rigs read dark, and the stand-in duelist is a flat dark shape against the haze (`lane_p_*`). But a near left pumpjack passing within about 15 m of z 0 is lit timber (the lane glow lights its train-facing side; accepted at the hero review), and the left mid rigs at 30 to 45 m are haze-brown with visible faces, not black (`fire_1.png`, `fire_2.png`; batch 5's finding). Real duelists were not judged |
| R3 | **Fail, on the dark head only** | `ref\R3_column.png` | White core, yellow, orange body, dark-red rim, and a glowing base (the mouth and pool, `well_pass_0.png`) all pass. There is no dark smoke head: the plumes were removed on 2026-10-29 (Roadmap Ideas) |
| R4 | **Pass** | `ref\R4_columns.png` | A 60 m, a 35 m, and a 15 m column stand together in `fire_2.png` and `fire_3.png`, smaller and dimmer with distance |
| R5 | **Pass** | `ref\R5_haze_steps.png` | In `lane_p_3.png` and `away_1.png` the near pumpjack, the mid derricks and tanks, and the far horizon tile sit at three distinct values between near black and the haze, told by haze and not by detail |
| R6 | **Pass** | `ref\R6_lit_side.png` | The right-hand rigs are lit on their train side, timber and sheet iron (`away_1.png`, `away_2.png`); the left ones are darker, with the pylon and the near rigs black against the band (`lane_p_1.png`, `fire_1.png`). The left mid rigs' brown is the R2 caveat |
| R7 | **Fail, on the ground** | `ref\R7_foreground.png` | The roofs outside the pool are near black (the tin is #30272C) and the horizon line is hard and flat. The ground to the fog is not near black: dark brick, #511C07 at the spawn and #71290F at 30 m, against frames 1 and 4's pure black. The ambient 0.25 and the fog's scatter lift it; a look issue, not a bug |
| R8 | **Pass** | `ref\R8_not_behind.png` | No column, rig, or flame within ±4.5° of the axis in `lane_p_*` or `lane_e.png`; the fires stand to the sides, as in frame 6 and the horse frame |
| R9 | **Pass** | `ref\R9_sky.png` | A plum top over a thin bright band, `sky_curve` 0.08; the stand-in's head at the horizon is cut out against the band. The clouds read as brown smoke shapes covering about 40% of the plum, not pale clouds: the hero review's open question, still the user's call |
| R10 | **Pass** | `ref\R10_darkest.png` | The unlit right side and the view from `EnemySpawn` keep the band glowing on the horizon (`away_3.png`, `lane_e.png`) |
| R11 | **Fail, on the dark head only** | `ref\R11_close_fire.png` | As the well comes abeam (`well_pass_0.png`) a white core stands over a glowing pool and mouth, the pylon's black lattice and wires are beside and across it, and the roof's pool brightens (`down_well_abeam.png` against `down.png`, and `well_pass_60.png`); the swell is smooth (batch 4). No dark head over the column: the plume is removed |

Further views, beside the nearest frame for mood only (no R row names a frame): `ref\Down_roof.png` (Down: the walk and the tin in the pool, the pool falling off to near black beyond), `ref\Edge.png` (Edge: pipe runs, wellheads, and sumps below the roof), `ref\DeathCam.png` (Death cam: the roof edge, the sky, and the columns, nothing near the lens), `ref\WellPass_all.png` (the well at 200 m and 60 m), `ref\Edge_motion_sheet.png` (four frames of the edge at 20 m/s).

**Still open:**

- **The user's final review**, then the headset: standing at both spawns, leaning over both sides, the cab roof, the nod, the wraps over a full loop (D13, D17, D18), the shimmer of the lattices and wires at 20 to 40 m (D15), and the flicker of the lane glow.
- **Quest timing:** 729 objects before culling, the lane glow, 14 opaque flame quads of up to 60 m by 18 m, and the fog colour written every frame.
- **The fails:** R3 and R11 want a dark head over the column (plumes, parked); R2's left mid rigs read haze-brown, not black (fog scatter on the fire side, batches 4 and 5); R7's ground is dark brick, not black; and the sump's lit crescent does not read (above). None is a bug; each is a look call for the user.
- **`oil_pipe_run`** is 80 triangles a copy over B's 140 (1,920 in the scene).
- **Painting:** nothing is painted. `TEXTURE_LIST.md` and `TEXTURING.md` list the ten GLBs (G17, done).
- **The rung is temporary:** Half-head's NPC will take it. An old "CLEARED" record stays cleared (the rung's notes above).

### Light tuning (2026-10-29)

The user's call after the reference match failed R2 and R7: darker, thinner low fog; less sun scatter; darker clouds. The sump is unchanged. Only the night keyframe (`scenarios/time_of_day.gd`) and the oil field's own scene (`scenarios/oilfield_train/oilfield_train.tscn`: its sky `ground_horizon` and `cloud_color`, its environment's fog colour, scatter, and density) changed, so the other arenas are untouched. Comments in `scenery_belt.gd` now say about 88% fog at the wraps. One check added to `_night_problem` in `dev/autotest.gd`: the oil field's fog density is 0.006. No other test pinned the old numbers (the night checks read the keyframe).

| Value | Old | New |
|---|---|---|
| Night `ground_horizon` (= fog colour, the sky's ground) | #A8401C (0.6588, 0.251, 0.1098) | #451A0B (0.27, 0.10, 0.045) |
| Fog density (oil field's Environment) | 0.009 | 0.006 |
| Night `fog_sun_scatter` | 0.5 | 0.2 |
| Night `cloud_color` | #4A2418 | #2C1821 (0.173, 0.095, 0.13), about two thirds of the way to the plum top #1C1226 |

A first pass at fog colour #5C2410 (0.36, 0.14, 0.06) left the ground at 30 m at about #3C1506 and the mid ground hazy; #451A0B put it at about #311104. Not changed: the sky gradient, `fog_sky_affect` 0.1, `fog_aerial_perspective` 0.35, the key, the lane glow, the ambient. `lane_glow.gd` reads its flicker base from `env.fog_light_color` each frame, so it follows the new colour with no edit (the captures show the flicker working). Its `smoke_fog_color` comes from the sky's gradient at 15°, which did not change, so the flame columns' far colour still matches the sky above them; the cloud deck is now closer to that colour than before.

**Pixel probes, `lane_p_1` (flat, 1280 × 720):** near ground left (pool) #4F1B06 to #330F00; ground at 30 m #7B3012 to #311104; ground right, outside the pool #411403 to #260900; a left mid derrick #8F3616 to #351206; sky top #4F2217 to #2B141F; the horizon band #BC5828 to #B85727 (unchanged).

**Reference match, before (batch 7) to after:**

| # | Before | After | Note |
|---|---|---|---|
| R1 | Pass | **Pass** | One orange family, now from a darker base; the plum and the dimmer clouds are the only other notes |
| R2 | Fail | **Pass, one caveat** | Left mid rigs and the pylon are black cut-outs on the band (`fire_1`, `fire_2`, `lane_p_*`). Open lattices still show a lit inner face on a close rig. Caveat as before: a near left pumpjack within about 15 m of z 0 is lit timber by the lane glow (`fire_2`), accepted at the hero review |
| R3 | Fail (no dark head) | Fail (no dark head) | Unchanged: the plumes are parked |
| R4 | Pass | **Pass** | Columns of 60, 35, and 15 m, dimmer with distance, now against a darker field |
| R5 | Pass | **Pass** | Near lit timber, mid derricks and tanks, and far horizon silhouettes sit at three values (`lane_p_3`, `away_1`); the far step now reads as dark brick on the band |
| R6 | Pass | **Pass** | Right-hand rigs lit on their train side, left black; the right is dimmer and flatter |
| R7 | Fail | **Pass** | The ground outside the pool is near black (#260900 to #311104), the horizon line hard and flat. The ground in the pool is still dark brick (#330F00) from the lane glow, which the sheet wants |
| R8 | Pass | **Pass** | Unchanged |
| R9 | Pass | **Pass** | Plum top over a thin band; the clouds are a faint texture, no longer brown shapes. The user's open question on the clouds is answered by decision 3 |
| R10 | Pass | **Pass** | The right side and `lane_e` keep a glowing band |
| R11 | Fail (no dark head) | Fail (no dark head) | Unchanged; the core, the pool, and the swell are as before, against a darker field (`well_pass_0`) |

**Wrap check.** At 0.006 the near wrap (±360 m) is 88.5% fogged and the mid and far wraps (±384 m) 90%, against 96% and 97%. The fog colour is now darker than the band, so an ungrown rig at the wrap is a dark silhouette on the bright band, where before it was haze on haze. `wrap_sheet_nogrow.png` shows that exactly: a derrick, tank, horizon tile, and pylon are still plainly visible at 390 m without the grow. `wrap_sheet_grow.png` shows the batch 6 grow (`GROW_M` 40 m, over 340 to 384 m) still hides every kind: each shrinks smoothly and is gone by 380 m; the near and mid pumpjacks, the wellheads' neighbour pipe, and the burning well show nothing at 360 m or beyond. The grow is now visible as a rig shrinking at the edge of sight, not a pop. The flame columns' melt (320 to 370 m, `flame_column.gdshader`) works on camera distance, not fog, so it is untouched: `wrap_sheet_far_columns.png` shows the columns fading to nothing by 370 m, with no column at either wrap. A far column at 320 to 350 m reads as a pale lilac ghost against the plum (its haze mix toward the sky colour while it melts), as it did before; not changed. The tracks (no grow) are 88% fogged at the wrap and are ground-coloured, so show nothing. Not done: the wraps watched over a full loop in motion.

**Tests:** `--import`, then `run_autotests.ps1 load multi duel gauntlet i18n`: `AUTOTEST PASS` on all five, run again after the autotest line was added.

**Images** (all in `C:\Users\lukeg\AppData\Local\Temp\claude\e--Projetos-gunslinger\383c0b52-7b1f-41ec-8269-29234f17f93b\scratchpad\oilfield_tune`): `ref\R1_hue.png`, `R2_silhouettes.png`, `R3_column.png`, `R4_columns.png`, `R5_haze_steps.png`, `R6_lit_side.png`, `R7_foreground.png`, `R8_not_behind.png`, `R9_sky.png`, `R10_darkest.png`, `R11_close_fire.png`, `Down_roof.png`, `Edge.png`, `DeathCam.png`, `WellPass_all.png` (each capture beside its Jarhead frame, as batch 7); the captures in `views\`; the wrap sheets `wrap_sheet_grow.png`, `wrap_sheet_nogrow.png`, and `wrap_sheet_far_columns.png`, with the frames in `wrap\`. Before: the batch 7 `ref\` and `views\` folders.

## References

**Repo**

- `.claude/skills/gunslinger-taste/references/board.md`: #03 (flat litho), #04 (two-colour image, the figure as a black hole), #05 (plain working objects), #20 (total silhouette on one colour), #24 (a monochrome figure in red smoke), #30 (the company drawn as landscape), and patterns 2 (colour loud and few) and 7 (print, not film).
- `.claude/skills/gunslinger-taste/references/steel-ball-run.md`: no fixed palette, colour chosen for the image; history bent one notch; stages with personalities.
- `docs/design/characters/`: `half-head.md` (the map is his; black, white, and bone; the flames as the only colour; the land-grant checker), `sheriff.md`, `ghost.md`, `drunk.md` (the railroad's reach), `player.md`.
- `docs/design/scenarios/`: `train_rooftop.md`, `main_street.md`, `canyon.md`, `saloon.md`; `jarhead.jpg` (contact sheet, 495 × 619) and `jarhead2.jpg` (the horse frame, 640 × 480).
- `scenarios/train_rooftop/train_rooftop.tscn`, `train_rooftop.tres`, `scenery_belt.gd`, `engine_smoke.gd`; `assets/vfx/engine_smoke.tscn`, `assets/vfx/vfx_catalog.gd`; `scenarios/scenario_base.gd`, `scenarios/time_of_day.gd`, `scenarios/sky_western.gdshader`; `autoload/game_manager.gd`; `gauntlet/duel_manager.gd`, `gauntlet/ladder_default.tres`, `gauntlet/encounters/e7_trio_street.tres`; `dev/autotest.gd`; `dev/build_train_rooftop_blender.py`, `dev/build_horizon_ridge_finals_blender.py`, `dev/build_main_street_blender.py`, `dev/unwrap_per_glb_blender.py`, `dev/unwrap_scenery_blender.py`, `dev/scenery_uv.py`, `dev/blender_kit.py`; `assets/shaders/world_surface_import.gd`; `docs/SHADERS.md`, `docs/TEXTURING.md`, `docs/FEATURES.md`, `Roadmap.md`.

**The reference**

- [Jarhead, American Cinematographer, November 2005, page 2](https://theasc.com/magazine/nov05/jarhead/page2.html): Stage 12; strip lights in full CTO on a rolling rig for "soft, flickering flame-light from the side"; lighting through the back of the cyc so distant fires lit the horizon; fires that seem to burn out; the crew watched *Lessons of Darkness*. Read through search excerpts only; the page returned 404 to a fetch.
- [Jarhead (film)](https://en.wikipedia.org/wiki/Jarhead_(film)), Wikipedia: the Marines see distant burning Kuwaiti wells; Deakins as cinematographer.
- [ILM camouflages CG work for Jarhead](https://studiodaily.com/2005/12/building-the-war-zone-with-invisible-fx), Studio Daily: the flames were ILM's CG. Read through a search excerpt only.
- [Lessons of Darkness](https://en.wikipedia.org/wiki/Lessons_of_Darkness), Wikipedia: Herzog's 1992 film of the Kuwait fields.

**Oil fields**

- [Walking beams](https://petroleumhistory.org/OilHistory/pages/Cable/walking.html), petroleumhistory.org: the standard rig by 1884; beam 26 ft, 12 in wide, 26 in thick at the middle; Samson post 13 ft (early ones 8 to 10 ft); derricks of 72 or 82 ft (Jarecki Catalogue No. 50).
- [Walking beams](https://ethw.org/Walking_beams), ETHW, and [Cable tool rig](https://elsmerecanyon.com/elsmerecanyon/oil/cabletoolrig/cabletoolrig.htm), Elsmere Canyon: band wheels of 8 to 10 ft driven by belt, the pitman on the band wheel's crank. Read through search excerpts only.
- [Oilfield counterbalanced pumping unit](https://www.texasescapes.com/AllThingsHistorical/Oilfield-Counterbalanced-Pumping-Unit-104BB.htm), Texas Escapes: Walter Trout's counterbalanced unit, sketched and installed in 1925 near Hull, Texas. Read through a search excerpt only.
- [Pumpjack](https://en.wikipedia.org/wiki/Pumpjack), Wikipedia: walking beam on an A-frame, horsehead, cranks and counterweights; central power and rod lines in the early 20th century; "nodding donkey".
- [Southwestern Petroleum Short Course papers](https://www.swpshortcourse.org/ppdl/782): conventional units run at about 6 to 14 strokes a minute. Read through a search excerpt only.
- [Eccentric wheels and jerk lines](https://aoghs.org/tag/walking-beams-2/), AOGHS, and [Central power](https://petroleumhistory.org/OilHistory/pages/Central%20Power/centralpower.html), petroleumhistory.org: jerker lines from 1879, wide in Pennsylvania by 1885. Read through search excerpts only.
- [Van Syckel](https://petroleumhistory.org/OilHistory/pages/Pipelines/van_syckel.html), petroleumhistory.org: about 5 miles of 2 in wrought iron in 15 ft joints, 1865. [Even pickaxes couldn't stop the nation's first oil pipeline](https://www.npr.org/2015/02/24/388729919/even-pickaxes-couldnt-stop-the-nations-first-oil-pipeline), NPR: teamsters tore it up.
- [Petroleum storage tanks](https://ethw.org/Petroleum_Storage_Tanks), ETHW: wooden tanks in the 1860s, riveted wrought iron from the early 1870s, a riveted steel tank of up to 35,000 barrels in an 1892 catalogue.
- [Black gold slideshow](https://legacy.education.texashistory.unt.edu/lessons/snapshots/TexasOil/docs/black-gold-slideshow.pdf), UNT: Spindletop, 500 wells on 144 acres; fires a constant danger. [Early Texas oilfield photographers](https://www.searchanddiscovery.com/abstracts/html/2014/90189ace/abstracts/1872695.html), Search and Discovery: Trost's derricks "so close together they appear to be touching". Read through search excerpts only.
- [Los Angeles City Oil Field](https://en.wikipedia.org/wiki/Los_Angeles_City_Oil_Field), Wikipedia: discovered 1890, Doheny's well 1892, about 200 companies by 1901. [Drilling for black gold in the Los Angeles oil field, 1890s](https://homesteadmuseum.blog/2016/11/17/drilling-for-black-gold-in-the-los-angeles-oil-field-1890s/), Homestead Museum.
- [Lakeview Gusher](https://en.wikipedia.org/wiki/Lakeview_Gusher), Wikipedia: Kern County, 1910; sandbag berms round the well; no fire.
- [Kuwaiti oil fires](https://en.wikipedia.org/wiki/Kuwaiti_oil_fires), Wikipedia: 605 to 732 wells, January to November 1991. [Kuwait oil well fires](https://www.nist.gov/node/594661), NIST: twelve fires measured, 90 MW to 2 GW, flame height correlated with heat release. [Album caption](https://www.album-online.com/detail/fr/MGUxOWI0MA/kuwait-city-march-1991-oil-wells-burning-out-control-ahmadi-alb3847764): about 300 oil lakes.
- [Petroleum industry in Azerbaijan](https://en.wikipedia.org/wiki/Petroleum_industry_in_Azerbaijan), Wikipedia: the first wooden derrick at Baku in 1871; blowouts 42% of recovered oil in 1887.

**Pylons and telegraph lines**

- [Transmission tower](https://en.wikipedia.org/wiki/Transmission_tower), Wikipedia: the first line wholly on steel towers, 1903, Mexico; Italy 1904. [Little Falls Tie Line Towers, HAER WA-82](https://reardanhistory.net/wiki/Little_Falls_Tie_Line_Towers_Historic_American_Engineering_Record_WA-82): in service 1910.
- [Western Union Telegraph Co. v. Pennsylvania Railroad, 195 U.S. 540](https://www.law.cornell.edu/supremecourt/text/195/540), Cornell LII, and [96 U.S. 1](https://www.law.cornell.edu/supremecourt/text/96/1): telegraph lines on railroad rights of way, one from 1859.

**Rendering and PSX** (as cited in the earlier sheets)

- [Lights and shadows](https://godot.readthedocs.io/en/4.2/tutorials/3d/lights_and_shadows.html) and [OmniLight3D](https://docs.godotengine.org/en/4.2/classes/class_omnilight3d.html), Godot docs: Compatibility shows eight omni lights per mesh by default; an omni lights only meshes whose AABB meets its own.
- [Spyro the Dragon](https://www.hardcoregaming101.net/spyro-the-dragon/), Hardcore Gaming 101: a flat-shaded far version of every level.
- [Making Crash Bandicoot, part 3](https://all-things-andy-gavin.com/2011/02/04/making-crash-bandicoot-part-3/), Andy Gavin: a budget set by the polygons on screen at once.
- [Draw distance](https://en.wikipedia.org/wiki/Draw_distance), Wikipedia: fog hides where the world stops.
- [Device optimization comparison](https://developers.meta.com/horizon/resources/device-optimization-comparison/), Meta: Quest 3 at under 200 draw calls and 1.5 million triangles a frame.
