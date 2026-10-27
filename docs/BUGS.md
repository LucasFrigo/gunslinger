# Bug tracker

Open gameplay / visual defects. Agents add new reports here and move items to **Fixed** when a change lands (same session as the code). Do not invent bugs.

Status: `open` | `investigating` | `fixed` | `wontfix`  
Severity: `blocker` | `major` | `minor` | `polish`

How to file: next unused `BUG-NNN`, repro steps, arena/mode if known, screenshot under `docs/bugs/` when useful.

---

## Open

### BUG-034 — NPCs start duels with the gun already drawn, not holstered on the hip

| | |
|---|---|
| Status | `open` |
| Severity | `minor` |
| Filed | 2026-10-27 |
| Platforms | Seen in a Canyon duel (`The Drunk`); platform not recorded. |
| Areas | `ai/duelist_ai.gd`, `weapons/weapon_base.gd`, `gauntlet/duel_manager.gd` |

**What:** At the start of a duel the NPC already holds the gun in its hand, pointed forward, instead of having it holstered on its hip until the draw.

**Repro:**
1. Start a duel against an NPC (The Drunk on Canyon seen; other archetypes untested).
2. Look at the NPC during the countdown, before the draw signal.
3. The gun is in its hand, not on its hip.

**Notes:** Not yet investigated. Check whether this is the same for every archetype and arena, and whether it relates to BUG-028 (holstered gun rotation) or BUG-029 (replay NPC draw animation).

---

### BUG-033 — Train Rooftop: bullets hit the invisible walls

| | |
|---|---|
| Status | `open` |
| Severity | `minor` |
| Filed | 2026-10-27 |
| Platforms | Train Rooftop; platform not recorded. |
| Areas | `scenarios/scenario_base.gd` (`Guard*` collision boxes), `scenarios/train_rooftop/train_rooftop.tscn` |

**What:** Bullets stop against the invisible `Guard*` walls around the rooftop instead of flying on.

**Repro:**
1. Free duel on Train Rooftop.
2. Shoot toward a side or end of the roof, or at an angle that crosses a guard box.
3. The bullet hits the invisible wall.

**Notes:** Not yet investigated. BUG-019 left bullets colliding with the `Guard*` boxes on purpose (only ragdolls ignore them), so the bullet's collision mask likely needs the same exception, or the guards should leave the bullet layer. Walkers and props should still be blocked.

---

### BUG-030 — Replay: off-hand props can be misplaced (cigarette floats ahead of the hand)

| | |
|---|---|
| Status | `open` |
| Severity | `minor` |
| Filed | 2026-10-19 |
| Platforms | Seen in the kill replay; platform not recorded. |
| Areas | `autoload/replay_buffer.gd` (`prop` pose, `PROP_PLACE_HAND`), `player/replay_objects.gd` |

**What:** In the replay, off-hand props are sometimes not where the hand is. The cigarette was seen floating ahead of the hand.

**Repro:**
1. Hold an off-hand prop (cigarette seen; others untested) during a duel.
2. Finish the duel and watch the replay.
3. Look at the prop relative to the hand.

**Notes:** Not yet investigated. Check whether the other props (coin, ace, bottle) are also offset, and whether the recorded `prop` transform is hand-relative or world-space when replayed.

---

## Fixed

### BUG-032 — Flat: the gun twirl is dead after a win, once the replay ends or is skipped

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-26 |
| Fixed | 2026-10-26 |
| Platforms | Flat (the twirl is flat-only). VR hinge spin was checked and is not affected. |
| Areas | `player/player.gd` (`twirl_allowed`) |

**What:** After winning a duel, holding the twirl bind (T) did nothing once the replay finished or was skipped, although the gun was back in hand.

**Repro:**
1. Flat run, free duel, draw and shoot the NPC.
2. Let the replay play out (or skip it with fire), then hold the twirl bind.

**Cause:** `twirl_allowed()` only allowed `DuelManager.State.DRAW` (or the practice hub). A kill moves the duel to `RESOLUTION`, so the twirl stayed refused for the rest of the round. `_combat_blocked()` already keeps the fly-along and the clip itself locked.

