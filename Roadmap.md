# Feature Roadmap & Key Concepts: VR Gunslinger Game

Ordered easiest → hardest to implement, given what already exists in the codebase.

**Living status of what already ships:** [`docs/FEATURES.md`](docs/FEATURES.md) · **How systems work:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Versions:** [`CHANGELOG.md`](CHANGELOG.md) / [`VERSION`](VERSION)

When an item below lands (or is clearly underway), update `docs/FEATURES.md` and move or strike the bullet here.

## 1. Easy — polish & finish existing hooks

*(none — kill cam shipped; see [`docs/FEATURES.md`](docs/FEATURES.md))*

## 2. Medium — contained mechanics & set pieces
* **Reload Mechanic:** ~~B-open / sustained motion dump / belt feed / bump-swing close shipped (`partial` in FEATURES).~~ Polish later: cylinder flip feel, real belt/cartridge assets. Dump/close knobs: `reload_dump_speed`, `reload_dump_hold`, `reload_swing_close`, `reload_bump_close`.
* **Regional Hit Effects:** ~~Arm/leg hitboxes + region gameplay shipped (`done` in FEATURES).~~ Head instakill; torso/limb HP; arm force-holster; leg slow. Tunables: `player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`.
* **Train Map Concept:** A duel scene featuring a moving train passing between opponents. Players must either wait for the train to clear or attempt risky shots through open train cars. (Builds on the existing Train Rooftop arena idea.)
* **Gun Release & Trick Shots:** Allow players to release, catch, and toss weapons mid-air to pull off stylish trick shots. (Needs reliable VR grab/release physics.)

## 3. Hard — new modes & netcode scope
* **Horde Mode:** Add an endless survival mode featuring wave-based enemy challenges. (Reuses AI/arenas, but needs wave/spawn systems.)
* **Mexican Standoff (3-Player Duel):** Design a dedicated dynamic mode/map featuring a three-way standoff. (Current netcode is 1v1 host-authoritative.)
* **Ranking & Leaderboard System:** Implement competitive online matchmaking, player ratings, and global/regional leaderboards.

## 4. Very hard — content & platform systems
* **Campaign Mode:** Develop a narrative-driven or level-based single-player story mode.
* **Mod Support:** Provide community modding capabilities (custom gun skins, custom maps, sound packs, and duel scenarios).
