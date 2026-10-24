# Canyon at Dusk: design sheet

| | |
|---|---|
| Status | `done`. Decided 2026-10-23 (section F); the user reviewed the whole scene on 2026-10-24 and decided F21 to F23, built the same day (batch 5). All five assets are built, final and untextured (H): the hero cliffs, the cover rocks and the floor (2026-10-23), and the rim and the horizon (2026-10-24). The backdrop butte stays 150 m out, not about 80 (F2, F21); the rim's collision follows its faces (F22); the butte's outline is broken beyond the field (F23). Still to do: the in-context review in a headset (D) and Quest timing (`RELEASE_TODOS.md`) |
| Kind | Scenario design sheet: greybox to final, untextured, UV-unwrapped meshes |
| In code | All five assets are final: `dev/build_canyon_finals_blender.py -- --part cliffs`, `--part cover`, `--part floor`, `--part rim`, and `--part horizon` rebuild the `CanyonCliffs`, `CanyonCover`, `CanyonFloor`, `CanyonRim`, and `CanyonHorizon` groups in `canyon.blend` (H). The greybox came from `dev/build_canyon_blender.py`, which must not be re-run. `scenarios/canyon/canyon.tscn` instances `canyon.glb` as `Canyon` beside the spawn markers, the `Sun`, and the environment. The GLB now holds 41 visible meshes (15,486 triangles: 4 cliff objects, 2 cover objects, 1 floor, 4 rim objects, 5 horizon rock and sand objects, 25 plant meshes) and 165 collision proxies: the greybox's 85, four of them (the rim's face proxies) moved, and 80 rim boxes added (F22). The scene facts below describe the greybox, before H |
| Prompt | [`prompts/canyon.md`](prompts/canyon.md) |
| Inherits | [`main_street.md`](main_street.md): global rules 1 to 28, the shared palette values (bone, the two grounds, the plants), the backdrop method, and the build lessons, plus the two build lessons in [`saloon.md`](saloon.md). The Canyon's exceptions are in A, each with its reason |

The deliverable is clean, final, untextured meshes with sensible UVs and flat Base Color materials. You texture by hand later, so nothing here plans texture art.

Positions are Blender's: Z-up, metres, −Y the player end, +Y the enemy end, −X the west cliff, +X the east cliff, as the build script names them. The compass words are labels; the sun does not follow them. Godot (x, y, z) is Blender (x, z, −y).

## Scene facts the design depends on

Read from `canyon.tscn`, `canyon.tres`, the build script, the GLB, `scenarios/time_of_day.gd`, `scenarios/scenario_base.gd`, `dev/autotest.gd`, and `ai/duelist_ai.gd`. Shadows and sightlines were ray-cast against the greybox's boxes.

