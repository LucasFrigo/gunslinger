# Architecture

How major systems fit together. Keep this short; link to files. Update when ownership or flow changes.

Pre-release TODOs: [`RELEASE_TODOS.md`](RELEASE_TODOS.md).

## Runtime stack

- **Engine:** Godot 4.6+/4.7, GDScript, GL Compatibility.
- **XR:** OpenXR + `addons/godot-xr-tools` (hands/pickup toolkit available; core duel loop is custom).
- **Targets:** Quest 3 (Android), PCVR, flat desktop harness (`--flat` or no OpenXR runtime).

## Entry & scene flow

1. `main.tscn` / `main.gd` boots, chooses VR vs flat rig.
2. Main menu (`ui/main_menu.tscn`) → free duel / gauntlet / host-join MP, plus a Settings page (`ui/settings_menu.tscn`). Menu and flat HUD show `v` + `application/config/version`.
3. In-match overlay (`ui/pause_menu.tscn`): ESC / VR menu button. Single-player pauses the scene tree; multiplayer does not (host clock and pose stream keep running). Local fire is suppressed while the overlay is up.
4. `GameManager` loads a scenario (`scenarios/`) and wires player + AI or remote peer.
5. `gauntlet/duel_manager.gd` owns the duel state machine (standoff → bell → draw → resolve).

## Autoloads

| Autoload | Role |
|---|---|
| `TimeManager` | `Engine.time_scale` slow-mo modes (SP); kill-cam burst also in MP after RESOLUTION |
| `NetworkManager` | Session lifecycle; picks ENet or Steam transport. Desktop: one long-lived `SteamTransport` for init, `run_callbacks`, and lobby browse; session `transport` points at it while hosting/joining Steam. |
| `GameManager` | Mode selection, scenario list, high-level flow |
| `PlayerSettings` | Master volume + flat window mode/resolution → `user://settings.cfg` |
| `MovementConfig` | Flat/VR movement knobs → `user://movement.cfg` |
| `DebugPresets` / `DebugMenu` | Live tuning + named presets |
| `ImpactFeedback` | Combat SFX / VFX / haptics (`AudioCatalog`, `VfxCatalog`, `CombatHaptics`) |
| `KillCam` | Trail fly-along kill cam (flat `Camera3D`, VR spectator `XROrigin3D`); SP + 1v1 MP; gates post-duel delays |

## Combat

