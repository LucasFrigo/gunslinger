# Architecture

How major systems fit together. Keep this short; link to files. Update when ownership or flow changes.

## Runtime stack

- **Engine:** Godot 4.6+/4.7, GDScript, GL Compatibility.
- **XR:** OpenXR + `addons/godot-xr-tools` (hands/pickup toolkit available; core duel loop is custom).
- **Targets:** Quest 3 (Android), PCVR, flat desktop harness (`--flat` or no OpenXR runtime).

## Entry & scene flow

1. `main.tscn` / `main.gd` boots, chooses VR vs flat rig.
2. Main menu (`ui/`) → free duel / gauntlet / host-join MP. Menu and flat HUD show `v` + `application/config/version`.
3. `GameManager` loads a scenario (`scenarios/`) and wires player + AI or remote peer.
4. `gauntlet/duel_manager.gd` owns the duel state machine (standoff → bell → draw → resolve).

## Autoloads

| Autoload | Role |
|---|---|
| `TimeManager` | `Engine.time_scale` slow-mo modes (SP); kill-cam burst also in MP after RESOLUTION |
| `NetworkManager` | Session lifecycle; picks ENet or Steam transport |
| `GameManager` | Mode selection, scenario list, high-level flow |
| `MovementConfig` | Flat/VR movement knobs → `user://movement.cfg` |
| `DebugPresets` / `DebugMenu` | Live tuning + named presets |
| `ImpactFeedback` | Combat SFX / VFX / haptics (`AudioCatalog`, `VfxCatalog`, `CombatHaptics`) |
| `KillCam` | Trail fly-along kill cam (flat `Camera3D`, VR spectator `XROrigin3D`); SP + 1v1 MP; gates post-duel delays |

## Combat

- **Weapons:** `WeaponBase` (`RigidBody3D`) → revolver. Carry states: holstered / held (either hand) / free (simulating). Fire, cock, and reload require `held`; `drawn` stays true while airborne (duel foul / STANDOFF). `attach_to` / `release_into_world` / `holster_to` in `weapons/weapon_base.gd`. Frozen bodies do not inherit parent motion: while `follow_parent` is set, `_sync_follow_parent()` copies the holster or `GunAttach` pose each process/physics frame. VR Ocelot soft-lock: gun-hand stick down (`primary` Y) hinges the held gun at `SpinPivot` (parent local X); stick up tweens back to identity. While held, that hand's stick Y is not used for locomotion. Layer `weapon` (6) vs world when tossed. VR grip is hold-to-hold; toss uses controller linear+angular velocity (plus hinge omega if spinning). Catch either hand or take from the other. `holster_side` (0 right / 1 left, debug menu) chooses the hip for draw/holster snap. Gun-hand gets trigger/A/B and shake-dump; off-hand gets belt `ReloadProbe` / `CartridgeAttach` and bump-close. Left B is gate while left-held, otherwise debug menu. Flat: RMB still toggles; `R` / Space reload. Dump/swing in `GameManager.tuning`; **Show reload volumes** on device. Status on `Hud.ReloadStatus` + VR `Label3D`. Flat-only rapid-fire jam: cadence heat in `try_fire` (`jam_enabled` on the local Flat revolver); jammed pull dry-clicks and does not fire; clear by looking down and holding Space (`jam_clear_hold` / `jam_clear_pitch`). VR and AI never jam.
- **Bullets:** Real projectiles (`weapons/bullet.gd`), not hitscan; feed trails; near-miss check vs player head; world/body impact feedback on ray hit. Player/peer shots keep shooter hitbox RIDs but ignore those hits inside `self_hit_grace` of the muzzle so a forward shot does not clip the gun arm; after that distance self-hits apply. AI bullets keep a full self-exclude.
- **Damage:** Host-authoritative in MP. Hits apply only while `DuelManager.accepts_hits()` (state `DRAW`); `Hitbox.receive_hit` and `mp_report_hit` no-op in `IDLE` / standoff / wait-for-bell / `RESOLUTION`, so a post-foul shot cannot overwrite a DQ. `CombatRules` (`combat/combat_rules.gd`): head always kills; torso/arm/leg subtract `Hitbox.damage_mult` HP (default player HP 2). Surviving arm hits force-holster + block redraw; leg hits apply a timed move-speed penalty. A self-kill loses the duel (SP reason `You shot yourself`). Non-fatal MP wounds sync via `DuelManager._mp_wound`. `Hitbox.region` also drives AV. `_finish_sp` is idempotent once `RESOLUTION` is set.
- **Feedback:** `ImpactFeedback` autoload — spatial stubs (`assets/audio/`), one-shot particles (`assets/vfx/`), XR rumble + flat joy vibration (`assets/haptics/`).
- **Kill cam:** `DuelManager.kill_cam_requested(trail_points)` → `KillCam` (SP and 1v1 MP). Flat: cinematic fly-along `Camera3D`. VR: spectator `XROrigin3D` ride (player rig stays put) + `XRToolsFade`. `TimeManager.notify_kill_cam` burst allowed in MP; other slow-mo stays SP. Lethal sting: `AudioCatalog` `&"duel_end"` on `notify_kill_shot`.

