# Train Rooftop: design sheet

| | |
|---|---|
| Status | `planned`. Decided 2026-10-23 (section F); nothing is built. The engine smoke is a separate Roadmap item (F13) |
| Kind | Scenario design sheet: greybox to final, untextured, UV-unwrapped meshes |
| In code | Greybox only. `dev/build_train_rooftop_blender.py` writes `train_rooftop.glb` (the consist: 371 visible meshes, 6,908 triangles, 30 proxies) and `horizon_ridge.glb` (three spans, 14 meshes, 168 triangles) beside `train_rooftop.blend` in `assets/models/scenarios/train_rooftop/`. `scenarios/train_rooftop/train_rooftop.tscn` instances the consist as `Train`, Main Street's `env_terrain.glb` as `Terrain`, and `Scenery` (`scenery_belt.gd`), which loops 90 Main Street tracks, 180 cactus clones, and 84 horizon spans past the stationary train |
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
- **Death cam.** It orbits the corpse's chest at 3.2 m (1.4 to 7 m), 16° up, with no collision, so it swings up to about 3 m outside the car sides at roof height plus 1 m. The duel cars' upper sides, eaves, and windows near both spawns are seen there from 1.5 to 3 m.
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

1. The coach's deck and walk, with two express hatches 1.0 × 1.0 m, 6 cm proud with bone rims, one each side of the walk.
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
| Role | `CarRearB`, z 27.0 to 39.0: the end of the train and the company agent's car (`sheriff.md`: on the train the company's agent outranks the Sheriff). From `EnemySpawn` its roof is behind the player's thighs and hips (−2.6° to −2.0°), and its rear edge is the line at his hips. `GuardEndRear` stands just past it; a player there looks down on the observation platform |
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
- **Bands** over the span's foot, as on the Canyon's walls: apron of 35° wedges to 2.0 to 2.5 m; lower body; one violet slab from 7.0 to 8.25 m standing 0.3 m or more proud or set back (never flush); upper body; a bone cap 1.25 to 2.0 m tall overhanging 0.5 to 0.8 m, broken into blocks with sky between them.
- **Colour by face** (rule 17 by this sun): a face the sun ever reaches (its normal leans to +x or +z) is vermilion; a face it never reaches (to −x or −z) is pink. So the left-hand side sees vermilion walls and the right-hand side pink ones, as the Canyon's player sees them.
- **Turned planes.** On the vermilion face, main planes turned 15 to 45° toward +z take the full step at dawn, late afternoon, and dusk. On the pink face, a sawtooth of planes turned 50 to 60° toward +z takes the middle step at every hour, and those planes face you as a span comes toward you: lit teeth on the shade side.
- **Both sides finished.** Every part has a counterpart on the other face, placed differently. Nothing is one-sided.
- **Closed ends** (F15): within the last 6 to 8 m at each end the span steps down to its apron in two or three steps, so any neighbour at any offset reads as a separate formation with a saddle between. Keep the 47.75 m length and the 0.125 m clearance at each end.
- **No coplanar faces.** Build each span as one exact self-union per material, as the Canyon's cliffs were built, then dissolve coplanar faces. Pieces of different materials step at least 0.3 m. Span bases sit at y 0, 12 cm under the terrain's top; no face lies at 0.12.
- **Objects and names.** One object per material per span: `Canyon_Rock`, `Canyon_RockDark`, `Canyon_CapDark`, `Canyon_Cap`, and so on, under roots named exactly `Canyon`, `Mesa`, `Butte`. No dots. No collision.
- **UV:** 8 m tiling UVs on every object, written by `scenery_uv.unwrap_object(obj, scenery_uv.TILING)`; each object at zero rotation with its origin at the span's origin, so the tiles run level across pieces (Canyon G2, G3). Nothing to paint in the per-GLB image.

### `Canyon` (span, ×20 on the belt)

| | |
|---|---|
| Role | The mid band's even slots, x ±28 to ±40 at 7 m/s: the tallest and nearest walls, 15 to 21% fogged at their nearest. Its right-hand copies throw the passing shadows at dawn and dusk |
| Size | Greybox: talus 18 × 47.75 × 2.0 m, wall 8 × 47.70 m to 17.7, buttress 1.8 × 4.5 m to 10.4 on the +x face, cap 6 × 12 m to 19.7. Final: a ridge 8 to 10 m thick on a talus skirt to ±9 m, skyline tops 14 to 19.7 m in segments about 6 m long |
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
| Edge | Godot | Eye at (±1.3, 4.9, 7), looking at (±4, 1.5, 7) | The fascia, eave, letterboard, windows, trucks, and truss on both sides |
| Death cam | Godot | Eye at (±3.08, 4.28, −10), looking at (0, 3.4, −10) | The duel car's upper side at the orbit's range |
| Cab | Godot | Eye at (0, 4.9, −48.7), looking at (0, 3.0, −55) | Boiler top, domes, bell, stack, headlight's back, pilot |
| Rear | Godot | Eye at (0, 4.9, 38.8) pitched 55° down toward +z | The observation platform, railing, lamps |
| Pass | Godot | From Lane P's eye, aimed at (±35, 8, −40) | Spans arriving on both sides, their ends, the far band's repeat |
| Top | Blender, the asset's `.blend` | Straight down from 1.7 m over the walk's centre | Every car (the roof as the player sees it) |
| Side | Blender | From +x, 10 m out, 2.0 m up, aimed at the asset's centre, 50 mm lens; spans from x 34 (mid) or 85 (far), 4.9 m up | Every asset (its duel-lane view in Blender) |
| Three-quarter | Blender | 45° between +x and −z (the front), 15 m out, 4.9 m up, 50 mm lens | Every asset |
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
16. Death cam and Edge: do the car side, letterboard, and windows read at 1.5 m without shimmer when you move your head?
17. In a headset: does crossing an open gap on the invisible walk read as a stride over a joint rather than a fall? Does the walk feel 3.2 m off the ground when you lean out?

### Asset checks

| Asset | Check |
|---|---|
| `train_car_coach` | Is the walk at 3.20 under all seven markers? Does the sprung board sit in a free band on both duel cars? Does the death cam see blue, bone, and ink, not black? |
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

`load` only checks that the belt built 80 pieces, which the tracks alone pass. Count them: 90 tracks, 180 cacti, 84 spans, 354 in all. Headless runs do not compile shaders. The look needs a flat run, then a headset.

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
