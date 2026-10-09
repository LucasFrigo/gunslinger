# Bug tracker

Open gameplay / visual defects. Agents add new reports here and move items to **Fixed** when a change lands (same session as the code). Do not invent bugs.

Status: `open` | `investigating` | `fixed` | `wontfix`  
Severity: `blocker` | `major` | `minor` | `polish`

How to file: next unused `BUG-NNN`, repro steps, arena/mode if known, screenshot under `docs/bugs/` when useful.

---

## Open

_None._

---

## Fixed

### BUG-020 — `load` (and occasionally `join` / `practice` / `horde`) headless autotest segfaults at shutdown after AUTOTEST PASS

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-09 |
| Fixed | 2026-10-09 |
| Platforms | Windows, Godot 4.7. Seen in the headless harness; any quit runs the same teardown. |
| Areas | `autoload/script_keepalive.gd`, Godot `GDScriptLanguage::finish()` |

**What:** The suite prints `AUTOTEST PASS`, then the process exits with code 139 (segfault) during scene-tree teardown, before `XR: Clearing primary interface`, with no backtrace. It happened in 6 of 15 `load` runs and 1 of 3 `join` runs, once in `practice` (1 run), and once in `horde` (after the hit chunks v2 rewrite). A script that checks the exit code reads a passing suite as a failure.

**Repro:**
1. `--headless --path . -- --autotest=load` (intermittent; repeat it).
2. Check the exit code after `AUTOTEST PASS`.

**Notes:** It still happened with `BodyChunks` creation and the chunk cache bypassed, so it is believed to predate the hit-chunks work, but that is not confirmed. Separately, `ragdoll` and `gauntlet` print "ObjectDB instances leaked" at exit.

