# Changelog

All notable changes to **Gunslinger VR** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

The current version is the single line in [`VERSION`](VERSION) (mirrored in `project.godot` → `application/config/version`).

## [Unreleased]

### Added

- Interactive revolver reload: VR opens gate with B, sustained shake to dump, grabs physical rounds from a torso ammo belt, closes with left-hand bump or gun swing; Flat uses `R` / Space. Reload status HUD. Dump/close thresholds live-tunable (`reload_dump_speed`, `reload_dump_hold`, `reload_swing_close`, `reload_bump_close` in debug panel).
- Reload status readout (ammo, gate open/closed, round in hand, empty/dry-fire/chambered events) on flat HUD and VR view.
- Regional hit effects: arm/leg hitboxes on player, AI, and remote avatar. Headshots are instant death; torso and limbs deal 1 HP (default HP 2 so a single torso is not fatal). Arm hits force-holster and block redraw for a window; leg hits apply a timed move-speed penalty. 1v1 MP tracks HP on the host and syncs non-fatal wounds. Tunable in the debug panel (`player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`).

### Fixed

- Quest 3 LAN: hosting no longer fails with "Can't create", and a PC host shows up in the headset list. The Android export was missing `INTERNET` / Wi-Fi multicast permissions; discovery now announces on subnet broadcasts and includes the host IP ([BUG-003](docs/BUGS.md)). Re-export the Quest APK.
- Bullet trails no longer draw as a bent double-V (first point was recorded before the slug reached the muzzle; camera-facing ribbon side vector flipped along the shot).
- Strafing AI (Sheriff, Ghost) no longer teleport toward the world origin when the bell rings ([BUG-002](docs/BUGS.md)). Spawn for strafing is captured after they are placed on the arena marker.

### Changed

- VR reload dump/close are less hair-trigger: dump requires sustained shake; swing/bump close thresholds raised (still tunable).
- Default duelist HP raised so torso is not instakill (drunk/ghost 2, sheriff 3, player 2). Headshots remain instantly fatal.

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
