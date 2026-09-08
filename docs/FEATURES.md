# Feature status

Living checklist of what the game can do. Agents update this when behavior lands or status changes.

Status: `done` | `partial` | `planned` | `blocked`  
Roadmap (future, by difficulty): [`../Roadmap.md`](../Roadmap.md)  
Open bugs: [`BUGS.md`](BUGS.md)  
Pre-release TODOs: [`RELEASE_TODOS.md`](RELEASE_TODOS.md)  
Design / lore: [`design/README.md`](design/README.md)

## Core duel

| Feature | Status | Notes / key paths |
|---|---|---|
| Standoff → bell → draw → resolve | `done` | `gauntlet/duel_manager.gd` |
| Holster / draw / fire / cock | `done` | `weapons/revolver/revolver.gd`, player rigs. VR grip is hold-to-hold; Flat RMB still toggles. VR cock is gun-hand A today; stick-down cock is planned |
| VR cock on stick-down | `planned` | Roadmap (Medium); gun-hand analog down cocks; A becomes trick-shot / Ocelot spin (`vr_rig.gd` `ax_button`, `player.gd` `_update_vr_spin`) |
| Button remapping | `planned` | Roadmap (Medium); Settings bind table → `PlayerSettings` / `user://settings.cfg` (VR + flat). None today |
| Projectile bullets + trails | `done` | `weapons/bullet.gd`, `weapons/bullet_trail.gd`; ribbon uses one camera-facing side vector, first point at muzzle. Shorter linger is planned (`FADE_TIME` 1.6s) |
| Shorter bullet-trail fade | `planned` | Roadmap (Polish / visual); `weapons/bullet_trail.gd` |
| Barrel smoke | `planned` | Roadmap (Polish / visual); stub `muzzle_smoke` already fires from `ImpactFeedback.shot_fired` — wants a lingering plume from the barrel |
| Head / torso / arm / leg hitboxes | `done` | `player/hitbox.gd`, `combat/combat_rules.gd` |
| Regional hit effects | `done` | Head instakill; torso/limb 1 HP (default HP 2); arm force-holsters + redraw lock; leg slows move. MP host HP + `_mp_wound` |
| Self-damage | `done` | Player/peer bullets can hit the shooter after `self_hit_grace` (~0.28m) on the **gun-hand arm only**, so a normal muzzle shot does not clip the forearm. Torso / head / off-hand / legs count immediately (muzzle into body, close miss). Same regional HP / arm-disarm / leg-slow; a self-kill loses the duel (`You shot yourself`). AI still excludes its own hitboxes |
| Self-hit hitbox tweak | `done` | Gun-hand arm is a thinner wrist-inset capsule along the limb (`Hitbox.place_along_limb`); off-hand uses a milder inset. Local player + remote avatar. Grace skips only that arm RID |
| Early-draw foul | `done` | duel state machine. Hits only apply during DRAW; a post-foul shot cannot overwrite the DQ |
| Near-miss slow-mo hook | `done` | `TimeManager.notify_near_miss`, `weapons/bullet.gd` |
| Gravity-drop / interactive reload | `done` | Gun-hand B opens; sustained shake dump; torso `AmmoBelt` + **off-hand** `ReloadProbe` overlap; `ChamberArea` seats; `BumpArea` bump or swing close (Flat `R` / Space). Layer `reload`. F3 **Show reload volumes**. Dump/swing in `GameManager.tuning`. Cylinder swings out on gate and indexes 60° per shot (`weapons/revolver/revolver.gd`) |
| Rapid-fire jam | `done` | Flat only (`revolver.jam_enabled`). Cadence heat in `weapons/weapon_base.gd`; jammed pull clicks and does not fire. Clear: look down + hold Space 1.5s. Knobs in debug **Flat Jam** (`jam_safe_interval`, `jam_heat_*`, `jam_chance_scale`, `jam_max_chance`, `jam_clear_hold`, `jam_clear_pitch`). VR / AI never jam |
| Kill-cam / replay | `done` | SP + 1v1 MP: `KillCam` + `TimeManager.notify_kill_cam`; flat `Camera3D` fly-along, VR spectator `XROrigin3D` ride; `duel_end` sting on lethal hit |
| Impact / AV polish (SFX, haptics, VFX) | `done` | `ImpactFeedback` + `AudioCatalog` / `VfxCatalog` stubs; combat XR/flat rumble wired |
| Gun release / trick shots | `done` | VR hold-to-hold: toss with hand velocity, catch either hand (or take from the other), holster snap on chosen hip (`holster_side`). Fire/reload only while held; airborne still counts as drawn for fouls. Frozen `RigidBody3D` copies the hand/hip pose (`follow_parent` in `weapons/weapon_base.gd`). MP pose sends free-gun transform + hand/hip flags |
| Revolver Ocelot spin | `done` | VR only: gun-hand stick down hangs the revolver on a finger hinge (`SpinPivot` / `WeaponBase`); hand motion builds momentum; stick up snaps back. Fire still works (muzzle aim). Debug **VR Spin**. MP flag `GUN_SPINNING` |
| Airborne fire / mystic trick shots | `planned` | Roadmap (Medium); fire while tossed/spinning; optional tech/mystic flag |

## Modes

