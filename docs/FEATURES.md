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
| Head / torso hitboxes (head 2×) | `done` | `player/hitbox.gd` |
| Early-draw foul | `done` | duel state machine |
| Near-miss slow-mo hook | `done` | `TimeManager.notify_near_miss`, `weapons/bullet.gd` |
| Gravity-drop / interactive reload | `planned` | Ammo `reset()` between duels only; see revolver comment |
| Kill-cam / replay | `partial` | `kill_cam_requested` emits trail points; no listener yet |
| Impact / AV polish (SFX, haptics, VFX) | `done` | `ImpactFeedback` + `AudioCatalog` / `VfxCatalog` stubs; combat XR/flat rumble wired |
| Regional hit effects (arm/leg/head rules) | `planned` | Hitbox `region` export ready; gameplay rules on Roadmap |
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
