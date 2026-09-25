# Feature Roadmap & Key Concepts: VR Gunslinger Game

Ordered easiest → hardest to implement, given what already exists in the codebase.

**Living status of what already ships:** `[docs/FEATURES.md](docs/FEATURES.md)` · **How systems work:** `[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)` · **Bugs:** `[docs/BUGS.md](docs/BUGS.md)` · **Pre-release TODOs:** `[docs/RELEASE_TODOS.md](docs/RELEASE_TODOS.md)` · **SFX checklist:** `[docs/SOUND.md](docs/SOUND.md)` · **Design / lore:** `[docs/design/README.md](docs/design/README.md)` · **Versions:** `[CHANGELOG.md](CHANGELOG.md)` / `[VERSION](VERSION)`

When an item below lands (or is clearly underway), update `docs/FEATURES.md`. When it is **done**, move the bullet to **Completed** at the bottom (do not leave strikethrough items in the active lists).

## 1. Polish / visual

VFX, trail, and presentation tweaks. Not new mechanics. Numbered easiest → hardest.

1. **Shorter bullet trails:** Trails linger too long after the slug is gone. Drop `FADE_TIME` in `weapons/bullet_trail.gd` (currently 1.6s) so the ribbon disappears faster; optional debug knob.
2. **Replace placeholder SFX:** Combat cues play today via `PlaceholderAudio` except `duel_end.wav`. Check boxes in `[docs/SOUND.md](docs/SOUND.md)` as real files land in `assets/audio/`. Gunshot first.
3. **Barrel smoke:** Visible smoke coming out of the barrel after a shot. A short stub already plays (`VfxCatalog` `&"muzzle_smoke"` from `ImpactFeedback.shot_fired` / `assets/vfx/muzzle_smoke.tscn`); this is a lingering plume that reads as gunsmoke, not a 0.45s puff.
4. **Flat jam as long clear animation:** Maybe drop the heat / chance / look-down hold clear and make a jam just play a long clear animation (cylinder fuss / shake) before you can fire again — same flat-only cadence punishment, less fiddly. Today: heat build + click + look down + hold Space (`weapons/weapon_base.gd` / FlatRig). Keep VR/AI jam-free.
5. **Wind bed + gusts:** Always-on outdoor wind, mixed per arena, plus occasional visual gusts that fire a gust SFX at the same moment. Bed can start from `ScenarioResource.ambience` (`scenario_base.gd`) — unused today. Gusts are a new `VfxCatalog` cue (dust/tumbleweed/cloth) paired with an `AudioCatalog` `&"wind_gust"` one-shot. Per map: quiet/still Main Street, drier Canyon, more height/air on Train Rooftop; Saloon stays interior (no outdoor bed). Cosmetic only (local, no net). Foley notes in `[docs/SOUND.md](docs/SOUND.md)`.



## 2. Medium — contained mechanics & set pieces

Numbered easiest → hardest. Later items that name a dependency stay after that dependency.