| Feature | Status | Notes / key paths |
|---|---|---|
| Free duel (arena + AI pick) | `done` | `GameManager`, main menu |
| Duel vs up to 3 NPCs | `planned` | Roadmap (Medium); local 1–3 AI in one standoff |
| Gauntlet (6 rungs, 3 lives, session score) | `done` | `gauntlet/gauntlet_controller.gd`, ladder `.tres` |
| Persistent gauntlet high scores | `planned` | Score is session-only today |
| 1v1 LAN multiplayer | `done` | `netcode/enet_transport.gd` + UDP discovery; Quest APK gets `INTERNET` + Wi-Fi multicast from `addons/gunslinger_lan_permissions/` at export. **Meta Store SKU is LAN-only** (no Steam / Meta online). Remote avatar is a full greybox (torso/legs/arms + holstered gun). Joiner on `EnemySpawn` faces the host; walk/strafe is world-XZ from look yaw so the 180° spawn root does not invert A/D. Main menu: double-click a LAN host (or Steam lobby on desktop) to join |
| Proximity voice chat | `planned` | Roadmap (Polish / visual); spatial voice by distance; muted players show an X over the mouth |
| 1v1 Steam lobbies | `done` | `netcode/steam_transport.gd` + GodotSteam 4.22 in `addons/godotsteam/` (Steamworks 1.65). **Desktop / Steam SKU only** — hidden and gated off on Android. Create / browse / join public 1v1 lobbies; Steam Datagram Relay. App ID **480** (`steam_appid.txt` + `steam/initialization/app_id`). Windows export copies the App ID file via `addons/gunslinger_steam_export/`. `dev/autotest.gd` `steam` mode still passes if the addon is absent. Leave/rejoin in the same process is broken ([BUG-009](BUGS.md)) |
| MP version check | `planned` | Roadmap (Medium) / [BUG-008](BUGS.md); Steam stores `gunslinger_version` but join does not compare; LAN has no version metadata |
| 4-player multiplayer | `planned` | Roadmap (Hard); 2–4 humans (FFA / 2v2 / 1v3); netcode is 1v1 today. LAN on all SKUs; Steam N-player desktop-only |
| Horde mode | `planned` | Roadmap |
| Mexican standoff (3P) | `planned` | Needs netcode beyond 1v1; related to 4-player MP |
| Campaign | `planned` | Roadmap |

## Content & platforms

| Feature | Status | Notes / key paths |
|---|---|---|
| Revolver mesh | `done` | PSX blaster `assets/models/weapons/wpn_psx_blaster.glb` (cylinder + gate/index anim). Pre-cylinder mesh kept as `wpn_psx_blaster_alt.glb`. Greybox `Barrel` / `Cylinder` / `Grip` stay hidden |
| Gunslinger character mesh | `partial` | Low-poly A-pose (empty hands) at `assets/models/characters/gunslinger.glb` + Blender source `gunslinger.blend`. Split serape/black poncho is a separate Cloth sim (baked for the GLB). Not on AI or the remote avatar yet |
| Arenas (Main Street, Saloon, Train Rooftop, Canyon) | `partial` | Greybox CSG; real art TBD |
| Moving train duel set piece | `planned` | Roadmap; rooftop arena exists as greybox |
| AI archetypes (Drunk / Sheriff / Ghost) | `done` | `ai/archetypes/*.tres`; Sheriff/Ghost strafe around the enemy spawn marker (not scene origin). `reload_time` per archetype. Design: [Drunk](design/characters/drunk.md), [Sheriff](design/characters/sheriff.md), [Ghost](design/characters/ghost.md) |
| More enemy NPCs | `planned` | Roadmap (Medium); extra archetypes as new `ai/archetypes/*.tres`, then free-duel pick + gauntlet rungs. First design: [Half-head](design/characters/half-head.md) |
| NPC reload | `done` | Spent cylinder is a combat window: `AIState.RELOADING`, arm dip, `open_gate` → wait `reload_time` (Drunk 3.5 / Sheriff 2.2 / Ghost 1.4, scaled by `ai_speed_mult`) → `fill_cylinder` / `close_gate`. Same 6-round limit as the player. Arm hit / death / duel-over cancel and close the gate; ammo stays empty across disarm. `ai/duelist_ai.gd`, `WeaponBase.fill_cylinder` |
| Quest 3 / PCVR / flat harness | `done` | OpenXR + `--flat`. Meta Store APK: LAN MP only; Steam lobby UI is hidden |
| Ranking / leaderboards | `planned` | Roadmap (Hard); Steam / desktop. Not on Meta Store |
| Mod support | `planned` | Roadmap |

## Tooling

| Feature | Status | Notes / key paths |
|---|---|---|
| Debug panel + presets | `done` | `autoload/debug_menu.gd`, `user://*.cfg` |
| Settings screen (main menu) | `done` | `ui/settings_menu.tscn` on main menu and pause. Master volume, holster side, VR turn mode; flat-only mouse sensitivity, window mode, resolution (**Apply Display** applies video immediately). `PlayerSettings` → `user://settings.cfg`. Debug panel stays F3 / Quest menu on the main menu |
| In-duel pause / MP overlay | `done` | ESC (flat) / VR menu button. SP sets `get_tree().paused`; MP is overlay-only. Resume, Settings, Restart Duel/Gauntlet (host-only in MP), Quit to main menu. `ui/pause_menu.tscn` |
| Blender MCP | `done` | Project `.cursor/mcp.json` → `uvx blender-mcp` → Blender addon on `localhost:9876`. Client helper `dev/blender_mcp.py` |
| In-game version tag | `done` | HUD corner + main menu; `ProjectSettings` `application/config/version` (`VERSION`) |
| Headless autotests | `done` | `dev/autotest.gd` (`duel`, `gauntlet`, `load`, `host`, `join`, `steam`) |
| Quest APK sideload | `done` | `dev/install-quest.bat` (`adb install -r` → `builds/vr/gunslinger-quest.apk`) |
