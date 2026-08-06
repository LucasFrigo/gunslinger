# Changelog

All notable changes to **Gunslinger VR** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

The current version is the single line in [`VERSION`](VERSION) (mirrored in `project.godot` → `application/config/version`).

## [Unreleased]

### Added

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
