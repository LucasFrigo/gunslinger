# Gunslinger VR — Wild West Gun Duels

A Godot 4.x VR dueling game: single-player gauntlet against AI gunslingers and
1v1 multiplayer over LAN (dev) or Steam lobbies (shipping). Bullets are real
slow projectiles with Superhot-style visible trajectories, and slow motion is
fully tunable at runtime so you can A/B test what feels best.

**Version:** see [`VERSION`](VERSION) · **Changelog:** [`CHANGELOG.md`](CHANGELOG.md)  
**Feature status:** [`docs/FEATURES.md`](docs/FEATURES.md) · **Architecture:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Bugs:** [`docs/BUGS.md`](docs/BUGS.md) · **Roadmap:** [`Roadmap.md`](Roadmap.md)  
**Business / pricing brief:** [`docs/BUSINESS_BRIEF.md`](docs/BUSINESS_BRIEF.md)

## Requirements

- **Godot 4.6+** (developed against 4.7 stable), standard build (GDScript).
- For Quest 3 export: Android SDK + OpenJDK 17 configured in Godot's Editor
  Settings, developer mode enabled on the headset
  ([official guide](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html)).
- For Steam multiplayer (optional, desktop only): the
  [GodotSteam GDExtension](https://godotsteam.com) 4.20+, dropped into
  `addons/godotsteam/`. The game runs fine without it (Steam UI is disabled,
  LAN still works). Uses app ID 480 (Spacewar) until the game has its own.

## Running

| What | How |
|---|---|
| Flat (desktop test harness) | Run the project. Without an OpenXR runtime it falls back to flat mode automatically; force it with `--flat` or the `Windows (Flat Test)` export. |
| PCVR | Have an OpenXR runtime active (SteamVR / Quest Link) and run the project. |
| Quest 3 standalone | Use the `Quest 3 (Android)` export preset with one-click deploy (headset connected over USB, gradle build enabled). After export, `dev\install-quest.bat` sideloads `builds/vr/gunslinger-quest.apk` over ADB. |

### Multiplayer test loop (Quest 3 vs notebook)

1. Both devices on the **same Wi-Fi** (not a guest/client-isolation SSID). The
   notebook's Windows Firewall must allow the game (UDP **9099** gameplay,
   UDP **9100** discovery) on a private network.
2. Notebook: run the flat build, click **HOST (LAN)**. The HUD shows the LAN
   IP to type if discovery misses.
3. Quest: deploy/launch a **fresh export** of the APK (LAN permissions are injected at export by `addons/gunslinger_lan_permissions/`), the notebook appears in the LAN
   host list — select it and **JOIN**. The IP field is a fallback.
   Steam Link + Play from the Godot editor is PCVR on Windows and does **not**
   test the Quest APK.
4. The host starts the duel automatically when the peer connects.

Steam flow (two desktop machines with Steam running): **HOST (STEAM)** on one,
**REFRESH LOBBIES** + join on the other. Same gameplay code; only the
transport differs (`netcode/enet_transport.gd` vs `netcode/steam_transport.gd`).

## Controls

| Action | VR (Quest 3) | Flat |
|---|---|---|
| Draw | Grip near the chosen hip (debug **Holster side**) | Right mouse button toggles |
| Hold / toss / holster | Hold grip to keep the gun; release near a still hip to holster, or flick to toss | Right mouse button toggles |
| Catch / swap hands | Grip near a tossed gun (either hand) or grip near the gun in the other hand | — |
| Fire | Gun-hand trigger (right if right-held, left if left-held) | Left mouse button |
| Cock hammer (single-action) | Gun-hand A | Space (closes gate if open) |
| Reload | Gun-hand B opens the gate; shake that hand to dump; off-hand in belt + grip for a round; release near cylinder; bump/swing close. Left B is debug menu unless the gun is left-held. | `R` open+dump, `R` chamber, Space close |
| Menu pointer | Right controller laser + trigger | Mouse |
| Move / lean | Left stick move, right stick turn | WASD / Q + E |
| Debug / tuning panel | Quest menu button (always); left B when the gun is not left-held | F3 |

