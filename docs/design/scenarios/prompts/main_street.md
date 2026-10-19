# Design-sheet prompt: Main Street

Run with: Agent, model **Fable 5.1**, effort **high**. Paste everything inside the fence.
Output: `docs/design/scenarios/main_street.md`

```text
SCENE: Main Street
Build script: dev/build_main_street_blender.py -> assets/models/scenarios/main_street/
Assets: bld_bank, bld_church, bld_depot, bld_general_store, bld_hotel, bld_jail, bld_newspaper, bld_saloon (street false-front), env_awning_post, env_boardwalk_4m, env_cattle_fence_4m, env_desert_scatter, env_rail_track_8m, env_street_ground, env_terrain, prp_barrels, prp_cow, prp_hitching_rail, prp_trough

Task: write the DESIGN SHEET for taking this scene from greybox to final, untextured,
UV-unwrapped meshes. Do NOT model anything and do NOT edit code, scenes, shaders, or Blender.
Output is one markdown file: docs/design/scenarios/main_street.md. Do not run git.

STYLE (already decided; design inside it, do not reopen it):
- Low-poly PSX look: chunky silhouettes, nearest-sampled low-res textures, visible texels.
- Steel Ball Run (Araki) energy: loud, flat, saturated color and strong graphic shape, not
  realism. The game is American West crossed with dark fantasy.
- Rendered through the repo shaders: banded toon light, outline, sky, grain, wind sway. Light is
  NEVER painted: no baked AO, shadows, or highlights, and no painted dirt or wear passes.
  Consequence: age, wear, and character must live in GEOMETRY and SILHOUETTE (warped planks,
  sagging rooflines, chipped edges, uneven heights, gaps) and in material color choice, because
  texture is flat ink at one low texel density.
- Squint test: at duel distance on a Quest, through PSX geometry, a scene reads as a few big
  shapes and two or three flat colors. Describe each asset's squint read first.
- PSX vertex snap and affine warp are flat-only at most (stereo makes the world wobble). Do not
  design anything that depends on them.

TEXTURING: KEEP IT SIMPLE (the user's intent wins over any existing doc):
- The user will texture BY HAND, later, after the meshes are modeled and UV unwrapped. The
  deliverable of the build is just: clean, final, untextured meshes with sensible UVs and flat
  Base Color materials. Nothing in this sheet should plan texture art, atlases, or painting.
- docs/TEXTURING.md describes an existing, more elaborate pipeline (per-GLB 256x256 images, a
  scripted unwrap in dev/unwrap_per_glb_blender.py with `uv_lock`, a paused trim sheet, a
  texture-ripper workflow). The user has not read it and does not want extra complexity. Treat
  it ONLY as a compatibility reference for what keeps the game loading:
    * material names `M_<Base>__<glb>` (the base name sets grain/sway in
      assets/shaders/world_surface_import.gd), exact repeated color values so materials share;
    * no vertex colors, normal maps, emission, or alpha on scenario materials;
    * ground and rock keep their 8 m tiling UVs and flat color;
    * `--autotest=load` must still pass.
- Do not design around the trim sheet, texel-density targets, the ripper, or anything else in
  that doc. If the existing unwrap script already does the UV job, the sheet just says "use it".
- Section G (below) is where you flag every place that pipeline would add work beyond "model +
  UV unwrap", with the simplest alternative. Do not silently adopt its complexity and do not
  silently ignore it.

Read first, in this order:
1. CLAUDE.md, docs/design/README.md, and the character pages in docs/design/characters/
   (tone, era, palette, lore the scenery must agree with).
2. .claude/skills/gunslinger-taste/SKILL.md, and its references/board.md and
   references/steel-ball-run.md (the moodboard and Steel Ball Run notes). Name which board
   items each of your choices draws on.
3. docs/SHADERS.md (the shaders the scenery is rendered through) and a skim of
   docs/TEXTURING.md, reference only (see the TEXTURING block above).
4. The build script above and every asset listed. For each, record dimensions and what it is
   for in play. Then read the scenario's .tscn and scripts under scenarios/main_street/ so you know the
   spawns, cover, sightlines, and what must stay clear.
5. The Roadmap.md and docs/FEATURES.md entries for this scene. Do not invent features.
6. dev/unwrap_per_glb_blender.py, dev/scenery_uv.py, and dev/blender_kit.py: the current UV and
   build helpers. Say whether the existing unwrap is good enough to reuse as-is.
7. Web references: real Old West architecture, photography, and the makers or design movements
   behind it, and PSX-era environment art for how low-poly scenery stays charming. Cite every
   source you rely on.

SCENE-SPECIFIC FACTS AND CONSTRAINTS (verify each against the files; report any that are wrong):
- Metric scale, Z-up, 1 BU = 1 m. Street-facing facade toward Blender +Y (Godot -Z).
- 16 m duel lane down the street; depot vs cattle pens on either side. Buildings are period
  false-fronts; list which are 1-sided facades (never seen from behind) vs full volumes.
- The recent commit added trim-sheet UVs to the scenery. Decide if that stays for finals.
- bld_saloon.glb is the street false-front only; the interior is a separate scene (Saloon).
- env_rail_track_8m and env_desert_scatter are also reused by Train Rooftop's scrolling belt.
- Props (barrels, cow, hitching rail, trough) may be grabbed or shot; note any that are physics
  bodies before changing their footprint.

Hard constraints for every scene:
- Triangle budget: docs/TEXTURING.md lists the current triangle counts per map. Start from those,
  state a budget per asset class and a scene total for Quest 3, and justify the increase.
- Untextured but UV-ready for hand texturing: per asset, note only what would make the unwrap
  bad to paint on (overlapping islands, mirrored geometry sharing UVs wrongly, slivers, seams
  across a face the player reads). Keep it short.
- Gameplay readability first: cover, sightlines, and the lane must read at duel distance through
  the outline shader. Name the silhouettes that carry that.
- Collision proxies keep the `-convcolonly` import suffix and unique names (no `.001`). Existing
  footprints stay unless you list the change and why.

The sheet must contain:
A. Art direction: 5-8 sentences on shape language, wear level, proportion rules, palette
   (loud, flat, Steel Ball Run-style color within the PSX look), and a one-line "what this place
   feels like". Ground each claim in a reference.
B. Per-asset sheets, one per asset (match the existing file or object name): role in play, real
   dimensions, squint read (silhouette plus two or three flat colors), 5-10 signature details ranked by
   importance (a builder cuts from the bottom to meet budget), which wear and character is
   carried by geometry, flat Base Color per material (using existing M_ names), UV notes
   (short), triangle budget.
C. Build order: the HERO asset (built first, sets the quality bar) and why, then the order for
   the rest. Mark which assets are modular repeats.
D. Review checklist: fixed camera views to render per asset (duel-lane view, 3/4 view,
   silhouette view) and pass/fail questions for each.
E. Cross-scene dependencies: this sheet is the style reference for every other scene. State the global rules (wear level, color-value logic, bevel size, plank width, detail density) in A so the other four sheets can inherit them. Note what Train Rooftop reuses from here.
F. Open questions for the user: every decision you could not settle from the repo or references
   (tone, wear, enterable interiors, per-asset budget, and so on). One question per decision,
   options stated, recommendation last. Do not guess; list them.

G. Pipeline friction: every place the existing texturing pipeline (docs/TEXTURING.md) would add
   work or constraints beyond "model + UV unwrap, then the user paints by hand". For each, give
   the simplest alternative and what it costs. Keep this to the real items; say "none" if none.

Report back: the file path, the hero asset you chose, any wrong facts you found above, and the
open questions.
```
