# Texturing

How to color and texture a mesh in Blender so it matches the look and runs on a Quest 3. Covers what the pipeline accepts today, the rules of the look, the steps per asset type, and the performance limits.

Shaders: [`SHADERS.md`](SHADERS.md) · Art direction: [`design/README.md`](design/README.md) · Blender setup: `.claude/rules/blender-mcp.md`

## What the pipeline accepts today

The renderer is `gl_compatibility` on every platform, so Quest, PCVR, and flat share one look.

| Asset | How it gets its surface | What Blender supplies |
|---|---|---|
| Scenario GLBs (`assets/models/scenarios/**`) | `assets/shaders/world_surface.gdshader`, swapped in at import by `world_surface_import.gd`. Flat color, banded light, procedural grain | A material **name**, a Base Color, a roughness. The GLBs also carry trim-sheet UVs that nothing reads yet (see [Trim sheet on scenery](#trim-sheet-on-scenery)). No images |
| Mannequin (`assets/models/characters/dummy.glb`) | `characters/body_skin.gdshader`: one flat `albedo`, tinted per duelist by `body_color` (`ai/ai_archetype.gd`) | Nothing. The shader samples no texture |
| Outfit (`gunslinger.glb`, not instanced yet) | Painted albedo (`poncho_albedo.png`, 512 px) | UVs and an albedo image |
| Weapons and props (`weapons/`, `props/`) | `StandardMaterial3D` with a small atlas (revolver 128 px, coin 128 px, ace 96×136) or flat vertex-colored materials (cigarette) | UVs and an albedo atlas, or flat materials |

Two things follow from this:

- **Scenery is not painted.** The import script leaves any scenario material with a texture, vertex color, normal map, emission, or transparency as a `StandardMaterial3D` and warns, and the `load` autotest then fails. "Texturing" a building means choosing its colors and material names.
- **Painted textures belong to things held or worn:** guns, props, clothing.

## The look

From `.claude/skills/gunslinger-taste/` and `SHADERS.md`. Check a texture against these before exporting.

- **Two or three flat colors per subject.** Loud and saturated. At duel range a character is a silhouette and those colors; if the idea needs fine detail to read, move it into a big shape.
- **Pattern is the silhouette.** Checker, stripes, cowhide, houndstooth, at a scale that survives 20 m. No small prints.
- **Printed, not filmed.** Flat inks, hard edges, halftone if anything. No photo textures, no soft gradients, no painted dirt or wear passes.
- **No dust-brown as a character's main color.** Sand and wood are for the ground and the walls.
- **Do not paint light.** No baked AO, shadows, or highlights. The banded light (`toon_light.gdshaderinc`) does the shading and `TimeOfDay` moves the sun, so baked light would contradict it.
- **Visible texels.** Nearest sampling, low resolution, one texel density across an object.
- **Ornament goes on the tool.** The revolver sits 30 cm from the eye all game. Spend detail there, not on a wall.

## Steps: scenery (flat color)

1. In the `.blend`, give each face a material from the existing names. The name sets grain and sway in `world_surface_import.gd`:
   - Grain 0.2: `M_Sand`, `M_Dirt`, `M_Rock`, `M_Cap` (and their `Far` / `Dark` variants).
   - Grain 0.12: `M_Wood`, `M_Plank`, `M_Roof`, `M_Car`, `M_Floor`, `M_Bar`, `M_Trim`, `M_Masonry`, `M_Whitewash`.
   - Sway: `M_Yucca`, `M_Scrub`, `M_ScrubDry`, `M_Hay`.
   - Any other name: flat color, no grain. A new grained or swaying material needs a line in that script.
2. Set the color on the Principled BSDF Base Color and set roughness. Leave metallic at 0; the shader ignores it.
3. Add no image nodes, no vertex colors, no normal maps, no alpha. The `Trim sheet preview` node that `dev/scenery_uv.py` adds to a material is unhooked at export, so the GLB keeps its Base Color.
4. Reuse exact color values. Surfaces with the same color, name, and roughness share one material at import; a slightly different shade is a new material.
5. Export glTF 2.0 (`.glb`, Y-up) beside the `.blend`.
6. Reimport and test:
   ```powershell
   & "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
   & "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
   ```
7. Tune grain and bands in game with F3 **World** (`grain_strength_mult`, `grain_scale_mult`), not in Blender.

## Steps: painted assets (weapons, props, clothing)

1. **Pick the colors and the pattern first.** Write down the two or three flats. Squint at the mesh from 20 m in the viewport.
2. **Pick the resolution.** Match what exists: 128 px for something held, 512 px for a full garment. Go up only when texels look wrong at the distance the object is seen from.
3. **Unwrap.** Hard seams are fine at this style. Stack mirrored and repeated parts on the same UV island. Keep one texel density across the object, and leave 2 to 4 px between islands.
4. **Paint one albedo atlas.** One image and one material per object. Flat fills, hard edges.
5. **Set the Image Texture node to Closest.** It exports as a nearest sampler.
6. **Base Color only.** No normal, roughness, metallic, or emission maps. Compatibility has no reflections, so metal maps render dark.
7. **Bake procedural nodes to an image.** Noise, gradient, and other generated nodes do not export to glTF.
8. **Export glTF 2.0** with a power-of-two PNG.
9. **Check the import in Godot.** Use Lossless for small atlases; VRAM compression smears hard texel edges at 128 px. Keep mipmaps on for anything seen beyond arm's length, or it shimmers in a headset. The existing `.png.import` files are mixed on both settings.
10. **Look at it.** `dev/mesh_lab/mesh_lab.tscn`, then a `--flat` run, then a headset. Headless runs do not compile shaders or show a texture.
11. **Warm it up.** A mesh or material that first appears in combat must draw once at boot (`ImpactFeedback._spawn_draw_warmup`, `autoload/impact_feedback.gd`), or it hitches (BUG-010).

## Performance

- **Materials are draw calls.** One material per object; share materials between objects where the colors match.
- **Opaque only.** For holes or fringe use alpha scissor (cutout), never alpha blend. Blended surfaces near the eye are the costly case on Quest.
- **Small textures.** Nothing in the project is above 512 px. Treat that as the ceiling for a worn or held asset.
- **Coarse detail.** Fine high-contrast detail under nearest sampling shimmers when the head moves. The world grain fades out between 15 m and 45 m for that reason.
- **Power-of-two sizes**, so the ETC2 / ASTC import (`project.godot`) and mipmaps work.
- **Measure on the Quest.** Compare frame time before and after a batch of new assets. None of the current look has been timed in a headset yet (`RELEASE_TODOS.md`).

## Needs a decision before anyone builds it

None of these exist in code. Each is a feature, so ask first (`.claude/rules/feature-planning.md`).

- **Painted textures on scenery.** `world_surface.gdshader` has no `albedo_tex` and reads no `UV`. The scenario GLBs now carry trim-sheet UVs (`dev/scenery_uv.py`), but nothing samples them yet. The route, its decisions, and what remains are in [Trim sheet on scenery](#trim-sheet-on-scenery).
- **Textured duelists.** `body_skin.gdshader` draws one flat color, and `gunslinger.glb` is not instanced on the player, AI, or remote avatar.
- **Banded light on the gun and props.** They keep smooth `StandardMaterial3D` light. Matcap metal (`SHADERS.md` #9) is not queued.

## Trim sheet on scenery

**Status: `partial`. The UVs and a placeholder sheet exist; the game does not use them yet.** The scenario GLBs are exported with a UV map, so they import and look exactly as before. A scenario material that carries a texture still fails the `load` autotest until the code todo below is done.

A trim sheet is one small image made of horizontal strips (planks, shingles, beams). Every building maps its faces onto those strips, so the whole town shares one texture.

### What exists

- `dev/scenery_uv.py` gives every built object a UV map on a 512 px sheet at 64 px per metre.
- `assets/textures/trim_sheet.png` is a **placeholder**: one tinted, labelled strip per row with a texel grid, for judging density and placement. It is not the final art.
- Each scenario `.blend` shows that sheet on its materials in Material Preview.
- The 24 scenario GLBs are re-exported with UVs and no image. Names, materials, colors, bounds, and collision are unchanged.

### How it will work in game

1. One PNG lives in the Godot project: `assets/textures/trim_sheet.png`, 512×512.
2. The GLB carries the UVs only. The image is never embedded.
3. `world_surface_import.gd` already runs on every scenario GLB. It will give the sheet to the surfaces that use it, so nothing is assigned by hand in the Godot editor.
4. Repainting the PNG changes every building at once, with no re-export.

### Decisions

| # | Decision | Answer |
|---|---|---|
| 1 | Sheet embedded in each GLB, or one shared PNG | Shared PNG. **Recommended, not confirmed** |
| 2 | In game, texture multiplies the material's Base Color or replaces it | Multiply, so one grey wood strip serves every wood color. **Recommended, not confirmed**. Blender's preview is sheet-only (decision 11) |
| 3 | Procedural grain on textured surfaces | Off there. **Recommended, not confirmed** |
| 4 | Ground, rock, sand, and plants | Plants stay flat. Rock and ground get plain tiling UVs (decision 12). **Confirmed** |
| 5 | One sheet for every map, or one per map | One, split later if it fills up. **Recommended, not confirmed** |
| 6 | "No photo textures" in [The look](#the-look) | Would become "photo-sourced, cut to a fixed palette". **Not changed yet** |
| 7 | Texture fades to flat color at distance | No; mipmaps only. **Recommended, not confirmed** |
| 8 | How the importer picks surfaces | Not "has UVs": rock and ground now have tiling UVs too. Pick by material name, using the sets at the top of `dev/scenery_uv.py`. **Recommended** |
| 9 | Walls and roofs taller than a strip | Cut into bands. **Confirmed, built** |
| 10 | UVs by hand, or written by script | Written by script. **Confirmed, built** |
| 11 | Look of the sheet in Blender | Sheet only, so the image replaces the color. **Confirmed** |
| 12 | Rock and ground | Tiling UVs at one tile per 8 m, for a later tiling texture. **Confirmed** |
| 13 | Round parts | Unwrapped automatically. **Confirmed** |
| 14 | A hand fix survives a re-run | Yes, with the `uv_lock` custom property. **Confirmed** |

Sheet-only has a cost: one strip is one color, so wood, dark wood, and whitewash need a strip each on the real sheet. The placeholder shares one Siding strip between them.

### Code todo (before the sheet shows in game)

- [ ] `assets/shaders/world_surface.gdshader`: add an albedo texture uniform (nearest filter with mipmaps, repeat, default white) and multiply it into `ALBEDO` by `UV`.
- [ ] `assets/shaders/world_surface_import.gd`: give the sheet to sheet-role surfaces, add it to the material cache key, and set grain to 0 on them (decisions 3 and 8). `_unsupported()` rejects any texture today, so this must change with it.
- [ ] `dev/autotest.gd` (`_world_surface_ok`): check that a sheet-role surface carries the sheet.
- [ ] Import settings for `trim_sheet.png`: Lossless, mipmaps on.
- [ ] Paint the real sheet over the placeholder, keeping the strip rows below.
- [ ] Update "What the pipeline accepts today", `SHADERS.md`, `FEATURES.md`, and `CHANGELOG.md`.
- [ ] Time one textured map on a Quest 3 against the flat version.

### The automatic unwrap

Run it, then review in Blender:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_scenery_blender.py
```

Add `-- --map saloon` for one map (`main_street`, `saloon`, `train_rooftop`, `practice_hub`, `canyon`) or `-- --dry` to unwrap and check in memory without saving or exporting. Each `dev/build_<map>_blender.py` also runs the same pass before it saves, so a rebuild keeps the UVs.

It prints one line per map and any object that needs a look.

**What it does to each object**

| Object | Result |
|---|---|
| Collision proxy (`-convcolonly`) | Untouched |
| Plants, hay, the cow, bottles, candles, flames, glass, mirror, brass, cushions, ivory, lamp | Skipped: no UVs, flat color |
| Sand, dirt, rock, cap | Tiling UVs, one tile per 8 m |
| `M_Masonry` | Masonry |
| `M_Roof` | Shingles |
| `M_Window`, and `M_Iron` named `Win_*` | Glass |
| `M_Iron`, `M_Boiler` | Metal |
| `Cornice`, `Moulding` | Moulding |
| `M_Bar`, `M_BarTop`, `M_Floor`, `M_FloorAlt`, `M_Plank` | Boards |
| Wood-like (`M_Wood`, `M_WoodDark`, `M_Whitewash`, `M_Car`, `M_CarDark`, `M_Trim`) | By proportions: a stick (both smaller dimensions ≤ 0.4 m) is Beam; a slab (one dimension ≤ 0.4 m) is Boards when thin vertically, Siding otherwise; a block is Siding |
| Round part | Side wrapped around, caps flat. Diameter ≤ 0.35 m is Beam, larger is Boards (Metal for iron) |

**How a face is laid out.** Each face is projected along its dominant axis at 64 px per metre. The longer side runs along the strip. A face taller than its strip is cut into bands that stack on the strip; a face up to 30% too tall is squeezed instead. Glass and Blank are flat fills, so a face is scaled to fit and never cut. A round part's side keeps its length along the strip; when it is longer than the strip is tall it is turned and wrapped once around.

**What it leaves on each object**

- Custom property `uv_role`: the strip name, `tiling`, or `skip`.
- Custom property `uv_review`: the reason, set only when the object needs a look.
- One UV map named `UVMap`. Any other UV map is removed.

**Results** (visible objects, collision proxies excluded)

| Map | Objects | On the sheet | Tiling | Skipped | Band cuts | Triangles on unwrapped objects |
|---|---|---|---|---|---|---|
| Main Street | 787 | 130 | 3 | 654 | 228 | 1692 → 2500 |
| Saloon | 195 | 149 | 0 | 46 | 38 | 2024 → 2176 |
| Train Rooftop | 385 | 365 | 14 | 6 | 255 | 5972 → 6940 |
| Practice Hub | 191 | 69 | 10 | 112 | 12 | 1172 → 1220 |
| Canyon | 393 | 0 | 104 | 289 | 0 | unchanged |

Faces within 10% of 64 px per metre: Main Street 91%, Saloon 95%, Train Rooftop 83%, Practice Hub 59%. The rest are round parts by design: tapered fence posts, wheel caps scaled down onto Blank, axles wrapped once, and faces squeezed up to 30% onto a strip. No face leaves its strip.

**Flagged for a look**

- Main Street: `Spire` (slanted faces), `Tank` (wrapped once, texels ×0.10).
- Saloon: `Stair` (slanted), `StoveBody` (wrapped once, ×0.28).
- Train Rooftop: `Engine_Boiler`, `Engine_Smokebox`, `Engine_Stack` (wrapped once, ×0.09–0.36), `CarRearBLadder_RailL/R` (×2.27), `Engine_Pilot` (slanted).
- Practice Hub, Canyon: none.

**Keeping a hand fix.** Select the object, open the Properties editor's Object tab (orange square), and in Custom Properties click New. Click the gear icon, set Property Name to `uv_lock`, and set the value to `1`. A re-run skips that object. A full rebuild from a build script still creates the object again without your fix, so a map with locked objects should not be rebuilt.

**Checking.** After a run, `scenery_uv.check_scene()` confirms every sheet-role corner sits inside its strip's rows. The unwrap script runs it and fails the map if any corner is outside.

### What you see in Blender

Open a map's `.blend` from `assets/models/scenarios/<map>/`, hold `Z` in the 3D viewport, and choose **Material Preview**. Materials that have sheet-role objects show the sheet, Closest filtered, in place of their color. Their color is still stored on the material and returns for the export.

- Skipped objects that share one of those materials (the rail iron, for instance) have no UVs and sample the bottom-left corner, which is the Blank strip, so they look plain.
- Skipped objects with their own material, such as bottles and plants, keep their flat color.
- Rock and ground keep their flat color; their tiling UVs wait for a tiling texture.
- To see the UV layout, open the **UV Editing** workspace and select an object.

### The sheet

512×512 at 64 px per metre. One metre of wall shows 64 texels, and the full width of the sheet covers 8 m before it repeats. The table is `STRIP_ROWS` in `dev/scenery_uv.py`; changing it and re-running moves every object, except locked ones.

| Strip | Height | Covers | Pixel rows from top | UV height (V) | Use |
|---|---|---|---|---|---|
| Siding | 128 px | 2 m | 0–128 | 0.75–1.0 | Plank walls, doors, car bodies |
| Masonry | 128 px | 2 m | 128–256 | 0.5–0.75 | Stone and brick walls |
| Shingles | 64 px | 1 m | 256–320 | 0.375–0.5 | Roofs |
| Boards | 64 px | 1 m | 320–384 | 0.25–0.375 | Floors, decks, crates, table tops |
| Beam | 32 px | 0.5 m | 384–416 | 0.1875–0.25 | Posts, frames, rails, legs |
| Metal | 32 px | 0.5 m | 416–448 | 0.125–0.1875 | Iron, wheels, boiler |
| Glass | 32 px | 0.5 m | 448–480 | 0.0625–0.125 | Window panes |
| Moulding | 16 px | 0.25 m | 480–496 | 0.03125–0.0625 | Cornices, thin trim |
| Blank | 16 px | 0.25 m | 496–512 | 0–0.03125 | Faces that stay plain. Pure white |

Rules for the image:

- Every strip repeats left to right with no visible join. Siding and Masonry also repeat top to bottom, because walls stack several bands of them.
- No shadows or highlights in the image. Use albedo maps from Poly Haven or ambientCG (both CC0) before raw photos; they already have the lighting removed.
- The UVs sit exactly on a strip's border. If mipmaps bleed a neighbouring strip's color in the headset, keep a few edge rows of each strip a plain copy of its own color.

### Making the real sheet in Blender

The placeholder already has this layout. This replaces it with photo-sourced strips. The strip heights must stay as in the table above, or the UVs no longer land.

You build a flat scene of nine photo strips and take one straight-on picture of it.

1. **New scene.** File > New > General. Click the cube and press `X` > Delete. Do the same for the light.
2. **Flat color output.** In the Properties editor (the column of icon tabs at the right), open the Render tab (camera-back icon). Under Color Management set View Transform to **Standard**. The default would shift your colors.
3. **Image size.** Open the Output tab (printer icon). Set Resolution X and Y to 2048, and the percentage to 100. You work at four times the final size and shrink it at the end.
4. **Camera.** Click the camera. Press `N` in the 3D viewport to open the sidebar and pick the Item tab. Set Location to 0, 0, 10 and Rotation to 0, 0, 0. In the Properties editor open the Data tab (green camera icon), set Type to **Orthographic** and Orthographic Scale to 1. The camera now sees a 1 m square centred on the origin.
5. **One plane per strip.** Press `Shift+A` > Mesh > Plane. In the sidebar Item tab, set its Dimensions and Location from this table (X dimension is always 1, X and Z location always 0):

   | Strip | Dimensions Y | Location Y |
   |---|---|---|
   | Siding | 0.25 | 0.375 |
   | Masonry | 0.25 | 0.125 |
   | Shingles | 0.125 | -0.0625 |
   | Boards | 0.125 | -0.1875 |
   | Beam | 0.0625 | -0.28125 |
   | Metal | 0.0625 | -0.34375 |
   | Glass | 0.0625 | -0.40625 |
   | Moulding | 0.03125 | -0.453125 |
   | Blank | 0.03125 | -0.484375 |

6. **Give each plane its photo.** Switch to the **Shading** workspace (tabs along the top of the window). With a plane selected, click New in the node editor at the bottom. Then:
   1. Click the Principled BSDF node and press `X` to delete it.
   2. `Shift+A` > Shader > Emission. Drag from its Emission output to the Surface input of Material Output. Emission shows the image at full brightness with no lighting.
   3. `Shift+A` > Texture > Image Texture. Click Open on it and pick the photo. Drag its Color output to the Emission node's Color input.
   4. `Shift+A` > Vector > Mapping, and `Shift+A` > Input > Texture Coordinate. Connect Texture Coordinate **UV** to Mapping **Vector**, and Mapping **Vector** to Image Texture **Vector**.
   5. On the Mapping node set Scale X to 8 divided by the real width of the photo in metres, and Scale Y to the strip's height in metres divided by the real height of the photo. A photo of 2 m × 2 m of planks on the Siding strip is X 4, Y 1. Keep Scale X a whole number or the strip will not repeat cleanly.
   6. For the Blank strip skip the image and leave the Emission color white.
7. **Check and render.** Press `Numpad 0` to look through the camera; the nine strips should fill the frame with no gaps. Press `F12` to render. In the render window choose Image > Save As and save `trim_sheet_master.png`.
8. **Shrink it and cut the colors.** This step is what makes it read as printed, not filmed. With ImageMagick:
   ```
   magick trim_sheet_master.png -filter Box -resize 512x512 -dither None -colors 16 trim_sheet.png
   ```
   Or in GIMP: Image > Scale Image to 512×512, then Image > Mode > Indexed with 16 colors and dithering None, then Image > Mode > RGB, then export as PNG.
9. **Put it in the project.** Save `trim_sheet.png` to `assets/textures/`. Keep the master and the source photos in a folder that holds an empty file named `.gdignore`, so Godot does not import them.

### Fixing UVs by hand

Use this for the flagged objects, or anything the script put on the wrong strip. Lock the object afterwards (see above) so a re-run keeps your work.

#### Blender basics

- **A key acts on the editor under the mouse.** If a shortcut does nothing, move the mouse over the right panel and press it again.
- **Object Mode and Edit Mode.** `Tab` switches between them. Object Mode moves whole objects. Edit Mode changes one object's faces and its UVs.
- **Face select.** In Edit Mode press `3`. Click a face to select it, `Shift`+click to add more, `A` to select everything, `Alt+A` to select nothing.
- **UV map.** The flat layout that says which part of the image each face shows. The UV Editor shows it on top of the image.
- **Island.** A group of connected faces in the UV Editor. Hover one and press `L` to select the whole island.
- **Move, rotate, scale.** `G`, `R`, `S`. Press `X` or `Y` afterwards to lock to an axis, type a number for an exact amount, `Enter` to confirm, `Esc` to cancel. In the UV Editor, Y is up and down the image.
- **Undo.** `Ctrl+Z`. Save often with `Ctrl+S`.
- **Collision boxes.** Objects whose name ends in `-convcolonly` are invisible collision shapes drawn as wireframes. Leave them alone.

#### Seeing the sheet while you work

The script has already put the sheet on the materials. In the **UV Editing** workspace, the left half is the UV Editor and the right half is the 3D viewport.

1. In the UV Editor header, click the image dropdown and choose `trim_sheet.png`.
2. Open the UV menu > Snap to Pixels > **Corner**, so islands stop on whole texels.
3. In the 3D viewport, hold `Z` and choose **Material Preview**.


#### Unwrapping a box object

Almost every built object is a box. The script does this for you; these are the same steps by hand.

1. In Object Mode, click the object. To do several at once, `Shift`+click each one; all of them enter Edit Mode together.
2. Press `Tab`, then `3`, then `A`. Every face is selected.
3. Press `U` > **Cube Projection**. A small panel opens at the bottom left of the viewport. Set **Cube Size** to **8** and untick Clip to Bounds and Scale to Bounds. Cube Size 8 means 8 m of model fills the 512 px sheet, which is 64 px per metre.
4. The faces now appear in the UV Editor at the right size but in the wrong place. Move the mouse over the UV Editor.
5. Select the faces that belong on one strip. On a wall box those are the four side faces; they sit on top of each other, so press `A` if the whole object uses one strip, or hover an island and press `L`.
6. Press `G` then `Y` and move the mouse until the island's top and bottom edges sit exactly on the strip's borders. Zoom with the scroll wheel to check. Click to confirm.
7. The island may hang past the left or right edge of the image. That is correct: the strip repeats. It must never cross the top or bottom of its strip.
8. If the grain should run the other way (a vertical post on the Beam strip, a door on the Siding strip), press `R`, type `90`, `Enter` before step 6.
9. Faces you do not care about (the underside, the back against a wall): select them, press `S`, type `0.01`, `Enter`, then `G` and drop them on the Blank strip.
10. Press `Tab` to leave Edit Mode. Press `Ctrl+S`.

**When the face is taller than the strip.** A 4 m wall does not fit the 2 m Siding strip. Cut it into bands first:

1. In Edit Mode, hover a vertical edge of the wall and press `Ctrl+R`. A yellow line previews a cut around the box.
2. Scroll the mouse wheel to set the number of cuts. Bands = wall height ÷ strip height, and cuts = bands − 1. A 4 m wall on Siding is 2 bands, so 1 cut. Round to the nearest whole band for odd sizes.
3. Click once, then right-click so the cuts stay evenly spaced.
4. Redo the Cube Projection (steps 2–3 above).
5. In the 3D viewport, select only the faces of one band (`Alt`+click a face edge selects a ring around the box). Only those faces show in the UV Editor. If every face still shows, turn off the sync button (two arrows) at the top left of the UV Editor.
6. In the UV Editor press `A`, then `G` `Y` and place that band on the strip. Repeat for each band; they all stack on the same strip.
7. If a band is slightly shorter or taller than the strip, press `S` `Y` and stretch it to fit. Under 10% is not visible.

**Glass and Blank.** These strips are flat fills, so density does not matter. Scale the island down (`S`) until it fits inside the strip.

**Copying to identical objects.** For objects of the same size (the windows of one building, a row of posts): select the copies, `Shift`+click the finished one last, then Object menu > Link/Transfer Data > **Copy UV Maps**. The copies must have the same cuts as the finished one, so cut them all together first.

#### Unwrapping a round object

Barrels, round posts, the water tank, the boiler. Cube Projection smears these, so mark where the surface is cut open instead.

1. In Edit Mode press `2` for edge select.
2. `Alt`+click an edge on the top rim to select the whole rim. `Shift+Alt`+click the bottom rim. `Shift`+click one vertical edge on the side that faces away from the player.
3. Press `Ctrl+E` > **Mark Seam**. The edges turn red.
4. Press `3`, `A`, then `U` > **Unwrap**. The side becomes one rectangle and each cap becomes a disc.
5. The islands fill the whole image, so shrink them. Select the side rectangle with `L`, press `S`, and scale until its height in texels is the object's height in metres × 64. Then place it on its strip as for a box.
6. Scale the caps down and put them on the Boards or Blank strip.

#### Checking your work

- In Material Preview, texels should be the same size on every textured object, and square.
- A plank should not change width from one building to the next.
- Orbit around the object and look for a strip showing the edge of its neighbour. That is an island crossing a strip border.

### Exporting

The unwrap script exports for you. By hand, from a `.blend`:

1. In Object Mode, select what goes into the GLB. In the Outliner (top right list) right-click the piece's root object and choose **Select Hierarchy**.
2. Main Street only: each piece is parked 20 m apart along X so the file is browsable, and must be exported from the origin. Click the root, note Location X in the sidebar (`N` > Item), set it to 0, export, then put the number back. Train Rooftop does the same for the `horizon_ridge` children.
3. **Unhook the sheet first.** In each material's Shading node editor, drag the `Trim sheet preview` node's Color link off Base Color. With it linked the exporter writes the image into the GLB and the color is lost. The script does this for you.
4. File > Export > **glTF 2.0 (.glb/.gltf)**. In the panel on the right:
   - Format: **glTF Binary (.glb)**.
   - Include > Limit to: **Selected Objects**.
   - Transform: **+Y Up** ticked.
   - Data > Mesh: **Apply Modifiers** ticked, **UVs** ticked.
   - Data > Material > Images: **None**.
5. Save over the existing `.glb` beside the `.blend`. Do not rename it; the Godot scenes point at that file.
6. Reimport and run the test:
   ```powershell
   & "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
   & "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
   ```

### Review pass per map

The script did the unwrap. What is left is a look in Blender (Material Preview) and a fix for what is wrong. Strip choice follows proportions, so expect some objects on a strip you would not have picked.

#### Main Street

`assets/models/scenarios/main_street/main_street.blend`, 19 GLBs. Build script `dev/build_main_street_blender.py`.

- [ ] Open `bld_newspaper` first. It is the smallest building and has one of everything.
- [ ] Walls: planks run horizontally on tall walls and vertically on narrow ones, because the longer side runs along the strip.
- [ ] `Spire` and `Tank` (flagged).
- [ ] `Door`, `DoorFrame*`, `Win_*`, and `Cornice` on each building.
- [ ] Street kit that repeats the most: `env_boardwalk_4m`, `env_cattle_fence_4m`, `env_awning_post`, `env_rail_track_8m`.
- [ ] Left flat on purpose: plants, `prp_cow`.

#### Saloon

`assets/models/scenarios/saloon/saloon.blend`, `saloon_interior.glb`. Build script `dev/build_saloon_blender.py`. Seen from a few metres, so texel mistakes show most here.

- [ ] Four walls, wainscot, and ceiling: bands line up at the corners.
- [ ] The 16 floor planks run along their length on Boards.
- [ ] `Stair` (slanted) and `StoveBody` (flagged).
- [ ] Tables: the `TableTop_A/B` caps are squeezed to fit Boards.
- [ ] Left flat on purpose: bottles, candles, flames, glass panes, mirror, brass, cushions, piano keys.

#### Train Rooftop

`assets/models/scenarios/train_rooftop/train_rooftop.blend`, `train_rooftop.glb` and `horizon_ridge.glb`. Build script `dev/build_train_rooftop_blender.py`. The duel is on the car roofs, so check those first.

- [ ] `Car*_Roof` and `Car*_Lip*` on Shingles.
- [ ] `Engine_Boiler`, `Engine_Smokebox`, `Engine_Stack`, `Engine_Pilot`, `CarRearBLadder_Rail*` (flagged).
- [ ] The 161 wheels, axles, and couplers are on Metal, with wheel caps on Blank. They sit under the cars; lock any you fix.
- [ ] `horizon_ridge` and the `M_Cap`/`M_Rock` blocks have tiling UVs only.

#### Practice Hub

`assets/models/scenarios/practice_hub/practice_hub.blend`, `practice_hub.glb`. Build script `dev/build_practice_hub_blender.py`.

- [ ] Porch: wall, roof, deck, sign, posts.
- [ ] The 28 `FencePost*` are tapered, so their density is off by design.
- [ ] Target rails and crates.
- [ ] Left flat on purpose: plants, hay. `Lot`, `Desert`, `Berm`, and `Mesa*` carry tiling UVs.

#### Canyon

`assets/models/scenarios/canyon/canyon.blend`, `canyon.glb`. Build script `dev/build_canyon_blender.py`.

Nothing here is built from wood or iron: 102 rock blocks and two sand planes carry tiling UVs, and 289 plants are flat. The trim sheet does not apply. Texturing the rock means a separate tiling texture, which is not decided.

- [ ] Decide whether rock and ground get a tiling texture (decision 12 only prepared the UVs).
