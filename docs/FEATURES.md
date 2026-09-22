# Feature status

Living checklist of what the game can do. Agents update this when behavior lands or status changes.

Status: `done` | `partial` | `planned` | `blocked`  
Roadmap (future, by difficulty): [`../Roadmap.md`](../Roadmap.md)  
Open bugs: [`BUGS.md`](BUGS.md)  
Pre-release TODOs: [`RELEASE_TODOS.md`](RELEASE_TODOS.md)  
Sound design (SFX checklist): [`SOUND.md`](SOUND.md)  
Design / lore: [`design/README.md`](design/README.md)

## Core duel

| Feature | Status | Notes / key paths |
|---|---|---|
| Standoff → bell → draw → resolve | `done` | `gauntlet/duel_manager.gd` |
| Holster / draw / fire / cock | `done` | `weapons/revolver/revolver.gd`, player rigs. VR grip is hold-to-hold; Flat RMB still toggles. Default VR cock is gun-hand stick down; A is trick-shot / Ocelot spin (remappable) |
| VR cock on stick-down | `done` | Default: gun-hand analog down cocks; A holds Ocelot spin (`PlayerSettings` VR binds, `vr_rig.gd` dispatch, `player.gd` `_on_trick_shot_changed`) |
| Button remapping | `done` | Settings Controls table → `PlayerSettings` / `user://settings.cfg`. VR: fire, grip, cock, trick shot, gate. Flat: fire, draw, cock, reload. Conflict swaps; Reset Controls |
| Projectile bullets + trails | `done` | `weapons/bullet.gd`, `weapons/bullet_trail.gd`; ribbon uses one camera-facing side vector, first point at muzzle. Shorter linger is planned (`FADE_TIME` 1.6s) |
| Shorter bullet-trail fade | `planned` | Roadmap (Polish / visual); `weapons/bullet_trail.gd` |
| Barrel smoke | `planned` | Roadmap (Polish / visual); stub `muzzle_smoke` already fires from `ImpactFeedback.shot_fired` — wants a lingering plume from the barrel |
| Wind bed + gusts | `planned` | Roadmap (Polish / visual); looping per-arena wind plus visual gusts that trigger `wind_gust` SFX. `ScenarioResource.ambience` slot exists but is empty. Saloon excluded. Checklist: [`SOUND.md`](SOUND.md) |
| Head / torso / arm / leg hitboxes | `done` | `player/hitbox.gd`, `combat/combat_rules.gd` |
| Regional hit effects | `done` | Head instakill; torso/limb 1 HP (default HP 2); arm force-holsters + redraw lock (`arm_disarm_duration`); leg slows move. MP host HP + `_mp_wound`. Arm holster-snap is planned to be replaced by pain-jerk drop (below) |
| Pain-jerk disarm | `planned` | Roadmap (Medium); arm hit tosses the gun up out of the hand instead of `force_holster()`. Catch with either hand; no snap-to-holster / redraw lock. Airborne fumble is the wound window |
| Self-damage | `done` | Player/peer bullets can hit the shooter after `self_hit_grace` (~0.28m) on the **gun-hand arm only**, so a normal muzzle shot does not clip the forearm. Torso / head / off-hand / legs count immediately (muzzle into body, close miss). Same regional HP / arm-disarm / leg-slow; a self-kill loses the duel (`You shot yourself`). AI still excludes its own hitboxes |
| Self-hit hitbox tweak | `done` | Gun-hand arm is a thinner wrist-inset capsule along the limb (`Hitbox.place_along_limb`); off-hand uses a milder inset. Local player + remote avatar. Grace skips only that arm RID |
| Early-draw foul | `done` | duel state machine. Hits only apply during DRAW; a post-foul shot cannot overwrite the DQ |
| Near-miss slow-mo hook | `done` | `TimeManager.notify_near_miss`, `weapons/bullet.gd` |
| Gravity-drop / interactive reload | `done` | Gun-hand B opens; sustained shake dump; torso `AmmoBelt` + **off-hand** `ReloadProbe` overlap; `ChamberArea` seats; `BumpArea` bump or swing close (Flat `R` / Space). Layer `reload`. F3 **Show reload volumes**. Dump/swing in `GameManager.tuning`. Cylinder swings out on gate and indexes 60° per shot (`weapons/revolver/revolver.gd`) |
| Rapid-fire jam | `done` | Flat only (`revolver.jam_enabled`). Cadence heat in `weapons/weapon_base.gd`; jammed pull clicks and does not fire. Clear: look down + hold Space 1.5s. Knobs in debug **Flat Jam** (`jam_safe_interval`, `jam_heat_*`, `jam_chance_scale`, `jam_max_chance`, `jam_clear_hold`, `jam_clear_pitch`). VR / AI never jam |
| Kill-cam (trail fly-along) | `done` | SP + 1v1 MP: `KillCam` + `TimeManager.notify_kill_cam`; flat `Camera3D` fly-along, VR spectator `XROrigin3D` ride; `duel_end` sting on lethal hit. Roadmap death cam + duel replay would replace or sequence after this |
| Death cam (3rd-person corpse) | `planned` | Roadmap (Medium); orbit the dead body, freeze move/fire until rematch; after ~2s (`death_cam_hold`) insert duel replay |
| Duel replay | `planned` | Roadmap (Hard); last ~5s through death + ~2s after (all tweakable); plays after death-cam hold; SP + 1v1 MP |
| Impact / AV polish (SFX, haptics, VFX) | `partial` | Wiring `done` (`ImpactFeedback` + catalogs + XR/flat rumble + boot warmup, [BUG-010](BUGS.md)). Real assets: only `duel_end.wav`. Every other catalog cue is still `PlaceholderAudio`. Checklist: [`SOUND.md`](SOUND.md) |
| Gun release / trick shots | `done` | VR hold-to-hold: toss with hand velocity, catch either hand (or take from the other), holster snap on chosen hip (`holster_side`). Fire/reload only while held; airborne still counts as drawn for fouls. Frozen `RigidBody3D` copies the hand/hip pose (`follow_parent` in `weapons/weapon_base.gd`). MP pose sends free-gun transform + hand/hip flags |
| Revolver Ocelot spin | `done` | VR only: default hold gun-hand A / X (remappable; was stick-down) hangs the revolver on a finger hinge (`SpinPivot` / `WeaponBase`); hand motion builds momentum; release (or stick up if bound to stick) snaps back. Fire still works (muzzle aim). Debug **VR Spin**. MP flag `GUN_SPINNING` |
| Cigarette prop mesh | `done` | `assets/models/props/msc_cigarette.glb` (single node `MSC_Cigarette`, ~8.4 cm × 8 mm, long axis **+Y**, `filter` / `paper` vertex-colored materials, no atlas), wrapped by `props/cigarette.tscn`. Authoring source `msc_cigarette.blend` is `importer="keep"` — rebuild the GLB with `dev/vend_cigarette_blender.py`. No collision shape, so it can never block `ReloadProbe` / belt overlaps. No ember yet |
| Misc prop radial (off-hand equip) | `done` | `props/prop_controller.gd`. Hold to open, highlight, release to equip. VR: off-hand `primary_click` + that stick, `Label3D` wedges facing the HMD (`props/prop_radial.gd`); the open wheel steals that stick from move/turn. Flat: Tab + mouse with look frozen, 2D wheel on the Hud (`ui/prop_radial_overlay.gd`). Release at centre cancels; wedges are **Empty Hand** / **Cigarette**. Refuses to open mid-flight or while a belt round is in hand |
| Cigarette boomerang | `done` | `props/cigarette.gd`. **Hold charges, release throws:** the windup draws the cig back and cocks it over `cig_charge_time`, and the throw range is `lerp(cig_min_range, cig_max_range, charge)`. It then flies a straight line along the hand forward captured at release (`cig_curve` bends it into a boomerang arc; 0 is straight), hangs spinning at the far end for the remainder of `cig_flight_time` so every throw lasts the same regardless of range, then homes back and re-parents inside `cig_catch_radius`. VR: off-hand `fire` trigger, launch along controller `-Z`, gun-hand trigger still fires the revolver; flat: `prop_fire` (G) along camera forward. Pause or death mid-windup cancels instead of throwing. Attach follows a gun hand-swap; VR reload parks it on `MouthAttach`. Debug **Cigarette Boomerang**: `cig_speed`, `cig_min_range`, `cig_max_range`, `cig_charge_time`, `cig_flight_time`, `cig_catch_radius`, `cig_curve`, `cig_spin`, `cig_spin_axis` |
| Airborne fire / mystic trick shots | `planned` | Roadmap (Medium); fire while tossed/spinning; optional tech/mystic flag |