- **Lane.** `PlayerSpawn` (0, −11) faces `EnemySpawn` (0, 11), so `duel_distance` is 22. Every marker stands on the floor's top at z 0. `--autotest=ragdoll` fails if the floor under a marker sits more than 1 cm above or 5 cm below it, and `--autotest=multi` sweeps a capsule 0.3 m in radius from 0.1 to 1.7 m at each multi marker. The build script refuses any proxy made through `col()` inside the shot band (|x| < 1.6, |y| < 12, z 0.9 to 1.9) or on a spawn pad (|x| < 1.5, |y| 9.5 to 12.5, z 0.05 to 2.2). Every Canyon proxy goes through `col()`.
- **Who fights here.** Gauntlet rung 5, "The Ghost of the canyon": the Ghost at 1× health, `STRAFE` at speed 1.6, swinging ±1.5 m along X (`STRAFE_RANGE`). Free duels with one to three NPCs of any archetype, and lobbies of two to four duelists, use every marker: `EnemySpawns2/A` (−3.3, 8.8), `/B` (4.6, 5.2); `EnemySpawns3/A` (−4.0, −2.5), `/B` (0, 11), `/C` (4.3, −3.0).
- **Mass.** A floor 32 × 29.2 m on top of a butte whose sides drop 24 m to a 6 km plain. On it, two cliffs of eight overlapping segments each frame a corridor 11.8 to 15.4 m wide between the talus toes. Six cover rocks stand 2.6 to 5.3 m off the centre line. Each asset sheet in B gives the sizes.
- **Sun.** The authored `Sun` points 15° off the lane toward +X, from the player end, 15° up. `TimeOfDay` keeps that yaw and moves only the elevation: dawn 8°, noon 70°, late afternoon 32°, dusk 12°. Every load rolls its time at random (`GameManager._instance_scenario`), so the arena plays at every hour, not only at dusk. With `band_low` 0.65 the light has three steps. Vertical faces, by the direction they face (0° faces the player end, 90° faces +X, the west cliff's inner face):

| Face | Dawn | Noon | Late afternoon | Dusk |
|---|---|---|---|---|
| Vertical, facing 0° to 60° (toward the player end) | full | middle | full | full |
| Vertical, facing 90° (+X: the west cliff's inner face) | middle | middle | middle | middle |
| Vertical, facing 120° to 270° (toward the enemy end, and −X: the east cliff's inner face) | none | none | none | none |
| Vertical, facing 300° (−X turned 30° toward the player end) | middle | middle | middle | middle |
| Vertical, facing 330° | full | middle | full | full |
| Up: floor, ledge tops, caps | middle | full | full | middle |
| Talus at 35°, facing +X | middle | full | full | middle |
| Talus at 35°, facing −X | none | full | middle | middle |

  - The east cliff's inner face never takes direct sun, at any hour. It reads by ambient light alone, about a sixth of its value in full sun.
  - Everything that faces the enemy end never takes sun either. So the canyon is front-lit for the player and backlit for whoever stands at `EnemySpawn`.
- **Shadows.** The lane at chest height, and each spawn's mark, stay in sun at all four times: the sun comes down the canyon through its open south end.
  - At dawn and dusk the east cliff's shadow covers the floor's east half from y −4 northward. Its edge runs along the lane's east edge and crosses into the lane near the enemy end.
  - At dawn `EastTooth1`'s shadow, and at dusk `EastWall0`'s, covers the enemy's east strafe beyond about x 0.7 at y 11, feet to head. The mark itself stays lit.
  - `EnemySpawns2/B` stands in `EastWall1`'s shadow at dawn, late afternoon, and dusk. The rock behind it is in shadow at every hour.
  - The scenario's own line is "Long shadows and long shots between the canyon walls" (`canyon.tres`).
- **Fog and sky.** Depth fog: begin 80 m, end 400 m, curve 1.4, density 1.0, aerial perspective 0.9, sky affect 0.85 (the greybox had begin 60, end 220, density 0.012; F1). `TimeOfDay` copies the sky's `ground_horizon` into the fog colour and sets the sun-scatter. It leaves the distances, density, and curves on the scene, and `load` fails if a time change moves them. The sky is `sky_western.gdshader` with the Canyon's `ground_curve` 0.12; its cloud deck fades in from 1.7° above the horizon. Shadows reach 360 m and start fading at 35%. F1 raised the density to 1.0; the user then found begin 60 and end 220 at that density too strong (the far mesas washed out) and moved them to 80 and 400 m. The fog now takes about 0.2% at 100 m, 5% at 150 m, 13% at 180 m, 28% at 220 m, 43% at 250 m, and all of it from about 390 m, where the plain behind the enemy lies.
- **What you can see.** From either spawn the cliffs close the view to a slot about 26 to 29° wide (from `PlayerSpawn`: 16.5° west to 12.4° east of the lane). The plain is 24 m down: a spawn sees it only beyond about 390 m, mid-lane only beyond about 220 m. The cliffs hide every mesa from the lane except Mesa5 and part of Mesa2 in the north opening, and no mesa shows from `EnemySpawn`. The rim's faces are hidden under the floor's 8 cm lip; only a VR player leaning over a rim wall sees them.
- **Sightlines.** What stands behind each marker, from the eye 1.7 m over the opposite spawn (rays against the greybox):

| Marker | Position | Behind the duelist | Who stands there |
|---|---|---|---|
| `EnemySpawn`, `EnemySpawns3/B` | (0, 11) | The floor up to its far edge, which crosses the duelist's shins at 0.24 m; from the shins to the chest, the plain 400 m to 3 km away; from the chest to the eye line, the sky's ground band past the plain's edge; at the head and hat, sky. Strafing 1.5 m west: Mesa5, 212 m away, from the knee to the head, its top at the hat brim. Strafing east: plain and sky | Rung 5 the Ghost, every 1v1, free duels, lobbies |
| `EnemySpawns2/A` | (−3.3, 8.8) | The floor at the shins, then Mesa5 at 214 m behind the chest and head | Two-NPC fights, three-player lobbies |
| `EnemySpawns2/B` | (4.6, 5.2) | `EastTalus6` and `EastTooth7`, 2 to 4 m behind, in shadow at every hour | Two-NPC fights, three-player lobbies |
| `EnemySpawns3/A` | (−4.0, −2.5) | `WestTalus4` and `WestWall4`, 0.7 to 1.4 m behind | Three-NPC fights |
| `EnemySpawns3/C` | (4.3, −3.0) | `EastTooth4`'s south face, 7 m behind | Three-NPC fights |
| `PlayerSpawn`, seen from `EnemySpawn` | (0, −11) | The plain and sky through the south opening. At dawn and dusk the sun hangs 15° east of the line, 8 to 12° up, inside the opening | The player; the other human in a lobby |

- **Free roaming.** Inside the invisible rim walls: the floor between the talus toes and the strips at both ends. The talus boxes, 1.6 to 2.3 m tall, stop every rig, and VR stick locomotion never climbs. A VR player can lean over a rim wall.
- **No outline on scenery** (inherited). Only duelists and held objects carry the ink line (#120D0A). Past 14 m the line stops widening, so at 22 m it is about 3.6 px on a Quest 3.
- **Wind.** `gust_strength` 1.0. Scrub sways; gusts carry dust across the lane from a side.

### The brief's facts, checked

1. **Axes, spawns, floor top:** correct. Z-up, metric, `PlayerSpawn` at y −11, `EnemySpawn` at y 11, the floor's top at z 0.
2. **"Shot lane ... chest-to-head height":** partly wrong. The band is z 0.9 to 1.9 m, hip to head; the hat, to about 2.3 m, is outside it. The check covers collision proxies only: visible meshes are never tested.
3. **"Pad around each spawn":** correct. 3 × 3 m, from 0.05 to 2.2 m.
4. **Stepped cliff segments, the mesa ending past each spawn, the invisible rim:** correct. The floor ends 3.6 m past each spawn, and four invisible walls 2.1 m tall stand 0.2 to 0.7 m inside its edges.
5. **"Fog distances and sky come from TimeOfDay":** wrong. `TimeOfDay` recolours the sky and the fog, and moves the sun's elevation. The fog's distances, mode, density, and curves, and the sky's curves, stay on `canyon.tscn` on purpose.
6. **"The 6 km plain dissolves into fog":** the plain is 6 km across, but it cannot dissolve. In depth mode `fog_density` is the fog's maximum opacity (Godot's Environment reference), and the Compatibility shader multiplies the depth fog by it, so this fog never passes 1.2%. The plain and the mesas draw almost unfogged, and the plain's 3 km edge should draw a line about 0.5° under the horizon, behind the enemy's chest from `PlayerSpawn`. `ARCHITECTURE.md` and `FEATURES.md` describe a fog opaque by 220 m. Not yet seen in a flat run: `RELEASE_TODOS.md` still asks for that check. Decided: raise it to 1.0 (F1).
7. **Dawn, noon, late afternoon, dusk:** correct, and every load picks its time at random, so "at Dusk" is only the authored look.
8. **"docs/TEXTURING.md lists the current triangle counts per map":** not for the Canyon. Its only triangle column counts objects the paused trim-sheet pass unwrapped, and the Canyon row says "unchanged". The counts in B are measured from the GLB.
9. **The asset list:** correct, and the rim also holds eight lip stones with proxies; the cliffs hold the teeth, rubble, caps, and two buried backs.

### Found in the greybox

None of these is in the brief. Where one needs a decision, F asks it.

1. The fog (fact 6). With it, the plain's dark band and its far edge sit behind the enemy from the shins to the chest. F1.
2. The greybox gives the darker rock (`M_RockDark`) to the east cliff, whose inner face never takes sun, and the lighter to the west. That is the opposite of rule 17. F3.
3. Mesa5 stands behind the Ghost's west strafe and the two-NPC west marker, its top at hat height. F2, F9.
4. Draw calls: 393 visible meshes, each drawn once and again into each shadow cascade it touches. Meta's Quest 3 guideline is under 200 per frame.
5. Colours: every rock and ground value is a tan between #B3866F and #DDBF9E, the dust-brown the taste skill throws out. `M_Sand` and `M_SandFar` are near-copies of Main Street's two grounds, and `horizon_ridge.glb`'s `M_Rock` and `M_RockDark` differ from the Canyon's while its `M_Cap` matches. Roughness runs 0.92 to 0.98 against rule 23's 0.9.
6. The plants stand 67 to 300 m out on the plain, 24 m under the floor, so only a player at a rim sees them. About half are beyond 220 m.
7. Every wall box runs 9 m deep, and several stand past the butte's side faces over the drop (`WestWall7` to x −18.8, the face at −18.3). Nobody sees those outer faces.
8. Names: no dots, no duplicates; the build script asserts it.

## A. Art direction

The canyon is a layer cake turned into a corridor: horizontal strata step in and out along both walls under a hard bone caprock, the way a resistant cap protects the softer rock under the mesas and buttes of Monument Valley and the Painted Desert (USGS; NPS Petrified Forest). It is built from big flat planes and raw angles, like Ed Mell's "angular, faceted" mesas (Masterworks), and snapped to a grid, as Tomb Raider's levels were laid out "on a grid of square blocks" after Ultima Underworld showed its makers that a grid need not feel like one (Life and Times). Wear is weathering in silhouette, never paint: rock falls rather than sags, so each 4.4 m segment carries one accent (a fallen block, a chipped cap, an undercut, a joint open to the sky), and the fallen rock gathers at each wall's foot as talus, which lies at its angle of repose, the steepest slope a pile can hold (Wikipedia, Scree; Angle of repose). Proportion follows distance: nothing on the cliffs touches a body except the talus, 1.6 to 2.3 m and too tall to climb, and the cover rocks keep the greybox's 1.15 to 1.65 m, so the walls work at 25 cm features and 0.25 to 0.8 m chamfers, as thick and blunt as board #12's padded, oversized workwear. The palette is history bent one notch: Clarence Dutton named the Grand Staircase's steps the Pink, Grey, White, Vermilion, and Chocolate Cliffs in the 1870s (NPS Bryce Canyon), and here the Vermilion Cliffs face the Pink across one slot, because the fixed sun gives the west wall the middle light step at every hour and never reaches the east wall (rule 17); one violet band runs through both, the Painted Desert's "grey, blue, purple, and green mudstones" pushed loud (NPS), under the bone cap, colour chosen for one image the way Araki chooses it (`steel-ball-run.md`): the Ghost's aquamarine and bone against hot red and violet, board #15's teal gun on orange and #25's complementary pair. Light does the drawing: the sun comes down the canyon behind the player, long shadows fill the east half of the floor at dawn and dusk, ledges draw lit lines across the shade wall, and shallow vertical flutes split the upper walls into two light steps, the "striations of the canyon wall" over the two small figures in O'Sullivan's 1873 survey photograph (board #07; Art Institute of Chicago). The far view is the printed West, like the 1892 chromolithograph the Santa Fe made of Moran's Grand Canyon and used in its advertising for over a decade (Gilcrease; board pattern 7): low horizons and simplified rock in bold colour (Maynard Dixon, BYU Museum of Art), flat two-value mesas fading into the sky colour, the fog doing what distance fog has always done in games, hiding where the world stops (Wikipedia, Draw distance).

**What this place feels like:** a red slot on top of a butte, company ground where the war ended in court and nobody told the Ghost: hot rock on your left, bleached rock on your right, and your opponent standing where the rock ends.

### Exceptions to the global rules

Rule numbers are Main Street's. Every rule not listed holds as written. PSX vertex snap and affine warp play no part.

| Rule | Main Street | Canyon | Why |
|---|---|---|---|
| 2, 3 | Human-contact sizes true; thin members fattened | Only the cover rocks and the talus touch a body; their heights are their proxies' | No doors, steps, or rails |
| 6 | Smallest modeled feature 10 cm; gaps 5 to 8 cm | 25 cm on the cliffs, rim, and mesas; 10 cm on the cover rocks and the floor. Gaps 0.25 to 0.6 m, only where sky or floor shows through | The walls are seen from 4 to 25 m: 25 cm at 8 m is 1.8°, about 45 px |
| 7, 20 | Boards 25 cm; raw wood silver | No wood: there is no lore mark (F12) | |
| 8 | No bevels on wood; stone corners one 8 to 10 cm chamfer | One 45° chamfer per edge: 0.25 to 0.8 m on cliff pieces (a sixth to a quarter of the piece's smaller side), 10 to 15 cm on cover rocks. Never rounded, never more than one cut per edge | Rock blocks are 0.5 to 9 m |
| 10 | Ledges carry the shade side | Holds, and is the cliffs' main rule: every slab steps 0.3 to 1.2 m from the one below, so its top shows as a lit line | The east cliff's inner face never takes sun |
| 11, 19 | Openings inset with ink | No openings and no ink: joints and undercuts are unlit faces | Ink is a non-tiling name; it would pull rock into the per-GLB image |
| 12 | One feature per 1.5 to 2 m of street face, 0 to 2.8 m up | One feature per 2 to 3 m of wall from 0 to 3 m up (a block, a joint, a bank); one skyline feature per segment | |
| 13 | One wear accent per 4 m of street face | One per segment (4.4 m), in silhouette | |
| 14 | Nothing broken through, nothing fallen; wood sags, stone does not | Rock falls: fallen blocks, chipped caps, open joints. Nothing sags, and no cave opens | Talus is fallen rock |
| 17 | Sun faces saturated; shade faces pale, Y 0.4 or more | Holds per wall: the west cliff (middle step at every hour) is vermilion, the east cliff (never lit) pink at Y 0.49 (F3) | The fixed sun |
| 21 | Company blue belongs to the railroad | Holds, and no blue appears: the canyon is company right-of-way but carries no company object (F12) | `ghost.md` |
| 22 | The wall behind a spawn is one flat field | The field behind `EnemySpawn` is the backdrop butte's flat violet face, with sky above it (F2). Nothing else stands above the shins within 6° of the lane seen from `PlayerSpawn`, or within 5° seen from `EnemySpawn`. Behind the multi markers, no band edge crosses 1.0 to 2.3 m | |
| 24 | The ground keeps its ochres | Holds, with Main Street's exact two ground values | One desert |
| 25 | Names prefixed with the asset | Visible objects take the asset prefix (`Cliffs_Rock`); the 85 proxies keep their greybox names, already unique and dotless | No code reads them, and the footprints stay traceable |
| 26 | One object per material per asset | Holds. Plants: one mesh per plant per sway material; rigid cacti merge across plants | Sway bends by its mesh's height; nothing clones these plants |
| New | | Every vertex on a 0.25 m grid in plan and height; plan angles in 15° steps | Crafted, not crumpled |
| New | | No two faces share a plane where pieces overlap | The greybox's z-fighting rule (`ARCHITECTURE.md`) |
| New | | Below 2.2 m, a rock face the lane can see sits within 0.15 m of its proxy's face | Bullets hit what you see |
| New | | Turn each wall's main planes 15 to 45° toward the player end; the returns that face away draw the dark notches | The light table: those planes take the middle or full step |
| New | | At dawn and dusk a cliff's shadow may cross the lane, but no shadow edge lands within 0.4 m of a spawn's mark | A standing duelist is never half in shadow |

### Rock vocabulary

Every rock in the scene, cliffs to mesas, is built from these pieces. A procedural build stays attractive when it places few, big, planar pieces by rule. Single-vertex jitter makes crumpled paper.

| Piece | Form | Size | Triangles at most | Used for |
|---|---|---|---|---|
| Ledge slab | A prism extruded from a plan line of 4 to 8 points (two or three planes), flat top, one or two front corners chamfered; bottom and buried faces deleted | 0.75 to 1.5 m tall on the cliffs (F15), 1.25 to 2.5 m on the rim's faces and the mesas; 3 to 9 m long | 40 | Wall strata, rim faces |
| Fluted slab | A ledge slab whose front is a zigzag: ridges 1.0 to 1.5 m apart, 0.2 to 0.3 m deep, faces turned ±30° | As above | 70 | Upper walls |
| Cap slab | A ledge slab in bone, overhanging the slab below by 0.3 to 0.8 m with its underside kept, cut by joints every 2 to 4 m into blocks 0.25 to 0.6 m apart | 1.25 to 2.0 m tall | 60 | The skyline |
| Chamfered block | A box with one to four vertical edges cut at 45°, and perhaps its top front edge | 0.5 to 4 m | 24 | Talus front, cover rocks, butte skirt |
| Wedge | A box with one face at about 35° (talus) or 55 to 70° (scree tongue) | 1 to 3 m | 10 | Behind the talus blocks, skirts, sand banks |
| Pillar | Two or three chamfered blocks, each inset 0.1 to 0.3 m from the one below, under a bone cap block overhanging 0.2 to 0.4 m | 1.2 to 1.8 m across, 3 to 6 m tall | 80 | The teeth |
| Fallen block | A chamfered block tilted 5 to 20° about a bottom edge, sunk 5 to 10 cm | 0.4 to 1.4 m | 24 | Rubble, wear accents |
| Joint | A vertical notch through one to three slabs | 0.25 to 0.5 m wide, 0.25 to 0.6 m deep | 8 per slab | Cracks |
| Far mesa | A ring of skirt wedges, two or three stacked prisms, a bone cap | 15 to 55 m | 150 | Horizon |

How the code places them:

1. Big planes, few cuts. Most faces are 2 to 6 m across; none under the size floor.
2. Snap to the grid: 0.25 m in plan and height, plan angles in 15° steps.
3. Strata sit at the fixed heights below, on both walls and the butte. Thickness varies only by whole grid steps.
4. Every slab steps 0.3 to 1.2 m in or out from the one below, never 0.
5. Seed each segment by its index and pick from ranges. No per-vertex noise, displacement, subdivision, remesh, or slivering booleans.
6. Turn the main planes toward the player end (the exception above).
7. Each flat region is one planar n-gon, shading flat, edges hard.
8. Neighbouring segments' skyline tops differ by at least 0.6 m, and each segment gets one skyline feature (rule 4 at rock scale).

### Bands

Heights above the floor's top, the same on both walls, so the lines run unbroken down the canyon and converge toward the far end.

| Band | Height | Material | Pieces |
|---|---|---|---|
| Apron (talus) | 0 to 2.0–2.6 m | The wall's body colour; one block in three bone, fallen from the cap | Chamfered blocks at the proxy's front face, wedges behind |
| Lower body | 2.5 to 7.0 m | Body colour | Three to five ledge slabs, 0.75 to 1.5 m each, and joints |
| Band | 7.0 to 8.25 m | Band violet | One slab, 0.3 to 0.5 m proud of the slab below |
| Upper body | 8.25 m to the cap | Body colour | Two to five fluted slabs, 0.75 to 1.5 m each |
| Cap | The top 1.25 to 2.0 m of each segment (tops 11.75 to 17.5 m) | Bone | A cap slab broken into teeth |
| Below the rim | 0 to −24 m | The face's body colour | Sheer drops, two ledges, a skirt; a second violet band at −6.0 to −7.25 m |

### Palette

Enter the linear value as the Blender Base Color. Hex is the sRGB display value; Y is linear luminance. "Seen" estimates the colour on screen at dawn, noon, late afternoon, and dusk, by the method under the backdrop check.

| Flat | Hex | Blender Base Color (linear) | Y | Base name | Used for | Seen: dawn / noon / late afternoon / dusk |
|---|---|---|---|---|---|---|
| Vermilion (new) | #D9472B | 0.694, 0.063, 0.024 | 0.19 | `M_Rock` | West cliff, west teeth, the rim's sunlit south and east faces, flank mesas | West inner face: #C1240E / #D1442A / #CE3B1C / #C22006 |
| Pink cliff (new) | #F2A6A0 | 0.888, 0.381, 0.352 | 0.49 | `M_RockDark` | East cliff, east teeth, the rim's north and west faces | Shade face: #652E31 / #57455C / #643E47 / #74261A. Plane turned to the player end: #FC6C50 / #E99F9C / #FFA585 / #FC6236 |
| Band violet (new) | #7E5BB5 | 0.209, 0.105, 0.462 | 0.15 | `M_CapDark` | The band, cover rock bodies, the backdrop butte (F2) | Facing the player end: #84395B / #7957B0 / #8E5A96 / #83333E |
| Bone (Main Street's) | #E8DDC4 | 0.807, 0.723, 0.552 | 0.73 | `M_Cap` | Caprock and its teeth, fallen cap blocks, cover lids, lip stones, mesa caps | Cap front: #F29263 / #E0D4BF / #FFDCA3 / #F18444 |
| Canyon sand (as built: Main Street's desert dirt; decided: its street dirt #DDC499, 0.72, 0.55, 0.32) | #B8A281 | 0.48, 0.36, 0.22 | 0.38 | `M_Sand` | The floor | Measured in flat captures (H, Floor), lit: #BA785F / #F7F5E8 / #F7DAB6 / #BB5735. In the east cliff's shadow at dawn and dusk: #5E423E / #622A1F. The decided street dirt drew white at noon (98% of the floor's pixels at 255 in a channel), so the build departs from it: see H, Floor |
| Far desert (Main Street's desert dirt) | #B8A281 | 0.48, 0.36, 0.22 | 0.38 | `M_SandFar` | The plain, also Main Street's and Train Rooftop's ground | #9A5842 / #CFB89A / #CAA178 / #974B27 |
| Plants (unchanged) | | Today's values, equal to Main Street's | | `M_Cactus`, `M_CactusDark`, `M_Scrub`, `M_ScrubDry` | The plain's plants; the sway names stay | |

- Roughness 0.9 and metallic 0 everywhere (rule 23).
- All six rock and ground names keep the importer's tiling set and grain 0.2; the plants take none. The four rock names no longer describe their colours (`M_CapDark` is violet), but a fifth rock colour would need code (G4).
- Under the dawn and dusk sun the violet reads wine, and every colour in shade falls to about a sixth of its value in full sun: the east cliff's faces and the shaded floor go dark at the ends of the day. The lit ledges, caps, and turned planes carry the shade side.
- Retired: the greybox's tans (#CB997C, #B3866F, #DDBF9E, #C4A281, #DABC99, #C4A686).

### Backdrop check

How the numbers were made, as on the Saloon sheet but outdoors. The banded sun (`band_low` 0.65, `band_soft` 0.03) in each time's light colour and energy, plus the sky's ambient light: the sky shader's gradient integrated over the hemisphere, times the scene's 0.6 sky contribution. Duelists' fronts face the viewer; the skin's edge light and the fog are left out. Contrast is (Y₁ + 0.05) / (Y₂ + 0.05); under 1.5, only hue separates the two. The roster colours are the Saloon sheet's approximations; starred are the shipped `body_color` tints. Each cell is the range over the four times.

| Backdrop | Bile yellow | Absinthe | Pale tin | Aquamarine | Bone | Red | Ox-blood | Gold | Black coat | Tan* | Blue-grey* | Near-white* | Ink outline |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Sky band and fogged plain behind `EnemySpawn` (rejected in F2) | 1.1–1.3 | 1.1–1.8 | 1.0–1.6 | 1.1–1.6 | 1.0–1.4 | 2.1–3.6 | 4.6–7.4 | 1.2–1.6 | 7.2–10.7 | 2.4–3.1 | 4.7–5.8 | 1.0–1.4 | 7.3–11.7 |
| The plain as it draws before the F1 fog | 1.0–1.9 | 1.1–1.4 | 1.1–1.6 | 1.0–1.6 | 1.2–2.3 | 1.1–3.2 | 2.1–6.7 | 1.1–1.6 | 3.2–9.7 | 1.2–2.6 | 2.2–4.8 | 1.3–2.2 | 3.3–10.6 |
| Butte face in band violet (decided, F2) | 2.7–3.2 | 2.0–2.7 | 2.2–2.8 | 2.2–3.1 | 3.2–4.0 | 1.1–1.5 | 1.5–2.2 | 2.3–2.5 | 2.3–3.4 | 1.1–1.2 | 1.6 | 3.1–4.0 | 2.3–3.7 |
| Butte face in vermilion (rejected) | 1.5–2.5 | 1.1–2.1 | 1.2–2.2 | 1.2–2.6 | 1.8–3.1 | 1.2–1.3 | 2.6–2.9 | 1.3–1.9 | 3.8–4.7 | 1.0–1.5 | 1.9–2.8 | 1.7–3.2 | 4.2–5.3 |
| West talus, vermilion, behind `3/A` | 1.9–3.0 | 1.4–2.5 | 1.6–2.6 | 1.6–3.0 | 2.3–3.8 | 1.1–1.3 | 2.0–2.6 | 1.7–2.4 | 3.2–3.8 | 1.0–1.2 | 1.7–2.2 | 2.2–3.8 | 3.2–4.2 |
| East tooth's lit face, pink, behind `3/C` (decided, F3) | 1.0–1.1 | 1.0–1.4 | 1.0–1.2 | 1.1–1.3 | 1.2–1.4 | 1.8–2.8 | 4.0–5.9 | 1.2 | 6.3–9.6 | 2.3–2.4 | 4.1–4.7 | 1.1–1.5 | 6.4–10.7 |
| The same face in vermilion (rejected) | 1.5–2.5 | 1.1–2.1 | 1.2–2.2 | 1.2–2.6 | 1.8–3.1 | 1.2–1.3 | 2.6–2.9 | 1.3–1.9 | 3.8–4.7 | 1.0–1.5 | 1.9–2.8 | 1.7–3.2 | 4.2–5.3 |
| East talus behind `2/B`, both in shadow (dawn, late afternoon, dusk) | 1.0–1.1 | 1.0–1.2 | 1.0–1.1 | 1.0–1.2 | 1.1–1.3 | 1.4–1.7 | 1.8–2.1 | 1.1 | 2.0–2.3 | 1.5–1.8 | 1.8–1.9 | 1.1–1.3 | 1.8–2.1 |
| The player seen from `EnemySpawn`, backlit against the south sky | 4.0–4.9 | 4.8–5.6 | 4.4–5.3 | 4.4–5.1 | 3.6–4.3 | 5.3–9.7 | 7.0–11.6 | 4.3–5.9 | 7.8–12.3 | 5.9–8.3 | 7.2–10.1 | 3.7–4.3 | 7.3–11.7 |

- **The open field (rejected in F2).** Behind the enemy the sky band and the fogged plain are one flat field, #F29E73 at dawn, #B2CCEB at noon, #DBBD85 in the late afternoon, #F28040 at dusk. The dark roster reads strongly. Every pale colour holds 1.0 to 1.8, among them the Ghost's aquamarine and bone, and he is this arena's duelist. Only hue and the ink line (7.3 to 11.7, about 3.6 px wide at 22 m) separate them, and the cloud deck starts 1.7° up, just over the hat (1.6°).
- **The violet butte (decided)** lifts every pale colour to 2.0 to 4.0 at every hour and hides the clouds behind the enemy. Its weak cases are the Sheriff's red and the shipped tan, 1.1 to 1.5.
- **Marker `3/C`** sees the east cliff's lit planes: pink gives pale duelists 1.0 to 1.5, vermilion 1.1 to 3.2. That is the price of rule 17 on this wall, accepted in F3: `3/C` is a three-NPC marker only.
- **Marker `2/B`** stands in shadow against rock that never takes sun. No rock colour fixes it. At noon the duelist is lit and pale colours read 3.6 to 6.0; at the other times the skin's edge light, 35% of the sun's colour on the duelist's outline and not in these numbers, is what shows them. Moving the marker would be a scene edit, and anywhere east of the lane at y 5.2 is shadowed at dawn and dusk.
- **The player**, backlit with the sun behind them, reads 3.6 to 12.3 against the south sky for every colour. The south opening stays clear (rule 22).

## B. Asset sheets

The brief's five assets. Each keeps its greybox objects' places, and each becomes one group under the `canyon` root in `canyon.blend`, all in one `canyon.glb` (F13).

| Asset | Greybox objects | Class | Triangles today | Budget | Objects after merging |
|---|---|---|---|---|---|
| Cliffs (hero) | `WestTalus0`–`7`, `WestWall0`–`7`, `WestCap0`/`2`/`4`/`6`, `WestTooth1`/`7`, seven `WestRubble*`, `WestBack`, and the east set with `EastTooth4` and eight rubble (62) | Rock, hero | 744 | 16,000 | 4 |
| Cover rocks | `CoverWPlayer`, `CoverEPlayer`, `CoverWMid`, `CoverEMid`, `CoverWEnemy`, `CoverEEnemy` and their `Chip`s (12) | Rock, cover | 144 | 1,500 | 2 |
| Floor | `Floor` (1) | Ground | 12 | 400 | 1 |
| Rim | `SouthFace`, `NorthFace`, `WestFace`, `EastFace`, `SouthLip0`–`3`, `NorthLip0`–`3` (12); the four invisible `Rim*` walls | Rock, seen from the rims | 144 | 2,000 | 4 |
| Horizon | `Desert`, `Mesa0`–`7` and their caps (17); 110 plants in 289 parts | Far dressing | 4,316 | 5,000 | 4, plus about 25 for plants |
| **Scene** | 393 meshes, 85 proxies | | **5,360** | **About 25,000** | **About 40** |

**Why the budget grows.** From 5,360 to about 24,900 triangles, about 4.6 times, as decided (F15). The increase lands on the cliffs, which fill both sides of every view from 4 to 25 m: rock and sand go from 1,248 to about 21,500, while the plants, seen no closer than 60 m, drop from 4,112 to about 3,400. That is a little above Main Street's built 22,550, well above the Saloon's 14,000, and 1.7% of Meta's Quest 3 guideline of 1.5 million triangles per frame. The PSX look caps detail first: the per-piece ceilings in A and the 25 cm size floor keep the rock chunky, so the extra buys more pieces, not smaller ones, as the polygons you can see at once set Crash's budget (Andy Gavin).

Two limits are tighter than the triangle count:

- **Draw calls.** Today's 393 meshes are each a draw call, drawn again into each of the sun's four shadow cascades they touch. Merging per material (rule 26) brings the rock and ground to 15 objects; the plants add about 25 (G6).
- **Shadow casters.** The merged cliffs cast into every cascade out to 360 m. Time it on a Quest at dusk, when the shadows are longest.

---

### Cliffs: `West*` and `East*` (hero)

| | |
|---|---|
| Squint | Two walls of stacked slabs stepping in and out along the lane, the left hot vermilion, the right bleached pink, each crossed by one violet stripe and topped by a broken bone line against the sky. Vermilion or pink, violet, bone |
| Role | Frames the lane for its whole length, the toes 4.7 to 9.0 m off the centre line; the scene's mass and its shadows. Never cover: the nearest cliff proxy is 3.05 m outside the shot band. The backdrop of three multi markers (`3/A`, `2/B`, `3/C`). Seen from 4 to 25 m, rising 50 to 65° above the eye from the lane |
| Size | Eight segments a side, 4.4 m long and overlapping, centred at y −10.6, −7.4, −4.2, −1.0, 2.2, 5.4, 8.6, 11.4. Talus 2.5 m deep, tops 1.63 to 2.30 m. Walls 9.0 m deep, 4.05 m long, from 1.1–1.75 m up to tops of 11.8 to 16.1 m. Caps on even segments, 4.6 × 3.2 m, tops 14.0 to 17.5 m. Teeth 1.35 × 1.7 × 4.8 m. Rubble 0.55 × 0.40 × 0.42 m. Backs 8 × 24 × 14 m behind the segments, x ±12 to ±20. Talus toes: west −4.65 to −8.96, east 5.80 to 8.77 |
| Triangles | 744 today; 16,000 at most: about 870 per segment (apron 230, lower body 210, band 60, upper body 210, cap 90, joints and rubble 70), the five greybox teeth 400, about 15 extra pillars 1,200, the backs' visible strips 300 |
| Collision | Unchanged: the 62 proxies keep their boxes and names. Rule 5 listings: above 2.2 m the rock stands up to 0.5 m proud of its proxy or 1.0 m inside it, so high bullets pass through some edges and stop short of others; below 2.2 m the lane-side faces stay within 0.15 m. Nothing enters the shot band or a pad |

Signature details, cut from the bottom:

1. Strata at the band heights on both walls, in slabs 0.75 to 1.5 m tall (F15), every slab stepping 0.3 to 1.2 m from the one below, so the shade wall reads as close lit ledge lines on dark rock (rule 10).
2. Main planes turned 15 to 45° toward the player end, joined by short returns that face away. From `PlayerSpawn` both walls show lit planes cut by dark notches; from `EnemySpawn` the returns dominate and the canyon is in shadow.
3. The bone cap: a slab overhanging 0.3 to 0.8 m, its underside a dark line, broken by joints every 2 to 4 m into blocks with sky between them: a row of teeth along each rim (F7). Neighbouring tops differ by 0.6 m or more.
4. The violet band, 7.0 to 8.25 m, unbroken down both walls except where a segment is broken back. The two lines converge toward the far end of the lane.
5. The talus apron (F8): chamfered blocks 0.8 to 1.8 m tall on each talus proxy's front face, one in three a fallen bone cap block, wedges at 35° behind them up to 2.0–2.6 m. Sand banks at their feet belong to the floor (F16).
6. Vertical flutes on the upper body, 1.0 to 1.5 m apart and 0.2 to 0.3 m deep. Under the fixed sun their faces take two light steps, so the upper walls read striped (board #07).
7. Teeth: the five greybox teeth as pillars of two or three stacked blocks under a bone cap block, 3 to 6 m tall, each the wall's body colour, on their own proxies. Today `EastTooth1` at dawn and `EastWall0` at dusk shadow the Ghost's east strafe; the finals keep that (F17), with no shadow edge on a spawn's mark.
8. About 15 more pillars, roughly one a segment (F19): rising from the talus or standing out of the wall face above 2.2 m, inside today's talus and wall proxies and up to 0.5 m proud above 2.2 m. None may move a shadow edge onto a spawn's mark.
9. Wear, one accent per segment in silhouette: a fallen block, a chipped cap corner (0.3 to 0.6 m), an undercut at the foot, a joint open to the sky, a pillar block leaning 3 to 6°.
10. Joints: two to four vertical notches per segment through the lower body.
11. The rubble: the 15 stones as fallen blocks tilted 5 to 20°, inside their proxies.

- **Wear in geometry:** fallen blocks, chipped caps, undercuts, open joints, a leaning block. Rock does not sag.
- **Base Color:** `M_Rock` Vermilion (west body and teeth). `M_RockDark` Pink cliff (east body and teeth). `M_CapDark` Band violet (the band). `M_Cap` Bone (caps, cap teeth, fallen cap blocks, pillar caps).
- **UV:** 8 m tiling UVs on all four objects (G2). Model every piece in place and keep each object's rotation at zero and its origin at the canyon's origin, so the tiles stay level and run on across pieces; chamfers and 35° faces stretch the tile up to 1.4 times. No image.
- **Draws on:** board #07 (a tiny figure under a striped cliff), #12 (Monument Valley red; workwear padded and oversized), #09 (teeth as a design surface), #20 (total silhouette: the cap line as line work), #15 and #25 (the complementary pair for the Ghost), and pattern 3 (pattern is the silhouette: the strata). Dutton's colour-named cliffs (NPS Bryce Canyon). The Blue Mesa Member's purple mudstones (NPS). Mell's angular, faceted planes (Masterworks). Talus at its angle of repose (Wikipedia). Tomb Raider's grid (Life and Times).

### Cover rocks: `Cover*`

| | |
|---|---|
| Squint | Six squat dark-violet blocks with pale bone lids standing apart on the sand, three a side, none in the lane. Violet, bone |
| Role | The only cover. Near the player: `CoverWPlayer` (−3.8, −6.2) and `CoverEPlayer` (4.5, −8.6). Mid-lane: `CoverWMid` (−3.3, 1.0) and `CoverEMid` (4.0, −0.6). Near the enemy: `CoverWEnemy` (−4.2, 6.4) and `CoverEEnemy` (3.6, 3.0). Their proxies stand 1.00 m (`CoverWMid`) to 2.10 m (`CoverEPlayer`) outside the shot band. Crouch cover for free roamers and lobbies; seen from 2 to 20 m, against the floor and the wall toes |
| Size | Bodies 1.4–2.0 × 1.4–1.8 m, 1.15 to 1.65 m tall, sunk 5 cm. Chips 0.77–1.10 × 0.70–0.90 × 0.32 m. Proxies are the body footprints at full height, 1.36 to 1.86 m |
| Triangles | 144 today; 1,500 at most, about 250 a rock |
| Collision | Footprints frozen: the multi clearances and the lane gap depend on them. The visible rock fills its proxy: chamfers of 0.15 m or less, tilts inside the box, the lid under the proxy's top. A chamfer past 0.15 m gives the proxy the same cut, which stays convex (rule 28 listing) |

Signature details, cut from the bottom:

1. One squat chamfered block per rock, vertical edges cut 10 to 15 cm, sides turned up to 8° off the axes so no two rocks repeat.
2. The bone lid: the greybox chip as a slab 0.25 to 0.35 m thick, overhanging 5 to 10 cm on the lane side, so a dark line runs under it.
3. One strata step at mid-height, 5 to 10 cm: the band's ledge in miniature.
4. One chipped corner of 15 to 25 cm per rock, each on a different corner.
5. A sand bank on the side away from the lane (the floor's rule).
6. `CoverWPlayer` and `CoverEMid` split by a joint into two blocks 10 cm apart, inside the footprint.

- **Wear in geometry:** the chips and the split.
- **Base Color:** `M_CapDark` Band violet (bodies), `M_Cap` Bone (lids). Against the sand the violet body holds 1.8 to 4.3 at every hour; bone would fall to 1.1 at noon. Against the vermilion wall the hue and the bone lid separate it.
- **UV:** tiling, two objects for all six rocks.
- **Draws on:** board #18 (one colour block behind an ink drawing: a dark block on pale sand), #04 (a two-colour image); fallen pieces of the canyon's own band and cap.

### Floor: `Floor`

| | |
|---|---|
| Squint | A pale sand floor running between the walls to a clean broken edge against the sky at each end. Sand |
| Role | Everything stands on it, at z 0 exactly under every marker (`ragdoll`, `multi`). Its far edge is the line at the enemy's shins seen from `PlayerSpawn`. It carries the long shadows: at dusk the shaded east half is #3D1B1F against #B65C30 in sun, the edge along the lane |
| Size | 32 × 29.2 × 0.24 m, top at z 0; ends at y ±14.6, 8 cm over the rim's faces |
| Triangles | 12 today; 400 at most |
| Collision | `Floor-convcolonly` unchanged (32 × 29.2 m, z −1 to 0). The banks and steps have none: feet sink up to 0.15 m in them |

Signature details, cut from the bottom:

1. The rim edge: the two ends broken in plan outside ±3 m of the lane, with notches 0.3 to 1.2 m deep and chipped corners; straight within ±3 m, so the line behind each duelist's shins is clean.
2. One plane at z 0 within |x| < 2.5 and within 1.5 m of every marker.
3. Sand banks 0.15 to 0.3 m tall, reaching 1.0 to 1.5 m out from the talus toes, between the apron's blocks and on the far sides of the cover rocks, so the floor meets the rock in a ramp rather than a seam (F16).
4. Three to five bedrock steps 0.10 to 0.15 m tall and 2 to 4 m across, beyond |x| 2.5: the dry wash's slickrock (F16).
5. The bottom and the parts under the cliffs deleted.

- **Wear in geometry:** the broken edge and the banks.
- **Base Color:** `M_Sand` Canyon sand, Main Street's street dirt value. As built: its desert dirt, because the street dirt draws white at noon (H, Floor).
- **UV:** tiling, one object.
- **Draws on:** the dry wash the greybox was built as (`ARCHITECTURE.md`); board #07 (the canyon bed and its two small figures); Main Street's ground values.

### Rim: `*Face`, `*Lip*`, `Rim*`

| | |
|---|---|
| Squint | From the edge, a sheer drop banded like the walls, stepping out in two ledges to a pale skirt on the plain 24 m below; along the edge, a few bone blocks. Vermilion or pink, violet, bone |
| Role | The butte's sides: four 24 m drops. The invisible rim walls keep bodies 0.2 to 0.7 m from the edge. The lip stones are shin-high accents at both ends, 5.2° and 7.9° off the lane from the far spawn. Seen from the lane only as the floor's end; from the rims by looking out, and by a VR player leaning over to look down |
| Size | `SouthFace` and `NorthFace` 36 × 2.4 × 24.2 m, inner faces at y ±14.52; `WestFace` and `EastFace` 2.4 × 33.2 × 24.2 m, inner faces at x ±15.92; all from z −24.35 to −0.15. Lip stones 0.55–0.90 × 0.35–0.55 m, 0.40 to 0.70 m tall, at y ±13.3, x −6.5, −2.2, 3.4, 7.2. `RimSouth` and `RimNorth` 36 × 0.45 × 2.1 m at y ±13.92 to ±14.38; `RimWest` and `RimEast` 0.45 × 33.2 × 2.1 m at x ±15.32 to ±15.78 |
| Triangles | 144 today; 2,000 at most: faces 1,300, skirt 400, lip stones 300 |
| Collision | Unchanged: the four face proxies, the four invisible rim walls, and the eight lip proxies. Rule 5 listing: the ledges and the skirt stand outside the face proxies, below the rim, where nobody reaches. As built, F22 changed this: the face proxies moved behind the upper drop and 80 boxes follow the strata, the ledges, and the lower drops (H, Rim) |

Signature details, cut from the bottom:

1. The strata continue down: each face in the body colour its light allows (the south and east faces take sun: vermilion; the north and west never do: pink), a violet band at −6.0 to −7.25 m.
2. Two ledges: the face drops sheer for 8 to 10 m, steps out 1.5 to 3 m, drops again, steps out, and ends on a skirt of 35° wedges 6 to 10 m wide on the plain, so a player leaning over sees depth (F11).
3. The four butte corners cut by one 45° chamfer of 1 to 2 m.
4. The face's top edge follows the floor's notches in plan.
5. The lip stones as fallen bone cap blocks, chamfered and tilted 5 to 15°, in their proxies.
6. Wear: one fallen block on each ledge.

- **Wear in geometry:** the fallen blocks and the broken edge.
- **Base Color:** `M_Rock` Vermilion (south and east faces), `M_RockDark` Pink cliff (north and west faces), `M_CapDark` Band violet (the band), `M_Cap` Bone (lip stones).
- **UV:** tiling; three tiles down each face.
- **Draws on:** Monument Valley's buttes, the cliff over its softer slope and capped by the Shinarump (USGS, 1957); talus at its angle of repose (Wikipedia).

### Horizon: `Desert`, `Mesa*`, `Plant*`

| | |
|---|---|
| Squint | Past each end of the canyon, an empty plain dissolving into the sky colour; a violet butte standing behind the enemy (F2); a few flat mesas fading off to the sides. Violet, vermilion, bone, fading to the sky |
| Role | Everything past the openings and below the rims; the field behind `EnemySpawn` seen from `PlayerSpawn` (F2); behind the player seen from `EnemySpawn`, open plain and sky with the sun 15° east of the line at dawn and dusk; the panorama from the rims. No collision |
| Size | `Desert` 6,000 m square, top at z −24. Eight mesas 18 to 54 m wide, 14 to 40 m deep, 28 to 64 m tall (tops 4 to 40 m above the floor), 124 to 225 m from the origin. 110 plants 67 to 300 m out, scaled 0.8 to 1.4 |
| Triangles | 4,316 today (204 rock and sand, 4,112 plants); 5,000 at most: the butte and mesas 1,600, the plain 12, the plants 3,400 |
| Collision | None, as today |

Signature details, cut from the bottom:

1. The backdrop butte (F2): about 80 m from `PlayerSpawn` on the lane's axis (y ≈ 69), within ±6° of the lane (about 17 m wide), clear of `EnemySpawns2/A` at 9.5° west. Its south face is one flat violet plane from below the rim line to 4° above the horizon (7.3 m over the floor, 31 m over the plain), with no line across it; a bone cap to 5°, and shoulders stepping down beyond ±6°. The fog takes about 0% at that range (it begins at 80 m).
2. Flank mesas 100 to 250 m out (the fog takes 0 to 43%: the nearer ones crisp, the farther ones fading, so they layer), two or three per opening, outside ±6° of the lane and away from `2/A`'s line: two values each, body and cap, with one or two steps or notches in the silhouette, tops between 2° and 8° above the horizon (F9).
3. In the south opening only west of the lane, so the dawn and dusk sun, 15° east, hangs over open plain.
4. The plain stays one frozen plane in Main Street's desert dirt.
5. A skirt of wedges round each mesa's foot, seen from the rims.
6. Plants in Main Street's final kinds and rules, about 55 within 200 m, plus about 10 round the butte's foot for the look-down (F10). Rigid cacti merged across plants per material; each scrub stays one plant's own mesh.

- **Wear in geometry:** the plants' deadwood, if Main Street's kinds bring it; the mesas' broken caps.
- **Base Color:** `M_CapDark` Band violet (the butte's face), `M_Rock` Vermilion (mesa bodies), `M_Cap` Bone (caps), `M_SandFar` Far desert (the plain), the plants unchanged.
- **UV:** tiling for rock and sand. The plants stay in the per-GLB image at 9.4 px per metre with no pad: flat colour.
- **Draws on:** Maynard Dixon's low horizons and simplified rock in bold colour (BYU Museum of Art), and *Mesas in Shadow* (1926), where shadow covers the distant mesas and one catches the sun (BYU store listing); Moran's Grand Canyon chromolithograph for the Santa Fe (Gilcrease); Spyro's flat-shaded far levels (Hardcore Gaming 101); board #22 (desert at blue hour), #14 (an empty plain under the sky), #00 (the duel framed by scale contrast).

## C. Build order

**Hero: the cliffs.**

- They are the scene's mass and its identity, and the hardest class to build in code, so they set the rock vocabulary, the band heights, the chamfer sizes, and the rate of triangles per metre that every other asset copies.
- The cover rocks, the rim, the mesas, and Train Rooftop's `horizon_ridge.glb` all inherit their kit (E).
- They test the rules that are new here: planes turned to the light, the lit ledges on the shade wall, the cliff shadows on the spawn marks.
- They are in view in every duel, and they meet the floor, the cover rocks, and the rim, so their review covers those contacts.

**Order:**

1. The cliffs, the hero: the vocabulary, all 16 segments, the backs. Scene edit first: `fog_density` 1.0, `fog_depth_begin` 80, `fog_depth_end` 400 in `canyon.tscn` (F1), checked in a flat run, since the review needs the real far view. Build segments 5 to 7 of both walls first and check them in the Lane P view, then the rest from the same code.
2. The cover rocks: six variations from one generator, not a module. Re-run `multi`.
3. The floor: the rim edge, the banks, the steps. Re-run `ragdoll` and `multi`.
4. The rim: the faces, their ledges and skirt, the lip stones.
5. The horizon: the backdrop butte (F2), the flank mesas (F9), the plain's colour, the plants (F10).

No asset is a modular repeat at the GLB level. Inside them, the vocabulary's pieces repeat with seeded variation, the six cover rocks come from one generator, and the plants repeat Main Street's kinds.

## D. Review checklist

### Views

| View | Where | Camera | For |
|---|---|---|---|
| Lane P | Godot, Canyon, shaders on | Eye at (0, 1.7, 11), looking at (0, 1.7, −11), the flat camera's field of view | Both cliffs, the north opening, the butte, the cover rocks, the floor's far edge |
| Lane E | Godot | Eye at (0, 1.7, −11), looking at (0, 1.7, 11) | The south opening, the sun, the shade sides, the player's backdrop |
| Flank | Godot | From Lane P's eye, aimed at each multi marker at 1.7 m: (−3.3, 1.7, −8.8), (4.6, 1.7, −5.2), (−4.0, 1.7, 2.5), (4.3, 1.7, 3.0) | The backdrops of `2/A`, `2/B`, `3/A`, `3/C` |
| Up | Godot | Eye at (0, 1.7, 0), pitched 50° up at each wall | Skyline, cap teeth, flutes, the band |
| Toe | Godot | Eye 1.7 m up, 2 m from a talus toe: (−2.6, 1.7, −1.0) facing −X, (6.1, 1.7, −1.0) facing +X | Apron blocks, sand banks, the lane-side 0.15 m rule |
| Rim | Godot | Eye at (0, 1.7, −13.6) facing −Z and (0, 1.7, 13.6) facing +Z, level and pitched 60° down | The drop, the ledges and skirt, the plants below, the far mesas |
| Front | Blender, `canyon.blend` | From the lane at the piece's y, 1.7 m up, facing the piece, 50 mm lens; for the cover rocks, from `PlayerSpawn`'s eye | Every asset (its duel-lane view in Blender) |
| Three-quarter | Blender | 45° between the lane and the piece's main face, 10 m out, 1.7 m up, 50 mm lens | Every asset |
| Silhouette | Blender: Workbench, flat lighting, one black colour, white world | The cliffs' skyline from mid-lane at 30° up; each wall in profile from the rim along Y; each cover rock from `PlayerSpawn` and from the side | Every asset |
| Squint | The Front render | Shrunk to 64 px wide, enlarged back with nearest filtering | Every asset |

- Render each Godot view at dawn, noon, late afternoon, and dusk with F3 `time_of_day`. A temporary `Camera3D` does the job; do not save it into the scene.
- Finish in a headset: stand at `PlayerSpawn`, look at the far end, walk to a talus toe and a cover rock, then lean over the north rim.

### Pass or fail, every asset

1. **Silhouette:** can you name the asset, and each wall, from its black outline alone?
2. **Squint:** does the 64 px render show one shape and at most three flats?
3. **Size floor:** is every modeled feature at least 25 cm on the cliffs, rim, and mesas, and 10 cm on the cover rocks and floor?
4. **Wear:** one accent per segment, in silhouette, and none in any colour?
5. **Budget:** triangles within the budget, and objects equal to materials?
6. **Names:** visible objects prefixed with the asset, no `.001`, proxies `-convcolonly` with no dot in the name?
7. **UVs:** does every rock and sand object carry 8 m tiling UVs, level on its walls? Does `dev/unwrap_per_glb_blender.py -- --map canyon --relayout` lay out only plants?
8. **Collision:** unchanged, or the listed change? Does no proxy overlap the shot band or a pad (G5)? Do `load`, `multi`, and `ragdoll` pass after export and reimport?
9. **No shared planes:** do overlapping pieces avoid every coplanar face? Is there no flicker in a flat run?

### Pass or fail, in context

10. Lane P: is the field behind the enemy one flat field from the shins to above the hat, within ±6°, with no line across it?
11. Do the duelists, in the shipped tints and in swatches of the designed colours, separate from the field and from each multi marker's backdrop at squint?
12. Lane E: does the backlit player stand clear against the south sky, with nothing above the shins within ±5°?
13. Is the shade wall a pattern of lit ledges and turned planes at noon and at dusk, and not a black field?
14. At dawn and dusk: does the east wall's shadow lie along the lane's edge as a clean shape, and does no shadow edge cut a spawn's mark?
15. With the raised fog (F1, density 1.0, begin 80 m, end 400 m): does the plain dissolve with no line, and do the mesas layer, the nearer ones crisp and the farther ones fading toward the sky?
16. Do the cover rocks read as cover, separate from the floor and the walls, at all four times?
17. In a headset: do the flutes and teeth hold still when you move your head? Does the drop at the rim feel 24 m deep?

### Asset checks

| Asset | Check |
|---|---|
| Cliffs | Do the band lines run unbroken down both walls? Do the planes turned to the player end take the light the table says? Is any talus slope readable as walkable where its proxy stops you? |
| Cover rocks | Does the violet body hold its edge against the sand at noon? Does every rock fill its proxy within 0.15 m below 1.7 m? |
| Floor | Is the floor at z 0 under every marker, and the rim edge straight within ±3 m of the lane? |
| Rim | From the north rim, leaning over, do the ledges and skirt show? |
| Horizon | Does the butte fill ±6° behind the enemy from below the rim line to 5°? Does every mesa stay outside ±6° and `2/A`'s line? |

### Tests

Run `--import`, then `--autotest=load` (the world shader on every Canyon surface, bare proxies, the time-of-day horizon contract), `--autotest=multi` (each marker on the floor and clear), `--autotest=ragdoll` (spawn floors), and `--autotest=gauntlet` (rung 5 loads the Canyon):

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=multi
```

Headless runs do not compile shaders. The look needs a flat run, then a headset.

## E. Cross-scene dependencies

`docs/design/scenarios/main_street.md` exists. This sheet inherits its global rules 1 to 28, its backdrop method, and its build lessons; the exceptions are in A.

- **Colour values shared with Main Street:** bone, exactly; the two grounds, exactly (`M_Sand` takes Main Street's street dirt, `M_SandFar` its desert dirt, which is also `env_terrain`, the Train Rooftop's ground); the plants' values and kinds, unchanged. The plain below the butte is the same desert the town and the train stand on.
- **Wear rules from Main Street:** rule 13's density, in silhouette and never in colour, at rock scale: one accent per 4.4 m segment. Rule 14 bends for rock: rock falls.
- **Saloon:** no shared asset. The Ghost follows the player there, off company ground (`ghost.md`), and the Saloon keeps no company blue.
- **Train Rooftop's `horizon_ridge.glb`** does not use this GLB: its belt clones its own `Canyon`, `Mesa`, and `Butte` spans, 28 to 100 m out, at 0.35× and 0.12× the train's 20 m/s. Its prompt asks it to agree with this vocabulary. So that the two scenes read as one desert, it should share:
  - the four rock values under the same four names (it now uses different `M_Rock` and `M_RockDark` values; only `M_Cap` matches);
  - the band order (apron, body, violet band, body, bone cap) and the band's height above each span's foot;
  - the vocabulary's large pieces, at its own size floor: cap overhangs, turned planes, wedge talus, chamfers of 0.5 m or more, flutes 1.0 to 1.5 m apart (at 7 m/s a flute passes in 10 to 15 frames at 72 Hz, so it does not strobe);
  - rule 17 by its own sun: whichever ridge face the train's sun never reaches takes the pink;
  - its own constraints stay: 48 m spans that tile at the ends, no collision, and a low count per span, since the belt draws 84 copies.
- **Practice Hub:** its `Mesa*` blocks are rock on tiling UVs; that sheet can take these four values.

**Build lessons, applied here:**

- Set colours on the per-GLB material copies, or delete stale ones. Only the plants have copies here (`M_Cactus__canyon`); rock and sand keep their shared names.
- Use headless Blender, or close the live session first: the unwrap script saves the `.blend`.
- Run the per-GLB unwrap with `--relayout` while nothing is painted.
- Check the sheet's numbers against each other before modeling. This sheet already moved the butte off `2/A`'s line and kept the cover lids under their proxies.
- Name proxies without dots.
- Model the finals in `canyon.blend` and never re-run `dev/build_canyon_blender.py` after the first final (G5).
- From the Saloon: avoid three collinear points on a face's outline, which leave zero-area triangles, and count UV islands in the `.blend`, not in the GLB.

## F. Decisions

Answered on 2026-10-23 in five rounds. Every answer took the recommendation except two: no lore mark (F12), and the higher budget, about 25,000 triangles with 16,000 on the cliffs (F15). F19 is the follow-up that budget raised. F20 was asked after the floor's build (batch 2), when the decided street dirt drew white at noon. F21 to F23 came from the user's review of the whole scene on 2026-10-24, after batch 4, and were built in batch 5. The split of the rest of the budget (cover 1,500, floor 400, rim 2,000, horizon 5,000) was stated before round 5 and stands. The last column says what each decision changes on this page or in the scene.

| # | Question | Decision | What it changes |
|---|---|---|---|
| 1 | Fog | Raise `fog_density` to 1.0; then begin 80 m and end 400 m (the user found 60 / 220 too strong) | Scene: three properties in `canyon.tscn`, made first in the hero build and checked in a flat run. The plain dissolves by about 390 m, the mesas fade by distance, and the plain's edge line goes |
| 2 | What stands behind the enemy | A violet butte about 80 m from `PlayerSpawn` | Horizon, detail 1. The sky stays open behind the player |
| 3 | The east cliff's colour | Bleached pink | Rule 17 per wall: `M_RockDark` takes pink |
| 4 | The fourth rock colour | Band violet | `M_CapDark`: the band, the cover rocks, the butte |
| 5 | Rock grain | Horizontal strata, with flutes on the upper walls | |
| 6 | Wear | Weathered: one accent per segment | Rule 13 at rock scale |
| 7 | The cap line | Broken into teeth | |
| 8 | Talus | Stepped blocks on today's proxies | No proxy changes |
| 9 | Horizon layout | Mesas move into the openings, 100 to 250 m out | Horizon, details 2 and 3; the mesas the fog would hide go. With the 80 / 400 m fog they take 0 to 43% and layer |
| 10 | Plants | Rebuilt in Main Street's kinds, about 65 | About 55 within 200 m and about 10 round the butte's foot; rigid cacti merged |
| 11 | The rim's faces | Stepped, with a talus skirt | |
| 12 | Lore mark | None | No breastwork. With no company object, the canyon uses no blue (rule 21) |
| 13 | One GLB or several | One `canyon.glb` with five groups | No scene or import change |
| 14 | Painting the rock | Keep the 8 m tiling UVs | A tiling texture later is a code change (G1) |
| 15 | Scene budget | About 25,000; cliffs 16,000 | Finer strata: cliff slabs 0.75 to 1.5 m, about twice the ledge lines; more pillars and joints. The budgets in B |
| 16 | Floor relief | Banks and steps | |
| 17 | The shadow on the Ghost's east strafe | Keep it | The rule stands: no shadow edge within 0.4 m of a spawn's mark |
| 18 | Enterable spaces | None | |
| 19 | Where the extra pillars stand (follow-up to F15) | Inside today's talus and wall proxies | No new collision; up to 0.5 m proud above 2.2 m |
| 20 | The noon floor (asked after batch 2) | Accept Main Street's desert dirt #B8A281 for `M_Sand` | The floor departs from the decided street dirt; at noon about 29% of floor pixels still clip, and Main Street's street, same value and light, likely does the same. Revisit in the headset |
| 21 | The backdrop butte's distance (review of batch 4) | Keep it 150 m out, not about 80 (F2) | Nothing to build. At about 80 m the east cliff's dawn and dusk shadow split the field behind the enemy; from about 145 m it falls west of the field at every hour (H, Horizon) |
| 22 | The rim's invisible collision shelf (review) | Make the collision follow what you see | A listed collision change (rule 28). The four face proxies move behind the upper drop, under the floor; 80 boxes are added, flush with the strata that step out (U1, the band, M1, L1), the two ledges, and the lower drops, round the corner chamfers too. No proxy stands more than 0.15 m in front of visible rock; nothing above z −0.15 (H, Rim) |
| 23 | The backdrop butte's outline (review) | Roughen it beyond the field: steps and notches from the rock vocabulary, the field still one flat face | Horizon, detail 1: the cap breaks into six blocks with chipped corners and a joint, the main block's ends step down, the shoulders split, and their outer corners break into 45° slopes. The field and its distance stay; the mesas and plants do not move (H, Horizon) |

## G. Pipeline friction

Where the existing texturing pipeline (`docs/TEXTURING.md`) adds work or constraints beyond "model and UV unwrap, then you paint by hand".

**Verdict on the unwrap: reuse `dev/unwrap_per_glb_blender.py` as it is, for the plants only.** It lays out every non-tiling mesh of a GLB in one 256 px image, which here means the plants. It never touches rock or sand. The real UV job in this scene is the 8 m tiling UVs, which `dev/scenery_uv.py` already writes (G2).

1. **Almost nothing here can be painted.** Rock and sand are tiling materials, and both the per-GLB unwrap and its image hookup skip them, so the canyon, nearly all rock, leaves you only the plants. Decided: accept it and keep the tiling UVs (F14). Later, a tiling texture per rock name is a code change to `world_surface_import.gd` and the shader, which would read a repeating image on tiling materials; the UVs are ready. The rejected alternative took the rock out of the tiling set, at the cost of new names, a grain line, and 6 to 15 px per metre.
2. **Nothing writes tiling UVs on a new rock mesh.** The per-GLB unwrap skips tiling meshes, and the strip unwrap (`dev/unwrap_scenery_blender.py`) is paused: it would put strip UVs on any unlocked object and re-export every root with no image. Simplest: in the build session, call `scenery_uv.unwrap_object(obj, scenery_uv.TILING)` on each new rock and sand object and set its `uv_role` to `tiling`; then run the per-GLB unwrap with `--relayout` for the plants. Cost: a few lines.
3. **Tiling UVs ignore rotation.** `_layout_tiling` projects each face along its dominant axis in the object's own frame. Keep rock objects at zero rotation with their origins at the canyon's origin, so the tiles stay level and continuous across a merged object; slanted faces stretch up to 1.4 times. Cost: none.
4. **Four rock names only.** The importer's `TILING` and `GRAIN` tables and `TILING_MATERIALS` know `M_Rock`, `M_RockDark`, `M_Cap`, and `M_CapDark`. A fifth rock colour needs a line in each of two files. Simplest: this sheet fits the palette into the four, so the names no longer describe their colours. Cost: naming only.
5. **The build script wipes finals.** `dev/build_canyon_blender.py` clears the scene, rebuilds the 104 boxes, and runs the paused trim-sheet pass. Simplest: model the finals in `canyon.blend` and never re-run it after the first final lands; the greybox survives in git. Its lane and pad check then never runs again: run the same box test on every proxy from the build session (D, check 8). Cost: one small script.
6. **Swaying plants cost draw calls.** Each swaying scrub must stay one plant's own mesh, so scrub cannot merge: about 20 to 45 draw calls for plants seen no closer than 60 m. Rigid cacti can merge across plants here, since nothing clones them. Decided: cut the plants beyond 200 m (F10). If the count still bites, far scrub can take a new non-sway name, which needs no code (plants take no grain).
7. **The plants' image is useless.** 289 meshes at 9.4 px per metre with no pad. Simplest: never paint it.
8. **No vertex colours, normal maps, emission, or alpha.** The strata are separate materials and real geometry, every gap is cut, and no scrub is an alpha card. Cost: triangles and draw calls, both budgeted.
9. **Names set behaviour.** Never give rock a sway name. Exact values and one roughness merge materials, but only within one GLB: the importer's cache starts empty for each.
10. **The fog is a scene edit.** The decided fix (F1) is three properties in `canyon.tscn` (density, begin, end), outside "model and UV unwrap". Cost: a line, plus a flat-run look.
11. **A split would cost scene work.** Five GLBs would need five `.glb.import` files copied from `canyon.glb.import` (`import_script/path` and `gltf/embedded_image_handling=3`, or `load` fails), instance nodes in `canyon.tscn`, and `canyon.glb` retired, and would buy nothing for painting while the rock tiles. Decided: one GLB (F13).
12. **Blender cannot judge the light.** The banded sun, the shade wall, the long shadows, and the fog only show in Godot. Simplest: one flat run per reviewed asset at all four times.
13. **The texturing docs go stale.** `docs/TEXTURE_LIST.md` and `docs/TEXTURING.md` (the Canyon rows: "102 rock blocks and two sand planes", 289 meshes at 9.4 px per metre) will be wrong after the build. Simplest: refresh them from the script's printout.

The trim sheet, its texel-density targets, and the texture ripper play no part in this sheet.

## H. As built

### Cliffs (hero)

Built on 2026-10-23 in `canyon.blend` by `dev/build_canyon_finals_blender.py` and exported by `dev/unwrap_per_glb_blender.py`, untextured:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b assets/models/scenarios/canyon/canyon.blend --python dev/build_canyon_finals_blender.py -- --part cliffs
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map canyon --relayout
```

The script deletes the 62 greybox cliff visuals on its first run. It then deletes and rebuilds the `CanyonCliffs` empty under `canyon` with four merged objects, writes the palette (A) on the six shared materials, and saves. It is deterministic, seeded by wall and segment index, and re-runnable: a second run gives the same 7,948 triangles. The cover rocks, floor, rim, and horizon are still greybox and already show the new colours.

- **Tests:** `--import`, then `load`, `multi`, `ragdoll`, and `gauntlet`: all print `AUTOTEST PASS`.
- **Unwrap:** `GLB canyon [canyon]: 289 meshes, 1455 islands, 9.4 px/m at 256 px (pad 0, 86% covered, 46 tiling meshes untouched); 0 materials copied; image none (flat colour)`. Only the plants get per-GLB UVs. The four cliff objects carry 8 m tiling UVs from `scenery_uv.unwrap_object` (`uv_role` `tiling`), with rotation zero and the origin at the canyon's origin.
  - UV islands, counted in the `.blend`: `Cliffs_Rock` 528, `Cliffs_RockDark` 568, `Cliffs_CapDark` 57, `Cliffs_Cap` 353. The tiling projection runs along each face's dominant axis, so islands follow face direction, not pieces.
- **Collision:** unchanged.
  - All 85 proxies keep their names and boxes: compared node by node with the greybox GLB dump, the largest difference is 0.0000 m.
  - None overlaps the shot band or a spawn pad (the build script runs the G5 box test on every proxy), and no cliff vertex enters them.
  - The 62 cliff proxies stay where they were, directly under `canyon`.
- **Scene edit:** in `canyon.tscn`, `fog_density` 0.012 → 1.0, `fog_depth_begin` 60 → 80, and `fog_depth_end` 220 → 400. Nothing else in the scene changed.
- **Fog, before and after** (BUG-031). Pixels from flat captures of Lane P, centre column, outside the repo:

| Fog | Plain at dusk | Plain at dawn | Mesa5 at dusk | Reads as |
|---|---|---|---|---|
| Before: density 0.012 | (204, 94, 55) | (204, 124, 98) | (255, 105, 46) | A darker band, behind the enemy from the shins to the chest, under a bright edge line (242, 140, 71); the sky at the horizon is (240, 128, 64) |
| Density 1.0, begin 60, end 220 | (243, 140, 71) | (237, 153, 112) | (250, 140, 71) | No line: the plain matches the horizon. Mesa5 is close to the fog colour |
| Density 1.0, begin 80, end 400 (the user's call) | (243, 140, 71) | (237, 153, 112) | (255, 140, 62) | No line, and Mesa5 keeps more of its body |

- **Views:**
  - Blender renders: Front from the lane at y −8, 0, and 8 facing each wall (50 mm, pitched 32°); Three-quarter per wall; Silhouettes of the skyline from mid-lane 30° up, of each wall's cap line 50° up, and of each wall in profile along Y; 64 px squints of the Fronts and Three-quarters.
  - Flat Godot captures at dawn, noon, late afternoon, and dusk: Lane P, Lane E, Up (each wall), Toe (each wall), and the four Flank views.
  - All are outside the repo. The headset review is open.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `canyon` (`CanyonCliffs` group) | 7,948 / 16,000 | 4 | 1 |

| Object | Material | Triangles | Faces | Holds |
|---|---|---|---|---|
| `Cliffs_Rock` | `M_Rock` (vermilion) | 3,133 | 933 | West body, teeth, pillars, back, and rubble |
| `Cliffs_RockDark` | `M_RockDark` (pink) | 3,295 | 1,020 | East body, teeth, pillars, back, and rubble |
| `Cliffs_CapDark` | `M_CapDark` (violet) | 261 | 94 | The band on both walls |
| `Cliffs_Cap` | `M_Cap` (bone) | 1,259 | 459 | Cap blocks; tooth and pillar caps; one apron block in three; fallen blocks; one rubble stone in three |

**How it is built.**

- Every piece is a closed prism over a grid-snapped plan: slabs, chamfered blocks, pillars, and the 35° wedges as prisms along Y. A 45° chamfer is an inset top ring.
- One exact self-union per wall deletes every buried face and every overlap. The joint and wear boxes are then subtracted.
- The result is cut at z 0. The faces that look out over the drop at x ±15.5 are deleted, and coplanar neighbours are dissolved into n-gons per material.
- A seeded search sets each layer's distance proud of or behind the wall proxy's front, on the 0.25 m lattice, so every rule below holds at once.

**Checks** (scratch scripts run against the saved `.blend`; numbers from the final build):

- **Shadow rule:** rays toward the sun at 8, 70, 32, and 12° against every visible mesh.
  - At all four times, a disk 0.4 m round each spawn mark is entirely lit from 0.05 to 1.9 m.
  - The nearest shadow at chest height is 0.90 m from `EnemySpawn` at dawn (`EastTooth1`), 1.10 m at dusk (segment 0 of the east wall), and 2.9 m in the late afternoon. None falls within 3 m of `PlayerSpawn`.
  - The Ghost's east strafe is shaded beyond x 0.9 at dawn and x 1.1 at dusk, as F17 keeps (the greybox: about 0.7).
  - `EnemySpawns2/B` is in shadow at dawn and dusk, as before. New: `EnemySpawns3/C` is in shadow at dawn. It is a three-NPC marker; the rule covers only the spawn marks.
- **Below 2.2 m (the 0.15 m rule):** 3,715 samples on cliff faces the lane can see, through unobstructed rays to eyes at x 0 and 1.7 m up, every 2 m along the lane.
  - 78.2% lie within 0.15 m of a cliff proxy's surface; 7.2% are more than 0.25 m off; none is more than 0.5 m off.
  - The worst are the 35° wedges: 0.27 m above a talus proxy's top at the West6 / West7 junction, and 0.47 m behind the wall proxy's front where a wedge meets the wall foot.
- **Above 2.2 m (0.5 proud to 1.0 inside):** 97.6% of 23,535 samples lie inside the window. The rest:
  - The cap blocks' ends, which run 0.5 m past the cap proxies' ends: up to 0.95 m from any proxy, 17 m up.
  - The cap gaps' side faces, cut through the cap's full depth: up to 1.52 m inside.
- **No shared planes:** 158,057 coplanar triangle pairs tested between the cliffs and every visible mesh in the GLB; none overlaps.
- **Mesh:**
  - No dots in names and no duplicates.
  - No zero-area triangles, no non-planar faces, no smooth faces.
  - No face wholly under the floor or past x ±15.92.
  - 66% of vertices sit on the 0.25 m grid. The rest are chamfer insets, tilted blocks, and the union's cut lines.

**Skyline tops** (both walls, segments 0 to 7): 14.0, 11.75, 17.5, 16.0, 14.0, 12.0, 16.25, 15.5 m.

**Wear, one accent per segment** (detail 9):

| Accent | Segments |
|---|---|
| Chipped cap corner | West0, West5, East1, East6 |
| Fallen block | West1, West6, East0, East5 |
| Joint open to the sky | West2, East3, East7 |
| Undercut | West3, West7, East4 |
| Leaning pillar block | West4, East2 |

**Where the build departs from B.** Most departures come from the 1.5 m proxy window (0.5 m proud to 1.0 m inside) meeting rule 4's steps of 0.3 m or more on a 0.25 m grid.

- **Strata pattern.**
  - The lower body, 2.5 to 7.0 m, is four layers: thick slabs (1.25 to 1.5 m) whose fronts carry the turned planes, and thin straight ledges (0.75 to 1.0 m) set back 0.5 m or more behind them.
  - Each thick slab's top gets a 0.25 m 45° chamfer, the lit line. The ledge above it reads as a dark notch.
  - The first builds stepped every slab in and out on the same sawtooth, and the walls read as brickwork.
  - East1 and East6 cannot fit that pattern in their window. They fall back to five layers with proud ledges.
- **Band.** The band stands 0.5 m proud of the ledge under it. In 14 segments it sits behind the thick slab below that ledge and under the upper body's overhang, so it reads as a violet stripe in a groove. It runs unbroken along each wall and steps only where the segments do.
- **Turned planes.**
  - Two per segment, each 20.6 to 23.2° (0.75 m over 1.75 to 2.0 m of wall), or 18.4 to 21.8° (0.5 m over 1.25 to 1.5 m) where the window is tight.
  - 15° would lie along the sun's azimuth and never light the east wall. Steeper turns make the planes shorter than 1.9 m inside the window.
  - Angles are what the grid gives, not exact 15° steps.
- **Upper body.** Straight fronts with flutes, not turned planes: a sawtooth plus flutes plus steps does not fit in 1.5 m. The flutes have a 1.0 m pitch and 0.25 m valleys, so their faces stand 26.6° off the wall (B: ±30°), and they carry the two light steps.
- **Cap.**
  - Two blocks per segment, 1.5 to 2.25 m long, with a 0.5 m sky gap (B: joints every 2 to 4 m).
  - Each block's front turns like a main plane, by 0.5 to 0.75 m. Its overhang over the flute ridges therefore runs from 0.5 to 0.75 m at its north end to about −0.25 m at its south end.
  - On the even segments the cap stops 0.5 m past the cap proxy's ends.
  - One block per segment rises or drops 0.5 to 0.75 m as the skyline feature, kept 0.6 m from the neighbours' tops. West6 and East6 have none, because no height fits both their proxy and segment 7. Their features are the gap and, on East6, the chipped corner.
  - Segments 6 and 7 are 16.25 and 15.5 m tall, not their proxies' 16.12 and 16.09, to keep 0.6 m between them.
- **Window slack.** The search allows 5 cm past the window and steps of up to 1.25 m (rule 4: 1.2 m), because grid points fall up to 0.125 m off the proxies' faces.
- **Talus apron.**
  - The front blocks are 1.5 to 2.5 m tall, not 0.8 to 1.8 m: each matches the talus proxy's top within 0.15 m, or stands up to 0.5 m above it where that top is above 2.05 m. That way the lane-facing rock fills its proxy.
  - Blocks are 0.75 to 1.0 m deep, with 0.25 m chamfers on the lane-side corners that leave V notches 0.25 m deep between them.
  - One block in three is bone, tilted back 4°.
  - The 35° wedge rises from 0.25 m under the blocks' tops to 2.25 or 2.5 m. It cannot stay within 0.15 m of box proxies (see Checks).
- **Pillars.**
  - 15 extra pillars, on every segment but East7. Each is two body blocks, the upper inset 0.25 m on the front and one side, under a bone cap block; tops 5.25 to 6.75 m.
  - They stand on the talus 1.0 m behind its front, at most 0.15 m proud of the wall proxy, so they read as buttresses where the wall behind them is set back.
  - East1's pillar stands behind `EastTooth1`, since the segment has no room beside it.
  - The five greybox teeth: a block filling the proxy to 2.5 m, a block inset 0.25 m on the lane and north sides to 4.0 m, and a bone cap to 4.75 m (0.05 m above the proxy). Each takes its own wall's colour; the greybox had them swapped.
- **Joints.** One to three per segment (East3 has one), 0.5 m wide and 0.5 m deep, through one to three lower layers. Pillars, fallen blocks, and undercuts block them only up to their own tops.
- **Rubble.** 0.5 × 0.3 × 0.3 m blocks tilted 12° inside their proxies and sunk 5 cm. Their 0.08 m chamfers follow rule 8's quarter of the smaller side, under the 25 cm floor. They are centred on the proxies rather than on the grid. One in three is bone.
- **Ends and backs.**
  - At the canyon's two ends, every other layer of segments 0 and 7 stops 0.5 m short, so the end faces step.
  - Each back is one body block from its inner face to x ±15.5, 12.5 m tall (1.0 m under its proxy), with a 0.5 m chamfer. It shows only above segments 1 and 5, and only from far off.
- **Booleans.** The vocabulary rules out slivering booleans. The union adds no shapes; it only removes buried faces and overlaps. Ten faces whose outlines hold T-junction points tessellated to zero-area triangles, so those faces alone are split into triangles (beauty method). That breaks "one planar n-gon per flat region" for them (the Saloon's build lesson).
- **Triangles.** 7,948 of 16,000. The window, the grid, and the 25 cm floor cap how many pieces fit; more pieces would mean smaller ones.
- **Build order.** Every iteration built all 16 segments from the one generator, and Lane P, which looks down segments 4 to 7 of both walls, was checked at each step. Segments 5 to 7 were not built alone first.

**Found while reviewing.**

- **The shade wall shades itself.** The light table in Scene facts gives the east wall's turned planes the middle step at dawn and dusk. In Godot most of the east wall is in shadow then anyway. The sun's azimuth is only 15° off the wall line, so every tooth and proud segment shades the faces north of it for about 3.7 m per metre it stands out.
  - At dawn and dusk the east wall reads as dark ledge lines with a few lit edges: a pattern, not a black field (D13).
  - At noon its flutes stripe and its chamfers light.
- **The floor at noon.** `M_Sand` (Main Street's street dirt) draws close to white in the noon sun under the grain. The floor's own review (C step 3) should look at it. Taken up in Floor below.

**Tunnel fix and outer faces** (2026-10-24, with the rim; same command):

- Batch 2 found tunnels under the wall slabs, which start 1.0 m up: from z 0 to 1.0, between the talus wedges and the backs, open at the walls' ends and seen from the end strips. Each segment now adds one fill block from 3.0 m behind its talus toe (inside the 35° wedge, which runs to 3.5 m) back to x ±15.5, from under the floor to 1.0 m, over the wall proxy's length. The union joins it to the wedge and the first slab, so the walls' ends close from the floor up. Its front stays inside the wedge: nothing the lane sees moves. No proxy changed; none enters the shot band or a pad.
- The faces that look out over the drop at x ±15.5 are no longer deleted. From a rim corner, leaning past `RimWest` or `RimEast`, they showed the inside of every slab; over the rim's west and east faces they are now the walls' outer sides.
- Triangles: 8,118 (was 7,948): `Cliffs_Rock` 3,169, `Cliffs_RockDark` 3,332, `Cliffs_CapDark` 277, `Cliffs_Cap` 1,340. Re-runs give the same count; UV islands 510, 552, 59, 383.
- Checked with the rim's sightline test below: no cliff underside between z 0 and 1 is seen from any reachable eye at the ends.

**Still open:**

- The user's review of the hero, then a headset: D items 10 to 17, and the cliffs' asset check with the other assets final.
- Closed: the horizon (C step 5); the cover rocks, floor, rim, and horizon are built (below).
- Quest timing for the merged cliffs as shadow casters in every cascade at dusk (B).

### Cover rocks

Built on 2026-10-23 in `canyon.blend` by the same script and exported the same way, untextured:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b assets/models/scenarios/canyon/canyon.blend --python dev/build_canyon_finals_blender.py -- --part cover
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map canyon --relayout
```

The first run deletes the 12 greybox visuals (the six `Cover*` and their `*Chip`). Each run then deletes and rebuilds the `CanyonCover` empty under `canyon` with two merged objects and saves. It is deterministic, seeded by rock index: a re-run gives the same 656 triangles, and `--part cliffs` still gives 7,948.

- **Tests:** after the final export and `--import`: `load`, `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`.
- **Unwrap:** `GLB canyon [canyon]: 289 meshes, 1455 islands, 9.4 px/m at 256 px (pad 0, 86% covered, 36 tiling meshes untouched); 0 materials copied; image none (flat colour)`. The 36 are the 4 cliff objects, the 2 cover objects, the floor, and 29 greybox rim and horizon boxes. Both cover objects carry 8 m tiling UVs from `scenery_uv.unwrap_object` (`uv_role` `tiling`), with rotation zero and the origin at the canyon's origin. UV islands in the `.blend`: `Cover_CapDark` 68, `Cover_Cap` 48.
- **Collision:** unchanged. The six `Cover*-convcolonly` proxies keep their names and boxes. All 85 proxies match the greybox GLB dump node by node (no line differs). None overlaps the shot band or a pad, and no cover vertex enters them.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `canyon` (`CanyonCover` group) | 656 / 1,500 | 2 | 1 |

| Object | Material | Triangles | Faces | Holds |
|---|---|---|---|---|
| `Cover_CapDark` | `M_CapDark` (violet) | 352 | 124 | The six bodies, two tiers each |
| `Cover_Cap` | `M_Cap` (bone) | 304 | 86 | The six lids |

**How it is built.**

- One generator, seeded per rock. For each rock a search of up to 400 tries fits three stacked prisms inside the proxy, all measured in 2.5 cm steps in from the proxy's faces:
  - a lower tier, every face 0 to 5 cm in, from 5 cm under the floor;
  - an upper tier, its lane and end faces stepped in 5 to 10 cm more (the strata step, detail 3) and never more than 10 cm from the proxy, its back stepped in 7.5 to 10 cm more at one end;
  - a bone lid 0.25 to 0.35 m thick, its top 0 to 5 cm under the proxy's top, overhanging the upper tier 5 to 10 cm on the lane side and 2.5 to 5 cm elsewhere, sunk 2 cm into it and tilted 1.5 to 3.1° (its low side 5 to 8 cm down).
- Every vertical edge has one 45° chamfer of 10 to 15 cm, picked so that each cut stays within 0.15 m of the proxy.
- A try is kept only when every piece lies inside the proxy and every sampled face that looks at a lane eye (x −1.6, 0, 1.6; 1.7 m up; every 2 m) below 1.7 m lies within 0.15 m of the proxy's sides or top.
- The chip (detail 4) is a 45° plane cut 15 to 25 cm off one top corner of the lid, as a bone boolean difference.
- The joint (detail 6): `CoverWPlayer` and `CoverEMid` are built as two halves 10 cm apart across the rock. The lid's halves overhang the joint by 1.25 cm a side.
- One exact self-union for all six (the cliffs' `union_wall`), cut at z 0, coplanar neighbours dissolved into n-gons, split by material.

| Rock | Strata step at | Lid (proxy top) | Lid tilt | Chamfers: lower, upper, lid | Chip | Joint |
|---|---|---|---|---|---|---|
| `CoverWPlayer` | 0.775 m | 1.46 to 1.71 m (1.71) | 2.3°, across the lane | 0.125, 0.10, 0.125 | Lane side, north, 0.15 m | y −6.125, turned −15° |
| `CoverEPlayer` | 0.70 m | 1.435 to 1.735 m (1.76) | 3.1°, along the lane | 0.125, 0.10, 0.10 | Lane side, south, 0.20 m | |
| `CoverWMid` | 0.575 m | 1.06 to 1.31 m (1.36) | 2.7°, along the lane | 0.15, 0.10, 0.10 | Lane side, south, 0.20 m | |
| `CoverEMid` | 0.75 m | 1.485 to 1.835 m (1.86) | 2.5°, along the lane | 0.125, 0.10, 0.125 | Back, north, 0.20 m | y −0.55, square |
| `CoverWEnemy` | 0.575 m | 1.21 to 1.56 m (1.61) | 1.5°, across the lane | 0.10, 0.10, 0.10 | Back, north, 0.20 m | |
| `CoverEEnemy` | 0.50 m | 1.06 to 1.41 m (1.41) | 3.1°, across the lane | 0.15, 0.10, 0.125 | Lane side, north, 0.20 m | |

**Checks** (scratch scripts run against the saved `.blend`):

- **The 0.15 m rule:** 6,263 samples on cover faces below 1.7 m that a lane eye sees (rays against every visible mesh): 100% within 0.15 m of a cover proxy's sides or top (worst 0.147 m). The two joints' walls are the exception: 427 samples, 24.8% within, up to 0.83 m in, where a ray from abeam looks straight into the 10 cm joint. No sample lies outside the proxies.
- **No shared planes:** 1,799 coplanar triangle pairs between the new objects and every visible mesh; none overlaps. The cover bases have no face at z 0.
- **Mesh:** no dots in names and no duplicates; no zero-area triangles, no non-planar faces, no smooth faces. Where the tilted lid crosses the upper tier's chamfer corners, the union leaves a few millimetre-sized triangles on the lids' undersides and seams (smallest about 0.00001 m²). None faces up.
- **Squint and silhouette:** each rock reads as one violet block under a pale lid, two flats, from `PlayerSpawn` and from the lane abeam.
- **In Godot** (flat captures, four times): the violet body and bone lid read against the floor and both walls at every hour. Luminance contrast of the body against the floor in Lane P: 1.43 at dawn, 2.77 at noon, 2.28 in the late afternoon, 1.17 at dusk. At dusk hue does the work (wine body, orange floor) along with the bone lid.

**Where the build departs from B.**

- **Turns.** Faces turn 0.7 to 3.1° off the axes, not up to 8°. A face turned further leaves part of a lane-visible face, its chamfer, or the back ledge (seen past the rock's end from far down the lane) more than 0.15 m inside the proxy. The rocks differ by their tier heights, lid thickness and tilt, chamfers, chips, and joints instead.
- **Grid.** Insets and heights snap to 2.5 cm off the proxy's faces, not the 0.25 m lattice, which lands up to 0.125 m off them.
- **Chips.** Six rocks share four corners: the three rocks on each wall chip three different corners.
- **Lid overhang.** The lid overhangs the upper tier on every side (B: the lane side), 2.5 to 5 cm off the lane side, so no lid face shares the upper tier's plane. The first builds left sliver faces there.
- **Triangles.** 656 of 1,500, about 110 a rock. All six details are built (the banks, detail 5, belong to the floor). More pieces would not fit the 0.15 m window.

**Still open:** the user's review, then a headset: walk to each rock, crouch behind it, and check D16 at all four times.

### Floor

Built on 2026-10-23 by the same script, untextured:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b assets/models/scenarios/canyon/canyon.blend --python dev/build_canyon_finals_blender.py -- --part floor
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map canyon --relayout
```

The first run deletes the greybox `Floor` visual. Each run then deletes and rebuilds the `CanyonFloor` empty under `canyon` with one object, writes the palette (now with the floor's new value), and saves. It is deterministic (one seed): a re-run gives the same 267 triangles.

- **Tests, unwrap:** as for the cover rocks above (one export covers both). `Floor_Sand` carries 8 m tiling UVs (`uv_role` `tiling`, rotation zero, origin at the canyon's origin); 71 UV islands in the `.blend`.
- **Collision:** unchanged. `Floor-convcolonly` keeps its box (32 × 29.2 m, z −1 to 0). The banks and steps have none: feet sink up to 0.3 m into a bank and 0.15 m into a step.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `canyon` (`CanyonFloor` group) | 267 / 400 | 1 | 1 |

| Object | Material | Triangles | Faces | Holds |
|---|---|---|---|---|
| `Floor_Sand` | `M_Sand` (desert dirt) | 267 | 107 | The top, the rim edge, 4 bedrock steps, 11 sand banks |

**How it is built.**

- **Top:** one planar n-gon at z 0 of 71 points (collinear points dropped), and no bottom.
  - Between y −9 and 9 its sides run 1 m (on the 0.25 m grid) in under the frontmost talus proxy's front. Each side steps halfway along each overlap of two talus proxies, and sits behind the deepest front of its stretch.
  - Beyond |y| 9 it runs out to x ±16. Under the wall slabs, which start 1.0 m up, the cliffs leave a tunnel between the talus wedges and the backs. It is open at the walls' south ends, at the east wall's north end, and behind the west back's end, so the floor must show in it.
- **Rim edge** (detail 1): the ends stay at y ±14.6 and are straight within |x| < 3.5 (the north end from x −3.5, the south end within ±4.75). Outside that are eight notches, 1.25 to 2.5 m wide and 0.3 or 0.75 m deep, with sides at 45 to 90° and some mouth corners chipped 0.25 m:
  - south: x −11.5 to −10.0, 5.0 to 6.5, 8.0 to 9.5, 11.0 to 12.25;
  - north: x −11.5 to −9.0, −5.0 to −3.5, 8.5 to 9.75, 11.75 to 13.25.
  - The four corners at x ±16 are chipped 0.5 to 1.0 m, and the notches keep 0.35 m clear of the lip stones.
  - The edge faces drop 0.24 m along both ends and along x ±16 beyond |y| 9 (45 faces).
- **Bedrock steps** (detail 4): four slabs with vertical sides and two corners cut at 45°: x −4.5 to −2.75, y −11.0 to −8.75, 0.15 m; x 2.75 to 5.0, y −7.25 to −4.75, 0.10 m; x −4.25 to −2.75, y 2.25 to 4.75, 0.125 m; x 2.75 to 4.5, y 7.0 to 10.0, 0.15 m.
- **Sand banks** (detail 3): eleven wedges, each one sloped face and two end triangles, open at the back and bottom.
  - Six sit behind the cover rocks: 0.15 to 0.2 m tall, reaching 0.65 to 0.9 m toward the wall, to the talus front or 10 cm short of a tooth or stone.
  - Five sit along talus fronts (`WestTalus6`, `EastTalus0`, `EastTalus2`, `EastTalus3`, `EastTalus6`): 0.15 to 0.3 m tall, 1.0 to 1.5 m out, 1.5 to 2.0 m long.
  - Each ridge lies on its proxy's face. No bank enters a proxy, comes within 1.55 m of a marker, or comes within 0.2 m of a rock, a step, or another bank, or within 5 cm of a tooth, stone, lip stone, or rim wall.

**Checks:**

- **Height:** at 14,697 points, the floor's top is at z 0 at every one. The points cover |x| < 2.5 along the floor's whole length, and rings 0, 0.5, 1.0, and 1.5 m round all six markers. The only visible mesh above z 0 at those points is the greybox lip stone `SouthLip1` (x −2.5 to −1.9), which is the rim's.
- **Under rock:** 796 samples along the floor's side edges. None is open on the lines under the talus. 85 lie on the steps at y ±9, inside the closed parts of the tunnels.
- **Proxies:** no raised floor vertex inside any proxy, and no floor vertex in the shot band or a pad.
- **No shared planes:** the coplanar test above covers the floor too. Neither the talus nor the cover rocks have a face at z 0.
- **Mesh:** no zero-area triangles (the smallest is 0.015 m²), no non-planar faces, no smooth faces.

**The floor's colour.** The decided `M_Sand`, Main Street's street dirt, draws white at noon. Values on the same hue were tried in flat captures of the Down view (Lane P's eye pitched 50° down), from it down to Main Street's desert dirt (t 0 to 1):

| `M_Sand` | Floor pixels with a channel at 255: dawn / noon / late afternoon / dusk | Lit floor, measured |
|---|---|---|
| Street dirt #DDC499 (0.72, 0.55, 0.32), decided | 0.4% / 98.4% / 98.4% / 0.6% | #E29473 / #FFFFFF / #FFFED7 / #E26D43 |
| t 0.25, 0.5, 0.75 | noon 94%, 82%, 61% | |
| Desert dirt #B8A281 (0.48, 0.36, 0.22), built | 0% / 28.7% / 29.6% / 0% | #BA785F / #F7F5E8 / #F7DAB6 / #BB5735 |
| Below the range, (0.42, 0.31, 0.195) and (0.384, 0.284, 0.18) | noon 4.5% and 0.3% | |

- No value in the allowed range keeps the noon floor off white. The noon sun lifts the floor to about 1.9 times its red and 3.6 times its blue with the sky's light, and the grain adds 20%, so clipping stops only near a linear red of 0.37, below Main Street's grounds.
- Built: desert dirt, the darkest value allowed and the ground Main Street's street stands on (`env_terrain`, `M_DirtFar`). It departs from the decided value (A, Palette; E: `M_Sand` took the street dirt). At noon the floor now reads as grained sand instead of a white field.
- `M_Sand` now equals `M_SandFar`. Rule 24 still holds: the ground keeps a Main Street value.
- Against the walls and the cover rocks, in Lane P: the luminance contrast of floor to violet body falls from 2.06 / 3.15 / 2.98 / 1.66 to 1.43 / 2.77 / 2.28 / 1.17. Floor to vermilion wall falls from 1.60 / 3.57 / 3.28 / 1.20 to 1.10 / 3.10 / 2.47 / 1.19.
- At dawn and dusk hue separates them: orange-brown floor, wine body, saturated vermilion wall, and the bone lids.

**Where the build departs from B.**

- **Colour:** desert dirt, not street dirt (above).
- **Notches** at most 0.9 m deep (B: up to 1.2; built 0.3 and 0.75). The rim walls' inner faces stand at y ±13.92, so a body pressed against one stands to y ±13.62, and a deeper notch would put it over empty space.
- **Under the cliffs** the floor is deleted only for |y| ≤ 9, and only behind 1 m of talus; beyond that it stays under the tunnels' open ends.
- **Banks.** Only one west talus bank (`WestTalus6`): teeth, stones, the steps, and the cover rocks' own banks take the other west fronts. Each bank's back is open: it would only face the rock. Where a snapped talus block stands up to 0.12 m behind its proxy's front, a slot of floor shows behind the ridge.
- **Triangles:** 267 of 400.

**Still open:**

- Closed: the notches' slots over the hollow butte, by the rim, whose top edge follows them (Rim, below).
- Closed: the tunnels under the wall slabs, by the cliffs' fill (Cliffs, above).
- The noon floor is still bright: 29% of its near pixels touch white in a channel. Decided: accept it (F20) and revisit in the headset.
- The user's review, then a headset.

### Rim

Built on 2026-10-24 by the same script, untextured:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b assets/models/scenarios/canyon/canyon.blend --python dev/build_canyon_finals_blender.py -- --part rim
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map canyon --relayout
```

The first run deletes the 12 greybox rim visuals (`SouthFace`, `NorthFace`, `WestFace`, `EastFace`, `SouthLip0`–`3`, `NorthLip0`–`3`). Each run then deletes and rebuilds the `CanyonRim` empty under `canyon` with four objects and saves. It is deterministic (one seed): a re-run gives the same 1,611 triangles. `--part cliffs` now gives 8,118 (the tunnel fix above); `--part cover` and `--part floor` still give 656 and 267, and their meshes are identical to batch 2's, vertex for vertex.

- **Tests:** after the export and `--import`: `load`, `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`.
- **Unwrap:** `GLB canyon [canyon]: 289 meshes, 1455 islands, 9.4 px/m at 256 px (pad 0, 86% covered, 28 tiling meshes untouched); 0 materials copied; image none (flat colour)`. The 28 are the 4 cliff objects, the 2 cover objects, the floor, the 4 rim objects, 16 greybox mesa boxes, and the desert plane. All four rim objects carry 8 m tiling UVs (`uv_role` `tiling`, rotation zero, origin at the canyon's origin): three tiles down each face. UV islands in the `.blend`: `Rim_Rock` 146, `Rim_RockDark` 143, `Rim_CapDark` 22, `Rim_Cap` 40.
- **Collision:** unchanged in this build. The four face proxies, the four `Rim*` walls, and the eight lip proxies keep their boxes. All 85 proxies match the greybox GLB dump node by node (no line differs). None overlaps the shot band or a pad, and no rim or cliff vertex enters them. Batch 5 moved the face proxies and added 80 boxes (F22; below, Collision follows the faces).

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `canyon` (`CanyonRim` group) | 1,611 / 2,000 | 4 | 1 |

| Object | Material | Triangles | Faces | Holds |
|---|---|---|---|---|
| `Rim_Rock` | `M_Rock` (vermilion) | 657 | 196 | The south and east faces, the SW and SE chamfers, their ledges, skirt, and fallen blocks |
| `Rim_RockDark` | `M_RockDark` (pink) | 633 | 182 | The north and west faces, the NE and NW chamfers, their ledges, skirt, and fallen blocks |
| `Rim_CapDark` | `M_CapDark` (violet) | 145 | 28 | The band, −6.0 to −7.25 m, all round |
| `Rim_Cap` | `M_Cap` (bone) | 176 | 72 | The eight lip stones |

By part: the faces 773 and their ledge tops and undersides 524 (1,297 of 1,300), the skirt 138 of 400, the lip stones 176 of 300. The build's own printout, which counts six wedge-end triangles against the faces, says 1,303 and 132.

**How it is built.**

- **Strata** (detail 1): ten closed prisms stacked over the butte's whole plan, so the union has no inside faces. Proudness is off the face proxies' inner faces (x ±15.92, y ±14.52):

| Layer | z (m) | Proud | Note |
|---|---|---|---|
| `U0` | −0.15 to −2.25 | 0 | Its plan is the floor's rim outline 8 cm inside: both ends with their eight notches and chipped mouths, the floor's 0.5 m corner chips, x ±16 beyond |y| 9 (detail 4) |
| `U1` | −2.25 to −4.25 | 0.5 | In a notch it stands 0.8 or 1.25 m proud of `U0`: a ledge under the notch |
| `U2` | −4.25 to −6.0 | 0 | |
| Band | −6.0 to −7.25 | 0.5 | Violet, the cliffs' band 0.5 m proud of the slab under it |
| `U3` | −7.25 to −9.25 | 0 | Under the band, so the band reads as a stripe over a groove. The drop is 9.1 m |
| `M0` | −9.25 to −11.75 | 2.25 | The first ledge, 1.75 to 2.75 m wide |
| `M1` | −11.75 to −14.0 | 2.75 | |
| `M2` | −14.0 to −16.5 | 2.25 | The middle drop is 7.25 m |
| `L0` | −16.5 to −18.75 | 4.5 | The second ledge, 2.25 m wide |
| `L1` | −18.75 to −24 | 5.0 | Mostly behind the skirt |

- **Bays:** each drop (U, M, L) shares one set of bays per face, 7 to 11 m wide, each 0.25 m proud of or behind its neighbours (end bays at 0), so joints run down each drop and every strata step stays exactly 0.5 m. The lower drop has one plane per face.
- **Corners** (detail 3): one 45° chamfer per corner on every layer below `U0`: SW 1.25, SE 1.5, NE 1.25, NW 1.25 m. `U0` keeps the floor's 0.5 m chip.
- **The crest:** beside the cliffs (|y| < 9), where the floor stops under the talus, the top rises to z 0 from x ±15.25 (under the cliffs' backs at ±15.5) to the face, so the cliffs' outer faces stand on rock and no slot opens under them.
- **Skirt** (detail 2): 35° wedges on the plain, 4 to 7 m long, their toes 6 m out at the corners and 7 to 9 m between, neighbours 1 m or more apart. Each wedge's back is buried 3 m inside the face and its top turns flat 1 m (corners 2.5 m) inside, under the ledges. The end wedges are mitred on each corner's 45° bisector, so the skirt turns the corner in a hip.
- **Wear** (detail 6): one fallen block on each ledge of each face (8): 1.0 to 1.25 × 0.75 to 1.0 × 0.75 to 1.0 m, corners chamfered 0.25, tilted 10 to 15° about the inner bottom edge, sunk 0.25 m, 0.25 m off the face above. Body colour (they fell from the face).
- **Lip stones** (detail 5): bone blocks with their vertical edges chamfered 7.5 to 10 cm, tilted 6 to 14° about a bottom edge (alternately the long and the short one), sunk so the lifted edge stays buried, and centred in the proxy. Every corner above the floor lies inside its proxy; the largest gap to the proxy's sides or top is 2.6 to 3.2 cm.
- One exact self-union, cut at the plain's top (z −24: no face on it); the top at −0.15 (under the floor) and the crest's inner sides and ends are deleted.
- **Colour** (rule 17): the faces split by side. The ledges, rings round the butte, are cut first along the SE–NW diagonal and at the SW and NE chamfers' outer ends, so each chamfer keeps one colour down its whole height and its ledges: SW and SE vermilion (they take sun), NE and NW pink. The skirt's slopes take the colour of the side they face.

**Checks** (scratch scripts against the saved `.blend`):

- **Hollow and seams:** 741 eyes on the end strips (standing, crouched, and leaning 0.5 m past the rim walls, only where a body fits), 7.9 million rays: no first hit shows the inside of the rim or the cliffs, or the plain under the butte. Five grazing rays hit the open back of a floor sand bank (by design, batch 2). 1,575 rays from leaning eyes to points just under the floor's rim edge, notches included: every one lands on the rim's face.
- **Tunnels:** no cliff underside between z 0 and 1 is seen from those eyes (before the fix, a first ray test saw them from the north end strip and both north corners).
- **No shared planes:** 186,392 coplanar triangle pairs between the rim and cliffs and every visible mesh: none overlaps. The faces stand 8 cm behind the floor's edge faces; the crest's top meets the floor only along y ±9; nothing lies on the plain's plane.
- **Floor:** z 0 at all 14,697 points. The only visible mesh above it there is the lip stone `SouthLip1` (x −2.5 to −1.9), as before.
- **Hidden faces:** no rim face lies under the floor. 23 small faces (7.2 m²) were never hit from the end strips, the plain round the butte (35 to 120 m, 1.7 to 54 m up), or straight on: the fallen blocks' sides against the face, short bay returns under the band, and three slivers under `NorthLip3`.
- **Lip stones:** the 0.15 m rule from the lane: 460 visible samples, all within 0.15 m of their proxy (worst 0.135).
- **Mesh:** no dots in names, no duplicates; no zero-area triangles, no non-planar faces, no smooth faces. One face split into triangles (beauty).

**Views** (outside the repo): Blender Front views of each face from the plain 70 m out, the SW corner, silhouettes, 64 px squints, the look-downs from the north and south rims and the SW and NE corners (leaning 0.5 m past the rim wall, 60° down, out and along the face), and notch close-ups. Flat Godot captures at dawn, noon, late afternoon, and dusk of the Rim views (level and 60° down, plus leaning), Lane P, Lane E, both corners, and the plain.

- From the Rim views at 13.6 m the drop shows only as the butte's shadow on the plain: the floor's edge hides everything steeper than 59°, and the ledges sit 74° down. Leaning, the face, the ledges, and the skirt show, the pink north face in shade at every hour, its ledge tops lit at noon.
- From the corners the south face reads as stepped strata over the ledges and skirt.
- In Lane P and Lane E the floor's far edge stays one clean line behind each duelist's shins; the lip stones show as small bone blocks.
- The silhouette from the plain is a stepped butte on a skirt; the squint gives body, band, and skirt.

**Where the build departs from B.**

- **Where the faces stand.** On the face proxies' inner faces, 8 cm under the floor's lip, with the rock inward. The proxies, 2.4 m thick, stood in front of the upper drop: a shot fired down past the edge stopped on an invisible shelf at z −0.15 up to 2.3 m out. The ledges and skirt stood outside them (the listed rule 5 change). Fixed in batch 5 (F22, below).
- **Slabs.** Bays shared down each drop, 7 to 11 m, not independent ledge slabs 3 to 9 m: the first builds stepped each layer on its own breaks and read as brickwork, as the cliffs' first builds did. `L1` is 5.25 m tall (B: 1.25 to 2.5), mostly behind the skirt.
- **Skirt** toes 6 to 9 m out (B: 6 to 10). A 10 m wedge lifts its buried top above the second ledge where that ledge's face steps in.
- **Corners.** `U0` keeps the floor's 0.5 m chip, so the 1.25 to 1.5 m chamfers start under it.
- **The crest** strip at z 0 beside the cliffs is new.
- **Grid.** Face lines lie on the proxies' faces (±15.92, ±14.52), not the 0.25 m lattice; offsets and heights are on it.
- **The cliffs' outer faces** at x ±15.5 are kept (they were deleted in the hero build).

**Still open:**

- The user's review, then a headset: lean over the north rim and both corners and check the drop feels 24 m deep (D17 and the Rim asset check).
- Closed: the invisible shelf on the face proxies (F22, below).
- Closed: the horizon (C step 5), built below.

**Collision follows the faces** (2026-10-24, batch 5; F22, a listed collision change under rule 28; same command, `--part rim`):

The visible rim does not change, mesh for mesh, and neither do the cliffs, the cover rocks, or the floor (hash for hash against batch 4). Only collision moves (`RIM_PX` and `RIM_PX_CORNER` in the script).

- **Before.** The four face proxies stood on the faces' lines and ran 2.4 m outward, from z −24.35 to −0.15, with the rock inward. From 126 leaning eyes, 41,120 of 47,877 rays down past the edge hit a face proxy before any rock, up to 3.06 m in front of it at the corners.
- **The rule.** Every box's outer face lies on one stratum's face (flush), every box runs 2.4 m into the rock, and every point of every box lies inside the rock or at most 0.15 m in front of it at its own height. The build checks that on the strata's plans in 5 cm samples and trims a box's ends until it holds. Nothing stands above z −0.15, and none enters the shot band or a pad (the build's box test: 165 proxies, none).
- **The upper drop** (the four greybox names, moved): z −9.25 to −0.15, under the floor, flush with the deepest face of U0 to U3. On the south and north ends that is the 0.75 m notch backs, so those boxes stand 0.75 m behind the face line; on the west, the bays 0.25 m behind it; on the east, the face line. The faces in front of them (U0, U2, and U3) stand under the floor's lip or under U1 and the band, where no shot from the rim reaches.
- **Per bay** (three bays per face, the same down each drop, numbered counter-clockwise: the south face west to east, the east face south to north, the north face east to west, the west face north to south): `U1Bay#` (U1, z −4.25 to −2.25) and `BandBay#` (the band, −7.25 to −6.0), flush with their faces 0.5 m proud; `Ledge1Bay#` (M0 to M2, −16.5 to −9.25), flush with M0, its top the first ledge; `M1Bay#` (−14.0 to −11.75), flush with M1.
- **Per face:** `Ledge2` (L0 and L1, −24.35 to −16.5), flush with L0, its top the second ledge; `L1` (−24.35 to −18.75), flush with L1.
- **Per corner** (SW, SE, NE, NW): six boxes turned 45°, flush with each stratum's chamfer and 2.4 m deep: `U1`, `Band`, `Ledge1`, `M1`, `Ledge2`, `L1`, at the same heights.
- **Unchanged:** `Floor-convcolonly`, the four `Rim*` walls, the eight lip proxies, and every cliff and cover proxy. In the exported GLB, 81 of the 85 greybox proxies match the greybox dump node by node; the four that differ are the face proxies.

Every new and moved box (Blender metres; each name carries `-convcolonly`). The four face proxies were: `SouthFace` x −18.0 to 18.0, y −16.92 to −14.52; `NorthFace` x −18.0 to 18.0, y 14.52 to 16.92; `WestFace` x −18.32 to −15.92, y −16.6 to 16.6; `EastFace` x 15.92 to 18.32, y −16.6 to 16.6; all z −24.35 to −0.15.

| Proxy | x | y | z | |
|---|---|---|---|---|
| `SouthFace` | −14.67 to 14.42 | −13.77 to −11.37 | −9.25 to −0.15 | moved |
| `SouthFaceU1Bay0` | −14.88 to −6.67 | −15.02 to −12.62 | −4.25 to −2.25 | new |
| `SouthFaceU1Bay1` | −6.67 to 4.33 | −14.77 to −12.37 | −4.25 to −2.25 | new |
| `SouthFaceU1Bay2` | 4.33 to 14.63 | −15.02 to −12.62 | −4.25 to −2.25 | new |
| `SouthFaceBandBay0` | −14.88 to −6.67 | −15.02 to −12.62 | −7.25 to −6.00 | new |
| `SouthFaceBandBay1` | −6.67 to 4.33 | −14.77 to −12.37 | −7.25 to −6.00 | new |
| `SouthFaceBandBay2` | 4.33 to 14.63 | −15.02 to −12.62 | −7.25 to −6.00 | new |
| `SouthFaceLedge1Bay0` | −15.60 to −6.67 | −16.77 to −14.37 | −16.50 to −9.25 | new |
| `SouthFaceLedge1Bay1` | −6.67 to 0.33 | −16.52 to −14.12 | −16.50 to −9.25 | new |
| `SouthFaceLedge1Bay2` | 0.33 to 15.35 | −16.77 to −14.37 | −16.50 to −9.25 | new |
| `SouthFaceM1Bay0` | −15.81 to −6.67 | −17.27 to −14.87 | −14.00 to −11.75 | new |
| `SouthFaceM1Bay1` | −6.67 to 0.33 | −17.02 to −14.62 | −14.00 to −11.75 | new |
| `SouthFaceM1Bay2` | 0.33 to 15.56 | −17.27 to −14.87 | −14.00 to −11.75 | new |
| `SouthFaceLedge2` | −16.53 to 16.28 | −19.02 to −16.62 | −24.35 to −16.50 | new |
| `SouthFaceL1` | −16.74 to 16.49 | −19.52 to −17.12 | −24.35 to −18.75 | new |
| `EastFace` | 13.52 to 15.92 | −13.02 to 13.27 | −9.25 to −0.15 | moved |
| `EastFaceU1Bay0` | 14.02 to 16.42 | −13.23 to −5.02 | −4.25 to −2.25 | new |
| `EastFaceU1Bay1` | 14.27 to 16.67 | −5.02 to 4.98 | −4.25 to −2.25 | new |
| `EastFaceU1Bay2` | 14.02 to 16.42 | 4.98 to 13.48 | −4.25 to −2.25 | new |
| `EastFaceBandBay0` | 14.02 to 16.42 | −13.23 to −5.02 | −7.25 to −6.00 | new |
| `EastFaceBandBay1` | 14.27 to 16.67 | −5.02 to 4.98 | −7.25 to −6.00 | new |
| `EastFaceBandBay2` | 14.02 to 16.42 | 4.98 to 13.48 | −7.25 to −6.00 | new |
| `EastFaceLedge1Bay0` | 15.77 to 18.17 | −13.95 to −2.02 | −16.50 to −9.25 | new |
| `EastFaceLedge1Bay1` | 15.52 to 17.92 | −2.02 to 6.98 | −16.50 to −9.25 | new |
| `EastFaceLedge1Bay2` | 15.77 to 18.17 | 6.98 to 14.20 | −16.50 to −9.25 | new |
| `EastFaceM1Bay0` | 16.27 to 18.67 | −14.16 to −2.02 | −14.00 to −11.75 | new |
| `EastFaceM1Bay1` | 16.02 to 18.42 | −2.02 to 6.98 | −14.00 to −11.75 | new |
| `EastFaceM1Bay2` | 16.27 to 18.67 | 6.98 to 14.41 | −14.00 to −11.75 | new |
| `EastFaceLedge2` | 18.02 to 20.42 | −14.88 to 15.13 | −24.35 to −16.50 | new |
| `EastFaceL1` | 18.52 to 20.92 | −15.09 to 15.34 | −24.35 to −18.75 | new |
| `NorthFace` | −14.67 to 14.67 | 11.37 to 13.77 | −9.25 to −0.15 | moved |
| `NorthFaceU1Bay0` | 5.67 to 14.88 | 12.62 to 15.02 | −4.25 to −2.25 | new |
| `NorthFaceU1Bay1` | −5.33 to 5.67 | 12.87 to 15.27 | −4.25 to −2.25 | new |
| `NorthFaceU1Bay2` | −14.88 to −5.33 | 12.62 to 15.02 | −4.25 to −2.25 | new |
| `NorthFaceBandBay0` | 5.67 to 14.88 | 12.62 to 15.02 | −7.25 to −6.00 | new |
| `NorthFaceBandBay1` | −5.33 to 5.67 | 12.87 to 15.27 | −7.25 to −6.00 | new |
| `NorthFaceBandBay2` | −14.88 to −5.33 | 12.62 to 15.02 | −7.25 to −6.00 | new |
| `NorthFaceLedge1Bay0` | 7.67 to 15.60 | 14.37 to 16.77 | −16.50 to −9.25 | new |
| `NorthFaceLedge1Bay1` | −0.33 to 7.67 | 14.62 to 17.02 | −16.50 to −9.25 | new |
| `NorthFaceLedge1Bay2` | −15.60 to −0.33 | 14.37 to 16.77 | −16.50 to −9.25 | new |
| `NorthFaceM1Bay0` | 7.67 to 15.81 | 14.87 to 17.27 | −14.00 to −11.75 | new |
| `NorthFaceM1Bay1` | −0.33 to 7.67 | 15.12 to 17.52 | −14.00 to −11.75 | new |
| `NorthFaceM1Bay2` | −15.81 to −0.33 | 14.87 to 17.27 | −14.00 to −11.75 | new |
| `NorthFaceLedge2` | −16.53 to 16.53 | 16.62 to 19.02 | −24.35 to −16.50 | new |
| `NorthFaceL1` | −16.74 to 16.74 | 17.12 to 19.52 | −24.35 to −18.75 | new |
| `WestFace` | −15.67 to −13.27 | −13.27 to 13.27 | −9.25 to −0.15 | moved |
| `WestFaceU1Bay0` | −16.42 to −14.02 | 6.27 to 13.48 | −4.25 to −2.25 | new |
| `WestFaceU1Bay1` | −16.17 to −13.77 | −2.73 to 6.27 | −4.25 to −2.25 | new |
| `WestFaceU1Bay2` | −16.42 to −14.02 | −13.48 to −2.73 | −4.25 to −2.25 | new |
| `WestFaceBandBay0` | −16.42 to −14.02 | 6.27 to 13.48 | −7.25 to −6.00 | new |
| `WestFaceBandBay1` | −16.17 to −13.77 | −2.73 to 6.27 | −7.25 to −6.00 | new |
| `WestFaceBandBay2` | −16.42 to −14.02 | −13.48 to −2.73 | −7.25 to −6.00 | new |
| `WestFaceLedge1Bay0` | −18.17 to −15.77 | 4.27 to 14.20 | −16.50 to −9.25 | new |
| `WestFaceLedge1Bay1` | −17.92 to −15.52 | −5.73 to 4.27 | −16.50 to −9.25 | new |
| `WestFaceLedge1Bay2` | −18.17 to −15.77 | −14.20 to −5.73 | −16.50 to −9.25 | new |
| `WestFaceM1Bay0` | −18.67 to −16.27 | 4.27 to 14.41 | −14.00 to −11.75 | new |
| `WestFaceM1Bay1` | −18.42 to −16.02 | −5.73 to 4.27 | −14.00 to −11.75 | new |
| `WestFaceM1Bay2` | −18.67 to −16.27 | −14.41 to −5.73 | −14.00 to −11.75 | new |
| `WestFaceLedge2` | −20.42 to −18.02 | −15.13 to 15.13 | −24.35 to −16.50 | new |
| `WestFaceL1` | −20.92 to −18.52 | −15.34 to 15.34 | −24.35 to −18.75 | new |

| Proxy (new, turned 45°) | Chamfer face from (x, y) | to (x, y) | z |
|---|---|---|---|
| `SWCornerU1` | (−16.42, −13.48) | (−14.88, −15.02) | −4.25 to −2.25 |
| `SWCornerBand` | (−16.42, −13.48) | (−14.88, −15.02) | −7.25 to −6.00 |
| `SWCornerLedge1` | (−18.17, −14.20) | (−15.60, −16.77) | −16.50 to −9.25 |
| `SWCornerM1` | (−18.67, −14.41) | (−15.81, −17.27) | −14.00 to −11.75 |
| `SWCornerLedge2` | (−20.42, −15.13) | (−16.53, −19.02) | −24.35 to −16.50 |
| `SWCornerL1` | (−20.92, −15.34) | (−16.74, −19.52) | −24.35 to −18.75 |
| `SECornerU1` | (14.63, −15.02) | (16.42, −13.23) | −4.25 to −2.25 |
| `SECornerBand` | (14.63, −15.02) | (16.42, −13.23) | −7.25 to −6.00 |
| `SECornerLedge1` | (15.35, −16.77) | (18.17, −13.95) | −16.50 to −9.25 |
| `SECornerM1` | (15.56, −17.27) | (18.67, −14.16) | −14.00 to −11.75 |
| `SECornerLedge2` | (16.28, −19.02) | (20.42, −14.88) | −24.35 to −16.50 |
| `SECornerL1` | (16.49, −19.52) | (20.92, −15.09) | −24.35 to −18.75 |
| `NECornerU1` | (16.42, 13.48) | (14.88, 15.02) | −4.25 to −2.25 |
| `NECornerBand` | (16.42, 13.48) | (14.88, 15.02) | −7.25 to −6.00 |
| `NECornerLedge1` | (18.17, 14.20) | (15.60, 16.77) | −16.50 to −9.25 |
| `NECornerM1` | (18.67, 14.41) | (15.81, 17.27) | −14.00 to −11.75 |
| `NECornerLedge2` | (20.42, 15.13) | (16.53, 19.02) | −24.35 to −16.50 |
| `NECornerL1` | (20.92, 15.34) | (16.74, 19.52) | −24.35 to −18.75 |
| `NWCornerU1` | (−14.88, 15.02) | (−16.42, 13.48) | −4.25 to −2.25 |
| `NWCornerBand` | (−14.88, 15.02) | (−16.42, 13.48) | −7.25 to −6.00 |
| `NWCornerLedge1` | (−15.60, 16.77) | (−18.17, 14.20) | −16.50 to −9.25 |
| `NWCornerM1` | (−15.81, 17.27) | (−18.67, 14.41) | −14.00 to −11.75 |
| `NWCornerLedge2` | (−16.53, 19.02) | (−20.42, 15.13) | −24.35 to −16.50 |
| `NWCornerL1` | (−16.74, 19.52) | (−20.92, 15.34) | −24.35 to −18.75 |

**Checks** (scratch scripts against the saved `.blend`, and Godot):

- **Rays past the edge:** 126 eyes where a body fits or leans (along the four rims and at the corners, 0.10 m inside and 0.36 m past the face line, 1.2 and 1.7 m up), 47,877 rays down past the edge, pitched 14 to 89°. No ray meets a rim box before visible rock. Each of the 6,183 rays that lands on a ledge top or a rim face meets a rim box within 0.05 m behind the rock it hits (the worst gap).
- **Box surfaces:** every rim box's faces sampled every 0.25 m against the visible rock: none stands in front of it (worst 0.000 m).
- **Still no collision:** 7,157 rays land on the skirt's 35° wedges and 25,321 on the plain. Neither had collision before, and those shots fly on.
- **Shelves left on unchanged proxies:** the four `Rim*` walls run about 2 m past the butte's corners over the drop (x ±18, y ±16.6), the cliffs' `WestBack` and `EastBack` stand past the west and east faces, and `Floor-convcolonly` covers the floor's notches down to z −1. Rays from the corners and over the notches still stop on them (8,818 rays). They were outside this change.
- **In Godot,** physics rays from the south rim stop on `SouthFaceU1Bay0` at z −2.25, on `SouthFaceLedge1Bay0` and `Bay1` at the first ledge (z −9.25, 1.3 to 2.0 m out), and on `SouthFaceLedge2` at the second (z −16.5, 4.1 to 4.4 m out), where the rock is drawn.
- **Tests:** after the export and `--import`, `load`, `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`.
- **Names:** 212 objects under `canyon`, no dots, no duplicates.

**Views** (outside the repo): flat Godot captures at dawn, noon, late afternoon, and dusk of the shots from the SW corner leaning and from outside the south face, the SW corner, and the north rim leaning 60° down.

### Horizon

Built on 2026-10-24 by the same script, untextured:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b assets/models/scenarios/canyon/canyon.blend --python dev/build_canyon_finals_blender.py -- --part horizon
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map canyon --relayout
```

The first run deletes the greybox horizon: `Desert`, `Mesa0`–`7` and their eight caps, and the 110 `Plant###` empties with their 289 parts. Each run then deletes and rebuilds the `CanyonHorizon` empty under `canyon` with 30 objects and saves. It reads Main Street's plant meshes from `main_street.blend` (appended read-only; that file is never saved) and is deterministic (one seed): a re-run gives the same meshes, hash for hash. `--part cliffs`, `cover`, `floor`, and `rim` still give 8,118, 656, 267, and 1,611 triangles, mesh for mesh identical to batch 3's.

- **Tests:** after the export and `--import`: `load` (1,381 scenario surfaces, 204 swaying), `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`.
- **Unwrap:** `GLB canyon [canyon]: 25 meshes, 1091 islands, 13.7 px/m at 256 px (pad 0, 86% covered, 16 tiling meshes untouched); 0 materials copied; image none (flat colour)`. The 25 are the plants. The 16 tiling meshes are the 4 cliff objects, the 2 cover objects, the floor, the 4 rim objects, and the 5 horizon rock and sand objects, all with 8 m tiling UVs (`uv_role` `tiling`, rotation zero, origin at the canyon's origin). UV islands in the `.blend`: `Horizon_Desert` 1, `Horizon_CapDark` 15, `Horizon_RockDark` 17, `Horizon_Cap` 115, `Horizon_Rock` 164.
- **Collision:** none in the horizon, as before. All 85 proxies match the greybox GLB dump node by node (no line differs); none overlaps the shot band or a pad.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `canyon` (`CanyonHorizon` group) | 4,834 / 5,000 (batch 4: 4,610) | 30 | 1 |

| Object | Material | Triangles | Holds |
|---|---|---|---|
| `Horizon_Desert` | `M_SandFar` (desert dirt) | 2 | The plain: one face, 6,000 m square, top at z −24, no bottom or sides |
| `Horizon_CapDark` | `M_CapDark` (violet) | 116 (batch 4: 62) | The backdrop butte's faces that take sun (south and east) and their skirt, the field face among them |
| `Horizon_RockDark` | `M_RockDark` (pink) | 100 (batch 4: 62) | The butte's faces the sun never reaches (west and north) and their skirt (rule 17) |
| `Horizon_Cap` | `M_Cap` (bone) | 531 (batch 4: 399) | The caps of the butte, its ends and shoulders, and the nine mesas |
| `Horizon_Rock` | `M_Rock` (vermilion) | 763 | The nine mesa bodies and skirts |
| `Horizon_Cactus` | `M_Cactus__canyon` | 1,736 | The rigid parts of the 51 cacti, merged across plants |
| `Horizon_CactusDark` | `M_CactusDark__canyon` | 814 | Their dark parts, merged across plants |
| 23 `Horizon_Plant##_<part>` | `M_Scrub__canyon`, `M_ScrubDry__canyon`, `M_Yucca__canyon` | 772 | The swaying parts of 14 plants, one mesh each (`ClumpA`, `ClumpB`, `Blade`, `Trunk`, `Stick`) |

By part: the plain 2 (budget 12), the butte 428 (batch 4: 204) and the mesas 1,082 (1,510 of 1,600; mesas 95 to 147, about 120 each, under the vocabulary's 150), the plants 3,322 of 3,400.

**How it is built.**

- **The backdrop butte** (detail 1). Every number is an angle from `PlayerSpawn`'s eye, so the view holds at any distance (`BUTTE_Y`).
  - The face's plane is y 139, 150 m from the eye. The main block runs x −17.0 to 17.5 (6.4° west to 6.6° east), 42 m deep, its body to z 13.0 (4.3°) under a bone cap to z 14.75 (5.0°).
  - The cap is flush with the face. An overhang would throw a shadow line across the field at noon, 1.4 m down per 0.5 m of overhang. Elsewhere it overhangs 0.5 m.
  - Three shoulders step down beyond the field, each set back 4.5 m behind the one inside it, each with a bone cap: `W1` to 7.0° west, its top at 2.0°; `E1` to 9.3° east, at 2.2°; `E2` to 11.6° east, at 0.25°. With its cap, `W1` ends at 7.2°, 1.4° short of `EnemySpawns2/A`'s body (8.6° to 10.3°).
  - Each piece gets its own ring of 35° skirt wedges (the vocabulary's wedge, toes 5.75 to 8.75 m, mitred at the corners). Where pieces meet, the union keeps the higher slope, so the skirt runs into valleys there. Neighbouring wedges overlap 0.25 m, so no two end faces coincide.
  - One exact union per rock, cut at the plain. Faces whose plan normal points away from the sun (15° east of the lane from the player end) take the pink; the rest stay violet.
- **The mesas** (details 2, 3, 5): the vocabulary's far mesa. Each has a rectangular plan with one chamfered corner, turned to face its eye in 15° steps and snapped to the 0.25 m grid. It stands as two or three stacked prisms, each level inset at least 0.5 m more than the one below on every side (more on the step side), under a bone cap overhanging 0.75 m. Most have a notch 3 to 5 m wide cut through the cap into the body, whose cut faces take the band they cut. A skirt ring of wedges runs round the foot, its corner toes 12% of the height and the others 1 to 3 m longer. Two values each: vermilion body, bone cap.

| Mesa | Placed from | Bearing, distance | Plan | Top (over the plain) | Levels | Seen from its eye (az, top) | Fog | Triangles |
|---|---|---|---|---|---|---|---|---|
| `N1` | `PlayerSpawn` | 20.25° W, 128 m | 34 × 18 m | z 11.75 (36 m) | 2, notch | 13.5° to 18.1° W (the west cliff from 17.5°), 4.9° | 1 to 3% | 95 |
| `N2` | `PlayerSpawn` | 21° W, 225 m | 52 × 28 m | z 26.25 (50 m) | 3, notch | 14.9° to 16.7° W, above `N1`, 6.7° | 24 to 37% | 147 |
| `N3` | `PlayerSpawn` | 14.5° E, 235 m | 52 × 24 m | z 17.0 (41 m) | 2, notch | 8.8° to 10.4° E, over the butte's shoulders, 3.9° | 30 to 33% | 127 |
| `S1` | `EnemySpawn` | 17° W of south, 118 m | 34 × 18 m | z 10.0 (34 m) | 2, notch | 9.4° to 15.3° W, 4.4° | 0 to 2% | 95 |
| `S2` | `EnemySpawn` | 19° W of south, 235 m | 54 × 28 m | z 23.25 (47 m) | 3, notch | 14.4° to 16.6° W, above `S1`, 5.6° | 29 to 42% | 139 |
| `P1` | mid-lane | 38° E of north, 195 m | 50 × 24 m | z 17.0 (41 m) | 2, notch | From the north rim: 32° to 49° E, 5.1° | 10 to 19% | 119 |
| `P2` | mid-lane | 47° W of north, 265 m | 55 × 30 m | z 25.0 (49 m) | 3 | From the north rim: 43° to 56° W, 5.5° | 38 to 53% | 115 |
| `P3` | mid-lane | 45° E of south, 215 m | 46 × 24 m | z 15.75 (40 m) | 2, notch | From the south rim: 41° to 55° E, 4.2° | 17 to 28% | 107 |
| `P4` | mid-lane | 32° W of south, 250 m | 52 × 28 m | z 22.5 (46 m) | 3, notch | From the south rim: 32° to 40° W, 5.3° | 30 to 46% | 139 |

  Azimuths and tops come from the vertices each eye sees (rays). Fog is Godot's depth fog at those vertices' distances.
- **The plants** (detail 6, F10): Main Street's final kinds, from `env_desert_scatter`'s 160 plants (meshes `P###_<part>`).
  - The mix: 14 saguaros with arms, 8 without, 13 barrels, 10 prickly pears, 6 organ pipes, 6 scrub, 3 yuccas, 5 deadwood, each a seeded pick from Main Street's plants of that kind. Yaw is random and scale runs 0.8 to 1.4.
  - Ten stand round the butte's foot, 1.5 to 12 m beyond its skirt toes. The other 55 stand on the plain 30 to 200 m from the canyon's origin, 8 m apart and clear of every skirt. As built they are 39 to 200 m out.
  - Each base sits 0.2 m into the plain, as on Main Street. The rigid cactus parts are merged across plants into the two `Horizon_Cactus*` objects.
  - Every swaying part is its own plant's mesh, with its origin at the plant's base (z −24.2), rotation zero, and scale one; the yaw and scale are baked into the mesh. The importer reads its height from that mesh: 0.3 to 1.5 m.
  - Materials are the canyon's per-GLB copies, checked equal to Main Street's. `M_Yucca__canyon` is new, copied from Main Street's `M_Yucca__env_desert_scatter`, since the greybox had no yucca.

**Checks** (scratch scripts against the saved `.blend`):

- **Rule 22 from `PlayerSpawn`:** 23,474 rays from the eye across ±6°, from −3.85° (the floor's rim line is at −3.80°) to +4°.
  - 22,977 land on the butte's field face, one planar polygon of 8 vertices.
  - 216, below the rim line, land on the floor's edge.
  - 281, at 4.4° to 5.7° west and −3.85° to −2.96°, land on the lip stone `NorthLip1`. That is the rim's shin-high accent, which the sheet puts at 5.2°.
  - Above 4° to 30°: the face to 4.3°, then the cap, then sky.
- **Rule 22 from `EnemySpawn`:** rays across ±5° from −3.85° to 30° find sky, the plain from 404 m out (fully fogged), the floor's edge under the rim line, and the lip stone `SouthLip1` at 4.4° to 5.0° west, under −3.05°. No butte, mesa, or plant.
- **`EnemySpawns2/A`'s line:** rays from `PlayerSpawn` at 7.4° to 11.5° west find only cover rocks, the floor, the plain from 388 m out, and sky.
- **The openings' fields:** no mesa or plant inside them; no plant vertex is seen through either opening (within 25° of the lane ahead) from either spawn.
- **Shadows on the field:** rays toward the sun at 8, 12, 32, and 70° from the face's samples within ±6.5°, from the rim line to its top. None is shadowed with the face at 145 m or more. At 80 m, half the face is shadowed at dawn and a third at dusk (below).
- **No shared planes:** 9,670 coplanar triangle pairs between the horizon and every visible mesh: none overlaps.
- **Mesh:** no dots in names and no duplicates. Rock and sand have no zero-area triangles and no non-planar or smooth faces; one needle triangle the union left on `P3` is merged into its neighbour. The plants are Main Street's meshes unchanged: 132 of their faces are non-planar by more than 1 mm, as on Main Street (1,291 of its 6,204 plant faces).
- **Sway:** 23 meshes on 14 plants. Each has its origin at its plant's base and no rotation or scale. Mesh bottoms sit at local z 0 to 0.39 (blades and sticks start above the base, as on Main Street), and none reaches more than 1.15 m from its origin.

**Views** (outside the repo):

- Blender renders of the butte from the lane's eye (50 and 24 mm), from the plain, three-quarter, and from the north rim; N1 and S1 from their eyes (85 mm) and from the plain; both openings; silhouettes and 64 px squints.
- Flat Godot captures at dawn, noon, late afternoon, and dusk: Lane P, Lane E, the four Flank views, both Rim views level, leaning, and leaning 60° down, both corners, and five plain views. The same set was captured with a throwaway mannequin at `EnemySpawn` in the Ghost's aquamarine, plus a 22° zoom of Lane P.
- In Lane P the mannequin stands against one flat violet field from the floor's edge to well above the hat at all four times: lavender at noon, wine at dawn and dusk.
- The mesas read as two-value blocks fading in layers, `N1` crisp and `N2` paler above it, `S1` dark against the low sun and `S2` paler behind it.
- From the rims the panorama runs from `P2` to `P1` round the butte.
- The squints give one shape and two or three flats per piece.

**Found while building.**

- **The east cliff shades the butte.** At about 80 m (F2), the east cliff's shadow covers the face's west half at dawn and its lower west part at dusk. Its edge runs up the field right beside the enemy, and its top edge is the cliff's skyline: half the field samples at dawn, a third at dusk. The low sun is only 15° off the lane, so the shadow drifts west by 0.27 m per metre north, and it clears the ±6° field from about 145 m. Built at 150 m: the same angles, about 5% fog. Captures at both distances are kept.
- **The south mesas stand in shade.** `S1` and `S2` show their north faces, which never take sun, so from `EnemySpawn` and the south rim they read as dark maroon blocks against the bright south sky (Dixon's *Mesas in Shadow*). The brief keeps them to two values, so they take no pink.
- The noon plain draws near white, like the floor (F20): the same desert dirt under the same sun.

**Where the build departs from B.**

- **Distance:** the butte stands 150 m out, not about 80 m (F2), for the shadow above; the user kept it there (F21). It is 35 m wide and 39 m over the plain. Its foot plants stand about 110 to 180 m from the north rim, so they serve the rim's level view rather than the look-down. Moving it back is one constant (`BUTTE_Y = 69.0`) and a re-run.
- **Colour:** the butte's sun faces are violet and its west and north faces pink (rule 17), so the horizon has five rock and sand objects (B: 4).
- **The cap** is flush with the field face (no overhang shadow line).
- **Mesas:** nine. Three in the north opening (two west of `2/A`'s line, one east behind the butte's shoulders), two in the south opening (west only), and four for the rim panorama at 195 to 265 m (NE, NW, SE, SW). None due east or west, where only the corners would see them. `N2` and `S2` show only as a layer above `N1` and `S1`.
- **Levels** step in at least 0.5 m on every side (rule 4), so no two levels share a plane.
- **Plants:** cacti-heavy (51 of 65; Main Street has 90 of 160) so that the swaying meshes, one draw call each, stay at 23. Plants make 25 draw calls (sheet: about 25). All seven kinds are there. All 65 stand within 200 m.
- **Grid:** plans are snapped to 0.25 m after turning, so plan angles are what the grid gives.

**Still open:**

- A headset: D items 10, 11, 12, and 15, and the horizon's asset check.
- Closed: the butte's distance (F21: 150 m) and its flat outline (F23, below).
- Quest timing for the scene (Whole scene, below).

**Outline roughened** (2026-10-24, batch 5; F23; same command, `--part horizon`):

The field stays: from `PlayerSpawn`'s eye the south face inside ±6°, from below the floor's rim line to 4°, is still one flat violet polygon, and the butte stays 150 m out. Above 4° and beyond ±6° the outline breaks into the vocabulary's steps, joints, and chipped corners (`BUTTE_BODY`, `BUTTE_CAP`, `BUTTE_ENDS`, `BUTTE_SPLITS`, `BUTTE_SLOPE`). The skirt, and the plan outline the plants keep clear of, are still built on batch 4's blocks, so the seeded build draws the same numbers after the butte: the mesas and the plants are unchanged, hash for hash, and so are the cliffs, cover rocks, floor, and rim.

- **Main block:** x −16.25 to 16.25 (±6.18°), its body to z 13.0 (4.3°). Its south face is the field: one polygon of 14 vertices.
- **The cap:** six blocks of the cap slab on the body, 1.25 to 3.75 m thick, their tops 4.78° to 5.73°. Every front is flush with the face or 0.5 m behind it, so no overhang casts a line onto the field. Neighbours overlap 0.5 m with one of them set back 0.5 m, so the band stays whole and no two faces share a plane, except at 0.4° east, where a 0.5 m joint opens to the sky. Four ends are chipped by one 45° cut down to the lower neighbour, 1.0 to 1.5 m, never through the whole cap.
- **The ends:** beyond ±6.18° the old main block steps down as `W0` and `E0`, set back 0.5 m on their front and back, under 1.0 m caps to 3.92° and 4.01°, each outer cap corner chipped 0.75 m.
- **The shoulders:** `W1` keeps its plan and top (1.97°). `E1` splits at 7.4° into `E1a`, taller (3.09°), and `E1b`, set back 0.5 m, at the old 2.24°. `E2` keeps its top (0.29°). Each shoulder block's outer top edge breaks into a 45° slope (1.0 m on `W1`, which is 2.5 m wide; 2.0 m on the others) under a cap that stops where the slope starts, a caprock over its talus. So the steps down read as broken rock rather than stairs.
- **`EnemySpawns2/A`'s line:** the butte ends at 7.01° west (`W1`'s body), east of 7.4°.
- **Grid:** plans and heights on the 0.25 m grid; chips and slopes 0.75 to 2.0 m. The cap's back corner chamfers keep the offset points they had.

| Block | x (m) | From `PlayerSpawn` | Top (z, degrees) | Breaks |
|---|---|---|---|---|
| Main body | −16.25 to 16.25 | ±6.18° | 13.0, 4.3° | The field face |
| `Cap0` | −16.75 to −10.5 | 6.37° to 4.00° W | 14.5, 4.88° | West end chipped 1.25 m |
| `Cap1` | −11.0 to −6.25, set back | 4.18° to 2.38° W | 15.75, 5.33° | West end chipped 1.5 m |
| `Cap2` | −6.75 to 1.0 | 2.58° W to 0.38° E | 14.75, 4.97° | A 0.5 m joint east of it |
| `Cap3` | 1.5 to 7.5 | 0.57° to 2.86° E | 16.75, 5.73° | Both ends chipped 1.5 m |
| `Cap4` | 7.0 to 12.0, set back | 2.66° to 4.56° E | 15.25, 5.14° | |
| `Cap5` | 11.5 to 16.75 | 4.38° to 6.37° E | 14.25, 4.78° | East end chipped 1.0 m |
| `W0` | −17.0 to −15.75, set back | to 6.44° W | 12.0, 3.92° | Cap chipped 0.75 m |
| `E0` | 15.75 to 17.5, set back | to 6.63° E | 12.25, 4.01° | Cap chipped 0.75 m |
| `W1` | −19.0 to −16.5 | 6.10° to 7.01° W | 7.0, 1.97° | Outer slope 1.0 m |
| `E1a` | 17.0 to 20.0 | 6.28° to 7.38° E | 10.0, 3.09° | Outer slope 2.0 m |
| `E1b` | 19.5 to 25.25, set back | 7.17° to 9.25° E | 7.75, 2.24° | Outer slope 2.0 m |
| `E2` | 24.75 to 32.75 | 8.85° to 11.64° E | 2.5, 0.29° | Outer slope 2.0 m |

- **Triangles:** the butte 428 (batch 4: 204); with the mesas 1,510 of 1,600; the horizon 4,834 of 5,000.
- **Rule 22 from `PlayerSpawn`:** 23,474 rays across ±6° from −3.85° to 4°: 22,977 land on the one field polygon, 216 on the floor's edge under the rim line, and 281 on the lip stone `NorthLip1`, as in batch 4. From 4° to 30°, only the butte's faces and caps, then sky.
- **Rule 22 from `EnemySpawn`:** unchanged (sky, the fogged plain, the floor's edge, and `SouthLip1`).
- **`EnemySpawns2/A`'s line:** rays at 7.4° to 11.5° west find only cover rocks, the floor, the plain from 388 m, and sky.
- **Shadows on the field:** rays toward the sun at 8, 70, 32, and 12° from 10,611 samples across ±6.5°, from the rim line to the face's top (4.3°), with every visible mesh casting, the butte's own cap and shoulders included: none is shadowed at any of the four times.
- **No shared planes:** 12,431 coplanar triangle pairs between the horizon and every visible mesh: none overlaps.
- **Mesh:** no dots in names and no duplicates; no zero-area triangles and no non-planar or smooth faces in the rock.
- **Tests:** after the export and `--import`, `load`, `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`.
- **Views** (outside the repo): Blender renders from the lane, the north rim, and the plain; flat Godot captures at dawn, noon, late afternoon, and dusk of Lane P, the butte from the north rim leaning and from the plain in front of it and to its southeast, and Lane P's 22° zoom with a throwaway mannequin at `EnemySpawn` in the Ghost's aquamarine. The mannequin still stands against one flat violet field at every time; above it the cap reads as one broken bone band, and the east side steps down in broken shoulders. The west side stays narrow, held east of `2/A`'s line.
- **Departures from B:** cap blocks to 3.75 m thick (the cap slab: 1.25 to 2.0) and tops to 5.73° (detail 1: a cap to 5°), so the steps read at 150 m; one joint, not one every 2 to 4 m, since a joint 0.25 to 0.6 m wide is under two pixels at this range in Lane P.

### Whole scene

The Canyon's final untextured meshes are complete. One GLB, five groups (F13).

| GLB group | Triangles / budget | Mesh objects | Draw calls |
|---|---|---|---|
| `CanyonCliffs` | 8,118 / 16,000 | 4 | 4 |
| `CanyonCover` | 656 / 1,500 | 2 | 2 |
| `CanyonFloor` | 267 / 400 | 1 | 1 |
| `CanyonRim` | 1,611 / 2,000 | 4 | 4 |
| `CanyonHorizon` | 4,834 / 5,000 | 30 | 30 (5 rock and sand, 25 plants) |
| **Scene** (`canyon.glb`) | **15,486** (budget about 25,000) | **41** | **41** (sheet: about 40) |

- Collision proxies (`-convcolonly`) are bodies, not meshes, and are not counted: 165. The greybox's 85, four of them moved (the rim's face proxies), and 80 rim boxes (F22; H, Rim).
- 15,486 triangles is 62% of the budget and 1.0% of Meta's 1.5 million per frame for Quest 3.
- 41 draw calls, against Meta's guideline of under 200 (the greybox had 393). Every mesh is drawn again into each of the sun's four shadow cascades it touches, and the merged cliffs touch them all at dusk.
- Lights: one, the shadowed `Sun`.
- Tests: `--import`, then `--autotest=load`, `multi`, `ragdoll`, and `gauntlet` all print `AUTOTEST PASS`.

## References

**Repo**

- `.claude/skills/gunslinger-taste/references/board.md`: items #00, #04, #07, #09, #12, #14, #15, #18, #20, #22, #25, and patterns 3 (pattern is the silhouette) and 7 (print texture).
- `.claude/skills/gunslinger-taste/references/steel-ball-run.md`: no fixed palette; colour chosen for the image; history bent one notch; stages with personalities.
- `docs/design/characters/`: `ghost.md` (rung 5; company right-of-way; the Royal Gorge war), `sheriff.md` (signed the paper), `drunk.md`, `half-head.md` (owns the skull), `player.md` (the black coat).
- `docs/design/scenarios/main_street.md` (global rules, palette, backdrop check, build lessons), `docs/design/scenarios/saloon.md` (build lessons, backdrop method).
- `dev/build_canyon_blender.py`, `dev/build_train_rooftop_blender.py`, `dev/unwrap_per_glb_blender.py`, `dev/unwrap_scenery_blender.py`, `dev/scenery_uv.py`, `dev/blender_kit.py`, `dev/autotest.gd` (`_spawn_floors_ok`, `_multi_arena_ok`, `_world_surface_ok`, `_outdoor_time_ok`), `scenarios/canyon/canyon.tscn`, `scenarios/canyon/canyon.tres`, `scenarios/time_of_day.gd`, `scenarios/scenario_base.gd`, `scenarios/train_rooftop/scenery_belt.gd`, `autoload/game_manager.gd`, `ai/duelist_ai.gd`, `ai/archetypes/*.tres`, `gauntlet/encounters/e5_ghost_canyon.tres`, `assets/shaders/world_surface_import.gd`, `docs/SHADERS.md`, `docs/TEXTURING.md`, `docs/ARCHITECTURE.md`, `docs/FEATURES.md`, `docs/RELEASE_TODOS.md`.

**Canyons, rock, and the railroad**

- [Ancient Ruins in the Cañon de Chelle, N.M.](https://www.artic.edu/artworks/140416/ancient-ruins-in-the-canon-de-chelle-n-m-in-a-niche-50-feet-above-present-canon-bed), Art Institute of Chicago: O'Sullivan, 1873, "in a niche 50 feet above present Cañon bed"; the White House ruins, "the striations of the canyon wall, and two small figures below". Board #07. Also [MFAH](https://emuseum.mfah.org/objects/4917/ancient-ruins-in-the-canon-de-chelle-nm): the Wheeler survey's side trip.
- [Royal Gorge Route Railroad](https://en.wikipedia.org/wiki/Royal_Gorge_Route_Railroad), Wikipedia: Rio Grande crews built 17 stone "forts", among them Fort DeRemer; Masterson's recruits; the companies settled out of court with the Treaty of Boston, 1880. Also [Railroad Wars](https://en.wikipedia.org/wiki/Railroad_Wars).
- [Grand Staircase](https://www.nps.gov/brca/learn/nature/grandstaircase.htm), NPS Bryce Canyon: Dutton named the steps Pink, Grey, White, Vermilion, and Chocolate Cliffs.
- [Geologic Formations](https://home.nps.gov/pefo/learn/nature/geologicformations.htm), NPS Petrified Forest: the Blue Mesa Member's "grey, blue, purple, and green mudstones"; red where the iron oxidized, green or blue where the water table stayed high; sandstone capping the mesas.
- [USGS open-file report, 1957](https://pubs.usgs.gov/of/1957/0124/report.pdf), on Monument Valley: the Shinarump caps most of the isolated mesas and buttes, as a cliff about 50 feet high. Read through a search excerpt.
- [Scree](https://en.wikipedia.org/wiki/Scree) and [Angle of repose](https://en.wikipedia.org/wiki/Angle_of_repose), Wikipedia: "Scree is formed by rockfall"; talus is concave, its steepest part at the angle of repose, "the steepest slope a pile of granular material can take". The 35° used here is a design value, between the article's natural gravel (25 to 30°) and crushed stone (45°).

**Painters and print**

- [Ed Mell](https://www.masterworks.com/academy/artists/ed-mell), Masterworks: "the angular, faceted painting style", "a modernist visual language" applied "to mesas, storm clouds, and desert light"; "desert modernism".
- [Maynard Dixon highlights](https://moa.byu.edu/maynard-dixon-highlights/), BYU Museum of Art: *Mesas in Shadow*, 1926; "low horizons and simplified, yet imposing clouds and rock formations in bold colors". The [store listing](https://moastore.byu.edu/product/mesas-in-shadow/) (shadow over the distant mesas, one mesa catching the sun) was read through a search excerpt; the page no longer loads.
- [Grand Canyon of the Colorado River](https://collections.gilcrease.org/node/148620), Gilcrease Museum: the Santa Fe's 1892 chromolithograph of Moran's painting, used in its advertising for over a decade. Read through a search excerpt. Also [Wikipedia](https://en.wikipedia.org/wiki/Grand_Canyon_of_the_Colorado_River_(Moran)).

**PSX era, engine, and hardware**

- [The Tomb Raider grid](https://lifeandtimes.games/7), *The Life and Times of Video Games*, episode 7: levels laid out "on a grid of square blocks"; Gavin Rummery found Ultima Underworld built on a grid though it "doesn't feel like that".
- [Spyro the Dragon](https://www.hardcoregaming101.net/spyro-the-dragon/), Hardcore Gaming 101: every level has a flat-shaded far version.
- [Making Crash Bandicoot, part 3](https://all-things-andy-gavin.com/2011/02/04/making-crash-bandicoot-part-3/), Andy Gavin: a budget set by the polygons on screen at once.
- [Draw distance](https://en.wikipedia.org/wiki/Draw_distance), Wikipedia: "A common trick used in games to disguise a short draw distance is to obscure the area with a distance fog."
- [Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html), Godot docs: in depth mode `fog_density` is "the maximum intensity of the deep fog". [`scene.glsl`](https://raw.githubusercontent.com/godotengine/godot/master/drivers/gles3/shaders/scene.glsl), Godot's Compatibility shader: depth fog is `pow(fog_z, fog_depth_curve) * fog_density`.
- [Device optimization comparison](https://developers.meta.com/horizon/resources/device-optimization-comparison/), Meta: Quest 3 at under 200 draw calls and 1.5 million triangles per frame. [Meta Quest compare](https://www.meta.com/ca/quest/compare/): 25 pixels per degree.
