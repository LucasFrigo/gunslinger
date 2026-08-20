# Feature status

Living checklist of what the game can do. Agents update this when behavior lands or status changes.

Status: `done` | `partial` | `planned` | `blocked`  
Roadmap (future, by difficulty): [`../Roadmap.md`](../Roadmap.md)  
Open bugs: [`BUGS.md`](BUGS.md)

## Core duel

| Feature | Status | Notes / key paths |
|---|---|---|
| Standoff → bell → draw → resolve | `done` | `gauntlet/duel_manager.gd` |
| Holster / draw / fire / cock | `done` | `weapons/revolver/revolver.gd`, player rigs |
| Projectile bullets + trails | `done` | `weapons/bullet.gd`, `weapons/bullet_trail.gd`; ribbon uses one camera-facing side vector, first point at muzzle |
| Head / torso / arm / leg hitboxes | `done` | `player/hitbox.gd`, `combat/combat_rules.gd` |
| Regional hit effects | `done` | Head instakill; torso/limb 1 HP (default HP 2); arm force-holsters + redraw lock; leg slows move. MP host HP + `_mp_wound` |
| Early-draw foul | `done` | duel state machine |
| Near-miss slow-mo hook | `done` | `TimeManager.notify_near_miss`, `weapons/bullet.gd` |
| Gravity-drop / interactive reload | `partial` | B open; sustained shake dump; torso belt + physical `CartridgePhysical`; bump/swing close (Flat `R`/Space). VR volumes: belt AABB 0.9×0.55×0.55 m, chamber 0.14 m. Dump/close thresholds in `GameManager.tuning` + debug sliders. Flip + VR volume polish TBD |
| Rapid-fire jam | `planned` | Roadmap (Medium); jam chance scales with shot cadence (Flat spam vs VR) |
| Kill-cam / replay | `done` | SP + 1v1 MP: `KillCam` + `TimeManager.notify_kill_cam`; flat `Camera3D` fly-along, VR spectator `XROrigin3D` ride; `duel_end` sting on lethal hit |
| Impact / AV polish (SFX, haptics, VFX) | `done` | `ImpactFeedback` + `AudioCatalog` / `VfxCatalog` stubs; combat XR/flat rumble wired |
| Gun release / trick shots | `planned` | Roadmap |

## Modes

| Feature | Status | Notes / key paths |
|---|---|---|
| Free duel (arena + AI pick) | `done` | `GameManager`, main menu |
| Duel vs up to 3 NPCs | `planned` | Roadmap (Medium); local 1–3 AI in one standoff |
| Gauntlet (6 rungs, 3 lives, session score) | `done` | `gauntlet/gauntlet_controller.gd`, ladder `.tres` |
| Persistent gauntlet high scores | `planned` | Score is session-only today |
| 1v1 LAN multiplayer | `done` | `netcode/enet_transport.gd` + UDP discovery; Quest APK gets `INTERNET` + Wi-Fi multicast from `addons/gunslinger_lan_permissions/` at export. Remote avatar is a full greybox (torso/legs/arms + holstered gun). Joiner on `EnemySpawn` faces the host; walk/strafe is world-XZ from look yaw so the 180° spawn root does not invert A/D. Main menu: double-click a LAN host (or Steam lobby) to join |
| 1v1 Steam lobbies | `partial` | `netcode/steam_transport.gd`; addon optional / may be absent |
| 4-player multiplayer | `planned` | Roadmap (Hard); 2–4 humans (FFA / 2v2 / 1v3); netcode is 1v1 today |
| Horde mode | `planned` | Roadmap |
| Mexican standoff (3P) | `planned` | Needs netcode beyond 1v1; related to 4-player MP |
| Campaign | `planned` | Roadmap |

## Content & platforms

| Feature | Status | Notes / key paths |
|---|---|---|
| Arenas (Main Street, Saloon, Train Rooftop, Canyon) | `partial` | Greybox CSG; real art TBD |
| Moving train duel set piece | `planned` | Roadmap; rooftop arena exists as greybox |
| AI archetypes (Drunk / Sheriff / Ghost) | `done` | `ai/*.tres`; Sheriff/Ghost strafe around the enemy spawn marker (not scene origin) |
| Quest 3 / PCVR / flat harness | `done` | OpenXR + `--flat` |
| Ranking / leaderboards | `planned` | Roadmap |
| Mod support | `planned` | Roadmap |

## Tooling

| Feature | Status | Notes / key paths |
|---|---|---|
| Debug panel + presets | `done` | `autoload/debug_menu.gd`, `user://*.cfg` |
| Headless autotests | `done` | `dev/autotest.gd` |
| Quest APK sideload | `done` | `dev/install-quest.bat` (`adb install -r` → `builds/vr/gunslinger-quest.apk`) |
