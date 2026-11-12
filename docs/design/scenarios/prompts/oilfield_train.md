# Design-sheet prompt: Oil-field Train

Run with: Agent, model **Fable 5.1**, effort **high**. Paste everything inside the fence. The reference frames are in the repo (`docs/design/scenarios/jarhead.jpg`, `jarhead2.jpg`), and the prompt tells the agent to open them with Read; no attachment is needed.
Output: `docs/design/scenarios/oilfield_train.md`

```text
SCENE: Oil-field Train (a variant of Train Rooftop)
Build script (new): dev/build_oilfield_train_blender.py -> assets/models/scenarios/oilfield_train/
Assets: NEW only: pumpjack (static frame and a separate walking beam), wellhead and burning-well mound, derrick, storage tanks, pipeline runs, a power pylon, sump pools and scorched ground, shacks or crates if the sheet wants them, and a new 48 m oil-field horizon tile (oilfield_horizon) with distant rigs and flame anchors. The train itself is NOT modeled here: the Train Rooftop consist is reused as-is (see the facts below).

Task: write the DESIGN SHEET for taking this scene from nothing to final, untextured,
UV-unwrapped meshes. Do NOT model anything and do NOT edit code, scenes, shaders, or Blender.
Output is one markdown file: docs/design/scenarios/oilfield_train.md. Do not run git.

WHAT THIS PLACE IS (already decided by the user; design inside it, do not reopen it):
- The same stopped train as Train Rooftop, with the desert scrolling past it, but the desert is
  an oil field. Pumpjacks stand on both sides of the track; burning wells are the horizon.
- It is a variant scene (its own scenario), not a re-skin of Train Rooftop. Train Rooftop stays as it is.
- Playable in the gauntlet (a temporary final rung until the Half-head NPC ships, then his rung),
  free duel, and MP lobbies. The last gauntlet map is the one Half-head is met on: see
  docs/design/characters/half-head.md (a checkered giant in black, white, and bone with two
  revolvers; the railroad is his; "the flames are the only colour in his fight").
- ONE fixed lighting condition, no random time of day: dusk into night. The sun has just set. A
  dark sky overhead, a lit horizon band, orange smoke-haze fog. The sheet designs for that one
  condition only (dawn, noon, and afternoon do not apply).
- Reference, and the GOAL: the Jarhead burning-oil scenes. Open both images with Read before
  anything else: docs/design/scenarios/jarhead.jpg (one frame: two figures seated in silhouette
  before a flame column and a pylon) and docs/design/scenarios/jarhead2.jpg (a contact sheet of
  eight frames: a pink-violet dusk sky over two rifle silhouettes, a figure drinking against an
  amber glow, two figures on a ridge against a dark sky, burning columns over a flat horizon with
  smoke, a soldier at a ridge). The user wants to capture the FEEL of these images as closely as
  the PSX / Steel Ball Run look allows: that is the acceptance test of the whole scene, not a mood
  note. What they carry, by looking: a saturated orange-red smoke-haze that fills the sky and the
  fog, so depth is told by haze steps and not by detail; near-black SILHOUETTES (figures, a pylon,
  a wrecked car, the ground itself) with almost no interior detail; one white-hot flame column
  with a yellow-orange body and a dark smoke head, its base glowing on the ground; a long, flat,
  dark horizon with several columns at different distances; a pink-violet dusk sky with an
  orange horizon in one frame; the lit side of things is the side facing the fire. The palette is
  nearly one hue, orange, with a dark foreground and one white-yellow hotspot. Reproduce the
  feel through shape, value, and haze, not photographic detail. Propose how that becomes flat
  Base Colors, geometry, and the sky and fog values (section A), say where the PSX look and the
  reference pull apart and what you chose, and ask in F anything it leaves open.
- Cosmetic flames: the burning oil bursts are flame and smoke columns on the horizon, a
  VfxCatalog cue (local cosmetic, no gameplay, nothing on the wire). The sheet specifies where
  they stand and how big they are; it does not design the particle effect.
- Light: the flames also (a) tint the sky and fog glow (orange, flickering) and (b) cast a soft,
  flickering OmniLight on the lane and on the skins. The sheet says which geometry must catch
  that light (the warm side of rigs, tanks, and the train's roofs) and which must stay dark
  silhouette, because the repo shaders turn the light into two flat bands.
- The pumpjacks nod: a walking beam rocks on a slow loop (a small script, cosmetic, no net). The
  beam is therefore a SEPARATE object with its pivot at the Samson post, named so a script can
  find it; everything else on the pumpjack is static.

STYLE (already decided; design inside it, do not reopen it):
- Low-poly PSX look: chunky silhouettes, nearest-sampled low-res textures, visible texels.
- Steel Ball Run (Araki) energy: strong graphic shape and flat color, not realism. The game is
  American West crossed with dark fantasy. Here the saturation comes from the fire and the haze,
  not from a loud local palette.
- Rendered through the repo shaders: banded toon light, outline, sky, grain, wind sway. Light is
  NEVER painted: no baked AO, shadows, or highlights, and no painted dirt or wear passes.
  Consequence: age, wear, and character must live in GEOMETRY and SILHOUETTE (bent legs, leaning
  derricks, sagging pipe runs, uneven tanks) and in material color choice, because texture is
  flat ink at one low texel density.
- Squint test: at duel distance on a Quest, through PSX geometry, a scene reads as a few big
  shapes and two or three flat colors. Describe each asset's squint read first. Here the squint
  read is a dark shape against orange: say what the silhouette of each asset is.
- PSX vertex snap and affine warp are flat-only at most (stereo makes the world wobble). Do not
  design anything that depends on them.

TEXTURING: KEEP IT SIMPLE (the user's intent wins over any existing doc):
- The user will texture BY HAND, later, after the meshes are modeled and UV unwrapped. The
  deliverable of the build is just: clean, final, untextured meshes with sensible UVs and flat
  Base Color materials. Nothing in this sheet should plan texture art, atlases, or painting.
- docs/TEXTURING.md describes an existing, more elaborate pipeline (per-GLB 256x256 images, a
  scripted unwrap in dev/unwrap_per_glb_blender.py with `uv_lock`, a paused trim sheet, a
  texture-ripper workflow). The user does not want extra complexity. Treat it ONLY as a
  compatibility reference for what keeps the game loading:
    * material names `M_<Base>__<glb>` (the base name sets grain/sway in
      assets/shaders/world_surface_import.gd), exact repeated color values so materials share;
    * no vertex colors, normal maps, emission, or alpha on scenario materials. The exception is
      the self-lit M_Flame / M_LampGlass path in the world shader (Saloon sheet G7): say whether
      a wellhead's burning mouth or a pumpjack lamp needs it;
    * ground and rock keep their 8 m tiling UVs and flat color;
    * `--autotest=load` must still pass.
- Do not design around the trim sheet, texel-density targets, the ripper, or anything else in
  that doc. If the existing unwrap script already does the UV job, the sheet just says "use it".
- Section G (below) is where you flag every place that pipeline would add work beyond "model +
  UV unwrap", with the simplest alternative. Do not silently adopt its complexity and do not
  silently ignore it.

Read first, in this order:
0. The two reference images, docs/design/scenarios/jarhead.jpg and jarhead2.jpg (Read opens images).
1. CLAUDE.md, docs/design/README.md, and the character pages in docs/design/characters/
   (tone, era, palette, lore the scenery must agree with). Half-head's page is the one this map
   serves; the Sheriff, Ghost, and Drunk pages say what the railroad did to the world.
2. .claude/skills/gunslinger-taste/SKILL.md, and its references/board.md and
   references/steel-ball-run.md (the moodboard and Steel Ball Run notes). Name which board
   items each of your choices draws on.
3. docs/SHADERS.md (the shaders the scenery is rendered through) and a skim of
   docs/TEXTURING.md, reference only (see the TEXTURING block above).
4. docs/design/scenarios/train_rooftop.md IN FULL (the train this scene reuses, its rules, the
   horizon tile, the belt) and its build script dev/build_train_rooftop_blender.py. Then
   scenarios/train_rooftop/ (.tscn, .tres, scenery_belt.gd, engine_smoke.gd): spawns, cover,
   sightlines, what must stay clear. Then scenarios/time_of_day.gd, scenarios/scenario_base.gd,
   and scenarios/sky_western.gdshader (what a fixed dusk-into-night would have to change).
5. The Roadmap.md and docs/FEATURES.md entries for this scene. Do not invent features.
6. dev/unwrap_per_glb_blender.py, dev/scenery_uv.py, and dev/blender_kit.py: the current UV and
   build helpers. Say whether the existing unwrap is good enough to reuse as-is.
7. Web references: real oil fields of the 1860s to 1900s (Pennsylvania's Oil Creek, Spindletop in
   1901, Kern County and Los Angeles' early fields, the Baku and Kuwait burning fields for
   flame behaviour), cable-tool derricks, the walking-beam engine and the first pumpjacks,
   riveted iron storage tanks, wooden pipelines, and the Jarhead frames' photography. Also
   PSX-era environment art for how low-poly scenery stays charming. Cite every source you rely on.
   Check the era: the game is 1880s-flavored American West crossed with dark fantasy, so say where a
   real oil-field object is later than the setting and what you do about it (anachronism is allowed
   if the silhouette needs it, but list it in F).

SCENE-SPECIFIC FACTS AND CONSTRAINTS (verify each against the files; report any that are wrong):
- Metric scale, Z-up. Roof tops stay at Godot y = 3.2 so spawns at z = +/-10 still stand on
  the duel cars (centers +/-6.6). The Train Rooftop footprint, spawns (PlayerSpawn, EnemySpawn,
  EnemySpawns2 A-B, EnemySpawns3 A-C), invisible walls, and walk proxy carry over unchanged: this
  scenario is a copy of that scene's train half. The 3-NPC finale must work here as on Train Rooftop.
- Cars are 12 m long with a 1.2 m coupler gap (pitch 13.2 m). The train heads -Z; the engine is the
  front, with the engine smoke at the stack (assets/vfx/engine_smoke.tscn). The train stays stationary.
- REUSE, DO NOT REMODEL: the train GLBs (train_car_coach x4, train_coupler x6, train_engine,
  train_car_baggage, train_car_business, and the guard walls) are instanced as they are. Their
  materials stay unless the sheet argues, in F, that a re-skin is needed; the user chose
  reuse. Say how the existing train reads against the new light and haze (its company blue is
  now seen at dusk through orange fog) and what the new scenery must do to keep it readable.
- The scenery scrolls past the stopped train via a belt script (scenarios/train_rooftop/scenery_belt.gd:
  near belt at 20 m/s for track and plants, mid belt at 0.35x, far belt at 0.12x; HORIZON_SPAN = 48 m,
  spans 48 m along Blender Y centered on the origin, ends must tile). The new scenario gets its own belt
  script. The sheet decides: which pieces ride the near belt (pumpjacks, wellheads, pipe runs,
  pylons?), which the mid belt (tanks, derricks), which the far belt (the horizon tile and its
  flame anchors), with counts, x offsets, and how many pumpjack beams are animated at once
  (cost on Quest; propose a single shared phase). Wrap length versus the fog: nothing may pop in.
- The track and ties (env_rail_track_8m from Main Street) are reused. Say what changes beside them
  (oil-soaked ground, spill, ballast) and whether the track needs an oilfield variant.
- Flame anchors: the horizon tile carries named empties for the flame columns
  (suggest `Flame_<n>`, with height and base size in the sheet). The sheet gives bearing, distance,
  and scale for each, how many are in view at once, and which belt moves them.
- Lighting: a fixed dusk into night. Say what the sky's dark overhead and lit horizon band do to
  roof tops, rigs, and the horizon's silhouettes, and which Base Colors survive being seen
  almost only as silhouette or through orange fog. The sheet may list the new TimeOfDay point's
  intent (colors in words) but must not write code.
- Invisible walls ring the roofs and the horizon has no collision; new scenery has no
  collision unless it sits within the walls' reach (the sheet says so per asset).
- Boxes and slabs must not share coplanar faces (cliff boxes z-fought before). Say how the final avoids it.
- The player stands on a roof: roof surface, hatches, vents, and walkway boards are seen from
  directly above at close range, and the pumpjacks and tanks are the first things the player sees
  past the enemy. Prioritize what the lane looks at. Undercarriage and car sides are seen only
  while scrolling past.

Hard constraints for every scene:
- Triangle budget: docs/TEXTURING.md lists the current triangle counts per map. Start from those
  (Train Rooftop is about 46,700 triangles with its horizon), state a budget per NEW asset class
  and a scene total for Quest 3, and justify the increase. The train GLBs are already counted.
- Untextured but UV-ready for hand texturing: per asset, note only what would make the unwrap
  bad to paint on (overlapping islands, mirrored geometry sharing UVs wrongly, slivers, seams
  across a face the player reads). Keep it short.
- Gameplay readability first: cover, sightlines, and the lane must read at duel distance through
  the outline shader. Name the silhouettes that carry that.
- Collision proxies keep the `-convcolonly` import suffix and unique names (no `.001`). Existing
  footprints stay unless you list the change and why.

The sheet must contain:
A. Art direction: 5-8 sentences on shape language, wear level, proportion rules, palette (the
   Jarhead feel as flat Base Colors, plus the sky, fog, and flame-glow values in words and hex:
   name the hot, dark, and mid values and the haze colour), a short frame-by-frame list of what
   you take from each Jarhead frame, and a one-line "what
   this place feels like". Ground each claim in a reference. Say how Half-head's black, white,
   and bone read against it.
B. Per-asset sheets, one per NEW asset (match the file or object name to be built): role in play,
   real dimensions, squint read (silhouette plus two or three flat colors), 5-10 signature
   details ranked by importance (a builder cuts from the bottom to meet budget), which wear and
   character is carried by geometry, flat Base Color per material (names `M_<Base>`), UV notes
   (short), triangle budget. For the pumpjack: the beam's pivot, rocking range, and rest pose.
C. Build order: the HERO asset (built first, sets the quality bar) and why, then the order for
   the rest. Mark which assets are modular repeats.
D. Review checklist: fixed camera views to render per asset (duel-lane view, 3/4 view,
   silhouette view) and pass/fail questions for each, plus a whole-scene REFERENCE MATCH check:
   from a roof at duel distance in the fixed dusk-into-night light, put a render beside each
   Jarhead frame (jarhead.jpg, and the frames of jarhead2.jpg that apply) and pass/fail it on:
   one dominant hue; silhouettes with no interior detail; a flame column with a hot core;
   haze steps between near, mid, and far; the lit side facing the fire; a dark flat foreground.
   Name which frame each question is checked against.
E. Cross-scene dependencies: the reused train (train_rooftop.md), env_rail_track_8m from Main
   Street, the Canyon cliff vocabulary for the horizon, and the belt contract in
   scenery_belt.gd. State what must match and what intentionally differs. Read
   docs/design/scenarios/main_street.md, canyon.md, and train_rooftop.md.
F. Open questions for the user: every decision you could not settle from the repo or references
   (tone, wear, anachronisms, whether the ground carries Half-head's checker as land-grant
   squares, per-asset budget, and so on). One question per decision, options stated,
   recommendation last. Do not guess; list them.
G. Pipeline friction: every place the existing texturing pipeline (docs/TEXTURING.md) would add
   work or constraints beyond "model + UV unwrap, then the user paints by hand". For each, give
   the simplest alternative and what it costs. Keep this to the real items; say "none" if none.

Report back: the file path, the hero asset you chose, any wrong facts you found above, and the
open questions.
```
