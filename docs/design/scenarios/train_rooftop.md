# Train Rooftop: design sheet

| | |
|---|---|
| Status | `partial`: built, untextured, awaiting the user's review. Decided 2026-10-23 (section F). Built 2026-10-26 in five batches (H): the GLB split (C step 1), the hero `train_car_coach` with `train_coupler` (C step 2), `train_engine` (C step 3), `train_car_baggage` with `train_car_business` (C step 4), and the horizon's `Canyon`, `Mesa`, and `Butte` spans (C step 6, built by the F19 finals script), all final and untextured; batch 5 also fixed two coplanar spots on the coach. Still to do: the in-context review in a headset (D) and Quest timing. The engine smoke is a separate Roadmap item (F13) |
| Kind | Scenario design sheet: greybox to final, untextured, UV-unwrapped meshes |
| In code | Split into one GLB per asset in `train_rooftop.blend` (`assets/models/scenarios/train_rooftop/`), exported by `dev/unwrap_per_glb_blender.py`: `train_car_coach` (final, 1,556 triangles in 5 objects, ×4), `train_coupler` (final, 100 triangles, ×6), `train_engine` (final, 2,294 triangles in 8 objects), `train_car_baggage` (final, 1,156 triangles in 5 objects), `train_car_business` (final, 1,602 triangles in 7 objects), `train_rooftop` (the four guard walls only), and `horizon_ridge` (11 meshes, 669 triangles: `Canyon` 292 in 4 objects, `Mesa` 236 in 4, `Butte` 141 in 3, all final), all built, untextured, and awaiting the user's review. The spans come from `dev/build_horizon_ridge_finals_blender.py` (F19). `scenarios/train_rooftop/train_rooftop.tscn` instances them under the greybox node names (`CarA`, `Coupler2`, `Engine`, …), keeps `Train` for the guard walls, and adds Main Street's `env_terrain.glb` as `Terrain` and `Scenery` (`scenery_belt.gd`), which loops 90 Main Street tracks, 180 cactus clones, and 84 horizon spans past the stationary train: 46,691 triangles in 902 objects in all (H, Whole scene). The greybox came from `dev/build_train_rooftop_blender.py`, which must not be re-run (G7). The scene facts below describe the greybox as measured before the split |
| Prompt | [`prompts/train_rooftop.md`](prompts/train_rooftop.md) |
| Inherits | [`main_street.md`](main_street.md): global rules 1 to 28, the palette, the backdrop method, and the build lessons. [`canyon.md`](canyon.md): the rock vocabulary, the four rock values, and the band order, for `horizon_ridge`. [`saloon.md`](saloon.md): brass, lamp glass, and two build lessons. The exceptions are in A, each with its reason |

The deliverable is clean, final, untextured meshes with sensible UVs and flat Base Color materials. You texture by hand later, so nothing here plans texture art.

Positions are Godot's (x, y, z), y up, unless a line says Blender. Blender (x, y, z) is Godot (x, z, −y). The train heads −z: "front" is toward the engine, "rear" toward `PlayerSpawn`'s back. Facing the front, +x is the right-hand side. Inside a car, u is the distance toward the front from the car's centre (Blender local +Y).

## Scene facts the design depends on

Read from `train_rooftop.tscn`, `train_rooftop.tres`, the build script, both GLBs, `scenery_belt.gd`, `scenario_base.gd`, `time_of_day.gd`, `ai/duelist_ai.gd`, `autoload/death_cam.gd`, `gauntlet/encounters/e4_sheriff_rooftop.tres`, and `dev/autotest.gd`. The GLBs were measured with a script outside the repo.

### The consist

Markers are given as (x, z); every one stands at y 3.2.

| Greybox root | Godot z | What stands on it |
|---|---|---|
| `CarRearB` | 27.0 to 39.0 (roof to 39.15) | The last car. A ladder on its rear end. `GuardEndRear` stands just past it |
| `CarRearA` | 13.8 to 25.8 | |
| `CarA` | 0.6 to 12.6 | `PlayerSpawn` (0, 10); `EnemySpawns3/C` (0.6, 3.5) |
| `CarB` | −12.6 to −0.6 | `EnemySpawn` (0, −10); `EnemySpawns2/A` (−0.6, −10); `EnemySpawns3/A` (0.6, −11); `EnemySpawns3/B` (−0.6, −5); `EnemySpawns2/B` (0.6, −3.5) |
| `CarFrontA` | −25.8 to −13.8 | |
| `CarFrontB` | −39.0 to −27.0 | |
| `Engine` | Tender −40.32 to −47.12; cab −47.64 to −49.71; boiler and smokebox −49.40 to −55.25; pilot to −56.83 | Tender deck and cab roof walkable; boiler not. `GuardEndFront` stands at the cab's front edge |
| `Coupler0` to `Coupler4` | 26.4, 13.2, 0, −13.2, −26.4 | `Coupler2` sits mid-lane, between the duelists |

- **Cars.** Bodies 12.0 × 2.9 m, y 1.15 to 3.01, at a 13.2 m pitch: 1.2 m gaps between bodies, 0.9 m between roofs (each roof is 12.3 m). Two four-wheel trucks per car, centred 3.7 m off the car's centre; wheels 0.84 m across, 8-sided.
- **Engine.** A 4-6-0: three driving axles (wheels 1.4 m), a two-axle pilot truck. Boiler 1.56 m across, top at 2.73. Stack crown at 4.40, the highest point of the train. Coal heap on the tender's front half, 1.4 × 2.5 m, to y 3.96.

### Frozen numbers

1. **You stand at y 3.20.** Every walk proxy tops out there: each car's `Car*Roof` (11.6 × 3.04 m, y 3.0 to 3.2), the tender and cab roofs with the engine's own gap walk between them, and six gap walks (2.9 × 1.8 m), five between cars and `GapWalkEngine` between the last car and the tender. `--autotest=ragdoll` fails if the floor under any of the seven markers sits more than 1 cm above or 5 cm below it. The AI does not follow the floor: a duelist stays at its spawn's y wherever it strafes.
2. **The track fits the wheels.** The belt's `env_rail_track_8m` has rail tops at +0.21 and rail centres at ±0.70; the greybox wheels sit there (treads from x ±0.62 to ±0.82, bottoms at 0.21). Wheel positions are frozen with the track (Main Street E).
3. **Guard walls.** Four invisible walls 2.2 m tall above the roofs: `GuardSideL`/`R` at x ±1.64 to ±1.92 from z −49.95 to 39.35, `GuardEndRear` at z 39.23 to 39.51, `GuardEndFront` at −49.83 to −50.11. `_vr_rig_ok` checks that stick walking stops at `GuardSideR`'s inner face (1.64). `scenario_base.gd` puts every `Guard*` StaticBody3D in the ragdoll ignore group by that name prefix, and `--autotest=multi` expects at least four. Nothing crosses the lane between the duelists.
4. **Strafe.** Rung 4, "Deputy on the 3:10", is the Sheriff at 1.5× health, `STRAFE` at 0.8: he swings along x at his spawn's z, ±1.5 m (`STRAFE_RANGE`), clamped to ±1.5 by `strafe_half_width`. The mannequin's feet reach ±0.21 m from its root, so his outer boot lands at x ±1.71 at each end of the swing.
5. **Multi markers.** `multi` sweeps a capsule 0.3 m in radius from 0.1 to 1.7 m above the floor at each marker in the table above. No collision may enter one.
6. **Belt names.** `horizon_ridge.glb` keeps three nodes named exactly `Canyon`, `Mesa`, and `Butte` (`_find_named`). Each spans 48 m along Blender Y centred on its origin; `HORIZON_SPAN` is 48 in the build script and in `scenery_belt.gd`.
7. **Nothing on the belt sways.** `--autotest=load` fails if a belt piece takes a sway name (`M_Yucca`, `M_Scrub`, `M_ScrubDry`, `M_Hay`), and it checks that the belt built at least 80 pieces.

### The belt

`scenery_belt.gd` moves pieces toward +z on wall-clock time and wraps them at the ends of their loops.

| Band | Pieces | Copies | Across the track | Speed | Loop |
|---|---|---|---|---|---|
| Near | `env_rail_track_8m` | 90 | Under the train | 20 m/s | ±360 m |
| Near | Cactus plants cloned from `env_desert_scatter` | 180 | x ±4.5 to ±16 | 20 m/s | ±360 m |
| Mid | `Canyon` and `Mesa`, alternating by slot | 20 slots × 2 sides = 40 | x ±28 to ±40, rolled per copy | 7 m/s (0.35×) | ±480 m |
| Far | `Butte` | 22 slots × 2 sides = 44 | x ±70 to ±100, rolled per copy | 2.4 m/s (0.12×) | ±528 m |

- Copies are moved, never turned. A span's +x face looks at the train from the left-hand side; its −x face looks at it from the right.
- Slots are 48 m apart along z, but each copy rolls its own x, so neighbours stand up to 12 m (mid) or 30 m (far) apart across the track, and the mid band alternates two different spans.
- Collision is stripped from every belt piece.

### Sun, shade, and fog

- **Sun.** The authored `Sun` stands 45° up, its yaw toward +x and +z: behind `PlayerSpawn` and to the right. `TimeOfDay` keeps the yaw and moves the elevation: dawn 8°, noon 70°, late afternoon 32°, dusk 12°. Every load rolls its time at random. With `band_low` 0.65 the light has three steps: none (ambient only), middle (65%), full.

| Face | Dawn | Noon | Late afternoon | Dusk |
|---|---|---|---|---|
| Up: roof decks, walks, caps | middle | full | full (just: N·L 0.53) | middle |
| Facing +x: the train's right side, the left-hand spans' train faces | full | middle | full | full |
| Facing +z: every end and face turned toward `PlayerSpawn` | full | middle | full | full |
| Facing −x: the train's left side, the right-hand spans' train faces | none | none | none | none |
| Facing −z: every end and face turned toward the engine | none | none | none | none |

  - The train's left side and every front-facing end never take sun. Shade reads at about a sixth to a seventh of its lit value (the ratios Main Street and the Canyon measured; this scene's ambient is close to Main Street's: energy 0.4 against 0.35, sky share 0.8 against 0.85).
  - From `PlayerSpawn` every end you see faces you and is lit; from `EnemySpawn` every end you see faces the engine and is not. As in the Canyon, the duel is front-lit for the player and backlit for the far end.
  - The train's own shadow falls toward −x and −z, about 23 m long at dawn: over the left-hand cacti, never onto a span.
