# Feature Roadmap & Key Concepts: VR Gunslinger Game

Ordered easiest → hardest to implement, given what already exists in the codebase.

**Living status of what already ships:** `[docs/FEATURES.md](docs/FEATURES.md)` · **How systems work:** `[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)` · **Bugs:** `[docs/BUGS.md](docs/BUGS.md)` · **Pre-release TODOs:** `[docs/RELEASE_TODOS.md](docs/RELEASE_TODOS.md)` · **SFX checklist:** `[docs/SOUND.md](docs/SOUND.md)` · **Design / lore:** `[docs/design/README.md](docs/design/README.md)` · **Versions:** `[CHANGELOG.md](CHANGELOG.md)` / `[VERSION](VERSION)`

When an item below lands (or is clearly underway), update `docs/FEATURES.md`. When it is **done**, move the bullet to **Completed** at the bottom (do not leave strikethrough items in the active lists).

## Polish / visual

VFX, trail, and presentation tweaks. Not new mechanics.

- **Shorter bullet trails:** Trails linger too long after the slug is gone. Drop `FADE_TIME` in `weapons/bullet_trail.gd` (currently 1.6s) so the ribbon disappears faster; optional debug knob.
- **Flat jam as long clear animation:** Maybe drop the heat / chance / look-down hold clear and make a jam just play a long clear animation (cylinder fuss / shake) before you can fire again — same flat-only cadence punishment, less fiddly. Today: heat build + click + look down + hold Space (`weapons/weapon_base.gd` / FlatRig). Keep VR/AI jam-free.
- **Barrel smoke:** Visible smoke coming out of the barrel after a shot. A short stub already plays (`VfxCatalog` `&"muzzle_smoke"` from `ImpactFeedback.shot_fired` / `assets/vfx/muzzle_smoke.tscn`); this is a lingering plume that reads as gunsmoke, not a 0.45s puff.
- **Wind bed + gusts:** Always-on outdoor wind, mixed per arena, plus occasional visual gusts that fire a gust SFX at the same moment. Bed can start from `ScenarioResource.ambience` (`scenario_base.gd`) — unused today. Gusts are a new `VfxCatalog` cue (dust/tumbleweed/cloth) paired with an `AudioCatalog` `&"wind_gust"` one-shot. Per map: quiet/still Main Street, drier Canyon, more height/air on Train Rooftop; Saloon stays interior (no outdoor bed). Cosmetic only (local, no net). Foley notes in `[docs/SOUND.md](docs/SOUND.md)`.
- **Proximity voice chat:** Nearby players hear each other in world space (volume/falloff by distance). Muted players show an X over the mouth so mute state is readable at a glance.
- **Replace placeholder SFX:** Combat cues play today via `PlaceholderAudio` except `duel_end.wav`. Check boxes in `[docs/SOUND.md](docs/SOUND.md)` as real files land in `assets/audio/`. Gunshot first.
- **Main Street art:** Greybox landed (`dev/build_main_street_blender.py` → `assets/models/scenarios/main_street/` kit, wired in `scenarios/main_street/main_street.tscn`). Detail meshes still pending. Scratch the old CSG (done — do not mesh-swap boxes). One wide dirt street; duelists at opposite ends of the 16 m lane. Railroad (depot as terminus) is the backdrop for one player, a cattle fence / stock-edge for the other. On the street: saloon, general store, hotel, bank, jail, newspaper office, railroad station, and church — two parallel rows of false-fronts facing each other, boardwalks, massing and facades accurate to a historical western small town (not a movie-set jumble). Keep `PlayerSpawn` / `EnemySpawn` and the `scenario_base.gd` contract. Headless vend like the cigarette (`blender -b --python`, GLB next to the `.blend`). Interior Saloon arena stays the separate `scenarios/saloon/` item.
- **Saloon art:** Same ground-up pass for `scenarios/saloon/`. Throw out the current box interior; new detailed greybox (bar, walls, tables, ceiling height for VR) then meshes.
- **Train Rooftop art:** Same ground-up pass for `scenarios/train_rooftop/`. Throw out the current two-car CSG; new detailed greybox (cars, roofs, desert) then meshes. Static cars only; moving-train gameplay stays the Train Map Concept item.
- **Canyon art:** Same ground-up pass for `scenarios/canyon/`. Throw out the current floor/walls/boulders CSG; new detailed greybox (cliffs, cover, dusk sightlines) then meshes.



