# Feature Roadmap & Key Concepts: VR Gunslinger Game

Ordered easiest → hardest to implement, given what already exists in the codebase.

**Living status of what already ships:** [`docs/FEATURES.md`](docs/FEATURES.md) · **How systems work:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Bugs:** [`docs/BUGS.md`](docs/BUGS.md) · **Versions:** [`CHANGELOG.md`](CHANGELOG.md) / [`VERSION`](VERSION)

When an item below lands (or is clearly underway), update `docs/FEATURES.md`. When it is **done**, move the bullet to **Completed** at the bottom (do not leave strikethrough items in the active lists).

## 1. Easy — polish & finish existing hooks

*(none)*

## 2. Medium — contained mechanics & set pieces
* **Rapid-fire jam:** Chance to jam on successive shots; higher rate of fire (especially Flat `auto_cock` spam) raises jam chance. Clearing a jam should cost time vs. a clean reload. Tunable fire-interval / chance knobs.
* **Train Map Concept:** A duel scene featuring a moving train passing between opponents. Players must either wait for the train to clear or attempt risky shots through open train cars. (Builds on the existing Train Rooftop arena idea.)
* **Duel vs up to 3 NPCs:** Free-duel option to face 1–3 AI opponents in one standoff (local, no netcode). Needs extra spawn marks, multi-combatant targeting, and resolve when more than two duelists fire. Reuses `ai/duelist.tscn` + archetypes.

## 3. Hard — new modes & netcode scope
* **Horde Mode:** Add an endless survival mode featuring wave-based enemy challenges. (Reuses AI/arenas, but needs wave/spawn systems.)
* **Mexican Standoff (3-Player Duel):** Design a dedicated dynamic mode/map featuring a three-way standoff. (Current netcode is 1v1 host-authoritative; 3P humans share the lobby work with 4-player MP below. Local 1v2 NPCs can land earlier via the item in Medium.)
* **4-Player Multiplayer:** Expand LAN/Steam beyond 1v1 to 2–4 human players (FFA, 2v2, or 1v3). Needs lobby size, extra spawn marks, remote avatars for every peer, and host-authoritative hits/HP for N combatants.
* **Ranking & Leaderboard System:** Implement competitive online matchmaking, player ratings, and global/regional leaderboards.

## 4. Very hard — content & platform systems
* **Campaign Mode:** Develop a narrative-driven or level-based single-player story mode.
* **Mod Support:** Provide community modding capabilities (custom gun skins, custom maps, sound packs, and duel scenarios).

## Completed

Newest at the top. Keep a one-line note of what shipped and where; details live in [`docs/FEATURES.md`](docs/FEATURES.md).

* **Gun release / catch:** VR hold-to-hold toss and either-hand catch; chosen hip (`holster_side`); gun-hand vs off-hand reload swap; MP free-gun pose. (`done` in FEATURES)
* **Reload Mechanic:** VR B-open / sustained shake dump / torso `AmmoBelt` + left `ReloadProbe` / `ChamberArea` seat / bump or swing close; Flat `R` / Space. Area3D volumes on layer `reload`; dump/close knobs in debug panel. Mesh-fit / cylinder-flip polish can land later without reopening this item. (`done` in FEATURES)
* **Regional Hit Effects:** Head instakill; torso/limb HP; arm force-holster; leg slow. Tunables: `player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`. (`done` in FEATURES)
* **Kill cam:** Flat trail fly-along + VR spectator ride; SP and 1v1 MP. (`done` in FEATURES)
