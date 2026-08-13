# Changelog

All notable changes to **Gunslinger VR** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

The current version is the single line in [`VERSION`](VERSION) (mirrored in `project.godot` → `application/config/version`).

## [Unreleased]

### Added

- Interactive revolver reload: VR opens gate with B, sustained shake to dump, grabs physical rounds from a torso ammo belt, closes with left-hand bump or gun swing; Flat uses `R` / Space. Reload status HUD. Dump/close thresholds live-tunable (`reload_dump_speed`, `reload_dump_hold`, `reload_swing_close`, `reload_bump_close` in debug panel).
- Reload status readout (ammo, gate open/closed, round in hand, empty/dry-fire/chambered events) on flat HUD and VR view.

### Changed

- VR reload dump/close are less hair-trigger: dump requires sustained shake; swing/bump close thresholds raised (still tunable).

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
