# Texturing

How to color and texture a mesh in Blender so it matches the look and runs on a Quest 3. Covers what the pipeline accepts today, the rules of the look, the steps per asset type, and the performance limits.

Shaders: [`SHADERS.md`](SHADERS.md) · Art direction: [`design/README.md`](design/README.md) · Blender setup: `.claude/rules/blender-mcp.md`

## What the pipeline accepts today

The renderer is `gl_compatibility` on every platform, so Quest, PCVR, and flat share one look.

| Asset | How it gets its surface | What Blender supplies |
|---|---|---|
| Scenario GLBs (`assets/models/scenarios/**`) | `assets/shaders/world_surface.gdshader`, swapped in at import by `world_surface_import.gd`. Flat color, banded light, procedural grain | A material **name**, a Base Color, a roughness. No UVs, no images |
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
3. Add no image nodes, no vertex colors, no normal maps, no alpha.
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

- **Painted textures on scenery.** `world_surface.gdshader` has no `albedo_tex` and reads no `UV`; the 23 scenario GLBs carry no UVs.
- **Textured duelists.** `body_skin.gdshader` draws one flat color, and `gunslinger.glb` is not instanced on the player, AI, or remote avatar.
- **Banded light on the gun and props.** They keep smooth `StandardMaterial3D` light. Matcap metal (`SHADERS.md` #9) is not queued.