## AI

- Data-driven `AIArchetype` resources (reaction, accuracy cone, draw speed, movement).
- SP spawn: `GameManager._begin_ai_duel` instantiates `ai/duelist.tscn`, assigns `ScenarioBase.get_enemy_spawn()`, then `DuelistAI.capture_spawn()` (`global_position`). Do not snapshot position in `_ready` — that runs at packed-scene origin before placement. Sheriff/Ghost strafe around that captured origin; Drunk stands.
- Encounter ladder: `DuelEncounter` + `GauntletLadder` `.tres` files — prefer data over code for new rungs.

## Multiplayer

- Interface in `netcode/`; `enet_transport.gd` (LAN + UDP discovery), `steam_transport.gd` (optional addon).
- LAN discovery (`lan_discovery.gd`): host beacon on UDP 9100 answers pings and announces `ip|name` on `255.255.255.255` plus subnet `.255`. Gameplay ENet is UDP 9099, bound to IPv4 `0.0.0.0`.
- Quest Android export: `addons/gunslinger_lan_permissions/` injects `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, and `CHANGE_WIFI_MULTICAST_STATE` into the manifest at gradle export (also set on `export_presets.cfg`). Without `INTERNET`, `create_server` fails with "Can't create" on device. Steam Link + editor is Windows networking, not the APK.
- Pose / shot sync; host validates hits and HP; non-fatal wounds via `_mp_wound`; auto rematch. Gameplay slow-mo off while networked; kill-cam burst still plays after `RESOLUTION` from `_mp_finish` trail points. Pose RPC is `head, left, right, flags, gun_transform`. Flags: `GUN_DRAWN`, `GUN_COCKED`, `GUN_FREE`, `HOLSTER_LEFT`, `GUN_HELD_LEFT`, `GUN_SPINNING`. Remote interpolates a free or spinning gun; does not simulate physics.
- `RemoteAvatar` (`player/remote_avatar.tscn`): pose-driven head/hands plus torso/leg meshes and shoulder-to-hand arms. Revolver sits on the chosen hip until drawn, parents to left or right hand (identity, or interpolated world pose while `GUN_SPINNING`), or follows the free-gun transform.
- MP spawn: host on `PlayerSpawn`, joiner on `EnemySpawn`. `reset_for_duel` copies the marker transform onto the Player root. Flat look yaw is stored local to that root (do not apply marker yaw twice). VR `reset_locomotion` yaws the origin so the HMD faces the marker -Z. Flat walk and VR stick locomotion apply in world XZ (`global_position`) from look yaw so the joiner's 180° root does not invert strafe.

## Config / user data

Persisted under `user://`: `slowmo.cfg`, `movement.cfg`, `tuning.cfg`, `debug_presets.cfg`.

Build identity is `VERSION` (mirrored in `project.godot` → `application/config/version`). `python dev/bump_version.py patch|minor` updates both; pushes to `main` that change code also auto-bump via `.github/workflows/bump-version.yml` if `VERSION` was not already updated.

## Tests

`dev/autotest.gd` — headless `--autotest=duel|gauntlet|load|host|join`. Prefer extending these when changing duel or load paths.