**Fix:** `twirl_allowed()` also allows `RESOLUTION` while the player is alive and `DeathCam.blocks_combat()` is false. A loser is dead and the fly-along and replay still block. `--autotest=duel` (`_spin_after_replay_ok`) holds the bind right after a win's replay, checks that a dead player may not twirl, and checks spin and twirl in the next duel. It failed before the fix. Roadmap 1.4.

### BUG-031 — Canyon: the desert plain draws a line behind the enemy instead of fading into the fog

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-23 |
| Fixed | 2026-10-23 |
| Platforms | All (seen in a flat run; the fog is the same in VR). |
| Areas | `scenarios/canyon/canyon.tscn` (`Environment` depth fog) |

**What:** From `PlayerSpawn` the 6 km plain under the butte drew as its own darker band, behind the enemy from the shins to the chest, with a bright edge line where it met the sky. The distant mesas drew almost unfogged.

**Repro:**
1. Load the Canyon (any time of day) in a flat run.
2. Stand at `PlayerSpawn` and look down the lane past `EnemySpawn`.

**Cause:** In depth mode `fog_density` is the fog's maximum opacity (Godot's Environment reference), and the Compatibility shader multiplies the depth fog by it. At 0.012 the fog never passed 1.2%, so begin 60 m and end 220 m did almost nothing.

**Fix:** `fog_density` 1.0 in `canyon.tscn`, with `fog_depth_begin` 80 and `fog_depth_end` 400. The user found 60 and 220 at full density too strong, since the far mesas washed out. Curve 1.4 stays. The fog now takes about 0.2% at 100 m, 28% at 220 m, and all of it from about 390 m, where the plain lies. A flat capture of Lane P before the fix showed the plain at (204, 94, 55) at dusk under a bright line (242, 140, 71), against a sky of (240, 128, 64) at the horizon. After it, the plain draws (243, 140, 71), the horizon's own colour, at dusk and (237, 153, 112) at dawn, with no line, and Mesa5 keeps its colour ((255, 140, 62) at dusk). `--autotest=load` (its time-of-day horizon contract) passes. Design: `docs/design/scenarios/canyon.md` F1 and H.

### BUG-029 — Kill replay: the NPC's hand stays at its side, no draw animation

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-15 |
| Fixed | 2026-10-15 |
| Platforms | Single player (flat seen; VR shares the path). |
| Areas | `ai/duelist_ai.gd` (`apply_replay_pose`, `_aim_replay_hand`) |

**What:** In the replay after an NPC died mid-draw, its arm and gun swung up but the mannequin's hand stayed by its side, so it looked shot without drawing.

**Repro:**
1. Play a duel and kill the NPC while it is drawing.
2. Watch the replay and look at the NPC's gun hand.

**Cause:** The pose was recorded and replayed correctly (`arm`, `gun`, flags). The gun-arm IK aims at the revolver's `GripAnchor` through a relative `target_path`. The lethal hit flings the revolver into the scene root (`release_into_world`), so the path resolved to nothing and the IK wrote no hand pose for the whole clip.

**Fix:** `DuelistAI.apply_replay_pose` retargets the IK each frame (`_aim_replay_hand`): the `GripAnchor` while the recorded flags have the gun drawn and held, else the arm's grip target, with the pistol or open hand curl. `--autotest=duel` kills an NPC mid-draw and checks the hand stays within 0.2 m of its gun in the replay.

### BUG-022 — Host logs ENet `Unable to send packet on channel 0` when two clients quit at the same moment

| | |
|---|---|
| Status | `fixed` (one engine-side line accepted) |
| Severity | `minor` |
| Filed | 2026-10-11 |
| Fixed | 2026-10-15 |
| Platforms | Windows, Godot 4.7. Seen in the headless harness (`lobbyhost` + two `lobbyjoin`); not seen in play. |
| Areas | `autoload/network_manager.gd` (`_queue_peer_disconnected`, `_sync_roster`), `gauntlet/duel_manager.gd` (`host_peer_left`) |

**What:** In the three-process lobby tests the host prints the engine error `Unable to send packet on channel 0, max channels: 0` when both joiners exit together at the end of the run. The suites still print `AUTOTEST PASS`.

