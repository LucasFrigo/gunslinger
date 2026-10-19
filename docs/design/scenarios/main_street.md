# Main Street: design sheet

| | |
|---|---|
| Status | `done`. Approved and built 2026-10-19 (see H); tested in game by the user. Still open: texture size for painting (F19) and Quest draw-call timing (F18) |
| Kind | Scenario design sheet: greybox to final, untextured, UV-unwrapped meshes |
| In code | Greybox kit only. `dev/build_main_street_blender.py` writes the 19 GLBs and `main_street.blend` in `assets/models/scenarios/main_street/`; `scenarios/main_street/main_street.tscn` assembles them. All 18 Main Street GLBs carry their final untextured meshes, modeled in `main_street.blend`; `env_street_ground` is deleted. The scene edits for F7, F8, and F9 are in `main_street.tscn`. Section H records the build |
| Prompt | [`prompts/main_street.md`](prompts/main_street.md) |
| Inherits | Nothing. This sheet is the style reference: the global rules in A apply to the Saloon, Canyon, Train Rooftop, and Practice Hub sheets |

The deliverable is clean, final, untextured meshes with sensible UVs and flat Base Color materials. You texture by hand later, so nothing here plans texture art.

Blender positions are Z-up with the street face toward +Y. Godot positions are (x, y, z) with y up; west is −x (the `WestWalk` side) and north is −z (the depot end).

## Scene facts the design depends on

Read from `main_street.tscn`, `main_street.tres`, the GLBs themselves, and the code that touches them. Positions here are the greybox's. The decisions in F move the porch posts, the rail line, and the water tower.

- **Lane.** `PlayerSpawn` (0, 0.12, 8) faces north at `EnemySpawn` (0, 0.12, −8), so `duel_distance` is 16. Every marker stands on the terrain top at +0.12. The spawn-floor check in `dev/autotest.gd` and `--autotest=ragdoll` fail if that floor moves (BUG-027).
- **Rows.** Street faces sit at x = ±12, 24 m apart.
  - West row, facing +x: saloon z −14 to −5, hotel −3 to 8, general store 10 to 19. The church is set back at x −33 to −19, z 20 to 28.
  - East row, facing −x: bank z −16 to −8, newspaper −6 to −1, jail 2 to 8, then an empty lot to z 20.
  - Boardwalks run x ±9.5 to ±12, z −16 to 20, nine 4 m modules a side. Awning posts stand at x ±9.6 every 6 m.
- **Ends.** The depot hall spans z −42 to −34, centred on the lane, with its platform out to z −31 and the water tower at (−10, −38). The rail line runs along x at z −34, from x −60 to 60. The stock pens fill x −12 to 12, z 28 to 40, with five cows. Depot and pens close the two ends of the street; neither stands on a side.
- **Cover near the lane.** Troughs (long axis across the street, street end at |x| 8.2), barrels at (±9.3, z 8 and −10), hitching rails at (±9.2, z ±10), and the awning posts. Nothing collides inside |x| < 8.2.
- **Sun.** Each map's sun yaw is fixed; `scenarios/time_of_day.gd` only moves its elevation (dawn 8°, noon 70°, late afternoon 32°, dusk 12°; authored 42°). Here the sun sits toward +x and +z, 40° off the lane toward the east row and the pens. With `band_low` 0.65 the light has three steps: unlit (ambient only), middle (65%), and full.
  - The east row's street faces never take direct sun, at any time of day. They read by ambient light alone, about a seventh of their lit value.
  - The west row's street faces take the full step while the sun is below about 39°, and the depot's below about 49°. Higher, around noon, they drop to the middle step.
  - Anything facing north, toward the depot, never takes direct sun either. That includes the pens' fence as seen from `EnemySpawn`.
  - Up-facing ledges take the full step whenever the sun is above 30°, and the middle step at dawn and dusk.
  - At dawn and dusk the east row's shadow covers most of the street, and the gaps between east buildings throw light stripes across it.
- **No outline on scenery.** `characters/body_outline.gdshader` draws only on duelists and held objects. Scenery reads by silhouette, flat value, and the light steps. The duelists' ink outline (#120D0A) disappears against an ink-dark wall.
- **Sightlines.** What stands behind each marker, seen from `PlayerSpawn`:

| Marker | Position | Wall behind it | Who stands there |
|---|---|---|---|
| `EnemySpawn`, `EnemySpawns3/B` | (0, −8) | Depot street face, 42 m away. The duelist's shoulders to hat cover the band 1.0 to 2.3 m up, within ±1 m of x 0, or ±4 m while strafing | Every 1v1 enemy: rung 1 (Lata), rung 3 (Encarnado), the Sheriff in rung 7 |
| `EnemySpawns2/A`, `/B` | (∓6.9, −4) | Saloon to the west, bank to the east, both near z −13 | Two-NPC fights, three-player lobbies |
| `EnemySpawns3/A`, `/C` | (∓7.5, 0) | Saloon–hotel gap to the west, newspaper to the east, near z −5 | Rung 7: the Ghost west, the Drunk east |
| `PlayerSpawn`, seen from `EnemySpawn` | (0, 8) | The pens' fence behind the torso, 36 to 48 m away; the horizon behind the head | The player, and the other human in multiplayer |

- **Free roaming.** Flat and VR stick locomotion are free, and Main Street has no `Guard*` walls, so a player can walk behind any building and out into the desert. No building is safely one-sided.
- **Props are static.** Barrels, cow, hitching rail, and trough are plain GLB meshes with `-convcolonly` static proxies. None is a physics body and none can be grabbed. A bullet on any of them plays the generic world impact, dust and a wood chip (`ImpactFeedback.world_impact`).
- **Shared with Train Rooftop.** `scenarios/train_rooftop/scenery_belt.gd` loops 90 copies of `env_rail_track_8m` under the train, whose wheels rest on its rails, and 180 cactus plants cloned from `env_desert_scatter`. `train_rooftop.tscn` also instances `env_terrain.glb` as its ground.
- **Hinge slabs.** `assets/shaders/world_surface_import.gd` swings the nodes named exactly `Sign` (saloon), `Canopy` (awning post), and `ShedAwning` (store) about one edge in gusts. `--autotest=load` fails if any of the four slab names, counting the practice hub's `PorchSign`, goes missing.

### Found in the greybox

None of these is in the brief. Where one needed a decision, F records it.

1. `env_street_ground.glb` is not in the scene. The street you stand on is `env_terrain`, in `M_DirtFar`. Decided: delete it (F21).
2. The awning canopies hang out over the street, not over the boardwalk. The build script points the beam at +Y and the scene turns +Y toward the street, while the importer's hinge table and `docs/SHADERS.md` treat +Y as the wall side. Decided: turn the instances so the canopies roof the walk (F7).
3. The rail line runs through the depot. Its rails at z −34 ± 0.7 lie on the hall's front wall line and under the platform. Decided: move it behind the hall (F9).
4. Every door starts at ground level, so the boardwalk deck (+0.40) hides the bottom 40 cm of each street door. The depot platform hides 0.8 m of the depot door, and the store's dock hides 0.7 m of the store door.
5. The track ballast tops out at +0.09, under the terrain top (+0.12), in both scenes. It never shows.
6. West awning posts C and D stand beside the hotel's gallery posts. Post E pierces the store's loading dock, posts E and F cut into its `ShedAwning`, and boardwalks G to I run inside the dock. East boardwalks G to I and posts E and F front the empty lot. Decided: remove west posts C to F; the walks inside the dock stay (F8).
7. Two of the three barrels in `prp_barrels` intersect by 8 cm.
8. Most meshes and proxies carry `.001` to `.007` suffixes (`Mass-convcolonly.003`). Godot strips them, so they work today, but the names are not unique.
9. The building triangle counts include band cuts left by the paused trim-sheet pass. The saloon's roof, a plain box, is 76 triangles. The trim-sheet UVs themselves are already gone: the GLBs on disk carry per-GLB UVs. The finals keep neither the strip UVs nor the band cuts.

## A. Art direction

