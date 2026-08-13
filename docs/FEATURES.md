# Feature status

Living checklist of what the game can do. Agents update this when behavior lands or status changes.

Status: `done` | `partial` | `planned` | `blocked`  
Roadmap (future, by difficulty): [`../Roadmap.md`](../Roadmap.md)

## Core duel

| Feature | Status | Notes / key paths |
|---|---|---|
| Standoff → bell → draw → resolve | `done` | `gauntlet/duel_manager.gd` |
| Holster / draw / fire / cock | `done` | `weapons/revolver/revolver.gd`, player rigs |
| Projectile bullets + trails | `done` | `weapons/bullet.gd`, `weapons/bullet_trail.gd` |
| Head / torso / arm / leg hitboxes | `done` | `player/hitbox.gd`, `combat/combat_rules.gd` |
| Regional hit effects | `done` | Head instakill; torso/limb 1 HP (default HP 2); arm force-holsters + redraw lock; leg slows move. MP host HP + `_mp_wound` |
| Early-draw foul | `done` | duel state machine |
| Near-miss slow-mo hook | `done` | `TimeManager.notify_near_miss`, `weapons/bullet.gd` |
| Gravity-drop / interactive reload | `partial` | B open; sustained shake dump; torso belt + physical `CartridgePhysical`; bump/swing close (Flat `R`/Space). Dump/close thresholds in `GameManager.tuning` + debug sliders. Flip polish TBD |
| Kill-cam / replay | `done` | SP only: `KillCam` + `TimeManager.notify_kill_cam`; flat cinematic trail fly-along, VR HMD + slow-mo |
| Impact / AV polish (SFX, haptics, VFX) | `done` | `ImpactFeedback` + `AudioCatalog` / `VfxCatalog` stubs; combat XR/flat rumble wired |
| Gun release / trick shots | `planned` | Roadmap |

## Modes

| Feature | Status | Notes / key paths |
|---|---|---|
| Free duel (arena + AI pick) | `done` | `GameManager`, main menu |
| Gauntlet (6 rungs, 3 lives, session score) | `done` | `gauntlet/gauntlet_controller.gd`, ladder `.tres` |
| Persistent gauntlet high scores | `planned` | Score is session-only today |
| 1v1 LAN multiplayer | `done` | `netcode/enet_transport.gd`, discovery |
| 1v1 Steam lobbies | `partial` | `netcode/steam_transport.gd`; addon optional / may be absent |
| Horde mode | `planned` | Roadmap |
| Mexican standoff (3P) | `planned` | Needs netcode beyond 1v1 |
| Campaign | `planned` | Roadmap |

## Content & platforms

| Feature | Status | Notes / key paths |
|---|---|---|
| Arenas (Main Street, Saloon, Train Rooftop, Canyon) | `partial` | Greybox CSG; real art TBD |
| Moving train duel set piece | `planned` | Roadmap; rooftop arena exists as greybox |
| AI archetypes (Drunk / Sheriff / Ghost) | `done` | `ai/*.tres` |
| Quest 3 / PCVR / flat harness | `done` | OpenXR + `--flat` |
| Ranking / leaderboards | `planned` | Roadmap |
| Mod support | `planned` | Roadmap |

## Tooling

| Feature | Status | Notes / key paths |
|---|---|---|
| Debug panel + presets | `done` | `autoload/debug_menu.gd`, `user://*.cfg` |
| Headless autotests | `done` | `dev/autotest.gd` |