**Repro:**
1. Start `--autotest=lobbyhost`, then two `--autotest=lobbyjoin` processes.
2. Search the host's `stderr` for `Unable to send packet` (before the fix: 3 errors in 6 of 8 runs).

**Cause:** Two peers that quit together reach the host in one poll. ENet marks both dead before the first `peer_disconnected` fires, so the sends made from that handler, `_mp_down.rpc` in `host_peer_left` and `_roster_sync.rpc_id` in `_sync_roster`, hit the second one.

**Fix:** `NetworkManager` handles the engine's `peer_disconnected` after the poll (`_queue_peer_disconnected` defers `_on_peer_disconnected`), and `_sync_roster` skips ids no longer in `multiplayer.get_peers()`. Both script-side errors are gone.

**Accepted:** one error remains, with no GDScript frame, in 5 of 5 passing runs after the fix, at the end of the host's run. It is raised inside the engine, not from a script call. Probably the engine's relay notification to the other quitting peer, but unconfirmed: turning `multiplayer.server_relay` off ended the runs early at the voice step, so it proved nothing. Nothing breaks because of it, and the owner accepted it on 2026-10-15.

### BUG-023 — `Basis must be normalized` error from `ai/duelist_ai.gd` in the DRAWING branch

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-11 |
| Fixed | 2026-10-15 |
| Platforms | Windows, Godot 4.7. Seen in the headless harness (the host of `lobbyhost` + two `lobbyjoin`, which runs a Sheriff NPC); not seen in play. |
| Areas | `ai/duelist_ai.gd` (`_animate_arm`, called from the `AIState.DRAWING` branch of `_process`) |

**What:** The host printed the engine error `Basis must be normalized in order to be casted to a Quaternion` from the NPC's DRAWING branch, once per frame for ~50 frames in a run. Every run still printed `AUTOTEST PASS`.

**Repro:**
1. Start `--autotest=lobbyhost`, then two `--autotest=lobbyjoin` processes.
2. Search the host's `stderr` for `must be normalized` (intermittent; 1 of 9 runs showed it, 51 times).