Every building is a plain box with one shaped edge: the false front, a flat stage wall raised before a cheap gable roof to hide it and make the business look bigger and settled, with the better wood and the ornament on the front (Wikipedia; NPS Skagway; Edmonton Historical Board), so each top gets its own outline and, where it can, a sign bigger than the building (board #05). Members are few and thick, sized to the pixel grid: a Quest 3 resolves about 25 px per degree, so 10 cm is 9 px at duel distance and 3 px at the depot, and nothing smaller is modeled, the way Naughty Dog made Crash's pupils two polygons so they would not vanish (Meta; Andy Gavin). Wear is lived-in, not ruined: a sprung board, a lean, or a sag every few metres, always in silhouette, after Bodie's "weather-washed wood that tilts" and Jackson's owner-built boardwalks that never lined up (Saving Places; Jackson Hole Historical Society). Light is never painted, so colour is chosen against the scene's fixed sun: the east row, which never takes direct sun, wears pale colours and carries its detail on up-facing ledges that do (`TimeOfDay`, `toon_light.gdshaderinc`). The palette is loud, flat, and few, as on the board and on the catalog storefronts that small towns ordered by rail and often painted bright colours (NPS, Mesker): hot magenta, orange, and marigold on the sunny side, chalk lilac, stone, and adobe in the shade, and one company blue that only the railroad owns, the orange-against-cornflower and magenta-against-cobalt pairs of board #25 and #28 chosen for the image the way Araki colours (`steel-ball-run.md`). That company colour is history bent one notch: Southern Pacific painted its standard depots in one company scheme, yellow trimmed in brown, and this railroad's scheme is blue (Town of Danville; `steel-ball-run.md`). Unpainted wood weathers to one silver grey on sides, backs, walks, and posts, so paint means money and sits on the street faces, and like Spyro's flat-shaded far version of every level, each building must still read with all its detail switched off (Wikipedia; Hardcore Gaming 101).

**What this place feels like:** a company town's painted stage set, hot paint in the sun and chalk in the shade, with the railroad's blue wall standing behind whoever you face.

### Global rules

The other four sheets inherit these. A rule changes only here.

**Scale and proportion**

1. Metric, Z-up, 1 BU = 1 m, street face toward +Y, origin at ground level and centred on the width, as the build script does today.
2. Anything a body touches keeps its real size: doors 2.2 to 2.4 m tall, sills at the floor the door opens onto (boardwalk +0.40, depot platform +0.80, store dock +0.70), rails at 1.0 m, troughs 0.7 m, barrels 1.1 m. VR shows a wrong step or door at once.
3. Thin members are fattened so they read: posts 18 to 25 cm, rails and pickets 8 to 15 cm, battens 12 cm, frames 15 cm. Cornices, eaves, and horns may be exaggerated. Human-contact sizes may not.
4. Neighbouring buildings differ in skyline by at least 0.6 m, or in the shape of the top.
5. Silhouette changes stay inside the existing collision box, or the change is listed on this page with its reason.

**Detail**

6. The smallest modeled feature is 10 cm. Gaps between modeled boards are 5 to 8 cm, and exist only where the background shows through them.
7. Modeled boards are 25 cm wide. Model boards only where their ends or gaps make silhouette: deck and dock edges, fence boards, false-front top edges, canopy edges. Elsewhere a wall is a plane, and the seams are yours to paint later.
8. No bevels on wood. Stone corners and post tops get one 45° chamfer of 8 to 10 cm, where the cut face lands in a different light step. Never a rounded, multi-segment bevel.
9. Round parts get 6 sides under 30 cm across, 8 up to 1.5 m, and 12 above. Edges stay hard and shading flat.
10. Ledges carry the shade side. Sills, string courses, cornice tops, and hoods project 8 to 15 cm with flat tops, so they catch the sun where the wall cannot.
11. Openings are inset 12 to 15 cm with an ink pane or void at the back. No interiors.
12. In the ground band, 0 to 2.8 m above the walk, place one readable feature per 1.5 to 2 m of street face. Give each building one skyline feature. The band between stays flat paint.

**Wear: lived-in**

13. One wear accent per 4 m of street face, always in silhouette: a sprung board with its end lifted 6 to 10 cm, a lean of 1.5 to 3°, a sag of 15 to 20 cm over a 9 m span or 5 to 8 cm on a deck between posts, a missing board or picket, a chipped stone or frame block of 10 to 15 cm.
14. Nothing is broken through, no hole opens into an interior, and nothing has fallen. Wood sags; stone does not.
15. A repeated module gets one accent, placed off-centre so its repeat does not read as a pattern.

**Colour and value**

16. No light in any Base Color: no baked AO, shadow, highlight, dirt, or wear.
17. Find each scene's sun yaw first; it never changes. Faces the sun reaches take saturated colours at any value from Y 0.1 up. Faces it never reaches take pale colours of Y 0.4 or more, so ambient light leaves them coloured instead of black.
18. Trim takes the opposite value of its body: bone on saturated bodies, ink on pale ones.
19. Openings are ink, the duelists' outline colour: panes, door voids, trough water.
20. Raw wood is one silver grey in every scene.
21. Company blue belongs to the railroad alone: the depot, the water tower, and later the trains if those sheets want it.
22. The wall behind a spawn marker, at the duelist's head height, is one flat field with no lines, of a mid value (never ink-dark), clear of the roster's colours. See the backdrop check below.
23. Every material uses an exact value from the palette, roughness 0.9, metallic 0. The importer merges materials whose name, colour, and roughness match, so a near-duplicate becomes a new material.
24. The ground keeps its ochres (`M_Dirt`, `M_DirtFar`). Nothing vertical uses a ground hue.

**Build hygiene**

25. Names are unique in the `.blend` and never end in `.001`. Prefix them with the asset: `Saloon_Front`, `Saloon_Mass-convcolonly`. Exact names stay as they are: `Sign`, `Canopy`, `ShedAwning`, and the plant parts.
26. One object per material per asset, plus the hinge slabs. Each object is a draw call, drawn again into the sun's shadow map.
27. Delete faces nobody can see: bottoms on the ground, tops under roofs, roof undersides inside false fronts, faces flush against another mesh. They cost triangles, overdraw (every scenery material renders both sides), and texture space in the per-GLB unwrap.
28. Collision proxies keep the `-convcolonly` suffix and their footprint unless a change is listed on this page.

### Palette

Enter the linear value as the Blender Base Color. Hex is the sRGB display value. Y is linear luminance. The base names come from the existing import tables, which set grain and sway by name, and each GLB's own copy (`M_Wood__bld_saloon`) holds that building's colour.

| Flat | Hex | Blender Base Color (linear) | Y | Base name | Used for |
|---|---|---|---|---|---|
| Raw wood | #8F8C86 | 0.275, 0.262, 0.238 | 0.26 | `M_Plank` | Sides, backs, walks, docks, platform decks, posts, hitching rails, trough sides, vigas |
| Bone | #E8DDC4 | 0.807, 0.723, 0.552 | 0.73 | `M_Trim`, `M_Cow` | Trim on saturated bodies, sign boards, cow coat |
| Ink | #120D0A | 0.006, 0.004, 0.003 | 0.00 | `M_Glass`; `M_Trim` on pale bodies | Panes, door voids, trough water; trim on pale bodies |
| Slate | #3A3542 | 0.042, 0.036, 0.054 | 0.04 | `M_Roof` | Every roof and canopy |
| Dark stain | #2B2630 | 0.024, 0.019, 0.030 | 0.02 | `M_WoodDark` | Shut doors, ties, joists, barrel staves |
| Iron | #24272E | 0.018, 0.020, 0.027 | 0.02 | `M_Iron` | Rails, bars, straps, hoops, brackets, pressed-metal cornices, bell |
| Company blue | #2D5BC9 | 0.026, 0.105, 0.584 | 0.12 | `M_Wood` | Depot and water tank |
| Saloon magenta | #C42D78 | 0.552, 0.026, 0.188 | 0.15 | `M_Wood` | Saloon street face, sun side |
| Hotel orange | #E06A22 | 0.745, 0.144, 0.016 | 0.26 | `M_Wood` | Hotel street face, sun side |
| Store marigold | #E8A825 | 0.807, 0.392, 0.019 | 0.45 | `M_Wood` | General store street face, sun side |
| Press lilac | #B8A6DC | 0.479, 0.381, 0.716 | 0.43 | `M_Wood` | Newspaper street face, shade side |
| Bank stone | #B9C4CE | 0.485, 0.552, 0.617 | 0.54 | `M_Masonry` | Bank, shade side |
| Jail adobe | #E9B7A6 | 0.815, 0.474, 0.381 | 0.54 | `M_Masonry` | Jail, shade side |
| Whitewash | #EFE9DA | 0.863, 0.815, 0.701 | 0.82 | `M_Whitewash` | Church, bank pilasters, pen fences (their street side never sees the sun) |
| Longhorn red | #9E3A26 | 0.342, 0.042, 0.019 | 0.10 | `M_CowDark` | Cow patches, muzzle, hooves, horn tips |
| Street dirt (unchanged) | #DDC499 | 0.72, 0.55, 0.32 | 0.57 | `M_Dirt` | Track ballast; tiling |
| Desert dirt (unchanged) | #B8A281 | 0.48, 0.36, 0.22 | 0.38 | `M_DirtFar` | `env_terrain`, also Train Rooftop's ground; tiling |
| Plants (unchanged) | | today's values | | `M_Cactus`, `M_CactusDark`, `M_Scrub`, `M_ScrubDry`, `M_Yucca` | Desert scatter; the sway names must stay |

`M_Plank`, `M_Trim`, and `M_Glass` are new to `main_street.blend` but already exist in the practice hub and Saloon GLBs. `M_Plank` and `M_Trim` take the wood grain (0.12); `M_Glass` takes none.

### Backdrop check

Luminance contrast between a wall and each roster colour, with a lit duelist. Shade-side walls are taken at a seventh of their lit value. The roster colours are approximations of the design pages; the shipped tints are the archetypes' `body_color`. Under 1.5, only a difference in hue separates the two.

| Wall | Red | Ox-blood | Gold | Absinthe | Bile yellow | Aquamarine | Bone | Black coat | Shipped tan / blue-grey / near-white | Ink outline |
|---|---|---|---|---|---|---|---|---|---|---|
| Company blue, lit (depot) | 1.1 | 2.2 | 2.7 | 2.5 | 3.3 | 3.6 | 4.7 | 3.0 | 1.4 / 1.4 / 4.6 | 3.2 |
| Saloon magenta, lit | 1.1 | 2.5 | 2.3 | 2.2 | 2.8 | 3.1 | 4.1 | 3.5 | 1.2 / 1.6 / 4.0 | 3.7 |
| Press lilac, shade | 1.6 | 1.4 | 4.1 | 3.8 | 4.9 | 5.5 | 7.1 | 2.0 | 2.1 / 1.1 / 6.9 | 2.1 |
| Bank stone, shade | 1.4 | 1.6 | 3.6 | 3.3 | 4.3 | 4.8 | 6.2 | 2.3 | 1.8 / 1.0 / 6.0 | 2.4 |
| Whitewash, shade (pens) | 1.1 | 2.2 | 2.7 | 2.5 | 3.3 | 3.6 | 4.7 | 3.0 | 1.4 / 1.4 / 4.6 | 3.2 |
| Raw wood, shade (rejected for pens) | 2.1 | 1.1 | 5.2 | 4.8 | 6.3 | 7.0 | 9.1 | 1.6 | 2.6 / 1.4 / 8.8 | 1.6 |
| SP yellow, lit (rejected for depot) | 3.5 | 8.1 | 1.4 | 1.5 | 1.2 | 1.0 | 1.2 | 11.4 | 2.8 / 5.2 / 1.2 | 12.0 |
| Company black, lit (rejected for depot) | 3.1 | 1.3 | 7.7 | 7.1 | 9.3 | 10.4 | 13.4 | 1.1 | 3.9 / 2.1 / 13.1 | 1.1 |

Company blue's weak cases are the Sheriff's red, which hue separates, and the shipped tan and blue-grey placeholder tints. Yellow swallows Lata at rung 1 and the Ghost. Black swallows the duelists' ink outline and the player's black coat.

## B. Asset sheets

| Asset | Copies here | Train Rooftop | Class | Triangles today | Budget each | Budget in scene |
|---|---|---|---|---|---|---|
| `bld_saloon` | 1 | | Street-led volume, hero | 236 | 900 | 900 |
| `bld_depot` | 1 | | Full volume | 320 | 1,300 | 1,300 |
| `bld_hotel` | 1 | | Street-led volume | 416 | 900 | 900 |
| `bld_general_store` | 1 | | Street-led volume | 264 | 700 | 700 |
| `bld_newspaper` | 1 | | Street-led volume | 164 | 500 | 500 |
| `bld_bank` | 1 | | Street-led volume | 216 | 600 | 600 |
| `bld_jail` | 1 | | Street-led volume | 192 | 500 | 500 |
| `bld_church` | 1 | | Full volume | 236 | 800 | 800 |
| `env_boardwalk_4m` | 18 | | Module | 64 | 150 | 2,700 |
| `env_awning_post` | 8 | | Module | 36 | 100 | 800 |
| `env_cattle_fence_4m` | 21 | | Module | 72 | 140 | 2,940 |
| `env_rail_track_8m` | 15 | 90 | Module, frozen dimensions | 120 | 120 | 1,800 |
| `env_desert_scatter` | 1 (160 plants) | 180 cactus clones | Dressing | 9,032 | 10,000 | 10,000 |
| `env_terrain` | 1 | 1 | Ground, frozen | 12 | 12 | 12 |
| `env_street_ground` | 0 | | Deleted (F21) | 12 | | 0 |
| `prp_barrels` | 2 | | Prop, cover | 84 | 300 | 600 |
| `prp_cow` | 5 | | Prop | 116 | 350 | 1,750 |
| `prp_hitching_rail` | 2 | | Prop | 36 | 80 | 160 |
| `prp_trough` | 2 | | Prop, cover | 20 | 120 | 240 |
| **Scene** | | | | **16,844** in the scene; 11,648 across the 19 GLBs | | **About 27,200** |

- **Street-led volume:** the street face is the hero, the side walls show through the 2 to 3 m gaps, and the back is closed and plain. A player can walk there, but nobody duels there.
- **Full volume:** seen from three sides or more.
- **One-sided facade:** none. Nothing stops a player walking behind the rows (F5).
- **Today's counts** are measured from the GLBs, collision excluded. The building counts include the trim-sheet band cuts.

**Why the budget grows.** The scene goes from 16,844 to about 27,200 triangles, 1.6 times and inside the approved 27,500, and nearly all of it lands on what is seen at duel range: buildings 2,044 to 6,200, walks and posts 1,584 to 3,500, pens 1,512 to 2,940, cows 580 to 1,750. That is under 2% of Meta's Quest 3 guideline of 1.5 million triangles per frame, so triangles are not what limits the Quest here. The PSX look caps detail first, and the per-asset ceilings keep it chunky.

Two limits are tighter than the triangle count:

- **Draw calls.** Meta's Quest 3 guideline is under 200 per frame. Main Street has 1,190 mesh objects today, each a draw call and drawn again in the shadow pass. Merging per material (rule 26) brings it to about 475, of which the scatter is about 290. A code-side fix waits for Quest timing (F18).
- **Train Rooftop multiplies two assets.** The track stays at 120 triangles for 90 copies, and cacti average at most 60 for 180 copies, so the belt stays near 21,600 triangles.

---

### `bld_saloon` (hero)

| | |
|---|---|
| Role | West row, north end: z −14 to −5, street face at x −12, sunlit. Street front only; the Saloon scene is the interior and does not instance this GLB. The wall behind the west marker of two-NPC fights. Seen from 12 to 21 m across the lane, at the left of the view toward the enemy |
| Size | Greybox; the details below set the final sizes. 9.0 wide × 12.0 deep. Body 4.0 m; false front to 5.5 m, 0.22 m thick. Door 1.8 × 2.2. Two windows 1.4 × 1.4, centred 2.8 m up, ±2.5 m off centre. `Sign` 6.0 × 0.7 m, 0.28 m proud, centred 4.85 m up. Proxy `Mass` 9.0 × 12.22 × 5.5 |
| Squint | A magenta wall standing taller than its roof, with a stepped top against the sky, a bone board across the top, and a dark door gap at the bottom with two small wings. Magenta, bone, ink |
| Triangles | 236 today; 900 at most |
| Collision | `Mass` unchanged, renamed `Saloon_Mass-convcolonly`. The doorway stays solid. Listed under rule 5: the lean, cornices, sign, sills, and corner boards stand 4 to 40 cm proud of `Mass` on the street side, and the sprung board and toothed board ends stick up to 12 cm past its sides at 4.0 to 4.65 m, so bullets pass through those edges. The crooked `Sign` makes the importer pivot it on its highest corner, so its low end swings 4 to 7 cm and still clears the shoulder caps by 4 cm. Listed under rule 22: the north window sits behind the two-NPC west marker's sightline (F22) |

Signature details, cut from the bottom:

1. Stepped false-front top with three edges against the sky: shoulders at about 4.6 m, a centre panel about 4.5 m wide up to 5.5 m, inside the proxy height, and a 45 cm deep bone cornice along both whose flat top catches the sun.
2. The sign: a bone board 7.0 × 1.0 m, its top near 4.9 m, so its ends rise above the shoulders against the sky while magenta panel shows above it. Hung on two iron straps, about 2° crooked. It stays one slab named `Sign`; the straps make its gust swing look intended.
3. Batwing doors: an opening 1.8 × 2.4 m from the deck (+0.40), an ink void 20 cm deep behind it, and two bone leaves 1.2 m tall hung 0.35 m above the sill.
4. Two windows in 15 cm bone frames, panes from 1.25 to 2.65 m so the frame tops line up with the door head and clear the porch canopies at 2.95 m. Ink panes inset 12 cm, sills projecting 12 cm.
5. Bone corner boards, 20 cm wide, up both front corners and the false front's edges.
6. The false front leans 1.5° toward the street, its top 14 cm proud of its base.
7. One sprung board on the false-front top, its end lifted 8 cm above the shoulder line.
8. The false front's back framing, two diagonal braces, visible from the gap to the hotel: the stage flat seen from the side.
9. A chipped corner on one window frame, a 15 cm block missing.

- **Wear in geometry:** the lean, the sprung board, the chipped frame. Nothing sags; the front is braced.
- **Base Color:** `M_Wood` Saloon magenta (street face, false front). `M_Trim` Bone (cornice, frames, corner boards, sign, batwings). `M_Glass` Ink (panes, void). `M_Plank` Raw wood (sides, back, braces). `M_Roof` Slate. `M_Iron` (straps).
- **UV:** keep the sign's street face one island, with no bevel and no cut across it. Delete the body top under the roof and the bottom. The two batwings are mirror copies with an island each; paint both.
- **Draws on:** board #05 (a sign bigger than the building), #28 (magenta answered by blue at the street's end), #16 and #22 (Araki's pinks); the false-front sources.

### `bld_depot`

| | |
|---|---|
| Role | Closes the lane's north end: hall z −42 to −34, street face at z −34, centred on x 0, sunlit except near noon. From `PlayerSpawn` it fills the middle ±9° of view at 42 m and is the wall behind every enemy at `EnemySpawn`. Railroad property. Its water tower moves to about (−12.5, −38), 11 to 19° left of the lane and clear of the duel field, and becomes the tallest thing in town (F10). The platform is walkable over an invisible ramp. The rail line moves behind the hall (F9) |
| Size | Greybox; the details below set the final sizes. Hall 14 × 8 × 4.2. Roof slab 15.2 × 9.2 × 0.4 to 4.6 m, a 0.6 m overhang. Two gable boxes on the roof to 5.8 m. Platform 16 × 3 × 0.8. Door 1.4 × 2.4 from ground level. Tank 3.2 m across and 2.5 m tall on four 6-sided iron legs to 6.0 m. Proxies `Hall` 14 × 8 × 4.6, `Platform`, `PlatformRamp`, `Tower` 3.5 × 3.5 × 8.5 |
| Squint | A long, low company-blue block under a deep dark roof, a thin plank line at its feet, and a huge blue tub high on a timber trestle to its left, the tallest shape in town. Company blue, slate, bone |
| Triangles | 320 today; 1,300 at most (hall and roof about 600, tower 500, platform 200) |
| Collision | `Hall`, `Platform`, and `PlatformRamp` unchanged; door sills rise to +0.8 in the mesh only. `Tower` moves 2.5 m out with the tower and grows to about 7.4 m square and 17 m tall: one box, so the space between the legs is solid (F10). Listed under rule 5: the bay window pokes 0.6 m past `Hall` at the back; the walls rise to about 4.7 m, above `Hall`'s 4.4 m; and the 1° lean carries the tub and cone up to 0.3 m past `Tower` near the top. Bullets pass through those edges |

Signature details, cut from the bottom:

1. The duel field: the street face within ±4 m of x 0, from the platform (0.8 m) to 2.6 m up, is one flat company blue with no frame, batten, sign, or opening.
2. Deep eaves: a low gable roof with its ridge along the hall at about 6.0 m, 1.2 m overhangs, and big bone knee brackets every 3 m. This is the depot's skyline.
3. The water tower at full size (F10): a 12-sided tub 7 m across and about 4.9 m tall, its bottom 12 m up like the Beaumont tank's. Three iron hoops 12 cm tall and 5 cm proud, a 6-sided slate cone roof with its tip near 19 m, and the spout arm folded up. It stands on eight 30 cm timber legs, splayed slightly at the base, with two levels of X-bracing. The tower moves 2.5 m further from the hall so its legs clear the deeper eaves.
4. Street-face doors outside the field. On one side, a bone waiting-room door, 1.2 × 2.4 m from +0.8 and 4.5 to 5.7 m off centre, since passengers now come from the town side. On the other, a blue sliding freight door, 2.4 × 2.6 m, under an iron track.
5. The company sign: a bone board along the full eave fascia, about 4.0 to 4.6 m up, which lands above the duelist's hat from `PlayerSpawn`.
6. Platform: raw planks with toothed ends at the street edge and a company-blue fascia. No bone edge stripe: the platform's top edge crosses behind the duelist's chest.
7. Wear: the ridge sags 15 cm at mid-span, one platform board is sprung, the tank leans 1°.
8. The agent's bay on the track side, which is now the back: a three-sided bay window projecting 0.6 m, ink panes in bone frames, facing the rails. From the street it shows only at an angle.
9. A stovepipe on the roof, off centre, as a skyline accent.
10. Board and batten outside the field: battens 12 cm wide and 6 cm proud every 1.2 m.

- **Base Color:** `M_Wood` Company blue (walls, fascia, tub, freight door). Railroad property is painted all round, sides and back included: decision F4 covers the town's businesses, not the company. `M_Trim` Bone (brackets, frames, sign, waiting-room door). `M_Glass` Ink. `M_Plank` Raw wood (platform deck, trestle). `M_Roof` Slate. `M_Iron` (hoops, spout, door track, stovepipe).
- **UV:** the duel field is one plane and one island. The tub unrolls as one rectangle only while it stays two round caps with quads between them; deleting its hidden top cap is fine and splits the side into three or four islands.
- **Draws on:** board #18 (one colour block behind an ink figure), #28 and #02 (cobalt grounds), #30 (the boss drawn as landscape: the company stands behind every opponent), #00 (the duel framed with scale contrast). Southern Pacific's Standard Station No. 22 in one company scheme (Town of Danville). The agent's bay window "for better visibility up and down the track" (A Guide to Georgia's Railroad Depots). A 50,000-gallon tank of staves and bands raised 40 ft on eight timber piers (Beaumont tank, 1875). Leone's three gunmen waiting at a ragged station (No Film School).

### `bld_hotel`

| | |
|---|---|
| Role | West row middle: z −3 to 8, street face at x −12, sunlit, level with the lane's centre and 13 m from `PlayerSpawn`. The largest west building and the only overhead structure near the lane: its gallery deck, 3.2 m up over the west walk, has collision. Its north end is behind the three-NPC west marker |
| Size | 11 × 14, two storeys: body 7.0, false front to 8.0. Door 1.4 × 2.2. Eight windows 1.1 × 1.3 at 2.0 and 5.0 m up, ±1.2 and ±3.5 m off centre. Gallery deck 11 × 2 × 0.15 at 3.2 m, rail 0.9 m, four posts 0.15 m square and 4.0 m tall. Proxies `Mass`, `Gallery`, four `GalPost` 0.2 m square |
| Squint | An orange two-storey wall cut across the middle by a silver gallery with a comb railing and four posts. Orange, raw silver, bone |
| Triangles | 416 today; 900 at most |
| Collision | Unchanged: `Gallery` and the four post proxies keep their positions. West porch posts C and D, which doubled the gallery posts, are removed (F8) |

Signature details, cut from the bottom:

1. The gallery: a deck edge with toothed board ends, a picket railing (top rail, bottom rail, 8 cm pickets every 45 cm), and four posts with knee braces.
2. False-front top: a flat cornice with a raised centre name board to 8.0 m and shoulders 0.4 m lower.
3. Window rhythm: two rows of four in bone frames with 12 cm sills. The two middle upper windows become doors onto the gallery, sills at its deck.
4. A street door with an ink transom light.
5. The gallery deck sags 6 cm between the middle posts.
6. One gallery post leans 2°, its top 14 cm out.
7. One picket missing: a gap in the comb.
8. Raw-wood sides and back.

- **Wear in geometry:** the deck sag, the leaning post, the missing picket.
- **Base Color:** `M_Wood` Hotel orange. `M_Trim` Bone. `M_Glass` Ink. `M_Plank` Raw wood (gallery, sides, back). `M_Roof` Slate.
- **UV:** the pickets become many tiny islands at this GLB's density, too small to paint; they take one flat colour.
- **Draws on:** board #25 (orange answered by the blue depot), #12 (workwear exaggerated, padded and oversized: chunky gallery members); one- and two-storey false fronts (Wyoming SHPO).

### `bld_general_store`

| | |
|---|---|
| Role | West row, south end: z 10 to 19, street face at x −12, sunlit, 14 m from `PlayerSpawn`, behind the player's left. Its raised loading dock (0.7 m, with an invisible ramp) and shed awning front the walk. The dock is walkable and is cover on the player's side of the street |
| Size | 9 × 12. Body 4.5, false front to 5.5. Door 1.2 × 2.1. Two display windows 2.0 × 1.6 at 2.2 m. Dock 6.3 × 2.4 × 0.7. `ShedAwning` 6.75 × 2.6 × 0.12 at 2.9 m. Proxies `Mass`, `LoadingPlat`, `LoadingRamp` |
| Squint | A marigold false front with a pointed top, over a dark shed roof and a raw dock. Marigold, ink, raw silver |
| Triangles | 264 today; 700 at most |
| Collision | Unchanged. West porch posts E and F, which hit the dock and the awning, are removed (F8); the walks inside the dock stay |

Signature details, cut from the bottom:

1. A gable-shaped false front: the top edge rises from 4.9 m shoulders to a 5.5 m point, with an ink cornice following it.
2. `ShedAwning`: one slab with a ragged board-end front edge, hung from the facade on two ink brackets near the wall, so its gust swing reads as natural.
3. The loading dock: raw planks with toothed ends at the street edge and two visible steps at the ramp end, the invisible ramp's excuse.
4. Two big display windows, ink panes in ink frames.
5. The door at dock height (+0.70).
6. The awning sags 10 cm mid-span.
7. One dock board missing.
8. The false front's braces, visible from the gap to the hotel.

- **Wear in geometry:** the awning sag and the missing dock board.
- **Base Color:** `M_Wood` Store marigold. `M_Trim` Ink, since the body is pale. `M_Glass` Ink. `M_Plank` Raw wood. `M_Roof` Slate (awning).
- **UV:** keep `ShedAwning` a single slab; its top is one island.
- **Draws on:** board #15 (a saturated orange ground), #19 (letterpress oranges); catalog-bought decorated storefronts, often painted bright (NPS, Mesker).

### `bld_newspaper`

| | |
|---|---|
| Role | East row middle: z −6 to −1, street face at x 12, shade side at every hour. The narrowest building, 17 m from `PlayerSpawn`. The wall behind the three-NPC east marker: the Drunk in rung 7 |
| Size | 5 × 10. Body 4.0, false front to 5.0. Door 1.0 × 2.1. Display window 2.8 × 1.8 at 2.0 m. Proxy `Mass` |
| Squint | A narrow pale-lilac front with an arched top and one big dark window, and a blade sign sticking out over the walk. Lilac, ink |
| Triangles | 164 today; 500 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. An arched top, 4.6 m at the ends rising to 5.0 m in the middle, with a 30 cm ink cornice whose top catches the sun.
2. The display window: three lights split by ink mullions, over a deep sill ledge.
3. A blade sign: a 1.4 × 0.6 m board on an iron bracket at 3.2 m, square to the facade, so it reads from up and down the lane. Rigid: the hinge list has no name for it.
4. A door with a transom, in an ink frame.
5. A string course at 3.4 m: another lit line.
6. Two boards on the arch top stand 6 cm proud.
7. Raw-wood sides.

- **Wear in geometry:** the proud boards on the arch.
- **Base Color:** `M_Wood` Press lilac. `M_Trim` Ink. `M_Glass` Ink. `M_Plank` Raw wood. `M_Roof` Slate. `M_Iron` (bracket).
- **UV:** the blade sign's two faces are its two islands; leave both whole.
- **Draws on:** board #19 (letterpress wood type: this is the town's printer) and the board's seventh pattern, print texture: the printed West, not the filmed one.

### `bld_bank`

| | |
|---|---|
| Role | East row, north corner: z −16 to −8, street face at x 12, shade side. Its north wall faces the rail end and is seen from the lane. The tallest east building at 8.0 m, the high point of the east skyline at the enemy's end. The wall behind the two-NPC east marker |
| Size | 8 × 12 masonry. Body 7.5; parapet lip 8.3 × 12.3 × 0.5 to 8.0. Two whitewash pilasters 0.4 × 0.35. Door 1.5 × 2.4. Windows 1.2 × 1.6 at 2.4 m and 1.2 × 1.4 at 5.4 m, ±2.0 m off centre. Proxy `Mass` 8.3 × 12.3 × 8.0 |
| Squint | A tall pale stone block with a heavy dark cornice and a cut corner toward the depot. Pale stone, iron, white |
| Triangles | 216 today; 600 at most |
| Collision | Changed (F14): `Mass` is chamfered to match the cut corner. A chamfered box is still convex, so it stays one convex shape |

Signature details, cut from the bottom:

1. The cornice: pressed metal 60 cm deep, brackets every 1.5 m, and a centre pediment to 8.0 m. This is the east skyline.
2. The cut corner: the corner at the street and the rail end is chamfered 1.5 m, and the door moves into it.
3. A rusticated ground floor: 50 cm courses, each stepping out 3 cm with a flat top, so the shaded wall gets lit lines.
4. Pressed-metal hoods over all four windows, their tops lit.
5. Whitewash pilasters at the corners. Their sides facing the pens take the sun.
6. Iron shutters folded open beside the lower windows.
7. One cornice bracket missing; one course offset 4 cm.

- **Wear in geometry:** the missing bracket and the offset course. Stone does not sag.
- **Base Color:** `M_Masonry` Bank stone. `M_Iron` (cornice, hoods, shutters). `M_Whitewash` (pilasters). `M_Glass` Ink. `M_WoodDark` (door).
- **UV:** the course steps leave long, thin ledge islands; each holds one colour.
- **Draws on:** board #06 (the presentation piece: ornament on the object that matters), #01 (engraved, chased metal); catalog cornices, bracket ornaments, and window hoods (NPS, Mesker); the cut-corner entrance of late-19th-century small-town banks (NRHP nominations).

### `bld_jail`

| | |
|---|---|
| Role | East row, south end: z 2 to 8, street face at x 12, shade side. Squat, and 12 m from `PlayerSpawn`, the nearest east building. The Sheriff's place: rung 3 is Encarnado on this street |
| Size | 6 × 10 masonry. Body 3.8; roof slab 6.3 × 10.3 × 0.4 to 4.2. Door 1.1 × 2.1. Two windows 0.7 × 0.7 at 2.2 m with one 6 cm bar each. Proxy `Mass` 6.3 × 10.3 × 4.2 |
| Squint | A low pale adobe block with a comb of log ends under a flat roof, two small barred holes, and a dark strapped door. Adobe, ink, raw silver |
| Triangles | 192 today; 500 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. Vigas: seven round log ends, 8-sided and 22 cm across, projecting 45 cm under the roof line. A comb in silhouette, with lit tops.
2. Battered walls: the street face leans back 3°, thicker at the base, with eroded parapet corners cut as one big chamfer.
3. Windows with three bars each, 8 cm square, in 20 cm reveals.
4. The door: dark, with three iron straps and a big lock box.
5. A short board sign over the door.
6. An eroded notch at the base beside the door; one viga shorter, broken.
7. A heart punched through the door, about 30 cm tall, the same punch as the Sheriff's hat and star (F15). An ink plane behind the door fills the hole.

- **Wear in geometry:** the eroded corners and notch, the broken viga.
- **Base Color:** `M_Masonry` Jail adobe. `M_Plank` Raw wood (vigas, sign). `M_Iron` (bars, straps, lock). `M_WoodDark` (door). `M_Glass` Ink (window voids).
- **UV:** each viga end cap is its own small island; fine.
- **Draws on:** the Sheriff page (the conductor's punch through his hat and star), board #09 (a hat with holes cut in it). Adobe and vigas come from the Southwest; setting them in a wooden false-front street is deliberate, history bent one notch (`steel-ball-run.md`).

### `bld_church`

| | |
|---|---|
| Role | South-west landmark set back from the street: x −33 to −19, z 20 to 28, facing +x onto open ground beside the pens. From `EnemySpawn` it stands 31° right of the lane, behind the player, its spire 15° up; from `PlayerSpawn` it is behind you. The south end's landmark: the spire's tip is at 12 m. Only the water tower, at the north end, stands taller |
| Size | Nave 8 × 14 × 5.0; a gable box; a flat roof slab at 6.3 to 6.7 m. A square tower 2.2 m wide from 5 to 9 m, and a 4-sided spire of 1.3 m radius from 9 to 12 m. Door 1.6 × 2.6. Two windows 1 × 2 at 3.0 m. Proxy `Mass` 8.4 × 14.4 × 11.0 |
| Squint | A white box under a steep dark roof, with a square tower and a needle spire. White, slate |
| Triangles | 236 today; 800 at most |
| Collision | Unchanged. The box already covers the roof and tower; tightening it is optional and far from the lane |

Signature details, cut from the bottom:

1. The steeple: a square tower, an open belfry with four arched openings that show sky, and a tall 4-sided slate spire.
2. A real gable roof at about 50°, slate, its ridge sagging 15 cm.
3. Pointed-arch windows, three per long side, in ink.
4. A double door with a pointed transom, up two steps.
5. The bell, visible in the belfry.
6. The spire tilts 1.5°.
7. An iron cross on the spire's tip.

- **Wear in geometry:** the ridge sag and the tilted spire.
- **Base Color:** `M_Whitewash` Whitewash. `M_Roof` Slate. `M_Glass` Ink. `M_WoodDark` (door). `M_Iron` (bell, cross).
- **UV:** the spire's four faces are four islands; the belfry openings leave slivers around them.
- **Draws on:** board #23 (votive imagery is welcome given a reason: the Drunk twins carried saints in processions), #22 (a pale, shrouded shape at blue hour).

### `env_boardwalk_4m` (module, ×18)

| | |
|---|---|
| Role | The raised walk along both rows. Its deck top (+0.40) is frozen: the invisible `StepRamp`, the VR step clearance, and every door sill depend on it. From the lane its street edge is the long horizontal line at the facades' feet |
| Size | Deck 4.0 × 2.5 × 0.16, top at +0.40; three joists 0.15 × 2.4 × 0.2 under it. Proxies `Deck` (the same box) and `StepRamp`, a wedge running 1.0 m out from the street edge |
| Squint | A silver plank band on dark stubs with a ragged street edge |
| Triangles | 64 today; 150 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. Planks laid across the walk, 25 cm wide, their ends uneven at the street edge by ±4 cm: a toothed silhouette.
2. The deck stands on short sleepers, so a dark gap shows under its street edge.
3. A running step board along the street edge, from +0.02 to +0.22 (10 cm above the terrain top) and 0.3 m deep, inside the ramp's footprint: the invisible ramp's visible excuse.
4. One sprung plank, off centre, its street end lifted 5 cm.
5. Joist ends showing at the module ends.

- **Wear in geometry:** the sprung plank, and one plank 10 cm short.
- **Base Color:** `M_Plank` Raw wood (deck, step). `M_WoodDark` Dark stain (joists, sleepers).
- **UV:** the plank ends are tiny islands; fine.
- **Draws on:** each owner built and mended the walk in front of their own store, so the sections never matched and the boards rocked underfoot (Jackson Hole Historical Society).

### `env_awning_post` (module, ×8)

| | |
|---|---|
| Role | Porch posts at the walk's street edge, every 6 m, and thin cover. Eight stay: west A and B, east A to F (F8). Each instance turns 180° so its canopy roofs the walk (F7). The `Canopy` slab swings about 2° in gusts |
| Size | Post 0.18 m square × 3.0 m. Beam 0.15 × 1.8 × 0.15 at 2.85 m toward +Y. Canopy 1.2 × 2.0 × 0.08 at 2.95 m. Proxy `Post` 0.22 m square |
| Squint | A thin silver post, a knee brace, and a dark roof slab |
| Triangles | 36 today; 100 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. A post 20 cm square with a 28 cm base block and cap block.
2. Two knee braces from the post to the beam: a triangle in silhouette.
3. The canopy slab, 2.3 m long so it reaches the facades, with a ragged board-end edge (±5 cm).
4. The beam's end cut at 45°.
5. The canopy's free end tipped 2° down.

- **Wear in geometry:** the tipped canopy.
- **Base Color:** `M_Plank` Raw wood (post, braces, beam). `M_Roof` Slate (`Canopy`).
- **Constraint:** `Canopy` stays one separate slab with that exact name. The importer swings it about its +Y edge, so its post end moves about 8 cm at the 2° swing and up to 12 cm at the 3° peaks. Keep the cap and braces that far below it, and hide the gap behind a fascia on the canopy (F7).
- **UV:** the canopy's top is one island.
- **Draws on:** board #20 (rope and reins as the only line work: posts as line work in front of the facades).

### `env_cattle_fence_4m` (module, ×21)

| | |
|---|---|
| Role | Two stock pens at the south end, with five cows. From `EnemySpawn` the fence is the band behind the player's torso, 36 to 48 m away, and its street side never takes direct sun. Nowhere near the lane |
| Size | Three posts 0.12 m square × 1.4 m at −1.7, 0, and 1.7 m. Three rails 4.0 × 0.08 × 0.10 at 0.35, 0.75, and 1.15 m. One proxy per post and one per rail |
| Squint | A pale band with dark slits, cow backs above it |
| Triangles | 72 today; 140 at most |
| Collision | Changed (F12): the three rail proxies become one slab 4.0 × 0.16 × 1.3, because boards make the fence solid. The post proxies stay |

Signature details, cut from the bottom:

1. Five close boards, 25 cm tall with 6 cm gaps: a solid band behind the player's torso instead of a ladder.
2. Posts 20 cm square with slanted tops, standing 15 cm above the top board.
3. One board hanging loose at one end, dropped 5°.
4. Post heights that vary by ±5 cm.

- **Wear in geometry:** the loose board and the uneven posts.
- **Base Color:** `M_Whitewash` Whitewash: one material, one object. Raw wood would drop to near ink in this shade (backdrop check).
- **UV:** each board's two faces are long islands; fine.
- **Draws on:** board #03 (stripes as the pattern), #13 (cattle pattern as silhouette); Abilene's pens at the railhead, the cowtown's other end (Abilene).

### `env_rail_track_8m` (module, ×15 here, ×90 on Train Rooftop)

| | |
|---|---|
| Role | The rail line across the north end, x −60 to 60. Its 15 instances move from z −34, through the depot's front, to about z −45 behind the hall (F9). On Train Rooftop the belt loops 90 copies under the train at 20 m/s, and the train's wheels rest on its rails |
| Frozen | Length 8.0 m. Rail top +0.21. Rail centres ±0.70; the train's wheels sit at x ±0.72 with their bottoms at +0.21. Origin at the centre, length along local X |
| Size | Ballast 8.0 × 2.6 × 0.10, top at +0.09, under the terrain. Rails 0.14 m square. Seven ties 0.22 × 2.2 at a 1.1 m pitch, so the joint gap is 1.4 m. Proxy `Track` 8.0 × 2.6 × 0.28 |
| Squint | Two iron lines over a ladder of dark ties on a pale stripe |
| Triangles | 120 today; 120 at most, because Train Rooftop draws 90 |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. Eight ties at exactly 1.0 m pitch, centres at ±0.5 to ±3.5, so the joint disappears and the belt's 20 m/s scroll does not strobe backward. The pitch must stay above 0.56 m at 72 Hz.
2. Ballast raised to +0.14, just above the terrain, with sloped shoulders, so it shows as a pale stripe.
3. Ties 25 cm wide and 2.4 m long, tops at +0.15.
4. Rails 10 cm wide and 6 cm tall, tops at +0.21.
5. One tie skewed 4°.

- **Wear in geometry:** the skewed tie.
- **Base Color:** `M_Dirt` (ballast; tiling UVs, colour unchanged). `M_WoodDark` Dark stain (ties). `M_Iron` (rails).
- **UV:** the ballast keeps its 8 m tiling UVs and stays out of the image.
- **Draws on:** the railroad as the power behind the town (the Half-head, Sheriff, and Ghost pages).

### `env_desert_scatter`

| | |
|---|---|
| Role | 160 plants on a disc out to 220 m, outside a keep-out around the town; the nearest is about 29 m from the lane. Horizon dressing: never cover, no collision. Train Rooftop clones its cactus plants 180 times. Scrub, dry scrub, and yucca sway |
| Size | 645 meshes, 9,032 triangles. Saguaro ×39 (56 triangles on average), barrel ×20 (28), prickly pear ×17 (37), organ pipe ×14 (67), scrub ×43 (62), yucca ×18 (93), deadwood ×9 (40) |
| Squint | Green columns with raised arms and dark mounds on the ochre plain. The saguaro is the one shape that must read at 100 m, where a 4 m plant is still about 57 px tall |
| Triangles | 9,032 today; 10,000 at most, cacti 60 at most on average |
| Collision | None, as today |

Signature details, cut from the bottom:

1. Saguaro arms go out, turn at an elbow, and rise: three segments. Trunks 6-sided, arms 5-sided.
2. All seven kinds kept, each with its own outline: column, barrel, pad stack, pipe cluster, scrub mound, yucca star, dead sticks.
3. Yucca blades as three-sided spikes instead of flat boxes, for a sharper star.
4. The scale spread kept, 0.75 to 1.35.
5. Each plant's parts merged per material: 645 objects become about 290.

- **Wear in geometry:** the deadwood is the wear.
- **Base Color:** today's plant materials and values, unchanged. Sway follows the names, and Train Rooftop shows the same cacti.
- **Constraints:** keep the `Plant_###` empties, each with its origin at the plant's base. Part names keep the words the belt reads: `Trunk`, `Arm`, `Tip`, `Body`, `Col`, `Pad` on cacti; `Clump`, `Blade`, `Stick` on the rest. Each swaying mesh stays one plant's own mesh, because sway bends by that mesh's height.
- **UV:** do not paint this GLB. Its 645 meshes share one 256 px image with no padding, and 24 of them get under 16 px².
- **Draws on:** board #14 (white sand and a teal sky in place of red rock), #07 (a tiny ruin under a huge cliff: scale as the drama); Steel Ball Run's stages, where the terrain decides who wins (`steel-ball-run.md`).

### `env_street_ground`

| | |
|---|---|
| Role | None. A 28 × 90 × 1 m dirt box in `M_Dirt` with a proxy, 12 triangles. The build script makes it, but `main_street.tscn` does not instance it and its `.import` has no world-surface script |
| Work | Delete it (F21). It lives in four places: the GLB and its `.import`; its root and objects in `main_street.blend`, or `dev/unwrap_per_glb_blender.py` will export it again; its builder in `dev/build_main_street_blender.py`; and its rows in `docs/TEXTURE_LIST.md`, `docs/TEXTURING.md`, `docs/ARCHITECTURE.md`, and `docs/FEATURES.md` |

### `env_terrain`

| | |
|---|---|
| Role | The street and the whole desert: a 2,000 m square box, top at +0.12, `M_DirtFar` with 8 m tiling UVs, proxy `TerrainPlayable`. Also Train Rooftop's ground |
| Frozen | The top at +0.12 (spawn floors, BUG-027; building feet sink 12 cm into it), the colour, the UVs |
| Squint | The ochre ground |
| Work | None. Deleting its bottom and side faces would save 10 triangles, not worth touching a shared asset |

### `prp_barrels` (×2)

| | |
|---|---|
| Role | Crouch cover at the walk's edge. The east group at (9.3, 8) is level with `PlayerSpawn`, 9 m to the right; the west group at (−9.3, −10) is near the enemy's end. Static |
| Size | Three 8-sided barrels, 0.4 m radius × 1.1 m; two of them intersect by 8 cm. Proxy `Barrels` 1.6 × 1.0 × 1.1 |
| Squint | Three dark bulging drums, one lid ajar. Dark stain, iron |
| Triangles | 84 today; 300 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. Bulged staves: a waist ring 10% wider than the ends.
2. Two iron hoops each, 8 cm tall and 4 cm proud, their tops catching light.
3. One lid ajar, tilted 10°.
4. One barrel leaning 4° against another.
5. The overlapping pair pulled apart, all three inside the proxy.

- **Wear in geometry:** the lean and the lid.
- **Base Color:** `M_WoodDark` Dark stain (staves, lids). `M_Iron` (hoops). Dark drums read against the silver walk behind them.
- **UV:** each barrel's side is one or two islands; three barrels, three sets.
- **Draws on:** board #12 (workwear exaggerated: everything padded and oversized).

### `prp_cow` (×5)

| | |
|---|---|
| Role | Pen dressing behind the player, seen from `EnemySpawn` at 36 to 48 m. Static |
| Size | Body box 0.55 × 1.5 × 0.7 with its back at 1.2 m; head, snout, 5-sided horns spanning about 1.0 m, legs 0.14 m square. Overall 1.0 × 1.57 × 2.15. Proxy `Cow` 0.7 × 1.8 × 1.5 |
| Squint | A long pale body, a low head, and a horn bar wider than the body. Bone with big red patches |
| Triangles | 116 today; 350 at most |
| Collision | Unchanged. The horns may poke past the box |

Signature details, cut from the bottom:

1. Horns spanning 1.6 m, going out and then up, three 6-sided segments each, with dark tips.
2. A body 2.2 m long with a deep chest, a hump at the shoulders, a sloping rump, and a tufted tail.
3. Three big patches as separate faces in the second material.
4. The head carried low.
5. Ears.
6. Dark hooves.

- **Wear in geometry:** none; it is an animal.
- **Base Color:** `M_Cow` Bone (coat, horns). `M_CowDark` Longhorn red (patches, muzzle, hooves, horn tips).
- **UV:** the patches are separate faces, so the image can repaint them freely. Check the horn and tail islands for folds.
- **Draws on:** board #13 (a cowhide suit on a pinto: the pattern is the silhouette); Texas Longhorn coats are "extremely variable", about 40% some shade of red, with horns spanning more than 2.4 m (Wikipedia).

### `prp_hitching_rail` (×2)

| | |
|---|---|
| Role | Walk-edge dressing at (±9.2, ±10), and thin cover: only the posts collide, so bullets pass the rail |
| Size | Two posts 0.12 m square × 1.0 m at ±1.2; a rail 2.6 × 0.1 × 0.1 at 0.95 m. Post proxies only |
| Squint | A silver bar on two stubby posts |
| Triangles | 36 today; 80 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. Posts 18 cm square with the rail set in a saddle notch.
2. The rail worn thin over its middle metre, an 8 cm waist: the rope wear.
3. Slanted post tops.
4. One post leaning 3°.

- **Wear in geometry:** the worn waist and the lean.
- **Base Color:** `M_Plank` Raw wood.
- **UV:** the waist splits the rail into three islands; fine.

### `prp_trough` (×2)

| | |
|---|---|
| Role | Low cover at the walk's edge, long axis across the street. West at (−9.2, 2) spans x −10.2 to −8.2; east at (9.2, −4) spans 8.2 to 10.2. The street end sits 1.3 m from the two-NPC east marker and about 1.8 m from the three-NPC west marker, so the footprint is frozen |
| Size | One iron box 0.6 × 2.0 × 0.7; the proxy is the same box |
| Squint | A low tub with a pale rim and a black water surface |
| Triangles | 20 today; 120 at most |
| Collision | Unchanged |

Signature details, cut from the bottom:

1. A plank tub with 8 cm sides and an ink water plane 10 cm below the rim.
2. Two iron bands.
3. Two skids under the ends, so a gap shows under the tub.
4. One split corner.

- **Wear in geometry:** the split corner.
- **Base Color:** `M_Plank` Raw wood (tub). `M_Iron` (bands). `M_Glass` Ink (water).
- **UV:** the water plane is one island.

## C. Build order

**Hero: `bld_saloon`.**

- Its kit is the one the others copy: false front, cornice, sign, door and frames, windows, raw sides, sills at deck height. The hotel, store, and newspaper reuse it, and the bank and jail borrow parts of it.
- It tests the sunlit rules, the sign's hinge constraint, the 10 cm floor, and the wear density on a building players see in every duel.
- It is the genre's archetype (board #05), and the Saloon scene's sheet must match its street wall.
- It meets the boardwalk and the awning post, so its review covers those two modules too.

**Order** (×N marks a modular repeat):

1. `bld_saloon`, the hero, with `env_boardwalk_4m` (×18) and `env_awning_post` (×8) in front of it for the review. Scene edit first: delete west posts C to F and turn the other eight 180° (F7, F8).
2. `bld_depot`, with the full-size water tower: the duel field and company blue. Scene edit: move the 15 track instances behind the hall to about z −45 (F9).
3. `bld_hotel`, `bld_general_store`, `bld_newspaper`: false-front variations on the hero's kit.
4. `bld_bank`, `bld_jail`: masonry and the shade-side ledge rules.
5. `bld_church`.
6. `env_cattle_fence_4m` (×21) and `prp_cow` (×5): the player's backdrop.
7. `prp_trough`, `prp_barrels`, `prp_hitching_rail` (×2 each): cover. Re-run `--autotest=multi`.
8. `env_rail_track_8m` (×15 here, ×90 on Train Rooftop): frozen dimensions; check Train Rooftop.
9. `env_desert_scatter`: check Train Rooftop.
10. `env_terrain`: no work. `env_street_ground`: delete it (F21).

## D. Review checklist

### Views

| View | Where | Camera | For |
|---|---|---|---|
| Lane P | Godot, Main Street, shaders on | Eye at (0, 1.82, 8), looking at (0, 1.82, −8), the flat camera's field of view | Depot, saloon, hotel, newspaper, bank, jail, walks, posts, track, props |
| Lane E | Godot | Eye at (0, 1.82, −8), looking at (0, 1.82, 8) | Pens, cows, church, store, jail, hotel |
| Flank | Godot | From Lane P's eye, aimed at each multi marker: (∓6.9, 1.82, −4) and (∓7.5, 1.82, 0) | Saloon, hotel, newspaper, bank |
| Walk | Godot | On the walk in front of the asset, eye 2.1 m up (deck + 1.7), 3 m from the facade, at the door | Every building, the walk, the posts |
| Front 16 | Blender, asset at its parked spot in `main_street.blend` | On +Y, 16 m in front of the asset's street face (not its origin), 1.7 m up, aimed at the face's centre 2.0 m up, 50 mm lens | Every asset |
| Three-quarter | Blender | 45° between +Y and +X, 20 m out, 1.7 m up, aimed at the asset's centre, 50 mm lens | Every asset |
| Silhouette | Blender: Workbench, flat lighting, single black colour, white world | Front 16, the +X side, and the front again from 40 m | Every asset |
| Squint | The Front 16 render | Shrunk to 64 px wide, enlarged back with nearest filtering | Every asset |

- Render each Godot view at dawn, noon, and late afternoon with F3 `time_of_day`.
- The flat camera's eye is 1.7 m over the street, which is y 1.82.
- For the Godot views, a temporary `Camera3D` in the editor at these coordinates does the job. Do not save it into the scene.

### Pass or fail, every asset

1. **Silhouette:** can you name the asset from its black outline alone?
2. **Squint:** does the 64 px render show one shape and at most three flats?
3. **Size floor:** is every modeled feature at least 10 cm?
4. **Wear:** is there one accent per 4 m of street face, in silhouette, and no wear in any colour?
5. **Budget:** are triangles within the budget, and objects equal to materials plus hinge slabs?
6. **Names:** unique, no `.001`, hinge slabs named exactly, proxies suffixed `-convcolonly`?
7. **UVs:** did `dev/unwrap_per_glb_blender.py -- --relayout --glb <name>` print no TINY share on a visible face? Does Blender's UV Select Overlap find nothing? Is each sign face, door face, and the depot's duel field a single island?
8. **Collision:** unchanged, or the listed change, with `--autotest=load` and `--autotest=multi` passing after export and reimport?

### Pass or fail, in context

9. Lane P and Lane E: is the lane clear, and is the wall behind each marker one flat field at head height?
10. Do the east facades read as colour, not black, at noon and at dusk?
11. Do the ledges on the shade side show as lit lines?
12. Do the duelists, in the shipped tints and in swatches of the designed colours, separate from the wall behind them at squint?
13. Does each building's skyline differ from its neighbours'?
14. Walk view, in a headset: do doors, steps, and rails look true to size from 3 m?

### Asset checks

| Asset | Check |
|---|---|
| `bld_saloon` | Does `Sign` swing in a gust (F3 **Wind**) without crossing its straps? Do the batwings read as batwings at 20 m? |
| `bld_depot` | From Lane P, does any line cross behind the enemy's hat or shoulders? Does the trestle stay clear of the duel field, 11 to 19° left of the lane? Does the tower read against the sky at dusk? |
| `bld_hotel` | Does the gallery's comb read at 13 m without shimmering when you move your head? |
| `bld_bank`, `bld_jail`, `bld_newspaper` | At noon, do the ledges show? |
| `bld_church` | From Lane E, does the belfry show sky through all four openings? |
| `env_boardwalk_4m` | Is the repeat invisible in a row of nine? Does a flat walker still climb the edge? |
| `env_awning_post` | Does the canopy clear its post when it swings? |
| `env_cattle_fence_4m` | From Lane E, does the fence read as a band behind the player's torso? |
| `env_rail_track_8m` | On Train Rooftop: wheels on the rails, no seam every 8 m, no backward strobing seen from the roof? |
| `env_desert_scatter` | Does the Train Rooftop belt still find cactus plants? `load` asserts it builds 80 or more pieces and that none sways |
| Props | Does `--autotest=multi`'s clearance probe still pass at every marker? |

### Tests

Run `--import`, then `--autotest=load` (materials, hinges, belt), `--autotest=multi` (marker clearance), and `--autotest=ragdoll` (spawn floors):

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
```

Headless runs do not compile shaders. The look needs a flat run, then a headset.

## E. Cross-scene dependencies

- **Global rules.** Rules 1 to 28 in A, the palette, and the backdrop check. The other sheets inherit them; a scene that needs an exception names it and gives the reason.
- **Train Rooftop reuses three assets:**
  - `env_rail_track_8m`: 90 copies looped under the train at 20 m/s, turned onto z, collision stripped. Frozen: 8.0 m long, rail tops at +0.21, rail centres at ±0.70 (the wheels' bottoms sit at +0.21, at x ±0.72), origin at the centre. Triangles stay at 120, and the tie pitch stays above 0.56 m.
  - `env_desert_scatter`: 180 cactus clones. The belt finds the `Plant_` roots, reads their part names, keeps each clone's rotation and scale, and sets its position. Cacti average 60 triangles at most, and their materials stay rigid, off the sway list.
  - `env_terrain.glb`: its ground. The top stays at +0.12, and the colour and UVs stay as they are.
  - After touching any of the three, run `--autotest=load`, which checks the belt builds at least 80 pieces and that none sways, then look at Train Rooftop in a flat run.
- **Saloon** inherits the palette, the batwing design, and the sign shape. The interior's street wall should agree with `bld_saloon`, since you leave one and enter the other.
- **Practice Hub** inherits the walk, post, and fence rules. Its `PorchSign` keeps that exact name.
- **Canyon** inherits the plant rules and the sun-side rule. Rock and sand keep their tiling UVs and flat colour.
- **Train Rooftop** may use company blue on railroad property. Nothing outside the railroad uses it.

**Build lessons from Main Street.** Every later build should follow these:

- **Set colours on the per-GLB copies.** `dev/unwrap_per_glb_blender.py` reuses an existing `<base>__<glb>` material by name and never copies a new colour onto it. Set the colour on the copy itself, or delete the stale copy. Reset any leftover specular on reused greybox copies too.
- **Use headless Blender, or close the live session first.** The unwrap script saves the `.blend`, so saving a live session afterwards overwrites its UVs.
- **Run the unwrap with `--relayout`.** A plain run keeps the old UVs and skips new meshes, and nothing is painted yet, so relayout is safe.
- **Check the sheet's numbers against each other before modeling.** On Main Street, window heights clashed with porch canopies, the church's roof pitch buried its belfry, and the fence and barrel sizes did not fit their colliders. Each fix is recorded in H.
- **Verify the shared assets explicitly.** `load` only checks that the Train Rooftop belt has 80 children, and the tracks alone pass that. Count the cactus clones.
- **Name collision proxies without dots.** Godot mangles a dot in a node name.

## F. Decisions

Answered on 2026-10-19. Every answer took the recommendation except two: the water tower goes to full size on a real trestle, and the unused street strip is deleted. The last column says what each decision changes on this page or in the scene.

| # | Question | Decision | What it changes |
|---|---|---|---|
| 1 | Wear level | Lived-in | Rules 13 to 15 stand |
| 2 | Palette | Sun side hot, shade side pale, railroad in company blue | The palette stands |
| 3 | Depot and tower colour | Company blue | |
| 4 | Painted sides | Street faces only; sides and backs raw silver | |
| 5 | Backs and boundaries | Free roaming, with closed volumes and plain backs | No guard walls |
| 6 | Interiors | None | Doorways stay solid |
| 7 | Porch canopies | Roof the walk, and keep the gust hinge | Scene: turn the eight remaining post instances 180°. Mesh: the canopy grows to 2.3 m and clears the post's cap by 12 cm |
| 8 | Doubled porch posts | Remove west posts C to F | Scene: delete four instances; eight posts remain |
| 9 | Rail line | Behind the hall, at about z −45 | Scene: move the 15 track instances. The depot's bay window moves to the track side, and the waiting-room door comes to the street face |
| 10 | Water tower | Full size, on a real 12 m trestle | A 7 m tub about 4.9 m tall, its bottom at 12 m and its roof tip near 19 m: the tallest thing in town. Eight legs. The tower moves 2.5 m further from the hall, `Tower` grows to about 7.4 m square and 17 m tall, and the depot's budget rises to 1,300 |
| 11 | Boardwalk variety | One module | |
| 12 | Pen fence | Five close boards | One slab proxy replaces each module's three rail proxies |
| 13 | Cows | Bone with longhorn-red patches | |
| 14 | Bank corner | Cut corner, with the proxy chamfered to match | `Mass` changes shape and stays convex |
| 15 | Lore marks | The jail heart only | No checker on the depot |
| 16 | Proportions | Thin parts fattened, human-contact sizes true | Rules 2 and 3 stand |
| 17 | Triangle budget | About 27,500 | With decisions 8 and 10, the plan lands near 27,200 |
| 18 | Scatter draw calls | Merge per plant now; decide a code fix after Quest timing | |
| 19 | Texture space | Decide after the hero's unwrap | Start at 256 px with hidden faces deleted. Data so far: the saloon unwraps at 10.2 px per metre, so its 7 m sign gets about 70 × 10 px; the depot, tower included, unwraps at 4.6 px per metre, so its 16 m sign gets about 75 × 3 px |
| 20 | How finals are built | Modeled in `main_street.blend` | Never re-run the build script on Main Street once the first final lands |
| 21 | `env_street_ground` | Delete it | Its asset sheet lists every place it lives |
| 22 | Saloon north window behind the two-NPC west marker (found in the hero build) | Accept it | An exception to rule 22, listed in the saloon's sheet. Dark hats lose contrast there in two-NPC fights and three-player lobbies |

## G. Pipeline friction

Where the existing texturing pipeline (`docs/TEXTURING.md`) adds work or constraints beyond "model and UV unwrap, then you paint by hand".

**Verdict on the unwrap: reuse `dev/unwrap_per_glb_blender.py` as it is.** It already does the UV job: one non-overlapping 0 to 1 layout per GLB at one texel density, islands upright and never mirrored, and `uv_lock` to keep hand edits. Its one risk is a chart that grows across faces up to 66° from its seed, which can fold a curved piece (horns, cactus arms, a sagging roof) onto itself. The overlap test in D7 catches that. The items below are its edges.

1. **Hidden faces eat texture.** The unwrap lays out every face at one density, hidden ones included. Simplest: delete them while modeling (rule 27). Cost: none; it also saves triangles and overdraw.
2. **Buildings get little texture.** One 256 px image per GLB leaves the buildings 6 to 11 px per metre, so a 7 m sign gets about 60 × 8 px, with no room for lettering. Simplest: accept it and paint big flats. Alternatives: 512 px for the eight buildings, which is the `TEX_PX` constant in the script and four times the memory, about 1.4 MB per building with mips (a `RELEASE_TODOS` memory line); or scale the sign islands up by hand after the unwrap, which `uv_lock` keeps. Decided: revisit after the hero's unwrap (F19).
3. **Every face gets the same density.** Backs and sides take as much of the image as the street face. Simplest: accept it. Alternative: shrink those islands by hand after the unwrap, about ten minutes per building, and the freed space only helps if you repack by hand.
4. **A plain run keeps old UVs.** The script keeps a GLB's existing UVs and only warns about new meshes. Simplest: run it with `-- --relayout --glb <name>` after each final. Cost: none while nothing is painted. After painting, a relayout breaks the image's fit.
5. **The build script still runs the paused trim-sheet pass.** `scenery_uv.process_scene()` cuts tall faces into bands (Main Street's unwrapped objects went from 1,692 to 2,500 triangles), writes strip UVs, and wires a `TrimSheetPreview` node. Decided: finals are modeled in the `.blend` (F20), so the pass never runs on them. Cost: none.
6. **A rebuild wipes finals.** The build script clears the scene and recreates the greybox. Decided: never run it on Main Street after the first final lands (F20). Cost: the greybox survives only in git history.
7. **No vertex colours, normal maps, emission, or alpha.** The importer skips such a material and `load` fails. So no PSX corner-colour shading, no glowing windows, and no alpha-cut fringe or lattice: variation is a separate material, which is a draw call, or your later image, and every gap is real geometry. Cost: triangles, which the budget includes.
8. **Names set behaviour.** A material's base name sets its grain and sway, so a magenta street face is still `M_Wood`. A new base name gets no grain, which is fine for paint, but must never be one of the sway names. Exact colours and one roughness let the importer merge materials. Cost: naming discipline only.
9. **The ground stays out of the image.** `M_Dirt` and `M_DirtFar` keep tiling UVs and flat colour, and `env_terrain` is Train Rooftop's ground too, so the street cannot be painted (ruts, stains) through this pipeline. Simplest: leave it. Alternative: ruts as geometry on a new street mesh, since the unused street strip is being deleted (F21).
10. **The scatter's image is useless.** 160 plants in 645 meshes share one 256 px image with no padding. Simplest: never paint it.
11. **Main Street exports from a parked layout.** Each GLB root sits 20 m from the next in the `.blend`, and the script moves it to the origin to export. Finals must stay under the same root empties with the same names. Cost: none.
12. **The texturing docs go stale.** `docs/TEXTURE_LIST.md` and the tables in `docs/TEXTURING.md` (mesh counts, densities) will be wrong after the remodel. Simplest: refresh them from the script's printout when the finals land.

The trim sheet, its texel-density targets, and the texture ripper play no part in this sheet.

## H. As built

Built on 2026-10-19 in `main_street.blend`, exported by `dev/unwrap_per_glb_blender.py`, untextured.

- **Tests:** `load`, `multi`, `ragdoll`, and `gauntlet` pass. `duel` fails about 4 runs in 6, at the same rate with the original greybox assets: its "replay hand" check belongs to BUG-029, which was already in progress.
- **Train Rooftop:** its belt still builds 90 tracks, 180 cacti, and 84 horizon spans. The new track keeps rail tops at +0.21 and centres at ±0.70.
- **Scene:** about 22,550 triangles and 465 mesh objects, against a budget of 27,500. The greybox had 16,844 triangles and 1,190 objects.

| GLB | Triangles / budget | Objects | Copies |
|---|---|---|---|
| `bld_saloon` | 394 / 900 | 7 | 1 |
| `bld_depot` | 1,038 / 1,300 | 6 | 1 |
| `bld_hotel` | 854 / 900 | 5 | 1 |
| `bld_general_store` | 486 / 700 | 6 | 1 |
| `bld_newspaper` | 326 / 500 | 7 | 1 |
| `bld_bank` | 375 / 600 | 5 | 1 |
| `bld_jail` | 364 / 500 | 5 | 1 |
| `bld_church` | 514 / 800 | 5 | 1 |
| `env_boardwalk_4m` | 128 / 150 | 2 | 18 |
| `env_awning_post` | 88 / 100 | 2 | 8 |
| `env_cattle_fence_4m` | 102 / 140 | 1 | 21 |
| `env_rail_track_8m` | 98 / 120 | 3 | 15, plus 90 on Train Rooftop |
| `env_desert_scatter` | 9,263 / 10,000; cacti average 52 | 278 | 1 |
| `env_terrain` | 12, unchanged | 1 | 1 |
| `prp_barrels` | 258 / 300 | 2 | 2 |
| `prp_cow` | 300 / 350 | 2 | 5 |
| `prp_hitching_rail` | 56 / 80 | 1 | 2 |
| `prp_trough` | 86 / 120 | 3 | 2 |

**Where the build departs from the pages above.** Each change fixes a clash the sheet's own numbers created.

- **`bld_saloon`:** windows run 1.25 to 2.65 m, under the turned canopies. The shoulders top out at 4.55 m and the sign's top is at 5.0 m at its centre. The lean is a shear from the ground. The roof is a low gable from 4.12 to 4.70 m.
- **`bld_depot`:** painted all round. The freight door carries blue Z-bracing so it reads against the blue wall. The walls rise to about 4.7 m, above `Hall`'s 4.4 m, and the leaning tank pokes up to 0.3 m past `Tower` near the top.
- **`bld_hotel`:** the lower middle windows and the gallery doors above them sit at ±1.65 m, because ±1.2 m hit the door. The door has a 12 cm frame and a 20 cm transom, so it stays under the gallery deck. The gallery posts are 0.20 m.
- **`bld_general_store`:** windows run 1.15 to 2.75 m. `ShedAwning` rises from 3.02 m at the street edge to 3.30 m at the wall, to clear the door hood and leave headroom over the dock. The door is an ink opening.
- **`bld_newspaper`:** the window is centred at 1.9 m, to clear east post B's canopy. `Newspaper_BladeSign` is its own object, which adds one draw call.
- **`bld_bank`:** windows sit at local x −2.6 and +1.3, beside the cut corner. Rustication covers the street face only, and the hidden roof is not modeled. `Mass` is chamfered 15 cm outside the visible cut, and the cornice and pilasters stand up to 0.45 m past it.
- **`bld_jail`:** the hidden roof is not modeled, and the vigas stand 0.2 m past `Mass`.
- **`bld_church`:** the roof pitch is 45°, not 50°, which would have buried the belfry. The walls are 4.5 m, and the tower rises from the ground at the street end. The belfry spans 8.7 to 10.0 m, the spire tops out at 12.0 m, and the cross at 12.6 m. The steps stand outside `Mass` and have no collision.
- **`env_boardwalk_4m`:** planks 10 cm thick, so an 8 cm dark gap shows under the street edge.
- **`env_awning_post`:** the canopy is 10 cm thick with an 18 cm fascia. The visible post ends at 2.685 m; its proxy still reaches 3.0 m.
- **`env_cattle_fence_4m`:** boards are 21 cm, so the band tops out at 1.29 m, inside the slab proxy, and the cows' backs show above it. Posts reach about 1.44 m.
- **`prp_barrels`:** barrels are 0.27 m in radius at the ends and 0.30 m at the waist, because three barrels standing apart don't fit the proxy at 0.4 m. The ajar lid's edge stands 10 cm above the proxy.
- **`prp_cow`:** the rump and muzzle reach 0.1 and 0.3 m past the box.
- **`prp_hitching_rail`:** a V saddle on the post top instead of a notch.

**Still open:**
- The in-context review in Godot and a headset: D, items 9 to 14.
- Texture space for painting (F19), now with data: the saloon gets 10.2 px per metre and the depot 4.6.
- Quest timing for draw calls (F18).

## References

**Repo**

- `.claude/skills/gunslinger-taste/references/board.md`: items #00, #01, #02, #03, #05, #06, #07, #09, #12, #13, #14, #15, #16, #18, #19, #20, #22, #23, #25, #28, #30, #31, and the seventh pattern, print texture.
- `.claude/skills/gunslinger-taste/references/steel-ball-run.md`: no fixed palette, history bent one notch, stages with personalities.
- `docs/design/characters/`: `drunk.md` (Lata, rung 1; the processions), `sheriff.md` (Encarnado, rung 3; the punched heart), `ghost.md`, `half-head.md` (the railroad; the checker), `player.md` (the black coat).
- `docs/SHADERS.md`, `docs/TEXTURING.md`, `scenarios/time_of_day.gd`, `assets/shaders/world_surface_import.gd`, `scenarios/train_rooftop/scenery_belt.gd`, `dev/autotest.gd`, `dev/unwrap_per_glb_blender.py`, `dev/scenery_uv.py`, `dev/blender_kit.py`.

**Old West building**

- [False front](https://en.wikipedia.org/wiki/False_front), Wikipedia: higher-grade materials and greater ornament on the front; the front largely hides the roof; a more settled look for frontier towns.
- [Boomtown or false front](https://www.edmontonhistoricalboard.com/character-defining-elements/boomtown-or-false-front), Edmonton Historical Board: "taller than the roof and hides it from view".
- [Boas Tailor & Furrier Shop](https://home.nps.gov/klgo/learn/historyculture/boas.htm), NPS Klondike Gold Rush: an elaborate wall added to a simple gable-roofed building; sides and back built less solidly; an image of size and prosperity.
- [Big Horn Johnson Street Historic District](https://wyoshpo.wyo.gov/index.php/programs/national-register/wyoming-listings/view-full-list/766-big-horn-johnson-street-historic-district), Wyoming SHPO: one- and two-storey false fronts, spaced unevenly.
- [At the Forefront of Storefronts](https://www.nps.gov/articles/at-the-forefront-of-storefronts-frank-ben-and-george-mesker.htm), NPS: the Mesker companies' catalog storefronts, shipped by rail from the 1880s to the 1910s and often painted bright colours; cornices, bracket ornaments, window hoods.
- [Jackson's Boardwalk Shuffle](https://jacksonholehistory.org/wp-content/uploads/chronicle-nov-2022-Boardwalk-Shuffle.pdf), *The Chronicle*, Jackson Hole Historical Society, November 2022: owners built and repaired the walk in front of their own stores, which left it varied and precarious.
- [Aging Gracefully](https://savingplaces.org/stories/aging-gracefully-the-resilience-of-historic-structures-preserved-in-place), National Trust for Historic Preservation: Bodie in arrested decay, "weather-washed wood that tilts".
- [Griswold National Bank NRHP nomination](https://npgallery.nps.gov/pdfhost/docs/nrhp/text/79003695.PDF), one of several nominations describing the cut-corner bank entrance as typical of small towns. The scans were read through search excerpts only.

**Rail and cattle**

- [Southern Pacific Railroad Depot](https://danville.ca.gov/254/Southern-Pacific-Railroad-Depot), Town of Danville: 1891, Standard Station No. 22, "a faded dandelion yellow / gold color and trimmed in brown".
- [A Guide to Georgia's Railroad Depots](https://www.railga.com/Depots/depotguide.html): the agent's bay window "for better visibility up and down the track"; freight doors on both sides.
- [Beaumont St. Louis and San Francisco Railroad Water Tank](https://en.wikipedia.org/wiki/Beaumont_St._Louis_and_San_Francisco_Railroad_Water_Tank), Wikipedia: 1875; cypress staves and steel bands, a six-sided shingle roof, 50,000 gallons, raised 40 ft on eight timber piers.
- [Cincinnati Southern standard tank](https://www.e-rara.ch/zut/content/pagetext/31998710), an 1893 railroad buildings text: 50,000 gallons, about 23 ft across. Read through a search excerpt.
- [September 5, 1867: The Day Abilene Became a Cowtown](https://abilenekansas.org/blog/2025/09/03/september-5-1867-the-day-abilene-became-a-cowtown), Abilene: McCoy's loading pens at the railhead.
- [Texas Longhorn](https://en.wikipedia.org/wiki/Texas_Longhorn), Wikipedia: coat colour, horn span.

**Film**

- [When Silence Speaks Louder Than Bullets](https://nofilmschool.com/once-upon-a-time-west-opening-scene), No Film School: three gunmen waiting at a ragged station in *Once Upon a Time in the West*.

**PSX era and hardware**

- [Making Crash Bandicoot, part 3](https://all-things-andy-gavin.com/2011/02/04/making-crash-bandicoot-part-3/), Andy Gavin: shaded, untextured triangles; corner colours in place of texture; pupils made two polygons so they stayed visible.
- [Spyro the Dragon](https://www.hardcoregaming101.net/spyro-the-dragon/), Hardcore Gaming 101: every level has a flat-shaded version with no detail, faded in by distance.
- [Device optimization comparison](https://developers.meta.com/horizon/resources/device-optimization-comparison/), Meta: Quest 3 at under 200 draw calls and under 1.5M triangles per frame, 72 Hz minimum, 90 Hz recommended.
- [Meta Quest compare](https://www.meta.com/ca/quest/compare/), Meta: Quest 3 at 2064 × 2208 per eye and 25 pixels per degree.