## 2. Medium — contained mechanics & set pieces

- **More off-hand props:** Extra radial wedges beyond the cigarette — bottle, badge, etc. Each needs a mesh vendored next to `assets/models/props/msc_cigarette.glb` and an entry in `PropController.ITEMS`; the wheel, attach, and stow plumbing already exist. Props are local-only today: remote avatars show nothing in the off hand, so MP pose sync (a flag plus the equipped id) is the other half. Cigarette polish that is still open: an ember emission / tiny light on the tip, and a readability pass on the thrown cig (real 8.4 cm scale is nearly invisible in flight — see `cig_spin_axis`).
- **More enemy NPCs:** Expand the roster beyond Drunk / Sheriff / Ghost. New opponents are new `ai/archetypes/*.tres` (`AIArchetype` — reaction, accuracy, draw, reload, move style). Wire them into the free-duel pick and gauntlet ladder rungs. Distinct silhouettes/meshes can follow once the gunslinger model is on AI. First design: [Half-head](docs/design/characters/half-head.md).
- **Airborne fire / mystic trick shots:** Optional tech/mystic branch: allow firing while the revolver is tossed and spinning, so you can go for mid-air trick shots. Today fire/reload require `held` (`weapons/weapon_base.gd`). Gate behind a flag so the grounded western default stays.
- **Train Map Concept:** A duel scene featuring a moving train passing between opponents. Players must either wait for the train to clear or attempt risky shots through open train cars. (Builds on the existing Train Rooftop arena idea.)
- **Horseback duel stage:** Both duelists fight mounted. Each horse’s speed varies randomly, so relative motion (and the shot window) changes from duel to duel. New arena/scenario; riding locomotion + aim-on-the-move on top of the existing standoff.
- **Practice hub:** A non-duel lobby/practice area (new scenario or main-menu destination) for warming up aim. Regenerating breakable bottles (or similar range targets) that respawn after a short delay; a casino slot machine as a interactable set piece (spin / payout flavor, no real-money). Local/SP first; optional later MP hangout. Reuses bullet/hit feedback; no `DuelManager` standoff required.
- **Duel vs up to 3 NPCs:** Free-duel option to face 1–3 AI opponents in one standoff (local, no netcode). Needs extra spawn marks, multi-combatant targeting, and resolve when more than two duelists fire. Reuses `ai/duelist.tscn` + archetypes.
- **Death cam (3rd-person corpse):** On a lethal hit, freeze the dead player (no move / fire / draw). Camera becomes a third-person orbit around their body; look/stick only orbits until the next duel starts. After `death_cam_hold` (~2s, tweakable) play the duel-replay item, then return to this orbit until rematch. SP + 1v1 MP. Replaces or sequences after the current trail fly-along KillCam (`autoload/kill_cam.gd`).



## 3. Hard — new modes & netcode scope

- **Horde Mode:** Add an endless survival mode featuring wave-based enemy challenges. (Reuses AI/arenas, but needs wave/spawn systems.)
- **Mexican Standoff (3-Player Duel):** Design a dedicated dynamic mode/map featuring a three-way standoff. (Current netcode is 1v1 host-authoritative; 3P humans share the lobby work with 4-player MP below. Local 1v2 NPCs can land earlier via the item in Medium.)
- **4-Player Multiplayer:** Expand LAN (all SKUs) and Steam (desktop only) beyond 1v1 to 2–4 human players (FFA, 2v2, or 1v3). Needs lobby size, extra spawn marks, remote avatars for every peer, and host-authoritative hits/HP for N combatants. Meta Store does not get a non-LAN online path.
- **Ranking & Leaderboard System:** Implement competitive online matchmaking, player ratings, and global/regional leaderboards on **Steam / desktop**. Not on the Meta Store SKU (LAN-only MP).
- **Duel replay:** After the death-cam hold (~2s), play back the last `replay_pre_death` (~5s) of the live duel through the moment the loser is considered dead, plus `replay_post_death` (~2s). All three durations tweakable (debug panel). Same feature in single-player and 1v1 MP (LAN + Steam). Needs a rolling buffer of poses / shots / AI so both peers watch the same clip. Depends on the Medium death-cam item for the 2s corpse-orbit lead-in.