**Cause:** Not ENet or Steam (an explicit `steamShutdown` + peer close at exit did not change the rate). Every crash faulted at the same address in the Godot exe (Windows Application log, event 1000). Disassembly puts it in `GDScriptLanguage::finish()`, the shutdown loop over every live script. In 4.7 that loop reads the next list entry, then drops its `Ref` to the current script. If that frees a script the current one owned (a preloaded scene's script, an inner class), the next read is freed memory. That read probably happens on every exit; it only faults when the freed page has been reused, which is why it was intermittent and more likely under CPU load. Upstream `master` rewrote `finish()` to copy the list first.

**Fix:** New first autoload `ScriptKeepalive` (`autoload/script_keepalive.gd`). On `_exit_tree` it pins every cached `.gd` (plus itself) in a static var. The loop walks newest-first, so it reaches this script, the oldest, last. Nothing can free mid-walk until that final `clear()` drops the static var, and removals there keep the list consistent. Verified with 4 `load` runs in parallel: 6 segfaults in 36 runs before, 0 in 48 after. Every other suite passes, including host/join. Remove the autoload when the engine moves past 4.7.

### BUG-019 — Ragdoll limbs rest on the invisible rooftop walls

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-08 |
| Fixed | 2026-10-08 |
| Platforms | All. Train Rooftop. |
| Areas | `characters/body_ragdoll.gd`, `scenarios/scenario_base.gd` |

**What:** When a duelist ragdolled on Train Rooftop, a hand or other limb could stop against the invisible side and end walls and hang in mid-air.

**Repro:**
1. Free duel on Train Rooftop.
2. Kill the NPC (or die) near a side of the roof.
3. A limb can rest on an invisible wall.

**Fix:** Ragdoll bodies mask the world layer, and the `Guard*` collision boxes are on it. `ScenarioBase` now puts every `Guard*` static body in the `ragdoll_ignore` group, and `BodyRagdoll` adds a collision exception for each when it builds a body. Walkers, bullets, and props still hit the walls. Covered by `--autotest=multi`.

### BUG-018 — Sheriff and Ghost teleport while strafing

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-08 |
| Fixed | 2026-10-08 |
| Platforms | All. Every arena; most visible on Train Rooftop. |
| Areas | `ai/duelist_ai.gd` |

**What:** A strafing NPC (Sheriff, Ghost) snapped sideways by up to 1.5 m at times.

**Repro:**
1. Free duel against the Sheriff.
2. Hit its arm so it drops the gun, then wait for it to redraw.
3. It jumps sideways when it draws again.

**Fix:** `begin_draw` re-captured the strafe origin each time it ran, including the redraw after a disarm, while the strafe phase kept running, so the position jumped by the old offset. The origin is now captured only at placement. The strafe line is also fixed at placement (`_strafe_axis`) instead of following the facing, which with several NPCs swung the offset whenever one retargeted. Covered by `--autotest=multi`.

### BUG-017 — NPC shots pulse the player's controller

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-08 |
| Fixed | 2026-10-08 |
| Platforms | VR (the haptic is a controller rumble). SP free duel and gauntlet. |
| Areas | `ai/duelist_ai.gd`, `autoload/impact_feedback.gd` `shot_fired` |

**What:** Every shot an NPC fired rumbled the player's controller as if the player had pulled the trigger.

**Repro:**
1. VR free duel.
2. Stand still while the NPC fires.
3. The controller buzzes on each NPC shot.

**Fix:** `WeaponBase` passes the revolver's `shooting_hand` to `ImpactFeedback.shot_fired` on every shot, and the NPC's revolver kept the default `right_hand`. `DuelistAI._ready` now clears it to `&""`, and `ImpactFeedback.shot_fired` skips the haptic when the hand is empty. The player always sets the hand in `attach_to` before it fires.

### BUG-016 — Mannequin knees bend backward

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-07 |
| Fixed | 2026-10-07 |
| Platforms | Flat (own body), AI, remote avatar, mesh lab. VR hides the local body, so the other player is who sees the step. |
| Areas | `characters/dummy_body.gd` `_apply_legs` |

**What:** On the in-place step, the knee bowed backward. The shin swung toward the face instead of folding behind the thigh.

**Repro:**
1. Flat free duel, or F3 mesh lab with Walk on.
2. Walk and watch the legs.
3. The knee breaks the wrong way while the trailing leg swings.

**Fix:** The knee uses the opposite rotation from the thigh swing, so a positive step toward the face flexes the shin backward. The foot still cancels the thigh and that signed knee so it stays level.

### BUG-015 — Replay freezes the dead player's body

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-04 |
| Fixed | 2026-10-06 |
| Platforms | SP free duel and gauntlet (killed by the AI). Flat and VR. The same local-player path is what a dead peer would see in 1v1; that side is not confirmed in a playtest. |
| Areas | `player/player.gd` `apply_replay_pose`, `freeze_replay_body`; `autoload/death_cam.gd` `_enter_trailing` |

**What:** On the replay, your mannequin stays in the pose it died in. The revolver still follows the clip. The body should retrace the draw, aim, and steps from before the shot.

**Repro:**
1. Free duel or gauntlet against an AI.
2. Lose — the bot lands the killing shot.
3. Wait through the fly-along and the corpse hold until the replay starts.
4. Your mesh does not move. Only the gun does.

**Fix:** `Player.apply_replay_pose` turns the pose writers back on for the dead local mannequin and places it from the recorded head, hands, and gun flags. The revolver is pinned to the recorded pose (hip, hand, spin, or in the air, with the gate and cylinder). An off-hand prop and a held reload round are ghosted along the clip. A travel marker drives the in-place step, including in VR where the rig stays put. When the clip ends, `freeze_replay_body` stops those writers again so the corpse orbit holds the death pose.

### BUG-014 — VR prop wheel is mirrored against the stick

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-04 |
| Fixed | 2026-10-04 |
| Platforms | VR (Quest / OpenXR) |
| Areas | `props/prop_radial.gd` |

**What:** The off-hand misc wheel highlights the opposite side from the stick, and the wedge names read backwards. Stick up still hits **Empty Hand** at the top, but stick right lights the wedge on the left.

**Repro:** In VR, hold the off-hand stick click to open the prop wheel. The words are mirrored. Push the stick toward **Cigarette** (clockwise from the top). The highlight lands on the wedge on the other side.

**Fix:** `Label3D` draws on +Z and is double-sided, so aiming -Z at the headset showed the glyphs from behind. The ring now uses model-front (`looking_at` with `use_model_front`), which puts the readable face toward the HMD and local +X on the viewer's right. Wedges stay clockwise from the top, matching `highlight_index` and the flat wheel.

### BUG-013 — VR height and hitboxes wrong after booting seated

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-09-29 |
| Fixed | 2026-09-30 |
| Platforms | Quest 3 (playtest). Any OpenXR session that starts seated is the same case. |
| Areas | `player/player.gd` `_follow_body`, `player/vr_rig.gd`, `ui/settings_menu.gd` |

**What:** Booting the Quest 3 while sitting, then standing up to play, leaves height wrong. Hitboxes are the part that breaks: the head follows the headset, and the torso, legs, shoulders, and holster stay at a fixed offset from the player root.

**Repro:**
1. Put on the Quest 3 and start the game while seated.
2. Stand up and play.
3. The head sits off the body capsules. Shots that should hit the torso miss, or land on the wrong region.

**Why the runtime does not save it:** The session asks for a floor space (`local-floor` / `bounded-floor` in `start_xr.gd`). `_follow_body` pins the torso at `global_position.y + 1.1`, the legs at `+ 0.4`, and the holster at `+ 1.0`. A floor estimate taken while seated does not move those when you stand.

**Fix:** Settings **Standing height** stores headset height above the player root (cm, or feet and inches). **Calibrate** samples the headset while you stand. **Reset view height**, the next VR launch, and each duel spawn set `XROrigin3D` Y so the headset matches that height. Torso, legs, and holster stay on those floor offsets. Until a height is saved, the runtime floor is left alone.

### BUG-011 — Revolver falls through the practice porch deck

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-09-26 |
| Fixed | 2026-09-30 |
| Platforms | VR and flat, practice hub |
| Areas | `dev/build_practice_hub_blender.py` `PorchDeck`, `scenarios/practice_hub/practice_hub.gd` `_align_ground_collision` |

**What:** On the practice porch, a dropped revolver ends up under the deck. Reported 2026-09-26.

**Repro:**
1. Tutorial / Practice (VR boots here already).
2. Stand on the porch and drop or toss the revolver onto the deck.
3. The gun rests under the planks instead of on top of them.

**Root cause:** `PorchDeck` is visual only (`put`, no collision proxy). `_align_ground_collision` replaces the imported ground with `LotPad`, whose top is y = 0. The deck mesh sits on that plane (about 6 cm thick, center y = 0.03), so a loose rigid body lands on the pad and clips through the planks.

**Fix:** `_align_ground_collision` adds a `PorchDeck` static pad matching the plank slab (top y = 0.06, same as `PlayerSpawn`). A dropped revolver rests on the boards. The mesh stays visual in the Blender build: a matching `-convcolonly` proxy would overlap the spawn-pad check (ankles start at z = 0.05). Autotest `practice` raycasts the deck and drops the revolver.

### BUG-012 — VR menu buttons open Meta and Steam, not the game

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-09-26 |
| Fixed | 2026-09-30 |
| Platforms | Quest through SteamVR. Flat Esc path is separate. |
| Areas | `player/vr_rig.gd` `_action_for_hand`, `player/player.gd` `draw_hand_name`, `autoload/player_settings.gd` |

**What:** The in-game menu did not open in VR. The Meta button opens the Meta system menu and the hamburger opens the Steam menu, so the game never received those presses.

**Fix:** Pause (and the debug panel on the main menu) opens from the draw-hand stick click. That is the right stick while holstered on the right hip, the left stick when Holster Side is Left, and whichever hand is holding the gun once it is drawn. The off-hand click stays the prop wheel. **Pause** is a Controls row and can be rebound; moving it off the stick click swaps the previous action onto that click, and the prop wheel stays on the off hand. Flat pause stays Esc. A hamburger press still toggles the menu when the runtime actually delivers it.

### BUG-010 — First shot hitch (short freeze / FPS drop)

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-09-16 |
| Fixed | 2026-09-16 |
| Platforms | SP and MP; VR and flat (desktop). First launch of a process. |
| Areas | `autoload/impact_feedback.gd`, `weapons/bullet.gd`, `weapons/bullet_trail.gd`, `assets/vfx/vfx_catalog.gd`, `assets/audio/audio_catalog.gd` |

**What:** The first shot after opening the game hitchs the frame for a moment (full freeze or a sharp FPS dip). Later shots in the same run are fine. Seen in both single-player and multiplayer, and in both VR and flat.

**Repro:**
1. Start the game (editor or exported build; a fresh process).
2. Enter a free duel, gauntlet, or 1v1 MP.
3. Fire the first round.
4. The game stutters briefly. Further shots do not repeat it.

**Root cause:** First trigger pull compiled combat AV that had never been drawn or mixed: `GPUParticles3D` muzzle smoke, the unshaded alpha trail ribbon, the slug mesh, muzzle OmniLight, and procedural gunshot PCM. Later shots reused those pipelines.

**Fix:** `ImpactFeedback.warmup()` runs from `GameManager.setup` on a boot loading screen (`ui/loading_screen.tscn`) before the menu opens. It precaches every `AudioCatalog` cue, builds the shared slug mesh, then parents a compile draw to the live camera (XR swapchain / flat viewport) for several frames so particle, trail, light, and gunshot shaders/mixers hitch behind "Loading..." instead of the first round. The draw has to actually rasterize: a 0.001-scale host is frustum-culled on Compatibility (regressed after more VFX landed). VR covers the HMD with a dark quad. Headless autotest skips the GPU draw.

---

### BUG-009 — Steam: cannot join or create a lobby after leaving

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-09-03 |
| Fixed | 2026-09-16 |
| Platforms | 1v1 Steam (desktop) |
| Areas | `netcode/steam_transport.gd`, `autoload/network_manager.gd` `leave` |

**What:** After leaving a Steam lobby, join and create both fail in the same process.

**Repro (leave / rejoin):**
1. HOST (STEAM), second player joins, play or quit.
2. Leave the lobby (Quit to menu / leave session).
3. Same process: JOIN an existing lobby, or HOST (STEAM) again.
4. Join and create fail until the game is restarted.

**Root cause:** GodotSteam 4.22's `SteamMultiplayerPeer.close()` does not release its Steam P2P listen socket, so Steam keeps that virtual port occupied for the rest of the process. `host_with_lobby` and `connect_to_lobby` both hardcode virtual port **0**, so the second session — host or join — died in `create_host` / `create_client` with `ERR_CANT_CREATE`. Confirmed by probe: after `close()`, a raw `Steam.createListenSocketP2P` on the same port returns `LISTEN_SOCKET_INVALID`, while a fresh port succeeds every time. Steam itself reuses ports fine when the socket is genuinely closed, so the leak is in the addon.

**Fix:** Sessions no longer use the port-0 lobby helpers. Each one takes a virtual port this process has not spent (port 0 first, then random 1–999) via `create_host` / `create_client`, and the host publishes it as lobby metadata `gunslinger_port` so joiners dial the right one. `SteamTransport.close()` drops the peer before leaving the lobby and clears any in-flight request, `NetworkManager.leave()` always tears the long-lived Steam transport down (it used to skip it once `transport` was nulled), a lobby handed to us by a late Steam callback is left again instead of adopted, and `createLobby` / `joinLobby` now time out after 10s instead of hanging the menu. Since `create_host` / `create_client` do not set the addon's `tracked_lobby`, `SteamTransport` watches `lobby_chat_update` itself to drop the peer when the other player leaves the lobby.

**Also confirmed:** "cannot join while drawn" was not a separate bug. A lobby in an active 2/2 duel is both `setLobbyJoinable(false)` and filtered out of the browse list, which is intended.

**Regression test:** `--autotest=steamcycle` drives create → leave → create, an abandoned create, and a dead join against a live Steam client; it is a no-op when Steam is absent (CI).

### BUG-008 — MP does not reject mismatched game versions

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-09-03 |
| Fixed | 2026-09-09 |
| Platforms | 1v1 Steam (desktop); LAN |
| Areas | `netcode/steam_transport.gd`, `netcode/lan_discovery.gd`, `autoload/network_manager.gd` |

**What:** Clients could join a host running a different `application/config/version`. Steam wrote `gunslinger_version` on lobby create but neither browse nor join compared it. LAN had no version metadata.

**Fix:** Steam and LAN browse show versions and disable incompatible rows; join refuses when the known host version differs. LAN beacon is `ip|name|version`. After connect, a `_version_hello` handshake gates `session_started` / `peer_joined`; mismatch shows both strings and disconnects the joiner (host stays up).

### BUG-007 — Foul loss overwritten by a later hit

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-21 |
| Fixed | 2026-08-21 |
| Platforms | SP AI duels (MP hit path already ignores `RESOLUTION`) |
| Areas | `gauntlet/duel_manager.gd` `_on_enemy_died` / `_finish_sp`, `player/hitbox.gd`, `weapons/bullet.gd` |

**What:** When a duel ends by disqualification (early draw), you can still fire. Hitting the opponent then overwrites the defeat with a win.

**Repro:**
1. Free duel vs AI.
2. Draw before the bell (foul / DQ).
3. After the loss is declared, shoot and hit the NPC.
4. The result flips to a win ("Clean kill").

**Fix:** Hits only apply during DRAW (`DuelManager.accepts_hits`). `Hitbox.receive_hit` and `mp_report_hit` ignore standoff / wait-for-bell / `RESOLUTION`. `_on_enemy_died` no longer treats a post-foul AI death as a win; `_finish_sp` is a no-op once `RESOLUTION` is set.

### BUG-006 — Joiner spawn: strafe is reversed (A ↔ D)

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | 1v1 MP (LAN); joiner / second player |
| Areas | `player/flat_rig.gd` walk, `player/vr_rig.gd` `_apply_locomotion` / `reset_locomotion`, `player/player.gd` `reset_for_duel` |

**What:** When the joining player spawns, movement left/right is inverted. Pressing A strafes as if D were held (and the reverse). Host on `PlayerSpawn` is unaffected.

**Repro:**
1. Host a LAN duel; second player joins (placed on `EnemySpawn`).
2. At standoff, press A / D (or left-stick strafe).
3. Strafe goes the opposite way of the input.

**Notes:** Related to BUG-004’s 180° joiner yaw (Player root + VR origin around HMD). Host yaw is ~0 so the same locomotion path looked correct there.

**Fix:** Flat walk and VR stick locomotion now move in world XZ from look yaw (`global_position`). The previous path built a world-facing move vector (VR) or used the rig basis (Flat) and added it to local `position`, so EnemySpawn’s 180° parent yaw flipped strafe.

---

### BUG-005 — PvP opponent has no visible body (hard to read aim)

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | 1v1 MP; both flat and VR |
| Areas | `player/remote_avatar.tscn`, `player/remote_avatar.gd` |

**What:** In PvP the other player is only a head/hat plus small hand boxes. Torso and legs are hitboxes with no mesh (unlike the AI capsule `Body`). The revolver stays hidden until the drawn pose flag. Silhouette and aim are hard to read.

**Repro:**
1. Host + join a LAN duel.
2. Look at the opponent during standoff / draw.
3. Compare to a free-duel NPC, who has a full body mesh.

**Fix:** `RemoteAvatar` now has greybox torso/leg meshes on the hitboxes and shoulder-to-hand arm cylinders. The revolver stays visible on a hip holster until `POSE_FLAG_GUN_DRAWN`, then reparents to the right hand.

---

### BUG-004 — Joiner spawns facing away from the opponent

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | 1v1 MP (LAN); joiner / second player |
| Areas | `player/player.gd` `reset_for_duel`, `player/flat_rig.gd` `face_yaw`, `player/vr_rig.gd` `reset_locomotion` |

**What:** The joining player is placed on `EnemySpawn` but looks the default direction (back to the host) instead of toward them. Host on `PlayerSpawn` is fine.

**Repro:**
1. Host a LAN duel, second player joins.
2. At standoff, the joiner is on the NPC mark with their back to the opponent.

**Fix:** `reset_for_duel` copies the marker transform onto the Player root (EnemySpawn is already yawed 180° toward the host). Flat `face_yaw` now treats its argument as world yaw and stores only the local remainder, so the joiner is not spun twice. VR `reset_locomotion` yaws the origin around the HMD so playspace facing matches the marker -Z.

### BUG-003 — Quest 3 cannot host or see LAN lobbies

| | |
|---|---|
| Status | `fixed` |
| Severity | `blocker` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | Quest 3 standalone APK (not Steam Link + editor) |
| Areas | `export_presets.cfg`, `addons/gunslinger_lan_permissions/`, `netcode/enet_transport.gd`, `netcode/lan_discovery.gd` |

**What:** After sideloading the Quest APK, HOST (LAN) on the headset shows "Can't create". Hosting on PC never appears in the Quest LAN list. Steam Link + running from the Godot editor works (game is on Windows).

**Repro:**
1. Export `Quest 3 (Android)`, `dev\install-quest.bat`.
2. PC: HOST (LAN). Quest: LAN host list stays empty.
3. Quest: HOST (LAN) → `Could not host LAN game: Can't create`.

**Fix:** The sideloaded APK had no `INTERNET` (aapt showed only OpenXR permissions). Godot's Export dialog rewrites `export_presets.cfg` from its checkboxes, which dropped the flags on re-export. An editor export plugin now injects `INTERNET` / Wi-Fi multicast into the Android manifest at gradle export; ENet and discovery bind IPv4 `0.0.0.0`; discovery announces on subnet broadcasts with the host IP in the pong. Confirmed on Quest 3 standalone after a fresh APK install (Steam Link + editor was never this path).

### BUG-002 — NPC teleports at draw (countdown pose ≠ duel pose)

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | SP AI duels; map-dependent |
| Areas | `ai/duelist_ai.gd`, `autoload/game_manager.gd`, spawn markers in `scenarios/` |

**What:** During standoff / wait-for-bell the NPC stands at one spot; when the duel actually starts they snap closer or to a different position.

**Repro:**
1. Free duel or gauntlet on several arenas (especially ones with a long gap between `PlayerSpawn` and `EnemySpawn`: Canyon, Train Rooftop).
2. Watch the NPC through “Holster” / “Wait for the bell…”.
3. On DRAW, note whether they jump.

**Fix:** `_spawn_position` was captured in `_ready` from local `position` (packed-scene origin) before `GameManager` applied `get_enemy_spawn()`. Sheriff/Ghost strafe then wrote `global_position = _spawn_position + right * sin(...)` and snapped toward world origin. Spawn is now recaptured as `global_position` after placement, and again when the bell rings.

### BUG-001 — Double / bent bullet traces

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | Player and NPC shots (seen in flat; VR unconfirmed) |
| Areas | `weapons/bullet_trail.gd`, `weapons/bullet.gd` |

**What:** One shot drew two glowing traces that met at a sharp angle (sideways V). The kink / split changed with look direction.

**Screenshot:** [`docs/bugs/BUG-001-double-trail.png`](bugs/BUG-001-double-trail.png)

**Fix:** Trails were recording the first point in `_ready` before the bullet was moved to the muzzle (kink from scene origin). The camera-facing ribbon also rebuilt a per-vertex `forward.cross(to_eye)` that flipped along the shot. First point is now taken after spawn placement; the ribbon uses one stable side vector for the whole strip.
