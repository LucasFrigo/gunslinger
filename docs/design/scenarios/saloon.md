# Saloon (interior): design sheet

| | |
|---|---|
| Status | `done`, with the headset review still open. Decided 2026-10-19 (section F). All seven assets are built, final and untextured (H), and the glow code has landed (G7). Still to do: the in-context review in a headset (D) and Quest timing (`RELEASE_TODOS.md`) |
| Kind | Scenario design sheet: greybox to final, untextured, UV-unwrapped meshes |
| In code | `saloon_bar.glb` (6 meshes, 2,532 triangles, 2 proxies), `saloon_shell.glb` (6 meshes, 2,111 triangles, 6 proxies), `saloon_table.glb` (module: 4 meshes, 468 triangles, 1 proxy; two copies), `saloon_chair.glb` (module: 1 mesh, 398 triangles, 1 proxy; eight copies), `saloon_balcony.glb` (3 meshes, 2,390 triangles, 6 proxies), `saloon_dressing.glb` (7 meshes, 1,628 triangles, 6 proxies), and `saloon_lamps.glb` (4 meshes, 1,232 triangles, no collision), all final and untextured, exported from `saloon.blend` by `dev/unwrap_per_glb_blender.py`: about 14,000 triangles in 42 draw calls. The greybox `saloon_interior.glb` is retired; `dev/build_saloon_blender.py` made it and must not be re-run. `scenarios/saloon/saloon.tscn` instances the seven (`Bar`, `Shell`, `TableA` and `TableB`, `ChairA0` to `ChairB3`, `Balcony`, `Dressing`, `Lamps`) with the spawn markers, the `Chandelier` OmniLight3D, the two bar spots, the two table spots, and the environment. The self-lit `M_Flame` and `M_LampGlass` are in `assets/shaders/world_surface_import.gd` and `world_surface.gdshader` (G7). The scene facts below describe the greybox before the hero |
| Prompt | [`prompts/saloon.md`](prompts/saloon.md) |
| Inherits | [`main_street.md`](main_street.md): global rules 1 to 28, the palette, the backdrop check, and the build lessons. The Saloon's exceptions are listed in A, each with its reason |

The deliverable is clean, final, untextured meshes with sensible UVs and flat Base Color materials. You texture by hand later, so nothing here plans texture art.

Blender positions are Z-up, in metres. −X is the west wall (the bar), −Y the street wall behind `PlayerSpawn`, and +Y the north wall behind `EnemySpawn`. Godot positions are (x, y, z) with y up: Blender (x, y, z) is Godot (x, z, −y).

## Scene facts the design depends on

Read from `saloon.tscn`, `saloon.tres`, the GLB, the build script, and the code that touches them. They describe the greybox as it is today.