## Modes

| Feature | Status | Notes / key paths |
|---|---|---|
| Free duel (arena + AI pick) | `done` | `GameManager`, main menu Singleplayer page |
| Practice hub (aim range + slots) | `planned` | Roadmap (Medium); non-duel area with regenerating bottles and a casino slot machine |
| Duel vs up to 3 NPCs | `planned` | Roadmap (Medium); local 1–3 AI in one standoff |
| Gauntlet (6 rungs, 3 lives, session score) | `done` | `gauntlet/gauntlet_controller.gd`, ladder `.tres` |
| Persistent gauntlet high scores | `planned` | Score is session-only today |
| 1v1 LAN multiplayer | `done` | `netcode/enet_transport.gd` + UDP discovery; Quest APK gets `INTERNET` + Wi-Fi multicast from `addons/gunslinger_lan_permissions/` at export. **Meta Store SKU is LAN-only** (no Steam / Meta online). Remote avatar is a full greybox (torso/legs/arms + holstered gun). Joiner on `EnemySpawn` faces the host; walk/strafe is world-XZ from look yaw so the 180° spawn root does not invert A/D. Multiplayer page: double-click a LAN host (or Steam lobby on desktop) to join |
| Proximity voice chat | `done` | `autoload/voice_chat.gd` (`VoiceChat`). 16 kHz mono PCM16 on an `unreliable` RPC **channel 2** (so shots cannot stall it). Playback is an `AudioStreamPlayer3D` under `RemoteAvatar/Head/MouthMarker` (`voice_max_distance` / `voice_unit_size`). Always-on uses an RMS **noise gate** (`PlayerSettings.voice_gate_cutoff`, Settings slider, default 0.08) plus a 180 Hz high-pass; optional **push-to-talk**. Mute wins, rides `POSE_FLAG_VOICE_MUTED` + `_voice_state` on channel 1, and raises a mouth **X**. Capture keeps only the newest 40 ms; playback is capped ~40–80 ms. Flat binds `voice_mute` (**M**) / `voice_ptt` (**V**); VR is always-on + the Settings toggle. Quest: `RECORD_AUDIO` + `OS.request_permissions()` |
| 1v1 Steam lobbies | `done` | `netcode/steam_transport.gd` + GodotSteam 4.22 in `addons/godotsteam/` (Steamworks 1.65). **Desktop / Steam SKU only** — hidden and gated off on Android. Create / browse / join public 1v1 lobbies; Steam Datagram Relay. App ID **480** (`steam_appid.txt` + `steam/initialization/app_id`). Windows export copies the App ID file via `addons/gunslinger_steam_export/`. `dev/autotest.gd` `steam` mode still passes if the addon is absent. Leave then HOST / JOIN works in the same process: every session takes an unspent P2P virtual port and advertises it as `gunslinger_port` ([BUG-009](BUGS.md)); `steamcycle` mode covers it against a live client. Steam invite overlay is pause **Invite friends** / Shift+Tab, not auto-opened on HOST |
| MP version check | `done` | Steam `gunslinger_version` compared on browse/join; LAN beacon `ip|name|version`; post-connect `_version_hello` handshake before `session_started` / `peer_joined`. Mismatched list rows disabled; both strings on failure ([BUG-008](BUGS.md)) |
| 4-player multiplayer | `planned` | Roadmap (Hard); 2–4 humans (FFA / 2v2 / 1v3); netcode is 1v1 today. LAN on all SKUs; Steam N-player desktop-only |
| Horde mode | `planned` | Roadmap |
| Mexican standoff (3P) | `planned` | Needs netcode beyond 1v1; related to 4-player MP |
| Campaign | `planned` | Roadmap |