## 4. Very hard — content & platform systems

- **Campaign Mode:** Develop a narrative-driven or level-based single-player story mode.
- **Mod Support:** Provide community modding capabilities (custom gun skins, custom maps, sound packs, and duel scenarios).



## Completed

Newest at the top. Keep a one-line note of what shipped and where; details live in `[docs/FEATURES.md](docs/FEATURES.md)`.

- **Main menu SP / MP split:** Landing is Singleplayer / Multiplayer / Settings / Quit. SP page is gauntlet + free duel; MP page is LAN / Steam host-join. Browse only while the MP page is open. (`done` in FEATURES)

- **Steam leave / rejoin:** HOST / JOIN work repeatedly in one process. Each session takes an unspent Steam P2P virtual port (`create_host` / `create_client` + `gunslinger_port` lobby metadata) because GodotSteam's peer never frees port 0; teardown also drops late-callback lobbies and times out unanswered requests. Fixes [BUG-009](docs/BUGS.md); "can't join while drawn" was just the intended 2/2 unjoinable lobby.

- **Off-hand props (radial + cigarette boomerang):** Hold-to-open equip wheel on both harnesses (VR off-hand stick click, flat Tab) with Empty Hand / Cigarette wedges; the cigarette throws as a hold-duration boomerang (VR off-hand trigger, flat `G`) and flicks into a spin until it is caught. (`done` in FEATURES)
- **MP version check:** Join refuses when `application/config/version` differs (Steam lobby metadata + LAN beacon `ip|name|version` + post-connect hello RPC). Both version strings shown; mismatched list rows disabled. Fixes [BUG-008](docs/BUGS.md).
- **Button remapping + VR stick-down cock:** Settings Controls table (`ui/settings_menu.tscn`) → `PlayerSettings` / `user://settings.cfg`. VR defaults: stick down cocks, A holds Ocelot spin, B gate, trigger fire, grip hold. Flat: fire / draw / cock / reload remappable. (`done` in FEATURES)
- **Main-menu settings + in-duel pause:** Settings on `ui/main_menu.tscn` (volume, holster, VR turn, mouse sens). Pause overlay in-match: SP tree-pause, MP overlay-only; Resume / Settings / Restart / Quit. (`done` in FEATURES)
- **Steam lobby multiplayer:** 1v1 create / browse / join over Steam Datagram Relay (`netcode/steam_transport.gd`); desktop only; App ID 480 until owned. (`done` in FEATURES)
- **Self-hit hitbox tweak:** Gun-hand arm is a thinner wrist-inset capsule along the limb; muzzle grace skips only that arm so a body-pointed shot still counts. (`done` in FEATURES)
- **NPC reload:** Spent 6-round cylinder is a combat window: `RELOADING` + arm dip + gate open, `reload_time` per archetype, `WeaponBase.fill_cylinder`. (`done` in FEATURES)
- **Revolver Ocelot spin:** VR gun-hand stick down hangs the revolver on a finger hinge; hand motion builds spin; stick up relocks. Fire still works. (`done` in FEATURES)
- **Self-damage:** Player/peer shots can hit the shooter after a muzzle grace; self-kill loses the duel. AI still self-excludes. (`done` in FEATURES)
- **Rapid-fire jam:** Flat-only cadence heat; jammed pull clicks with no bullet; look down + hold Space 1.5s to clear. (`done` in FEATURES)
- **Gun release / catch:** VR hold-to-hold toss and either-hand catch; chosen hip (`holster_side`); gun-hand vs off-hand reload swap; MP free-gun pose. (`done` in FEATURES)
- **Reload Mechanic:** VR B-open / sustained shake dump / torso `AmmoBelt` + left `ReloadProbe` / `ChamberArea` seat / bump or swing close; Flat `R` / Space. Area3D volumes on layer `reload`; dump/close knobs in debug panel. Mesh-fit / cylinder-flip polish can land later without reopening this item. (`done` in FEATURES)
- **Regional Hit Effects:** Head instakill; torso/limb HP; arm force-holster; leg slow. Tunables: `player_health`, `arm_disarm_duration`, `leg_slow_duration`, `leg_speed_mult`. (`done` in FEATURES)
- **Kill cam:** Flat trail fly-along + VR spectator ride; SP and 1v1 MP. (`done` in FEATURES)