- **Weapons:** `WeaponBase` (`RigidBody3D`) → revolver. Visual is `assets/models/weapons/wpn_psx_blaster.glb` instanced as `Model` on `weapons/revolver/revolver.tscn` (pre-cylinder copy: `wpn_psx_blaster_alt.glb`). Greybox `Barrel` / `Cylinder` / `Grip` stay hidden. Live drum is `Model/WPN_PSX_Blaster/CylinderPivot/Cylinder`: gate yaws the pivot, shots index the drum 60°, muzzle kick is visual-only on `Model` so aim markers stay put. Carry states: holstered / held (either hand) / free (simulating). Fire, cock, and reload require `held`; `drawn` stays true while airborne (duel foul / STANDOFF). `attach_to` / `release_into_world` / `holster_to` in `weapons/weapon_base.gd`. Frozen bodies do not inherit parent motion: while `follow_parent` is set, `_sync_follow_parent()` copies the holster or `GunAttach` pose each process/physics frame. VR Ocelot soft-lock: gun-hand stick down (`primary` Y) hinges the held gun at `SpinPivot` (parent local X); stick up tweens back to identity. While held, that hand's stick Y is not used for locomotion. Layer `weapon` (6) vs world when tossed. VR grip is hold-to-hold; toss uses controller linear+angular velocity (plus hinge omega if spinning). Catch either hand or take from the other. `holster_side` (0 right / 1 left, Settings) chooses the hip for draw/holster snap. Gun-hand gets trigger/A/B and shake-dump; off-hand gets belt `ReloadProbe` / `CartridgeAttach` and bump-close. Left B is gate while left-held, otherwise debug menu. Flat: RMB still toggles; `R` / Space reload. Dump/swing in `GameManager.tuning`; **Show reload volumes** on device. Status on `Hud.ReloadStatus` + VR `Label3D`. Flat-only rapid-fire jam: cadence heat in `try_fire` (`jam_enabled` on the local Flat revolver); jammed pull dry-clicks and does not fire; clear by looking down and holding Space (`jam_clear_hold` / `jam_clear_pitch`). VR and AI never jam.
- **Bullets:** Real projectiles (`weapons/bullet.gd`), not hitscan; feed trails; near-miss check vs player head; world/body impact feedback on ray hit. Player/peer shots keep shooter hitbox RIDs but ignore only the **gun-hand arm** inside `self_hit_grace` of the muzzle so a forward shot does not clip the forearm; torso / head / off-hand / legs can be hit immediately (muzzle into body). Arm volumes are limb capsules with wrist inset (`Hitbox.place_along_limb` on the local player and remote avatar). AI bullets keep a full self-exclude.
- **Damage:** Host-authoritative in MP. Hits apply only while `DuelManager.accepts_hits()` (state `DRAW`); `Hitbox.receive_hit` and `mp_report_hit` no-op in `IDLE` / standoff / wait-for-bell / `RESOLUTION`, so a post-foul shot cannot overwrite a DQ. `CombatRules` (`combat/combat_rules.gd`): head always kills; torso/arm/leg subtract `Hitbox.damage_mult` HP (default player HP 2). Surviving arm hits force-holster + block redraw; leg hits apply a timed move-speed penalty. A self-kill loses the duel (SP reason `You shot yourself`). Non-fatal MP wounds sync via `DuelManager._mp_wound`. `Hitbox.region` also drives AV. `_finish_sp` is idempotent once `RESOLUTION` is set.
- **Feedback:** `ImpactFeedback` autoload — spatial stubs (`assets/audio/`), one-shot particles (`assets/vfx/`), XR rumble + flat joy vibration (`assets/haptics/`).
- **Kill cam:** `DuelManager.kill_cam_requested(trail_points)` → `KillCam` (SP and 1v1 MP). Flat: cinematic fly-along `Camera3D`. VR: spectator `XROrigin3D` ride (player rig stays put) + `XRToolsFade`. `TimeManager.notify_kill_cam` burst allowed in MP; other slow-mo stays SP. Lethal sting: `AudioCatalog` `&"duel_end"` on `notify_kill_shot`.

## AI

- Data-driven `AIArchetype` resources (reaction, accuracy cone, draw speed, `reload_time`, movement).
- After 6 shots the AI enters `RELOADING`: gate opens (cylinder tilt), arm dips, waits `reload_time / ai_speed_mult`, then `WeaponBase.fill_cylinder()` + `close_gate()` and resumes fire. Arm hit / death / duel-over close the gate without refilling. SP only.
- SP spawn: `GameManager._begin_ai_duel` instantiates `ai/duelist.tscn`, assigns `ScenarioBase.get_enemy_spawn()`, then `DuelistAI.capture_spawn()` (`global_position`). Do not snapshot position in `_ready` — that runs at packed-scene origin before placement. Sheriff/Ghost strafe around that captured origin; Drunk stands.
- Encounter ladder: `DuelEncounter` + `GauntletLadder` `.tres` files — prefer data over code for new rungs.

## Multiplayer

