# Feature Roadmap & Key Concepts: VR Gunslinger Game

Ordered easiest → hardest to implement, given what already exists in the codebase.

**Living status of what already ships:** [`docs/FEATURES.md`](docs/FEATURES.md) · **How systems work:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Bugs:** [`docs/BUGS.md`](docs/BUGS.md) · **Versions:** [`CHANGELOG.md`](CHANGELOG.md) / [`VERSION`](VERSION)

When an item below lands (or is clearly underway), update `docs/FEATURES.md`. When it is **done**, move the bullet to **Completed** at the bottom (do not leave strikethrough items in the active lists).

## Polish / visual

VFX, trail, and presentation tweaks. Not new mechanics.

* **Shorter bullet trails:** Trails linger too long after the slug is gone. Drop `FADE_TIME` in `weapons/bullet_trail.gd` (currently 1.6s) so the ribbon disappears faster; optional debug knob.
* **Barrel smoke:** Visible smoke coming out of the barrel after a shot. A short stub already plays (`VfxCatalog` `&"muzzle_smoke"` from `ImpactFeedback.shot_fired` / `assets/vfx/muzzle_smoke.tscn`); this is a lingering plume that reads as gunsmoke, not a 0.45s puff.

## 1. Easy — polish & finish existing hooks
* **Self-hit hitbox tweak:** Self-damage already applies after `self_hit_grace` (`weapons/bullet.gd`, `player/hitbox.gd`). Tune the shooter's own volumes (especially gun-hand arm) so a normal muzzle shot still does not clip the arm, but a real self-hit (muzzle into body, ricochet-style close miss) reads fairly.

## 2. Medium — contained mechanics & set pieces
* **NPC reload:** AI currently `reset()`s the cylinder when empty and fires forever (`ai/duelist_ai.gd` `_fire`). Make NPCs empty out and spend time reloading (delay / simple animation) so a spent cylinder is a window, same 6-round limit as the player.
* **Airborne fire / mystic trick shots:** Optional tech/mystic branch: allow firing while the revolver is tossed and spinning, so you can go for mid-air trick shots. Today fire/reload require `held` (`weapons/weapon_base.gd`). Gate behind a flag so the grounded western default stays.
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

* **Revolver Ocelot spin:** VR gun-hand stick down hangs the revolver on a finger hinge; hand motion builds spin; stick up relocks. Fire still works. (`done` in FEATURES)
* **Self-damage:** Player/peer shots can hit the shooter after a muzzle grace; self-kill loses the duel. AI still self-excludes. (`done` in FEATURES)
* **Rapid-fire jam:** Flat-only cadence heat; jammed pull clicks with no bullet; look down + hold Space 1.5s to clear. (`done` in FEATURES)
* **Gun release / catch:** VR hold-to-hold toss and either-hand catch; chosen hip (`holster_side`); gun-hand vs off-hand reload swap; MP free-gun pose. (`done` in FEATURES)
* **Reload Mechanic:** VR B-open / sustained shake dump / torso `AmmoBelt` + left `ReloadProbe` / `ChamberArea` seat / bump or swing close; Flat `R` / Space. Area3D volumes on layer `reload`; dump/close knobs in debug panel. Mesh-fit / cylinder-flip polish can land later without reopening this item. (`done` in FEATURES)
* **Regional Hit Effects:** Head instakill; torso/limb HP; arm force-holster; leg slow. Tunables: `player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`. (`done` in FEATURES)
* **Kill cam:** Flat trail fly-along + VR spectator ride; SP and 1v1 MP. (`done` in FEATURES)
