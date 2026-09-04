# Feature Roadmap & Key Concepts: VR Gunslinger Game

Ordered easiest → hardest to implement, given what already exists in the codebase.

**Living status of what already ships:** [`docs/FEATURES.md`](docs/FEATURES.md) · **How systems work:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Bugs:** [`docs/BUGS.md`](docs/BUGS.md) · **Pre-release TODOs:** [`docs/RELEASE_TODOS.md`](docs/RELEASE_TODOS.md) · **Design / lore:** [`docs/design/README.md`](docs/design/README.md) · **Versions:** [`CHANGELOG.md`](CHANGELOG.md) / [`VERSION`](VERSION)

When an item below lands (or is clearly underway), update `docs/FEATURES.md`. When it is **done**, move the bullet to **Completed** at the bottom (do not leave strikethrough items in the active lists).

## Polish / visual

VFX, trail, and presentation tweaks. Not new mechanics.

* **Shorter bullet trails:** Trails linger too long after the slug is gone. Drop `FADE_TIME` in `weapons/bullet_trail.gd` (currently 1.6s) so the ribbon disappears faster; optional debug knob.
* **Barrel smoke:** Visible smoke coming out of the barrel after a shot. A short stub already plays (`VfxCatalog` `&"muzzle_smoke"` from `ImpactFeedback.shot_fired` / `assets/vfx/muzzle_smoke.tscn`); this is a lingering plume that reads as gunsmoke, not a 0.45s puff.
* **Proximity voice chat:** Nearby players hear each other in world space (volume/falloff by distance). Muted players show an X over the mouth so mute state is readable at a glance.

## 2. Medium — contained mechanics & set pieces
* **MP version check:** Reject join when `application/config/version` differs so mismatched builds cannot start a match. Steam already stores `gunslinger_version` on the lobby but does not filter or refuse ([BUG-008](docs/BUGS.md)); LAN has no check. Show both version strings on failure.
* **Steam leave / rejoin:** After leaving a Steam lobby, create and join can fail until the process restarts ([BUG-009](docs/BUGS.md)). Tear down `SteamMultiplayerPeer` + lobby so HOST / JOIN work again in the same session. Confirm whether “can’t join while drawn” is this teardown bug or the lobby already marked unjoinable at 2/2.
* **More enemy NPCs:** Expand the roster beyond Drunk / Sheriff / Ghost. New opponents are new `ai/archetypes/*.tres` (`AIArchetype` — reaction, accuracy, draw, reload, move style). Wire them into the free-duel pick and gauntlet ladder rungs. Distinct silhouettes/meshes can follow once the gunslinger model is on AI. First design: [Half-head](docs/design/characters/half-head.md).
* **Airborne fire / mystic trick shots:** Optional tech/mystic branch: allow firing while the revolver is tossed and spinning, so you can go for mid-air trick shots. Today fire/reload require `held` (`weapons/weapon_base.gd`). Gate behind a flag so the grounded western default stays.
* **Train Map Concept:** A duel scene featuring a moving train passing between opponents. Players must either wait for the train to clear or attempt risky shots through open train cars. (Builds on the existing Train Rooftop arena idea.)
* **Duel vs up to 3 NPCs:** Free-duel option to face 1–3 AI opponents in one standoff (local, no netcode). Needs extra spawn marks, multi-combatant targeting, and resolve when more than two duelists fire. Reuses `ai/duelist.tscn` + archetypes.

## 3. Hard — new modes & netcode scope
* **Horde Mode:** Add an endless survival mode featuring wave-based enemy challenges. (Reuses AI/arenas, but needs wave/spawn systems.)
* **Mexican Standoff (3-Player Duel):** Design a dedicated dynamic mode/map featuring a three-way standoff. (Current netcode is 1v1 host-authoritative; 3P humans share the lobby work with 4-player MP below. Local 1v2 NPCs can land earlier via the item in Medium.)
* **4-Player Multiplayer:** Expand LAN (all SKUs) and Steam (desktop only) beyond 1v1 to 2–4 human players (FFA, 2v2, or 1v3). Needs lobby size, extra spawn marks, remote avatars for every peer, and host-authoritative hits/HP for N combatants. Meta Store does not get a non-LAN online path.
* **Ranking & Leaderboard System:** Implement competitive online matchmaking, player ratings, and global/regional leaderboards on **Steam / desktop**. Not on the Meta Store SKU (LAN-only MP).

## 4. Very hard — content & platform systems
* **Campaign Mode:** Develop a narrative-driven or level-based single-player story mode.
* **Mod Support:** Provide community modding capabilities (custom gun skins, custom maps, sound packs, and duel scenarios).

## Completed

Newest at the top. Keep a one-line note of what shipped and where; details live in [`docs/FEATURES.md`](docs/FEATURES.md).

* **Main-menu settings + in-duel pause:** Settings on `ui/main_menu.tscn` (volume, holster, VR turn, mouse sens). Pause overlay in-match: SP tree-pause, MP overlay-only; Resume / Settings / Restart / Quit. (`done` in FEATURES)
* **Steam lobby multiplayer:** 1v1 create / browse / join over Steam Datagram Relay (`netcode/steam_transport.gd`); desktop only; App ID 480 until owned. (`done` in FEATURES)
* **Self-hit hitbox tweak:** Gun-hand arm is a thinner wrist-inset capsule along the limb; muzzle grace skips only that arm so a body-pointed shot still counts. (`done` in FEATURES)
* **NPC reload:** Spent 6-round cylinder is a combat window: `RELOADING` + arm dip + gate open, `reload_time` per archetype, `WeaponBase.fill_cylinder`. (`done` in FEATURES)
* **Revolver Ocelot spin:** VR gun-hand stick down hangs the revolver on a finger hinge; hand motion builds spin; stick up relocks. Fire still works. (`done` in FEATURES)
* **Self-damage:** Player/peer shots can hit the shooter after a muzzle grace; self-kill loses the duel. AI still self-excludes. (`done` in FEATURES)
* **Rapid-fire jam:** Flat-only cadence heat; jammed pull clicks with no bullet; look down + hold Space 1.5s to clear. (`done` in FEATURES)
* **Gun release / catch:** VR hold-to-hold toss and either-hand catch; chosen hip (`holster_side`); gun-hand vs off-hand reload swap; MP free-gun pose. (`done` in FEATURES)
* **Reload Mechanic:** VR B-open / sustained shake dump / torso `AmmoBelt` + left `ReloadProbe` / `ChamberArea` seat / bump or swing close; Flat `R` / Space. Area3D volumes on layer `reload`; dump/close knobs in debug panel. Mesh-fit / cylinder-flip polish can land later without reopening this item. (`done` in FEATURES)
* **Regional Hit Effects:** Head instakill; torso/limb HP; arm force-holster; leg slow. Tunables: `player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`. (`done` in FEATURES)
* **Kill cam:** Flat trail fly-along + VR spectator ride; SP and 1v1 MP. (`done` in FEATURES)