## Content & platforms

| Feature | Status | Notes / key paths |
|---|---|---|
| Revolver mesh | `done` | PSX blaster `assets/models/weapons/wpn_psx_blaster.glb` (cylinder + gate/index anim). Pre-cylinder mesh kept as `wpn_psx_blaster_alt.glb`. Greybox `Barrel` / `Cylinder` / `Grip` stay hidden |
| Gunslinger character mesh | `partial` | Low-poly A-pose (empty hands) at `assets/models/characters/gunslinger.glb` + Blender source `gunslinger.blend`. Split serape/black poncho is a separate Cloth sim (baked for the GLB). Not on AI or the remote avatar yet |
| Arenas (Main Street, Saloon, Train Rooftop, Canyon) | `partial` | Main Street is a Blender greybox kit (`assets/models/scenarios/main_street/`, `dev/build_main_street_blender.py`) — modular GLBs with `-convcolonly` proxies (buildings + terrain), invisible street-side slope colliders on raised boardwalk / depot / store steps, assembled in `scenarios/main_street/main_street.tscn`. Saloon interior is one greybox GLB (`assets/models/scenarios/saloon/saloon_interior.glb`, `dev/build_saloon_blender.py`) instanced in `scenarios/saloon/saloon.tscn`: bar on the west wall, tables east of the 10 m lane, ceiling underside 4.2 m, north balcony with a sub-45° stair. Train Rooftop is a Blender greybox (`assets/models/scenarios/train_rooftop/train_rooftop.glb`, `dev/build_train_rooftop_blender.py`) instanced in `scenarios/train_rooftop/train_rooftop.tscn`: two walkable roofs about 1.2 m apart, invisible walls around them (shot lane stays open), and a local scenery belt (`scenery_belt.gd`) that scrolls Main Street tracks and cacti while canyon walls (0.35×) and buttes (0.12×) drift slower. The belt loops are long enough that the wrap stays in the fog. Canyon is a Blender greybox (`assets/models/scenarios/canyon/canyon.glb`, `dev/build_canyon_blender.py`) instanced in `scenarios/canyon/canyon.tscn`: winding cliff segments, off-lane cover, and a narrow butte whose sheer sides drop to a desert horizon (cacti, scrub, distant mesas; invisible rim), with the 22 m shot lane and both spawn pads kept clear. The scene authors a dusk sky and depth fog that hides the desert edge; each load recolors that sky without moving the fog. Detail-mesh pass still planned for all four. FlatRig collides with world layer 1. |
| Random time of day | `done` | `scenarios/time_of_day.gd`. Each outdoor load picks one t along dawn → noon → late afternoon → dusk and recolors the sun and sky. Fog distances, sky curves, and shadow fade stay on the scene; `fog_light_color` is copied from `ground_horizon_color` so Canyon’s 6 km plain and the Train Rooftop belt wrap still dissolve. Saloon has no `Sun` and stays lamp-lit. Host sends t on `_mp_begin`. F3 `time_of_day` scrubs the live arena |
| Moving train duel set piece | `planned` | Roadmap. Train Rooftop already scrolls scenery past a stopped train; a train passing between the duelists is still this item |
| Horseback duel stage | `planned` | Roadmap (Medium); both duelists mounted; horse speeds vary randomly |
| AI archetypes (Drunk / Sheriff / Ghost) | `done` | `ai/archetypes/*.tres`; Sheriff/Ghost strafe around the enemy spawn marker (not scene origin). `reload_time` per archetype. Design: [Drunk](design/characters/drunk.md), [Sheriff](design/characters/sheriff.md), [Ghost](design/characters/ghost.md) |
| More enemy NPCs | `planned` | Roadmap (Medium); extra archetypes as new `ai/archetypes/*.tres`, then free-duel pick + gauntlet rungs. First design: [Half-head](design/characters/half-head.md) |
| NPC reload | `done` | Spent cylinder is a combat window: `AIState.RELOADING`, arm dip, `open_gate` → wait `reload_time` (Drunk 3.5 / Sheriff 2.2 / Ghost 1.4, scaled by `ai_speed_mult`) → `fill_cylinder` / `close_gate`. Same 6-round limit as the player. Arm hit / death / duel-over cancel and close the gate; ammo stays empty across disarm. `ai/duelist_ai.gd`, `WeaponBase.fill_cylinder` |
| Quest 3 / PCVR / flat harness | `done` | OpenXR + `--flat`. Meta Store APK: LAN MP only; Steam lobby UI is hidden |
| Ranking / leaderboards | `planned` | Roadmap (Hard); Steam / desktop. Not on Meta Store |
| Mod support | `planned` | Roadmap |