1. **Airborne fire / mystic trick shots:** Optional tech/mystic branch: allow firing while the revolver is tossed and spinning, so you can go for mid-air trick shots. Today fire/reload require `held` (`weapons/weapon_base.gd`). Gate behind a flag so the grounded western default stays.
2. **More off-hand props:** Extra radial wedges beyond the cigarette — bottle, badge, etc. Each needs a mesh vendored next to `assets/models/props/msc_cigarette.glb` and an entry in `PropController.ITEMS`; the wheel, attach, and stow plumbing already exist. Props are local-only today: remote avatars show nothing in the off hand, so MP pose sync (a flag plus the equipped id) is the other half. Cigarette polish that is still open: an ember emission / tiny light on the tip, and a readability pass on the thrown cig (real 8.4 cm scale is nearly invisible in flight — see `cig_spin_axis`).
3. **More enemy NPCs:** Expand the roster beyond Drunk / Sheriff / Ghost. New opponents are new `ai/archetypes/*.tres` (`AIArchetype` — reaction, accuracy, draw, reload, move style). Wire them into the free-duel pick and gauntlet ladder rungs. Distinct silhouettes/meshes can follow once the gunslinger model is on AI. First design: [Half-head](docs/design/characters/half-head.md).
4. **Practice hub:** A non-duel lobby for warming up aim. The hub environment still needs to be modeled (new scenario, same greybox path as the arenas). Regenerating breakable bottles that respawn after a short delay; a casino slot machine as a interactable set piece (spin / payout flavor, no real-money). The range bottle is modeled: `MSC_Longneck.blend` in the sibling `blender-mcp-connection` project (one directory above this repo). Still needs to be vendored into `assets/models/props/` and wired as the breakable. **Flat:** on open, load a random existing duel scene and leave it paused behind the menu (today `GameManager.go_to_menu` always loads scenario 0 and does not pause it). Landing on `ui/main_menu.tscn` gains a **Tutorial / Practice** button that takes you to the hub. **VR:** the menu already floats in the world (`GameManager._spawn_vr_menu_panel`), so the player spawns in the hub on load instead of a random arena. Local/SP first; optional later MP hangout. Reuses bullet/hit feedback; no `DuelManager` standoff required.
5. **Tutorial billboard:** A news-board panel in the practice hub that spells out button mappings and the mechanics (draw, fire, cock, reload, jam clear, off-hand props). Reads like an old-town newspaper billboard, not a settings screen. Same board in flat and VR; the listed binds follow remaps in `PlayerSettings` so it stays true after Settings. Depends on the practice hub.
6. **Duel vs up to 3 NPCs:** Free-duel option to face 1–3 AI opponents in one standoff (local, no netcode). Needs extra spawn marks, multi-combatant targeting, and resolve when more than two duelists fire. Reuses `ai/duelist.tscn` + archetypes.
7. **Death cam (3rd-person corpse):** On a lethal hit, freeze the dead player (no move / fire / draw). Camera becomes a third-person orbit around their body; look/stick only orbits until the next duel starts. After `death_cam_hold` (~2s, tweakable) play the duel-replay item, then return to this orbit until rematch. SP + 1v1 MP. Replaces or sequences after the current trail fly-along KillCam (`autoload/kill_cam.gd`).
8. **Train Map Concept:** A duel scene featuring a moving train passing between opponents. Players must either wait for the train to clear or attempt risky shots through open train cars. Train Rooftop already scrolls desert and horizon past a stopped train; this item is the train that crosses the lane.
9. **Oil-field train:** A variant of the Train Map Concept. The same train crosses the lane, this time through open desert, with oil pumps (pumpjacks) scattered along both sides of the track. On the horizon, oil bursts burn as distant flame columns — a `VfxCatalog` cue, cosmetic only (local, no gameplay). Depends on the crossing train.
10. **Ragdoll physics:** On a lethal hit, the corpse collapses instead of holding the last pose the death cam orbits. `assets/models/characters/gunslinger.glb` is still an unskinned A-pose (not on AI or the remote avatar), so this needs a skeleton plus Godot `PhysicalBone3D` / `PhysicalBoneSimulator3D` against arena collision. At the lethal hit, drop the controller / IK pose and let the sim take the body; an impulse from the shot direction sells the fall. SP first; 1v1 MP can share a host-authored impulse so both peers see the same collapse. Depends on the death-cam corpse.
11. **Dismemberment:** A killing or limb-removing hit severs that part (head, either arm, a leg), keyed off the existing regions (`HeadHitbox`, `ArmHitboxL` / `ArmHitboxR`, `LegHitbox` in `player/player.gd`). Cost-effective path: pre-cut boolean meshes in `gunslinger.blend` that hide or swap out a chunk, rather than runtime CSG or a fracture sim. Show the stump and spawn the cut piece as a rigid body so it drops with the ragdoll. Cosmetic only — hit resolution stays `combat/combat_rules.gd`. Depends on the ragdoll item for the falling piece.
12. **Horseback duel stage:** Both duelists fight mounted. Each horse’s speed varies randomly, so relative motion (and the shot window) changes from duel to duel. New arena/scenario; riding locomotion + aim-on-the-move on top of the existing standoff.



## 3. Hard — new modes & netcode scope

Numbered easiest → hardest.

