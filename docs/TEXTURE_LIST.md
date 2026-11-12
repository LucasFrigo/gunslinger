# Texture list

One hand-painted 256×256 image per exported scenario GLB, 39 GLBs. Workflow and rules: [`TEXTURING.md`](TEXTURING.md#hand-painted-texture-per-glb). Source for ripper output and photos: `assets/texture_src/` (credit each photo in `SOURCES.md`; that folder is not imported by Godot).

Nothing is painted yet. Every GLB is still flat colour and grain. A box is checked when `tex/<glb>.png` is saved, linked (`dev/unwrap_per_glb_blender.py -- --link --glb <glb>`), and looks right in game.

## How to read it

- **PNG** is the path to save the image at, relative to `assets/models/scenarios/`. Save it exactly there; the link script looks for that name.
- **Meshes** is how many visible meshes share that image. **Density** is the texel density the unwrap gave the whole GLB at 256 px (a larger GLB gets fewer pixels per metre because it shares one image). Every mesh of a GLB shares one layout, so the PNG is the whole GLB, not one object.
- **Left alone** counts the ground and rock meshes in the GLB. They keep tiling UVs and flat colour and are not in the image.
- A GLB with 0 meshes has nothing to paint (all of it is ground or rock). Its box is marked n/a.
- To see the layout of a GLB: open its `.blend`, select the GLB's root and its hierarchy, UV Editing workspace, UV > Export UV Layout at 256×256, and paint over it.

## Main Street (`main_street/main_street.blend`)

| Done | GLB | PNG | Meshes | Density | Left alone |
|---|---|---|---|---|---|
| [ ] | `bld_bank` | `main_street/tex/bld_bank.png` | 5 | 7.9 px/m | 0 |
| [ ] | `bld_church` | `main_street/tex/bld_church.png` | 5 | 7.7 px/m | 0 |
| [ ] | `bld_depot` | `main_street/tex/bld_depot.png` | 6 | 4.6 px/m | 0 |
| [ ] | `bld_general_store` | `main_street/tex/bld_general_store.png` | 6 | 9.5 px/m | 0 |
| [ ] | `bld_hotel` | `main_street/tex/bld_hotel.png` | 5 | 6.7 px/m | 0 |
| [ ] | `bld_jail` | `main_street/tex/bld_jail.png` | 5 | 18.6 px/m | 0 |
| [ ] | `bld_newspaper` | `main_street/tex/bld_newspaper.png` | 7 | 13.6 px/m | 0 |
| [ ] | `bld_saloon` | `main_street/tex/bld_saloon.png` | 7 | 10.2 px/m | 0 |
| [ ] | `env_awning_post` | `main_street/tex/env_awning_post.png` | 2 | 66.6 px/m | 0 |
| [ ] | `env_boardwalk_4m` | `main_street/tex/env_boardwalk_4m.png` | 2 | 46.0 px/m | 0 |
| [ ] | `env_cattle_fence_4m` | `main_street/tex/env_cattle_fence_4m.png` | 1 | 45.5 px/m | 0 |
| [ ] | `env_desert_scatter` | `main_street/tex/env_desert_scatter.png` | 278 (plants) | 8.0 px/m | 0 |
| [ ] | `env_rail_track_8m` | `main_street/tex/env_rail_track_8m.png` | 2 | 31.5 px/m | 1 (`Track_Ballast`) |
| n/a | `env_terrain` | none | 0 | | 1 |
| [ ] | `prp_barrels` | `main_street/tex/prp_barrels.png` | 2 | 75.8 px/m | 0 |
| [ ] | `prp_cow` | `main_street/tex/prp_cow.png` | 2 | 70.7 px/m | 0 |
| [ ] | `prp_hitching_rail` | `main_street/tex/prp_hitching_rail.png` | 1 | 96.9 px/m | 0 |
| [ ] | `prp_trough` | `main_street/tex/prp_trough.png` | 3 | 80.4 px/m | 0 |

## Saloon (`saloon/saloon.blend`)

| Done | GLB | PNG | Meshes | Density | Left alone |
|---|---|---|---|---|---|
| [ ] | `saloon_bar` | `saloon/tex/saloon_bar.png` | 6 | 20.0 px/m | 0 |
| [ ] | `saloon_shell` | `saloon/tex/saloon_shell.png` | 6 | 6.4 px/m | 0 |
| [ ] | `saloon_table` | `saloon/tex/saloon_table.png` | 4 (one image for both tables) | 95.1 px/m | 0 |
| [ ] | `saloon_chair` | `saloon/tex/saloon_chair.png` | 1 (one image for all eight chairs) | 171.0 px/m | 0 |
| [ ] | `saloon_balcony` | `saloon/tex/saloon_balcony.png` | 3 | 16.8 px/m | 0 |
| [ ] | `saloon_dressing` | `saloon/tex/saloon_dressing.png` | 7 | 40.9 px/m | 0 |
| [ ] | `saloon_lamps` | `saloon/tex/saloon_lamps.png` | 4 | 71.1 px/m | 0 |

## Train Rooftop (`train_rooftop/train_rooftop.blend`)

| Done | GLB | PNG | Meshes | Density | Left alone |
|---|---|---|---|---|---|
| [ ] | `train_car_coach` | `train_rooftop/tex/train_car_coach.png` | 5 (one image for all four coaches; final) | 12.5 px/m | 0 |
| [ ] | `train_coupler` | `train_rooftop/tex/train_coupler.png` | 1 (one image for all six couplers; final) | 141.2 px/m | 0 |
| [ ] | `train_engine` | `train_rooftop/tex/train_engine.png` | 8 (final) | 10.5 px/m | 0 |
| [ ] | `train_car_baggage` | `train_rooftop/tex/train_car_baggage.png` | 5 (final) | 13.3 px/m | 0 |
| [ ] | `train_car_business` | `train_rooftop/tex/train_car_business.png` | 7 (final) | 11.9 px/m | 0 |
| n/a | `train_rooftop` | none (the four invisible guard walls only) | 0 | | 0 |
| n/a | `horizon_ridge` | none | 0 | | 11 (all tiling rock, all final: `Canyon_*` and `Mesa_*`, four each; `Butte_Rock`, `Butte_RockDark`, `Butte_Cap`) |

## Oil-field Train (`oilfield_train/oilfield_train.blend`)

| Done | GLB | PNG | Meshes | Density | Left alone |
|---|---|---|---|---|---|
| [ ] | `oil_pumpjack` | `oilfield_train/tex/oil_pumpjack.png` | 3 (one image for all 32 copies; `WalkingBeam` is its own object) | 17.5 px/m | 0 |
| [ ] | `oil_wellhead` | `oilfield_train/tex/oil_wellhead.png` | 1 (one image for all 16 copies) | 112.5 px/m | 1 tiling mesh (`Wellhead_Dirt`, the pad) |
| [ ] | `oil_sump` | `oilfield_train/tex/oil_sump.png` | 1 (`Sump_Glass`, three faces; one image for all 16 copies) | 37.9 px/m | 1 tiling mesh (`Sump_Dirt`, the berm) |
| [ ] | `oil_pipe_run` | `oilfield_train/tex/oil_pipe_run.png` | 2 (one image for all 24 copies) | 16.1 px/m | 0 |
| [ ] | `oil_derrick` | `oilfield_train/tex/oil_derrick.png` | 2 (one image for all 10 copies) | 4.1 px/m | 0 |
| [ ] | `oil_tank` | `oilfield_train/tex/oil_tank.png` | 3 (one image for all 8 copies) | 9.4 px/m | 0 |
| [ ] | `oil_pylon` | `oilfield_train/tex/oil_pylon.png` | 1 (one image for all 8 copies) | 2.5 px/m | 0 |
| [ ] | `oil_burning_well` | `oilfield_train/tex/oil_burning_well.png` | 3 (`Well_Iron`, `Well_Flame`, `Well_LampGlass`; both copies share one image) | 25.1 px/m | 2 tiling meshes (`Well_Rock`, `Well_Dirt`) |
| [ ] | `oilfield_horizon` | `oilfield_train/tex/oilfield_horizon.png` | 2 (`Horizon_Flame`, `Horizon_LampGlass`; all 32 tiles share one image) | 12.4 px/m | 2 tiling meshes (`Horizon_Rock`, `Horizon_RockDark`) |
| n/a | `oilfield_terrain` | none | 0 | | 1 (`Oilfield_Ground`) |

Most of these are seen as silhouettes under orange light, so paint only what the key reaches (`docs/design/scenarios/oilfield_train.md` G16).

## Practice Hub (`practice_hub/practice_hub.blend`)

| Done | GLB | PNG | Meshes | Density | Left alone |
|---|---|---|---|---|---|
| [ ] | `practice_hub` | `practice_hub/tex/practice_hub.png` | 181 | 7.4 px/m | 10 |

## Canyon (`canyon/canyon.blend`)

| Done | GLB | PNG | Meshes | Density | Left alone |
|---|---|---|---|---|---|
| [ ] | `canyon` | `canyon/tex/canyon.png` | 25 (plants) | 13.7 px/m | 16 tiling meshes: the 4 cliff objects, the 2 cover objects, the floor, the 4 rim objects, and the 5 horizon rock and sand objects |

Density is set by the GLB's total surface area and by its longest single piece (an 8 m rail cannot be longer than 256 px). A dozen small pieces on a tiny GLB (`prp_hitching_rail`) get 97 px/m; the train's coach gets 12.5 px/m, so a 2 cm detail there is a quarter of a pixel; the final engine gets 10.5 px/m, the final baggage car 13.3 px/m, and the final business car 11.9 px/m. See the stats table in [`TEXTURING.md`](TEXTURING.md#what-the-unwrap-gave-each-glb).

## Stays flat (ground and rock)

Ground and rock keep their tiling UVs (one tile per 8 m), flat colour, and grain. They are not in any GLB's image and no tiling texture is decided (`TEXTURING.md` decision 12 of the paused sheet). Materials: `M_Sand`, `M_SandFar`, `M_Dirt`, `M_DirtFar`, `M_Rock`, `M_RockDark`, `M_Cap`, `M_CapDark`.

| Map | Meshes left alone |
|---|---|
| Main Street | `TerrainFlat`, `Track_Ballast` (the GLB `env_terrain`, and the ballast in `env_rail_track_8m`) |
| Train Rooftop | 11 rock objects (`horizon_ridge`: `Canyon_Rock`, `Canyon_RockDark`, `Canyon_CapDark`, `Canyon_Cap`, the same four `Mesa_*`, and `Butte_Rock`, `Butte_RockDark`, `Butte_Cap`) |
| Oil-field Train | `Oilfield_Ground` (the GLB `oilfield_terrain`), `Horizon_Rock` and `Horizon_RockDark` (`oilfield_horizon`), `Well_Rock` and `Well_Dirt` (`oil_burning_well`), `Wellhead_Dirt` (`oil_wellhead`), `Sump_Dirt` (`oil_sump`) |
| Practice Hub | `Lot`, `Desert`, `Berm`, 6 `Mesa*` |
| Canyon | The 4 cliff objects (`Cliffs_*`), the 2 cover objects (`Cover_*`), the floor (`Floor_Sand`), the 4 rim objects (`Rim_*`), and the horizon's plain, butte, and mesas (`Horizon_Desert`, `Horizon_CapDark`, `Horizon_RockDark`, `Horizon_Cap`, `Horizon_Rock`) |

## Not scenery (separate textures, already exist or undecided)

| Thing | State |
|---|---|
| Duelist mannequin (`characters/dummy.glb`) | One flat colour per duelist from `body_skin.gdshader`. Textured duelists need a decision |
| Outfit (`characters/gunslinger.glb`) | Painted `poncho_albedo.png` (512 px) exists. The model is not instanced in game yet |
| Revolver | 128 px atlas exists |
| Props: coin, ace | `msc_coin_*_tex.png` (128), `msc_ace_*_tex.png` (96×136) exist |
| Props: cigarette, longneck bottle | Flat vertex-coloured materials |
| PSX blaster (`weapons/wpn_psx_blaster.glb`) | Check its material before texturing |

## Paused: the shared trim sheet

The strips and the 16 photo cells (`assets/textures/trim_sheet.png`, `dev/build_trim_sheet.py`, `dev/trim_layout.py`, `assets/texture_src/strips/` and `cells/`) are kept but nothing in game uses them. Their lists are in the git history of this file and the paused section of [`TEXTURING.md`](TEXTURING.md#trim-sheet-on-scenery-paused).