- **Passing shadows.** By the geometry, at dawn and dusk the right-hand spans throw their shadows across the train: a wall reaches the roofs if it stands taller than about 8 m at dawn and 10 to 14 m at dusk, and the greybox walls stand 17.7 m. So at those two times the duel runs through a band of shade every 48 m, about every 7 s at 7 m/s. Not yet seen in a flat run.
- **Fog.** Exponential (the scene sets no `fog_mode`), density 0.006, tinted with the sky's ground horizon at each time. It takes 11% at the enemy (20 m), 26 to 32% on the engine (50 to 65 m), 15 to 21% on the nearest mid spans (28 to 40 m), 34 to 45% on the nearest far buttes, 88% at the near loop's wrap (360 m), and 94 to 96% at the horizon loops' wraps.
- **Wind.** The loudest arena: bed −14 dB, gusts every 6 to 16 s at strength 1.4. Nothing on the train or the belt sways.
- **No outline on scenery.** Only duelists and held objects carry the ink line (#120D0A), about 4 px wide at 20 m on a Quest 3.

### What you see

From an eye 1.7 m over the roof (y 4.9) at one spawn, looking at a duelist at the other, 20 m away. A standing duelist covers ±0.86° across the shoulders and ±0.7° across the legs; strafing, ±4.3°.

| Band on the duelist | Angle | Behind the enemy, from `PlayerSpawn` | Behind the player, from `EnemySpawn` |
|---|---|---|---|
| Feet to knees (y 3.2 to 3.7) | −4.9° to −3.4° | `CarB`'s roof beyond him, the gap at z −13.2 (−4.1°), `CarFrontA`'s roof | `CarA`'s roof, the gap at 13.2, `CarRearA`'s roof |
| Knees to hips (3.7 to 4.2) | −3.4° to −2.0° | `CarFrontA`, the gap at −26.4 (−2.7°), `CarFrontB`, whose far end lies at −2.0° | `CarRearA`, the gap at 26.4, `CarRearB`, whose rear edge lies at −2.0° |
| Hips to chest (4.2 to 4.7) | −2.0° to −0.6° | The engine's top: tender deck edge (−1.9°), coal heap (to −1.0°, ±0.74° wide), cab roof (−1.7°), domes and bell (−1.6° to −1.4°), stack (to −0.45°, ±0.4° wide). Elsewhere the desert in fog | The ground from 138 m back, at least 56% fog, up to the horizon at −0.27° |
| Head and hat (4.7 to 5.5) | −0.6° to +1.7° | Sky. The horizon line at −0.27°, behind the neck; the cloud deck from +1.7° | The same |

- **The standing enemy hides the engine.** Its coal heap and stack sit behind his torso; they show beside him only while he strafes. At the ends of his swing his legs stand against the ground beside the engine, 64 m away and 32% fogged, with cacti passing.
- **The field at head height is the sky** from both spawns: the Canyon's "open field", which the Canyon rejected for its own rung, the pale Ghost (backdrop check).
- **The roofs are the floor of every view.** The player's own roof runs from under the feet to 10 m ahead. A 10 cm feature is 72 px tall at 2 m on a Quest 3 and 7 px at 20 m.
- **Over the edge.** From the walk's centre the car's own side is hidden by the roof edge; the ground shows from about 4.6 m out. A player at a guard wall leaning out sees the side.
- **Death cam.** It orbits the corpse's chest at 3.2 m (1.4 to 7 m), 16° up, with no collision, so it swings up to about 3 m outside the car sides at roof height plus 1 m. From that height the 0.30 m eave (F5) hides the windows: the death cam sees the duel cars' deck edges and fascias from 1.5 to 3 m. The side wall itself shows only to an eye below the eave or leaning out past it (found in the hero build, H).
- **The cab roof** is the walkable front end. From it the boiler top, domes, bell, stack, and headlight are 1 to 7 m ahead and below: the engine's close-range view.

### The brief's facts, checked

1. **Metric, Z-up, roofs at y 3.2, spawns at z ±10 on cars centred ±6.6:** correct. The walk proxies stop 0.2 m inside each roof's end, and the gap walks overlap them by 0.1 m.
2. **12 m cars, 1.2 m gaps, 13.2 m pitch; two cars behind the player, the duel pair, two ahead, the engine leading toward −z:** correct for the bodies. The roofs are 12.3 m, so the open gap at roof level is 0.9 m.
3. **The stationary train and the belt:** correct, with two horizon bands: `Canyon` and `Mesa` alternate at 0.35×, `Butte` alone at 0.12×. `HORIZON_SPAN` is 48 in both files.
4. **"The horizon spans 48 m ... and its ends must tile":** wrong as stated. The spans are 47.75 m long (`_SPAN_LEN`, so neighbours never share a face), and the belt never lays two spans end to end: each copy rolls its own x, and the mid band alternates `Canyon` and `Mesa`. A span's ends are always seen. Decided: closed ends (F15).
5. **Invisible walls ring the roofs, the shot lane stays open, a thin walk proxy covers each coupler gap, the horizon has no collision:** correct. There are six gap walks; the sixth sits between the last car and the tender, and the greybox puts no coupler there.
6. **"Cliff boxes must not share coplanar faces":** correct for the greybox. Its boxes are inset or buried (walls 47.70 m inside talus 47.75 m, bases buried in the talus, the buttress clear of the wall). How the finals avoid it is in B under `horizon_ridge`.
7. **"Roof surface, hatches, vents, and walkway boards are seen from directly above at close range":** correct for the roofs, but the greybox has none of the three: each roof is a flat slab with two 12 cm lip rails.
8. **"Undercarriage and car sides are seen only while scrolling past":** wrong twice. The train never scrolls; only the scenery does. And the death cam swings outside the duel cars' sides, the cab roof looks down on the boiler, and a player at a guard wall can lean out.
9. **"docs/TEXTURING.md lists the current triangle counts per map":** partly. Its Train Rooftop row (5,972 → 6,940) counts the objects the paused trim-sheet pass unwrapped in both GLBs together, and leaves out the six brass and lamp objects (136 triangles). It does not count the belt, which draws the horizon 84 times and Main Street's track and cacti 270 times. Measured, the scene draws about 30,500 triangles in about 1,380 objects (B).

### Found in the greybox

None of these is in the brief. Where one needs a decision, F asks it.

1. **Buried end walls.** Each car's `BulkA` and `BulkB` (12 objects, 144 triangles) sit inside its body box and are never seen.
2. **The tender's deck floats.** The tender body tops out at 2.87 and its deck starts at 3.02: a 15 cm slot runs round the tender under the walk.
3. **No coupler joins the train to its engine.** The last car and the tender share a gap walk and nothing else.
4. **The Sheriff's boot leaves the roof.** At each end of his strafe his outer boot (x ±1.71) passes through the 12 cm lip rail (x ±1.48 to ±1.56) and hangs 11 cm past the roof's edge (±1.60). F5.
5. **One-sided spans.** The `Canyon` span's buttress stands on its +x face only, so only the left-hand side ever sees it; from the right every span is plain boxes.
6. **Names and colours on the horizon.** `Talus.001` and `Talus.002` carry dots (rule 25). The three rock colours are the greybox tans, and none matches the Canyon's palette since the Canyon's caps went bone.
7. **Draw calls.** 371 train meshes; the horizon's 4, 3, and 7 meshes per span across 84 copies, 448; the tracks' 3 × 90, 270; the cactus clones, about 290 (1.6 meshes per plant). About 1,380 before culling, against Meta's Quest 3 guideline of under 200 per frame.
8. **Band cuts.** The train's counts include 255 band cuts from the paused trim-sheet pass: a car body box is 20 triangles, its roof 28, the tender 76.
9. **Squat cars.** The frozen roof height leaves 1.78 m from the car floor (1.23) to the roof inside. Accepted as the chunky look (A); nothing can raise it without moving every spawn.
10. **Materials.** `M_Car`, `M_Window`, `M_Iron`, `M_Boiler`, `M_Brass`, and `M_Lamp` carry metallic 0.15 to 0.75 and roughness 0.2 to 0.95, which the shader ignores; they only split materials (Saloon G10). `M_Lamp` would not glow: only `M_Flame` and `M_LampGlass` do.

## A. Art direction

The 3:10 is long low boxes on dark trucks, every roof a flat company-blue deck with a raw plank walk down its spine, joined by open gaps over link-and-pin couplers and pulled by a Victorian 4-4-0 dressed as a presentation piece: the walk is the freight car's running board, which brakemen walked from car to car to set the hand brakes (Wikipedia, Running board), bent one notch onto a company passenger train whose deputies ride on top (`steel-ball-run.md`), and the engine is board #06's Tiffany revolver at railroad scale. The train stands still and the desert is reeled past it, the oldest form of this trick: the 1900 Trans-Siberian panorama moved its painted bands at 1,000, 400, 130, and 16 feet a minute past three stationary railway cars, close to the belt's 1 : 0.35 : 0.12, and Hale's Tours shook a dummy Pullman car and blew wind and smoke into it while its films ran, a holdup among them (Wikipedia, Trans-Siberian Railway Panorama; Lost Wonderland), so the horizon is built as painted flats in the Canyon's rock vocabulary, two values a face and closed at both ends, the way Spyro's far levels were flat-shaded shapes (Hardcore Gaming 101; board pattern 7, the printed West). One frozen number sets the proportions: you stand at 3.20 m everywhere, so the cars stay squat, 1.78 m from floor to roof inside, while wheels, windows, railings, and the walk keep true sizes and the eaves, stack, domes, and headlight are fattened to read, as rule 3 does and as board #12's padded, oversized workwear does. Wear is "kept": company property painted all round, one accent per module copy and two or three per one-off, always in silhouette and never on the walk where anyone stands (a sprung walk board, a bent brake staff, a racked cab window, a stack leaning 2°), with the wooden car's real enemy, sag between the trucks, shown by the truss rods whose turnbuckles were tightened to cure it (Trains.com forum) rather than by the deck, which never leaves 3.20. The train is the railroad, so it wears Main Street's company blue with bone letterboards and ink windows (rule 21), and the engine takes the three colours the *Sacramento Bee* gave the Jupiter in 1869, "blue, crimson, and gold" (Wikipedia, Jupiter), pushed loud: a blue jacket, vermilion wheels and pilot, brass domes and bands, the brightly painted locomotive of the Russia-iron years (Wikipedia, Russia iron) coloured for the image the way Araki colours (`steel-ball-run.md`) and flat as board #03's railway poster in litho ink. Under this scene's sun, 45° behind the player and to the right, the walk and every end facing `PlayerSpawn` are lit and everything facing the engine is not, so the enemy stands on a silver strip with open sky behind his head, the field that shows daylight through the Sheriff's punched hat (`sheriff.md`), and the horizon splits as the Canyon does: hot vermilion faces on the left, bleached pink on the right, one violet band through both (rule 17; `canyon.md`).

**What this place feels like:** the company's 3:10 at full tilt, the desert reeled past it like a stage panorama, hot rock on your left and bleached rock on your right, and the deputy waiting on the next car with the engine's stack under his chin.

### Exceptions to the global rules

Rule numbers are Main Street's. Every rule not listed holds as written. PSX vertex snap and affine warp play no part: nothing here depends on them.

| Rule | Main Street | Train Rooftop | Why |
|---|---|---|---|
| 2, 3 | Human-contact sizes true; thin members fattened | The walk top stays at 3.20 under every marker and strafe line. Wheels (0.84 m), windows, railings (1.0 m), and steps stay true; eaves (0.30 m), stack, domes, bell, and headlight are fattened. The cars stay squat | The roof height is frozen |
| 6 | Smallest modeled feature 10 cm | 10 cm on the train, with rule 3's 8 cm for railings, grab irons, rods, and pins. 0.5 m on the horizon | The roof is seen from 0.5 to 10 m; the nearest span from 28 m, where 0.5 m is 1°, about 25 px |
| 7 | Boards 25 cm, modeled only where their ends or gaps make silhouette | The walk is one plane with toothed board ends at each car end | The walk's ends show at every gap |
| 12 | One feature per 1.5 to 2 m of street face | On the coach roofs, nothing rises above the walk within 0.35 m of a marker line (the bands in `train_car_coach`); each free band carries one low feature, at most 10 cm | Duelists stand and strafe across the whole roof width |
| 13, 15 | One wear accent per 4 m; a module gets one, off-centre | The coach and coupler modules get one each; the one-off cars and the engine get two or three. No accent on the walk inside a marker band | Kept company property |
| 17 | Sun faces saturated; shade faces pale | The train is one livery on both sides: its left side never takes sun and reads dark navy. Accepted, as the depot is painted all round (Main Street F4). The horizon follows the rule per face: faces the sun reaches are vermilion, faces it never reaches are pink | A train is not painted by side; a span is seen from one side at a time |
| 21 | Company blue belongs to the railroad | The train is the railroad: company blue on every car and on the engine | |
| 22 | The wall behind a spawn is one flat field | The field at head height is the sky from both spawns. Nothing on the engine rises above the stack's crown (4.40) within ±1.2 m of the lane's axis, and nothing on the cars ahead of `EnemySpawn` or behind `PlayerSpawn` stands more than 0.15 m above the walk within ±0.6 m of the axis | The standing enemy hides the engine; above it is open sky. The planned engine smoke (F13) will rise behind the enemy's head from `PlayerSpawn`, accepted for the smoke alone |
| 25 | Names prefixed with the asset | Objects take their module's prefix (`Coach_Car`). The scene keeps the greybox node names for the instances. `Guard*`, `Canyon`, `Mesa`, and `Butte` stay exact | Code reads those names |
| New | | The roof deck reaches x ±1.75 with no raised lip | The Sheriff's boot lands at ±1.71 (F5) |
| New | | Horizon: no two faces share a plane, no face lies at y 0.12 (the terrain's top), every span reads from both sides and closes at both ends | z-fighting; the belt shows both faces and both ends |

### Palette

Enter the linear value as the Blender Base Color. Hex is the sRGB display value; Y is linear luminance. Every value already exists in a sheet; one gets a new base name. Each GLB's own copy (`M_Car__train_car_coach`) holds the colour.

| Flat | Hex | Blender Base Color (linear) | Y | Base name | Used for |
|---|---|---|---|---|---|
| Company blue (Main Street's) | #2D5BC9 | 0.026, 0.105, 0.584 | 0.12 | `M_Car` | Car bodies, roof tin, fascias, ends, doors; the boiler jacket, cab walls, and tender |
| Bone (Main Street's) | #E8DDC4 | 0.807, 0.723, 0.552 | 0.73 | `M_Trim` | Letterboards, window and door frames, sills, hatch rims, the tender's rim |
| Ink (Main Street's) | #120D0A | 0.006, 0.004, 0.003 | 0.00 | `M_Glass` | Window panes, door lights |
| Raw wood (Main Street's) | #8F8C86 | 0.275, 0.262, 0.238 | 0.26 | `M_Plank` | Roof walks, platform floors and steps, the cordwood heap, the tender's walk |
| Iron (Main Street's) | #24272E | 0.018, 0.020, 0.027 | 0.02 | `M_Iron` | Trucks, wheels, axles, truss rods, sills, railings, brake staffs, vents, couplers, stack, smokebox, cab roof, frames, rods |
| Brass (the Saloon's) | #C9A23A | 0.584, 0.361, 0.042 | 0.39 | `M_Brass` | Domes, bell, boiler bands, whistle, headlight body, the business car's railing and lamps |
| Engine vermilion (the Canyon's vermilion under a new name) | #D9472B | 0.694, 0.063, 0.024 | 0.19 | `M_Red` | Drivers, pilot wheels, pilot, tender wheels |
| Lamp glass (the Saloon's; glows) | #FFF0C8 | 1.000, 0.871, 0.578 | 0.88 | `M_LampGlass` | The headlight's glass and the rear marker lenses |
| Vermilion (the Canyon's) | #D9472B | 0.694, 0.063, 0.024 | 0.19 | `M_Rock` | Span faces the sun reaches: +x and +z |
| Pink cliff (the Canyon's) | #F2A6A0 | 0.888, 0.381, 0.352 | 0.49 | `M_RockDark` | Span faces it never reaches: −x and −z |
| Band violet (the Canyon's) | #7E5BB5 | 0.209, 0.105, 0.462 | 0.15 | `M_CapDark` | The band on the mid spans |
| Bone (the Canyon's cap) | #E8DDC4 | 0.807, 0.723, 0.552 | 0.73 | `M_Cap` | Span caps and fallen cap blocks |
| Desert dirt (unchanged) | #B8A281 | 0.48, 0.36, 0.22 | 0.38 | `M_DirtFar` | `env_terrain`; tiling |

- Roughness 0.9 and metallic 0 everywhere (rule 23).
- Grain by name: `M_Car`, `M_Trim`, and `M_Plank` take 0.12; the four rock names 0.2; `M_Glass`, `M_Iron`, `M_Brass`, `M_Red`, and `M_LampGlass` none. `M_Red` is a new base name and needs no code: an unknown name is flat colour with no grain. It must not be `M_Rock`, which is a tiling name.
- `M_LampGlass` draws unlit, exactly its colour, and its meshes cast no shadow (Saloon G7, landed). No code.
- The underframe's wooden sills take iron's value: both flats are near black, and it saves one object per car.
- Retired: the greybox's red `M_Car` and `M_CarDark`, `M_Roof`, the brown `M_Wood`, `M_Window`, `M_Boiler`, `M_Lamp`, and the horizon's three tans.

### Backdrop check

How the numbers were made, more roughly than the Canyon's: the banded sun in each time's colour and energy, a flat ambient of 0.4 × (a fifth of the ambient colour plus four fifths of the sky gradient's hemisphere average), and the scene's fog at each distance. Contrast is (Y₁ + 0.05) / (Y₂ + 0.05); under 1.5, only hue separates the two. Roster colours as on the Saloon sheet; starred are the shipped `body_color` tints. The duelist stands 20 m away, his front lit as +z faces are. Each cell is the range over the four times. The flat run decides.

| Behind the duelist | Seen at dawn / noon / late afternoon / dusk | Bile yellow | Absinthe | Pale tin | Aquamarine | Bone | Red | Ox-blood | Gold | Black coat | Tan* | Blue-grey* | Near-white* | Ink |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| The walk, raw wood, 30 m (legs; proposed) | #9A634A / #A5A4A1 / #AB9370 / #9A5934 | 1.3–1.9 | 1.2–1.5 | 1.2–1.6 | 1.4–1.7 | 1.6–2.3 | 1.1–1.9 | 1.5–3.1 | 1.0–1.7 | 2.0–3.7 | 1.0–1.7 | 1.6–2.6 | 1.7–2.2 | 2.0–3.9 |
| The tin, company blue, 30 m (legs while strafing; proposed) | #6E5161 / #587BDE / #68709E / #704A46 | 2.1–2.9 | 1.9–2.5 | 1.9–2.6 | 2.2–2.9 | 2.6–3.6 | 1.2–1.6 | 1.1–1.9 | 1.7–2.3 | 1.4–2.3 | 1.0–1.4 | 1.1–1.6 | 2.7–3.6 | 1.4–2.4 |
| The tin, slate, 30 m (rejected) | #724838 / #5F6372 / #6E5B48 / #734226 | 3.0–4.0 | 2.3–3.4 | 2.5–3.5 | 2.5–3.9 | 3.5–4.9 | 1.3–1.8 | 1.0–1.3 | 2.6–3.2 | 1.3–1.5 | 1.5–1.7 | 1.0 | 3.3–4.8 | 1.3–1.6 |
| The cordwood heap's end grain, 55 m (chest, strafing) | #B47252 / #93979C / #B2976E / #B5693A | 1.5–1.7 | 1.1–1.4 | 1.2–1.5 | 1.2–1.7 | 1.7–2.1 | 1.2–1.6 | 2.0–2.6 | 1.2–1.3 | 2.6–3.4 | 1.4 | 2.1–2.3 | 1.6–2.1 | 2.6–3.6 |
| The iron stack, 64 m (chest) | #905D45 / #677383 / #836E4E / #93552E | 2.1–3.0 | 1.6–2.5 | 1.8–2.6 | 1.7–2.9 | 2.4–3.6 | 1.0–1.2 | 1.4–1.6 | 1.8–2.4 | 1.8–1.9 | 1.1–1.3 | 1.3–1.5 | 2.3–3.6 | 1.8–2.0 |
| Sky band (head and hat; the Canyon's numbers, same keyframes) | | 1.1–1.3 | 1.1–1.8 | 1.0–1.6 | 1.1–1.6 | 1.0–1.4 | 2.1–3.6 | 4.6–7.4 | 1.2–1.6 | 7.2–10.7 | 2.4–3.1 | 4.7–5.8 | 1.0–1.4 | 7.3–11.7 |

- **The rung's duelist reads.** The Sheriff's ox-blood legs stand on the silver walk at 1.5 to 3.1; his red jacket against the chest band is hue only, but the standing Sheriff hides the engine; his ox-blood hat stands against the sky at 4.6 to 7.4, with daylight through the punched heart.
- **Pale duelists in free duels** read against the sky and the walk by hue and the ink line only (1.0 to 1.9). The blue tin lifts them to 1.9 to 3.6 wherever they stand on it, which is why the tin is blue and only the walk is silver.
- **Slate swallows the dark roster**: the black coat 1.3 to 1.5, ox-blood 1.0 to 1.3, the ink line 1.3 to 1.6. Rejected for the roofs.
- **Seen from `EnemySpawn`** everything is backlit; the player's front faces the engine and takes ambient light only, and the receding roofs behind him are lit. The black coat and the ink line carry him, as on the Canyon.

## B. Asset sheets

The brief's two assets, split as it asks: the consist into an engine, three car types, and a coupler, each its own GLB (F1, F2); the horizon into its three spans.

| Asset | Greybox objects | Copies | Class | Triangles today | Budget each | Budget in scene | Objects after merging |
|---|---|---|---|---|---|---|---|
| `train_car_coach` (hero) | `CarRearA`, `CarA`, `CarB`, `CarFrontA` (48 meshes and 2 proxies each) | 4 | Module: the duel floor | 848 | 1,600 | 6,400 | 5 a copy |
| `train_car_baggage` | `CarFrontB` | 1 | One-off car | 848 | 1,300 | 1,300 | 5 |
| `train_car_business` | `CarRearB` (with the ladder) | 1 | One-off car: the rear | 916 | 1,800 | 1,800 | 7 |
| `train_engine` | `Engine` (58 meshes, 8 proxies) | 1 | Engine and tender | 1,472 | 3,500 | 3,500 | 8 |
| `train_coupler` | `Coupler0`–`4` (4 meshes each), `GapWalk0`–`4`, `GapWalkEngine` | 6 | Module | 56 | 100 | 600 | 1 a copy |
| `train_rooftop` | `GuardSideL`, `GuardSideR`, `GuardEndRear`, `GuardEndFront` | 1 | Collision only | 0 | 0 | 0 | 0 |
| `horizon_ridge` › `Canyon` | `Talus`, `Wall`, `Buttress`, `Cap` | 20 on the belt | Span, mid band | 48 | 300 | 6,000 | 4 |
| `horizon_ridge` › `Mesa` | `Talus.001`, `Lower`, `Upper` | 20 on the belt | Span, mid band | 36 | 240 | 4,800 | 4 |
| `horizon_ridge` › `Butte` | `Talus.002`, `TowerA`–`C`, `LipA`–`C` | 44 on the belt | Span, far band | 84 | 150 | 6,600 | 3 |
| Main Street's, unchanged | `env_rail_track_8m` ×90, cactus clones ×180, `env_terrain` | | Shared | 8,820 + about 9,400 + 12 | | about 18,200 | 270 + about 290 + 1 |
| **Scene** | | | | **About 30,500** (6,908 train, 5,376 horizon, about 18,200 shared) | | **About 49,200** (decided: about 49,600, F17) | **About 900**, from about 1,380 |

- **Module:** one GLB instanced more than once and painted once.
- **Today's counts** are measured from the GLBs, collision excluded, and include the band cuts. Cactus clones are rolled at random from 90 templates averaging 52 triangles and 1.6 meshes.

**Why the budget grows.** From about 30,500 to about 49,200 triangles in the scene, 1.6 times and inside the decided 49,600 (F17; the open gaps, F7, saved 360), and nearly all of it on what is seen near: the train goes from 6,908 to about 13,600 and the horizon from 5,376 to about 17,400, while Main Street's belt pieces stay at about 18,200. Half the belt is behind you or outside the view at any moment: from a spawn about 27,000 triangles are in the view at once (today about 16,600), close to Main Street's whole built scene (22,550) and the Canyon's (about 25,000), and under 2% of Meta's Quest 3 guideline of 1.5 million triangles per frame. The PSX look caps detail first: the 10 cm and 0.5 m floors and the per-asset ceilings keep it chunky, and the budget buys the roof kit and the closed span ends, not finer parts, since the polygons on screen at once are what set the budget (Andy Gavin).

Two limits are tighter than the triangle count:

- **Draw calls.** Merging per material (rule 26) takes the train from 371 objects to 46 and the horizon from 448 to 292. The belt's tracks and cacti stay at about 560, so the scene falls from about 1,380 objects to about 900 before culling, about 450 in the view from a spawn (today about 730). Meta's guideline is under 200. Going lower is code, decided after Quest timing (F18).
- **Shadows.** The default directional shadow distance (100 m) takes in every car, the engine, and the nearest spans, each drawn again into the cascades. Time it on a Quest at dawn, when the spans' shadows cross the train.

---

### `train_car_coach` (hero, module ×4)

| | |
|---|---|
| Role | The duel floor. `CarA` carries `PlayerSpawn` and `EnemySpawns3/C`; `CarB` carries `EnemySpawn` and the other four markers; `CarRearA` and `CarFrontA` are the roofs behind each duelist's legs from the other spawn. Its roof is under every duelist's feet, seen from 0.5 m straight down to 50 m at a graze. The death cam swings outside its upper sides near both spawns |
| Size | Greybox: body 12.0 × 2.9 × 1.86 m (y 1.15 to 3.01), roof 12.3 × 3.2 m (y 3.02 to 3.20), lips 12 cm tall at x ±1.48 to ±1.56, six windows a side 0.72 × 0.95 m (y 1.68 to 2.62), trucks at u ±3.7. Final: an enclosed body 10.4 m long between two open platforms 0.8 m deep; a roof deck 12.3 × 3.5 m (x ±1.75) with its tin at 3.16 and a walk 1.5 m wide (x ±0.75) to 3.20; eaves 0.30 m over the body sides |
| Squint | From the roof: a blue deck with a silver plank walk down its spine and a dark slot at each end. From the side: a long blue box under a dark eave, a bone letterboard over a row of ink windows, open ends with dark railings, on two dark trucks. Company blue, raw silver or bone, ink |
| Triangles | 848 today; 1,600 at most: body, windows, and ends 450; roof deck, walk, hatch, and vents 250; two platforms 400; trucks 350; underframe and truss 150 |
| Collision | `CarXBody` and `CarXRoof` keep their boxes, renamed `Coach_Body-convcolonly` and `Coach_Roof-convcolonly`. Listed under rule 5: the platforms are open space inside `Body`, so a bullet into a platform stops 0.8 m short of the end door; the deck and eaves reach ±1.75 against `Roof`'s ±1.52, with no floor under the outer 0.23 m (the guard walls keep walkers off it) |

**Marker bands.** One module serves both duel cars, so every marker on either is a line across this roof. Nothing may rise above the walk within these bands, and no wear accent may sit in them:

| | Keep clear (u) | Markers |
|---|---|---|
| Rear | −3.75 to −2.75 | `PlayerSpawn` (−3.4), `EnemySpawns2/B` (−3.1) |
| Middle | −1.95 to −1.25 | `EnemySpawns3/B` (−1.6) |
| Front | 2.75 to 4.75 | `EnemySpawns3/C` (3.1), `EnemySpawn` and `EnemySpawns2/A` (3.4), `EnemySpawns3/A` (4.4) |

The free bands are u −6.15 to −3.75, −2.75 to −1.95, −1.25 to 2.75, and 4.75 to 6.15.

Signature details, cut from the bottom:

1. **The roof deck.** One flat plane of blue tin at 3.16 across x ±1.75, and the walk on it: six boards' width (1.5 m) to 3.20, 4 cm proud so its edges take another light step, modeled as one plane whose ends at each car end are toothed by ±4 cm board by board. The walk's top is the whole deck you stand on.
2. **The roof edges.** No raised lip: the deck folds down into a blue fascia 15 cm deep at x ±1.75, and its 0.30 m eave throws an unlit band over the letterboard. The strafing Sheriff's boot (±1.71) stays on the deck (F5).
3. **Open platforms** at both ends (F6): a raw plank floor at the car floor (1.23), two steps a side down to 0.45 m, an iron railing 1.0 m high with a 0.7 m gate gap at its middle, and an iron brake staff in one corner with a 0.45 m wheel at about 2.3 m. The end wall behind carries a blue door 0.75 × 1.65 m in a bone frame with an ink light. The deck runs on over the platform and ends in a blue end fascia 0.20 m deep.
4. **Windows.** Eight a side at a 1.2 m pitch, 0.72 × 0.95 m as today, inset 12 cm, ink panes, 10 cm bone frames, 12 cm sills, under a bone letterboard 0.25 m tall that stands 3 cm proud just below the eave.
5. **Trucks.** Two four-wheel trucks with chunky iron side frames, axle boxes, and equalizer bars; wheels where they are today.
6. **Truss rods.** Two iron rods, 8 cm, down from the bolsters at u ±3.7 to queen posts at u ±1.2 hanging 0.4 m under the sills, with a turnbuckle block at u 0: the V under the car seen from the side.
7. **The roof hatch** the deputies come up through: a bone-rimmed cover 0.7 × 0.9 m, 8 cm proud, beside the walk on the right-hand strip at u 0.5 (free band), with a hinge and a handle. No lore mark (F14).
8. **Four mushroom vents**, 0.25 m across and 10 cm tall, near the deck edges at u −5.0, −2.35, 0.8, and 5.4, alternating sides.
9. **Wear, one accent (rule 15):** one walk board at u −5.0 sprung, its end lifted 6 cm. On `CarB` that puts it mid-lane at z −1.6; from `PlayerSpawn` it lies at −8°, well under the enemy's feet (−4.9°).
10. **Grab irons** at the platform corners, 8 cm, and the greybox's ladder idea as rungs on the end wall beside the door.

- **Wear in geometry:** the sprung board. The truss rods carry the sag story; the deck never leaves 3.20.
- **Base Color:** `M_Car` Company blue (body, deck tin, fascias, end walls, doors). `M_Trim` Bone (letterboard, frames, sills, hatch rim). `M_Glass` Ink (panes, door lights). `M_Plank` Raw wood (walk, platform floors, steps). `M_Iron` Iron (trucks, wheels, axles, truss rods, sills, railings, brake staffs, vents, grab irons). Five objects.
- **UV:** the walk's top is one island, toothed outline and all; keep it one n-gon (the Saloon's build lesson: no three collinear outline points). Delete the tin under the walk, which leaves the tin as two strips, one island each. Each side wall stays one island between its window holes; left and right are separate islands (the unwrap never mirrors), so paint both. Wheels, vents, and railing bars are too small to paint: flat colour.
- **Draws on:** board #03 (a railway's own poster in flat litho colour), #18 (one colour block behind an ink figure: the blue deck behind the duelists' legs), #20 (railings and truss rods as the line work), #12 (chunky eaves); the running board (Wikipedia); open platforms, the norm until the first vestibuled train on 15 June 1887 (Wikipedia, Vestibuled train); truss rods, queen posts, and turnbuckles against sag (Trains.com forum); company blue (Main Street rule 21).

### `train_car_baggage`

| | |
|---|---|
| Role | `CarFrontB`, z −39.0 to −27.0, the car behind the tender. From `PlayerSpawn` its roof is the last before the engine, behind the enemy's thighs and hips (−2.6° to −2.0°). Walkable; nobody spawns on it |
| Size | The coach's body, deck, and trucks |
| Squint | From the lane: the last blue deck, its silver walk running into the tender. From the side: a long blind blue box with one big door and two small high windows. Company blue, bone, ink |
| Triangles | 848 today; 1,300 at most |
| Collision | `CarFrontBBody` and `CarFrontBRoof` unchanged, renamed `Baggage_Body-convcolonly` and `Baggage_Roof-convcolonly`. Same rule 5 listings as the coach |

Signature details, cut from the bottom:

1. The coach's deck and walk, with two express hatches 0.80 × 1.0 m (across by along: the strip between the walk and the deck's edge is 1.0 m), 6 cm proud with bone rims, one each side of the walk.
2. A sliding door each side, 1.8 × 1.6 m, blue with bone Z-bracing, on an iron top track; the shut door shows its edge 4 cm proud.
3. A blind front end toward the tender: no door, no gate, the railing closed.
4. Two small high windows a side, 0.5 × 0.4 m, ink in bone frames.
5. One smoke jack: an iron pipe 0.7 m tall with a cap, at x +1.25, u −4.0. From `PlayerSpawn` it stands 1.8° right of the lane, beside the standing enemy's hip.
6. Wear: one express hatch ajar 4 cm; the smoke jack leaning 3°.

- **Wear in geometry:** the ajar hatch and the leaning jack.
- **Base Color:** as the coach. Five objects.
- **UV:** each door is one island. The blind sides are big plain islands.
- **Draws on:** board #18 (a blind colour block); the coach's kit.

### `train_car_business`

| | |
|---|---|
| Role | `CarRearB`, z 27.0 to 39.0: the end of the train and the company agent's car (`sheriff.md`: on the train the company's agent outranks the Sheriff). From `EnemySpawn` its roof is behind the player's thighs and hips (−2.6° to −2.0°), and its rear edge is the line at his hips. `GuardEndRear` stands just past it. The deck runs on over the observation platform, so from the roof it shows only to a player leaning out over `GuardEndRear`; it is seen from behind the train |
| Size | The coach's body and trucks; the rear platform deepened to 1.2 m inside the body proxy; six wider windows a side, 1.0 × 0.95 m |
| Squint | From the lane: a blue deck with two smoke jacks at its corners. From the rear: a gold railing round an open platform under the deck's end, two lamps at its corners. Company blue, brass, ink |
| Triangles | 916 today; 1,800 at most |
| Collision | `CarRearBBody` and `CarRearBRoof` unchanged, renamed `Business_Body-convcolonly` and `Business_Roof-convcolonly`. Listed under rule 5: the rear platform is 1.2 m of open space inside `Body` |

Signature details, cut from the bottom:

1. **The observation platform.** 1.2 m deep, with a three-sided brass railing 1.0 m high (top rail 8 cm, balusters 8 cm at 0.25 m centres), and the rear door in a bone frame.
2. **Marker lamps** on the rear corners: brass bodies with `M_LampGlass` lenses, which glow (no code).
3. **Two smoke jacks**, iron, 0.7 m tall, at x ±1.25, u 4.0: from `EnemySpawn` 1.6° to 1.9° either side of the standing player.
4. Six wide windows a side in bone frames, with bone pilasters between them: the richer car.
5. The coach's deck, walk, hatch, and vents.
6. Wear: the brass railing's top rail dented 4 cm at one corner; one marker lamp turned 10°.

- **Wear in geometry:** the dent and the turned lamp.
- **Base Color:** as the coach, plus `M_Brass` Brass (railing, lamp bodies) and `M_LampGlass` (lenses). Seven objects.
- **UV:** the railing's balusters take flat colour. The rear door is one island.
- **Draws on:** board #06 and #01 (ornament on the object that matters: the company's own car), #10 (black trimmed in crystal: a dark shape opened to show ornament); the Sheriff's page.

### `train_engine`

| | |
|---|---|
| Role | The front of the train and the far end of the lane. From `PlayerSpawn` its top sits behind the enemy's hips and chest (−2.0° to −0.45°), 26 to 32% fogged; the standing enemy hides most of it, the strafing one uncovers it. Its tender deck and cab roof are walkable, and from the cab roof the boiler top is 1 to 7 m away |
| Size | Greybox: tender 6.8 × 2.8 m (body y 1.15 to 2.87, deck 3.02 to 3.20), coal heap 1.4 × 2.5 × 0.76 m on the deck's front half, cab 2.07 × 2.55 m (y 1.08 to 3.08, roof to 3.20), boiler 1.56 m across from z −49.40 to −54.90, smokebox to −55.15, stack crown at 4.40, drivers 1.4 m, pilot to −56.83. Final: as the greybox, with the tender's sides raised to the deck, a 4-4-0 with drivers 1.52 m across (F10), a diamond stack (F11) |
| Squint | From the lane: a black stack and a silver wood heap just above the last roof line, two gold domes between them. From the side: a blue barrel on red wheels under a black funnel and a gold headlight, a blue cab, a blue tender heaped with grey wood. Company blue, vermilion, iron, with gold accents |
| Triangles | 1,472 today; 3,500 at most: boiler, smokebox, bands, and stack 450; domes, bell, whistle, and headlight 400; cab 400; tender and wood heap 900; drivers, rods, and cylinders 650; pilot and pilot truck 350; frame, running boards, and handrails 350 |
| Collision | The eight proxies keep their boxes, renamed `Engine_TenderBody`, `Engine_TenderRoof`, `Engine_Fuel` (was `EngineCoal`; the wood heap fills it), `Engine_CabBody`, `Engine_CabRoof`, `Engine_GapWalk`, `Engine_Boiler`, `Engine_Pilot`, each with `-convcolonly`. Listed under rule 5: the tender's sides rise 0.15 m above `Engine_TenderBody` to close the slot; the stack, domes, bell, and headlight stand above `Engine_Boiler` with no proxy, as today; the larger drivers stand outside every proxy |

Signature details, cut from the bottom:

1. **The diamond stack** (F11): an 8-sided base 0.5 m across rising from the smokebox to a double cone 1.2 m across, its crown at 4.40 and no higher, iron. The train's skyline, behind the enemy's chin from `PlayerSpawn`.
2. **Domes and bell.** A steam dome and a sand dome, 8-sided and 0.75 m across, in brass, the bell in a brass yoke between them, a whistle on the steam dome; every top under 3.6 m.
3. **The cordwood heap** in `Engine_Fuel`: 6-sided logs 0.2 m across, stacked with their cut ends toward the cars, the end grain the face seen from the lane. Raw silver.
4. **The headlight**: a box headlight 0.8 m tall (oversized) on a bracket at the smokebox's top front, brass, its glass in `M_LampGlass`, which glows. Its back is what the cab roof sees.
5. **The cab**: blue walls, arched window heads in bone frames over ink panes, an iron roof with 0.25 m eaves, walkable at 3.20.
6. **The boiler**: a company-blue jacket with three brass bands 12 cm wide and 5 cm proud, an iron smokebox with a round door, running boards with iron handrails.
7. **Running gear** (F10): two pairs of vermilion drivers, 12-sided, with counterweights; side rods and main rods; cylinders beside the smokebox.
8. **The pilot**: a vermilion cowcatcher of eight 10 cm slats in a V on an iron beam, and a four-wheel pilot truck with vermilion wheels 0.8 m across.
9. **The tender**: blue sides raised to the deck (Found 2) under a bone rim, a plank walk on the deck's rear half, two trucks with vermilion wheels.
10. Wear: the stack leans 2° back; a 10 cm flat on the sand dome; one cab window frame racked 2°.

The planned engine smoke (F13, Roadmap) leaves the stack's crown at (0, 4.40, −54.25); keep the crown's centre there.

- **Wear in geometry:** the leaning stack, the flat, the racked frame.
- **Base Color:** `M_Car` Company blue (jacket, cab walls, tender sides). `M_Iron` Iron (stack, smokebox, frame, cab roof, rods, handrails, cylinders). `M_Brass` Brass (domes, bell, bands, whistle, headlight). `M_Red` Engine vermilion (drivers, pilot, pilot and tender wheels). `M_Trim` Bone (window frames, tender rim). `M_Glass` Ink (cab panes). `M_Plank` Raw wood (wood heap, tender walk). `M_LampGlass` (headlight glass). Eight objects.
- **UV:** keep the boiler, smokebox, and stack plain prisms between round caps so each side unrolls as one rectangle (the unwrap's cylinder path); the diamond stack's cones are several. The logs are too small to paint: flat colour.
- **Draws on:** board #06 (the presentation piece), #01 (chased metal: the bands and domes), #30 (the company drawn as landscape, standing at the far end of the lane); the Jupiter, a wood-burning 4-4-0 with 5 ft 4 in drivers, "blue, crimson, and gold" in 1869 (Wikipedia, Jupiter); the 4-4-0 as about 85% of American locomotives in the early 1870s (Wikipedia, 4-4-0); box headlights with reflectors, common by 1850 (Wikipedia, Train lights); Russia iron's jackets on "brightly painted locomotives" (Wikipedia, Russia iron).

### `train_coupler` (module ×6)

| | |
|---|---|
| Role | Joins the cars, and, new, the last car to the tender (Found 3): six gaps, `Coupler2` at mid-lane between the duelists. The gaps stay open (F7): you cross each one on the invisible gap walk, over the coupler and the track rushing below |
| Size | Greybox: two drawheads 0.42 × 0.22 × 0.32 m, a drawbar, a pin, 56 triangles. Final: as below, plus the gap walk proxy moved in from `train_rooftop.glb` |
| Squint | From the roof: a dark slot with an iron knot at its bottom, between two platforms. Iron |
| Triangles | 56 today; 100 at most |
| Collision | Each gap walk (2.9 × 1.8 × 0.2 m, top at 3.2) moves into the module as `Coupler_GapWalk-convcolonly`, same box, one per instance. `GapWalkEngine` becomes the sixth instance's |

Signature details, cut from the bottom:

1. **Link and pin:** two iron drawheads 0.30 m square on short drawbars, an oval link between them fattened to an 8 cm bar, and two pins standing 0.25 m with ring tops: the knot you see between your boots at every gap.
2. A safety chain each side, as three 10 cm links drooping between the cars' end sills.
3. Wear: one pin standing 10° crooked in its drawhead.

- **Wear in geometry:** the crooked pin.
- **Base Color:** `M_Iron` Iron. One object.
- **UV:** small islands, flat colour; the module is painted once for six gaps.
- **Draws on:** link-and-pin couplers, under which "many brakemen lost fingers or entire hands", replaced after Janney's 1873 knuckle and the Safety Appliance Act of 1893 (Wikipedia, Link-and-pin coupler); board #20 (line work).

### `train_rooftop` (collision only)

| | |
|---|---|
| Role | Keeps the four guard walls, so the scene's `Train` node, its `.import`, and every test that finds `Guard*` stay as they are |
| Work | Delete every visual and every proxy except `GuardSideL`, `GuardSideR`, `GuardEndRear`, and `GuardEndFront`, unchanged (F2) |

### `horizon_ridge`: rules for all three spans

The Canyon's rock vocabulary at the belt's own size floor, so the train's desert and the Canyon's read as one country (E).

- **Pieces.** Ledge slabs, fluted slabs, cap slabs, chamfered blocks, wedges, pillars, and fallen blocks, as the Canyon defines them, at a 0.5 m floor: chamfers 0.5 m or more, flutes 1.0 to 1.5 m apart (at 7 m/s one passes in 10 to 15 frames at 72 Hz, so it does not strobe). Big planes, one planar n-gon per flat region, edges hard, vertices on a 0.25 m grid. No per-vertex noise, subdivision, or slivering booleans.
- **Bands** over the span's foot, as on the Canyon's walls: apron of 35° wedges to 2.0 to 2.5 m (so the toe stands about 3.4 m out from the body, wherever that puts it: see `Canyon`'s Size); lower body; one violet slab from 7.0 to 8.25 m standing 0.3 m or more proud or set back (never flush); upper body; a bone cap 1.25 to 2.0 m tall overhanging 0.5 to 0.8 m, broken into blocks with sky between them.
- **Colour by side first** (rule 17 by this sun, as built in H). Bone and violet stay. A rock face whose plan normal leans to Blender +X (x 0.3 or more) is vermilion, and one leaning to −X is pink, whatever its turn toward the ends. A face along the span is vermilion toward −Y (Godot +z, the end the sun reaches) and pink toward +Y. A ledge top takes its side's colour (the low ledge ring is split at x 0); a top above the eye takes the colour of its centre. Why side first, not "every face the sun reaches is vermilion": the pink face's teeth turn toward Godot +z, so they do take sun, but they must stay pink, so the shade side reads pink with lit teeth. So the left-hand side sees vermilion walls and the right-hand side pink ones, as the Canyon's player sees them.
- **Turned planes.** On the vermilion face, main planes turned 15 to 45° toward +z take the full step at dawn, late afternoon, and dusk. On the pink face, a sawtooth of planes turned 51 to 60° toward +z takes the middle step at every hour (at 50° the noon N·L is 0.0298, under the band's start at 0.03; the spans' teeth are built at 56.3°, N·L 0.067), and those planes face you as a span comes toward you: lit teeth on the shade side.
- **Both sides finished.** Every part has a counterpart on the other face, placed differently. Nothing is one-sided.
- **Closed ends** (F15): within the last 6 to 8 m at each end the span steps down to its apron in two or three steps, so any neighbour at any offset reads as a separate formation with a saddle between. Keep the 47.75 m length and the 0.125 m clearance at each end.
- **No coplanar faces.** Build each span as one exact self-union per material, as the Canyon's cliffs were built, then dissolve coplanar faces. Pieces of different materials step at least 0.3 m. Span bases sit at y 0, 12 cm under the terrain's top; no face lies at 0.12.
- **Objects and names.** One object per material per span: `Canyon_Rock`, `Canyon_RockDark`, `Canyon_CapDark`, `Canyon_Cap`, and so on, under roots named exactly `Canyon`, `Mesa`, `Butte`. No dots. No collision.
- **UV:** 8 m tiling UVs on every object, written by `scenery_uv.unwrap_object(obj, scenery_uv.TILING)`; each object at zero rotation with its origin at the span's origin, so the tiles run level across pieces (Canyon G2, G3). Nothing to paint in the per-GLB image.

### `Canyon` (span, ×20 on the belt)

| | |
|---|---|
| Role | The mid band's even slots, x ±28 to ±40 at 7 m/s: the tallest and nearest walls, 15 to 21% fogged at their nearest. Its right-hand copies throw the passing shadows at dawn and dusk |
| Size | Greybox: talus 18 × 47.75 × 2.0 m, wall 8 × 47.70 m to 17.7, buttress 1.8 × 4.5 m to 10.4 on the +x face, cap 6 × 12 m to 19.7. Final: a ridge 8 to 10 m thick on a talus skirt, skyline tops 14 to 19.7 m in segments about 6 m long. As built (H): the 35° apron meets the 9.25 m ridge's faces at 2.36 m, so its toe stands at x 7.875 and −8.125, not ±9 (a toe at ±9 would meet them at about 3.1 m); the free pillars and fallen blocks reach out to x ±9 |
| Squint | From the left: a long vermilion wall with a violet stripe and a broken bone top. From the right: the same wall in pink with lit teeth. Vermilion or pink, violet, bone |
| Triangles | 48 today; 300 at most |

Signature details, cut from the bottom:

1. The bands on both faces, the violet slab running the full length except where the ends step down.
2. The bone cap in blocks, neighbouring tops differing by at least 0.6 m.
3. The closed ends: two or three steps down to the apron.
4. Turned planes on the vermilion face, the lit sawtooth on the pink face.
5. Two pillars per face (the greybox buttress, made two-sided), at different positions on each.
6. Flutes on the upper body, 1.0 to 1.5 m apart.
7. Wear: one fallen cap block on the apron each side; one chipped cap corner.

- **Base Color:** `M_Rock` Vermilion, `M_RockDark` Pink, `M_CapDark` Violet, `M_Cap` Bone. Four objects.
- **Draws on:** board #07 (a striped cliff), #12 (Monument Valley red); the Canyon's vocabulary; the Trans-Siberian panorama's middle screens.

### `Mesa` (span, ×20 on the belt)

| | |
|---|---|
| Role | The mid band's odd slots, alternating with `Canyon`: the lower, wider table between the walls |
| Size | Greybox: talus 20 × 47.75 × 2.0 m, lower 12 × 47.70 m to 11.5, upper 8 × 26 m from 11.1 to 16.1. Final: two tiers, the upper set back 2 m or more on both faces, tops 10 to 16 m |
| Squint | A stepped table: a wide lower tier, a narrower upper one, a bone rim on each. Vermilion or pink, violet, bone |
| Triangles | 36 today; 240 at most |

Signature details, cut from the bottom:

1. Two tiers, each under its own bone cap: two skyline lines.
2. The violet band on the lower tier.
3. Closed ends stepping down through both tiers.
4. The sawtooth and turned planes on the lower tier's faces.
5. Wear: a fallen block on one skirt; a notch out of the upper tier's rim.

- **Base Color:** as `Canyon`. Four objects.
- **Draws on:** the Canyon's horizon mesas; Maynard Dixon's simplified rock (via `canyon.md`).

### `Butte` (span, ×44 on the belt)

| | |
|---|---|
| Role | The far band, x ±70 to ±100 at 2.4 m/s, 34 to 45% fogged at its nearest and fading beyond: the slow back layer, the panorama's 16-feet-a-minute screen |
| Size | Greybox: talus 18 × 47.75 × 2.2 m and three towers 4.2 to 6 m thick, 20, 30, and 38 m tall, each under a lip. Final: three pillars, each two or three chamfered blocks stepping in 0.5 to 1 m under an overhanging bone cap block, heights about 20, 31, and 39 m, on a skirt of wedges |
| Squint | Three tall red posts with pale caps on a low skirt, in a row that repeats. Vermilion or pink, bone |
| Triangles | 84 today; 150 at most |

Signature details, cut from the bottom:

1. Three pillars of distinct heights and widths, their caps overhanging.
2. The skirt of wedges round their feet.
3. Spacing that is uneven inside the span (the period is 48 m whatever happens inside it).
4. Wear: one pillar's top block leaning 3°.

- **Base Color:** `M_Rock` Vermilion, `M_RockDark` Pink, `M_Cap` Bone; no band, as the Canyon's flank mesas have none. Three objects.
- **Draws on:** board #14 (an empty plain under the sky), #22 (desert at blue hour); Spyro's flat-shaded far versions (Hardcore Gaming 101).

## C. Build order

**Hero: `train_car_coach`.**

- Both duelists stand on it, its roof is the floor of every duel view, and its receding copies are the field behind each duelist's legs.
- Its kit is the one the others copy: the deck and walk, the fascia and eaves, the open platform, the windows and letterboard, the trucks and truss rods. The baggage and business cars are variations, and the tender takes its deck.
- It tests the rules new here: the frozen walk top, the marker bands, the boot at ±1.71, the death cam at the car's side.
- It is a module ×4, so its count and its unwrap matter four times, and its review covers the coupler and the open mid-lane gap between the two duel cars.

**Order** (×N marks a modular repeat):

1. Scene edit first, for the split (F2): new roots in `train_rooftop.blend`, a `.glb.import` for each copied from `train_rooftop.glb.import`, the instances in `train_rooftop.tscn` under the greybox node names, the visuals deleted from `train_rooftop.glb`. Run `load`, `multi`, and `ragdoll`.
2. `train_car_coach` (×4), the hero, with `train_coupler` (×6) between the duel cars for the review.
3. `train_engine`: the far end of the lane and the second reviewed asset.
4. `train_car_business` and `train_car_baggage`: the hero's kit.
5. `train_coupler` at all six gaps, the car-to-tender one new.
6. `horizon_ridge`: `Canyon` (×20) first, which sets the span vocabulary, then `Mesa` (×20), then `Butte` (×44).

## D. Review checklist

### Views

| View | Where | Camera | For |
|---|---|---|---|
| Lane P | Godot, Train Rooftop, shaders on | Eye at (0, 4.9, 10), looking at (0, 4.9, −10), the flat camera's field of view | The coach roofs, the gaps, the baggage roof, the engine's top, both horizon bands |
| Lane E | Godot | Eye at (0, 4.9, −10), looking at (0, 4.9, 10) | The coach roofs, the business car, the rear edge, the backlit side |
| Strafe | Godot | From Lane P's eye, aimed at (±1.5, 4.9, −10) | The deck under the boot at each end of the swing; what stands behind the legs there |
| Down | Godot | Eye at (0, 4.9, 10) pitched 60° down; eye at (0, 4.9, 1.2) pitched 75° down over the mid-lane gap | The deck, walk, hatch, vents; the open gap, its platforms, the coupler, the track below |
| Edge | Godot | Eye at (±2.1, 4.6, 7), leaning out past the eave, looking at (±1.45, 1.8, 7); and from the ground beside the car, eye at (±4.5, 2.2, 7), looking at (0, 2.2, 7) | The fascia, eave, letterboard, windows, trucks, and truss on both sides |
| Death cam | Godot | Eye at (±3.08, 4.28, −10), looking at (0, 3.4, −10) | The duel car's deck edge and fascia at the orbit's range (the eave hides the windows) |
| Cab | Godot | Eye at (0, 4.9, −48.7), looking at (0, 3.0, −55) | Boiler top, domes, bell, stack, headlight's back, pilot |
| Rear | Godot | From behind the train: eye at (0, 3.0, 46), looking at (0, 2.0, 38). From the roof the deck hides the platform | The observation platform, railing, lamps |
| Pass | Godot | From Lane P's eye, aimed at (±35, 8, −40) | Spans arriving on both sides, their ends, the far band's repeat |
| Top | Blender, the asset's `.blend` | Straight down from 1.7 m over the walk's centre | Every car (the roof as the player sees it) |
| Side | Blender | From +x and −x, 2.0 m up, aimed at the asset's centre: a car 22 m out with a 50 mm lens, the engine 26 m out with 50 mm or 15 m with 24 mm (50 mm at 10 m frames neither a 12.3 m car nor the 16.6 m engine); spans from x ±34 (mid) or ±85 (far), 4.9 m up, at 35 or 24 mm | Every asset (its duel-lane view in Blender) |
| Three-quarter | Blender | 45° between +x and −z (the front), 15 m out, 4.9 m up, 35 mm lens (50 mm does not frame a car at 15 m) | Every asset |
| Silhouette | Blender: Workbench, flat lighting, one black colour, white world | Side, end-on, and the Top view; spans from both faces | Every asset |
| Squint | The Side render | Shrunk to 64 px wide, enlarged back with nearest filtering | Every asset |

- Render each Godot view at dawn, noon, late afternoon, and dusk with F3 `time_of_day`. A temporary `Camera3D` does the job; do not save it into the scene.
- The belt runs on wall-clock time, so one capture is one moment: take three, 2 s apart.
- Finish in a headset: walk the roofs from the rear wall to the cab, crossing every gap; lean over both sides; stand on the cab roof.

### Pass or fail, every asset

1. **Silhouette:** can you name the asset from its black outline alone?
2. **Squint:** does the 64 px render show one shape and at most three flats?
3. **Size floor:** is every modeled feature at least 10 cm on the train (8 cm for railings, rods, pins) and 0.5 m on the spans?
4. **Wear:** one accent per module copy, two or three per one-off, in silhouette, none in any colour, none in a marker band?
5. **Budget:** triangles within the budget, and objects equal to materials?
6. **Names:** unique, no dots, prefixed with the asset; `Guard*`, `Canyon`, `Mesa`, `Butte` exact; proxies suffixed `-convcolonly`?
7. **UVs:** did `dev/unwrap_per_glb_blender.py -- --relayout --glb <name>` print no TINY share on a face you mean to paint? Does Blender's UV Select Overlap find nothing? Is each walk top one island? Do the spans carry 8 m tiling UVs only?
8. **Collision:** unchanged, or the listed change, with `load`, `multi`, and `ragdoll` passing after export and reimport?
9. **No shared planes:** do overlapping pieces avoid every coplanar face, and does nothing lie at y 0.12? Is there no flicker in a flat run?

### Pass or fail, in context

10. Lane P: is the stack's crown (4.40) the highest thing within ±1.2 m of the axis, with clear sky behind the enemy's head and hat?
11. Strafe: does the Sheriff's boot stay on the deck at both ends, and does nothing on the roof pass through his legs?
12. Do the duelists, in the shipped tints and in swatches of the designed colours, separate from the walk, the tin, and the sky at squint?
13. Do the gaps across the lane read as clean dark joints, with the walk's toothed ends on both sides?
14. At dawn and dusk: do the passing shadows read the way F16 decided?
15. Pass: does any span pop, show a seam where it meets a neighbour, or show a cut end? Does the far band's repeat show?
16. Edge: do the car side, letterboard, and windows read at 1.5 m without shimmer when you move your head? Death cam: does the deck edge read as a clean blue line?
17. In a headset: does crossing an open gap on the invisible walk read as a stride over a joint rather than a fall? Does the walk feel 3.2 m off the ground when you lean out?

### Asset checks

| Asset | Check |
|---|---|
| `train_car_coach` | Is the walk at 3.20 under all seven markers? Does the sprung board sit in a free band on both duel cars? From the Edge views, do the sides read blue, bone, and ink, not black? |
| `train_car_baggage` | From Lane P, does the smoke jack stay beside the enemy, not behind him? |
| `train_car_business` | From Lane E, do the smoke jacks stay beside the player? Do the marker lenses glow and cast no shadow? |
| `train_engine` | Is the tender's slot closed? Does the headlight glow? Does the stack's crown stay at 4.40? |
| `train_coupler` | Is the gap walk the same box, one per gap, six in all? Does the coupler read from the roof at every gap, the car-to-tender one included? |
| Spans | Does each read from both faces? Do the ends close? Do the left and right bands read vermilion and pink at every time? |

### Tests

Run `--import`, then `--autotest=load` (the world shader on every surface of every new GLB, the belt's pieces and no sway, the horizon contract), `--autotest=multi` (each marker on the roof and clear, the guard walls in the ragdoll ignore group, the Sheriff's strafe), `--autotest=ragdoll` (spawn floors at 3.20), and `--autotest=gauntlet` (rung 4 loads the train):

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=multi
```

`load` does not see the belt's cloned spans or cactus copies: they are `duplicate()`s, which its scenario-GLB check (`_in_scenario_glb`) skips. It covers the belt only by the count of at least 80 pieces, which the tracks alone pass, and by the template GLBs' own surfaces. So count the belt in a flat run: 90 tracks, 180 cacti, 84 spans, 354 children under `Scenery`, every span copy on the world shader and none swaying. Headless runs do not compile shaders. The look needs a flat run, then a headset.

## E. Cross-scene dependencies

`main_street.md` and `canyon.md` both exist. This sheet inherits Main Street's global rules 1 to 28, its palette, its backdrop method, and its build lessons, and the Canyon's rock vocabulary for the horizon. The exceptions are in A.

- **Main Street's belt pieces, unchanged.** This sheet changes none of them.
  - `env_rail_track_8m`: 98 triangles in 3 objects; 8.0 m long, rail tops at +0.21, rail centres at ±0.70, origin at its centre. The train's wheels sit on it, so the trucks' wheel positions are frozen with it.
  - `env_desert_scatter`: the belt clones its cactus plants by their part names (`Trunk`, `Arm`, `Tip`, `Body`, `Col`, `Pad`) and skips any plant with `Blade`, `Clump`, or `Stick`. Cacti stay rigid.
  - `env_terrain`: the ground, top at +0.12, `M_DirtFar`. No span face may lie at 0.12.
- **Main Street's rules on the train.** The train is the railroad, so it takes rule 21's company blue, the depot's colour, with the same bone, ink, raw wood, and iron values: one company across the town and the train. Boards 25 cm, no bevels on wood, rule 9's round parts, the 10 cm floor, and closed volumes painted all round (Main Street F4 for the depot).
- **The Canyon's rules on `horizon_ridge`.** The spans share:
  - the four rock values under the four names (`M_Rock` vermilion, `M_RockDark` pink, `M_CapDark` violet, `M_Cap` bone), replacing the greybox tans;
  - the band order and the band's height over each span's foot (7.0 to 8.25 m);
  - the vocabulary's large pieces at a 0.5 m floor, flutes 1.0 to 1.5 m apart, chamfers 0.5 m or more;
  - rule 17 by this scene's sun: the faces it never reaches take the pink, so the right-hand side shows pink and the left vermilion, the Canyon's "hot rock on your left, bleached rock on your right";
  - the Canyon's way of building: one self-union per material, coplanar faces dissolved, tiling UVs from `scenery_uv.unwrap_object`, objects at zero rotation.
  - The ends are the difference: the belt never tiles them, so they close (F15). The 48 m pitch, the 47.75 m length, and no collision stay.
- **The Saloon's values.** Brass and lamp glass, with the glow code that landed for the chandelier. The Saloon keeps no company blue; the train is the only other scene that does.
- **The desert is one.** The terrain under the train is Main Street's desert dirt, which is also the Canyon's plain.

**Build lessons, applied here:**

- Set colours on the per-GLB material copies, or delete stale ones (`unwrap_per_glb_blender.py` reuses a `<base>__<glb>` copy by name and never copies a new colour onto it). Reset any leftover metallic and specular on the greybox's copies.
- Use headless Blender, or close the live session first: the unwrap script saves the `.blend`.
- Run the per-GLB unwrap with `--relayout` while nothing is painted.
- Check the sheet's numbers against each other before modeling. This sheet already moved the roof edge out of the boot, kept every roof feature off the marker bands, and kept the engine under 4.40.
- Name proxies without dots.
- Never re-run `dev/build_train_rooftop_blender.py` once the first final lands (G7).
- From the Saloon: avoid three collinear points on a face's outline, which leave zero-area triangles; count UV islands in the `.blend`, not in the GLB.
- From the Canyon: tiling UVs follow each object's own axes, so keep rock objects at zero rotation.

## F. Decisions

Answered on 2026-10-23 in five rounds, plus two rounds on the engine smoke. Every answer took the recommendation except three: the coupler gaps stay open (F7), no lore mark (F14), and the smoke went to the Roadmap as a numbered item rather than into this build, with its root accepted behind the enemy's head (F13). The last column says what each decision changes on this page or in the scene.

| # | Question | Decision | What it changes |
|---|---|---|---|
| 1 | Car variants | A coach ×4, a baggage car behind the tender, a business car at the rear | Three car GLBs; the coach is the hero module |
| 2 | One GLB or several | One per asset; `train_rooftop.glb` keeps only the four guard walls | Five new GLBs with copied `.import` files and instances in `train_rooftop.tscn`; the gap walks move into the coupler (G1) |
| 3 | Roof profile | A flat deck at 3.20 across the width | No clerestory; the walk proxies and the strafe stay |
| 4 | Roof colours | Company-blue tin with a raw-silver plank walk | The backdrop check's two proposed rows stand |
| 5 | The Sheriff's boot at the roof edge | Widen the deck to x ±1.75, no raised lip | A flush blue fascia and 0.30 m eaves; listed under rule 5 |
| 6 | Car ends | Open platforms 0.8 m deep inside the body proxy | Railings, steps, brake wheels, end doors; listed under rule 5 |
| 7 | The coupler gap | Open, as today | No bridge: you cross on the invisible gap walk over the coupler. The coupler drops to one object and 100 triangles |
| 8 | Windows | Ink panes, inset | |
| 9 | Wear | Kept: one accent per module copy, two or three per one-off | Rules 13 and 15 at module rates |
| 10 | Wheel arrangement | A 4-4-0 | Two pairs of drivers 1.52 m across |
| 11 | Fuel and stack | A wood-burner: diamond stack, cordwood heap | The stack's crown stays at 4.40; the heap fills `Engine_Fuel` |
| 12 | Engine livery | Blue, vermilion, and gold after the Jupiter | `M_Red` (the Canyon's vermilion under a new name) on wheels and pilot |
| 13 | Engine smoke | None in this build; a Roadmap item (section 2) | Its spec: silver-grey dithered puffs from the stack's crown, full size from the root (accepted behind the enemy's head from `PlayerSpawn`), bending off the left side within about 20 m; same in flat and VR; always on with an F3 density knob; local cosmetic. Plan and build on Sonnet 5.5 `high` |
| 14 | Lore mark | None | The coach hatch stays plain |
| 15 | Span ends | Closed: each span steps down to its skirt | No belt code; `HORIZON_SPAN` stays 48 |
| 16 | Passing shadows at dawn and dusk | Keep, judged in the hero's flat run | D14 |
| 17 | Scene budget | About 49,600 | With F7's open gaps the plan lands near 49,200 |
| 18 | Draw calls | Merge per material now; decide a belt fix in code after Quest timing | About 900 objects before culling, about 450 in view |
| 19 | How the finals are built | A finals script for `horizon_ridge`; the train modeled by hand in `train_rooftop.blend` | Never re-run the greybox script (G7); the span script must not call `scenery_uv.process_scene()` |

## G. Pipeline friction

Where the existing texturing pipeline (`docs/TEXTURING.md`) adds work or constraints beyond "model and UV unwrap, then you paint by hand".

**Verdict on the unwrap: reuse `dev/unwrap_per_glb_blender.py` as it is for the train.** It already does the UV job: one non-overlapping 0-to-1 layout per GLB at one texel density, islands upright and never mirrored, round parts unrolled, and `uv_lock` to keep hand edits. It treats every root empty in `train_rooftop.blend` as its own GLB, so the split (F2) needs no change. For `horizon_ridge` the real UV job is the 8 m tiling UVs, which `dev/scenery_uv.py` writes (G8). The items below are its edges.

1. **One image for the whole train.** Today 371 meshes share one 256 px image at 4.3 px per metre, and 132 of them get under 16 px². Simplest: split by asset (F2): each module gets its own image, painted once for every copy. Cost: five new GLBs, each with a `.glb.import` copied from `train_rooftop.glb.import` (`import_script/path` and `gltf/embedded_image_handling=3`, or `load` fails); instance nodes in `train_rooftop.tscn`; the gap walks move into the coupler; new rows in `TEXTURE_LIST.md` and `TEXTURING.md`.
2. **The deck under your feet wants more texels than 256 px gives.** A coach alone should unwrap near 15 px per metre (an estimate from its surface area), so a texel is about 7 cm: 48 px across at 2 m in a headset. Simplest: accept it and paint big flats; decide after the hero's unwrap, as Main Street F19. Alternatives: scale the walk's and deck's islands up by hand after the unwrap, which `uv_lock` keeps; a 512 px image for the coach (`TEX_PX` is one constant for every map, so this is code); or tiling UVs on the deck, which needs a tiling-texture path (code, Canyon G1).
3. **Hidden faces eat texture.** The unwrap lays out every face at one density. Simplest: delete them while modeling (rule 27): the tin under the walk, the body's top under the deck, the deck's underside inside the eaves where the body meets it, faces against the platforms' floors. Cost: none; it also saves triangles.
4. **Copies inside one GLB get separate islands.** Eight wheels a car, the vents, the logs, the balusters: the unwrap never stacks copies. Simplest: accept it; they are too small to paint and stay flat colour. The modules avoid it for the cars themselves.
5. **Mirrored sides.** Each car's left and right sides get their own islands, never stacked or mirrored. Simplest: paint both. Cost: twice the side painting, which is also the honest result, since the two sides are lit differently.
6. **A plain run keeps old UVs.** Simplest: run `-- --relayout --glb <name>` after each final. Cost: none while nothing is painted; after painting, a relayout breaks the image's fit.
7. **The build script wipes finals.** `dev/build_train_rooftop_blender.py` clears the scene, rebuilds the greybox, and runs the paused trim-sheet pass (band cuts, strip UVs, a preview node). Simplest: model the finals in `train_rooftop.blend` and never re-run it after the first final lands; a finals script for the spans (F19) must not call `scenery_uv.process_scene()`. Cost: the greybox survives only in git history.
8. **Nothing writes tiling UVs on a new rock mesh.** The per-GLB unwrap skips tiling meshes. Simplest: call `scenery_uv.unwrap_object(obj, scenery_uv.TILING)` on each span object in the build session and set its `uv_role` to `tiling`, with zero rotation and the origin at the span's origin (Canyon G2, G3). Cost: a few lines.
9. **Four rock names only.** A fifth rock colour needs a line in each of two files. Simplest: the spans fit into `M_Rock`, `M_RockDark`, `M_CapDark`, and `M_Cap`, whose names no longer describe their colours. Cost: naming only.
10. **No vertex colours, normal maps, emission, or alpha.** The importer skips such a material and `load` fails. So every railing bar and baluster is real geometry, and nothing glows except through the names `M_Flame` and `M_LampGlass`. Cost: triangles and draw calls, both budgeted.
11. **Names set behaviour.** `M_Car`, `M_Trim`, and `M_Plank` take grain by name; `M_Red` gets none, which suits paint; nothing on the train or the belt may take a sway name. Metallic and specular do nothing (Saloon G10): set 0.9 and 0. Exact values and one roughness merge materials, within one GLB only.
12. **The horizon is parked.** `horizon_ridge`'s three children sit beside the train in the `.blend` and are moved to the origin for export (`PARKED_CHILDREN`). Simplest: keep the spans as children of `horizon_ridge` under their exact names. New module roots need nothing: the export zeroes each root's location. Cost: none.
13. **Generated LODs.** Every scenario `.glb.import` sets `meshes/generate_lods=true`, so Godot may simplify a far span's strata. Simplest: look for a span that changes shape as it comes in (D15); if one does, set it false in `horizon_ridge.glb.import`, an import setting, not code. Cost: one reimport.
14. **Draw calls are a code question.** Merging per material is the floor for a mesh. The belt's 270 track objects and about 290 cactus objects stay, and going lower is code (F18).
15. **Blender cannot judge the light.** The banded sun, the passing shadows, the fog, and the glow only show in Godot. Simplest: one flat run per reviewed asset at all four times.
16. **The texturing docs go stale.** `TEXTURE_LIST.md` and the Train Rooftop rows in `TEXTURING.md` (one GLB, 371 meshes at 4.3 px per metre) will be wrong after the split. Simplest: refresh them from the script's printout.

The trim sheet, its texel-density targets, and the texture ripper play no part in this sheet.

## H. As built

### The split (C step 1)

Done on 2026-10-26 in `train_rooftop.blend`, by hand in a headless Blender session (a throwaway script outside the repo; F19: no train finals script in `dev/`). Every parentless empty is now one GLB root, exported by `dev/unwrap_per_glb_blender.py`:

| Root (GLB) | Parked in the `.blend` at Blender y | Holds | Proxies |
|---|---|---|---|
| `train_car_coach` | −6.6 (`CarA`'s place) | The final coach (below) | `Coach_Body`, `Coach_Roof` |
| `train_coupler` | 0 (`Coupler2`'s place) | The final coupler (below) | `Coupler_GapWalk` |
| `train_engine` | 40.2 (the greybox `Engine` root, unparented and renamed) | The greybox engine, geometry unchanged | `Engine_TenderBody`, `Engine_TenderRoof`, `Engine_Fuel`, `Engine_CabBody`, `Engine_CabRoof`, `Engine_GapWalk`, `Engine_Boiler`, `Engine_Pilot` |
| `train_car_baggage` | 33.0 (was `CarFrontB`) | The greybox car, geometry unchanged | `Baggage_Body`, `Baggage_Roof` |
| `train_car_business` | −33.0 (was `CarRearB`, with its ladder) | The greybox car, geometry unchanged | `Business_Body`, `Business_Roof` |
| `train_rooftop` | 0 | Nothing visible | `GuardSideL`, `GuardSideR`, `GuardEndRear`, `GuardEndFront`, boxes unchanged |
| `horizon_ridge` | 0 (children parked as before) | Unchanged | none |

All proxies carry `-convcolonly`. Deleted: `CarRearA`, `CarA`, `CarB`, `CarFrontA` (50 objects each), `Coupler0` to `Coupler4` (4 meshes each), the six `GapWalk*` proxies, and the buried `BulkA`/`BulkB` of the baggage and business cars (4 objects, 48 triangles). The export zeroes each root's location, so every GLB is modelled from its own origin and the scene carries the offsets.

- **Scene.** `train_rooftop.tscn` keeps `Train` (now the four guard walls) and gains, under the greybox node names, with no rotation: `CarRearB` (business) at z 33.0, `CarRearA`, `CarA`, `CarB`, `CarFrontA` (coach) at 19.8, 6.6, −6.6, −19.8, `CarFrontB` (baggage) at −33.0, `Engine` at −40.2 (the greybox root's Blender y, checked: its instance spans z −40.27 to −56.83 and up to y 4.40, as the greybox did), and `Coupler0` to `Coupler5` at 26.4, 13.2, 0, −13.2, −26.4, and −39.6. Markers, `Sun`, environment, and `Scenery` are untouched. Each new GLB has a `.glb.import` copied from `train_rooftop.glb.import` (`import_script/path`, `gltf/embedded_image_handling=3`), its uid filled in by Godot.
- **Names.** Godot strips `-convcolonly`, so a proxy may not share a name with a visual sibling: three greybox engine meshes are renamed (`Engine_Boiler` → `Engine_BoilerJacket`, `Engine_CabRoof` → `Engine_CabRoofSlab`, `Engine_Pilot` → `Engine_Cowcatcher`), geometry unchanged. Before that, Godot named those three proxies `@StaticBody3D@…`. `Talus.001` and `Talus.002` in `horizon_ridge` keep their dots until the spans are built (Found 6).
- **Materials.** The unwrap gave the three greybox GLBs their own copies of the greybox materials (`M_Car__train_car_baggage` and so on: 6 copies each), so they look exactly as before. The `__train_rooftop` copies have no users left and are gone.

### `train_car_coach` (hero) and `train_coupler`

Built on 2026-10-26 in `train_rooftop.blend` under the two new roots, by a throwaway headless script outside the repo that always starts from a backup of the greybox `.blend`. Exported, with every other root, by:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map train_rooftop --relayout
```

- **Tests:** `--import`, then `load`, `multi`, `ragdoll`, and `gauntlet`: all print `AUTOTEST PASS`. `load`: "1191 scenario surfaces wear world_surface.gdshader". `multi`: "rooftop strafe stays continuous and ragdolls ignore the guard walls". `ragdoll`: "spawn markers flush on the floor on every arena".
- **Belt:** counted in a throwaway run: 354 children under `Scenery` (90 tracks, 180 cacti, 84 spans).
- **Unwrap:**
  - `GLB train_car_coach [train_rooftop]: 5 meshes, 561 islands, 12.5 px/m at 256 px (pad 1, 60% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`
  - `GLB train_coupler [train_rooftop]: 1 meshes, 35 islands, 141.2 px/m at 256 px (pad 2, 63% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`
  - No TINY share on either. No UV overlap across islands (a triangle-pair test on the saved `.blend`), nothing outside 0 to 1. The walk top is one 24-vertex n-gon and one island. 0 copies, because the materials were made under their per-GLB names (`M_Car__train_car_coach`), with the Palette's values, roughness 0.9, metallic 0, Specular IOR Level 0.5, and no emission.
  - UV islands counted in the `.blend` (faces joined by shared UV edges): `Coach_Car` 19, `Coach_Trim` 147, `Coach_Glass` 18, `Coach_Plank` 68, `Coach_Iron` 317, `Coupler_Iron` 35. The unwrap counts 309 charts in `Coach_Iron`; some of its charts touch only at a vertex.
  - 12.5 px/m, against G2's estimate of 15: a 7.5 cm texel, about 48 px across at 2 m.
- **Collision:** `Coach_Body-convcolonly` x ±1.45, u ±6.0, z 1.15 to 3.01; `Coach_Roof-convcolonly` x ±1.525, u ±5.8, z 3.0 to 3.2 (the greybox's 3.05 m; the sheet's 3.04 is a rounding). `Coupler_GapWalk-convcolonly` x ±1.45, ±0.9, z 3.0 to 3.2, one per instance. In Godot after import, a ray down at all seven markers hits `Coach_Roof` at y 3.20, and at z 0, 13.2, and −39.6 it hits `Coupler_GapWalk` at 3.20.
- **Checks** (scratch scripts on the saved `.blend`): no zero-area triangles, non-planar faces, three-collinear corners, or smooth faces; names unique, no dots. Ray down in the module: the walk top is 3.20 under all seven marker lines; at x ±1.71 (the boot) every marker line lands on the tin at 3.16. No vertex above 3.20 inside u −3.75..−2.75, −1.95..−1.25, or 2.75..4.75. The highest points are the vents, the hinge, the handle, and the sprung board's lifted end, all at 3.26.
- **Views:** Blender renders: Top from 1.7 m over the walk and an orthographic top, Side at 10 and 22 m from both sides, Three-quarter (front right and rear left), Close views of a platform, a truck, the hatch, and the sprung board, Silhouettes (side, end-on, top), and the 64 px squints. The coupler alone (side, three-quarter, top, silhouettes, squint) and between two coaches at mid-lane (down 75°, from the roof, from the side). Flat Godot captures at noon, dusk, and dawn: Lane P, Lane E, Strafe both ends, Down 60° and over the mid-lane gap at 75°, Edge both sides, and Death cam both sides. Also the cab, the car-to-tender gap from the side and above, the mid-lane gap from beside the track, and the sprung board from `PlayerSpawn`. All outside the repo. The headset review is open.

| GLB | Triangles / budget | Objects | Copies | In scene |
|---|---|---|---|---|
| `train_car_coach` | 1,588 / 1,600 | 5 | 4 | 6,352 |
| `train_coupler` | 100 / 100 | 1 | 6 | 600 |
| `train_engine` (greybox) | 1,472 / 3,500 | 58 | 1 | 1,472 |
| `train_car_baggage` (greybox) | 824 / 1,300 | 46 | 1 | 824 |
| `train_car_business` (greybox) | 892 / 1,800 | 51 | 1 | 892 |
| `train_rooftop` | 0 | 0 | 1 | 0 |
| **Train** | | | | **10,140** in 181 objects (the greybox: 6,908 in 371) |

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Coach_Car` | `M_Car__train_car_coach` | 150 | Side walls, end walls, doors, deck tin, fascias, downstands, soffit, hatch cover |
| `Coach_Trim` | `M_Trim__train_car_coach` | 404 | Letterboards, window frames, reveals, sills, door frames and reveals, hatch rim |
| `Coach_Glass` | `M_Glass__train_car_coach` | 36 | 16 panes, 2 door lights |
| `Coach_Plank` | `M_Plank__train_car_coach` | 158 | The walk and the sprung board, platform floors, step treads |
| `Coach_Iron` | `M_Iron__train_car_coach` | 840 | Trucks, wheels, sills, truss, railings, brake staffs, rungs, grab irons, step hangers, vents, hinge, handle |
| `Coupler_Iron` | `M_Iron__train_coupler` | 100 | Drawheads, drawbars, link, pins and rings, safety chains |

Against B's lines: body, windows, and ends 524 (B: 450); roof deck, walk, hatch, and vents 276 (250); two platforms 444 (400); trucks 272 (350); underframe and truss 72 (150). The 16 windows take 384 of the body's 524. Coupler: drawheads 16, drawbars 12, link 24, pins and rings 36, chains 12.

**Where the coach departs from B:**

- **Windows.** The bone frames are flush in the wall plane (10 cm members; the top member is 13.5 cm and meets the letterboard, so no strip of blue under 10 cm runs between them). Each side wall is therefore one comb-shaped n-gon (36 vertices) and one island. The reveals run 12 cm back to the ink pane; the head reveal faces down and is deleted (rule 27). Sills are 10 cm tall, 12 cm proud, and 1.0 m long, under each frame.
- **Letterboard.** 2.76 to 3.01 m, 3 cm proud, the full body length; its top meets the soffit and is deleted, and the wall behind it is not modelled.
- **Deck.** The tin is two C-shaped faces: each strip plus an 8 cm tab at each end (u ±6.07 to ±6.15, x 0 to ±0.75) that fills the notches between the walk's short boards. The tabs join the two strips, so the tin is one island, not two. Side fascias run 3.01 to 3.16 m. The 0.20 m end fascia is the 0.15 m deck edge over a 10 cm deep downstand from 2.96 to 3.01 m (u ±6.05 to ±6.15). The soffit is two C-shaped faces round the deleted body top.
- **Walk.** Long boards end at u ±6.15 and short ones at ±6.07. The front reads long, short, long, short, long, short from x −0.75; the rear is the opposite, so the teeth interlock across every gap.
- **Sprung board.** The outermost right-hand board (x 0.50 to 0.75) from the rear end (u −6.15) to u −5.0, as its own piece, with the end at −5.0 lifted 6 cm. The walk n-gon is notched round it. On `CarB` it lies at z −1.6, x 0.5 to 0.75.
- **Hatch.** A bone rim 0.70 × 0.90 m, 10 cm wide and 8 cm proud (top at 3.24), with the blue cover flush inside it. The hinge (on the outboard edge) and the handle are iron straps 10 cm wide and 2 cm tall on top, to 3.26 m, so the roof's 10 cm ceiling holds. Their 2 cm height is under the size floor.
- **Vents.** 6-sided (rule 9): a 14 cm stem to 3.21 m and a 25 cm cap to 3.26 m. The left-hand vents are at u −5.0 and 0.8, the right-hand ones at −2.35 and 5.4, so the 0.8 vent sits across the walk from the hatch.
- **Platforms.** A raw-wood floor from 1.13 to 1.23 m. Two treads a side, 10 cm thick at 0.84 and 0.45 m, hang outboard of the body line (x 1.45 to 1.70, under the eave) on 8 cm iron hangers at each end: the platform floor is too close to the sill for treads under it. The railing is posts at x ±0.39 and ±1.41, with a top rail at 2.15 to 2.23 and a mid rail at 1.69 to 1.77 m, and no balusters (the triangle budget). The gate gap is 0.70 m between the posts' inner faces. The brake staff is 6-sided, 8 cm across its flats, with an 8-sided wheel 0.45 m across at 2.27 to 2.33 m: front platform at the right corner, rear at the left. Three solid iron rungs (0.40 × 0.10 × 0.08 m) at 1.55, 2.05, and 2.55 m stand on the other side of the door. Grab irons, 8 cm square from 1.35 to 2.35 m, stand at the end wall's corners.
- **End wall and door.** The blue leaf is recessed 5 cm behind a bone frame whose head (13 cm) meets the soffit. The ink light, 0.45 × 0.60 m, is flush with the leaf. Each door frame is three mitred quads. One n-gon frame per end gave the object exactly two faces of more than four vertices, which `scenery_uv._is_cylinder` read as a cylinder's caps, so the unwrap unrolled all of `Coach_Trim` as one cylinder (788 overlapping triangle pairs) until it was split.
- **Underframe.** The wooden sills are one iron box, x ±1.45, u ±6.0, 0.95 to 1.13 m. The body wall and the platform floors start at 1.13, 2 cm under `Coach_Body`'s 1.15.
- **Trucks.** The wheels are exactly the greybox's: 8 sides, bottoms at 0.21, treads x ±0.62 to ±0.82, axle centres at u ±3.7 ± 0.72. Side frames stand outside the wheels (x ±0.86 to ±0.98), with a dropped middle that reads as the equalizer bar. Axle boxes stand on the frames at each axle, and a bolster crosses at 0.78 to 0.95 m. Rule 27 deletes the axles, the wheels' inner caps, and the two tread faces that face down: from every view in D the axles are hidden by the wheels, the side frames, and the sill.
- **Truss.** Two 8 cm square rods at x ±1.30 drop from the sill at u ±3.7 to queen posts at u ±1.2 (rod at 0.55 m, 0.4 m under the sill), with a 10 × 25 cm turnbuckle block at u 0. The faces toward the car's centre and the downward faces are deleted.
- **Unseen undersides deleted:** the vent caps, the brake wheels, the step treads, the rungs.

**Where the coupler departs from B:**

- **Height.** The drawheads are centred at 1.04 m (0.30 m cubes, 0.89 to 1.19 m) at ±0.25 to ±0.55 m from the gap centre, under the platform floors' level. Their faces toward the cars, in a 5 cm slot, and their bottoms are dropped. The drawbars (14 cm square) run on to ±0.85 m, 0.25 m into each car's sill.
- **Link.** A 6-sided oval, 0.88 m long and 0.28 m wide over the 8 cm bar, its ends inside the drawheads. Top and outer faces only: the shader draws both sides, so its far bar's back shows through the hole.
- **Pins.** 8 cm square, not 6-sided as rule 9 asks: the budget. Each stands 0.25 m above its drawhead with a flat ring 0.24 m across (8 cm bar), facing along the train. The front pin (toward the engine) leans 10° toward the gap centre.
- **Chains.** Three links a side at x ±0.45, each a flat diamond 0.46 m long and 0.10 m wide, the middle one in the vertical plane and the outer two flat. They droop from 1.04 m at the ends to 0.80 m. "Three 10 cm links" cannot span a 1.2 m gap, so the links are 10 cm wide and about 0.46 m long.
- **The car-to-tender gap** (`Coupler5`, z −39.6): the car's end is 0.6 m from the centre and the tender's rear face 0.72 m. The drawbar reaches 0.85 m and a chain end 0.74 m, so both meet the tender's face line, with the same module at all six gaps. The greybox tender has no end beam at coupler height (its body starts at 1.15 m), so the drawbar and chain ends run 2 to 13 cm under its body. The engine's final needs an end beam there, about 0.95 to 1.15 m.

**Build lessons:**

- `scenery_uv._is_cylinder` takes any object with exactly two faces of more than four vertices and quads elsewhere as a cylinder, if the n-gons' corners lie near a circle. A merged per-material object can trip it. After the unwrap, check UV overlap, or keep n-gons off such objects (more than two, or none).
- Godot strips `-convcolonly`. A proxy named like a visual sibling (`Engine_Boiler`) imports as `@StaticBody3D@…`.
- Workbench F12 renders take the world colour, not the viewport background: set `scene.world.color` to white for silhouettes.

**Found while reviewing:**

- **The Edge and Death cam views in D do not see the car's side.** From (±1.3, 4.9, 7) the eye is inside the 0.30 m eave, so the deck hides everything below it out to about x 2.6 on the ground. From (±3.08, 4.28, −10) looking at (0, 3.4, −10) the eye is 1.1 m above the tin and looks down across the deck: it sees blue tin, the walk, and the fascia, not the letterboard or windows. D16 and the coach's asset check ("does the death cam see blue, bone, and ink") need an eye below about 3.0 m to look at the side.
- **Noon.** The raw-wood walk under the noon sun and grain draws nearly white in the flat capture, close to the bone trim. The silver walk on blue tin reads at every time; at dawn and dusk it is mid-brown.
- **The gaps.** From Lane P the mid-lane gap reads as a dark joint with the toothed walk ends on both sides, and through it the far platform's railing, the coupler's pins, and the track. The sprung board shows from `PlayerSpawn` as a short raised step at the far side of the mid-lane gap.

**Still open:**

- The rest of C: `train_engine` (done, below), `train_car_business` and `train_car_baggage` (the coach's kit; done, below), then `horizon_ridge`. The coupler is already at all six gaps.
- The in-context review in a headset: D items 10 to 17, and the coach's and coupler's asset checks there (the gap crossing, leaning out at a guard wall).
- Late afternoon flat captures, and three captures 2 s apart per view (only one per view was taken).
- Whether 12.5 px/m on the coach is enough to paint the deck (G2).
- Quest timing: the train is 181 objects (was 371).

### `train_engine` (C step 3)

Built on 2026-10-26 in `train_rooftop.blend` under the `train_engine` root only, by a throwaway headless script outside the repo that starts from a backup of the `.blend` holding the approved coach and coupler. It deletes the root's 58 greybox visuals, keeps the eight proxies untouched, deletes the stale copies (`M_Boiler__train_engine`, `M_CarDark__…`, `M_Lamp__…`, `M_Window__…`), and writes the eight materials under their per-GLB names with the Palette's values, roughness 0.9, metallic 0, Specular IOR Level 0.5, and no emission. Every other root is untouched. Exported alone by:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map train_rooftop --glb train_engine --relayout
```

- **Tests:** `--import`, then `load`, `multi`, `ragdoll`, and `gauntlet`: all print `AUTOTEST PASS`. `load`: "1141 scenario surfaces wear world_surface.gdshader (… 3 self-lit …)" (1191 before: the engine went from 58 meshes to 8). `multi`: "rooftop strafe stays continuous and ragdolls ignore the guard walls". `multi` and `ragdoll`: "spawn markers flush on the floor on every arena".
- **Unwrap:** `GLB train_engine [train_rooftop]: 8 meshes, 573 islands, 10.5 px/m at 256 px (pad 1, 58% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`. No TINY share (a first pass flagged the lamp glass at 15.8 px²; the lens grew from 0.38 to 0.41 m across). UV islands counted in the `.blend`: 575 (`Engine_Brass` 69, `Engine_Car` 12, `Engine_Glass` 4, `Engine_Iron` 326, `Engine_LampGlass` 1, `Engine_Plank` 10, `Engine_Red` 122, `Engine_Trim` 31). No UV overlap between any two triangles of different faces, nothing outside 0 to 1. The tender walk top is one quad and one island. No object trips `scenery_uv._is_cylinder` (each has 0, 1, or more than 2 n-gons; checked by calling it).
- **Other GLBs:** `train_car_coach`, `train_coupler`, `train_car_baggage`, `train_car_business`, `train_rooftop`, and `horizon_ridge` are byte-identical before and after (MD5); in the `.blend` they hold 5/1,588, 1/100, 46/824, 51/892, 0/0, and 14/168 objects/triangles, as before.
- **In Godot:** a ray down hits `Engine_TenderRoof` at y 3.20 on the tender deck (z −41.0, −43.5, −45.5), `Engine_GapWalk` at 3.20 over the tender-to-cab gap (z −47.4), `Engine_CabRoof` at 3.20 on the cab roof (z −48.7, −49.4), and `Coupler_GapWalk` at 3.20 at z −39.6. The proxies import as `StaticBody3D` under their own names (`Engine_Boiler`, `Engine_CabBody`, …: no `@StaticBody3D@`). `Engine_LampGlass` is self-lit and casts no shadow; every other engine mesh casts. Four `Guard*` walls. The `Engine` instance spans x ±1.525, y 0.21 to 4.40, z −40.24 to −56.83.
- **Checks** (scratch scripts on the saved `.blend`): no zero-area triangles, non-planar faces, three-collinear corners, or smooth faces; no two overlapping triangles share a plane anywhere on the engine; names unique, no dots, and no visual shares a stripped name with a proxy. The highest vertex is the stack's crown at 4.40; nothing else passes 3.73 (the headlight's chimney). Tops: steam dome and whistle 3.58, sand dome 3.33, bell yoke 3.34. Every wheel bottom is at 0.21 with its tread at x ±0.62 to ±0.82.
- **Views:** Blender renders: Side from +x at 15 m (24 mm) and at 26 m (50 mm: a 50 mm lens at 10 or 15 m cannot frame the 16.6 m engine), Side from −x at 26 m, Three-quarter (front right and rear left), orthographic Top, the cab view, the tender walk, Close views of the running gear, domes, stack and headlight, cab window, pilot, and the tender's rear, Silhouettes (side, front, rear, top), the 64 px squints, and the car-to-tender gap with `Coupler5` and the baggage car. Flat Godot captures at noon and dusk: Lane P (wide and zoomed on the engine), the Cab view, a low side view from both sides, a front quarter, the car-to-tender gap from beside the track and from above, and the tender deck. All outside the repo. The headset review is open.

| GLB | Triangles / budget | Objects | Copies | In scene |
|---|---|---|---|---|
| `train_engine` | 2,294 / 3,500 | 8 | 1 | 2,294 |
| **Train** | | | | **10,962** in 131 objects (after the coach: 10,140 in 181) |

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Engine_Car` | `M_Car__train_engine` | 58 | Tender sides and ends, deck tin, cab walls, boiler jacket |
| `Engine_Trim` | `M_Trim__train_engine` | 154 | Tender rim, four arched window frames and their reveals |
| `Engine_Glass` | `M_Glass__train_engine` | 24 | Four cab panes |
| `Engine_Plank` | `M_Plank__train_engine` | 272 | Tender walk, the cordwood heap |
| `Engine_Iron` | `M_Iron__train_engine` | 846 | Smokebox and door, stack, cylinders and saddle, cab roof and floor plate, frames, running boards, handrails, rods, crossheads and guides, counterweights, crank bosses, pilot beam, truck frames, tender sills and end beams, grab irons, fall plate, drawbar, headlight bracket |
| `Engine_Brass` | `M_Brass__train_engine` | 494 | Bands, steam and sand domes, whistle, bell and yoke, headlight body |
| `Engine_Red` | `M_Red__train_engine` | 440 | Drivers, pilot and tender wheels, cowcatcher |
| `Engine_LampGlass` | `M_LampGlass__train_engine` | 6 | The headlight lens |

Against B's lines (about; the script's sections do not fall exactly on them): boiler, smokebox, bands, and stack 346 (B: 450); domes, bell, whistle, and headlight 348 (400); cab 194 (400); tender and wood heap 658, of which the heap is 264 (900); drivers, rods, and cylinders 376 (650); pilot and pilot truck 256 (350); frame, running boards, and handrails 116 (350).

Positions below are the root's local Blender y (Godot z = −y − 40.2).

**Where the engine departs from B:**

- **Merged prisms.** B's UV note asks for the boiler, smokebox, and stack as plain prisms on the unwrap's cylinder path. Merged into eight objects (rule 26) they are not single cylinders, so they unroll as charts (a 12-sided barrel in about three). The jacket is one open 12-sided tube, flat face on top (z 2.73), y 9.40 to 13.55; its rear end is inside the cab.
- **Drivers under a fattened boiler.** The 1.56 m boiler is wider than the gauge, so each driver's top (to 1.73) runs inside the barrel's lower side from about 1.48 up. The running boards (1.76 to 1.84, x ±0.70 to ±1.30) cover the join from above and the side; there are no splashers. Interpenetration, not a shared plane.
- **Wheel layout.** Driver axles at 10.35 and 12.15 (Godot z −50.55, −52.35): 1.52 m across corner to corner, 12-sided, vertex down like the coach's wheels, centre 0.97. The rear driver clears the cab front (9.51) by 8 cm. Pilot axles at 13.75 and 14.75, wheels 0.80 m, 8-sided. Tender axles where the greybox had them (1.55 ± 0.72, 5.45 ± 0.72), 0.84 m, 8-sided, now vermilion. No axles are modelled; the wheels' inner faces and the treads that face down are deleted (rule 27, as the coach).
- **Rods.** Crank pins set back and up (150°), so the side rod runs level at 1.12 between them and the main rod runs from a crosshead at 13.20 to the front pin. Counterweights are iron, not vermilion, so they read on the red wheel; B does not say. Cylinders are horizontal, 8-sided, 0.48 m, at x ±1.10, y 13.70 to 14.60, on an iron saddle.
- **Stack.** 8-sided: a 0.5 m pipe to 3.55, the double cone 1.2 m across the flats at 4.00, a crown 0.96 m across from 4.34 to 4.40. Read "crown 1.2 m across" as the double cone's width. Leaning 2° back, its highest corner is exactly 4.40, so the crown's centre is at (0, 4.383, −54.25): 1.7 cm under 4.40, on the smoke's axis.
- **Headlight.** On a 12 cm iron bracket on the smokebox's flat top (2.81): a brass box 0.54 × 0.52 × 0.60 m, a roof step, and a chimney, 0.80 m tall from 2.93 to 3.73. B's 3.6 m ceiling names the domes, bell, and whistle, not the lamp; it stays under 4.40 and behind the stack from Lane P. The lens is an 8-sided `M_LampGlass` face 0.41 m across, 5 cm inside a brass reveal.
- **Cab windows.** One arched window a side (opening 0.80 m wide, sill 1.95, spring 2.48, crown 2.86) and two small arched windows in the front wall over the boiler's shoulders (0.30 m wide), whose outer stiles are the cab corners so no blue strip under 10 cm is left. The arch has five segments with a flat crown: a four-segment arch came to a Gothic point. As on the coach, each bone frame runs up to the roof's soffit (3.02) and is three mitred quads plus a head n-gon, so each wall is one notched n-gon. The panes are 8 cm in, with reveals all round. The right-hand side window is the racked one (2°); its head stays level at the soffit. The rear wall is plain blue. The boiler passes through the front wall; the hidden part of the wall is not cut out.
- **Cab roof.** Iron slab 3.02 to 3.20, eaves 0.25 m at the sides (x ±1.525) and 0.10 m at the ends, so it stops short of the fall plate and under `GuardEndFront`. The greybox's cab-roof slab name is gone with it.
- **Tender.** Sides and ends blue from 1.15 to 3.06, then a bone rim 3.06 to 3.20, 3 cm proud and 12 cm wide on top: the 15 cm slot is closed (Found 2). Inside the rim the deck is blue tin at 3.16, as on the coach, with the plank walk (x ±0.75, y 0.24 to 4.05) at 3.20 on the rear half. `Engine_TenderRoof` still tops out at 3.20 everywhere, so the tin beside the walk is 4 cm under the proxy, as the coach's tin is.
- **Cordwood.** 43 logs in two rows of 1.24 m cordwood (y 4.12 to 5.36 and 5.36 to 6.60), stacked 7, 6, 5, 4 a row as pointy-topped hexagons 0.2 m across the flats, resting on the tin; the front row lacks one top log, which shows a notch from the side and the cab. Top at 3.91 (`Engine_Fuel` 3.96). Every face two logs share is removed, so the heap is the end grain toward the cars, the front row's end grain toward the cab, and the outer faces.
- **End beam (new, from batch 1).** Iron, x ±1.44, y 0.06 to 0.22 (Godot z −40.26 to −40.42), z 0.95 to 1.15, under the tender's rear wall, with a matching beam at the front. `Coupler5`'s drawbar runs 19 cm into it and the chain ends 8 cm; seen from beside the track and from above. Grab irons stand on the rear corners.
- **Fall plate.** Iron over the tender-to-cab gap, top at 3.20, y 6.95 to 7.34, x ±0.75 (the greybox plate reached 3.21). An iron drawbar joins the tender's front beam to the cab's floor plate underneath.
- **Bands.** 12 cm wide, 5 cm proud, at 9.80, 11.89, and 13.25, clear of the dome flares; the three faces under the barrel are left out (between the frames, behind the wheels).
- **Domes and bell.** Steam dome at 10.65 with the whistle (6-sided) to 3.58, bell in its yoke at 11.55 to 3.34, sand dome at 12.55 to 3.33. The sand dome's flat is a 10.1 cm facet on its front right shoulder, cut by a plane (wear).
- **Running boards and handrails.** Boards to 14.85, 4 cm short of the smokebox's front. Handrails 8 cm square at x ±0.74 to ±0.82, z 2.46 to 2.54, on three stanchions a side.
- **Pilot.** The beam is iron (x ±1.05, y 15.05 to 15.30). Eight vermilion slats (10 × 6 cm) at x ±0.16, ±0.40, ±0.64, ±0.88 fall from a top V rail at 1.05 to a bottom V rail at 0.33, with a nose post; the tip reaches 16.63. Pilot truck frames and axle boxes are iron.
- **Hidden faces deleted:** body bottoms, the bell yoke posts' tops, the stack and domes' bottoms, the boiler's rear end, the frames' ends, the sills' tops and ends.

**Found while reviewing:**

- **Lane P.** Zoomed on the engine, the iron crown is the highest thing on the axis with open sky above it at noon and dusk; the silver end grain of the heap stands below it and hides the domes and the cab. The domes and the headlight do not show from `PlayerSpawn`.
- **Cab view.** The steam dome, whistle, bell yoke, and sand dome fill the near half, the stack the far; the headlight's back hides behind the stack's pipe.
- **Noon.** The heap and the tender walk draw near white at noon, as the coach's walk does.
- **Dusk.** The headlight's lens reads as a lit disc in the front quarter view.

**Still open:**

- The headset review: stand on the cab roof (D's Cab view at 1 to 7 m), walk the tender deck and cross the tender-to-cab gap, and check the lamp glass reads flat and unshadowed.
- Dawn and late afternoon captures, and three captures 2 s apart per view.
- The baggage and business cars (C step 4; done, below) and `horizon_ridge` (C step 6). The engine smoke is its own Roadmap item; the crown's centre is at (0, 4.383, −54.25).
- Whether 10.5 px/m is enough to paint the engine (G2).
- Quest timing: the train is now 131 objects.

### `train_car_baggage` and `train_car_business` (C step 4)

Built on 2026-10-26 in `train_rooftop.blend` under those two roots only, by a throwaway headless script outside the repo that starts from a backup of the `.blend` holding the approved coach, coupler, and engine. It reuses batch 1's coach geometry and numbers (deck at 3.16 tin and 3.20 walk, x ±1.75, fascias, eaves, soffit, platforms, windows, letterboard, trucks, wheels, truss), parameterised by where each body's end walls stand. It deletes both roots' greybox visuals (46 and 51 objects), keeps the four proxies untouched, deletes the stale copies (`M_CarDark__…`, `M_Roof__…`, `M_Window__…`, `M_Wood__…` for both GLBs), and writes the materials under their per-GLB names with the Palette's values, roughness 0.9, metallic 0, Specular IOR Level 0.5, and no emission. Every other root is untouched. Exported one at a time by:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map train_rooftop --glb train_car_baggage --relayout
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map train_rooftop --glb train_car_business --relayout
```

- **Tests:** `--import`, then `load`, `multi`, `ragdoll`, and `gauntlet`: all print `AUTOTEST PASS`. `load`: "1056 scenario surfaces wear world_surface.gdshader (204 sway, 4 self-lit, …)" (1141 before: the two cars went from 46 and 51 meshes to 5 and 7; the business car's lamp glass is the fourth self-lit surface). `multi`: "spawn markers flush on the floor on every arena" and "rooftop strafe stays continuous and ragdolls ignore the guard walls".
- **Unwrap:**
  - `GLB train_car_baggage [train_rooftop]: 5 meshes, 426 islands, 13.3 px/m at 256 px (pad 1, 61% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`
  - `GLB train_car_business [train_rooftop]: 7 meshes, 567 islands, 11.9 px/m at 256 px (pad 1, 58% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`
  - No TINY share on either (the four marker lenses together are well over 16 px²). No UV overlap between any two triangles of different faces, nothing outside 0 to 1. Each walk top is one 24-vertex n-gon and one island. No object trips `scenery_uv._is_cylinder` (checked by calling it).
  - UV islands counted in the `.blend`: baggage 434 (`Baggage_Car` 28, `Baggage_Trim` 61, `Baggage_Glass` 8, `Baggage_Plank` 49, `Baggage_Iron` 288); business 576 (`Business_Car` 19, `Business_Trim` 117, `Business_Glass` 14, `Business_Plank` 41, `Business_Iron` 246, `Business_Brass` 135, `Business_LampGlass` 4). The unwrap's counts are lower where charts touch only at a vertex.
  - A first pass found 16 overlapping triangle pairs in `Baggage_Trim`: the Z-brace's diagonal shared the battens' corners, so its 3 cm edges and theirs fell into one folded chart. The diagonal now stops 6 cm short of the leaf's edges, and the overlap is gone.
- **Other GLBs:** `train_car_coach`, `train_coupler`, `train_engine`, `train_rooftop`, and `horizon_ridge` are byte-identical before and after (MD5); in the `.blend` they hold 5/1,588, 1/100, 8/2,294, 0/0, and 14/168 objects/triangles, as before.
- **In Godot:** a ray down hits `Business_Roof` at y 3.20 at z 38.7, 33.0, 27.3, and at x 1.4 (z 30); `Baggage_Roof` at 3.20 at z −27.3, −33.0, −38.7, and at x −1.4 (z −35); `Coupler_GapWalk` at 3.20 at z 26.4, 13.2, −26.4, and −39.6, the gaps either side of both cars. The proxies import as `StaticBody3D` under their own names (`Business_Body`, `Business_Roof`, `Baggage_Body`, `Baggage_Roof`). `Business_LampGlass` is self-lit and casts no shadow; every other mesh on both cars casts. Four `Guard*` walls. In the scene the train is 12,004 triangles in 46 meshes.
- **Checks** (scratch scripts on the saved `.blend`): no zero-area triangles, non-planar faces, three-collinear corners, or smooth faces; no two overlapping triangles share a plane on either car; names unique, no dots, and no visual shares a stripped name with a proxy. Ray down along x −0.7, 0, and 0.7 from u −6.1 to 6.1: the walk is 3.20 everywhere and the tin 3.16 beside it; at x ±1.71 (the boot) the tin is 3.16. Nothing stands more than 0.15 m above the walk within ±0.6 m of the axis: every vertex over 3.35 is a smoke jack. Highest points: the baggage jack 3.859 (leaning), the business jacks 3.86. Every wheel bottom is at 0.21 with its tread at x ±0.62 to ±0.82.
- **Views:** Blender renders of both cars: Side from +x and −x at 22 m (50 mm) and from +x at 10 m (24 mm), Three-quarter (front right and rear left, 35 mm: a 50 mm lens at 15 m crops the 12.3 m car), orthographic Top, Top from 1.7 m over the walk (down and forward), Silhouettes (side, both ends, top), and the 64 px squints. Close views: the baggage car's door, ajar hatch, jack, and blind front end; the business car's rear platform, the rear from low behind, both lamps, the dent, the windows and pilasters, and the jacks; each car's roof from the walk. Flat Godot captures at noon and dusk: Lane P (wide and zoomed on the baggage car), Lane E (wide and zoomed on the business car), with a stand-in capsule 0.6 m across at the far spawn; D's Rear view; leaning over `GuardEndRear`; behind the train, low; each car from the side at 9 m; and the whole train from 26 m on both sides. All outside the repo. The headset review is open.

| GLB | Triangles / budget | Objects | Copies | In scene |
|---|---|---|---|---|
| `train_car_baggage` | 1,156 / 1,300 | 5 | 1 | 1,156 |
| `train_car_business` | 1,602 / 1,800 | 7 | 1 | 1,602 |
| **Train** | | | | **12,004** in 46 objects (after the engine: 10,962 in 131) |

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Baggage_Car` | `M_Car__train_car_baggage` | 114 | Side walls (two pieces a side), door leaves, end walls, the rear door, deck tin, fascias, downstands, soffit, the closed hatch's cover and the ajar one |
| `Baggage_Trim` | `M_Trim__train_car_baggage` | 162 | Letterboards, window frames and reveals, Z-bracing, the rear door frame, hatch rims |
| `Baggage_Glass` | `M_Glass__train_car_baggage` | 14 | Four panes, the rear door light, the ajar hatch's slit |
| `Baggage_Plank` | `M_Plank__train_car_baggage` | 118 | The walk, platform floors, step treads |
| `Baggage_Iron` | `M_Iron__train_car_baggage` | 748 | Trucks, wheels, sills, truss, railings, brake staffs, rungs, grab irons, step hangers, door tracks, the smoke jack |
| `Business_Car` | `M_Car__train_car_business` | 102 | Side walls, end walls, doors, deck tin, fascias, downstands, soffit, hatch cover |
| `Business_Trim` | `M_Trim__train_car_business` | 320 | Letterboards, window frames and reveals, pilasters, sill courses, door frames, hatch rim |
| `Business_Glass` | `M_Glass__train_car_business` | 28 | Twelve panes, two door lights |
| `Business_Plank` | `M_Plank__train_car_business` | 102 | The walk, both platform floors, the front step treads |
| `Business_Iron` | `M_Iron__train_car_business` | 726 | Trucks, wheels, sills, truss, the front railing, brake staff, rungs, grab irons, step hangers, vents, hinge, handle, two smoke jacks |
| `Business_Brass` | `M_Brass__train_car_business` | 316 | The rear railing (top rail and 20 balusters), two marker lamp bodies with caps and stems |
| `Business_LampGlass` | `M_LampGlass__train_car_business` | 8 | Four lenses |

Baggage by section: sides, walls, and windows 92; doors and tracks 80; letterboards 16; end walls and the rear door 30; rear platform 206; blind front platform 196; deck, fascias, soffit, and walk 118; hatches 40; jack 34; underframe, trucks, and truss 344. Business: sides, windows, pilasters, and sill course 312; letterboards 16; end walls and doors 56; front platform 206; observation platform and railing 208; marker lamps 124; deck, fascias, soffit, and walk 118; hatch and vents 150; jacks 68; underframe, trucks, and truss 344.

Positions below are the root's local Blender (x, u); Godot z = −u − 33.0 for the baggage car and 33.0 − u for the business car.

**Where both cars depart from the coach's kit:**

- **Two kit faults fixed in the copies, not in the coach.** The coach's step treads end against the hangers with both end faces in the hangers' planes, and its queen posts share the truss rod's outer plane (a coplanar pair the engine's check would flag; batch 1 did not run it). On these two cars the tread ends are dropped and the queen posts stand 1 cm proud of the rod. The approved coach is untouched; see Still open.
- **No sprung board** on either walk: neither car's wear names one. Each walk is the coach's toothed 24-vertex n-gon.

**Where the baggage car departs from B:**

- **Express hatches** are 0.80 × 1.00 m, not 1.0 × 1.0: the strip between the walk (x 0.75) and the deck edge (1.75) is 1.0 m, and a full-width hatch would leave no tin and put its side in the walk's side plane. They stand at x ±0.85 to ±1.65, 6 cm proud (top 3.22), with 10 cm bone rims and blue covers: left at u −1.0, right at u 1.0. The right one is ajar, hinged on its outboard edge with the inboard edge lifted 4 cm (to 3.26); an ink slit (`M_Glass`, a quad and two triangles) closes the gap, so it reads as a dark line under a raised lid.
- **Sliding doors.** Each leaf is 1.8 × 1.6 m (u −0.9 to 0.9, z 1.08 to 2.68), blue, 4 cm proud, its top hidden under the track. The Z-bracing is bone, 3 cm proud: two 12 cm battens flush with the leaf's top and bottom and a 12 cm diagonal from bottom rear to top front. The iron track is 8 × 8 cm at 2.68 to 2.76, under the letterboard, from u −0.9 to 2.75, the length of two doors (the door slides toward the front). The wall behind the leaf and the track is cut, so each side wall is two pieces and two islands; each door leaf is one island.
- **Windows.** Two a side at u ±3.6, openings 0.5 × 0.4 m (2.25 to 2.65), flush 10 cm frames whose top member (11 cm) meets the letterboard, as the coach's do, 12 cm reveals, ink panes. No sills: B does not ask for them.
- **The blind front end** (u 5.2, toward the tender) is one blue face with no door. The railing is closed: posts at x ±1.41 and 0, both rails continuous. Steps, brake staff (right corner), rungs, and grab irons are the coach's. The rear end (toward `CarFrontA`) is the coach's platform and door.
- **Smoke jack** at (1.25, −4.0): a 6-sided pipe 0.20 m across to 3.76, a 6-sided brim 0.32 m across its corners (3.76 to 3.80), and a low 6-sided pyramid to 3.86, 0.70 m in all. It leans 3° outboard about its foot; the pipe starts 3 cm inside the deck so the lean opens no gap. From `PlayerSpawn` it stands 1.8° right of the axis, beside the stand-in capsule at `EnemySpawn` in both zoomed captures.
- **No vents:** B lists none for this car.

**Where the business car departs from B:**

- **Observation platform.** The rear end wall stands at u −4.8, so the platform is 1.2 m deep inside `Business_Body`, on a raw-wood floor (1.13 to 1.23). The railing's top rail is one 8 × 8 cm bar swept round three sides (2.15 to 2.23, 1.0 m over the floor) with mitred corners, its ends against the end wall. Twenty 8 cm balusters stand under it: twelve across the rear at 0.256 m centres, corner posts included, and four a side at 0.25 m; their tops follow the rail's underside. The railing is closed on three sides as B says: no gate, steps, or brake wheel on the rear platform. The rear door is the coach's door kit in its bone frame.
- **The dent** is at the right-rear corner (+x, the lit side): the rail drops 4 cm to the corner over its last 0.46 m on both the rear and the side run. Those two sloped, mitred quads on top and bottom are each two triangles.
- **Marker lamps** hang from the soffit at the rear corners (x ±1.52, u −5.85), outside the side railing and over the platform's corners, under the deck end: brass bodies 0.44 × 0.44 × 0.50 m (2.40 to 2.90), a cap 0.52 m square (2.90 to 2.95), and a 10 cm stem to the soffit. Each has two lenses, on its rear and outboard faces, 0.24 × 0.30 m and 3 cm inside a 10 cm brass frame. The left lamp is turned 10° about its stem; its cap reaches x −1.82, 7 cm past the deck edge.
- **Windows and pilasters.** Six a side, openings 1.0 × 0.95 m (1.675 to 2.625) at a 1.4 m pitch centred on the body (u −3.3 to 3.7), in flush 10 cm frames whose top member (13.5 cm) meets the letterboard, with 12 cm reveals and ink panes. Bone pilasters 0.20 m wide, 3 cm proud (flush with the letterboard's face), run from the sill course to the letterboard: five between the windows, where each with the two frame stiles makes a 0.40 m bone post, and two at the body's corners. In place of single sills, one sill course runs the body's length, 12 cm proud and 10 cm tall. Blue shows as a dado under the sill course and as a 0.7 m panel at each end of the window row: the side reads as a bone colonnade with ink windows on blue, the richer car.
- **Smoke jacks** at (±1.25, 4.0), as the baggage car's but upright, top 3.86. From `EnemySpawn` they stand either side of the stand-in capsule at `PlayerSpawn` in both zoomed captures.
- **Deck kit.** The coach's hatch (no mark, F14) and four vents at the coach's places. The front end is the coach's platform kit, facing `CarRearA` across `Coupler0`.
- **The greybox ladder is dropped**; the three rungs on the front end wall are the coach's.

**Found while reviewing:**

- **D's Rear view does not see the observation platform.** From (0, 4.9, 38.8) pitched 55° down toward +z, the eye looks past the deck's end (39.15) at the track: the deck runs on over the platform to 39.15 as the coach kit's does, so the platform lies under it. It shows when you lean over `GuardEndRear` (eye at (0.3, 4.5, 39.8): the brass railing and the lamps under the deck's edge) and from behind the train. B's Role ("a player there looks down on the observation platform") holds only leaning out past the wall.
- **The rear at dusk.** From behind and below, the brass railing, the bone-framed door, and both lit lenses read clearly against the blue end.
- **Noon.** The walks and the business car's bone side band draw near white at noon, as on the coach and the engine.

**Still open:**

- The headset review: lean over `GuardEndRear` and check the platform, railing, dent, and lamps read under the deck's edge; check the lenses read flat in their own colour with no shadow; walk both roofs and cross the gaps at z 26.4, −26.4, and −39.6.
- The coach's two kit faults (tread ends and queen posts sharing planes): fixed in batch 5 (Coach fix, below).
- Dawn and late afternoon captures, and three captures 2 s apart per view.
- Whether 13.3 and 11.9 px/m are enough to paint the two cars (G2).
- `horizon_ridge` (C step 6; `Canyon` and `Mesa` done, below). Quest timing: the train is now 46 objects.

### `horizon_ridge`: `Canyon` and `Mesa` (C step 6)

Built on 2026-10-26 in `train_rooftop.blend` under the `Canyon` and `Mesa` children of `horizon_ridge` only, by the finals script F19 asks for, `dev/build_horizon_ridge_finals_blender.py`, committed and deterministic. It opens the `.blend` itself, runs headless, and never calls `scenery_uv.process_scene()`. `--part canyon` and `--part mesa` delete the span's children (the greybox `Talus`, `Wall`, `Buttress`, `Cap`, and `Talus.001`, `Lower`, `Upper`, or an earlier final) and build four merged objects under it. `--part butte` is a stub that leaves the greybox `Butte` as it is (the next batch). `--part all` runs all three. The span roots keep their names and their parked places beside the train (`Canyon` at Blender (40, 56, 0), `Mesa` at (40, 112, 0); `PARKED_CHILDREN`). The script writes the Palette's four rock values to `M_Rock`, `M_RockDark`, `M_CapDark` (new in this `.blend`) and `M_Cap`, with roughness 0.9, metallic 0, and Specular IOR Level 0.5. These are shared tiling names with no per-GLB copies, so the greybox Butte now wears them too. Every other root is untouched. Built and exported by:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/build_horizon_ridge_finals_blender.py -- --part all
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map train_rooftop --glb horizon_ridge
```

- **How it is built.** Every piece is a closed prism placed by an explicit table on the 0.25 m grid (`CANYON_*`, `MESA_*`): slabs, blocks, 35° wedges, pillars, and fallen blocks. Each slab's foot is sunk 0.25 m into the slab under it, and a cap block stands on its body. One exact self-union per span is cut at z 0, so no face lies at 0 or at the terrain's 0.12. Coplanar fragments are dissolved, the 7.0 m ledge ring is split at x 0, every face is coloured (below), and the result is dissolved into one planar n-gon per flat region per material and split into one object per material. Each object sits at its span's origin with zero rotation and carries one `UVMap` of 8 m tiling UVs (`scenery_uv.unwrap_object(obj, scenery_uv.TILING)`, `uv_role` `tiling`). Nothing is random.
- **Colour by face** (rule 17 by this sun, toward Blender +X and −Y). Bone and violet stay as built. Each body face is coloured by these rules:
  - A vertical face or slope whose plan normal leans to +X (x component 0.3 or more) is `M_Rock`, and one leaning to −X is `M_RockDark`. So the −X face's sawtooth, turned 56.3° toward −Y, stays pink with lit teeth, as B's squint asks.
  - A face along the span is vermilion toward −Y, the end the sun reaches, and pink toward +Y. So the turned planes' returns on the +X face are pink, and so is every +Y end. The −Y ends and the pillars' −Y sides are vermilion on both faces.
  - The 7.0 m ledge ring is split at x 0 and takes its side's colour. Each top above it (the saddle, the upper body's strips in the sky gaps) crosses x 0 and takes the colour of its centre: pink on the Canyon, vermilion on the Mesa. All of those sit above the 4.9 m eye.
- **Re-run:** a second `--part all` prints the same counts and geometry hashes (Canyon `0fd4b61832b3`, Mesa `c7f13e1195b9`). A second export writes a byte-identical `horizon_ridge.glb`.
- **Tests:** `--import`, then `load`, `multi`, `ragdoll`, and `gauntlet`: all print `AUTOTEST PASS`. `load`: "1056 scenario surfaces wear world_surface.gdshader (204 sway, 4 self-lit, …)", unchanged, because it counts no belt copy (see Found). `multi`: "rooftop strafe stays continuous and ragdolls ignore the guard walls".
- **Unwrap:** `GLB horizon_ridge [train_rooftop]: 0 meshes, 0 islands, 0.0 px/m at 256 px (pad 2, 0% covered, 15 tiling meshes untouched); 0 materials copied; image none (flat colour)`.
- **Other GLBs:** `train_car_coach`, `train_coupler`, `train_engine`, `train_car_baggage`, `train_car_business`, and `train_rooftop` are byte-identical before and after (MD5).
- **In Godot** (a throwaway flat run):
  - `Scenery` has 354 children: 270 tracks and cacti, 20 `Canyon`, 20 `Mesa`, and 44 `Butte` copies.
  - The horizon instance has `Canyon`, `Mesa`, and `Butte`, and imports 292 and 236 triangles.
  - All 84 span copies wear world_surface.gdshader, and none sways.
- **Checks** (printed by the script on every run, and on the saved `.blend`):
  - Each span runs exactly y ±23.875 (47.75 m). No zero-area triangles, no non-planar faces, no smooth faces, no face at z 0 or 0.12, and no edge under 0.5 m.
  - Coplanar test across each span's four objects: 408 (Canyon) and 332 (Mesa) coplanar triangle pairs, none sharing area.
  - Skyline neighbours stand 0.75 m or more apart.
  - The sawtooth's least sunlight at any of the four elevations is N·L 0.067, at noon.
  - Names are unique with no dots.
  - 63% (Canyon) and 81% (Mesa) of vertices sit on the 0.25 m grid. The rest are the tilted fallen blocks, the apron's mitres and toes, and the chip.
  - 35 and 36 vertices lie on a straight outline edge (T-junctions where a neighbour's corner meets an edge: the cap blocks' ends on their body, the ledge ring's x 0 seam). Each such face triangulates without a zero-area triangle.
- **Views:**
  - Blender renders (Workbench, light from the scene's sun): Side from (±34, 0, 4.9) at 50 and 24 mm, Three-quarter from (±30, ±46, 4.9) onto both ends, a high three-quarter, Silhouettes (each face from 34 m, end-on from both ends), and the 64 px squints.
  - Flat Godot captures at noon, dusk, and dawn, three per view 2 s apart: Pass left and right (Lane P's eye at (0, 4.9, 10) aimed at (±35, 8, −40)), straight out each side, and Lane P at dawn and dusk.
  - All outside the repo. The headset review is open.

| GLB child | Triangles / budget | Objects | Copies on the belt | In scene |
|---|---|---|---|---|
| `Canyon` | 292 / 300 | 4 | 20 | 5,840 |
| `Mesa` | 236 / 240 | 4 | 20 | 4,720 |
| `Butte` (greybox) | 84 / 150 | 7 | 44 | 3,696 |
| **Horizon** | | 15 | 84 | **14,256** in 468 belt objects (the greybox: 5,376 in 448) |

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Canyon_Rock` | `M_Rock` | 73 | The +X lower body (flats, two turned planes, the buttress), the +X apron slope and the −Y end's, the +X upper body, every −Y end and step face, the +X half of the 7.0 m ledge ring, the +X free pillar |
| `Canyon_RockDark` | `M_RockDark` | 103 | The −X lower body (flats, three sawtooth planes, the buttress), the −X apron slope and the +Y end's, the −X upper body, every +Y face (returns, ends, steps), the −X half of the ledge ring, the saddle's top and the upper body's strips in the sky gaps, the −X free pillar |
| `Canyon_CapDark` | `M_CapDark` | 18 | The band: its two long faces, ends, and its top ring |
| `Canyon_Cap` | `M_Cap` | 98 | Four cap blocks (one chipped) with their undersides, two fallen blocks |
| `Mesa_Rock` | `M_Rock` | 54 | The +X lower body (flats, two turned planes at the +Y end), the +X apron slope and the −Y end's, the +X faces of both tiers' upper bodies, the −Y faces, the +X half of the ledge ring, the strips in both rims' sky gaps |
| `Mesa_RockDark` | `M_RockDark` | 62 | The −X lower body (flats, three sawtooth planes at the −Y end), the −X apron slope and the +Y end's, the −X faces of both upper bodies, the +Y faces, the −X half of the ledge ring |
| `Mesa_CapDark` | `M_CapDark` | 18 | The band |
| `Mesa_Cap` | `M_Cap` | 102 | The lower rim (two blocks) and its top round the upper tier, the upper rim (two blocks, one notched), one fallen block |

Positions below are the span's own Blender frame: x across the track (+X looks at the train from its left), y along it (−Y faces `PlayerSpawn`'s end), z up.

**`Canyon`, as built:**

- **Bands.** The lower body runs from the apron's slope to 7.0, its faces at x 4.5 and −4.75 (9.25 m thick), y ±20.5. The band runs from 7.0 to 8.25, 0.5 m behind the lower body, y ±18.0. The upper body stands 0.5 m behind the band, y ±17.5. The bone cap blocks overhang it 0.75 m on both faces.
- **Apron.** One 35° wedge a side, mitred at the corners: its toe at x 7.875 and −8.125 and at y ±23.875 (the span's ends), meeting the faces at 2.36 m.
- **Turned planes.** On +X, a run of two main planes turned 20.6° toward −Y (1.5 m forward over 4.0 m) at y −13 to −5, each with a square return. On −X, a sawtooth run of three planes turned 56.3° toward −Y (1.5 m out over 1.0 m) at y 3 to 6. They take the middle step at every hour: N·L at least 0.067, at noon.
- **Skyline.** Five 7 m segments, with tops 14.25, 15.0, 12.5 (the saddle), 17.5, and 16.75. The bodies stand at three heights (13.0, 12.5, 15.5), and each cap block is 1.25 to 2.0 m tall. Blocks stop 0.5 m short of a body's end face, with 1.0 m of sky between neighbours.
- **Closed ends.** Each end steps down twice within its last 6.375 m. The cap comes down to the 7.0 m ledge at y ±17.5, past a 0.5 m strip of upper-body top and the band's 0.5 m lip. The lower body then comes down to the apron at ±20.5.
- **Pillars.** Each face has two.
  - A buttress 1.5 m wide stands 1.5 m proud of the lower body, up to its top at 7.0. It ends the face's plane run: +X at y −5.0, −X at y 6.0.
  - A free pillar 1.5 × 1.5 m stands across the apron's toe, 2.625 m clear of the face, to 7.5 m: +X at y 12.0, −X at y −15.0.
- **Wear.** A fallen bone block lies across each toe: +X at y −1, 1.5 × 1.25 × 1.0 m, tilted 12°; −X at y 10, 1.75 m long, tilted 15°. The −Y, +X corner of the block over segment 3 (tops 17.5) is chipped 0.75 m at 45°.

**`Mesa`, as built:**

- **Lower tier.** The lower body's faces stand at x 6.0 and −5.75 (11.75 m wide, the greybox's 12), y ±20.5, with the same apron (toes at x 9.375 and −9.125). The band runs from 7.0 to 8.25, 0.5 m behind the lower body, from y −18.0 to 17.5. A 1.0 m upper body (8.25 to 9.25) stands 0.5 m behind the band, from y −17.5 to 17.0.
- **Lower rim.** The lower rim is two bone blocks overhanging 0.75 m: one from −17.0 to 11.75, top 10.5; one from 12.75 to 16.5, top 11.25. The sky shows between them past the upper tier's +Y end.
- **Upper tier.** Its body is set back 2.25 m behind the lower rim's front on both faces (x 3.5 and −3.25), from y −11.0 to 10.5, its foot sunk into the long rim block. Its rim is two blocks with tops 15.0 and 15.75.
- **Turned planes.** They sit at the lower body's ends, where they share its corners (about 10 triangles cheaper than mid-face). On +X, two planes at 20.6° run to the +Y end (y 12.5 to 20.5). On −X, three sawtooth planes at 56.3° start at the −Y end (y −20.5 to −17.5): the end a span shows as it comes toward the train.
- **Closed ends.** Each end steps down through both tiers: the upper tier at y −11.0 and 10.5, then the lower rim to the 7.0 m ledge at −17.5 and 17.0 (within the last 6.4 and 6.9 m), then the lower body to the apron at ±20.5.
- **Wear.** A notch bites 1.0 m into the +X face of the taller upper block and 1.0 m down, over its last 1.5 m (y 8.5 to 10.0). A fallen bone block lies across the −X toe at y 2.

**Where the spans depart from B:**

- **The budgets set the detail.** These are measured costs on this kernel, in triangles:
  - A capped skyline segment costs about 24: 18 in its bone block, whose ends carry T-junctions, plus the upper body's strips and step faces.
  - A turned plane or tooth costs about 13 spread along a face, and 8 to 10 in a run.
  - A bare pillar costs 10 to 16; with a bone cap, about 32.
  - A fallen block costs about 16.
  - A two-groove flute patch costs about 20 a face, because its vertices also land in the band's top ring and the cap's underside.
  - Every extra apron piece costs about 8 (a valley and an end face).
- **Flutes are not built** (Canyon detail 6). With the pillars and the wear, the Canyon has 8 triangles left, and one patch a face would take 40. `CANYON_FLUTES` builds them if the budget moves.
- **Pillars have no bone caps.** On each face, one pillar is a buttress ending the plane run, and one stands free on the toe (as the greybox buttress stood clear of its wall).
- **Skyline.** The Canyon has five segments 7 m long (B: about 6 m): the 35 m between the stepped ends. The middle segment is an uncapped saddle, so four bone blocks carry the cap. That saves about 20 triangles and gives the skyline its deepest notch. Each upper body is one plane a face per height.
- **Turned planes and sawtooth come in runs, not spread.** The Canyon has two planes on +X and three on −X; the Mesa the same, at the ends.
- **The ends step twice** (B allows two or three).
- **The apron is one wedge a side.** Its toe stands at 7.875 to 8.125 m (Canyon) and 9.125 to 9.375 m (Mesa), so the slope meets the faces at 2.36 m (B: 2.0 to 2.5). A toe at ±9 on the Canyon's 9.25 m ridge would meet them at about 3.1 m. The Canyon's free pillars and fallen blocks reach x 8.6 to 9.0.
- **The Mesa's rims are two blocks each**, the lower one with its single sky gap past the upper tier's end. Its notch is a bite in the taller block's corner.

**Found while reviewing:**

- **`load` does not see the belt's spans or cacti.** `scenery_belt.gd` duplicates `Canyon`, `Mesa`, `Butte`, and the cactus plants out of their GLB instances. `_in_scenario_glb` looks for a parent whose `scene_file_path` ends in `.glb`, so `load`'s surface count, world-shader check, and belt sway check skip them. Only the instanced tracks are counted, and D's Tests line overstates it. The throwaway run above checked all 84 span copies.
- **Generated LODs (G13).** With the belt frozen and the view down each band to 150 m, LODs on and off differ in 10 and 11 of 230,400 sampled pixels. No span changes shape as it comes in. `horizon_ridge.glb.import` is unchanged.
- **The light in the flat run.**
  - At noon the left-hand faces take the middle step and read salmon, with the cap overhangs' shadow along the top of the upper body. The band reads lavender and the caps white. The right-hand faces read mauve, the sawtooth reads as pale lit slivers, and the −Y ends and pillar sides read salmon.
  - At dusk and dawn the left faces read full orange-red and the right faces dull pink. At dusk, Lane P's roofs lie in the right-hand spans' shadow (F16).
  - Neighbours at any offset read as separate formations with a saddle of apron between. No cut end, seam, or flicker shows in the stills.
- **The greybox Butte has changed colour.** It shares the four materials, so it showed vermilion, bone, and pink blocks until its final landed (batch 5, below).

**Still open:**

- `Butte`: built in batch 5 (below); `Talus.002` and its dot are gone.
- Flutes on the Canyon's upper body, if the budget or another detail moves.
- The headset review, late afternoon captures, and Quest timing. The horizon is 14,256 triangles in 468 belt objects; with the Butte merged to three objects, it will be 292 objects (B; done, below).

### `horizon_ridge`: `Butte` (C step 6, batch 5)

Built on 2026-10-26 by `--part butte` of `dev/build_horizon_ridge_finals_blender.py` (the stub is gone), under the `Butte` child of `horizon_ridge` only, with the Canyon and Mesa's kernel, colour rule, and printed checks. It deletes the greybox's seven objects (`Talus.002`, `TowerA` to `C`, `LipA` to `C`) and builds three: `Butte_Rock`, `Butte_RockDark`, and `Butte_Cap`. No band (B). The span keeps its name and its parked place (Blender (40, 0, 0)). Built and exported by the two commands above.

- **Re-run:** two `--part all` runs print the same counts and geometry hashes for all three spans: Canyon `0fd4b61832b3` and Mesa `c7f13e1195b9` (as in batch 4), Butte `0ff5d3f14872`. A second export writes a byte-identical `horizon_ridge.glb`.
- **Tests:** `--import`, then `load`, `multi`, `ragdoll`, and `gauntlet`: all print `AUTOTEST PASS`. `load`: "1056 scenario surfaces wear world_surface.gdshader (204 sway, 4 self-lit, …)", unchanged (it counts no belt copy).
- **Unwrap:** `GLB horizon_ridge [train_rooftop]: 0 meshes, 0 islands, 0.0 px/m at 256 px (pad 2, 0% covered, 11 tiling meshes untouched); 0 materials copied; image none (flat colour)`.
- **Other GLBs:** `train_coupler`, `train_engine`, `train_car_baggage`, `train_car_business`, and `train_rooftop` are byte-identical before and after (MD5); `train_car_coach` changed by the coach fix only (below).
- **In Godot** (a throwaway flat run): `Scenery` has 354 children (270 tracks and cacti, 20 `Canyon`, 20 `Mesa`, 44 `Butte`). The horizon instance has `Canyon`, `Mesa`, and `Butte` and imports 292, 236, and 141 triangles. All 84 span copies wear world_surface.gdshader, and none sways. With the belt frozen and a 30° view on each far band, LODs on and off differ in 0 of 230,400 sampled pixels (G13).
- **Checks** (printed by the script, and on the saved `.blend`): the formation runs y −23.25 to 19.25 inside the span's ±23.875, and z 0 to 39.0. No zero-area triangles, non-planar faces, smooth faces, three-collinear outline points, faces at z 0 or 0.12, or edges under 0.5 m. Coplanar test: 96 coplanar triangle pairs, none sharing area. The pink teeth's least sunlight is N·L 0.067, at noon. Skyline tops 31, 39, and 20 m. Names unique, no dots. 62% of vertices on the 0.25 m grid; the rest are the lean, the chamfers, and the skirts' mitres and toes.
- **Views:** Blender renders (Workbench, light from the scene's sun): Side from (±85, 0, 4.9) at 50 and 35 mm, end-on from both ends, three-quarters onto the −Y end from both faces and onto the +Y end from −X, a high three-quarter, a close view of the lean, Silhouettes (both faces, both ends), and the 64 px squints. A close render of the coach's fixed steps and truss. Flat Godot captures at noon and dusk: the far band on each side from Lane P's eye toward (±85, 15, −100), straight out each side, and Lane P, two per view 2 s apart; and three 30° views per side 2 s apart, out and ahead. All outside the repo. The headset review is open.

| GLB child | Triangles / budget | Objects | Copies on the belt | In scene |
|---|---|---|---|---|
| `Canyon` | 292 / 300 | 4 | 20 | 5,840 |
| `Mesa` | 236 / 240 | 4 | 20 | 4,720 |
| `Butte` | 141 / 150 | 3 | 44 | 6,204 |
| **Horizon** | | 11 | 84 | **16,764** in 292 belt objects (batch 4: 14,256 in 468; the greybox: 5,376 in 448) |

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Butte_Rock` | `M_Rock` | 46 | The +X and −Y faces of every block, the three 45° chamfers, the skirts' +X and −Y slopes and their +X, −Y hips |
| `Butte_RockDark` | `M_RockDark` | 44 | The −X and +Y faces of every block, the three 56.3° teeth, the skirts' −X and +Y slopes and the hips under the teeth |
| `Butte_Cap` | `M_Cap` | 51 | The three cap blocks: four sides and the underside ring each |

**`Butte`, as built** (the span's own Blender frame, as above):

- **Pillars.** Each is two chamfered blocks under a bone cap block that overhangs the top block 0.75 m on all four sides. Each block's foot is sunk 0.25 m into the one below, and the top block runs 0.25 m into its cap.
  - A, centred at y −17.0: 6.5 × 6.5 m to 17.0, stepping in 0.75 m to 5.0 × 5.0; cap 1.75 m tall, its top at 31.0.
  - B, at x 0.25, y −5.0: 5.5 × 5.0 m to 23.0, stepping in 0.75 m to 4.0 × 3.5; cap 2.0 m tall, top 39.0.
  - C, at x −0.25, y 12.0: 8.0 × 8.5 m to 12.0, stepping in 0.75 m across and 1.0 m along to 6.5 × 6.5; cap 1.5 m tall, top 20.0.
- **Chamfers.** One vertical edge a block, always on the −Y end (the end the sun reaches and the one a span shows as it comes in), alternating sides up each pillar. On the +X corner a 45° cut, 1.0 × 1.0 m. On the −X corner the cut is turned 56.3° toward −Y (1.5 m across, 1.0 m along): a lit tooth on the pink face.
- **Skirts.** A 35° wedge along each edge of each pillar's foot, mitred at the corners (the Canyon's `apron()`, five wedges a pillar), its toe 3.0 m out and 2.1 m tall at the foot. Three separate skirts; the first two toes stand 0.25 m apart.
- **Spacing.** Centres 12.0 and 17.0 m apart inside the span, 19.0 m across the belt's 48 m pitch. The formation stops 0.625 m and 4.625 m short of the span's ends, so it closes at both ends on the skirts' own slopes.
- **Wear.** Pillar A's top block and its cap lean 3° toward −Y about the block's +Y foot: its top moves 0.65 m, and its −Y face looks slightly down.
- **Colour** by side first, as the Canyon and Mesa (B's rules).

**Where the Butte departs from B:**

- **Unseen tops deleted** (rule 27). Every up-facing face over 6.5 m goes: the pillars' two ledges and the caps' tops, nine faces, all 12 m or higher. No eye in the game rises above about 6.1 m (the death cam's highest orbit; a VR player on the cab roof stands about 5.2 m), and the spans stand 70 to 100 m out, so none of them is ever seen. Closed, the span measured 219 triangles with three blocks on the tallest pillar and about 185 with two, against the 150 budget, so the budget goes on the sides that are seen. The pillars are open from above: Blender's high view shows the openings. The shader draws both sides (`cull_disabled`), so the walls still cast whole shadows. The Canyon and Mesa keep their tops.
- **Two blocks a pillar**, not three on the tallest: a third block cost 19 triangles.
- **Three separate skirts**, not one continuous talus as the greybox had: merging the first two cost 6 triangles, and apart they read as three formations standing in a row.
- **The pink-side chamfer turns 56.3°**, not 45°: at 45° it would take no noon sun at all (N·L 0).

**Found while reviewing:**

- **From the train the far band shows above and between the mid band.** The mid spans' walls stand 12 to 20 m tall at 28 to 40 m and cover the buttes' feet nearly everywhere; the pillars' upper blocks and caps show over them and through their saddles and closed ends. The skirts show only through a gap.
- **Noon:** the left-hand posts read salmon with white caps, the right-hand ones pale mauve with grey caps, close to the sky through 34 to 45% fog. The −Y faces and the lit teeth read as lighter strips as spans come in.
- **Dusk:** both sides read orange through the orange fog; at that range the right-hand pink hardly separates from the left's vermilion, as it does on the mid band at the same time.
- No flicker, pop, cut end, or seam in the stills.

### Coach fix (batch 5)

Batch 3 found two coplanar spots in the approved `train_car_coach` and fixed them in the baggage and business cars only. Batch 5 applied the same two fixes to the coach's saved geometry by a throwaway headless script outside the repo (batch 1's coach script was not re-run):

- **Step treads:** the 16 tread end faces (at u ±5.29 and ±5.91, in the hangers' planes) are deleted from `Coach_Plank`, as on the two cars. The hangers' faces cover the ends.
- **Queen posts:** the eight posts' outer faces move from x ±1.34 to ±1.35 (16 vertices of `Coach_Iron`), so each post stands 1 cm proud of the truss rod's outer plane.
- Nothing else changed: colours, names, proxies, and `Coach_Car`, `Coach_Trim`, `Coach_Glass` are as before. 1,588 to 1,556 triangles (−32, all in `Coach_Plank`, 158 to 126); −128 in the scene.
- Coplanar triangle pairs sharing area across the coach's five objects: 74 before, 0 after.
- **Unwrap** (`-- --glb train_car_coach --relayout`): `GLB train_car_coach [train_rooftop]: 5 meshes, 545 islands, 12.5 px/m at 256 px (pad 1, 60% covered, 0 tiling meshes untouched); 0 materials copied; image none (flat colour)`. No TINY share, no UV overlap between any two triangles of different faces, nothing outside 0 to 1. The walk top is one 24-vertex n-gon and one island. UV islands counted in the `.blend`: 553 (`Coach_Plank` 52, was 68).
- In Godot a ray down at all seven markers still hits `Coach_Roof` at y 3.20.

### Whole scene

The Train Rooftop's final untextured meshes are complete: the train (five GLBs plus the guard walls) and the horizon's three spans. Main Street's belt pieces and terrain are unchanged.

| GLB | Triangles / budget | Objects | Copies | In scene |
|---|---|---|---|---|
| `train_car_coach` | 1,556 / 1,600 | 5 | 4 | 6,224 |
| `train_coupler` | 100 / 100 | 1 | 6 | 600 |
| `train_engine` | 2,294 / 3,500 | 8 | 1 | 2,294 |
| `train_car_baggage` | 1,156 / 1,300 | 5 | 1 | 1,156 |
| `train_car_business` | 1,602 / 1,800 | 7 | 1 | 1,602 |
| `train_rooftop` | 0 / 0 | 0 | 1 | 0 |
| **Train** | | | | **11,876** in 46 objects (greybox 6,908 in 371; B planned about 13,600) |
| `horizon_ridge` › `Canyon` | 292 / 300 | 4 | 20 | 5,840 |
| `horizon_ridge` › `Mesa` | 236 / 240 | 4 | 20 | 4,720 |
| `horizon_ridge` › `Butte` | 141 / 150 | 3 | 44 | 6,204 |
| **Horizon belt** | | | | **16,764** in 292 objects (greybox 5,376 in 448; B planned about 17,400) |
| Main Street's `env_rail_track_8m` | 98 | 3 | 90 | 8,820 in 270 |
| Main Street's cactus clones | about 51 a plant | | 180 | 9,219 in 293 |
| Main Street's `env_terrain` | 12 | 1 | 1 | 12 in 1 |
| **Shared** | | | | **18,051** in 564 objects |
| **Scene** | | | | **46,691** in 902 objects (decided: about 49,600, F17; greybox about 30,500 in about 1,380) |

- Counted in a throwaway flat-scene run: every visible mesh instance, index count over three. Collision proxies and the guard walls are not counted.
- 46,691 triangles is 94% of the decided budget and about 3% of Meta's 1.5 million a frame for Quest 3. Half the belt is behind you or outside the view at any moment.
- Draw calls before culling: 902, one surface per object (B planned about 900): the train 46, the horizon 292, the shared belt pieces 564. B estimates about 450 in the view from a spawn (not measured), against Meta's guideline of under 200. Going lower is code, decided after Quest timing (F18).
- Self-lit: the engine's headlight lens and the business car's four marker lenses (`M_LampGlass`), unlit and casting no shadow.
- Tests: `--import`, then `--autotest=load`, `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`. A flat run counts 354 children under `Scenery` and finds the walk at y 3.20 under all seven markers.

**Still open:**

- **The user's review**, then the in-context review in a headset: D items 10 to 17, walking the roofs from `GuardEndRear` to the cab across every gap, leaning out at the guard walls and over `GuardEndRear` (the observation platform), standing on the cab roof, and watching spans arrive on both sides.
- **Quest timing:** 902 objects before culling (F18 decides a belt fix in code after it), and the shadow cascades at dawn, when the right-hand spans' shadows cross the train.
- **Noon washout:** the raw-wood walks, the tender's walk and cordwood, and the business car's bone colonnade draw near white at noon, close to the bone trim.
- **F16, the passing shadows:** seen at dusk in flat runs (Lane P's roofs lie in the right-hand spans' shadow), not yet judged by the user (D14).
- **The Canyon's flutes are not built** (detail 6; the budget), and its pillars and the Butte's are as built: the Canyon's uncapped, the Butte's open at the top above every eye.
- **The far band at dusk:** the right-hand pink hardly separates from the left's vermilion through the orange fog.
- **Captures:** dawn and late afternoon captures for the engine, the end cars, and the Butte (noon and dusk only), and three captures 2 s apart for every view (some views have one or two).
- **Painting density** (G2): 12.5 px/m on the coach, 10.5 on the engine, 13.3 and 11.9 on the end cars.
- **`load` coverage:** it does not check the belt's cloned spans and cacti (D, Tests); a change to the test is the user's call.
- **The engine smoke** is its own Roadmap item (F13).

## References

**Repo**

- `.claude/skills/gunslinger-taste/references/board.md`: items #01, #03, #06, #07, #10, #12, #14, #18, #20, #22, #30, and pattern 7 (print texture).
- `.claude/skills/gunslinger-taste/references/steel-ball-run.md`: history bent one notch; colour chosen for the image; stages with personalities.
- `docs/design/characters/`: `sheriff.md` (rung 4, "Deputy on the 3:10"; the company's agent; the conductor's punch and the heart of daylight in his hat), `half-head.md` (the railroad; the checker), `ghost.md`, `drunk.md`, `player.md` (the black coat).
- `docs/design/scenarios/main_street.md` (global rules, palette, backdrop method, build lessons, the belt's pieces), `canyon.md` (rock vocabulary, palette, backdrop numbers for the sky band, build method), `saloon.md` (brass, lamp glass, the glow code, build lessons).
- `dev/build_train_rooftop_blender.py`, `dev/unwrap_per_glb_blender.py`, `dev/unwrap_scenery_blender.py`, `dev/scenery_uv.py`, `dev/blender_kit.py`, `dev/autotest.gd` (`_spawn_floors_ok`, `_multi_arena_ok`, `_multi_rooftop_ok`, `_vr_rig_ok`, the belt count in `load`), `scenarios/train_rooftop/train_rooftop.tscn`, `train_rooftop.tres`, `scenery_belt.gd`, `scenarios/scenario_base.gd`, `scenarios/time_of_day.gd`, `ai/duelist_ai.gd`, `autoload/death_cam.gd`, `autoload/game_manager.gd`, `gauntlet/encounters/e4_sheriff_rooftop.tres`, `assets/shaders/world_surface_import.gd`, `docs/SHADERS.md`, `docs/TEXTURING.md`, `docs/FEATURES.md`, `Roadmap.md`.

**Railroads**

- [Jupiter (locomotive)](https://en.wikipedia.org/wiki/Jupiter_(locomotive)), Wikipedia: a 4-4-0 with 5 ft 4 in drivers; the *Sacramento Bee*, March 1869: "blue, crimson, and gold"; the 1994 repaint follows it; wood-burning until 1893.
- [4-4-0](https://en.wikipedia.org/wiki/4-4-0), Wikipedia: about 85% of locomotives in the United States estimated as 4-4-0s around 1872; cowcatchers, bells, and headlights gave the type its look.
- [Russia iron](https://en.wikipedia.org/wiki/Russia_iron), Wikipedia: a glossy black, sometimes greenish sheet used to clad American locomotive boilers, suited to the brightly painted locomotives of the era; demand fell by 1900.
- [Train lights](https://en.wikipedia.org/wiki/Train_lights), Wikipedia: the box headlight of sheet metal with a reflector, common in the United States by 1850.
- [Running board](https://en.wikipedia.org/wiki/Running_board), Wikipedia: walkways on top of boxcars, used by brakemen to travel from car to car to apply hand brakes.
- [Vestibuled train](https://en.wikipedia.org/wiki/Vestibuled_train), Wikipedia: open end platforms until the first vestibuled train on 15 June 1887.
- [Clerestory](https://en.wikipedia.org/wiki/Clerestory), Wikipedia: clerestory roofs on passenger cars from the 1860s to the 1930s, for daylight and ventilation.
- [Link-and-pin coupler](https://en.wikipedia.org/wiki/Link-and-pin_coupler), Wikipedia: coupling by hand between the cars; brakemen lost fingers and hands; the Janney coupler (1873) and the Safety Appliance Act (1893).
- [The Purpose of Truss Rods](https://forum.trains.com/t/the-purpose-of-truss-rods/264785), Trains.com forum: wooden cars sagged between their trucks; truss rods as an inverted queen-post truss with a turnbuckle at mid-car. Anecdotal; read through search excerpts only.
- [3:10 to Yuma (1957 film)](https://en.wikipedia.org/wiki/3:10_to_Yuma_(1957_film)), Wikipedia: from Elmore Leonard's 1953 story "Three-Ten to Yuma"; the 3:10 train west to Yuma, Arizona. The source of the rung's copy.

**Panoramas**

- [Trans-Siberian Railway Panorama](https://en.wikipedia.org/wiki/Trans-Siberian_Railway_Panorama), Wikipedia: Paris, 1900, for the Compagnie Internationale des Wagons-Lits; three 70-foot railway cars; sand and rocks on a belt at 1,000 feet a minute, shrubs at 400, distant scenery at 130, mountains, forests, and cities at 16.
- [Hale's Tours, The Rocky Mountain Holdup, The World in Motion, and Humanovo](https://lost-wonderland.com/hales-tours-the-rocky-mountain-holdup-the-world-in-motion-and-humanovo/), Lost Wonderland: George C. Hale's stationary "Pullman railroad car" whose front wall was a film screen, some versions made to shake with smoke and wind blown in; *The Great Rocky Mountain Holdup*, filmed for it. Its 1904 debut at St. Louis comes from [Picturegoing](https://picturegoing.com/?p=1712), read through a search excerpt only.

**PSX era and hardware** (as cited in `main_street.md` and `canyon.md`)

- [Spyro the Dragon](https://www.hardcoregaming101.net/spyro-the-dragon/), Hardcore Gaming 101: every level has a flat-shaded far version.
- [Making Crash Bandicoot, part 3](https://all-things-andy-gavin.com/2011/02/04/making-crash-bandicoot-part-3/), Andy Gavin: a budget set by the polygons on screen at once.
- [Draw distance](https://en.wikipedia.org/wiki/Draw_distance), Wikipedia: distance fog hides where the world stops.
- [Device optimization comparison](https://developers.meta.com/horizon/resources/device-optimization-comparison/), Meta: Quest 3 at under 200 draw calls and 1.5 million triangles per frame. [Meta Quest compare](https://www.meta.com/ca/quest/compare/): 25 pixels per degree.