**Cause:** `_animate_arm` slerps `global_transform.basis * _rest_arm_basis`. The logged basis was a clean rotation to six digits, but its columns were about 0.999995 long, so the NPC node carries a hair of non-unit scale (a spawn point's rounded basis, set through `global_transform = spawns[slot]`). `Basis.slerp` rejects that once the error passes its 1e-5 tolerance, which happens only for some spawn points and yaws, hence the intermittence. That the scale comes from the spawn marker is inferred from the logged basis, not traced to a marker.

**Fix:** `_animate_arm` orthonormalizes both bases before the slerp. Only the orientation matters there. After the change 0 of 16 trio runs printed it.

### BUG-028 — Holstered gun has the wrong rotation (barrel not pointing down)

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-14 |
| Fixed | 2026-10-15 |
| Platforms | Arena, mode and VR / flat not recorded. |
| Areas | `player/player.gd` (holster placement after `# Holster rides the chosen hip`), `player/remote_avatar.gd` (holster placement, `_apply_gun_parent`), `weapons/weapon_base.gd` (`holster_to`) |

**What:** While the gun is in the holster, it does not hang with the tip of the barrel pointing down, as a holstered revolver should.

**Repro:**
1. Start any mode with the gun holstered.
2. Look at the gun on the hip.

**Fix:** `Player` and `RemoteAvatar` now pitch the holster basis -90° about X after the yaw, so the gun's -Z barrel points down.

### BUG-027 — Main Street: a killed NPC jumps into the air the moment it ragdolls

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-10-13 |
| Fixed | 2026-10-14 |
| Platforms | Main Street, every mode, VR and flat. NPCs, the player's own body, and remote avatars all stood on the same markers. Other arenas were already flush. |
| Areas | `scenarios/main_street/main_street.tscn` (spawn markers), `dev/autotest.gd` (`_spawn_floors_ok`, `_ragdoll_npc_floor_ok`) |

**What:** On the Main Street map, when an NPC is killed it launches upward at the instant it switches to ragdoll, instead of dropping.

**Repro:**
1. Start a duel against an NPC on Main Street.
2. Kill the NPC.
3. At the moment the body ragdolls it jumps into the air.

**Fix:** The reporter's lead was right. The `env_terrain` collider's top is at y=+0.12 (`dev/build_main_street_blender.py`, so building feet sink into the dirt), but all 7 Main Street spawn markers sat at y=0. The shin capsules that `BodyRagdoll._build` makes reach down to the sole, so they started 12 cm inside the ground, and the solver threw the body out (the hips rose 0.163 m in a gravity-only collapse).
- The markers (`PlayerSpawn`, `EnemySpawn`, `EnemySpawns2/*`, `EnemySpawns3/*`) are now at y=0.12. Lobby rings, horde spawns, and gusts read the markers, so they follow.
- `--autotest=multi` (`_spawn_floors_ok`) now fails if any marker on any arena has its floor above it, or more than 5 cm below it.
- `--autotest=ragdoll` (`_ragdoll_npc_floor_ok`) collapses an NPC on Main Street and fails if its hips rise more than 3 cm.

### BUG-026 — Flat draw: the hand animates slower than the gun

| | |
|---|---|
| Status | `fixed` |
| Severity | `minor` |
| Filed | 2026-10-12 |
| Fixed | 2026-10-14 |
| Platforms | Flat (local player), and how other players see a draw in multiplayer. VR keeps its catch ease. |
| Areas | `player/player.gd` (`_place_wrist`, `_snap_wrist`, `_attach_gun_to_hand`, `_holster_gun`), `player/remote_avatar.gd` (`_apply_gun_parent`, `_place_snap`) |

**What:** In flat mode the draw animation of the hand runs slower than the gun's, so the two are out of sync during the draw. They should move together.

**Repro:**
1. Start a duel in flat mode.
2. Draw and watch the hand and the gun.

**Fix:** The revolver teleports between the hip and `GunAttach` in one frame, but the mannequin wrist eased onto the grip over `DummyBody.WRIST_BLEND_SEC` (0.1 s) on scaled time. Under the on-draw slow-mo (×0.25) the hand trailed the gun by about 0.4 s.
- A flat draw, a flat pickup of a loose gun, and a flat holster now call `Player._snap_wrist`, so the wrist lands on the grip (or back at the hang) in the same frame as the gun. Tosses still ease, because the gun leaves from the hand.
- `RemoteAvatar` snaps both wrists on the frame its gun-drawn flag flips between the hip and the hand. A catch of a loose gun still eases.
- The finger curl keeps its 0.1 s blend.

Covered by `--autotest=gauntlet` (`_assert_flat_draw_snap`).

### BUG-025 — Shot in the non-gun arm still disarms the player

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-10-12 |
| Fixed | 2026-10-14 |
| Platforms | All: VR, flat, NPCs, multiplayer. |
| Areas | `combat/combat_rules.gd` (`resolve`, `is_gun_arm`), `player/hitbox.gd` (`side`), `player/player.gd` (`_apply_nonfatal`), `ai/duelist_ai.gd`, `gauntlet/duel_manager.gd` (`mp_report_hit`, `_mp_wound`) |

**What:** A hit on the arm that is not holding the gun still disarms the player, as if the gun arm had been hit.

**Repro:**
1. Start a duel and let the opponent shoot your arm on the side that is not holding the gun.
2. You are disarmed.

**Fix:** Both arm hitboxes had only `region = &"arm"`, so `CombatRules.resolve` and `Player._apply_nonfatal` disarmed on either arm.
- `Hitbox.side` (`&"L"` / `&"R"`, set on `ArmHitboxL` / `ArmHitboxR` in `player.tscn`, `duelist.tscn` and `remote_avatar.tscn`) now rides `take_bullet_hit(..., side)`. In MP it also rides `mp_report_hit` and `_mp_wound`, so the victim's own peer decides.
- `CombatRules.is_gun_arm` compares the side with the victim's gun side:
  - Player: `draw_hand_name()`, the holding hand, or the holster side when no gun is held.
  - NPC: the right arm. A left-arm hit no longer stops its draw either.
- A player's off-arm hit instead drops the off-hand coin / ace / longneck loose (`PropController.drop_from_hand`), then the VR belt round. The cigarette stays.

Covered by `--autotest=gauntlet` (`_assert_pain_jerk`).

### BUG-024 — VR player spawns off the Train Rooftop, past the invisible wall

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-10-12 |
| Fixed | 2026-10-14 |
| Platforms | VR. Train Rooftop. Flat appears correct. Headset / runtime and game mode not recorded. |
| Areas | `player/player.gd` `reset_for_duel`, `player/vr_rig.gd` `reset_locomotion`, `scenarios/scenario_base.gd` (`Guard*` walls, `get_player_spawn`), `scenarios/train_rooftop/train_rooftop.tscn` |

**What:** On Train Rooftop the VR player is placed off the roof at spawn, on the far side of the invisible `Guard*` wall that should keep them on it. The same arena in flat mode appears to spawn the player in the right place.

**Repro:**
1. Start a duel on Train Rooftop in VR.
2. At spawn the player is off the rooftop, outside the invisible wall.

**Fix:** `reset_for_duel` put the Player root on the marker, and `VRRig.reset_locomotion` zeroed the origin and yawed it around the HMD. Nothing removed the HMD's offset from the playspace centre. A player standing about 1.75 m off centre therefore started outside the roof's 3.5 m guard walls, and other arenas shifted the same way.
- `reset_locomotion` now also shifts the origin in XZ so the head stands on the spawn. Height is kept, and every arena gets this.
- If the headset is still on the identity pose (not tracking yet), the alignment waits in `_process` until `headset_height_ready()`, the same way the saved eye height waits.
- Second gap found while fixing this: VR stick walking had no collision and passed through every `Guard*` wall and building. `VRRig.collide_stick_motion` now shape-casts a capsule against world layer 1 and slides along whatever it hits, like flat's `move_and_slide`.
  - The capsule has flat's 0.28 m radius and sits at the head's XZ. It spans floor + 0.35 m to floor + 1.6 m, so ground lips don't snag it.
  - Walking in your room is not checked. If your head is already inside a wall, only the part of the step leading out is kept.

Covered by `--autotest=load` (`_vr_rig_ok`).

### BUG-021 — Multiplayer process crashes when a remote avatar is freed (seen as `join` / `lobbyjoin` exiting with an access violation after AUTOTEST PASS)

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-10-10 |
| Fixed | 2026-10-10 |
| Platforms | Windows, Godot 4.7. Seen in the headless harness; the same free happens in play on every rematch, leaver, and quit. |
| Areas | `autoload/voice_chat.gd`, Godot `AudioStreamGeneratorPlayback` |

**What:** A joiner prints `AUTOTEST PASS`, then the process exits with `0xC0000005` (-1073741819) during scene-tree teardown, with no backtrace. Measured with the mixed-lobbies waiting room in the tree: 7 of 52 `join` runs and 3 of 14 `lobbyjoin` processes. The same crash also happens on the commit before that work, less often (1 of 30 `join` runs). The host process never crashed.

**Repro:**
1. Start `--autotest=host`, then `--autotest=join` (intermittent; repeat it).
2. Check the joiner's exit code after `AUTOTEST PASS`.

**Cause:** Every crash dump (`%LOCALAPPDATA%\CrashDumps`, 10 of 10) faults at the same address in the Godot exe, on an unnamed engine thread. The disassembly is `AudioStreamGeneratorPlayback::get_stream_sampling_rate()`: the audio thread loads the playback's raw `generator` pointer and reads the stream's mix-rate fields from freed memory. `VoiceChat.bind_voice_player` made a new `AudioStreamGenerator` per avatar and only the avatar's player held it, so freeing the avatar freed the stream while the audio thread still had the playback listed for one more mix. The read only faults when the freed page is gone, which is why it is intermittent and mostly seen at exit. Not timing of the quit: a 1.5 s wait before quitting still crashed 3 of 24.

**Fix:** `VoiceChat` keeps one `AudioStreamGenerator` for the whole process, every bound voice player plays it, and it holds one reference that is never released, so the audio thread can never read a freed stream. Verified: 0 crashes in 28 `host` / `join` runs and 0 in 12 `lobbyhost` + 2 × `lobbyjoin` runs after. The cost is one small object reported as leaked at exit.

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