1. **Horde Mode:** Add an endless survival mode featuring wave-based enemy challenges. (Reuses AI/arenas, but needs wave/spawn systems.) The shot that drops the last enemy of a wave also plays the kill-cam slow-mo burst (`TimeManager.notify_kill_cam`, `kill_cam_factor` / `kill_cam_duration`) — same presentation as a duel-ending hit, then time returns and the next wave spawns. Mid-wave kills stay at normal speed.
2. **Duel replay:** After the death-cam hold (~2s), play back the last `replay_pre_death` (~5s) of the live duel through the moment the loser is considered dead, plus `replay_post_death` (~2s). All three durations tweakable (debug panel). Same feature in single-player and 1v1 MP (LAN + Steam). Needs a rolling buffer of poses / shots / AI so both peers watch the same clip. Depends on the Medium death-cam item for the 2s corpse-orbit lead-in.
3. **Mexican Standoff (3-Player Duel):** Design a dedicated dynamic mode/map featuring a three-way standoff. (Current netcode is 1v1 host-authoritative; 3P humans share the lobby work with 4-player MP below. Local 1v2 NPCs can land earlier via the item in Medium.)
4. **4-Player Multiplayer:** Expand LAN (all SKUs) and Steam (desktop only) beyond 1v1 to 2–4 human players (FFA, 2v2, or 1v3). Needs lobby size, extra spawn marks, remote avatars for every peer, and host-authoritative hits/HP for N combatants. Meta Store does not get a non-LAN online path.
5. **Ranking & Leaderboard System:** Implement competitive online matchmaking, player ratings, and global/regional leaderboards on **Steam / desktop**. Not on the Meta Store SKU (LAN-only MP).



## 4. Very hard — content & platform systems

Numbered easiest → hardest.

1. **Campaign Mode:** Develop a narrative-driven or level-based single-player story mode.
2. **Mod Support:** Provide community modding capabilities (custom gun skins, custom maps, sound packs, and duel scenarios).



## Completed

Newest at the top. Keep a one-line note of what shipped and where; details live in `[docs/FEATURES.md](docs/FEATURES.md)`.

- **Pain-jerk disarm:** An arm hit flings the held revolver upward (`WeaponBase.pain_jerk_into_world`) instead of snapping it to the hip. VR catches with either hand; flat looks at the loose gun and presses draw (RMB). AI tosses the same way and snatches it back after `arm_disarm_duration`. No redraw lock. (`done` in FEATURES)
- **Random time of day:** Each outdoor load picks one time along dawn → noon → late afternoon → dusk (`scenarios/time_of_day.gd`). Fog distances and shadow fade stay on the scene, and the fog tint matches the sky ground, so Canyon’s plain and the Train Rooftop belt wrap still dissolve. Saloon stays lamp-lit. The host sends the time on the duel RPC. F3 scrubs it.
- **Canyon art:** Greybox wash (`dev/build_canyon_blender.py` → `assets/models/scenarios/canyon/canyon.glb`). Winding cliffs, off-lane cover, sheer butte rim, and a desert horizon. Detail meshes still pending.
- **Saloon art:** Greybox interior (`dev/build_saloon_blender.py` → `assets/models/scenarios/saloon/saloon_interior.glb`). Bar, tables off the 10 m lane, balcony, 4.2 m ceiling. Detail meshes still pending. Street false-front stays `bld_saloon.glb`.
- **Main Street art:** Greybox kit (`dev/build_main_street_blender.py` → `assets/models/scenarios/main_street/`). Period false-fronts, boardwalks, depot vs cattle pens, 16 m lane. Detail meshes still pending.
- **Train Rooftop art:** Greybox consist (`dev/build_train_rooftop_blender.py` → `assets/models/scenarios/train_rooftop/`): six passenger cars and a steam engine at the front. The train stays put; Main Street tracks and cacti, plus slower horizon mesas, scroll in `scenarios/train_rooftop/scenery_belt.gd`. Detail meshes still pending. The passing-train duel stays the Train Map Concept item.

- **Main menu SP / MP split:** Landing is Singleplayer / Multiplayer / Settings / Quit. SP page is gauntlet + free duel; MP page is LAN / Steam host-join. Browse only while the MP page is open. (`done` in FEATURES)

- **Proximity voice chat:** World-space voice from the peer's mouth in 1v1 (LAN + Steam, Quest included) — 16 kHz mono PCM16 on an unreliable RPC beside the pose stream, played through an `AudioStreamPlayer3D` on a new `Voice` bus (`autoload/voice_chat.gd`). Always-on with a voice gate, optional push-to-talk, and a red X over a muted player's mouth. Settings gains a Voice Chat block with input/output device pickers and a mic level bar. (`done` in FEATURES)

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

