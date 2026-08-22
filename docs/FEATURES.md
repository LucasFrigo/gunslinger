# Feature status

Living checklist of what the game can do. Agents update this when behavior lands or status changes.

Status: `done` | `partial` | `planned` | `blocked`  
Roadmap (future, by difficulty): [`../Roadmap.md`](../Roadmap.md)  
Open bugs: [`BUGS.md`](BUGS.md)

## Core duel

| Feature | Status | Notes / key paths |
|---|---|---|
| Standoff → bell → draw → resolve | `done` | `gauntlet/duel_manager.gd` |
| Holster / draw / fire / cock | `done` | `weapons/revolver/revolver.gd`, player rigs. VR grip is hold-to-hold; Flat RMB still toggles |
| Projectile bullets + trails | `done` | `weapons/bullet.gd`, `weapons/bullet_trail.gd`; ribbon uses one camera-facing side vector, first point at muzzle. Shorter linger is planned (`FADE_TIME` 1.6s) |
| Shorter bullet-trail fade | `planned` | Roadmap (Polish / visual); `weapons/bullet_trail.gd` |
| Barrel smoke | `planned` | Roadmap (Polish / visual); stub `muzzle_smoke` already fires from `ImpactFeedback.shot_fired` — wants a lingering plume from the barrel |
| Head / torso / arm / leg hitboxes | `done` | `player/hitbox.gd`, `combat/combat_rules.gd` |
| Regional hit effects | `done` | Head instakill; torso/limb 1 HP (default HP 2); arm force-holsters + redraw lock; leg slows move. MP host HP + `_mp_wound` |
| Self-damage | `done` | Player/peer bullets can hit the shooter after `self_hit_grace` (~0.28m) so a normal muzzle shot does not clip the gun-hand arm. Same regional HP / arm-disarm / leg-slow; a self-kill loses the duel (`You shot yourself`). AI still excludes its own hitboxes |
| Self-hit hitbox tweak | `planned` | Roadmap (Easy); tune shooter volumes (esp. gun-hand arm) so grace + hitboxes feel fair |
| Early-draw foul | `done` | duel state machine. Hits only apply during DRAW; a post-foul shot cannot overwrite the DQ |
| Near-miss slow-mo hook | `done` | `TimeManager.notify_near_miss`, `weapons/bullet.gd` |
| Gravity-drop / interactive reload | `done` | Gun-hand B opens; sustained shake dump; torso `AmmoBelt` + **off-hand** `ReloadProbe` overlap; `ChamberArea` seats; `BumpArea` bump or swing close (Flat `R`/Space). Layer `reload`. F3 **Show reload volumes**. Dump/swing in `GameManager.tuning`. Mesh-fit / cylinder-flip are art polish, not blockers |
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
| NPC reload | `planned` | Roadmap (Medium); AI `reset()`s ammo when empty today (`ai/duelist_ai.gd`) — wants a real reload window |
| Quest 3 / PCVR / flat harness | `done` | OpenXR + `--flat` |
| Ranking / leaderboards | `planned` | Roadmap |
| Mod support | `planned` | Roadmap |

## Tooling

| Feature | Status | Notes / key paths |
|---|---|---|
| Debug panel + presets | `done` | `autoload/debug_menu.gd`, `user://*.cfg` |
| In-game version tag | `done` | HUD corner + main menu; `ProjectSettings` `application/config/version` (`VERSION`) |
| Headless autotests | `done` | `dev/autotest.gd` |
| Quest APK sideload | `done` | `dev/install-quest.bat` (`adb install -r` → `builds/vr/gunslinger-quest.apk`) |