- Interface in `netcode/`; `enet_transport.gd` (LAN + UDP discovery), `steam_transport.gd` (optional GodotSteam GDExtension).
- **SKU split:** Meta Store / Quest APK is **LAN-only**. Steam lobbies are desktop / Steam. `NetworkManager.steam_available()` is false on Android; `ui/main_menu.gd` hides Steam host/join chrome there. No Meta dedicated-server path.
- **Steam 1v1:** `NetworkManager` inits Steam once on desktop (`steamInitEx` app ID 480, then `initRelayNetworkAccess`). GodotSteam 4.22 lives in `addons/godotsteam/` (not enabled as an editor plugin; the GDExtension loads on its own). `steam_appid.txt` + Project Settings `steam/initialization/app_id` are 480 for editor/dev; `addons/gunslinger_steam_export/` copies that file next to Windows/Linux/macOS executables. Lobby metadata: `gunslinger=1`, display name, `gunslinger_version`. Browse uses worldwide distance + that game key. `SteamMultiplayerPeer` is created with `server_relay`. Host session starts on `lobby_ready`; joiner waits until the Godot peer is `CONNECTION_CONNECTED`. Full lobby (2/2) is set unjoinable until the peer leaves. `close()` leaves the lobby and drops the peer; it does not shut Steam down. Overlay invite on host is best-effort (`activateGameOverlayInviteDialog`).
- LAN discovery (`lan_discovery.gd`): host beacon on UDP 9100 answers pings and announces `ip|name` on `255.255.255.255` plus subnet `.255`. Gameplay ENet is UDP 9099, bound to IPv4 `0.0.0.0`.
- Quest Android export: `addons/gunslinger_lan_permissions/` injects `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, and `CHANGE_WIFI_MULTICAST_STATE` into the manifest at gradle export (also set on `export_presets.cfg`). Without `INTERNET`, `create_server` fails with "Can't create" on device. Steam Link + editor is Windows networking, not the APK. GodotSteam is excluded from the Android preset (`exclude_filter`).
- Pose / shot sync; host validates hits and HP; non-fatal wounds via `_mp_wound`; auto rematch. Gameplay slow-mo off while networked; kill-cam burst still plays after `RESOLUTION` from `_mp_finish` trail points. Pose RPC is `head, left, right, flags, gun_transform`. Flags: `GUN_DRAWN`, `GUN_COCKED`, `GUN_FREE`, `HOLSTER_LEFT`, `GUN_HELD_LEFT`, `GUN_SPINNING`. Remote interpolates a free or spinning gun; does not simulate physics.
- `RemoteAvatar` (`player/remote_avatar.tscn`): pose-driven head/hands plus torso/leg meshes and shoulder-to-hand arms. Revolver sits on the chosen hip until drawn, parents to left or right hand (identity, or interpolated world pose while `GUN_SPINNING`), or follows the free-gun transform.
- MP spawn: host on `PlayerSpawn`, joiner on `EnemySpawn`. `reset_for_duel` copies the marker transform onto the Player root. Flat look yaw is stored local to that root (do not apply marker yaw twice). VR `reset_locomotion` yaws the origin so the HMD faces the marker -Z. Flat walk and VR stick locomotion apply in world XZ (`global_position`) from look yaw so the joiner's 180° root does not invert strafe.

## Config / user data

Persisted under `user://`: `settings.cfg` (volume, flat window/resolution), `slowmo.cfg`, `movement.cfg`, `tuning.cfg`, `debug_presets.cfg`.

Build identity is `VERSION` (mirrored in `project.godot` → `application/config/version`). `python dev/bump_version.py patch|minor` updates both; pushes to `main` that change code also auto-bump via `.github/workflows/bump-version.yml` if `VERSION` was not already updated.

## Menus / pause

- Main menu and pause share `ui/settings_menu.tscn`. Back from Settings returns to mode select or the pause root.
- `Hud` (`PROCESS_MODE_ALWAYS`) owns both Controls. VR reparents them into a world `UIPanel3D` (`Player.show_menu_panel`); `reclaim_menu` returns each to `MenuHolder` / `PauseHolder`.
- SP pause: `get_tree().paused`. `TimeManager` / `KillCam` skip ticks while paused. `VRRig` stays `PROCESS_MODE_ALWAYS` so the laser can hit the overlay; locomotion is skipped while paused or the overlay is open.
- MP overlay: title **Menu**, tree not paused, restart disabled for clients. Quit calls `GameManager.go_to_menu()` (`NetworkManager.leave()`).
- Flat ESC toggles pause in-match; on Settings it goes Back first. VR left menu/Y opens pause in-match and still opens debug on the main menu. F3 stays debug.

## Tests

`dev/autotest.gd` — headless `--autotest=duel|gauntlet|load|host|join|steam`. Prefer extending these when changing duel or load paths. `steam` asserts `SteamTransport` parses and stays unavailable without GodotSteam (CI has no addon).
