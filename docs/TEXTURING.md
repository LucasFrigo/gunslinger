# Texturing

How to color and texture a mesh in Blender so it matches the look and runs on a Quest 3. Covers what the pipeline accepts today, the hand-painted texture per scenery GLB, the rules of the look, the steps per asset type, and the performance limits.

Shaders: [`SHADERS.md`](SHADERS.md) · Art direction: [`design/README.md`](design/README.md) · Blender setup: `.claude/rules/blender-mcp.md`

## What the pipeline accepts today

The renderer is `gl_compatibility` on every platform, so Quest, PCVR, and flat share one look.

| Asset | How it gets its surface | What Blender supplies |
|---|---|---|
| Scenario GLBs (`assets/models/scenarios/**`) | `assets/shaders/world_surface.gdshader`, swapped in at import by `world_surface_import.gd`. Flat color, banded light, and procedural grain; or, on a GLB that has its own hand-painted image, that image in place of the color (see [Hand-painted texture per GLB](#hand-painted-texture-per-glb)). The shared trim sheet is [paused](#trim-sheet-on-scenery-paused) | A material **name** (`M_Wood__bld_bank`: base name, then the GLB), a Base Color, a roughness, the per-GLB UVs from `dev/unwrap_per_glb_blender.py`, and optionally one 256×256 PNG per GLB in `tex/` |
| Mannequin (`assets/models/characters/dummy.glb`) | `characters/body_skin.gdshader`: one flat `albedo`, tinted per duelist by `body_color` (`ai/ai_archetype.gd`) | Nothing. The shader samples no texture |
| Outfit (`gunslinger.glb`, not instanced yet) | Painted albedo (`poncho_albedo.png`, 512 px) | UVs and an albedo image |
| Weapons and props (`weapons/`, `props/`) | `StandardMaterial3D` with a small atlas (revolver 128 px, coin 128 px, ace 96×136) or flat vertex-colored materials (cigarette) | UVs and an albedo atlas, or flat materials |

Two things follow from this:

- **Scenery is painted per GLB, not per object.** The import script accepts one albedo image on a scenario material (the GLB's own `tex/<glb>.png`, embedded by the export) and leaves any material with a vertex color, normal map, emission, or transparency as a `StandardMaterial3D` with a warning, which makes the `load` autotest fail. A GLB with no image is flat color: "texturing" it means choosing its colors and material names until you paint its image.
- **Painted textures belong to things held or worn:** guns, props, clothing.

## Hand-painted texture per GLB

**Status: `partial`. The unwrap, the materials, the image hookup, the export, and the importer are built and tested; no image has been painted, so every GLB is flat colour and grain in game.** This replaced the shared trim sheet ([paused](#trim-sheet-on-scenery-paused)): you texture one GLB at a time, by hand, and the rest stay flat until you get to them.

Each exported scenario GLB (29 of them) has **one 256×256 image**. Every mesh in that GLB samples it. You open the map's `.blend`, look at the GLB's unwrap, make an image for it (ripped textures arranged to fit the UV islands, or painted straight over the exported layout), save it under `tex/`, and run one command.

### Decisions

| Topic | Decision |
|---|---|
| Granularity | One image per exported GLB, shared by all its meshes |
| Resolution | 256×256 |
| UVs | Fresh non-overlapping 0-1 unwrap per GLB: every non-ground, non-collision mesh packed into one layout at one texel density, 2 px pad where it fits (see the table below for what it gave each GLB) |
| Which meshes | Every visible mesh, plants, hay, the cow, bottles, candles, flames, glass, mirror, brass, cushions, piano keys, and lamp included. Low detail is accepted |
| Ground and rock | Unchanged: `M_Sand`, `M_SandFar`, `M_Dirt`, `M_DirtFar`, `M_Rock`, `M_RockDark`, `M_Cap`, `M_CapDark` keep their 8 m tiling UVs, flat colour, and grain. They are not in any GLB's image |
| Collision proxies | Untouched (`-convcolonly`) |
| Hand work on a re-run | Every unwrapped object gets `uv_role = "glb"` and `uv_lock = 1`. `dev/unwrap_scenery_blender.py` skips locked objects, and `dev/unwrap_per_glb_blender.py` keeps the UVs of a GLB that already has them unless you pass `--relayout` |
| Image file | `assets/models/scenarios/<map>/tex/<glb>.png`, embedded in the GLB on export |
| No image yet | The GLB exports with no image: flat colour and grain exactly as before the sheet. Paint one GLB at a time |
| In game | A material with an image becomes `world_surface.gdshader` with the image as `albedo_tex` (`use_albedo_tex`): nearest filter with mipmaps, clamped, banded light, outline, and wind sway kept, grain off. The `load` autotest accepts it |
| Trim sheet | Off in game. The code and files stay; one switch (`USE_TRIM_SHEET` in `assets/shaders/world_surface_import.gd`, false) brings it back |

### The 29 GLBs

Each row is one image. The path is relative to `assets/models/scenarios/`. A GLB with nothing in its layout (all ground or rock) has no image to paint. The same list with mesh counts and a done box is in [`TEXTURE_LIST.md`](TEXTURE_LIST.md).

| Map `.blend` | GLB | PNG |
|---|---|---|
| `main_street/main_street.blend` | `bld_bank`, `bld_church`, `bld_depot`, `bld_general_store`, `bld_hotel`, `bld_jail`, `bld_newspaper`, `bld_saloon` | `main_street/tex/<glb>.png` |
| `main_street/main_street.blend` | `env_awning_post`, `env_boardwalk_4m`, `env_cattle_fence_4m`, `env_desert_scatter`, `env_rail_track_8m` | `main_street/tex/<glb>.png` |
| `main_street/main_street.blend` | `prp_barrels`, `prp_cow`, `prp_hitching_rail`, `prp_trough` | `main_street/tex/<glb>.png` |
| `main_street/main_street.blend` | `env_terrain` (all ground: nothing to paint) | none |
| `saloon/saloon.blend` | `saloon_bar` | `saloon/tex/saloon_bar.png` |
| `saloon/saloon.blend` | `saloon_shell` | `saloon/tex/saloon_shell.png` |
| `saloon/saloon.blend` | `saloon_table` (module, two copies share one image) | `saloon/tex/saloon_table.png` |
| `saloon/saloon.blend` | `saloon_chair` (module, eight copies share one image) | `saloon/tex/saloon_chair.png` |
| `saloon/saloon.blend` | `saloon_balcony` | `saloon/tex/saloon_balcony.png` |
| `saloon/saloon.blend` | `saloon_dressing` | `saloon/tex/saloon_dressing.png` |
| `saloon/saloon.blend` | `saloon_lamps` | `saloon/tex/saloon_lamps.png` |
| `train_rooftop/train_rooftop.blend` | `train_car_coach` (module, four copies share one image) | `train_rooftop/tex/train_car_coach.png` |
| `train_rooftop/train_rooftop.blend` | `train_coupler` (module, six copies share one image) | `train_rooftop/tex/train_coupler.png` |
| `train_rooftop/train_rooftop.blend` | `train_engine` (final) | `train_rooftop/tex/train_engine.png` |
| `train_rooftop/train_rooftop.blend` | `train_car_baggage` (final) | `train_rooftop/tex/train_car_baggage.png` |
| `train_rooftop/train_rooftop.blend` | `train_car_business` (final) | `train_rooftop/tex/train_car_business.png` |
| `train_rooftop/train_rooftop.blend` | `train_rooftop` (the guard walls only: nothing to paint) | none |
| `train_rooftop/train_rooftop.blend` | `horizon_ridge` (all rock: nothing to paint) | none |
| `practice_hub/practice_hub.blend` | `practice_hub` | `practice_hub/tex/practice_hub.png` |
| `canyon/canyon.blend` | `canyon` | `canyon/tex/canyon.png` |

### Your workflow

1. Open the map's `.blend` (for example `assets/models/scenarios/main_street/main_street.blend`). In the Outliner, right-click the GLB's root empty (`bld_bank`) and choose **Select Hierarchy**.
2. Switch to the **UV Editing** workspace. The left half shows the UV layout of the selected meshes: every mesh of the GLB sits in the same 0-1 square. Material Preview in the 3D viewport shows the flat colour until an image is linked.
3. Export the layout to paint over: UV menu > **Export UV Layout**. Set the size to **256×256** and save it somewhere outside `assets/` (a scratch folder), because it is only a guide.
4. Make the image. Either paint over the layout in GIMP or Krita, or arrange ripped textures (the [texture ripper](https://github.com/raycastly/texture-ripper) output) so each fits its island. Keep the islands where they are: the UVs are fixed. Keep important detail 2 px away from island edges.
5. Save it as **`assets/models/scenarios/<map>/tex/<glb>.png`**, 256×256, for example `main_street/tex/bld_bank.png`. Do not add it from the Godot editor: the folder holds a `.gdignore` on purpose (below).
6. Link it and re-export that GLB. This reopens the `.blend`, hooks the PNG to the GLB's materials, saves the `.blend`, and writes the GLB with the image embedded:
   ```powershell
   & "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --link --glb bld_bank
   ```
   Close the `.blend` in the Blender window first (or save and reopen it afterwards): saving from the window would overwrite what the script wrote.
7. Reimport and look: `godot --headless --path . --import` (or the editor on focus), then a `--flat` run of the map or `dev/mesh_lab/mesh_lab.tscn`.
8. Tick the box in [`TEXTURE_LIST.md`](TEXTURE_LIST.md).

To see it in Blender first, open the `.blend` after step 6: the GLB's materials show the PNG in Material Preview (Closest filter). Repainting later: save over `tex/<glb>.png` and run step 6 again.

### The script

`dev/unwrap_per_glb_blender.py` (Blender 5.1, `-b`). One run with no options does everything and is safe to repeat.

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_per_glb_blender.py
```

| Option | Does |
|---|---|
| `--map <name>` | One map: `main_street`, `saloon`, `train_rooftop`, `practice_hub`, `canyon` |
| `--glb <name>` | One GLB root, for example `bld_bank` |
| `--link` | No unwrap and no material pass: only link the PNG (or unlink it when it is gone), save the `.blend`, and re-export |
| `--dry` | Compute and print the stats; save and export nothing |
| `--relayout` | Throw away the existing per-GLB UVs and unwrap again. **Loses hand work, and any image painted to fit the old layout no longer fits** |
| `--rotate` | Let the packer turn islands 90 degrees. Denser, but islands may sit sideways |

For each GLB root it:

1. **Materials.** Gives the GLB its own copy of every non-ground material it uses, named `<base>__<glb>` (`M_Wood__bld_bank`). Materials are shared across GLBs in the `.blend`, but each GLB has its own image, so each needs its own. The importer strips `__<glb>` before looking up grain, sway, and tiling, so `M_Wood__bld_bank` still behaves as `M_Wood`.
2. **Unwrap.** For every non-ground, non-collision mesh: a round part (two caps and quads between) is unrolled into one side rectangle plus flat caps; every other mesh is cut into islands by growing a region of faces whose normals stay within 66 degrees of the first, and each island is projected flat in metres with the up direction up. Then every island of the GLB is packed into one 256×256 square at the largest single scale that fits: one texel density across the whole GLB, with a pad of 2 px on every side where the density allows it (a pad costing more than a quarter of the density is cut to 1 px, then none). It sets `uv_role = "glb"` and `uv_lock = 1`, and leaves one UV map named `UVMap`. Ground and rock keep their tiling UVs.
3. **Image.** Adds one Image Texture node (Closest, extension Extend) named `GlbTexture` to each of those materials. If `tex/<glb>.png` exists it is linked to Base Color; if not, the node stays unlinked and the material keeps its Base Color. The old `Trim sheet preview` node is removed.
4. **Export.** Saves the `.blend` and writes `<glb>.glb` beside it (Main Street pieces and `horizon_ridge` are moved to the origin for the export and put back). The image is embedded when one is linked, and the file holds no image otherwise.

It prints one line per GLB: mesh count, island count, texel density at 256 px, pad, how much of the square is covered, and any mesh whose share of the image is under 16 px² (too small to paint).

### What the unwrap gave each GLB

Texel density is pixels per metre at 256 px. It is set by the GLB's total surface area (every face counts, undersides and hidden faces included) and by its longest single island: an 8 m rail cannot be more than 256 px long, and a long thin piece is not cut.

| GLB | Meshes | Islands | px/m | Pad | Covered | Meshes under 16 px² |
|---|---|---|---|---|---|---|
| `bld_bank` | 5 | 170 | 7.9 | 2 | 66% | 0 |
| `bld_church` | 5 | 141 | 7.7 | 2 | 72% | 0 |
| `bld_depot` | 6 | 393 | 4.6 | 1 | 61% | 0 |
| `bld_general_store` | 6 | 164 | 9.5 | 2 | 62% | 0 |
| `bld_hotel` | 5 | 352 | 6.7 | 2 | 47% | 0 |
| `bld_jail` | 5 | 108 | 18.6 | 2 | 77% | 0 |
| `bld_newspaper` | 7 | 111 | 13.6 | 2 | 62% | 0 |
| `bld_saloon` | 7 | 167 | 10.2 | 2 | 61% | 0 |
| `env_awning_post` | 2 | 39 | 66.6 | 2 | 68% | 0 |
| `env_boardwalk_4m` | 2 | 63 | 46.0 | 2 | 53% | 0 |
| `env_cattle_fence_4m` | 1 | 42 | 45.5 | 2 | 46% | 0 |
| `env_desert_scatter` | 278 | 3426 | 8.0 | 0 | 77% | 8 |
| `env_rail_track_8m` | 2 | 46 | 31.5 | 2 | 19% | 0 |
| `prp_barrels` | 2 | 41 | 75.8 | 2 | 70% | 0 |
| `prp_cow` | 2 | 71 | 70.7 | 2 | 69% | 0 |
| `prp_hitching_rail` | 1 | 18 | 96.9 | 2 | 43% | 0 |
| `prp_trough` | 3 | 38 | 80.4 | 2 | 67% | 0 |
| `saloon_bar` | 6 | 659 | 20.0 | 1 | 53% | 0 |
| `saloon_shell` | 6 | 663 | 6.4 | 1 | 61% | 1 |
| `saloon_table` | 4 | 68 | 95.1 | 2 | 77% | 0 |
| `saloon_chair` | 1 | 39 | 171.0 | 2 | 56% | 0 |
| `saloon_balcony` | 3 | 331 | 16.8 | 1 | 62% | 0 |
| `saloon_dressing` | 7 | 389 | 40.9 | 1 | 66% | 0 |
| `saloon_lamps` | 4 | 325 | 71.1 | 1 | 70% | 0 |
| `train_car_coach` | 5 | 545 | 12.5 | 1 | 60% | 0 |
| `train_coupler` | 1 | 35 | 141.2 | 2 | 63% | 0 |
| `train_engine` | 8 | 573 | 10.5 | 1 | 58% | 0 |
| `train_car_baggage` | 5 | 426 | 13.3 | 1 | 61% | 0 |
| `train_car_business` | 7 | 567 | 11.9 | 1 | 58% | 0 |
| `train_rooftop` | 0 | 0 | | | | guard walls only |
| `practice_hub` | 181 | 858 | 7.4 | 1 | 41% | 3 |
| `canyon` | 25 | 1091 | 13.7 | 0 | 86% | 0 |
| `env_terrain`, `horizon_ridge` | 0 | 0 | | | | all ground or rock |

The train is split into one GLB per asset (`docs/design/scenarios/train_rooftop.md` H). The final coach module gets 12.5 px/m for all four copies: its walk top is one island and each side wall one island between its window holes; wheels, vents, and railing bars are flat colour. The coupler module gets 141.2 px/m. The final engine gets 10.5 px/m: its tender walk top is one island, and its wheels, logs, rods, and small brass are flat colour. The final baggage car gets 13.3 px/m and the final business car 11.9 px/m: each walk top is one island, each baggage door leaf one island, and their wheels, balusters, lamp caps, and jacks are flat colour; the greybox ladder's TINY rungs are gone with it. The Saloon's greybox GLB, `saloon_interior`, is retired: its last pieces, the chandelier, became `saloon_lamps` (71.1 px/m; its six shades, fonts, and flames and the chain links are flat colour). `saloon_balcony` gets 16.8 px/m: its 13.4 m fascia and deck are single islands, and its 48 balusters are flat colour. `saloon_dressing` gets 40.9 px/m; its shards, splinters, checks, and cards are flat colour. The two modules are the opposite case: one table gets 95 px/m and one chair 171 px/m, painted once for every copy. `saloon_shell` gets 6.4 px/m, under the sheet's estimate of 8 (G2): the floor (13.4 × 17.4 m) and each wall are one island, and the ceiling bays are next largest, so a 4.2 m wall gets about 27 px of height; its one TINY mesh is `Shell_Iron` (the hasp and the hatch ring), left flat. Painting those GLBs well means a few large flat colours per surface, not fine detail. If a GLB needs more, the lever is a bigger image or splitting the GLB, not a smaller pad; neither is decided.

### Keeping your work (`uv_lock`)

- Every object the script unwraps carries `uv_lock = 1` and `uv_role = "glb"`. `dev/unwrap_scenery_blender.py` (the strip unwrap) skips locked objects, so it cannot overwrite them.
- Running `dev/unwrap_per_glb_blender.py` again leaves a GLB alone if its meshes already have `uv_role = "glb"`; a GLB that is only partly done prints a warning and is left alone too. `--relayout` is the only way to redo it, and an image painted for the old layout will no longer fit.
- A full rebuild with a `dev/build_<map>_blender.py` script creates the objects again without your UVs, materials, image links, or locks, and runs the old strip unwrap. A map with hand-painted GLBs should not be rebuilt. If you must, re-run `dev/unwrap_per_glb_blender.py --map <name> --relayout` afterwards and repaint.

### How it gets into the game

1. The GLB embeds `tex/<glb>.png` as its base-colour texture and Godot imports it inside the GLB's scene. Two settings keep that to exactly one imported copy: every scenario `.glb.import` sets `gltf/embedded_image_handling=3` (embed uncompressed; Godot's default, 1, would extract a duplicate `<glb>_<name>.png` plus a `.import` beside the GLB), and each `tex/` folder holds an empty `.gdignore`, so Godot does not also import the source PNG as a separate texture. The PNG therefore does not show in the Godot FileSystem dock. Checked with a throwaway 256×256 image on `prp_trough`: it arrived as a 256×256 `ImageTexture` inside the scene and no extra file appeared.
2. `world_surface_import.gd` swaps each material for `world_surface.gdshader`. A material whose glTF base colour has an image sets `use_albedo_tex` and `albedo_tex` (the image copied into an `ImageTexture` with a mip chain); grain is off and sway is kept. A material with no image is the flat colour and grain it always was.
3. `world_surface.gdshader` reads `albedo_tex` by `UV`: nearest filter with mipmaps and `repeat_disable`, so an island at the edge never reads the opposite side. The banded light and the outline still apply.

Reimport after re-exporting a GLB. Changing `world_surface_import.gd` does not trigger one: Godot keys the import on the GLB's content and `.import`, so delete that GLB's files under `.godot/imported/` (`<name>.glb-*`) and run `--import` again.

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

1. In the `.blend`, give each face a material from the existing names. The name (without its `__<glb>` suffix) sets grain and sway in `world_surface_import.gd`:
   - Grain 0.2: `M_Sand`, `M_Dirt`, `M_Rock`, `M_Cap` (and their `Far` / `Dark` variants).
   - Grain 0.12: `M_Wood`, `M_Plank`, `M_Roof`, `M_Car`, `M_Floor`, `M_Bar`, `M_Trim`, `M_Masonry`, `M_Whitewash`.
   - Sway: `M_Yucca`, `M_Scrub`, `M_ScrubDry`, `M_Hay`.
   - Self-lit (`SELF_LIT`): `M_Flame`, `M_LampGlass`. Drawn exactly their color (or their painted texels), ignoring light, with no grain; a mesh whose surfaces are all self-lit casts no shadow, so give a glowing material its own mesh. Nothing else may use these names.
   - Any other name: flat color, no grain. A new grained, swaying, or self-lit material needs a line in that script.
2. Set the color on the Principled BSDF Base Color and set roughness. Leave metallic at 0; the shader ignores it.
3. Add no vertex colors, no normal maps, no alpha. The one image a GLB may have is the `GlbTexture` node that `dev/unwrap_per_glb_blender.py` adds and links (see [Hand-painted texture per GLB](#hand-painted-texture-per-glb)); leave it unlinked for a flat GLB. A material copy is named `<base>__<glb>`; keep the base name.
4. Reuse exact color values. Surfaces with the same color, name, and roughness share one material at import; a slightly different shade is a new material.
5. Export glTF 2.0 (`.glb`, Y-up) beside the `.blend`.
6. Reimport and test:
   ```powershell
   & "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
   & "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=load
   ```
7. Tune grain and bands in game with F3 **World** (`grain_strength_mult`, `grain_scale_mult`), not in Blender. `sheet_mix` has no effect while the trim sheet is paused.

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
- **Small textures.** Nothing in the project is above 512 px. Treat that as the ceiling for a worn or held asset. Scenery has 25 images of 256×256, one per paintable GLB (up to about 6.2 MB uncompressed with mipmaps, less if Godot compresses them; not timed or measured on a Quest yet). The paused trim sheet was 512×1024.
- **Coarse detail.** Fine high-contrast detail under nearest sampling shimmers when the head moves. The world grain fades out between 15 m and 45 m for that reason.
- **Power-of-two sizes**, so the ETC2 / ASTC import (`project.godot`) and mipmaps work.
- **Measure on the Quest.** Compare frame time before and after a batch of new assets. None of the current look has been timed in a headset yet (`RELEASE_TODOS.md`).

## Needs a decision before anyone builds it

None of these exist in code. Each is a feature, so ask first (`.claude/rules/feature-planning.md`).

- **Photo textures on scenery.** The route is now a hand-painted image per GLB ([Hand-painted texture per GLB](#hand-painted-texture-per-glb)), and no image exists yet. The "no photo textures" rule in [The look](#the-look) is not changed: it waits for a look test on one painted GLB. The paused trim-sheet route is in [Trim sheet on scenery](#trim-sheet-on-scenery-paused).
- **Textured duelists.** `body_skin.gdshader` draws one flat color, and `gunslinger.glb` is not instanced on the player, AI, or remote avatar.
- **Banded light on the gun and props.** They keep smooth `StandardMaterial3D` light. Matcap metal (`SHADERS.md` #9) is not queued.

## Trim sheet on scenery (paused)

**Paused: kept, not used in game.** Everything from here to the end of the file describes the shared-sheet route: strip and cell UVs, `trim_sheet.png`, the sheet builder, and the review passes. The user chose a hand-painted image per GLB instead ([above](#hand-painted-texture-per-glb)), which replaced the strip UVs, so `world_surface_import.gd` no longer assigns the sheet (`USE_TRIM_SHEET` is false), the shader's `use_sheet` path is idle, and F3 **World** `sheet_mix` does nothing. The GLBs now carry per-GLB UVs and the strip unwrap would skip them (locked). Turning the sheet back on means rebuilding the strip UVs on the objects you want, deleting their `uv_lock`, and setting the switch. The `Exporting` steps below ("Images: None") are for GLBs with no hand-painted image; use `dev/unwrap_per_glb_blender.py` to export a painted one.

**Status when paused: `partial`. The sheet builder and the cell UVs are built and the atlas is 512×1024, but no photo has been added yet, so the strips and cells in game are still a neutral placeholder; F3 **World** `sheet_mix` blends the sheet over the flat color (1 is the sheet, 0 the old look). What remains is art and testing: the photos, the texture-ripper trial, the look test, and Quest timing.** The scenario GLBs are exported with a UV map and no image; `world_surface_import.gd` hands the sheet to the surfaces that use it.

Scenery uses one atlas image with two kinds of texture on it:

| Kind | Used for | Made from | Status |
|---|---|---|---|
| **Strips** | Big surfaces that repeat: walls, roofs, floors, boardwalk, fences, beams, iron | Seamless photo or painted strips, one per row | UVs and builder built; art is a placeholder |
| **Cells** | One-off objects that fit one square: doors, windows, signs, barrels, crates, a trough, table tops | A photo of the real thing, flattened with the texture ripper and squashed to 128×128 | UVs and builder built; no photo yet |

A building uses both: strip siding on the walls, and a ripped door, window, and sign on its front. If a cell has not been made yet (no `cells/<name>.png`), the object keeps using its strip, so cells can be added one at a time.

Strips and cells are not interchangeable. A strip tiles because the UVs run past the image edge and wrap. A cell sits beside other cells, so it cannot tile; stretching one 128 px cell over a 9 m wall would be about 14 px per metre. That is why big surfaces stay on strips.

### What exists

- `dev/scenery_uv.py` gives every built object a UV map on the 512×1024 sheet at 64 px per metre: a strip, a photo cell when the object matches a cell that has an image, or tiling UVs. The layout tables (`STRIP_ROWS`, `CELLS`, the name rules) are in `dev/trim_layout.py`, plain Python that `dev/build_trim_sheet.py` shares.
- `dev/build_trim_sheet.py` builds `assets/textures/trim_sheet.png` and `assets/texture_src/cells_manifest.json` from `assets/texture_src/strips/` and `cells/`. With no photos it paints every strip and cell a plain tint (17 colors), which is the sheet in the repo today. Details in [Making the real sheet](#making-the-real-sheet).
- `assets/textures/trim_sheet.png` is a **placeholder** built from no photos: one flat color per strip and cell, pulled toward the town's palette, with a faint line every metre on the strips (the Blank strip is one flat color), no labels. `ensure_sheet(force=True, neutral=False)` in `dev/scenery_uv.py` writes the labelled debug sheet with a texel grid and the cell names instead. It is not the final art.
- In game, `world_surface.gdshader` reads the sheet by `UV` (nearest filter, mipmaps, repeat). The importer sets `use_sheet` on a surface when its mesh has UVs and its material is not tiling ground or rock (`TILING` in `assets/shaders/world_surface_import.gd`, kept in step with `TILING_MATERIALS` in `dev/scenery_uv.py`). Import settings: Lossless, mipmaps on, no VRAM compression.
- Each scenario `.blend` shows that sheet on its materials in Material Preview.
- The 24 scenario GLBs are re-exported with UVs and no image. Names, materials, colors, bounds, and collision are unchanged; moving to the 1024-tall atlas only halved every sheet V (checked against the previous GLBs: 713 UV sets remapped exactly, 131 tiling sets unchanged, and every position, normal, index, and node transform identical).

### How it works in game

1. One PNG lives in the Godot project: `assets/textures/trim_sheet.png`.
2. The GLB carries the UVs only. The image is never embedded.
3. `world_surface_import.gd` runs on every scenario GLB and gives the sheet to the surfaces that use it, so nothing is assigned by hand in the Godot editor. Reimport the GLBs after changing it; the script changing does not trigger one.
4. Repainting the PNG changes every building at once, with no re-export, as long as the strip and cell rectangles stay where they are.

### Where the textures come from

```
photos → texture ripper → one PNG per cell ─┐
photos → seamless strip PNGs ───────────────┼→ sheet builder → trim_sheet.png → Blender → GLB → game
                                            ┘   (shrink, cut colors, place)
```

- **Texture ripper:** [raycastly/texture-ripper](https://github.com/raycastly/texture-ripper), a browser app and a rework of the older Shoebox Texture Ripper. You draw four corners over a door, window, or wall in an angled photo, and it extracts a flat, perspective-corrected rectangle. It runs from GitHub Pages with no install.
- **Sheet builder:** `dev/build_trim_sheet.py`. It reads the folder of strips and cells, shrinks and color-cuts them together, and writes `trim_sheet.png` and a manifest of which cells exist. You never place a tile by hand.

#### About 128×128

Not every PS1 texture was 128×128. The hardware allowed anything up to 256×256 per texture, and games mixed 32, 64, 128, and 256 depending on memory. 128 is a common choice, and it suits this project: 128 px is exactly 2 m at 64 px per metre, and a 512 px-wide sheet holds four of them across. A door that is not square is squashed into the square cell and stretched back by its UVs, which is what PS1 games did.

### Decisions

| # | Decision | Answer |
|---|---|---|
| 1 | Sheet embedded in each GLB, or one shared PNG | **Shared PNG. Confirmed, built.** One `assets/textures/trim_sheet.png`, assigned by the importer; the GLBs embed no image |
| 2 | In game, texture multiplies the material's Base Color or replaces it | **Replace. Confirmed, built.** The sheet is the albedo on sheet surfaces; Base Color stays on the material as the `sheet_mix = 0` fallback (`mix(albedo, sheet, sheet_mix)`). Matches Blender's preview (decision 11) |
| 3 | Procedural grain on textured surfaces | **Off. Confirmed, built.** The shader scales grain by `1 - sheet_mix` on sheet surfaces, so it is gone at 1 and back at 0 |
| 4 | Ground, rock, sand, and plants | Plants stay flat. Rock and ground get plain tiling UVs (decision 12). **Confirmed** |
| 5 | One sheet for every map, or one per map | **One for every map. Confirmed, built.** Split later if it fills up |
| 6 | "No photo textures" in [The look](#the-look) | Photo-sourced, cut to a fixed palette, if the test looks right. **Not changed yet**: test one door, one window, and one wall first |
| 7 | Texture fades to flat color at distance | **No; mipmaps only. Confirmed, built.** The builder repeats each cell's outer 4 px and each strip's top and bottom 4 rows, so far mips do not bleed a neighbour |
| 8 | How the importer picks surfaces | **Confirmed, built.** The mesh surface has UVs **and** its material name is not a tiling material (`TILING`; rock and ground carry tiling UVs too). No glTF extras, no GLB re-export |
| 9 | Walls and roofs taller than a strip | Cut into bands. **Confirmed, built** |
| 10 | UVs by hand, or written by script | Written by script. **Confirmed, built** |
| 11 | Look of the sheet in Blender | Sheet only, so the image replaces the color. **Confirmed** |
| 12 | Rock and ground | Tiling UVs at one tile per 8 m, for a later tiling texture. **Confirmed** |
| 13 | Round parts | Unwrapped automatically. **Confirmed** |
| 14 | A hand fix survives a re-run | Yes, with the `uv_lock` custom property. **Confirmed** |
| 15 | Big repeating surfaces versus one-off objects | Strips for the big, cells for the one-off. **Confirmed** |
| 16 | Source of cell art | Photos flattened in the texture ripper. **Confirmed**. Whether it exports single tiles instead of one packed atlas is untested |
| 17 | Cell size | 128×128, non-square objects squashed. **Confirmed** |
| 18 | Atlas size | **512×1024: strips in the top 512 rows, 16 cells in the bottom 512. Confirmed, built** (`dev/trim_layout.py`). Raises the 512 px ceiling in [Performance](#performance) for scenery |
| 19 | How a cell is matched to objects | **By cell name. Confirmed, built.** `door.png` serves every object the script treats as a door (`cell_for_name` in `dev/trim_layout.py`); `bld_<building>_<cell>.png` overrides it for one building, taking one of the 2 spare slots in filename order. A third override fails the build and names the files |
| 20 | Making a repeating strip seamless | **You supply seamless strips; the builder does not fake seams. Confirmed, built** |
| 21 | Color cut | **One shared palette of 32 colors for the whole assembled sheet. Confirmed, built.** Pillow median cut, no dither; a sheet that already has 32 colors or fewer is left exact |
| 22 | A cell that has no image yet | **The object keeps its strip layout. Confirmed, built.** The builder paints the cell a plain tint and writes `assets/texture_src/cells_manifest.json`; the unwrap reads it |

Replace has a cost: one strip is one color, so wood, dark wood, whitewash, and car bodies share the Siding color in game at `sheet_mix = 1`, and the town goes more uniform. They need a strip each on the real sheet. `sheet_mix = 0` restores the old look exactly, grain included.

### Code todo

**A. The sheet shows in game** (the strips alone; done, apart from the Quest timing)

- [x] `assets/shaders/world_surface.gdshader`: `sheet_tex` (nearest filter with mipmaps, repeat, default white), `use_sheet`, and the global `sheet_mix`; the sheet replaces the color and scales grain by `1 - sheet_mix`.
- [x] `assets/shaders/world_surface_import.gd`: give the sheet to sheet-role surfaces and add it to the material cache key (decisions 3 and 8). `_unsupported()` needed no change: the GLBs embed no image, so it never sees one.
- [x] `dev/autotest.gd` (`_world_surface_ok`): a surface uses the sheet exactly when its mesh has UVs and its material is not tiling; the count is floored. The globals test covers `sheet_mix`.
- [x] Import settings for `trim_sheet.png`: Lossless, mipmaps on, `detect_3d/compress_to=0` so the first 3D use does not switch it to VRAM compression.
- [x] F3 **World** `sheet_mix` (0..1, default 1), persisted with `GameManager.tuning`.
- [x] Update "What the pipeline accepts today", `SHADERS.md`, `FEATURES.md`, and `CHANGELOG.md`.
- [ ] Time Main Street and the Saloon on a Quest 3 with `sheet_mix` 0 against 1 (`RELEASE_TODOS.md`).

**B. Cells and the sheet builder** (code done; the art and the look test remain)

- [x] `assets/texture_src/` with an empty `.gdignore`, `strips/`, `cells/`, and a `SOURCES.md` that records where every photo came from.
- [x] `dev/build_trim_sheet.py` (new): shrink each strip to 512 px wide and each cell to 128×128 with a box filter, cut all of them to one shared palette, pad each cell's border, place everything on the 512×1024 atlas, and paint a plain tint for any file that is missing. It also writes which cells exist, so the unwrap knows what to fall back from.
- [x] `dev/scenery_uv.py`: move to a 512×1024 atlas (every strip's V halves and moves up, so the whole unwrap re-runs); add a `CELLS` table with the grid positions; add rules from object names to cells; look for a per-building override; fall back to the strip when a cell is absent; write `uv_role` as `cell:<name>`; extend `check_scene()` to cell rectangles; and make the placeholder generator draw cells.
- [x] Re-run `dev/unwrap_scenery_blender.py` and compare the 24 GLBs against the old ones as before (same names, materials, colors, positions, and collision; only UVs differ). The five build scripts were not re-run: they would create the same objects and the same UVs again.
- [ ] Try the texture ripper on one real photo and record in this file what it exports.
- [ ] A look test: one door, one window, and one wall on the saloon and the bank, before deciding on photo textures everywhere (decision 6).
- [x] Update `SHADERS.md`, `FEATURES.md`, `RELEASE_TODOS.md` (photo licenses, Quest timing), and `CHANGELOG.md`.


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
| Round part (two round caps and quads between; a band-cut box with long caps is not one) | Side wrapped around, caps flat. Diameter ≤ 0.35 m is Beam, larger is Boards (Metal for iron) |
| Any of the above whose name matches a cell that has an image | That cell, see [How a cell is laid out](#how-a-cell-is-laid-out) |

**How a face is laid out.** Each face is projected along its dominant axis at 64 px per metre. The longer side runs along the strip. A face taller than its strip is cut into bands that stack on the strip; a face up to 30% too tall is squeezed instead. Glass and Blank are flat fills, so a face is scaled to fit and never cut. A round part's side keeps its length along the strip; when it is longer than the strip is tall it is turned and wrapped once around.

**What it leaves on each object**

- Custom property `uv_role`: the strip name, `cell:<name>`, `tiling`, or `skip`.
- Custom property `uv_cell`: the cell's slot (0 to 15), cell objects only. A building with an override gets slot 14 or 15.
- Custom property `uv_review`: the reason, set only when the object needs a look.
- One UV map named `UVMap`. Any other UV map is removed.

**Results** (visible objects, collision proxies excluded)

| Map | Objects | On the sheet | Tiling | Skipped | Band cuts | Triangles on unwrapped objects |
|---|---|---|---|---|---|---|
| Main Street | 787 | 130 | 3 | 654 | 228 | 1692 → 2500 |
| Saloon | 195 | 149 | 0 | 46 | 38 | 2024 → 2176 |
| Train Rooftop | 385 | 365 | 14 | 6 | 255 | 5972 → 6940 |
| Practice Hub | 191 | 69 | 10 | 112 | 12 | 1172 → 1220 |
| Canyon | 41 | 0 | 16 | 25 | 0 | unchanged |

Faces within 10% of 64 px per metre: Main Street 91%, Saloon 95%, Train Rooftop 83%, Practice Hub 59%. The rest are round parts by design: tapered fence posts, wheel caps scaled down onto Blank, axles wrapped once, and faces squeezed up to 30% onto a strip. No face leaves its strip.

**Flagged for a look**

- Main Street: `Spire` (slanted faces), `Tank` (wrapped once, texels ×0.10).
- Saloon: `Stair` (slanted), `StoveBody` (wrapped once, ×0.28).
- Train Rooftop: `Engine_Boiler`, `Engine_Smokebox`, `Engine_Stack` (wrapped once, ×0.09–0.36), `CarRearBLadder_RailL/R` (×2.27), `Engine_Pilot` (slanted).
- Practice Hub, Canyon: none.

**Keeping a hand fix.** Select the object, open the Properties editor's Object tab (orange square), and in Custom Properties click New. Click the gear icon, set Property Name to `uv_lock`, and set the value to `1`. A re-run skips that object. A full rebuild from a build script still creates the object again without your fix, so a map with locked objects should not be rebuilt.

**Checking.** After a run, `scenery_uv.check_scene()` confirms every sheet-role corner sits inside its strip's rows, or inside its cell's 128 px rectangle. The unwrap script runs it and fails the map if any corner is outside.

### How a cell is laid out

Built in `dev/scenery_uv.py`; tables and name rules in `dev/trim_layout.py`.

- **Which objects.** `cell_for_name`, on the Blender name without its `.001` suffix: `Door` to `door`, `DoorL`/`DoorR` to `door_swing`, `Win_*` to `window`, `Sign` to `sign_saloon`, `PorchSign` to `sign_porch`, `Barrel*` to `barrel`, `CrateA`/`CrateB` to `crate`, `Trough` to `trough`, `Tank` to `tank`, `TableTop_*` to `tabletop`. Door frames, jambs, braces, `Counter`, `CounterTop`, and the train's `*_Win*` panes match nothing and keep their strip. `window_barred`, `sign_blank`, `poster`, and `counter_front` have no rule yet.
- **The picture.** The builder squashes a source to 120×120 and repeats its outer pixels 4 px outward to fill the 128 px cell, so the picture is the inner rectangle (`CELL_PAD` in `dev/trim_layout.py`). UVs stay inside it; the pad only protects mipmaps and filtering.
- **A box.** Every face with at least half the area of the biggest face (the two large faces of a door, all four sides of a cube) shows the whole picture, corner to corner, upright, and not mirrored from the back. The thin edge faces sample a 2 px sliver just inside the matching picture edge, so they take its border color.
- **A round part taller than a quarter of its diameter** (barrel, tank, trough). The side wraps the picture once around, the axis running up the picture. The caps sit on one texel of the picture's top border, so they take the border color.
- **A disc** (shorter than a quarter of its diameter, a table top). Laid out like a box: the two caps show the picture and the rim samples a border sliver.
- **No cell yet.** The object keeps the strip layout described above.
- **A cell is never cut into bands.** Anything that needs bands is too big for a cell and belongs on a strip.
- **Per building.** The building is the object's root in the `.blend` without `bld_` (`bld_bank` is `bank`; `saloon_interior` and `practice_hub` are their own names). If `cells/bld_bank_door.png` exists, the bank's door uses it; every other door uses `door.png`. If only the override exists, the other doors keep the strip.

### What you see in Blender

Open a map's `.blend` from `assets/models/scenarios/<map>/`, hold `Z` in the 3D viewport, and choose **Material Preview**. Materials that have sheet-role objects show the sheet, Closest filtered, in place of their color. Their color is still stored on the material and returns for the export.

- Skipped objects that share one of those materials (the rail iron, for instance) have no UVs and sample the bottom-left corner, which is the Blank strip, so they look plain.
- Skipped objects with their own material, such as bottles and plants, keep their flat color.
- Rock and ground keep their flat color; their tiling UVs wait for a tiling texture.
- To see the UV layout, open the **UV Editing** workspace and select an object.

### The sheet

**Atlas: 512 wide × 1024 tall** (decision 18). 64 px per metre. The top 512 rows hold the strips and the bottom 512 rows hold the cells. The tables are `STRIP_ROWS` and `CELLS` in `dev/trim_layout.py`, which both `dev/scenery_uv.py` and `dev/build_trim_sheet.py` import. Changing them and re-running the unwrap moves every object, except locked ones.

#### Strips

One metre of wall shows 64 texels, and the full width of the sheet covers 8 m before it repeats.

| Strip | Height | Covers | Pixel rows from top | V | Use |
|---|---|---|---|---|---|
| Siding | 128 px | 2 m | 0–128 | 0.875–1.0 | Plank walls, doors without a cell, car bodies |
| Masonry | 128 px | 2 m | 128–256 | 0.75–0.875 | Stone and brick walls |
| Shingles | 64 px | 1 m | 256–320 | 0.6875–0.75 | Roofs |
| Boards | 64 px | 1 m | 320–384 | 0.625–0.6875 | Floors, decks, crates, table tops |
| Beam | 32 px | 0.5 m | 384–416 | 0.59375–0.625 | Posts, frames, rails, legs |
| Metal | 32 px | 0.5 m | 416–448 | 0.5625–0.59375 | Iron, wheels, boiler |
| Glass | 32 px | 0.5 m | 448–480 | 0.53125–0.5625 | Window panes |
| Moulding | 16 px | 0.25 m | 480–496 | 0.515625–0.53125 | Cornices, thin trim |
| Blank | 16 px | 0.25 m | 496–512 | 0.5–0.515625 | Faces that stay plain; always one flat color. A light warm grey on the placeholder (it is the albedo of wheel caps and unwrapped round-part caps, and pure white would glare) |

Rules for the strip images:

- Every strip repeats left to right with no visible join. Siding and Masonry also repeat top to bottom, because walls stack several bands of them.
- No shadows or highlights in the image. Use albedo maps from Poly Haven or ambientCG (both CC0) before raw photos; they already have the lighting removed.
- The UVs sit exactly on a strip's border. The builder overwrites each strip's top and bottom 4 rows with a copy of the row inside them, so mipmaps do not pull in a neighbouring strip. Keep anything important out of those rows.

#### Cells

Sixteen cells of 128×128 in a 4×4 grid, in the bottom 512 rows. Pixel rows 512–1024, so V on the 1024-tall atlas runs from 0.5 down to 0. The names below are the `CELLS` list; change them before the first cell is made. The two spares are not files: a per-building override (`bld_<building>_<cell>.png`) takes them, in filename order, as `spare_1` then `spare_2`.

| Row (pixel rows) | V | Column 0 (U 0–0.25) | Column 1 (U 0.25–0.5) | Column 2 (U 0.5–0.75) | Column 3 (U 0.75–1.0) |
|---|---|---|---|---|---|
| 0 (512–640) | 0.5–0.375 | `door` | `door_swing` | `window` | `window_barred` |
| 1 (640–768) | 0.375–0.25 | `sign_saloon` | `sign_porch` | `sign_blank` | `poster` |
| 2 (768–896) | 0.25–0.125 | `barrel` | `crate` | `trough` | `tank` |
| 3 (896–1024) | 0.125–0 | `tabletop` | `counter_front` | spare (slot 14) | spare (slot 15) |

Rules for the cell images:

- Any source size and shape. The builder squashes it to 120×120 with a box filter, inside a 4 px border of its own edge pixels.
- A cell is one flat photo of one thing, straight-on and evenly lit.
- Keep the thing's own edge colors out to the border: thin faces and round-part caps take their color from it.


### Making the real sheet

Everything here goes in `assets/texture_src/`, which holds an empty `.gdignore` so Godot does not import the photos. Layout:

```
assets/texture_src/
  .gdignore
  SOURCES.md          where every photo came from, and its license
  strips/
    siding.png  masonry.png  shingles.png  boards.png
    beam.png    metal.png    glass.png     moulding.png
  cells/
    door.png  door_swing.png  window.png  sign_saloon.png  barrel.png ...
    bld_bank_door.png         (optional: overrides door.png for the bank)
  cells_manifest.json   written by the builder; read by the unwrap
```

With no files in `strips/` and `cells/`, `assets/textures/trim_sheet.png` is the placeholder.

#### A. A cell with the texture ripper

1. **Shoot the photo.** Stand back and square on to the door, window, or sign, in flat overcast light if you can. Get the whole thing in the frame with a little around it. A phone is fine.
2. **Open the ripper.** Follow the link in the [repository README](https://github.com/raycastly/texture-ripper); it runs in the browser.
3. **Load the photo.** Upload it and lock it in place.
4. **Mark the object.** Click **Add Rectangle**, then drag its four corners onto the four corners of the door in the photo. This is what flattens the perspective.
5. **Extract.** Click **Extract All**. If it looks skewed, move a corner and extract again.
6. **Export.** Set the resolution in the right panel (anything 256 or larger is plenty) and click **Export**. The README does not say whether it can save one tile at a time or only a packed atlas. If it gives you an atlas, crop the tile out in GIMP or Krita, so you have one PNG per object.
7. **Name and save it.** Save it as `assets/texture_src/cells/door.png` (use the cell name from the table above). Add the photo's source and license to `SOURCES.md`.

You do not need to resize or square it. A tall, thin door in a 40×90 PNG is fine; the builder squashes it.

Things the ripper does not do for you: it does not remove shadows, it does not make anything tile, and the README lists the drawing mode as unfinished, so use **Add Rectangle**.

#### B. A strip from a photo

A strip has to repeat sideways without a seam. The ripper does not do that, so use GIMP or Krita.

1. Rip or crop a flat patch of the material (planks, brick, shingles) at least 512 px wide, as above.
2. **Offset it by half.** In GIMP: Layer > Transform > Offset, click **By x/2, y/2**, and set the edge behaviour to **Wrap around**. In Krita: Image > Offset Image, half the width and height. The old seams now sit in a cross across the middle.
3. **Paint the cross out.** Use the Clone or Heal tool and sample from clean areas until the middle matches. Check by offsetting again.
4. Save as the strip's name in `assets/texture_src/strips/`.

For wood and brick that runs in one direction, keep the planks horizontal in the strip.

#### C. Build the sheet

```powershell
python dev/build_trim_sheet.py            # writes trim_sheet.png and cells_manifest.json
python dev/build_trim_sheet.py --check    # exit 1 if the files on disk differ from a rebuild
```

Plain Python with Pillow; no Blender. It:

1. Reads `strips/<name>.png` (`siding`, `masonry`, `shingles`, `boards`, `beam`, `metal`, `glass`, `moulding`, `blank`) and `cells/<name>.png`. A file that is missing is painted a plain tint, so the sheet always builds.
2. Squashes each strip to 512 px wide and its row height, and each cell to 120×120, both with a box filter. Any source size or shape; transparent pixels sit on white.
3. Gives each cell a 4 px border of its own edge pixels and does the same to the top and bottom 4 rows of each strip, so mipmaps do not bleed.
4. Places everything on the 512×1024 atlas and cuts the whole sheet to one palette of 32 colors, no dither. A sheet that already has 32 or fewer is left exact.
5. Writes `assets/textures/trim_sheet.png` and `assets/texture_src/cells_manifest.json` (which cells have an image, and which building owns which override slot), and prints one line: strips and cells found, tints used, palette size.

It stops with a message, writing nothing, on a file in `cells/` that is not a cell name or `bld_<building>_<cell>`, a `strips/` file that is not a strip, or a third override. Then re-run the unwrap so objects pick up their cells, reimport, and look in Blender:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python dev/unwrap_scenery_blender.py
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
```

Add the photo's source and licence to `assets/texture_src/SOURCES.md`.

#### What to check first

Before committing to photos everywhere, make one door, one window, and one wall siding strip, build the sheet, and look at the bank and the saloon in Material Preview and in a `--flat` run. If the photos fight the banded light and the ink lines, the answer is decision 6, not more work on the builder.


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
4. The sheet is 1024 px tall but 512 px wide, so the projection is now twice as dense up the sheet as across it. In the UV Editor press `A`, `S`, `Y`, `0.5`, `Enter` to make the texels square again. The faces are then at the right size but in the wrong place. Move the mouse over the UV Editor.
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

`assets/models/scenarios/saloon/saloon.blend`, `saloon_bar.glb`, `saloon_shell.glb`, `saloon_table.glb`, `saloon_chair.glb`, `saloon_balcony.glb`, `saloon_dressing.glb`, and `saloon_lamps.glb`. Build script `dev/build_saloon_blender.py` (greybox only; never re-run it: every Saloon GLB is final, and the greybox `saloon_interior.glb` it wrote is retired). Seen from a few metres, so texel mistakes show most here. The checks below date from the trim sheet and cover the greybox.

- [ ] Four walls, wainscot, and ceiling: bands line up at the corners.
- [ ] The 16 floor planks run along their length on Boards.
- [ ] `Stair` (slanted) and `StoveBody` (flagged).
- [ ] Left flat on purpose: bottles, candles, flames, glass panes, mirror, brass, piano keys.

#### Train Rooftop

`assets/models/scenarios/train_rooftop/train_rooftop.blend`, `train_rooftop.glb` and `horizon_ridge.glb`. Build script `dev/build_train_rooftop_blender.py`. The duel is on the car roofs, so check those first. Since the split (`docs/design/scenarios/train_rooftop.md` H) this list is out of date: the greybox coaches and couplers it names are gone (replaced by `train_car_coach` and `train_coupler`), the other greybox pieces moved to `train_car_baggage` and `train_car_business`, which are final now too (five and seven merged objects), and the engine is final (eight merged objects, `Engine_Car` to `Engine_LampGlass`), so the `Engine_*` and `CarRearBLadder_Rail*` items below no longer apply.

- [ ] `Car*_Roof` and `Car*_Lip*` on Shingles.
- [ ] `Engine_Boiler`, `Engine_Smokebox`, `Engine_Stack`, `Engine_Pilot`, `CarRearBLadder_Rail*` (flagged).
- [ ] The 161 wheels, axles, and couplers are on Metal, with wheel caps on Blank. They sit under the cars; lock any you fix.
- [ ] `horizon_ridge` and the `M_Cap`/`M_Rock` blocks have tiling UVs only. The `Canyon`, `Mesa`, and `Butte` spans are final (four, four, and three tiling objects, from `dev/build_horizon_ridge_finals_blender.py`, which writes their 8 m tiling UVs itself).

#### Practice Hub

`assets/models/scenarios/practice_hub/practice_hub.blend`, `practice_hub.glb`. Build script `dev/build_practice_hub_blender.py`.

- [ ] Porch: wall, roof, deck, sign, posts.
- [ ] The 28 `FencePost*` are tapered, so their density is off by design.
- [ ] Target rails and crates.
- [ ] Left flat on purpose: plants, hay. `Lot`, `Desert`, `Berm`, and `Mesa*` carry tiling UVs.

#### Canyon

`assets/models/scenarios/canyon/canyon.blend`, `canyon.glb`. Build script `dev/build_canyon_blender.py`.

Nothing here is built from wood or iron. The final cliffs (`CanyonCliffs`: four merged objects, 8,118 triangles), cover rocks (`CanyonCover`: two objects, 656 triangles), floor (`CanyonFloor`: `Floor_Sand`, 267 triangles), rim (`CanyonRim`: four objects, 1,611 triangles), and the horizon's rock and sand (`CanyonHorizon`: `Horizon_Desert`, the butte, and the nine mesas in four objects, 1,288 triangles), all from `dev/build_canyon_finals_blender.py`, carry 8 m tiling UVs. The 65 plants in 25 meshes are flat (per-GLB unwrap: 25 meshes, 1091 islands, 13.7 px/m, 86% covered, 16 tiling meshes untouched). The trim sheet does not apply. Texturing the rock means a separate tiling texture, which is not decided.

- [ ] Decide whether rock and ground get a tiling texture (decision 12 only prepared the UVs).