## Tooling

| Feature | Status | Notes / key paths |
|---|---|---|
| Debug panel + presets | `done` | `autoload/debug_menu.gd`, `user://*.cfg` |
| Settings screen (main menu) | `done` | `ui/settings_menu.tscn` on main menu and pause. Master volume, **Voice Chat** block (voice volume, mute mic, push-to-talk, noise gate / voice-activation cutoff, input/output device, live mic level), holster side, VR turn mode; flat-only mouse sensitivity, window mode, resolution (**Apply Display**); Controls remapping (VR + flat). Scrollable panel. `PlayerSettings` → `user://settings.cfg`. Device pickers are desktop-only (`can_pick_audio_devices()`); the panel holds a `VoiceChat` mic monitor only while it is visible. Debug panel stays F3 / Quest menu on the main menu |
| Main menu SP / MP split | `done` | Landing is Singleplayer / Multiplayer / Settings / Quit (`ui/main_menu.tscn`). SP page: gauntlet + free-duel pick. MP page: LAN / Steam host-join. Page switch like Settings (`show_mode_select` / `go_back`). LAN/Steam browse only while the MP page is open |
| In-duel pause / MP overlay | `done` | ESC (flat) / VR menu button. SP sets `get_tree().paused`; MP is overlay-only. Resume, Settings, Restart Duel/Gauntlet (host-only in MP), Quit to main menu. `ui/pause_menu.tscn` |
| Blender MCP | `done` | Project `.cursor/mcp.json` → `uvx blender-mcp` → Blender addon on `localhost:9876`. Client helper `dev/blender_mcp.py` |
| In-game version tag | `done` | HUD corner + main menu; `ProjectSettings` `application/config/version` (`VERSION`) |
| Boot loading screen | `done` | `ui/loading_screen.tscn` on the HUD (flat) plus an HMD cover in VR. Compiles combat AV via `ImpactFeedback.warmup()` while `GameManager` is still `BOOT`, then opens the menu |
| Headless autotests | `done` | `dev/autotest.gd` (`duel`, `gauntlet`, `load`, `host`, `join`, `steam`) |
| Quest APK sideload | `done` | `dev/install-quest.bat` (`adb install -r` → `builds/vr/gunslinger-quest.apk`) |
