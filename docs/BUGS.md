# Bug tracker

Open gameplay / visual defects. Agents add new reports here and move items to **Fixed** when a change lands (same session as the code). Do not invent bugs.

Status: `open` | `investigating` | `fixed` | `wontfix`  
Severity: `blocker` | `major` | `minor` | `polish`

How to file: next unused `BUG-NNN`, repro steps, arena/mode if known, screenshot under `docs/bugs/` when useful.

---

## Open

_(none)_

---

## Fixed

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

**Fix:** `ImpactFeedback.warmup()` runs from `GameManager.setup` on a boot loading screen (`ui/loading_screen.tscn`) before the menu opens. It precaches every `AudioCatalog` cue, builds the shared slug mesh, then parents a tiny compile draw to the live camera (XR swapchain / flat viewport) for a few frames so particle, trail, light, and gunshot shaders/mixers hitch behind "Loading..." instead of the first round. VR covers the HMD with a dark quad. Headless autotest skips the GPU draw.

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