Reload dump/close feel: F3 → **Gunplay / AI** → **VR Reload** sliders (`reload_dump_speed`, `reload_dump_hold`, `reload_swing_close`, `reload_bump_close`), persisted in `user://tuning.cfg`. **VR Gun Release** has **Holster side** (right/left hip) plus `gun_catch_radius`, `gun_holster_max_speed`, `gun_throw_scale`, `gun_throw_spin_scale`. **Show reload volumes** draws the belt / chamber / bump / both-hand probe shapes (edit those `CollisionShape3D`s in the scenes to fit future meshes). Regional hit knobs (`player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`) live under **Regional Hits** in the same panel.

## Slow motion (single-player only)

`autoload/time_manager.gd` drives `Engine.time_scale`. Modes, selectable and
tunable live in the debug panel (persisted to `user://slowmo.cfg`):

- **CONSTANT** — always slowed.
- **ON_DRAW** — slows the moment the enemy starts drawing.
- **MOVEMENT** — Superhot: time speed follows your physical head/hand speed
  (plus stick locomotion in VR / WASD in flat).
- **NEAR_MISS** — bullet-time burst when a bullet passes near your head.

Slow motion is hard-disabled whenever a network session is active.

The debug panel also exposes Flat/VR movement knobs (`user://movement.cfg`),
gunplay/AI tuning (`user://tuning.cfg`), **named presets** (Save / Load /
Delete snapshots of all tunables in `user://debug_presets.cfg`), **Reset duel**
(restart the current free duel / gauntlet encounter / host MP rematch), and
**Back to main menu**.

## Project structure

```
autoload/    game_manager, network_manager, time_manager (slow-mo),
             movement_config, debug_presets, debug_menu
player/      player body + hitboxes, VR rig, flat rig, remote avatar
combat/      shared hit resolution (head/torso/arm/leg)
weapons/     weapon_base, revolver, bullet + trajectory trail
ai/          duelist AI + data-driven archetypes (*.tres)
scenarios/   scenario template (resource + base scene contract) + 4 greybox arenas
gauntlet/    duel state machine, gauntlet controller, encounter ladder (*.tres)
netcode/     transport interface, ENet (LAN), Steam, LAN discovery
ui/          main menu, HUD, 3D UI panel (VR menus)
assets/      drop real models/textures/audio here (placeholders are procedural)
addons/      godot-xr-tools (hands/pickup/teleport toolkit for expansion)
```

## Extending (data-driven by design)

- **New scenario**: duplicate a folder in `scenarios/`, keep the
  `ScenarioBase` contract (PlayerSpawn/EnemySpawn markers), create a
  `ScenarioResource` .tres, add its path to `GameManager.SCENARIOS`.
  Greybox CSG nodes are named after the assets that will replace them
  (`BLD_*` buildings, `PRP_*` props, `GND_*` ground, `RCK_*` rocks).
- **New enemy**: create an `AIArchetype` .tres (reaction time, accuracy cone,
  draw speed, movement) — no code changes.
- **New tower**: create `DuelEncounter` .tres files and a `GauntletLadder`.
- **New weapon**: extend `WeaponBase`, place a `Muzzle` marker.

## Headless smoke tests

`dev/autotest.gd` runs end-to-end checks without a window or headset:

```powershell
godot --headless --path . -- --autotest=duel      # AI duel resolves via real bullets
godot --headless --path . -- --autotest=gauntlet  # gauntlet progression
godot --headless --path . -- --autotest=load      # every scene/resource loads
# multiplayer: run host first, then join in a second terminal
godot --headless --path . -- --autotest=host
godot --headless --path . -- --autotest=join
```

Each prints `AUTOTEST PASS` / `AUTOTEST FAIL` and sets the process exit code
(CI-friendly).

## Git LFS

`.gitattributes` routes binary assets (models, textures, audio) through Git
LFS. Run `git lfs install` once before committing real assets.