- **Room.** Inside, 13.4 × 17.4 m. Walls 0.30 m thick and 4.45 m tall; the floor's top at 0; the ceiling's underside at 4.20 m. Under the ceiling: four beams across the room at y −6.2, −2.8, 2.8, and 6.6, hanging to 3.52 m; the chandelier's ring at 3.40 m; and along the north wall the balcony, whose underside is at 2.86 m.
- **Lane.** `PlayerSpawn`, Blender (0, −5) and Godot (0, 0, 5), faces `EnemySpawn`, Blender (0, 5) and Godot (0, 0, −5), so `duel_distance` is 10. The build script refuses any collider made through `col()` inside \|x\| < 1.5, \|y\| < 6, from 0.30 to 2.20 m up. The nearest collision to that corridor is table A's west chair, at x 2.29, 0.79 m outside it.
- **Who stands at `EnemySpawn`.** Gauntlet rung 2 is Plata ("His angrier brother": the Drunk archetype at 1.5× health, `STAND`). Rung 6 is the Ghost ("The Ghost, up close": 2× health, `STRAFE`, swinging ±1.5 m along x by `STRAFE_RANGE` in `ai/duelist_ai.gd`). Free duels and lobbies use every marker.
- **Light.** No `Sun` and no sky. One OmniLight3D, `Chandelier`, at Godot (0, 3.4, 0): colour (1, 0.8, 0.55), energy 2.5, range 14 m, shadows on. Ambient colour (0.8, 0.6, 0.4) at 0.25; background (0.05, 0.04, 0.03). Time of day never touches the Saloon. `--autotest=load` (`_saloon_time_ok`) needs that node, with that name and type, and no `Sun`.
  - Both spawns stand 5.35 m from the light, so both duelists are lit alike. The floor takes the full light step out to about 5.5 m from the point under the chandelier, which covers both spawns and the Ghost's strafe.
  - The wall behind each spawn is 8.9 m from the light. It gets 0.58 of the light that reaches the duelist's chest: luminance of white 0.223 against 0.386.
  - In linear terms the light is (1, 0.60, 0.26). With the warm ambient, bone reads tan (#916A3D on the north wall) and the Ghost's aquamarine reads olive (#708657). F2 changes this.
  - The beams hang below the ceiling but above the light (3.52 against 3.40 m), and the light casts shadows. So it reaches the ceiling only between beams 1 and 2. The ceiling's end bays, the north wall above about 3.6 m, and the top of the balcony's balustrade (above 3.53 m, in beam 3's shadow) get ambient light only.
- **Banded light indoors.** A face turned toward the chandelier takes the full step; one turned more than 60° away takes the middle step, 65% (`band_low` 0.65, `band_soft` 0.03). Walls face the light and take the full step, while a ledge more than 4 m from the chandelier (measured flat) takes the middle step. Indoors, a ledge draws a darker line than the wall below it, not a lit one.
- **How close things are.** From `PlayerSpawn`'s eye at 1.7 m: the floor 1.7 m, beam 0 overhead 2.1 m, the street wall 3.7 m, table A's nearest chair 3.8 m, the kegs 3.9 m, the bar's south end 4.9 m, the piano 5.5 m, the east wall 6.7 m. On Main Street the nearest facade is 12 m from the lane. Free roaming brings any piece to arm's length.
- **Who can walk where.** The flat rig is a capsule 0.28 m in radius from 0.1 to 1.7 m, with its camera at 1.7 m; it climbs slopes up to 51.6° (`floor_max_angle` 0.9). VR stick locomotion sweeps a capsule from 0.35 to 1.6 m above a fixed floor height and never climbs. Room-scale walking is not checked.
- **Sightlines.** What stands behind each marker, seen from `PlayerSpawn`'s eye (rays cast against the greybox):

| Marker | Blender position | Behind the duelist's shoulders to hat (1.0 to 2.3 m) | Who stands there |
|---|---|---|---|
| `EnemySpawn`, `EnemySpawns3/B` | (0, 5) | The north wall, 3.7 m behind, from 0.75 to 2.52 m up and within about ±2.5 m of x 0 with the strafe. The wainscot's top and the chair rail (1.12 to 1.19 m) cross behind the chest | Rung 2 Plata, rung 6 the Ghost, every 1v1 |
| `EnemySpawns2/A` | (−3, 2) | The stair's side and its brass handrail, 3 to 5 m behind. The rail crosses behind the head | Two-NPC fights, three-player lobbies |
| `EnemySpawns2/B`, `EnemySpawns3/C` | (3.8, 0.3) | The east wall, 4 to 6 m behind: window E2's ink pane behind the head, the chair rail behind the chest | Two- and three-NPC fights |
| `EnemySpawns3/A` | (−3, −0.5) | The bar counter's front behind the hips; above it, the west wall over the stair, 6 to 8 m behind | Three-NPC fights |
| `PlayerSpawn`, seen from `EnemySpawn` | (0, −5) | The south wall, 3.7 m behind, from 0.74 to 2.52 m up: the door, with its two full-height leaves propped open on either side of the player | The player; the other human in a lobby |

- **No wind, no hinge slabs.** The Saloon has no wind, so `wind_ambient` and `wind_gust` stay 0 and nothing sways. No node here needs a hinge name.
- **No outline on scenery** (inherited). Only duelists and held objects carry the ink line (#120D0A).
- **Props are static.** Every proxy is a static `-convcolonly` box or ramp, and nothing can be grabbed.

### The brief's facts, checked

1. **Axes:** correct. −X is the bar wall, −Y the street wall behind `PlayerSpawn`, +Y the north wall behind `EnemySpawn`. The spawns stand 3.7 m from those walls, at y ±5.
2. **"Chest-to-head height":** wrong. The script keeps colliders out of 0.30 to 2.20 m, from the shin to above the hat, which is stricter. It also checks only colliders made through `col()`: the chair proxies go through `convcol()` directly and skip the check. They sit 0.79 m outside the corridor anyway.
3. **"Tables off a 10 m lane":** both numbers are true and measure different things. 10 m is `duel_distance`, spawn to spawn. The corridor kept free of collision is 12 m long (1 m behind each spawn) and 3 m wide. The Roadmap and FEATURES lines would be clearer as "east of the 3 × 12 m shot corridor".
4. **"Ceiling underside is 4.2 m":** true, but the beams come down to 3.52 m, the chandelier to 3.40 m, and the balcony's underside to 2.86 m. All of them clear a standing player. The balcony itself does not: its floor is 1.2 m under the ceiling (Found 4).
5. **"No Sun":** true, and there is no sky either. There is no window light today: the windows are flush panes on solid walls, and the background is near-black.
6. **"Seen from 1–2 m":** only the floor and beam 0 are that close to a player standing at a spawn; the furniture starts at 3.8 m. The claim holds once a player walks around, and even from the spawns the room is two to four times closer than Main Street.
7. **"`docs/TEXTURING.md` lists the current triangle counts per map":** it lists 2,024 → 2,176 for the Saloon, which counts only the 149 objects the paused trim-sheet pass unwrapped. The GLB holds 2,976 visible triangles in 195 meshes, and 308 in 26 proxies.
8. **The asset list:** `saloon_interior` also holds the floor, the doors, the windows, the piano, the stove, the kegs, the spittoons, and the chandelier. This sheet adds asset sheets for them (chairs, lamps, dressing).

### Found in the greybox

None of these is in the brief. Where one needed a decision, F records it.

1. The back bar's mirror and its eight shelf bottles sit inside the back bar's box, so they are never seen: the mirror at x −6.69 to −6.66 and the bottles at −6.54 to −6.48, inside a box that spans −6.70 to −6.32. That hides 172 triangles. Only the three shelf lips show, 2 cm proud.
2. The street door is painted on. The south wall is solid, and the two "batwings" are full-height leaves (0.02 to 2.18 m) propped 32° open into the room against it.
3. The windows are panes laid flat on solid walls, with 8 cm frames.
4. Nobody can use the balcony. Its floor (3.0 m) is 1.2 m under the ceiling. A flat player climbs the 39.8° stair until the capsule's top meets the ceiling, about 0.6 m short of the top, with the camera in the ceiling. VR stick-walk cannot climb it at all. Decided: gate the stair (F11).
5. The balcony's visible rail runs from 0.44 to 0.52 m above its floor, at knee height, while its posts and its proxy reach 0.9 m.
6. The stove pipe stops at 2.55 m, 1.65 m below the ceiling.
7. The three "barrels" are kegs, 0.32 to 0.42 m tall and 0.56 m across: lower than a chair seat. Their proxies match, so they are not cover. Decided: full barrels (F14).
8. The piano stands 0.94 m off the east wall and 0.80 m off the south wall. Decided: against the wall (F21).
9. Readability problems, from the sightline table: the north wainscot's top and chair rail cross behind the enemy's chest; window E2 is behind the east multi marker's head (decided: move it, F9); the brass stair rail crosses behind the west two-NPC marker's head (decided: accept it, F10).
10. Names: the chair parts repeat as `Seat`, `Back`, and `Cushion` with `.001` to `.007`, and `FootPost_-0.3` and `BenchLeg_-0.28` carry signs and decimals.
11. Band cuts from the paused trim-sheet pass: the ceiling, a plain box, is 116 triangles, and each wall is 20.
12. Seven of the 17 materials are close browns (`M_Floor`, `M_FloorAlt`, `M_Wood`, `M_WoodDark`, `M_Bar`, `M_BarTop`, `M_Trim`): the average western room that the taste skill throws out. Iron, brass, glass, and mirror carry metallic 0.15 to 0.9 and roughness 0.08 to 0.45, which the shader ignores.
13. The chandelier hangs wholly at or above its light (3.40 m), so its shadows fall only on the ceiling. Keep that.

## A. Art direction

Inside Main Street's stage set the room is a plain box, and its money goes into one object: a mirrored back bar like the 16- to 30-foot back bars Brunswick-Balke-Collender built in Dubuque, mirrors behind shelves of liquor as in an Albuquerque saloon photographed about 1885, carrying the room's ornament the way the Tiffany Smith & Wesson carries it on the tool (True West; Albuquerque Museum; board #06). Members are few and thick, sized for a player 1.7 to 6 m away instead of Main Street's 12 to 40: 5 cm is the smallest modeled feature on furniture, fixtures, and anything below 2.2 m, 14 px at 5 m and 48 px at 1.5 m on a Quest 3, the same reasoning that made Crash's pupils a full quad so they always showed (Meta; Jason Rubin in Andy Gavin's blog). It is the night after a fight, and the building itself is sound: between table A and the bar's south end a chair lies on its back, another is smashed, a mirror bay is shot through, and glass, splinters, and spilled checks run across the floor and the lane, while the rest of the room keeps Main Street's lived-in accents, all of it in silhouette; it answers the Bird Cage Theatre's walls "riddled with gunshot holes", which are too small to model (Wikipedia). The room is shut for the night, doors closed and shutters drawn, and the palette is loud and few: the walls carry the street face's saloon magenta inside, the dado, bar, beams, and furniture are black dark stain trimmed in cream and gold, and the pressed-tin ceiling is white, because tin was painted to pass for plaster; magenta against cream is board #04's two-colour image and #16's Araki pink, and black trimmed in gold is #10 and #21, the dark-fantasy West (Wikipedia, Tin ceiling). Colour carries the warmth so the lamps can stay nearly white, because Araki picks a colour for the image, not for the scene (`steel-ball-run.md`). Light is never painted, so the lamps are the lighting design: one brass kerosene chandelier over the lane's midpoint lights both duelists alike, four hooded lamps pool light on the bar and the felt, and only the flames and the chandelier's glass glow, drawn flat in their own colour (The Henry Ford; board #18, #20). The enemy always stands on one flat magenta field under the gallery, framed by two posts and a comb of cream balusters like one of the Bird Cage Theatre's balcony boxes, and every piece must still read with its detail switched off, as Spyro's flat-shaded far levels did (Wikipedia; Hardcore Gaming 101).

**What this place feels like:** a wine-dark room shut up the night after a fight, with glass underfoot, the street door closed behind you, the back bar's mirrors bright on your left and one of them shot through, and your opponent waiting on a lit stage under the gallery.

### Exceptions to the global rules

Rule numbers are Main Street's. Every rule not listed here holds as written, including rule 21: no company blue, because the Saloon is off company ground (`ghost.md`).

| Rule | Main Street | Saloon | Why |
|---|---|---|---|
| 6 | Smallest modeled feature 10 cm; gaps 5 to 8 cm | 5 cm on furniture, fixtures, and anything below 2.2 m; 10 cm on the shell and the gallery above 2.2 m. Rule 3's 8 cm rails and balusters still apply. Gaps of 3.5 to 4 cm between louvres and between the chair's spindles (F19) | Seen from 1.7 to 6 m, not 12 to 40. 5 cm is 14 px at 5 m and 48 px at 1.5 m, more than 10 cm gets at Main Street's 16 m (9 px). The shell and the gallery above head height are big planes and members, seen from below |
| 8 | No bevels on wood | Also one 45° chamfer of 3 to 4 cm on the front edges of the bar top and the table tops | Those are the edges a hand rests on. The chamfer takes another light step and draws the edge |
| 10 | Ledges carry the shade side | Ledges stay 8 to 15 cm deep, but more than 4 m from the chandelier they take the middle step while the wall takes the full one, so they draw dark lines | There is no sun; the light sits above and beside every ledge |
| 12 | One feature per 1.5 to 2 m of street face, 0 to 2.8 m up | One per 0.6 to 1 m on furniture and fixtures between 0.5 and 2.2 m; walls stay flat paint | Eye level is where a player in a room looks. The furniture carries the detail; the walls carry the duel fields |
| 13 | One wear accent per 4 m of street face | Outside the fight zone, one per 3 m of wall and one per piece of furniture. Inside it, the fight's debris (rule 14) | Seen three times closer |
| 14 | Nothing is broken through, no hole opens into an interior, nothing has fallen | Broken on purpose inside the fight zone, between table A and the bar's south end: a tipped chair, a smashed chair, a shot-through mirror bay, broken bottles, and glass, splinters, checks, and cards on the floor, some of it in the lane. The building stays whole: walls, floor, ceiling, beams, gallery | F20: the room the night after a fight |
| 17 | Sunlit faces saturated, shaded faces pale | Faces that only ambient light reaches (the ceiling's end bays, everything above 3.5 m beyond beams 1 and 2, undersides) take luminance 0.4 or more if they must read as colour. Otherwise they go near black, which suits frames and undersides | There is no sun. Ambient light alone shows a flat at about a tenth of its value |
| 19 | Openings are ink | No opening shows: the shutters are closed (F8) and the outer doors shut (F7) | Night, and the room is sealed. An ink void would sit behind the player's head and hat |
| 20 | Raw wood is one silver grey | Holds, and the floor and the shutters are raw wood too | Unpainted interior wood is raw wood |
| 22 | The wall behind a spawn is one flat mid-value field | Applies to the north field behind `EnemySpawn` and to the door behind `PlayerSpawn`. The east windows move off the east marker's backdrop (F9); the stair behind the west two-NPC marker is accepted (F10) | |
| New | No emission on scenario materials (Main Street G7) | `M_Flame` and `M_LampGlass` draw unshaded, flat in their own colour; nothing else glows. The code has landed (G7) | F4, F27 to F29 |
| New | | Dark stain and iron show no light: detail on them reads only in silhouette, or as a cream or gold trim. Keep relief for the mid and pale flats | Dark stain under the lamp has a luminance of about 0.008 |

PSX vertex snap and affine warp play no part: nothing here depends on them.

### Palette

Enter the linear value as the Blender Base Color. Hex is the sRGB display value; Y is linear luminance. "Seen" is this sheet's estimate of the colour on screen under the decided lamp (F2; method under the backdrop check); the flat run decides. Each GLB's own copy of a material (`M_Wood__saloon_bar`) holds the colour.

| Flat | Hex | Blender Base Color (linear) | Y | Base name | Used for | Seen |
|---|---|---|---|---|---|---|
| Saloon magenta | #C42D78 | 0.552, 0.026, 0.188 | 0.15 | `M_Wood` | Walls above the dado, the north field | Wine: #731438 on the north field, #8A1A44 by the bar |
| Dark stain | #2B2630 | 0.024, 0.019, 0.030 | 0.02 | `M_WoodDark` | Dado, baseboards, beams, bar and back bar, tables, chairs, balcony, piano, barrels, splinters | Near black, #151012 to #1E181A |
| Bone | #E8DDC4 | 0.807, 0.723, 0.552 | 0.73 | `M_Trim`; `M_Ivory` (no grain) | `M_Trim`: cap rail, frames, batwings, bar top, balusters. `M_Ivory`: piano keys, checks, cards, glasses | Cream: #A49273 at the back bar, #F5D9AB under a lamp |
| Raw wood | #8F8C86 | 0.275, 0.262, 0.238 | 0.26 | `M_Plank` | Floor, shutters, stair treads, the outer doors' inner face | Warm grey, #675E4F at the spawn |
| Whitewash | #EFE9DA | 0.863, 0.815, 0.701 | 0.82 | `M_Whitewash` | Pressed-tin ceiling, medallion | #D0BD9D in the lit middle bay, #585045 in the end bays |
| Iron | #24272E | 0.018, 0.020, 0.027 | 0.02 | `M_Iron` | Stove, pipe, chains, rods, hanging-lamp shades, hoops, hasp | Black |
| Store marigold | #E8A825 | 0.807, 0.392, 0.019 | 0.45 | `M_BottleAmber` | Amber bottles and their shards | #A46E11 on the shelves |
| Brass (new) | #C9A23A | 0.584, 0.361, 0.042 | 0.39 | `M_Brass` | Foot rail, brackets, capitals, spittoons, chandelier, piano arms | Gold: #987121 on the counter, #D49F31 under a lamp |
| Mirror silver (new) | #B9CCD2 | 0.485, 0.604, 0.645 | 0.58 | `M_Mirror` | Back-bar mirrors and their shards, the tin heart | #82867B, the brightest band on the west wall |
| Felt green (new) | #1F7A4A | 0.014, 0.195, 0.068 | 0.15 | `M_Cloth`; `M_Bottle` | Table felt; green bottles and their shards | #248044 under its lamp, #134E28 without it |
| Flame yellow (new) | #FFD966 | 1.000, 0.694, 0.133 | 0.72 | `M_Flame`, glows | Flame tips in the chandelier's chimneys | #FFD966 exactly: it draws unshaded |
| Lamp glass (new) | #FFF0C8 | 1.000, 0.871, 0.578 | 0.88 | `M_LampGlass`, glows | The chandelier's shades and chimneys | #FFF0C8 exactly: it draws unshaded |

- Roughness 0.9 and metallic 0 everywhere (rule 23), iron, brass, and mirror included.
- Retired here: `M_Bar`, `M_BarTop`, `M_Floor`, `M_FloorAlt`, `M_Candle`, `M_Glass` (no pane shows), the red cushion cloth, and the brown values of `M_Wood`, `M_WoodDark`, and `M_Trim`. `M_Plank` and `M_Whitewash` are new to the Saloon but exist on Main Street.
- Grain by name: `M_Wood`, `M_WoodDark`, `M_Trim`, `M_Plank`, and `M_Whitewash` take 0.12. `M_Iron`, `M_Brass`, `M_Mirror`, `M_Cloth`, `M_Bottle`, `M_BottleAmber`, `M_Ivory`, `M_Flame`, and `M_LampGlass` take none.

### Light plan

The lamps are the lighting design. Light nodes live in `saloon.tscn`, not in the GLB, so every new row is a scene edit (F3).

| Light | Node | Blender | Godot | Kind | Energy | Reach | Shadows | Lights |
|---|---|---|---|---|---|---|---|---|
| Chandelier | `Chandelier`, exists: keep its name and type | (0, 0, 3.40) | (0, 3.40, 0) | OmniLight3D | 2.5 | 14 m | On: the only shadowed light | Both duelists alike, the ceiling's middle bay, the room |
| Bar lamp, south | `BarLampS`, new | (−5.2, −2.8, 2.35) | (−5.2, 2.35, 2.8) | SpotLight3D, straight down | 1.0 | 3.5 m, 35° cone | Off | The counter top and the customers' side |
| Bar lamp, north | `BarLampN`, new | (−5.2, 2.8, 2.35) | (−5.2, 2.35, −2.8) | SpotLight3D, straight down | 1.0 | 3.5 m, 35° cone | Off | The same, at the north end |
| Table lamp A | `TableLampA`, new | (3.5, −2.5, 1.95) | (3.5, 1.95, 2.5) | SpotLight3D, straight down | 1.0 | 3.0 m, 30° cone | Off | Table A's felt |
| Table lamp B | `TableLampB`, new | (4.0, 3.0, 1.95) | (4.0, 1.95, −3.0) | SpotLight3D, straight down | 1.0 | 3.0 m, 30° cone | Off | Table B's felt |

- **Colour (F2).** All five lights share (1, 0.93, 0.82), against today's (1, 0.8, 0.55). The ambient goes to (0.7, 0.66, 0.62) at 0.25 from (0.8, 0.6, 0.4) at 0.25. The background stays (0.05, 0.04, 0.03).
- **No window light.** It is night (F1), and the shutters are closed (F8).
- **The glow lights nothing.** The flames and the chandelier's glass draw in their own colour (F27, F28), but they cast no light; the OmniLight does the lighting.
- **The chandelier stays the key light.** It falls equally on both spawns, and its full step on the floor holds the whole lane. The four hooded lamps' pools stay off the lane and off every marker: the bar pools reach x −3.55 at most, the table pools x 2.4 to 5.1, and the east marker stands between the two table pools.
- **One shadowed light.** In Compatibility, shadows are drawn in extra passes; an omni light's cube is six faces (two in dual-paraboloid mode) and a spot's is one (Godot docs). Without shadows, a table lamp also lights the floor under its table, which shows only from low angles.
- **Light limits.** Compatibility applies at most 8 omni and 8 spot lights to a mesh, and an omni light only to meshes whose bounds touch its own (Godot docs). The shell touches all five lights, inside the limit. The per-asset GLBs (F13) keep the spots off distant furniture.
- **Pools.** With banded light, a pool has a ring edge where the surface turns 60° from the lamp. Set each spot's cone edge hard in the flat run so the pools read as printed discs. Energies and angles are starting values for that run.

### Backdrop check

How the numbers were made: Godot's Compatibility light approximated with the omni falloff (1 − (d/range)⁴)² / d, the two light steps, and light and ambient colours converted to linear. The duelist's front is 5.35 m from the chandelier and the north field 8.9 m. Contrast is (Y₁ + 0.05) / (Y₂ + 0.05) of the two colours as lit; under 1.5, only a difference in hue separates them. The roster colours are approximations of the design pages: bile yellow #D8C83A, absinthe #8FC93A, pale tin #B8BCC0, aquamarine #8ED8D0, bone #E8DDC4, red #C8282A, ox-blood #6A1B1F, gold #D4A62A, black coat #1A1A1A. The shipped tints are the archetypes' `body_color` values, read as sRGB. The duelists' ink outline is unshaded.

North field, behind `EnemySpawn`, under the decided lamp unless the row says otherwise:

| Field | Seen | Bile yellow | Absinthe | Pale tin | Aquamarine | Bone | Red | Ox-blood | Gold | Black coat | Shipped tan / blue-grey / near-white | Ink outline |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Saloon magenta (decided) | #731438 | 3.5 | 3.0 | 3.1 | 3.5 | 4.3 | 1.3 | 1.3 | 2.7 | 1.7 | 1.5 / 1.1 / 4.3 | 1.7 |
| Saloon magenta, today's lamp | #791022 | 2.9 | 2.4 | 2.5 | 2.7 | 3.5 | 1.3 | 1.3 | 2.4 | 1.8 | 1.3 / 1.3 / 3.5 | 1.8 |
| Rose #E0569A (rejected) | #842C4A | 2.7 | 2.3 | 2.4 | 2.7 | 3.3 | 1.0 | 1.7 | 2.1 | 2.2 | 1.2 / 1.4 / 3.4 | 2.2 |
| Raw wood (rejected) | #524B3F | 2.7 | 2.3 | 2.4 | 2.7 | 3.3 | 1.0 | 1.7 | 2.1 | 2.2 | 1.2 / 1.4 / 3.4 | 2.2 |
| Dark stain (rejected) | #151012 | 5.9 | 5.1 | 5.2 | 6.0 | 7.3 | 2.3 | 1.3 | 4.6 | 1.0 | 2.5 / 1.5 / 7.3 | 1.0 |
| Whitewash (rejected) | #8D806B | 1.2 | 1.0 | 1.1 | 1.2 | 1.5 | 2.2 | 3.8 | 1.1 | 5.0 | 1.9 / 3.2 / 1.5 | 5.0 |

For comparison, Main Street's depot field: bile yellow 3.3, aquamarine 3.6, bone 4.7, black coat 3.0, ink 3.2.

- The two duelists who fight here, Plata (bile yellow, absinthe, pale tin) and the Ghost (aquamarine, bone), stand out from magenta at 3.0 to 4.3, about as well as the depot field does on Main Street.
- The weak cases are the ink outline and black, at 1.7 (dark wine against black), and the Sheriff's reds, which meet this wall only in free duels. The Drunk's shipped tan placeholder gets 1.5.
- The lamp colour is what lifts Plata and the Ghost: under today's orange lamp they fall to 2.4 to 2.9, and aquamarine turns olive.
- The door behind `PlayerSpawn`, seen from `EnemySpawn`, with the outer doors shut (F7): the player's head is against raw wood (2.2 for the black coat) and the hat against the cream door head (4.5). An open door would have put ink behind them (1.0).

## B. Asset sheets

The prompt's four assets (bar, tables, balcony, shell) plus three for the objects they leave out or that the decisions split off: chairs, lamps, and dressing with the fight's debris. Each is its own GLB root in `saloon.blend` (F13, F30).

| Asset | Greybox objects in `saloon_interior` | Copies | Class | Triangles today | Budget each | Budget in scene | Objects after merging |
|---|---|---|---|---|---|---|---|
| `saloon_bar` (hero) | `Counter`, `CounterTop`, `FootRail`, `FootPost_*`, `Backbar`, `Mirror`, `Shelf_*`, `ShelfBottle_*`, `BarBottle_*`, `Spittoon_*` (24) | 1 | Eye-level piece | 448 | 4,400 | 4,400 | 6 |
| `saloon_shell` | `Plank_*`, `Wall*`, `Ceiling`, `Beam_*`, `Base_*`, `Wainscot_*`, `Rail_*`, `Door*`, `Pane_*`, `WinTop_*`, `WinBot_*`, `WinL_*`, `WinR_*` (66) | 1 | The room | 928 | 3,400 | 3,400 | 6 |
| `saloon_table` | `Pedestal_*`, `TableTop_*` (2 per table) | 2 | Module, low cover | 72 | 600 | 1,200 | 4, drawn twice |
| `saloon_chair` | The parts under `Chair_A_*` and `Chair_B_*` (7 per chair) | 8 | Module, low cover | 84 | 400 | 3,200 | 1, drawn eight times |
| `saloon_balcony` | `Balcony`, `BalconyRail`, `BalPost_*`, `Stair`, `StairRail`, `StairPost_*` (15) | 1 | Frame | 200 | 2,400 | 2,400 | 3 |
| `saloon_lamps` | `Chain`, `ChandelierRing`, `Candle_*`, `Flame_*` (14) | 1 | Fixtures | 256 | 1,400 | 1,400 | 4 |
| `saloon_dressing` | `Piano*`, `BenchLeg_*`, `Stove*`, `Barrel_*`, `Hoop_*` (16), plus the debris | 1 | Dressing and debris | 328 | 2,000 | 2,000 | 7 |
| **Scene** | 195 meshes | | | **2,976** | | **About 18,000** | **42 draw calls** |

- **Eye-level piece:** players walk up to it; the detail goes below 2.2 m.
- **Module:** one GLB instanced more than once, painted once.
- **Frame:** the structure round the north field.
- **Today's counts** are measured from the GLB, collision excluded, and include the band cuts.

**Why the budget grows.** From 2,976 to about 18,000 triangles, six times, as decided (F18): more bottles, louvred batwings and shutters, turned balusters, more debris, and turned chairs after your reference. About 70% of it sits below 2.2 m, where a player looks: eye level comes first, as the brief asks. The whole room is on screen at once and nothing is culled, so the scene total is the frame's scenery count: the budget Naughty Dog set Crash by, the polygons you could see at once, 800 in the first game (Andy Gavin). 18,000 is 1.2% of Meta's Quest 3 guideline of 1.5 million triangles per frame. The PSX look caps detail before the hardware does, and the per-asset ceilings keep it chunky.

Two limits are tighter than the triangle count:

- **Draw calls.** Today's 195 mesh objects are each a draw call, and each is drawn again into the chandelier's shadow cube, up to six faces. Merging per material (rule 26) brings the room to 42, with the modules drawn once per copy. Meta's Quest 3 guideline is under 200 per frame.
- **Lights.** Five lights, one with shadows (F3). Every light is shaded on every pixel of every mesh it reaches. Time it on a Quest with the four spots on and off.

---

### `saloon_bar` (hero)

| | |
|---|---|
| Squint | A long black block at waist height with a cream top line and a row of gold dots under it, a bright band of mirror above it cut into three arches by black columns, a black hole punched in its south arch, a stepped black crown against the magenta wall, and a gold line at its foot. Dark stain, mirror silver, brass |
| Role | The room's one rich object, along the west wall from y −4.0 to 3.4. From `PlayerSpawn`'s eye it spans 30° left (its north end, 9.7 m away) to 78° left (its south end, 4.9 m away). Its south end is one end of the fight zone. It is behind the three-NPC west marker's hips. The counter is cover only for someone who walks behind it. Players walk up to it, so everything on its front and top is seen from 1 to 2 m |
| Size | Counter 7.40 m long, 0.68 m deep (x −5.54 to −4.86), 1.05 m tall. Top 0.80 × 7.46 m, 6 cm thick, up to 1.11 m, overhanging 10 cm toward the room. Aisle behind it 0.72 m. Back bar 7.40 × 0.38 m against the wall (x −6.70 to −6.32), 2.50 m to its top, with the crown to about 3.20 m. Foot rail 7 cm across at 0.16 m. Proxies `Counter` (x −5.60 to −4.76, up to 1.10 m) and `Backbar` (up to 2.50 m) |
| Triangles | 448 today; 4,400 at most: back bar and crown 1,800, bottles 1,100, counter 800, rail, brackets, and spittoons 500, the shot bay and its shards 200 |
| Collision | Unchanged, renamed `Bar_Counter-convcolonly` and `Bar_Backbar-convcolonly`. Listed under rule 5: the crown rises about 0.7 m above `Backbar`, and the columns and cornice stand up to 15 cm proud of it, so bullets pass through those parts |

Signature details, cut from the bottom:

1. Three arched mirror bays across the back bar's face, between four columns. Each bay is about 2.0 m wide. Its mirror is a flat plane 3 cm proud of the back bar, from 1.20 to 2.30 m, under a three-segment arch rising to 2.45 m. The columns are 8-sided, 15 cm across, on 20 cm square plinths with brass capitals. This brings the mirror out of the box (Found 1).
2. The crown: a stepped cornice from 2.50 to 2.75 m, 15 cm proud, and a centre pediment over the middle bay rising to about 3.2 m, under the beams at 3.52 m. It is the west wall's skyline seen from the lane.
3. The counter front: pilasters 12 cm wide and 4 cm proud every 0.9 m, each with a brass capital block 8 cm tall under the top, so a row of gold dots runs along the bar.
4. The bar top: a cream slab 6 cm thick, overhanging 10 cm, its front edge chamfered 3 to 4 cm (exception to rule 8), returned at both ends.
5. The south bay shot through (F26): a jagged hole about 0.6 m across in the bay nearest the fight, its edge a seven-point star, showing the black back bar behind it. Three loose pieces of mirror round the hole sit tilted 2°, so they take other light steps. Shards lie on the bar top below.
6. The brass foot rail: 8-sided, 7 cm across, at 0.16 m and 0.16 m out from the counter, on four brackets, returning to the counter at both ends. Behind it, a 10 cm toe recess at the counter's foot.
7. Bottles in the bays: three 4 cm shelves cross each bay at about 1.35, 1.70, and 2.05 m, carrying about 30 bottles (6-sided, 8 cm across, 28 to 32 cm tall with a neck), amber and green, with gaps where the fight knocked some off. Six more stand on the bar top. They stand in front of the mirror, not inside the box.
8. Spittoons: two brass ones, 8-sided, 26 cm across and 10 cm tall, by the rail at y −1.6 and 1.8. The southern one lies on its side.
9. Wear: the top's south corner, the one facing the player, chipped by a 10 cm notch; one rail bracket missing, with the rail sagging 3 cm there.
10. The back bar's base cabinet, from 0 to 1.0 m, with panelled doors. It shows only from the aisle and past the counter's ends.
11. The tin heart (F17): a 20 cm milagro nailed to a middle column at 1.7 m.

- **Wear in geometry:** the shot bay, the chipped corner, the sagging rail, the fallen spittoon, the gaps on the shelves.
- **Base Color:** `M_WoodDark` Dark stain (counter, back bar, columns, crown, cabinet; replaces `M_Bar`). `M_Trim` Bone (top; replaces `M_BarTop`). `M_Mirror` Mirror silver (mirrors, mirror shards, tin heart). `M_Brass` Brass (rail, brackets, capitals, spittoons). `M_Bottle` Felt green and `M_BottleAmber` Store marigold (bottles).
- **UV:** keep each whole mirror bay one island, and each piece round the shot hole its own. Delete the faces against the wall and the floor, and the top's underside where it sits on the counter. Bottles, brackets, capitals, and shards are too small to paint and stay flat colour. Keep the columns plain prisms, with the plinth and capital as separate pieces, so each shaft unrolls as one rectangle.
- **Draws on:** board #06 (the presentation piece: ornament on the object that matters), #10 and #21 (a black shape trimmed in, or opened to show, ornament), #01 (chased metal); Brunswick's 16- to 30-foot back bars (True West); the Albuquerque saloon of about 1885, with mirrors behind shelves of liquor (Albuquerque Museum); the brass foot rail with spittoons along it (Legends of America).

### `saloon_shell`

| | |
|---|---|
| Squint | A magenta box with a black band round its foot and a white lid crossed by four black beams. Behind you, a cream door frame with louvred cream batwings against shut grey doors; on the right, louvred grey shutters in cream frames. Magenta, black, white |
| Role | The room and both duel fields. The north wall under the balcony is behind every enemy at `EnemySpawn`, and the south wall's door is behind the player as seen from there. The east wall is behind the east multi marker. The floor is the nearest surface to a standing player (1.7 m) and beam 0 the next (2.1 m) |
| Size | Inside, 13.4 × 17.4 m; walls 0.30 m thick and 4.45 m tall; ceiling underside 4.20 m; beams 0.22 × 0.68 m at y −6.2, −2.8, 2.8, and 6.6, from 3.52 to 4.20 m. A new door opening, 1.8 × 2.4 m. Five window openings, 1.4 × 1.4 m from 0.85 to 2.25 m. Dado to 1.1 m. Proxies `Floor`, `WallWest`, `WallEast`, `WallNorth`, `WallSouth`, `Ceiling` |
| Triangles | 928 today; 3,400 at most: shutters 1,000, ceiling coffers 600, batwings, frame, and outer doors 550, walls with openings and reveals 400, dado and baseboard 250, beams and braces 250, medallion and back-room door 200, floor, hatch, and sprung boards 150 |
| Collision | Unchanged, renamed `Shell_*-convcolonly`. `WallSouth` stays solid across the new door opening, since nobody walks out, and the shut outer doors fill it (F7) |

Signature details, cut from the bottom:

1. The north field: from x −2.6 to 2.6, from a 0.2 m black baseboard to the balcony's underside at 2.86 m, one flat magenta plane. No dado, rail, lamp, frame, opening, or seam crosses it.
2. The street door, agreeing with `bld_saloon` in size and shape (E): a real 1.8 × 2.4 m opening through the south wall, in a 15 cm cream frame with a 10 cm outer step and a head up to 2.55 m. Two cream batwing leaves, 0.86 m wide with an 8 cm gap, hang shut: each runs from 0.35 to 1.55 m at the hinge edge, its top falling to 1.30 m at the meeting edge in two steps, and each is a frame filled with 5 cm louvres at about 9 cm centres. The louvres are inside only; the street's leaves stay plain (F31). Behind them, at the wall's outer face, the solid outer doors are shut for the night: raw wood on this side, with an iron hasp at 1.1 m in the middle, where the player's body hides it (F7).
3. Five windows, agreeing with `bld_saloon` in size: openings 1.4 × 1.4 m from 0.85 to 2.25 m, in 15 cm cream frames with 12 cm sills, each closed by a pair of louvred raw-wood shutters set in the reveal (a 6 cm frame round 5 cm slats at about 9 cm centres). The panes behind them are hidden, so they are deleted. The south pair stays at x ±3.5, outside the player's backdrop band. The three east windows move to y −5.0, −1.5, and 2.0, off the east marker's backdrop (F9).
4. The dado: dark stain up to 1.1 m, a cream cap rail 8 cm proud with a flat top, and a 0.2 m baseboard. There is none behind the back bar, and only the baseboard in the north field.
5. The beams: four, black, each with two knee braces at the walls (from 3.0 m on the wall to 0.6 m along the beam), making triangles in the room's upper corners.
6. The ceiling: whitewash pressed tin. In the lit middle bay, between beams 1 and 2, a coffer grid of 1.2 m panels with 10 cm ribs 5 cm proud, so the ribs' sides take different light steps. The end bays are plain.
7. A ceiling medallion for the chandelier: a stepped octagon 1.0 m across, in two tiers stepping down 5 cm each.
8. The floor: one raw-wood plane (the board seams are yours to paint), with a cellar hatch in the bar's aisle (0.6 × 0.9 m, inset 1 cm, an iron ring) and two sprung boards (25 cm wide, one end lifted 3 cm) outside the fight zone, one by the piano and one by the stove, away from the markers.
9. Wear outside the fight: beam 0 sags 4 cm at mid-span; one east window frame is racked 2°; one shutter slat is missing, leaving a black slot; one length of the cap rail is split and stepped 2 cm.
10. A back-room door in the north wall under the balcony, at x 4.4, outside the field: black, shut, in a cream frame.

- **Wear in geometry:** the sagging beam, the racked frame, the missing slat, the split cap rail, the sprung boards. The fight leaves the building whole (rule 14).
- **Base Color:** `M_Wood` Saloon magenta (walls above the dado, the field). `M_WoodDark` Dark stain (dado, baseboard, beams, back-room door). `M_Trim` Bone (cap rail, door and window frames, batwings, sills). `M_Plank` Raw wood (floor, shutters, outer doors; replaces `M_Floor` and `M_FloorAlt`). `M_Whitewash` Whitewash (ceiling, medallion). `M_Iron` Iron (hasp, hatch ring). Retires `M_Glass`.
- **UV:** the north field is one island with no cuts; each wall's inner face stays whole between its openings. Delete the walls' outer faces and tops, the ceiling's top, the floor's underside, and the panes (rule 27). The batwings are mirror copies with an island each; paint both. Louvre slats become many thin islands: flat colour. The floor is a single 13.4 × 17.4 m island.
- **Draws on:** board #04 (ox-blood and cream: a two-colour image), #16 (Araki's pinks), #18 (one colour block behind the figure: the field); tin ceilings, widespread from the 1880s and painted white to pass for plaster (Wikipedia, Tin ceiling); solid outer doors outside the batwings, shut and padlocked when needed (Mental Floss); batwings "from chest to knee level" (Wikipedia, Western saloon).

### `saloon_table` (module, ×2)

| | |
|---|---|
| Squint | A green octagon on a black post, a dark cone hanging over it in its own light. Felt green, black |
| Role | Two poker tables east of the lane: the scenario's "card table gone wrong" (`saloon.tres`). Table A is one end of the fight zone. The east multi marker stands between the two, and their tops (0.78 m) are low cover round it. Both stay intact (F23); the damage lies round table A as debris |
| Size | Top 1.24 m across, from 0.72 to 0.78 m, on a pedestal. Instances at Blender (3.5, −2.5) and (4.0, 3.0), Godot (3.5, 0, 2.5) and (4.0, 0, −3.0). Proxy per table 1.24 × 1.24 × 0.80 m |
| Triangles | 72 per table today; 600 at most per table: top, rim, and felt 150, pedestal and feet 200, the game on the felt 250 |
| Collision | Footprint unchanged, renamed `Table_Top-convcolonly`. The second instance turns 180° so its accents fall on the other side |

Signature details, cut from the bottom:

1. An 8-sided top (rule 9): a black rim 8 cm wide round a green felt field inset 1 cm. The felt takes the lamp's pool.
2. A heavy pedestal: an 8-sided column 16 cm across on four splayed block feet spanning 0.8 m, the black shape under the top.
3. The game on the felt (F15, poker): a deck, a fanned hand (5 × 8 cm cards), three stacks of checks (6-sided, 4 cm across, 5 to 10 cm tall), a bottle, two glasses (6-sided, 6 cm across).
4. Wear: a 10 cm chip out of the rim.

- **Wear in geometry:** the chip. The fight's damage is in the debris set (`saloon_dressing`).
- **Base Color:** `M_Cloth` Felt green (the felt). `M_WoodDark` Dark stain (rim, pedestal). `M_Ivory` Bone (cards, checks, glasses). `M_BottleAmber` Store marigold (bottle). Retires the set's `M_BarTop`.
- **UV:** the felt is one island. The module is painted once for both tables.
- **Draws on:** faro's "green cloth" and its "checks", the same tables poker was played on (Historynet); board #18 (one colour block behind an ink drawing: green under black chairs).

### `saloon_chair` (module, ×8)

| | |
|---|---|
| Squint | A black spindle-back chair: a wide curved top rail on five turned uprights, over a thick seat on four splayed legs. Black |
| Role | Eight round the two tables: seven upright, and one, table A's south chair, lying on its back toward the player where it fell in the fight (F22). Low cover. The type is your reference image of 2026-10-19, [`victorian-turned-wooden-chair.jpg`](victorian-turned-wooden-chair.jpg): a spindle-back kitchen chair. The nearest is 3.8 m from `PlayerSpawn`'s eye |
| Size | Seat 0.42 m wide at the front and 0.38 m at the back, 0.40 m deep, 4 cm thick, its top at 0.46 m. Crest rail 0.46 m wide and 8 cm tall, its top at 0.88 m. Legs splayed 4° outward; H-stretcher at about 0.15 m. The upright ones stand at the greybox's chair positions, 0.95 m from each table's centre, facing it. The tipped one lies on its back at about Blender (3.5, −3.9), its crest rail on the floor near y −4.5 and its legs pointing back up at the table. Proxy `Chair-convcolonly`, 0.46 × 0.48 × 1.00 m, inside the module |
| Triangles | 84 per chair today; 400 at most per chair: four legs 140, two stiles 90, three spindles 70, seat 40, crest rail 25, stretchers 35 |
| Collision | The seven upright chairs keep the greybox's footprints and heights. Listed under rule 28: the tipped chair's proxy turns with its instance into a low box about 0.48 m high, running from y −4.5 to −3.5 at x 3.27 to 3.73 (F24), 1.8 m outside the corridor |

Signature details, cut from the bottom:

1. The crest rail: a wide board curved in plan (three segments), 8 cm tall and 4 cm thick, its ends overhanging the stiles by 3 cm. It is the chair's silhouette top.
2. Five turned uprights, fanning out slightly toward the top: two outer stiles, 6-sided and 6 cm thick, with a long swell under the rail and a pair of rings above the seat; three inner spindles, 6-sided and 5 cm thick, each with one pair of rings at mid-height. The gaps between them run about 3.5 cm (exception to rule 6).
3. The seat: a 4 cm plank seat with a rounded front edge (three segments) and a shallow saddle, its top stepped once by 1 cm.
4. Four splayed legs, 6-sided, tapering from 5.5 to 5 cm, each with a pair of rings under the seat; the front legs carry one more ring near the foot.
5. The H-stretcher: a side stretcher on each side and a cross stretcher between them, at about 0.15 m, 6-sided, 5 cm thick.

- **Wear in geometry:** none in the module; eight copies would repeat it. The fight's smashed chair, in the debris set, carries the wear.
- **Base Color:** `M_WoodDark` Dark stain, one material (F32). The turnings read in silhouette, against the raw floor and the green felt.
- **UV:** one chair, painted once for all eight. Each turned member is a plain prism with ring sections, so it unrolls as one rectangle. Delete the ends buried in the seat and the rail.
- **Draws on:** your reference image (a spindle-back kitchen chair: a curved crest rail, turned stiles and spindles, a saddled plank seat, splayed ringed legs, an H-stretcher); board #20 (lines as the only drawing: the spindles as line work in silhouette).

### `saloon_balcony`

| | |
|---|---|
| Squint | A black band across the far end at 3 m with a comb of cream balusters on it, two black posts framing the magenta field below, and a black stair coming down on the left. Black, cream |
| Role | The gallery over the enemy: the top of the frame round the north field. It is dressing: nobody can stand on it (1.2 m of headroom), and VR stick-walk cannot climb. Its stair and balustrade are behind the west two-NPC marker (accepted, F10) |
| Size | Deck 13.24 × 1.45 m, 0.14 m thick, its top at 3.00 m (underside 2.86 m), along the north wall. Stair 1.85 m wide, with a 3.6 m run and a 3.0 m rise (39.8°), against the west wall from y 3.65 to 7.25. Proxies `Balcony`, `BalconyRail` (x −4.55 to 6.55, from 3.0 to 3.9 m), and `Stair` (a walkable ramp) |
| Triangles | 200 today; 2,400 at most: turned balusters 1,400, stair 400, rails, fascia, and deck 300, posts and braces 200, newels and gate 100 |
| Collision | Changes listed under rule 28. Two posts at (±3.1, 7.25), 0.2 m square, get new proxies `Balcony_PostW-convcolonly` and `Balcony_PostE-convcolonly` (F12). A gate across the stair's foot gets `Balcony_StairGate-convcolonly`, 1.85 × 0.10 × 1.0 m at y 3.65, so a flat player cannot climb into the ceiling (F11). The rest stays, renamed `Balcony_*` |

Signature details, cut from the bottom:

1. The balustrade: a black top rail at 3.95 m (0.95 m above the deck, 0.25 m under the ceiling) and a bottom rail at 3.10 m, with turned cream balusters, 6-sided, 8 cm at their widest, with one swell, at 0.3 m centres; 15 cm black newels at both ends and over the posts. This is the comb against the upper wall.
2. The fascia: a 0.30 m black board along the gallery's front, from 2.80 to 3.10 m, with an 8 cm cream bead on its bottom edge. It is the frame's top line, above the enemy's hat as seen from `PlayerSpawn`.
3. Two posts at x ±3.1 under the front edge, 20 cm square, with knee braces up to the fascia: the sides of the frame (F12).
4. The stair as steps: 12 risers of 0.25 m on 0.30 m treads, raw-wood treads, and a black open stringer whose sawtooth shows to the room. A 20 cm newel at the foot, 1.15 m tall with a block cap, and a balustrade like the gallery's.
5. The gate across the stair's foot: a rail on two cream balusters, with a blank board hanging from it (F11).
6. Wear: the deck and fascia sag 5 cm between the posts; one baluster is missing toward the east end, outside the field; the third tread is sprung 3 cm.

- **Wear in geometry:** the sag, the missing baluster, the sprung tread.
- **Base Color:** `M_WoodDark` Dark stain (fascia, rails, posts, stringer, newels, underside). `M_Trim` Bone (balusters, bead, gate balusters). `M_Plank` Raw wood (treads, deck top). Retires the brown `M_Wood` deck and the brass stair rail.
- **UV:** the balusters become many small islands that take one flat colour. The fascia is one island.
- **Draws on:** the Bird Cage Theatre's twelve balcony boxes (Wikipedia); board #00 (the duel framed by scale: the enemy small under the gallery); Main Street's hotel gallery (a pale comb on a saturated wall).

### `saloon_lamps`

| | |
|---|---|
| Squint | A black wheel of six glowing cream cups with yellow flames, one cup missing, hanging in a white halo over the lane; small black cones over the bar and the tables, each above its own pool. Brass, black, glowing cream |
| Role | The fixtures of the light plan. The chandelier hangs over the lane's midpoint on the `Chandelier` light, 5.35 m from both duelists' chests and about 19° up from both spawns' eyes. No collision |
| Size | Chandelier: a hoop 1.2 m across at 3.42 m, 0.8 m tall from 3.40 to 4.20 m. The Henry Ford's kerosene chandelier of 1885 to 1900 is 0.97 m tall and 0.76 m across; this one is widened for a 13 × 17 m room. Bar lamps: 0.40 m cone shades, mouths at 2.35 m, on rods from beams 1 and 2. Table lamps: 0.45 m shades, mouths at 1.95 m, on chains from the ceiling |
| Triangles | 256 today; 1,400 at most: chandelier 800, four lamps 120 each, chains and rods 120 |
| Collision | None, as today |

Signature details, cut from the bottom:

1. The chandelier: a brass hoop 1.2 m across carrying six 8-sided brass fonts (12 cm) on short arms. Each font has a chimney and a 6-sided shade opening upward to 3.75 m, both in `M_LampGlass`, which glows (F27). A black stem rises to a 0.45 m smoke bell at 3.95 m, and a chain runs on to the ceiling medallion. Nothing hangs below 3.40 m, the light's height, so its shadows fall only on the ceiling.
2. Bar lamps (×2): black cone shades on iron rods from beams 1 and 2, over the counter at y ±2.8. They do not glow.
3. Table lamps (×2): wide black cone shades on chains, hanging low over each felt. They do not glow.
4. Flame tips: flame-yellow points (6-sided, 5 cm) in the chimneys, in `M_Flame`, which glows.
5. Wear from the fight: one of the six shades shot away, leaving a broken stub and a dark gap in the glowing ring; the chandelier hangs 2° out of level.

- **Wear in geometry:** the missing shade and the tilt.
- **Base Color:** `M_Brass` Brass (hoop, fonts, arms). `M_Iron` Iron (stem, smoke bell, chain, rods, hanging-lamp shades). `M_LampGlass` Lamp glass, glowing (shades, chimneys). `M_Flame` Flame yellow, glowing (flame tips). Retires `M_Candle`. The glowing names draw unlit since the code landed (G7).
- **UV:** the six identical shades and fonts get six sets of islands, too small to paint: flat colour.
- **Draws on:** the Henry Ford's kerosene chandelier (Plume & Atwood, brass and glass, 1885 to 1900); board #20 (total silhouette, with lines as the only drawing), #18 (one colour block behind an ink drawing: the black wheel in its white halo).

### `saloon_dressing` (dressing and the fight's debris)

| | |
|---|---|
| Squint | Piano: a black upright block with a cream key strip and two gold arms. Stove: a black pot on legs with a pipe up to the ceiling. Barrels: three black drums with iron bands. Debris: a smashed black chair and a spray of pale shards and black splinters across the floor, from the bar's end to table A |
| Role | Corner dressing and the fight. The piano stands in the south-east corner facing west, behind the player's right shoulder, and left of the door in the view from `EnemySpawn`. The stove stands in the north-east corner, the room's only heat, 26° right of the lane from `PlayerSpawn` and well outside the north field. The barrels stand at the bar's south end, level with the player and about 4 m to the left: full height now, they are crouch cover 3.6 m from `PlayerSpawn` (F14). The debris runs from the bar's south end across the lane to table A, in front of the player (F22, F25) |
| Size | Piano 1.40 × 0.62 × 1.19 m, keys at 0.74 m; bench 0.70 × 0.36 m at 0.32 m. Stove belly 0.80 m across, pipe 14 cm across. Barrels 0.56 m across and 0.90 m tall. Debris pieces 5 to 50 cm, lying flat. Proxies `Piano`, `Stove`, `Barrel_0` to `Barrel_2` |
| Triangles | 328 today; 2,000 at most: piano and bench 400, stove 300, barrels 450, debris 850 |
| Collision | Listed under rule 28. The piano moves 0.8 m east, against the east wall, its proxy with it (F21). The three barrel proxies keep their footprints and rise to 0.90 m (F14). The smashed chair's main piece gets `Dressing_BrokenChair-convcolonly`, about 0.6 × 0.6 × 0.25 m at Blender (−2.8, −3.6), 1.0 m outside the corridor (F24). The rest of the debris has none, and none of it reaches 0.30 m, the corridor's lower edge (F25). Renamed `Dressing_*` |

Signature details, cut from the bottom:

1. The piano: an upright case with a lid, a fallboard, a key bed at 0.74 m with a cream key strip, two turned front legs (8-sided), a music desk, and two brass candle arms on the front panel.
2. The debris set (F22 to F25): a smashed chair (the chair module's parts, broken: the seat on its side with two legs, the crest rail, two spindles, a snapped leg); 30 to 40 shards of mirror and bottle glass, flat 5 to 12 cm triangles 5 mm above the floor; 15 to 20 black splinters; two broken bottles (a neck and a base); spilled checks and a few cards. They run from the bar's south end, across the lane, to table A.
3. The barrels: full barrels, 8-sided, 0.9 m tall, their staves bulging 10% at the waist, two iron hoops each (8 cm tall, 2 cm proud), and a spigot on one.
4. The stove: an 8-sided pot belly 0.8 m across on four short legs, a door with a latch, and a 14 cm 6-sided pipe straight up to the ceiling with a damper and a ceiling collar (Found 6).
5. A sheet-iron stove board under the stove, 1.0 m square, and the piano bench on turned legs.
6. Wear outside the fight: the piano's lid propped 3 cm open; the stove pipe kinked 2° at a joint; one barrel's lid off.

- **Wear in geometry:** the debris itself, plus the open lid, the kinked pipe, and the missing lid.
- **Base Color:** `M_WoodDark` Dark stain (piano case, bench, barrels, smashed chair, splinters). `M_Ivory` Bone (keys, checks, cards). `M_Iron` Iron (stove, pipe, stove board, hoops, spigot). `M_Brass` Brass (piano arms). `M_Mirror` Mirror silver (mirror shards). `M_Bottle` and `M_BottleAmber` (bottle glass). Retires the brown `M_Wood` and `M_Trim` on these pieces.
- **UV:** keep the pipe a plain prism so it unrolls as one rectangle. Each barrel's side is one island. The debris pieces are too small to paint: flat colour.
- **Draws on:** the Bird Cage's original 1881 rosewood piano and its walls "riddled with gunshot holes" (Wikipedia); early saloons warmed by "a single wood-burning stove" (Wikipedia, Western saloon); board #12 (workwear exaggerated: padded, chunky, oversized).

## C. Build order

**Hero: `saloon_bar`.**

- It is the room's identity and its densest eye-level piece, so it sets the 5 cm floor, the detail per metre, and the triangle rate the other assets follow.
- It sets the kit the rest reuse: black wood with cream and gold trim, brass, mirror, bottles.
- It fixes the greybox's worst fault, the mirror and bottles buried in the box, and it carries the fight's first mark, the shot bay.
- It is in view in every Saloon duel, sits behind the three-NPC west marker, and is the piece players walk up to.
- It meets the floor, the west wall, and the two bar lamps, so its review also tests the light plan's first spots.

The shell is bigger but simpler: its key surface, the north field, is a single plane.

**Order** (×N marks a modular repeat):

1. `saloon_bar`, the hero, with the floor plane and the west wall roughed in. Scene edits for its review: the lamp colour and ambient (F2) and the two bar spots (F3).
2. `saloon_shell`: the field, the door with its louvred batwings and shut outer doors, the shuttered windows (F9), the dado, the beams, the ceiling. This is the second reviewed asset.
3. `saloon_table` ×2, its second instance turned 180°, and `saloon_chair` ×8, one tipped; then the two table spots. Re-run `--autotest=multi`.
4. `saloon_balcony`, with the posts (F12) and the stair gate (F11). Re-run `multi` and `load`.
5. `saloon_lamps`: the chandelier, the bar lamps ×2, the table lamps ×2. Its glow needs the code change in G7; review the lamps after it lands.
6. `saloon_dressing`: the piano (F21), the stove, the barrels ×3 at full height (F14), and the debris. Re-run `multi`.

Repeats inside the assets: five windows with ten shutters, four columns, three mirror bays, the bottles, the balusters, six shades, two spittoons.

## D. Review checklist

### Views

| View | Where | Camera | For |
|---|---|---|---|
| Lane P | Godot, Saloon, shaders on | Eye at (0, 1.7, 5), looking at (0, 1.7, −5), the flat camera's field of view | North field, balcony, bar, tables, chairs, chandelier, the debris in the lane |
| Lane E | Godot | Eye at (0, 1.7, −5), looking at (0, 1.7, 5) | Door and outer doors, south shutters, piano, barrels, tipped chair |
| Flank | Godot | From Lane P's eye, aimed at each multi marker at 1.7 m: (−3, 1.7, −2), (3.8, 1.7, −0.3), (−3, 1.7, 0.5) | The stair (F10), the east windows (F9), the counter |
| Up | Godot | From Lane P's eye, aimed at the chandelier at (0, 3.4, 0) | Chandelier, its glow and halo, ceiling bays, beams, the shadow line across the balustrade |
| Down | Godot | From Lane P's eye, pitched 50° down | The debris at the player's feet |
| Close | Godot | Eye 1.7 m up and 1.5 m in front of the piece, level: the bar's front from (−3.3, 1.7, 0), a table's rim, a chair, 1.5 m inside the door, the piano's keys, the stove | Eye-level detail |
| Front | Blender, `saloon.blend` | 5 m in front of the piece's main face, 1.7 m up, aimed at its centre, 50 mm lens | Every asset (its duel-lane view in Blender) |
| Three-quarter | Blender | 45° off the main face, 6 m out, 1.7 m up, 50 mm lens | Every asset |
| Silhouette | Blender: Workbench, flat lighting, one black colour, white world | Front, the side, and the front again from 10 m | Every asset |
| Squint | The Front render | Shrunk to 64 px wide, enlarged back with nearest filtering | Every asset |

- The Saloon has one lighting state; there is no time of day to cycle.
- The flat camera's eye is 1.7 m above the floor.
- For the Godot views, a temporary `Camera3D` in the editor does the job. Do not save it into the scene.
- Finish in a headset: stand at `PlayerSpawn`, look down at the glass, then walk to the bar, a chair, the door, and the stair gate.

### Pass or fail, every asset

1. **Silhouette:** can you name the asset from its black outline alone?
2. **Squint:** does the 64 px render show one shape and at most three flats?
3. **Size floor:** is every modeled feature at least 5 cm on furniture, fixtures, and below 2.2 m, and at least 10 cm on the shell and gallery above it?
4. **Wear:** outside the fight zone, one accent per 3 m of wall or per piece of furniture, in silhouette; inside it, the debris as listed; no wear in any colour?
5. **Budget:** triangles within the budget, and objects equal to materials?
6. **Names:** unique, no `.001`, prefixed with the asset, proxies suffixed `-convcolonly` with no dot in the name?
7. **UVs:** did `dev/unwrap_per_glb_blender.py -- --relayout --glb <name>` print no TINY share on a face you mean to paint? Does Blender's UV Select Overlap find nothing? Are the north field and each whole mirror bay single islands?
8. **Collision:** unchanged, or the listed change, with `load` and `multi` passing after export and reimport?
9. **Lamps:** does nothing on the chandelier hang below 3.40 m?

### Pass or fail, in context

10. Lane P: is the north field one flat magenta plane behind the enemy from the shoulders to above the hat, with the balcony's fascia above the hat?
11. Do Plata's and the Ghost's colours, as swatches and as the shipped tints, separate from the field at squint?
12. Lane E: is the player's head against the shut outer doors and the hat against the cream door head, with no black behind them?
13. Flank: is the east marker's head clear of every window? Does the stair behind the west two-NPC marker look the way F10 accepted it?
14. Up: do the flames and the chandelier's glass draw flat in their own colour, and nothing else? Do the beams hold the light in the middle bay as intended? Does beam 3's shadow line across the balustrade look deliberate?
15. Do the four pools land on the counter and the felts, and stay off the lane and the north field?
16. Down and Lane P: does the debris in the lane read as glass and splinters, without a shard catching the eye like a target near the enemy?
17. Close, in a headset: do the bar, a chair, the door, and the piano look true to size from 1.5 m? Do the louvres, the balusters, or the chair's spindles shimmer when you move your head?
18. Is the room loud under the decided lamp: magenta, black, white, green, gold, and not brown?

### Asset checks

| Asset | Check |
|---|---|
| `saloon_bar` | Do the mirrors stand in front of the back bar now? Does the shot bay read as a hole, not a stain? Do the bottles show in the bays from Lane P? |
| `saloon_shell` | Is the north field free of every line from 0.2 to 2.86 m within ±2.6 m? Do the door and windows match `bld_saloon`'s sizes (E)? |
| `saloon_table` | Do the two instances read as the same table without the repeat showing? Does each felt take its lamp's pool? |
| `saloon_chair` | Does it read as your reference chair at 4 m? Does the tipped one lie flat on the floor, its proxy with it? |
| `saloon_balcony` | Does the gate stop a flat player at the stair's foot? Do the posts frame the field without entering it? |
| `saloon_lamps` | Do all the chandelier's shadows stay on the ceiling? Does the missing shade read as a gap in the glowing ring? |
| `saloon_dressing` | Does the stove pipe reach the ceiling? Is the piano against the wall? Do the barrels give cover at 0.9 m? Does no debris rise to 0.30 m? |

### Tests

Run `--import`, then `--autotest=load` (the world shader on every Saloon surface, bare proxies, `Chandelier` present and no `Sun`, wind zero; after G7, the glow check) and `--autotest=multi` (each Saloon marker on the floor and clear of geometry, a 0.3 m capsule up to 1.7 m, with 2 and 3 NPCs):

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=multi
```

Headless runs do not compile shaders. The look needs a flat run, then a headset.

## E. Cross-scene dependencies

`docs/design/scenarios/main_street.md` exists. This sheet inherits its global rules 1 to 28, its palette, its backdrop method, and its build lessons. The exceptions are in A.

**Agreement with `bld_saloon`, the street front** (Main Street's sheet and the built GLB). You leave one and enter the other.

| | `bld_saloon`, as built | Saloon interior |
|---|---|---|
| Era | An 1880s false front | The same |
| Paint | Saloon magenta street face, bone trim, raw-wood sides and back | Saloon magenta walls inside (F5), bone trim |
| Door | A 1.8 × 2.4 m opening from the boardwalk deck (+0.40), a 15 cm bone frame with a 10 cm outer step, an ink void 20 cm deep | The same opening from the floor. The void becomes the shut outer doors (F7) |
| Batwings | Two plain bone leaves, 0.86 m wide with an 8 cm gap, from 0.35 to 1.55 m above the deck at the hinge, the top falling to 1.30 m at the meeting edge in two steps | The same outline, louvred. Accepted mismatch: the street's leaves stay plain (F31) |
| Windows | Two, ink panes 1.4 × 1.4 m from 0.85 to 2.25 m above the deck, inset 12 cm, 15 cm bone frames, 12 cm sills, at ±2.5 m | The same openings and frames at ±3.5 m (the wall inside is 13.4 m wide, and at ±2.5 m the frames would enter the player's backdrop band), closed by louvred shutters for the night (F8). By day, on the street, the shutters stand folded back |
| Sign | A bone board on the false front | Not seen from inside |
| Size | 9 × 12 m, body 4.0 m | 14 × 18 m, walls 4.45 m: one and a half times the street front. Accepted: the 12 m corridor and the room behind both spawns cannot fit in 12 m, and the two are separate scenes |

**What the Saloon adds.** Five palette entries, for any later sheet that wants them: Brass, Mirror silver, Felt green, Flame yellow, and Lamp glass. The two glowing names work in any scenario: the code has landed (G7). The Saloon itself keeps rule 21: no company blue.

**Build lessons from Main Street,** which apply here unchanged:

- Set colours on the per-GLB material copies, or delete stale copies. The seven new roots get fresh copies (`M_Wood__saloon_bar`), and the old `__saloon_interior` copies keep their brown values until they are deleted.
- Use headless Blender, or close the live session first: the unwrap script saves the `.blend`.
- Run the unwrap with `--relayout` while nothing is painted.
- Check the sheet's numbers against each other before modeling. This sheet already moved the east windows, raised the balcony rail, and brought the mirror out of the back bar for that reason.
- Name collision proxies without dots.
- Model the finals in `saloon.blend`, and never re-run `dev/build_saloon_blender.py` once the first final lands. It clears the scene and runs the paused trim-sheet pass (Main Street's F20).

## F. Decisions

Answered on 2026-10-19 in nine rounds. Seven answers departed from the recommendation: F4, F8, F14, F18, F20, F25, and F31. F16 was folded into the fight questions (F22 to F25) once F20 chose "after a fight". F22 to F32 are follow-ups that those answers raised; F30 also brought your reference image for the chair. The last column says what each decision changes on this page or in the scene.

| # | Question | Decision | What it changes |
|---|---|---|---|
| 1 | Time of day inside | Night | No window light; the background stays near-black |
| 2 | Lamp and ambient colour | Paler warm: light (1, 0.93, 0.82), ambient (0.7, 0.66, 0.62) at 0.25 | Scene: the `Chandelier`'s colour and the ambient. The palette's "Seen" column and the backdrop check use it |
| 3 | Light rig | The chandelier and four unshadowed spots, two over the bar and two over the tables | Scene: four new SpotLight3D nodes (light plan) |
| 4 | Glowing lamp glass | Yes: a self-lit material class | Needs code (G7). F27 to F29 say what glows and how |
| 5 | Wall colour | Saloon magenta | The palette and the backdrop check stand |
| 6 | Ceiling | White pressed tin, coffered in the lit middle bay | |
| 7 | Street door at night | The outer doors shut | Rule 19 exception: no void behind the batwings |
| 8 | Windows | Closed interior shutters, louvred raw wood | No pane shows; the panes are deleted; `M_Glass` retires |
| 9 | Window behind the east multi marker | Move the east windows to y −5.0, −1.5, and 2.0 | Shell |
| 10 | Stair behind the west two-NPC marker | Accept it as an exception to rule 22 | |
| 11 | Balcony headroom | Gate the stair's foot | New proxy `Balcony_StairGate-convcolonly` |
| 12 | Balcony supports | Two posts at x ±3.1 | New proxies `Balcony_PostW-convcolonly` and `Balcony_PostE-convcolonly` |
| 13 | One GLB or several | Per-asset GLBs: six, then seven with the chair module (F30) | `saloon.tscn` instances, copied `.import` files, rows in the texturing docs (G1) |
| 14 | Keg height | Full barrels, 0.9 m | The three barrel proxies rise to 0.9 m: new crouch cover 3.6 m left of `PlayerSpawn` |
| 15 | Game on the tables | Poker on both | One table module |
| 16 | "A card table gone wrong" | Folded into the fight: table A's south chair lies tipped (F22 to F24) | |
| 17 | Lore mark | The tin heart on a back-bar column | |
| 18 | Scene budget | About 18,000: more bottles, louvred batwings and shutters, turned balusters, more debris | The budgets in B |
| 19 | Size floor | 5 cm on furniture, fixtures, and below 2.2 m; 10 cm on the shell and gallery above | Rule 6 exception |
| 20 | Wear | After a fight | Rule 14 exception: things break and fall inside the fight zone (F22 to F26) |
| 21 | The piano's place | Against the east wall | Its proxy moves 0.8 m east |
| 22 | Where the fight happened | Between table A and the bar's south end | The fight zone: the room's south middle, in front of `PlayerSpawn` |
| 23 | How the tables carry the damage | Both stay one intact module; the damage is a separate debris set in the dressing GLB | |
| 24 | Debris collision | Low proxies on big pieces only | The tipped chair's proxy lies down with it; the smashed chair gets `Dressing_BrokenChair-convcolonly` |
| 25 | Debris in the lane | Allowed | Visual only, below the 0.30 m collision band, with no proxy |
| 26 | The mirror | The south bay shot through | Bar |
| 27 | What glows | The flames and the chandelier's glass | New `M_LampGlass`; the hanging lamps' shades stay dark |
| 28 | How it glows | Flat and unshaded, exactly its colour | Code (G7) |
| 29 | How the importer knows | By base name, a table in the import script | Code (G7) |
| 30 | Chairs | A chair module ×8, one instance tipped; the shape from your reference image | Seventh GLB, `saloon_chair` |
| 31 | Louvred batwings against the street's plain leaves | Louvres inside only | Accepted mismatch with `bld_saloon` |
| 32 | Chair colour | Dark stain | The turnings read in silhouette |
| 33 | Do glowing pieces cast shadows (asked after the hero was approved) | No | The importer turns shadow casting off on glowing meshes (G7) |
| 34 | How a painted image shows on a glowing surface | The painted image, unlit | A glowing surface shows its painted texels exactly, ignoring light (G7) |

## G. Pipeline friction

Where the existing texturing pipeline (`docs/TEXTURING.md`) adds work or constraints beyond "model and UV unwrap, then you paint by hand".

**Verdict on the unwrap: reuse `dev/unwrap_per_glb_blender.py` as it is.** It already does the UV job: one non-overlapping 0-to-1 layout per GLB at one texel density, islands upright and never mirrored, and `uv_lock` to keep hand edits. It treats every root empty in `saloon.blend` as its own GLB, so the split (F13) needs no change to the script. The items below are its edges.

1. **One image per GLB, now seven GLBs.** Today 195 meshes share one 256 px image at 5.0 px per metre, and 122 of them get less than 16 px² (`TEXTURING.md`): a table leg is narrower than a pixel. Decided: one root per asset (F13, F30), each with its own image. Rough densities at 256 px: bar 25 to 30 px per metre, table and chair well over 100, balcony under 20 (its 13.2 m deck is one island and cannot exceed 256 px), lamps and dressing 60 or more, shell about 8. Cost: six more GLBs, each with a `.glb.import` copied from `saloon_interior.glb.import` (`import_script/path` and `gltf/embedded_image_handling=3`, or `load` fails); instance nodes in `saloon.tscn` (the table twice, the chair eight times); the proxies move with their assets; new rows in `TEXTURE_LIST.md` and `TEXTURING.md`; and `saloon_interior` retired.
2. **The shell stays coarse even alone,** at about 8 px per metre: a 4.2 m wall gets about 34 px. Simplest: accept it and paint big flats. Alternatives: a bigger image for that one GLB (`TEX_PX` is one constant for every map, so this is code), or a split of the shell into walls, floor, and ceiling GLBs (more images, the same draw calls).
3. **Hidden faces eat texture.** The unwrap lays out every face at one density, hidden ones included. Simplest: delete them while modeling (rule 27), the panes behind the shutters included. Cost: none.
4. **Copies inside one GLB get separate islands.** Six shades, about 54 balusters, about 36 bottles, the louvre slats, the shards: the unwrap never stacks copies. Simplest: accept it; they are too small to paint and stay flat colour. Alternative: stack copies by hand after the unwrap, which `uv_lock` keeps. Never stack mirrored copies such as the batwings: they would paint backwards. The chairs and tables avoid this as modules, painted once.
5. **A plain run keeps old UVs.** Simplest: run `-- --relayout --glb <name>` after each final. Cost: none while nothing is painted; after painting, a relayout breaks the image's fit.
6. **The build script wipes finals.** `dev/build_saloon_blender.py` clears the scene, rebuilds the greybox, and runs the paused trim-sheet pass (band cuts, strip UVs, a `TrimSheetPreview` node). Simplest: model the finals in `saloon.blend` and never re-run the script after the first one lands. Cost: the greybox survives only in git history.
7. **The glow needs code (F4, F27 to F29, F33, F34).** Today the importer skips any scenario material with emission, and `load` fails, so nothing can glow. The decided feature: a table of self-lit base names in `assets/shaders/world_surface_import.gd` (`M_Flame`, `M_LampGlass`), an unshaded path in `assets/shaders/world_surface.gdshader` that draws them exactly their colour, and a `load` check that only those names glow. Glowing meshes cast no shadow (F33), and a painted image shows on them unlit (F34). Simplest: build it as its own task before the lamps' review. Cost: a code change and a test, outside "model and UV unwrap". **Landed** with `saloon_lamps` (H, "The glow code"): a `SELF_LIT` table and `cast_shadow` off in the importer, a `self_lit` uniform in the shader, and the `load` check.
8. **No alpha and no vertex colours.** No lace curtains, cut-out fringe, or see-through glass, and no PSX corner-colour shading: every gap is geometry, louvres and shards included, which the budget covers.
9. **Names set behaviour,** as on Main Street. The magenta walls are still `M_Wood`. Brass, mirror, felt, flame, lamp glass, and ivory get no grain, which suits them. Never use a sway name (`M_Yucca`, `M_Scrub`, `M_ScrubDry`, `M_Hay`). Exact values and one roughness let the importer merge materials. Cost: naming discipline only.
10. **Metal and gloss settings do nothing.** The shader drops metallic and specular, so the greybox's metallic 0.15 to 0.9 and roughness 0.08 to 0.45 only split materials. Simplest: set 0.9 and 0 everywhere (rule 23). Cost: none.
11. **Lights live in the scene, not the GLB.** The four spots, the lamp colour, and the ambient are edits to `saloon.tscn`, outside "model and UV unwrap". `load` needs `Chandelier` to stay an OmniLight3D with that name, and no `Sun`. Cost: one scene edit, made with the hero.
12. **Blender cannot judge the light.** The banded light, Compatibility's separate pass for the shadowed chandelier, which works in sRGB rather than linear (Godot docs), the light pools, and the glow do not show in Blender. Simplest: judge colours, pools, and glow in a flat run, then a headset. Cost: one flat run per reviewed asset.
13. **The texturing docs go stale.** `docs/TEXTURE_LIST.md` and the tables in `docs/TEXTURING.md` will be wrong after the remodel and the split. Simplest: refresh them from the script's printout when the finals land.

The trim sheet, its texel-density targets, and the texture ripper play no part in this sheet.

## H. As built

### `saloon_bar` (hero)

The hero, `saloon_bar`, built on 2026-10-19 in `saloon.blend` and exported by `dev/unwrap_per_glb_blender.py -- --map saloon --glb saloon_bar --relayout`, untextured. `saloon_interior` was re-exported without `--relayout`, so it keeps its UVs and loses the bar. The other six assets are still greybox in `saloon_interior`.

- **Tests:** `--import`, then `load` and `multi`: both pass.
- **Unwrap:** 6 meshes, 659 islands, 20.0 px/m at 256 px (pad 1, 53% covered), no TINY share. No UV overlap across the six meshes. Each whole mirror bay is one island. The shot bay's mirror, its three loose pieces, the heart, and each shard are separate islands.
- **Collision:** unchanged. `Counter-convcolonly` and `Backbar-convcolonly` moved under `saloon_bar` as `Bar_Counter-convcolonly` (x −5.60 to −4.76, y −4.0 to 3.4, z 0 to 1.10) and `Bar_Backbar-convcolonly` (x −6.70 to −6.32, same y, z 0 to 2.50), with the same boxes.
- **Scene (C step 1):** `Bar` instances `saloon_bar.glb` at the origin beside `Interior`. The `Chandelier` light and the ambient take F2's colours. `BarLampS` and `BarLampN` are new: unshadowed SpotLight3Ds pointing straight down, energy 1.0, range 3.5 m, 35°. Their `spot_angle_attenuation` is 8.0 (the default is 1.0), so the pool keeps full light until the last tenth of the cone and the edge is hard.
- **Views:** Blender renders: Front at 5 and 10 m, Three-quarter, two Close views, Silhouette (front at 5 and 10 m, side), and the 64 px squint. A flat Godot capture of Lane P and the bar's Close view, outside the repo. The in-context and headset review is still open.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `saloon_bar` | 2,532 / 4,400 | 6 | 1 |

| Object | Material | Triangles |
|---|---|---|
| `Bar_Wood` | `M_WoodDark__saloon_bar` | 849 |
| `Bar_Top` | `M_Trim__saloon_bar` | 36 |
| `Bar_Mirror` | `M_Mirror__saloon_bar` | 69 |
| `Bar_Brass` | `M_Brass__saloon_bar` | 354 |
| `Bar_BottlesGreen` | `M_Bottle__saloon_bar` | 569 |
| `Bar_BottlesAmber` | `M_BottleAmber__saloon_bar` | 655 |

The bottles take 1,224 triangles, over their 1,100 line in B but inside the asset's total. Every other line is well under its share.

**Where the build departs from B:**

- **Six sides, not eight.** The columns (15 cm across), the foot rail (7 cm), and the spittoons (26 cm) are 6-sided. B says 8-sided, but rule 9 gives 6 sides under 30 cm, and A lists no exception to it.
- **Bays.** Four columns from end to end put their centres 2.37 m apart, so each mirror is 2.27 m wide rather than about 2.0 m.
- **Columns and plinths.** The columns are 15 cm across their flats and stand 15 cm proud. The plinths (20 cm) and the two-tier brass capitals (17 and 21 cm) stand 17.5 cm proud, past B's "up to 15 cm". The plinths stand on a back counter, 5 cm thick at 1.00 to 1.05 m and 19 cm proud, which B does not list. Between the plinths and the counter top the aisle narrows to 0.56 m. The collision aisle is unchanged at 0.72 m.
- **Shelves.** Shelves are 10 cm deep and 4 cm thick, in dark stain. The 4 cm comes from B and sits under the 5 cm floor.
- **Bottles.** 31 bottles on the shelves and 6 on the top. Each bottle is 8 cm across its corners and has a neck 5 cm across its flats. Rule 27 deletes the face against the mirror, and the caps of the bottles on the top two shelves, whose tops stand above 1.9 m.
- **The shot.** The hole is centred at y −2.55, 1.86 m up, and the 1.70 and 2.05 m shelves cross it. Shelves 2 and 3 carry no bottles in front of it. The three loose pieces are the notches between star points next to the hole, each tilted 2° about its outer edge. Each is also shrunk 3% so it stays its own island, which leaves a hairline crack that shows in Godot. In Blender's light they take the same tone as the mirror. Shards: four of mirror and one green on the back counter under the bay; three of mirror and one amber on the top's south end.
- **Foot rail.** There are five bracket positions. Four brackets are present and the southernmost, at y −2.67, is missing; the rail sags 3 cm there. Each bracket is an L: an arm from the counter and a post down to the floor.
- **Chip.** A 10 cm jagged notch through the top's full thickness at the south front corner. The chamfer stops at it.
- **Crown.** The three cornice steps return at the ends by their own projection: 7, 11, and 15 cm. Under the top step runs a row of 47 dentils, 6 cm square and 4 cm proud, which B does not list (376 triangles). The pediment steps up in three tiers to 3.08 m, then a low gable rises to 3.20 m.
- **Counter and cabinet.** Nine pilasters stand at 0.91 m centres, with a raised panel between each pair and one on each end. The base cabinet has two raised door panels per bay and no pulls.
- **Heart and spittoons.** The tin heart is on the south-middle column (y −1.48), 20 cm wide, 14 cm tall, and 1.2 cm thick. The upright spittoon stands at y 1.8. The southern one lies on its side at y −1.6, mouth toward the room.
- **UVs.** Merging one object per material (rule 26) stops the unwrap from unrolling a column shaft into one rectangle. Each shaft becomes three islands. The density is 20 px/m, against G1's estimate of 25 to 30, because 659 small islands each carry a pad.

**Still open:**

- The in-context review in Godot and a headset: D, items 10 to 18, and the bar's asset checks with the shell and the dressing in place.
- Whether the 2° tilt on the loose pieces ever crosses a light step in game.
- Quest timing with the two bar spots on and off (B's light limits).

### `saloon_shell`

Built on 2026-10-19 in `saloon.blend` under a new root `saloon_shell` and exported by `dev/unwrap_per_glb_blender.py -- --map saloon --glb saloon_shell --relayout`, untextured. The 66 greybox shell meshes (`Plank_*`, the four `Wall*`, `Ceiling`, `Beam_*`, `Base_*`, `Wainscot_*`, `Rail_*`, the seven `Door*`, `Pane_*`, `WinTop_*`, `WinBot_*`, `WinL_*`, `WinR_*`) are deleted from `saloon_interior`, which was re-exported without `--relayout`. The unused `M_Floor`, `M_FloorAlt`, and `M_Glass` copies of `saloon_interior` are deleted.

- **Tests:** `--import`, then `load` and `multi`: both pass.
- **Unwrap:** 6 meshes, 663 islands, 6.4 px/m at 256 px (pad 1, 61% covered). One TINY share: `Shell_Iron` (the hasp and the hatch ring, 3.0 px²), which stays flat colour. No UV overlap across the six meshes. The north wall, field included, is one island; so is each other wall and the floor.
- **Collision:** unchanged. `Floor`, `WallWest`, `WallEast`, `WallNorth`, `WallSouth`, and `Ceiling` (`-convcolonly`) moved under `saloon_shell` as `Shell_Floor-convcolonly` and so on, with the same boxes: floor x −7.0 to 7.0, y −9.0 to 9.0, z −0.4 to 0; west and east walls x −7.0 to −6.7 and 6.7 to 7.0, north and south walls y 8.7 to 9.0 and −9.0 to −8.7, all 0 to 4.45 m; ceiling 4.2 to 4.45 m. `Shell_WallSouth-convcolonly` stays solid across the door.
- **Scene:** `Shell` instances `saloon_shell.glb` at the origin beside `Bar` and `Interior`. Nothing else in `saloon.tscn` changed.
- **Views:** Blender renders: Front of the north field, the south wall, and the east wall at 5 m (and the field flat-lit), Three-quarter of the north and south walls, Close views of the door, a south window, and the hatch, Up, the 64 px squints, Silhouettes of the door and windows without the walls, and Lane P, Lane E, Flank, and Up with the greybox in place. Flat Godot captures: Lane P, Lane E, the Flank to the east marker and to the west two-NPC marker, Up, Down, the door's Close view from 1.5 m inside it, Close views of an east and a south window, and a south window from `EnemySpawn`. All outside the repo. The headset review is still open.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `saloon_shell` | 2,111 / 3,400 | 6 | 1 |

| Object | Material | Triangles |
|---|---|---|
| `Shell_Walls` | `M_Wood__saloon_shell` | 163 |
| `Shell_Dark` | `M_WoodDark__saloon_shell` | 292 |
| `Shell_Trim` | `M_Trim__saloon_shell` | 464 |
| `Shell_Plank` | `M_Plank__saloon_shell` | 624 |
| `Shell_Tin` | `M_Whitewash__saloon_shell` | 512 |
| `Shell_Iron` | `M_Iron__saloon_shell` | 56 |

The shutters and their backing take 448 triangles of their 1,000, and the coffer ribs 450 of their 600. The floor is built from shared grid quads so it stays one island around the hatch and the boards; it takes 156 triangles, and 182 with the hatch and boards, over its 150 line but inside the total.

**Where the build departs from B:**

- **A dark backing behind the shutters.** Slats 5 cm tall at 9 cm centres cannot overlap, so their 4 cm gaps see straight through, and with the panes deleted they would show the background. A dark-stain board closes each opening 6 cm behind the slats. The gaps read as dark lines, and the missing slat as the black slot B asks for. It adds `M_WoodDark` to the windows.
- **Louvres.** Every slat is one tilted quad, 5 cm tall and 3 cm deep, front edge up; the shader draws both sides. Shutters: leaves 0.70 m wide, a 6 cm frame 4 cm thick whose front sits 6 cm behind the wall face, 14 slats at 9.1 cm centres (3.9 cm gaps). Batwings: 8 cm stiles, a 10 cm bottom rail, 9 slats at 8.6 cm centres (3.6 cm gaps). Horizontal slats cannot follow the stepped top, so the batwings are louvred only up to 1.22 m. Above that, the top rail is one solid cream board cut to the stepped top: 8 cm deep at the meeting edge and 33 cm at the hinge.
- **Door.** The casings are 15 cm wide and 8 cm proud. The head is a 15 cm board from 2.40 to 2.55 m, 13 cm proud, stepping 10 cm past the casings on each side as `bld_saloon`'s does. The cream jambs and soffit run back through the wall to the outer doors, whose inner face is 26 cm behind the wall face. The batwings' fronts are 2 cm behind it, and the leaves are 5 cm thick. The hasp is an 8 × 16 cm plate with a 6 × 8 cm padlock, which B does not list.
- **Windows.** The casings and head are 15 cm wide and 5 cm proud. The 5 cm sill projects 12 cm and its top runs back into the reveal to the shutters, over a 10 cm apron that B does not list. The jambs and head soffit are cream.
- **North field.** One magenta polygon covers the whole north wall: the field from 0.2 to 2.86 m, the wall beside it above the dado, and the wall above the balcony. The field is therefore part of one uncut island. The dado and cap rail stop at x ±2.6 with returned ends. The strip behind the balcony deck's edge is kept, since the greybox deck stops 7.5 cm short of each side wall.
- **Dado.** The dado is a flush paint line on the wall face. The cap rail runs from 1.10 to 1.17 m and the baseboard is 3 cm proud. On the west wall the dado runs outside the back bar, behind the stair too.
- **Wear.** The racked frame is the east window at y −5.0, sheared 2° so its head shifts 5.4 cm north; the wall face stays behind it, so a sliver of wall shows instead of a hole. The missing slat is the tenth from the bottom of the south window at x 3.5, east leaf. The cap rail splits on the east wall at y 4.4 and runs 2 cm lower from there to the north corner. Beam 0 sags 4 cm at mid-span, sides and all, and the ceiling stays whole over it so the gap shows ceiling.
- **Beams and braces.** The braces are 12 cm wide and about 11 cm deep, from 3.0 m on the wall to 0.6 m along the beam. The ceiling is cut over beams 1 to 3, whose tops meet it.
- **Coffers.** Ten by four panels of 1.25 × 1.27 m (B: 1.2 m), so the ribs fill the bay exactly. The ribs are 10 cm wide and 5 cm deep and run only between panels, with no rib against the beams or the walls. Ribs cross at x 0 and y 0, under the medallion.
- **Medallion.** Two octagonal tiers below the ribs: 1.0 m across from 4.15 to 4.10 m, then 0.6 m across from 4.10 to 4.05 m.
- **Hatch.** 0.5 × 0.9 m (B: 0.6 × 0.9), at x −6.11 to −5.61 and y 0.40 to 1.30. It fits the 0.57 m of aisle floor visible between the back counter (x −6.13) and the bar top's back edge (−5.56). Its lid is 1 cm down, with a flat 6-sided iron ring 18 cm across and 1.5 cm thick.
- **Sprung boards.** Each is 25 × 120 cm, its free end 3 cm up. One is by the piano at x 4.30 to 4.55, y −7.6 to −6.4, lifted at its north end. The other is by the stove at x 4.40 to 4.65, y 5.6 to 6.8, lifted at its south end.
- **Back-room door.** A 0.9 × 2.1 m leaf recessed 4 cm, in a 15 cm frame 5 cm proud up to 2.25 m.
- **Hidden faces.** Rule 27 deletes the faces behind the back bar's body, its crown steps, and the pediment steps, and those behind the beam ends, frames, sills, and cap rails. The floor reaches into the door's reveal and under the back-room door.

**Build lesson.** `tessellate_polygon` left zero-area triangles where three outline points lie on one line, here along the cap rail's 1.17 m line through the field's notch. The unwrap then cut the field into two islands at 1.17 m. The shell builds each flat region from grid cells with shared vertices and dissolves each simply connected region into one n-gon, so a region is one face and one island. Later assets with large concave faces should do the same.

**Found while reviewing.** The greybox `ChandelierRing` is a solid disc from 3.40 to 3.44 m with the light at its underside, so it shadows the whole ceiling, which takes ambient light only. With it hidden in a throwaway capture, the middle bay lit as A's light plan says: the coffers' rib sides took the other light step, the medallion read, and beams 1 and 2 held the light in the middle bay. `saloon_lamps` replaces the disc with an open hoop (B), which fixes it.

**Still open:**

- The in-context review in Godot and a headset: D, items 10 to 18, and the shell's asset check with the balcony's posts and the lamps in place.
- Whether the batwing and shutter louvres shimmer in a headset (D17). In the flat capture they hold as stripes from Lane E, 13.7 m away.
- The ceiling under the final chandelier (see Found while reviewing). Resolved: with `saloon_lamps`' open hoop the middle bay lights (H, `saloon_lamps`).

### `saloon_table` and `saloon_chair` (modules)

Built on 2026-10-19 in `saloon.blend` under two new roots, parked for viewing at table A's place (`saloon_table` at (3.5, −2.5, 0)) and its south chair's (`saloon_chair` at (3.5, −3.45, 0)). Each is modeled around its root in local coordinates and exported from the origin, standing on z 0; the chair faces local +Y with its back toward −Y. Exported by `dev/unwrap_per_glb_blender.py -- --map saloon --glb saloon_table --relayout` and the same for `saloon_chair`, untextured. The greybox tables and chairs (78 objects: `Pedestal_A`/`_B`, `TableTop_A`/`_B`, `Table_A`/`_B-convcolonly`, and the eight `Chair_A_*`/`Chair_B_*` pivots with their `Seat*`, `Back*`, `Cushion*`, `Leg_*` and `Chair_*-convcolonly` children) are deleted from `saloon_interior`, which was re-exported without `--relayout`. The unused `M_BarTop` and `M_Cloth` copies of `saloon_interior` are deleted.

- **Tests:** `--import`, then `load` and `multi`: both pass.
- **Unwrap:** `saloon_table`: 4 meshes, 68 islands, 95.1 px/m at 256 px (pad 2, 77% covered). `saloon_chair`: 1 mesh, 39 islands, 171.0 px/m (pad 2, 56% covered). No TINY share in either; no UV overlap; no zero-area triangle. The felt is one island. `saloon_interior` kept its 45 UVs.
- **Collision:** the proxies are the greybox's, copied into the modules: `Table_Top-convcolonly` (x and y ±0.62, z 0 to 0.80 about the table's centre) and `Chair-convcolonly` (x ±0.23, y −0.26 to 0.22, z 0 to 1.00). Checked in Godot after import: both tables and the seven upright chairs give the greybox's world boxes exactly. The tipped chair's proxy is x 3.27 to 3.73, y −4.50 to −3.50, z 0 to 0.48 (rule 28, F24): 1.77 m outside the corridor and 3.8 m from the east marker.
- **Scene:** `TableA` at Godot (3.5, 0, 2.5); `TableB` at (4.0, 0, −3.0), turned 180° about Y, so its chip faces the east wall. `ChairA0` to `ChairA2` and `ChairB0` to `ChairB3` stand at the greybox chairs' places and yaws, facing their tables. `ChairA3`, table A's south chair, is the tipped one: turned +90° about Godot X (`Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, 3.5, 0.26, 3.5)`), so it lies on its back with the crest rail on the floor at Blender y −4.30 to −4.38, the seat front up, and the legs pointing at the table; its mesh's lowest point is on the floor. `TableLampA` at (3.5, 1.95, 2.5) and `TableLampB` at (4.0, 1.95, −3.0) are new: unshadowed SpotLight3Ds pointing straight down (checked), energy 1.0, range 3.0 m, 30°, `spot_angle_attenuation` 8.0, the lamp colour of F2.
- **Views:** Blender renders of both: Front at 5 m, Three-quarter, Close, the 64 px squint, Silhouette (front at 5 and 10 m, side), each in colour and clay; the chair from 4 m, from the side, and from the reference photo's angle, set beside the photo. Flat Godot captures: Lane P, Lane E, the Flank to the east marker, Close views of both felts, an upright chair, and the tipped chair from 1.5 m, the tipped chair from `PlayerSpawn`, and both felts with the table spots off. All outside the repo. The headset review is still open.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `saloon_table` | 468 / 600 | 4 | 2 |
| `saloon_chair` | 398 / 400 | 1 | 8 |

| Object | Material | Triangles |
|---|---|---|
| `Table_Wood` | `M_WoodDark__saloon_table` | 268 |
| `Table_Felt` | `M_Cloth__saloon_table` | 12 |
| `Table_Ivory` | `M_Ivory__saloon_table` | 148 |
| `Table_Bottle` | `M_BottleAmber__saloon_table` | 40 |
| `Chair_Wood` | `M_WoodDark__saloon_chair` | 398 |

Against B's lines: the table's top, rim, and felt take 120 of 150, the pedestal and feet 160 of 200, and the game 188 of 250. The chair's legs take 144 (B: 140), stiles 96 (90), spindles 72 (70), seat 22 (40), crest rail 28 (25), and stretchers 36 (35).

**Where the build departs from B:**

- **Pedestal.** It is 6-sided, not 8, because rule 9 gives 6 sides under 30 cm. It is 16 cm across its flats, from a 20 cm hub at the foot (0 to 0.17 m) up to a 26 cm flared cap under the top (0.60 to 0.72 m), with one 19 cm collar at 0.33 m. B lists none of the three.
- **Feet.** Four, on the diagonals: blocks 8 cm wide, 0.40 m out from the centre (0.8 m tip to tip), 16.5 cm tall at the hub, sweeping down in a concave curve to a 5 cm toe.
- **Top.** The octagon has its flats on the axes, 1.24 m across them so it fills the proxy's square, and 1.34 m across its corners. It is 6 cm thick (0.72 to 0.78 m), with an 8 cm rim. The chamfer is 3 cm at 45° and runs all round the rim's outer top edge, since every edge of a round table is a front edge. It leaves a 5 cm flat on the rim. The felt is 1 cm down, at 0.77 m.
- **Chip.** A 10 cm jagged bite out of the rim's top edge, 3 to 5 cm deep and down to 0.73 m, on the module's −X side: toward the lane on table A, toward the east wall on table B. It does not go through the rim.
- **The game.** The deck is 6 × 8.5 × 2.5 cm. The hand is five flat 5 × 8 cm cards fanned on the felt by the south seat, as if dropped, each 1.5 mm above the last. The checks stand 10, 6, and 8 cm tall (B: 5 to 10), 4 cm across their flats. The bottle is the bar's 30 cm amber bottle. The glasses are 9 cm tall open cups, 6 cm across their flats, with a 2.5 cm base.
- **Chair rings.** Each "pair of rings" is one collar: a ring of vertices 6 to 8 mm proud, 5 to 6 cm tall. Two rings under the 5 cm floor cannot both be modeled. The 400 budget leaves no room for them either.
- **Chair stiles and spindles.** The stiles are 5.6 cm at the seat, with a 7.2 cm collar at 0.50 m, a 5.2 cm waist at 0.55 m, a 6.4 cm swell at 0.71 m, and a 4.6 cm neck under the rail. They fan from x ±0.163 to ±0.176. The spindles are 4.6 cm at both ends with one 5.8 cm collar at 0.63 m. They fan from x 0 and ±0.08 to 0 and ±0.09. The gaps run 3.3 to 3.5 cm at the seat, 4.0 to 4.5 cm under the rail, and about 2.7 cm at the collars.
- **Saddle.** The seat's top is a 1 cm dish, a fan of six triangles to a centre point, not a 1 cm step. The step costs 8 to 12 more triangles and would take the chair to 406 to 410.
- **Legs.** All splay 4° outward; the front legs 4° forward and the back legs 6° back (B: 4°). With 6°, the back feet reach the proxy's back face, so the tipped chair lies on its crest rail and its back feet together; the feet stand 6 mm off the floor. The legs taper from 5.5 to 5.0 cm. Each has a 6.8 cm collar just under the seat, and each front leg has one 6.4 cm ring at 7.5 cm.
- **Crest rail and rake.** The rail's middle sits 3 cm behind its ends, with its back face on the proxy's back face (y −0.26). Its mitred ends reach x ±0.234, 4 mm past the proxy. That back face limits the back's rake to about 6°, less than the reference chair's.
- **Hidden faces.** Rule 27 deletes the pedestal's, the feet's, and the legs' floor faces, and the ends buried in the seat, the rail, the legs, the hub, and the top. The felt and the underside are triangle fans, because the chip's points lie on straight sides.

**Review.** Against the reference image, the chair reads as the same type: a wide curved crest rail, two turned outer stiles, three ringed spindles, a thick plank seat with a rounded front, splayed ringed legs, and an H-stretcher. It is chunkier, because of the 5 cm floor. Its spindles, as thick as the gaps between them, read nearly as slats at 1.5 m in Blender's clay light. In game, in dark stain, the turnings read only in silhouette, as F32 intends. Both felts take their spots: with the table spots off, the felt is a flat green, and on, it lifts. The lift is mild, because the pool (0.68 m in radius at the felt, against the felt's 0.54 m half-width) covers the whole felt and its ring edge falls under the rim.

**Build lesson.** Count UV islands in the `.blend`, not in the exported GLB. Flat shading splits every vertex per face on export, so in the GLB only coplanar faces share edges. The chair's 39 islands count as 197 there.

**Still open:**

- The in-context review in Godot and a headset: D, items 15 and 17 (the pools, and whether the chair spindles shimmer), and the asset checks for the table and chair.
- The table spots' energy if the felt needs a stronger pool (energies are starting values for the flat run, A's light plan), and Quest timing with all four spots (`RELEASE_TODOS.md`).

### `saloon_balcony` and `saloon_dressing`

Built on 2026-10-19 in `saloon.blend` under two new roots at the origin, `saloon_balcony` and `saloon_dressing`, their children at room coordinates. Exported by `dev/unwrap_per_glb_blender.py -- --map saloon --glb saloon_balcony --relayout` and the same for `saloon_dressing`, untextured. The 31 greybox objects they replace are deleted from `saloon_interior`: `Balcony`, `BalconyRail`, `BalPost_0` to `_7`, `Stair`, `StairRail`, `StairPost_0` to `_2`, `PianoBody`, `PianoKeys`, `PianoMusic`, `PianoBench`, the two `BenchLeg_*`, `StoveBody`, `StoveBelly`, `StovePipe`, `StoveDoor`, `Barrel_0` to `_2`, and `Hoop_0` to `_2`. The unused `M_Wood`, `M_WoodDark`, `M_Trim`, and `M_Ivory` copies of `saloon_interior` are deleted. `saloon_interior` was re-exported without `--relayout`. It now holds only the greybox chandelier (`Chain`, `ChandelierRing`, `Candle_0` to `_5`, `Flame_0` to `_5`: 14 meshes, 256 triangles, no proxies), which `saloon_lamps` will replace.

- **Tests:** `--import`, then `load` and `multi`: both pass.
- **Unwrap:** `saloon_balcony`: 3 meshes, 331 islands, 16.8 px/m at 256 px (pad 1, 62% covered). `saloon_dressing`: 7 meshes, 389 islands, 40.9 px/m (pad 1, 66% covered). Neither has a TINY share, a UV overlap, or a zero-area triangle. The fascia is one island; each barrel's side is split at its hoops, because the hoops are `M_Iron` faces in the same profile. `saloon_interior` kept its 14 UVs: 60 islands in 0.1% of the square, 13 meshes under 16 px².
- **Collision (rule 28):**
  - Moved unchanged, with the same world boxes in Godot after import:
    - `Balcony_Deck-convcolonly` (was `Balcony`): x −6.625 to 6.625, y 7.25 to 8.70, z 2.86 to 3.00.
    - `Balcony_Rail-convcolonly` (was `BalconyRail`): x −4.55 to 6.55, y 7.24 to 7.34, z 3.00 to 3.90.
    - `Balcony_Stair-convcolonly` (was `Stair`, the walkable ramp): x −6.55 to −4.70, y 3.65 to 7.25, z 0 to 3.00.
    - `Dressing_Stove-convcolonly`: x 5.125 to 5.975, y 5.925 to 6.775, z 0 to 1.10.
  - Moved and changed:
    - `Dressing_Piano-convcolonly` moved 0.8 m east (F21): x 5.525 to 6.675, y −7.95 to −6.45, z 0 to 1.24.
    - `Dressing_Barrel0` to `2-convcolonly` keep their footprints and rise to 0.90 m (F14), from 0.42, 0.36, and 0.32: x −4.65 to −4.05 at y −5.45 to −4.85; x −5.15 to −4.55 at y −5.85 to −5.25; x −4.20 to −3.60 at y −5.90 to −5.30.
  - New:
    - `Balcony_PostW-convcolonly` and `Balcony_PostE-convcolonly` (F12): x −3.20 to −3.00 and 3.00 to 3.20, y 7.15 to 7.35, z 0 to 2.86.
    - `Balcony_StairGate-convcolonly` (F11): x −6.55 to −4.70, y 3.60 to 3.70, z 0 to 1.00.
    - `Dressing_BrokenChair-convcolonly` (F24): x −3.10 to −2.50, y −3.90 to −3.30, z 0 to 0.25, 1.0 m outside the corridor.
  - Nothing else in the debris has collision.
- **The gate stops a flat player.** In a headless Godot run, a `CharacterBody3D` with the flat rig's capsule (0.28 m radius, 1.6 m tall, `floor_max_angle` 0.9) walked at 2.5 m/s at the stair from these sides:
  - Up the bar aisle.
  - Round the foot newel.
  - Along the stair's open east side at y 3.72, 3.80, 3.90, 4.10, and 4.60.
  - Into the newel's corner.
  - Through the 15 cm gap between the gate and the west wall.

  It never left the floor. Near the gate the ramp's open side is low enough to step onto, but the gate box's east corner holds the capsule off it. Further north the side is too tall to climb.
- **Scene:** `Balcony` and `Dressing` instance the two GLBs at identity, after `ChairB3`. Nothing else in `saloon.tscn` changed.
- **Views:**
  - Blender renders: the balcony's Front with and without the room, Three-quarter, the stair from close and from the side, the gate, and a post. Silhouettes of the gallery at 5 and 10 m and of the stair from the side. The 64 px squint.
  - Blender renders of the dressing: the piano's Front, in context, and Close; the stove's Front, in context, and Close; the barrels' Front and Close; the debris from `PlayerSpawn`'s eye, three-quarter, and round the smashed chair. Silhouettes of each, and the squints.
  - Flat Godot captures, all outside the repo: Lane P; Lane E; the Flank to the west two-NPC marker and to the east marker; Down; Close views of the piano, the stove, the barrels, and the smashed chair; the pipe meeting the ceiling from two sides; the east post; and the gate from the bar aisle, from the east, and from the stair's foot.
  - The headset review is still open.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `saloon_balcony` | 2,390 / 2,400 | 3 | 1 |
| `saloon_dressing` | 1,628 / 2,000 | 7 | 1 |

| Object | Material | Triangles |
|---|---|---|
| `Balcony_Wood` | `M_WoodDark__saloon_balcony` | 502 |
| `Balcony_Trim` | `M_Trim__saloon_balcony` | 1,742 |
| `Balcony_Plank` | `M_Plank__saloon_balcony` | 146 |
| `Dressing_Wood` | `M_WoodDark__saloon_dressing` | 806 |
| `Dressing_Ivory` | `M_Ivory__saloon_dressing` | 140 |
| `Dressing_Iron` | `M_Iron__saloon_dressing` | 542 |
| `Dressing_Brass` | `M_Brass__saloon_dressing` | 64 |
| `Dressing_Mirror` | `M_Mirror__saloon_dressing` | 18 |
| `Dressing_Bottle` | `M_Bottle__saloon_dressing` | 37 |
| `Dressing_BottleAmber` | `M_BottleAmber__saloon_dressing` | 21 |

Against B's lines:

- **Balcony.** The balusters take 1,704 (B: 1,400): 35 on the gallery, 11 on the stair, and the gate's two. The stair takes 312 (400); rails, fascia, and deck 188 (300); posts and braces 48 (200); newels and the rest of the gate 138 (100).
- **Dressing.** The piano and bench take 330 (B: 400), the stove 228 (300), and the barrels 584 (450). The debris takes 486 (850): the smashed chair 220, splinters 54, shards 36, broken bottles 40, and checks and cards 136.

**Where the `saloon_balcony` build departs from B:**

- **The bottom rail is the fascia's top.** The fascia is 5 cm thick, its face at y 7.20, in front of the deck's edge at 7.25. Between 3.00 and 3.10 m it deepens to y 7.34, so its flat top carries the balusters. A separate rail would share that plane.
- **The bead.** An 8 cm square-edged strip from 2.80 to 2.88 m, 3 cm proud.
- **The deck runs wall to wall** (x ±6.70), 7.5 cm past `Balcony_Deck` at each end. That closes the strip the shell kept behind the deck's edge.
- **Gallery.**
  - The balusters stand on y 7.29.
  - The top rail is 10 cm wide, from 3.87 to 3.95 m. It stands 5 cm above `Balcony_Rail` (3.90), listed under rule 5.
  - The newels are 15 cm square, from the deck at 3.00 m to 4.03 m, under a 19 cm block cap to 4.08 m.
  - The west-end newel, at x −4.80, is also the stair's top newel. So the balustrade starts 25 cm west of `Balcony_Rail` (x −4.55).
- **Balusters.**
  - 6-sided: 5 cm at the foot over a straight base block, 8 cm at the swell 40% of the way up, and 4.8 cm at the neck.
  - Each bay between newels is divided evenly, so the centres are 0.283 m (west bay), 0.295 m (the field), and 0.288 m (east bay) instead of 0.3 m.
  - The gate's two have the swell and no base block.
- **The sag.** 5 cm at x 0, piecewise linear through 3.75 cm at x ±1.55 to nothing at the posts. The deck's front edge, the fascia, the bead, the top rail, and the gallery balusters drop together; the deck's back edge stays level at the wall. The lowest point inside x ±2.6 is the bead's bottom at 2.75 m, at x 0.
- **Posts.**
  - 20 cm square, on the proxies' footprints: 5 cm proud of the fascia, from the floor to the deck's underside.
  - Two knee braces each, inside and outside, 10 cm thick. Each runs from 2.42 to 2.56 m on the post to the deck's underside, 0.30 to 0.44 m out. Their faces are 1 cm behind the fascia's.
  - The inner braces' lower edges reach 2.80 m at x ±2.62, so nothing below 2.80 m enters the field. Their tops are hidden behind the bead.
- **Stair.**
  - Twelve 2 cm black risers (B gives them no colour) and twelve 4 cm raw-wood treads with a 2.5 cm nosing.
  - The 12th tread is level with the deck and ends at its front edge, so the run is the proxy's 3.6 m.
  - The treads run from x −6.60 to −4.70: 5 cm past the proxy toward the west wall, 2 cm clear of the cap rail.
  - The open stringer is 8 cm (x −4.78 to −4.70). It is flush with the tread and riser ends, so the sawtooth shows as grey tread ends and black riser ends over a black band 0.25 m (vertically) under the inner corners.
  - The third tread's east end is lifted 3 cm, which opens a gap over the stringer.
- **Stair balustrade.**
  - The rail is 8 cm square, its centre 0.62 m above the nosing line: lower than a building-code rail, so it meets the foot newel under its cap and the top newel at 3.86 m.
  - It passes 3 cm under beam 3 (3.49 m against 3.52 m at y 6.71).
  - The foot newel is 20 cm square at x −4.90 to −4.70 and y 3.55 to 3.75, 1.07 m tall under a 24 cm cap to 1.15 m.
- **Gate.**
  - The rail is 8 cm square, from 0.92 to 1.00 m at y 3.53 to 3.61, running from the west wall to the foot newel.
  - A blank raw-wood board, 0.48 × 0.35 m, hangs from it on two 5 cm black straps, between two cream balusters at x −6.27 and −5.65.
  - It stands 3 to 7 cm in front of its proxy.
  - **Why the balusters moved.** The bar's north end stands 13 cm in front of the gate, so from the room the counter and the back bar hide all but the gate's east end at the newel. The gate reads from the bar aisle, the one way to the stair. Its balusters were first at x −6.45 and −5.15, behind the back bar and the counter. They were moved to frame the aisle after the flat capture.
- **Hidden faces.** Rule 27 deletes the deck's back and end edges, the posts' feet and tops, the treads' back ends, the stringer's top faces under the treads, and the newels' feet.

**Where the `saloon_dressing` build departs from B:**

- **Piano.**
  - The case is 0.62 × 1.40 m (x 5.98 to 6.60, y −7.90 to −6.50), 1.17 m to its top, with the lid propped 3 cm open at the front to 1.22 m (B: 1.19).
  - "Against the wall" means 2 cm off the east wall's cap rail (x 6.62), which stands 8 cm proud at 1.10 to 1.17 m. So the case moved 0.84 m east while its proxy moved 0.80 m.
  - The key bed reaches x 5.70. The legs are 6-sided (rule 9), not 8.
  - The music desk is a ledge with a leaning board.
  - The candle arms are 5 cm rods 12 cm out at 1.00 m, each ending in an 8 cm cup, with no candle.
  - The black keys, 1.3 cm wide, are under the size floor and not modeled.
- **Piano clearances.**
  - The case is 1.35 m south of the frame of the east window at y −5.0.
  - The bench moved 0.8 m east with the piano. It now clears the shell's sprung board by the piano (x 4.30 to 4.55), which the greybox bench overlapped; the board is 0.67 m west of it.
  - Nothing else of the shell's wear is near.
- **Bench.** 0.70 × 0.36 m with its top at 0.32 m (B), a 5 cm top on four 6-sided turned legs. It overlaps the piano's proxy by 5.5 cm, as the greybox did, and has no collision of its own.
- **Stove.**
  - The belly is 8-sided, 0.80 m across its flats, widest from 0.48 to 0.66 m, with a flat top at 0.94 m. It stands on four 6 cm square legs.
  - The door is a 24 × 16 cm plate on the west flat, 2 cm proud, with a latch.
  - The pipe is 6-sided and 14 cm across. It runs straight to a joint band at 2.40 m, then leans 2° west to 4.12 m, so its top is 6 cm west of its base.
  - The ceiling collar is 20 cm across its flats, from 4.12 to 4.20 m, at y 6.24 to 6.47: 2.5 cm clear of beam 3 (6.49).
  - The damper is a key at 1.60 m with its handle toward the room.
  - The stove board is a 1.0 m square, 1.5 cm thick.
- **Barrels.**
  - 8-sided: 0.50 m across the flats at the ends and 0.55 m at the waist (the 10% bulge).
  - The two hoops (0.10 to 0.18 m and 0.72 to 0.80 m) are steps in the same profile, 2 cm proud, inside the 0.60 m proxies.
  - Barrel 1, at the back, has its lid off: a 2.5 cm rim, an inner wall, and the contents 6 cm down. Its lid leans on the barrel's west side.
  - The spigot is on barrel 2 at 0.32 m, facing the room. It stands 7 cm out of its proxy.
- **The smashed chair** is built from the chair module's own parts:
  - The main piece is the seat with its two right-hand legs, snapped 22 cm under the seat with a spiked break. It is tipped 38° so it rests on the seat's edge and the two stubs, at (−2.8, −3.6) and turned 25°. Its top is at 0.29 m, 4 cm above its proxy (rule 5).
  - The crest rail lies on its back at (−2.05, −3.10).
  - The two outer spindles lie at (−1.75, −3.95) and (−3.45, −3.00), their ends capped.
  - The left front leg, snapped at 0.33 m, lies in the lane at (−1.15, −3.45).
- **Splinters.** 18 black wedges, 5 cm across the butt, 2 cm tall, and 10 to 28 cm long, at three triangles each: 12 round the chair and 6 in the lane.
- **Shards.** 36 single triangles, 5 to 12 cm long, 5 mm above the floor, none overlapping: 18 of mirror (most under the bar's south end, 3 in the lane), 9 green, and 9 amber.
- **Broken bottles.** A green neck lies at (−3.90, −2.90). An amber base, 11.5 cm tall to its jagged top, stands in the lane at (0.90, −3.30).
- **Checks and cards.** 8 checks, 6-sided, 1 cm thick, and 5 cm across their flats (the size floor; the table's checks are 4 cm), between table A and the lane at x 1.7 to 2.75. Four flat 5 × 8 cm cards, one in the lane at x 1.32.
- **Extent.** The debris spans x −4.56 to 2.78 and y −4.25 to −2.05. Its highest point inside \|x\| < 1.5, \|y\| < 6 is the amber base at 0.115 m. The placement uses a fixed random seed.

**Review.** In Lane P the north field is still one flat magenta plane from the baseboard to the bead, framed by the two posts and their braces, with the fascia's cream bead above the enemy's hat. From the spawn, the gallery's balusters read only faintly, because they stand in beam 3's shadow and get ambient light only, as A's light plan says. The debris reads as glass, splinters, and checks at the player's feet in the Down view. Nothing of it lies north of y −2.0, so no shard sits near the enemy. The stove pipe meets the ceiling in its collar, in front of beam 3. The barrels read as three full barrels with iron bands. The stair behind the west two-NPC marker looks as F10 accepted it.

**Still open:**

- The in-context review in a headset: D, items 16 and 17 (the debris, and whether the gallery balusters shimmer), and the asset checks for the balcony and the dressing.
- Whether the gallery's comb needs more light. In beam 3's shadow it reads as a dim comb from `PlayerSpawn`, not the bright cream one A describes. That belongs to the lamps' review.
- The three barrels are now 0.90 m crouch cover 3.6 m left of `PlayerSpawn`, in every mode (`RELEASE_TODOS.md`).

### The glow code (G7)

Landed on 2026-10-19, before the lamps' review, as G7 and F27 to F29, F33, and F34 decided.

- **Which.** `SELF_LIT` in `assets/shaders/world_surface_import.gd` lists `M_Flame` and `M_LampGlass`, beside the grain and sway tables. The name before `__` decides; the glTF materials carry no emission, and a material that does is still skipped with a warning.
- **How it draws.** `world_surface.gdshader` has a `self_lit` uniform. Under it the fragment writes `ALBEDO` 0, `SPECULAR` 0, and `EMISSION` = the base colour: the flat colour, or the painted texel where `use_albedo_tex` is set (F34). Grain is off. Every light, band, and ambient term multiplies the albedo, so light adds nothing, and the scenes' linear tonemap passes the colour through. Every scenario surface stays on `world_surface.gdshader`.
- **Shadows (F33).** The importer turns `cast_shadow` off on a `MeshInstance3D` whose surfaces are all self-lit. Rule 26 makes each glowing material its own mesh, so `Lamps_Glass` and `Lamps_Flame` cast none.
- **Verified in a flat run** (Compatibility, Godot 4.7). Two quads wearing the imported materials, outside every light's range, read exactly #FFD966 (255, 217, 102) for `M_Flame` and #FFF0C8 (255, 240, 200) for `M_LampGlass`. In the Up view the chandelier's south shade read (255, 240, 200) on screen. With `self_lit` switched off at run time, the same pixel read (94, 82, 63): lit glass, darker than its pool of light.
- **Test.** `--autotest=load` now asserts that `SELF_LIT` is exactly `M_Flame` and `M_LampGlass`; that a surface carries `self_lit` exactly when its base name is one of them; that at least one does (the Saloon has two); and that a mesh has `cast_shadow` off exactly when all its surfaces are self-lit, so every other scenario mesh still casts. Every earlier assertion holds.
- **Reimport.** All 29 scenario GLBs were reimported after the script changed (their `.godot/imported` files deleted, then `--import`).

### `saloon_lamps`

Built on 2026-10-19 in `saloon.blend` under a new root `saloon_lamps` at the origin, its children at room coordinates, and exported by `dev/unwrap_per_glb_blender.py -- --map saloon --glb saloon_lamps --relayout`, untextured. The greybox chandelier (`Chain`, `ChandelierRing`, `Candle_0` to `_5`, `Flame_0` to `_5`) is deleted from `saloon_interior`.

- **Tests:** `--import`, then `load`, `multi`, and `practice`: all pass.
- **Unwrap:** 4 meshes, 325 islands, 71.1 px/m at 256 px (pad 1, 70% covered). No TINY share, no UV overlap, no zero-area triangle. The shades, fonts, flames, and chain links are flat colour.
- **Collision:** none, as B says.
- **Materials:** `M_Brass__saloon_lamps` (0.584, 0.361, 0.042), `M_Iron__saloon_lamps` (0.018, 0.020, 0.027), `M_LampGlass__saloon_lamps` (1.000, 0.871, 0.578), and `M_Flame__saloon_lamps` (1.000, 0.694, 0.133). All have roughness 0.9, metallic 0, and no emission.
- **Scene:** `Lamps` instances `saloon_lamps.glb` at identity, after `Dressing`. `saloon_lamps.glb.import` has `saloon_bar.glb.import`'s `[params]` and a uid from Godot. The `Chandelier` node keeps its name, type, and place.
- **Views:**
  - Blender renders: Front at 5 m (alone and in the room), Three-quarter (alone and in the room), Up from Lane P's eye, a view from below, a Close view of the chandelier, Close views of a bar lamp and a table lamp, and an overview. Silhouettes: the front at 5 and 10 m, the side, a table lamp, and a bar lamp. The 64 px squints.
  - Flat Godot captures: Lane P, Lane E, Up, Up with the glow off, Up close, the ceiling from the south end, Close views of a bar lamp and of table A's and table B's lamps, and the north field. All outside the repo.
  - The headset review is still open.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `saloon_lamps` | 1,232 / 1,400 | 4 | 1 |

| Object | Material | Triangles |
|---|---|---|
| `Lamps_Brass` | `M_Brass__saloon_lamps` | 304 |
| `Lamps_Iron` | `M_Iron__saloon_lamps` | 706 |
| `Lamps_Glass` | `M_LampGlass__saloon_lamps` | 192 |
| `Lamps_Flame` | `M_Flame__saloon_lamps` | 30 |

Against B's lines:

- **Chandelier:** 656 (B: 800). The hoop takes 64, the arms 72, the fonts 168, the shades and chimneys with the stub 192, the flames 30, the rods 36, the finial and stem 40, the smoke bell 38, and its chain 16.
- **Lamps:** each lamp's shade and neck take 54, so 216 for the four (B: 480).
- **Chains and rods:** 376 (B: 120). The two table chains take 152 each in 19 links, the bar rods and the four mounting plates 56, and the chandelier's chain 16. The links cost more than B's line, but the asset stays inside its total.

**Where the build departs from B:**

- **Six-sided fonts.** The fonts are 12 cm across, so rule 9 gives them 6 sides, not B's 8, as the bar's columns took. Each font is a 6-sided double cone from a 5 cm foot at 3.52 m, 12 cm across at 3.575 m, to a 7 cm collar at 3.63 m.
- **The hoop.**
  - An 8-sided ring (rule 9), 1.2 m across its centre line, with a 5 × 5 cm square section.
  - Its centre line sits at 3.45 m (B: 3.42), so that with the 2° tilt its lowest edge is at 3.403 m, just above the light. That is the chandelier's lowest point.
- **Arms and fonts outside the hoop.** Each 5 cm brass arm rises about 50° from the hoop to a font 0.66 m from the centre, so the shades clear the smoke bell. Across the shade rims the chandelier is 1.57 m wide.
- **Glass.**
  - Each shade is a 6-sided cup from the font's collar at 3.63 m, 22 cm across at its rim at 3.75 m (B).
  - The chimney is a 7 cm 6-sided tube from 3.63 to 3.80 m, rising 5 cm out of the shade.
  - The glass is opaque, so the flame shows only above the chimney. Each flame is a 6-sided point, 6 cm across at its base at 3.79 m and tipped at 3.90 m.
  - The shades and chimneys share the `M_LampGlass` mesh.
- **Suspension.**
  - Three 5 cm iron rods, which B does not list, rise from the hoop between the fonts to the stem at 3.80 m. They hold the hoop up.
  - The stem is 5 cm, from a finial at 3.46 m to the smoke bell.
  - The bell is 8-sided, 0.45 m across at its rim at 3.865 m and closed at 3.955 m.
  - The medallion's underside is at 4.05 m, so the chain between the bell and the medallion is two links, 10 cm.
- **Wear.**
  - The shot shade is the south-west one, toward the bar's south end. A jagged glass stub, 2.5 to 5.5 cm tall, is left on its font, with no chimney or flame.
  - The tilt is 2° about the north-south axis through the hoop's centre, west side low, so the light stays at the hoop's centre and the chain hangs plumb from the tilted bell.
- **Bar lamps.**
  - An 8-sided black cone 0.40 m across its flats, with a 5 cm vertical lip at the mouth from 2.35 to 2.40 m, rising to a 12 cm top at 2.57 m and a 7 cm neck to 2.62 m.
  - A 5 cm square iron rod runs up to a 12 cm plate under the beam, from 3.50 to 3.52 m.
  - Each is centred on its spot at (−5.2, ±2.8), under the middle of beams 1 and 2.
- **Table lamps.**
  - The same shade 0.45 m across, lip from 1.95 to 2.00 m, cone to 2.13 m, neck to 2.18 m.
  - A chain of 19 links runs to a 12 cm plate on the ceiling at 4.18 to 4.20 m.
  - Table A's chain is 16.5 cm clear of beam 1's north face, and table B's 6.5 cm clear of beam 2's north face. Table A's plate is flat ceiling between the coffer ribs (x 2.75 and 4.0).
- **Chain links.** Each link is an open box 5 cm wide, 2.5 cm thick, and 13 cm tall, alternating 90° at about 11 cm. The 2.5 cm thickness is under the 5 cm floor: a link 5 cm thick both ways reads as a bar, not a chain. The open ends are hidden by the next link.
- **Hidden faces.** Rule 27 removes the arms' and rods' buried ends, the fonts' tops under the glass, and the links' ends.

**The retired greybox.** `saloon_interior` was empty after the chandelier went:

- Its root and its four material copies (`M_Brass`, `M_Candle`, `M_Flame`, and `M_Iron` `__saloon_interior`) are deleted from `saloon.blend`.
- `saloon_interior.glb` and `.glb.import` are deleted from the repo; git history keeps them.
- `saloon.tscn` loses the `Interior` node and its ext_resource and gains `Lamps`, so `load_steps` stays 10.
- A search for `saloon_interior` across `.gd`, `.tscn`, `.tres`, and `.py` finds only `dev/build_saloon_blender.py`, which wrote it (left as it is, with a docstring line saying it is retired and must not be re-run), and a docstring example in `dev/trim_layout.py`.

**Review.**

- **The glow.** From Lane P and in the Up views, the five shades and chimneys draw flat cream and the five flame tips flat yellow, the same from every side. With the glow switched off, the cups read dark brown against the lit ceiling.
- **The gap.** The south-west font shows its stub and no cup, a gap in the ring of five.
- **The middle bay** now lights as A's light plan intends. The open hoop no longer shadows it, and beams 1 and 2 hold the light, so the end bays stay ambient grey. The ceiling straight over the chandelier washes to near white.
- **The chandelier's shadows** all land on the ceiling: six long blobs from the fonts and three radial stripes from the rods, all inside the middle bay. The lamps' glass and flames cast none.
- **The hanging lamps.** Each hangs over its pool, on the counter and on the felts.
- **The north field** behind `EnemySpawn` is unchanged: one flat magenta plane between the posts.

**Found while reviewing:**

- The brass hoop and the fonts' undersides sit 3 to 25 cm from the light, so their lit faces clip to a hot yellow in Godot. They are lit, not self-lit, but from the lane the hoop reads nearly as bright as the glass. Levers: a darker brass on `M_Brass__saloon_lamps` only, or the hoop and arms in iron.
- The hoop sits 2.5 to 7.5 cm above the light, so its shadow leaves the light nearly level. It runs out across the ceiling's outer edge and the top of the side walls in the middle bay. In the flat captures that shows at most as a thin darker strip under the ceiling.
- The bar lamps' shades are iron and cast the chandelier's shadow: a dark cone falls on the back bar's mirror under each lamp (seen in the south lamp's Close view).
- The gallery's comb is still dim in beam 3's shadow from `PlayerSpawn`, as the balcony's review found. The lamps do not change it; the decision stays open.

**Still open:**

- The headset review: D items 14 and 15 and the lamps' asset check. Whether the brass reads as glowing.
- Quest timing with the four spots, and with the glow (`RELEASE_TODOS.md`).

### Whole scene

The Saloon's final untextured meshes are complete. `saloon_interior` is retired.

| GLB | Triangles each | Copies | In scene | Mesh objects | Draw calls |
|---|---|---|---|---|---|
| `saloon_bar` | 2,532 | 1 | 2,532 | 6 | 6 |
| `saloon_shell` | 2,111 | 1 | 2,111 | 6 | 6 |
| `saloon_table` | 468 | 2 | 936 | 4 | 8 |
| `saloon_chair` | 398 | 8 | 3,184 | 1 | 8 |
| `saloon_balcony` | 2,390 | 1 | 2,390 | 3 | 3 |
| `saloon_dressing` | 1,628 | 1 | 1,628 | 7 | 7 |
| `saloon_lamps` | 1,232 | 1 | 1,232 | 4 | 4 |
| **Scene** | | | **14,013** (budget about 18,000) | **31** | **42** (sheet: 42) |

- Collision proxies (`-convcolonly`) are bodies, not meshes, and are not counted.
- 14,013 triangles is 78% of the budget and 0.9% of Meta's 1.5 million per frame for Quest 3.
- 42 draw calls, against Meta's guideline of under 200.
- Every mesh but `Lamps_Glass` and `Lamps_Flame` is drawn again into the chandelier's shadow cube: 40 casters.
- Lights: five. The `Chandelier` OmniLight3D is the only shadowed one, plus `BarLampS`, `BarLampN`, `TableLampA`, and `TableLampB`, unshadowed `SpotLight3D`s. The glow lights nothing.
- Tests: `--import`, then `--autotest=load`, `multi`, and `practice` all print `AUTOTEST PASS`.

## References

**Repo**

- `.claude/skills/gunslinger-taste/references/board.md`: items #00, #01, #04, #06, #10, #12, #16, #18, #20, #21, and pattern 2, colour loud and few.
- `.claude/skills/gunslinger-taste/references/steel-ball-run.md`: no fixed palette; colour chosen for the image.
- `docs/design/characters/`: `drunk.md` (Plata, rung 2; the tin milagros), `ghost.md` (rung 6; off company ground; the eyes indoors), `sheriff.md` (the reds), `player.md` (the black coat).
- `docs/design/scenarios/main_street.md` (global rules, palette, backdrop check, build lessons, `bld_saloon`), `docs/SHADERS.md`, `docs/TEXTURING.md`.
- `dev/build_saloon_blender.py`, `dev/unwrap_per_glb_blender.py`, `dev/scenery_uv.py`, `dev/blender_kit.py`, `dev/autotest.gd` (`_saloon_time_ok`, the `multi` marker probe), `scenarios/saloon/saloon.tscn`, `scenarios/saloon/saloon.tres`, `scenarios/scenario_base.gd`, `gauntlet/ladder_default.tres`, `ai/duelist_ai.gd`, `player/flat_rig.tscn`, `player/vr_rig.gd`, `assets/shaders/world_surface_import.gd`, `project.godot`.
- [`victorian-turned-wooden-chair.jpg`](victorian-turned-wooden-chair.jpg): your reference image of a spindle-back kitchen chair, 2026-10-19.

**Saloons**

- [Whiskey Rows](https://www.truewestmagazine.com/article/whiskey-rows/), *True West*: Brunswick-Balke-Collender added bar fixtures in 1878 and sold back bars until 1912; its Dubuque plant built them 16 to 30 feet long. Read through a search excerpt; the page refused a direct fetch.
- [Saloon](https://albuquerque.emuseum.com/objects/141788/saloon), Albuquerque Museum: about 1885, a bar counter with mirrors behind shelves of liquor. Read through a search excerpt.
- [Saloons of the American West](https://www.legendsofamerica.com/we-saloons/), Legends of America: "the long paneled bar, usually made of oak or mahogany"; "a gleaming brass foot rail" with "a row of spittoons spaced along the floor next to it".
- [Western saloon](https://en.wikipedia.org/wiki/Western_saloon), Wikipedia: batwing doors on double-action hinges "from chest to knee level"; early saloons warmed by "a single wood-burning stove"; faro and poker; pianos.
- [How did saloons in the Old West lock their doors at night?](https://www.mentalfloss.com/article/78758/how-did-saloons-old-west-lock-their-doors-night), Mental Floss: solid doors on the outermost part of the entrance, laid flat against the building during business hours, shut and padlocked when needed.
- [Bird Cage Theatre](https://en.wikipedia.org/wiki/Bird_Cage_Theatre), Wikipedia: twelve balcony boxes, the original 1881 rosewood piano, the original faro table, walls "riddled with gunshot holes".
- [Faro: Favorite Gambling Game of the Frontier](https://historynet.com/faro-favorite-gambling-game-of-the-frontier/), Historynet: the green cloth layout, the dealing box, the casekeeper, "checks", the tiger sign, and faro dominating Western gambling.
- [Kerosene Chandelier, 1885-1900](https://www.thehenryford.org/collections/explore/artifact/165594), The Henry Ford: Plume & Atwood, brass and glass, 38 in high and 30 in across.
- [Tin ceiling](https://en.wikipedia.org/wiki/Tin_ceiling), Wikipedia: widespread from the 1880s to the 1930s, traditionally painted white to look like plaster.

**PSX era, engine, and hardware**

- [Making Crash Bandicoot, part 3](https://all-things-andy-gavin.com/2011/02/04/making-crash-bandicoot-part-3/), Andy Gavin: "more polys on the characters, less texture"; a budget set by what you could see at once, 800 polygons for Crash 1; Jason Rubin on making the pupils a quad so they "almost always showed up".
- [Spyro the Dragon](https://www.hardcoregaming101.net/spyro-the-dragon/), Hardcore Gaming 101: every level has a flat-shaded version with no detail, faded in by distance.
- [Lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html), Godot docs: Compatibility renders up to 8 omni and 8 spot lights per mesh; shadows take extra passes and render in sRGB; an omni shadow is a cube of six faces or a dual paraboloid of two, a spot's is one.
- [OmniLight3D](https://docs.godotengine.org/it/4.x/classes/class_omnilight3d.html), Godot docs: in Mobile and Compatibility, an omni light affects only meshes whose bounds intersect its own. Read through a search excerpt.
- [Device optimization comparison](https://developers.meta.com/horizon/resources/device-optimization-comparison/), Meta: Quest 3 at under 200 draw calls and under 1.5 million triangles per frame, 72 Hz minimum and 90 Hz recommended.
- [Meta Quest compare](https://www.meta.com/ca/quest/compare/), Meta: Quest 3 at 25 pixels per degree, as cited in `main_street.md`.
