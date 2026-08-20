# Changelog

All notable changes to **Gunslinger VR** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

The current version is the single line in [`VERSION`](VERSION) (mirrored in `project.godot` → `application/config/version`).

## [Unreleased]

### Added

- Double-click (or Enter) a LAN host or Steam lobby in the main menu list to join; the Join button still works.
- VR kill cam: spectator `XROrigin3D` flies along the killing trail (player rig stays put); short fade in/out; locomotion frozen. Same cinematic in 1v1 MP from synced trail points.
- Duel-end sting (`assets/audio/duel_end.wav`) at the lethal hit (not on fouls); pitch stays concert under slow-mo.
- Interactive revolver reload: VR opens gate with B, sustained shake to dump, grabs physical rounds from a torso ammo belt, closes with left-hand bump or gun swing; Flat uses `R` / Space. Reload status HUD. Dump/close thresholds live-tunable (`reload_dump_speed`, `reload_dump_hold`, `reload_swing_close`, `reload_bump_close` in debug panel).
- Reload status readout (ammo, gate open/closed, round in hand, empty/dry-fire/chambered events) on flat HUD and VR view.
- Regional hit effects: arm/leg hitboxes on player, AI, and remote avatar. Headshots are instant death; torso and limbs deal 1 HP (default HP 2 so a single torso is not fatal). Arm hits force-holster and block redraw for a window; leg hits apply a timed move-speed penalty. 1v1 MP tracks HP on the host and syncs non-fatal wounds. Tunable in the debug panel (`player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`).

### Fixed

- LAN joiner strafe (A/D, left stick) matches the view after spawning on `EnemySpawn`. Stick/WASD motion is applied in world XZ from look yaw so the 180° spawn root is not applied twice ([BUG-006](docs/BUGS.md)).
- PvP opponent now has a readable greybox body (torso, legs, arms) and a holstered revolver until they draw, instead of a floating head and hands ([BUG-005](docs/BUGS.md)).
- Quest 3 LAN: hosting no longer fails with "Can't create", and a PC host shows up in the headset list. The sideloaded APK had no `INTERNET` permission (Steam Link + Godot editor worked because that path runs on Windows). Permissions are now injected at Android export so the dialog cannot drop them; ENet/discovery bind IPv4 ([BUG-003](docs/BUGS.md)).
- Bullet trails no longer draw as a bent double-V (first point was recorded before the slug reached the muzzle; camera-facing ribbon side vector flipped along the shot).
- Strafing AI (Sheriff, Ghost) no longer teleport toward the world origin when the bell rings ([BUG-002](docs/BUGS.md)). Spawn for strafing is captured after they are placed on the arena marker.
- LAN joiner no longer spawns with their back to the host ([BUG-004](docs/BUGS.md)). Flat was applying EnemySpawn yaw twice (player root + look); VR now yaws the origin so the HMD faces the marker.

### Changed

- VR reload dump/close are less hair-trigger: dump requires sustained shake; swing/bump close thresholds raised (still tunable).
- Default duelist HP raised so torso is not instakill (drunk/ghost 2, sheriff 3, player 2). Headshots remain instantly fatal.
- VR reload grab / seat / bump use `Area3D` collision shapes on physics layer `reload` (`AmmoBelt`, revolver `ChamberArea` + `BumpArea`, left-hand `ReloadProbe`). Resize the shapes in the scenes to fit future meshes. F3 **Show reload volumes** draws translucent gizmos on device.

### Added (earlier unreleased)

- SP kill cam: flat cinematic trail fly-along + VR slow-mo burst (`KillCam`, `TimeManager.notify_kill_cam`); win and lose shots.
- Combat impact feedback: spatial SFX stubs, western-grit particles (dust/wood/blood), and XR/flat haptics via `ImpactFeedback` (`AudioCatalog` / `VfxCatalog` swap path).
- Project docs scaffold: `docs/FEATURES.md`, `docs/ARCHITECTURE.md`, agent rule for keeping them + this changelog current.

## [0.1.0] — 2026-08-06

### Added

- Core 1v1 duel loop (standoff → bell → draw → first lethal hit) for VR, PCVR, and flat harness.
- Free duel vs AI, 6-rung gauntlet (lives + session score), LAN multiplayer (ENet + UDP discovery).
- Steam transport hook (optional GodotSteam; app ID 480 until owned).
- Slow-mo modes (CONSTANT / ON_DRAW / MOVEMENT / NEAR_MISS) — single-player only.
- Four greybox arenas; three AI archetypes; revolver + projectile bullets + trails.
- Debug wrist/F3 panel (slow-mo, movement, gunplay/AI tuning, presets).
- Headless autotests (`duel`, `gauntlet`, `load`, `host` / `join`).

[Unreleased]: https://github.com/LucasFrigo/gunslinger/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/LucasFrigo/gunslinger/releases/tag/v0.1.0
