# Architecture

How major systems fit together. Keep this short; link to files. Update when ownership or flow changes.

## Runtime stack

- **Engine:** Godot 4.6+/4.7, GDScript, GL Compatibility.
- **XR:** OpenXR + `addons/godot-xr-tools` (hands/pickup toolkit available; core duel loop is custom).
- **Targets:** Quest 3 (Android), PCVR, flat desktop harness (`--flat` or no OpenXR runtime).

## Entry & scene flow

1. `main.tscn` / `main.gd` boots, chooses VR vs flat rig.
2. Main menu (`ui/`) → free duel / gauntlet / host-join MP.
3. `GameManager` loads a scenario (`scenarios/`) and wires player + AI or remote peer.
4. `gauntlet/duel_manager.gd` owns the duel state machine (standoff → bell → draw → resolve).

## Autoloads

| Autoload | Role |
|---|---|
| `TimeManager` | `Engine.time_scale` slow-mo modes; SP only (disabled in network sessions) |
| `NetworkManager` | Session lifecycle; picks ENet or Steam transport |
| `GameManager` | Mode selection, scenario list, high-level flow |
| `MovementConfig` | Flat/VR movement knobs → `user://movement.cfg` |
| `DebugPresets` / `DebugMenu` | Live tuning + named presets |
| `ImpactFeedback` | Combat SFX / VFX / haptics (`AudioCatalog`, `VfxCatalog`, `CombatHaptics`) |

## Combat

- **Weapons:** `WeaponBase` → revolver; muzzle marker; cock/fire/holster; fire kick via `ImpactFeedback.shot_fired`.
- **Bullets:** Real projectiles (`weapons/bullet.gd`), not hitscan; feed trails; near-miss check vs player head; world/body impact feedback on ray hit.
- **Damage:** Host-authoritative in MP; head 2× / torso 1× via `player/hitbox.gd` (`region` for AV + future limb rules).
- **Feedback:** `ImpactFeedback` autoload — spatial stubs (`assets/audio/`), one-shot particles (`assets/vfx/`), XR rumble + flat joy vibration (`assets/haptics/`).
- **Kill-cam hook:** `DuelManager.kill_cam_requested(trail_points)` — emit only until a replay consumer exists.

## AI

- Data-driven `AIArchetype` resources (reaction, accuracy cone, draw speed, movement).
- Encounter ladder: `DuelEncounter` + `GauntletLadder` `.tres` files — prefer data over code for new rungs.

## Multiplayer

- Interface in `netcode/`; `enet_transport.gd` (LAN + UDP discovery), `steam_transport.gd` (optional addon).
- Pose / shot sync; host validates hits; auto rematch. Slow-mo off while networked.

## Config / user data

Persisted under `user://`: `slowmo.cfg`, `movement.cfg`, `tuning.cfg`, `debug_presets.cfg`.

## Tests

`dev/autotest.gd` — headless `--autotest=duel|gauntlet|load|host|join`. Prefer extending these when changing duel or load paths.
