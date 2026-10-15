extends Node
## Headless smoke tests, launched via `--autotest=<mode>` after `--`:
##   duel     - the `ScreenOverlay` state first (hurt per region and its fade, the kill-cam
##              iris on the kill-cam camera, abort, a freed camera, the Settings toggle),
##              then a free duel vs AI; passes when bullets actually resolve the duel
##   props    - equips the cigarette / coin / ace / bottle and throws them
##   gauntlet - clears two gauntlet rungs by force-killing the AI;
##              first rung also checks the pain-jerk toss
##   host     - hosts a LAN game, waits for a peer in the waiting room, presses
##              START (NetworkManager.host_start), wins the MP duel; slot tints
##   join     - joins 127.0.0.1, stands in the waiting room on slot 1, expects to
##              lose the MP duel; slot tints
##   lobbyhost - hosts 4 slots (the last an NPC), waits for two `lobbyjoin` peers, checks
##              an avatar per joiner on its ring point and no NPC before START, starts,
##              has the slowed NPC draw and fire, kills it mid-duel ("3 left"), then slot
##              1 (collapse, "2 left", bullets pass through, no finish), then slot 2 (win,
##              tally 1), then the shared 4-actor clip, slot 1's skip, and a clean
##              auto-rematch. Then a Teams round: back to the waiting room, each joiner's
##              side pick arriving from its own process, a 3v1 start with the NPC alone on
##              PlayerSpawn, and a 2v2 (host + slot 2 against slot 1 + the NPC) in which
##              the host shoots slot 1, its own teammate, and the NPC
##   lobbyjoin - run twice against one lobbyhost: its slot, two avatars, the NPC as a
##              proxy that moves, draws, fires a tracer, and falls from the host's
##              stream, its own death (spectating a living duelist, unable to act) or
##              the other's, the loss, the host's tally, the same sealed 4-actor clip,
##              and the clean rematch. Then the Teams round: side tints in the waiting
##              room following every pick, its own side button, every actor on the
##              ring point and in the colour the snapshot gives, the 2v2 from its own
##              side (slot 1 loses, slot 2 wins dead), and the tally
##   lobby    - the host alone, with rosters whose other humans never connect: the clip
##              wire format for 2 / 3 / 4 actors, ring spawns on every arena, waiting-room
##              avatars, pose / shot routing by sender, foul void then out (3 slots, a
##              sealed 3-actor clip), 2-slot fouls, a leaver mid-duel and the rematch
##              with its slot as an NPC, the win check by sides, spectating (hold,
##              killer, cycle, auto-advance, hand-off to the final replay, a foul, a
##              leaver, stop), a leaver's blank actor in the replay, NPC slots (the host
##              and three NPCs to a last-standing finish and a sealed 4-actor clip, the
##              host spectating its own NPCs, a client's proxy staged on the host),
##              `DeathCam.blocks_npcs`, and Teams: side picks and the empty-side START
##              guard, slot / side tints on every body, ring points by `spawn_order()` on
##              every arena (1v3, 2v2, 1v2, a 2-slot lobby; an NPC, an avatar, and a
##              proxy on PlayerSpawn), an NPC that never targets or turns on a teammate,
##              friendly fire and team kills, a dead winner, fouls and leavers by side,
##              and the per-slot tally
##   steam    - SteamTransport parses; is_available() is false without GodotSteam
##   steamcycle - create/leave/create + join recovery against a live Steam
##              client (BUG-009); passes as a no-op when Steam is absent
##   load     - loads every scene/resource, then bind, prop, version, LAN beacon,
##              lobby roster, main-menu SP/MP split, and host/leave/re-host
##              (BUG-009, host roster API) checks
##   ragdoll  - a dummy on a floor collapses from a shot: falls, moves along it,
##              settles with its bodies freed, track ends match, release stands it up
##   chunks   - hit chunks in a free duel: snap triangles per bone, cuts land on the
##              skin, a bullet cuts the struck bone (holes, uniforms, gib), the 8-hole
##              cap, chance 0 / gore off / shelved, gib settle + cap, replay heal / open
##              / hold, wave reset, a head kill replayed, and a new duel freeing the gibs
##   multi    - duel vs 2-3 NPCs: marker clearance, free-for-all fight, last one
##              standing, replay retrace, survivors fighting after a loss, ladder rung 7
##   horde    - endless waves: focus targeting, scoring (kill, headshot, wave clear;
##              crossfire scores 0), spawn safety + no teleport between waves, the
##              wave table's loop promotion, and a death ending the run to the menu
##   practice - practice hub: shot / thrown bottles shatter, count, respawn on
##              the rail, reset, slot machine spin, tutorial board remaps,
##              porch deck holds a dropped revolver, no wounds, flat backdrop
##   i18n     - every tr("KEY") / key constant / scene text key in code exists in
##              translations.csv, and the imported English translation resolves
## Prints AUTOTEST PASS / AUTOTEST FAIL and sets the exit code.

var mode := "duel"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			mode = arg.get_slice("=", 1)
	print("AUTOTEST: mode=%s" % mode)
	# The processes drive the roster with no player at the menu: the host's Lobby page stays
	# shut unless a test is about it (`_lobby_page_ok`).
	GameManager.hud.pause_menu.auto_open_lobby = false
	_saved_lobby_setup = _lobby_setup_snapshot()
	match mode:
		"duel":
			_test_duel()
		"gauntlet":
			_test_gauntlet()
		"host":
			_test_host()
		"join":
			_test_join()
		"lobbyhost":
			_test_lobby_host()
		"lobbyjoin":
			_test_lobby_join()
		"lobby":
			_test_lobby()
		"load":
			_test_load_all()
		"props":
			_test_props()
		"multi":
			_test_multi()
		"horde":
			_test_horde()
		"practice":
			_test_practice()
		"ragdoll":
			_test_ragdoll()
		"chunks":
			_test_chunks()
		"i18n":
			_test_i18n()
		"steam":
			_test_steam()
		"steamcycle":
			_test_steam_cycle()
		_:
			_fail("unknown mode %s" % mode)


# -- Scenarios -------------------------------------------------------------------

func _test_duel() -> void:
	await _sleep(1.0)
	if not await _screen_overlay_ok():
		return
	GameManager.start_free_duel(0, 0)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		return _fail("duel never reached DRAW")
	print("AUTOTEST: DRAW reached, waiting for bullets to decide it...")
	var result := await _wait_duel_finished(60.0)
	if result.is_empty():
		return _fail("duel did not resolve (no bullet hit landed)")
	print("AUTOTEST: duel finished, local won=%s (%s)" % [result[0], result[1]])
	_pass()


## `ScreenOverlay` is checked as state; headless draws no shader. The NPC is slowed so its
## bullets do not land mid-test.
func _screen_overlay_ok() -> bool:
	var saved_speed: float = GameManager.tuning["ai_speed_mult"]
	GameManager.tuning["ai_speed_mult"] = MULTI_AI_SPEED
	var ok := await _screen_overlay_steps()
	GameManager.tuning["ai_speed_mult"] = saved_speed
	PlayerSettings.screen_effects_enabled = true
	ScreenOverlay.reset()
	return ok


func _screen_overlay_steps() -> bool:
	GameManager.start_free_duel(0, 0)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail("overlay: the duel never reached DRAW")
		return false
	var player := GameManager.local_player
	var trail := PackedVector3Array([Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.5, -2.0)])
	var quad_idle := func() -> bool:
		return not ScreenOverlay._quad.visible and ScreenOverlay._quad.get_parent() == ScreenOverlay
	var calm := func() -> bool: return not ScreenOverlay.is_active()
	if GameManager.hud.get_node_or_null("RedFlash") != null or GameManager.hud.has_method("flash_red"):
		_fail("overlay: the HUD still has the red flash")
		return false

	# A wound scales with the region, then fades and the quad parks hidden under the autoload.
	ScreenOverlay.reset()
	for wound in [[CombatRules.REGION_TORSO, "hurt_torso"], [CombatRules.REGION_ARM, "hurt_limb"]]:
		player.take_bullet_hit(0.0, PackedVector3Array(), wound[0])
		var want := float(GameManager.tuning[wound[1]])
		if not is_equal_approx(ScreenOverlay.hurt_level(), want) or not ScreenOverlay.is_active():
			_fail("overlay: a %s hit set hurt to %.2f, expected %.2f" % [wound[0], ScreenOverlay.hurt_level(), want])
			return false
		if not await _wait_for(calm, 3.0) or not quad_idle.call():
			_fail("overlay: the %s vignette did not fade and park" % wound[0])
			return false

	# Toggle off: a wound and the kill cam leave the overlay idle.
	PlayerSettings.screen_effects_enabled = false
	player.take_bullet_hit(0.0, PackedVector3Array(), CombatRules.REGION_TORSO)
	GameManager.duel.kill_cam_requested.emit(trail)
	await get_tree().process_frame
	if not KillCam.is_playing or ScreenOverlay.is_active() or ScreenOverlay.hurt_level() != 0.0:
		_fail("overlay: effects off, but the overlay woke (kill cam playing %s)" % KillCam.is_playing)
		return false
	KillCam.cancel()
	PlayerSettings.screen_effects_enabled = true

	# Kill cam: shut on its own camera, opens, closes at the end, then opens on the next view.
	GameManager.duel.kill_cam_requested.emit(trail)
	var cam: Camera3D = KillCam._camera
	if not KillCam.is_playing or not is_instance_valid(cam) or not ScreenOverlay.is_active() 			or ScreenOverlay.iris_level() != 0.0 or not ScreenOverlay._quad.visible 			or ScreenOverlay._quad.get_parent() != cam:
		_fail("overlay: the kill cam did not start shut on its camera")
		return false
	if not await _wait_for(func() -> bool: return ScreenOverlay.iris_level() >= ScreenOverlay.IRIS_OPEN, 3.0):
		_fail("overlay: the iris never opened on the kill cam")
		return false
	if not await _wait_for(func() -> bool: return not KillCam.is_playing, 10.0) 			or not await _wait_for(calm, 3.0) or not quad_idle.call() 			or ScreenOverlay.iris_level() != ScreenOverlay.IRIS_OPEN:
		_fail("overlay: after the kill cam the iris is not open with the quad parked")
		return false

	# Abort: cancel mid-wipe leaves it open, clear and parked at once.
	GameManager.duel.kill_cam_requested.emit(trail)
	await get_tree().process_frame
	if not ScreenOverlay.is_active():
		_fail("overlay: the second kill cam did not wake the overlay")
		return false
	KillCam.cancel()
	if ScreenOverlay.is_active() or ScreenOverlay.iris_level() != ScreenOverlay.IRIS_OPEN 			or ScreenOverlay.hurt_level() != 0.0 or not quad_idle.call():
		_fail("overlay: cancelling the kill cam left the overlay up")
		return false

	# A camera freed under the quad does not take it, or the running effect, with it.
	var temp := Camera3D.new()
	add_child(temp)
	temp.current = true
	ScreenOverlay.hurt(0.5, 5.0)
	await get_tree().process_frame
	if ScreenOverlay._quad.get_parent() != temp:
		_fail("overlay: the quad did not ride the current camera")
		return false
	temp.free()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(ScreenOverlay._quad) or not ScreenOverlay._quad.is_inside_tree() 			or ScreenOverlay.hurt_level() <= 0.0:
		_fail("overlay: freeing the camera under the quad broke the overlay")
		return false
	ScreenOverlay.reset()

	# A kill: the strongest vignette, carried onto the kill-cam camera, then idle.
	player.take_bullet_hit(99.0, trail, CombatRules.REGION_HEAD)
	if not is_equal_approx(ScreenOverlay.hurt_level(), float(GameManager.tuning["hurt_kill"])) 			or not KillCam.is_playing or ScreenOverlay._quad.get_parent() != KillCam._camera:
		_fail("overlay: a kill did not show the vignette on the kill-cam camera")
		return false
	if not await _wait_for(func() -> bool: return not KillCam.is_playing, 10.0) 			or not await _wait_for(calm, 3.0) or not quad_idle.call():
		_fail("overlay: the overlay did not go idle after the kill cam")
		return false
	print("AUTOTEST: screen overlay hurt per region, iris on the kill cam, abort, freed camera, and toggle ok")
	return true


func _test_gauntlet() -> void:
	await _sleep(1.0)
	GameManager.start_gauntlet()
	for rung in 2:
		if not await _wait_for_state(DuelManager.State.DRAW, 25.0):
			return _fail("gauntlet rung %d never reached DRAW" % (rung + 1))
		if rung == 0:
			var ai := GameManager.current_ais[0]
			if not await _assert_hitboxes_follow(ai, ai._dummy, "NPC"):
				return
			var local := GameManager.local_player
			local._draw_gun()
			var player_ok: bool = await _assert_hitboxes_follow(local, local._dummy, "player (gun drawn)")
			local._holster_gun()
			if not player_ok:
				return
			if not (_assert_flat_draw_snap() and _assert_pain_jerk() and _assert_spin_throw()):
				return
		# Arm the listener before the kill: duel_finished fires synchronously.
		var result := _arm_duel_listener()
		var doomed := GameManager.current_ais[0]
		doomed.take_bullet_hit(99.0, PackedVector3Array())
		await _await_result(result, 10.0)
		if result.is_empty() or result[0] != true:
			return _fail("gauntlet rung %d did not resolve as a win" % (rung + 1))
		if rung == 0 and not await _assert_npc_falls(doomed):
			return
		print("AUTOTEST: gauntlet rung %d cleared, score=%d" % [rung + 1, GameManager.gauntlet.score])
	if GameManager.gauntlet.encounter_index < 1:
		return _fail("gauntlet did not advance")
	if not _gauntlet_record_ok():
		return
	_pass()


## Best rung / score / cleared each keep their maximum. Restores the real record.
func _gauntlet_record_ok() -> bool:
	var saved := [PlayerSettings.gauntlet_best_rung, PlayerSettings.gauntlet_best_score,
		PlayerSettings.gauntlet_cleared]
	PlayerSettings.gauntlet_best_rung = 0
	PlayerSettings.gauntlet_best_score = 0
	PlayerSettings.gauntlet_cleared = false
	var ok: bool = PlayerSettings.record_gauntlet_run(3, 500, false) 		and not PlayerSettings.record_gauntlet_run(2, 400, false) 		and PlayerSettings.record_gauntlet_run(2, 400, true) 		and PlayerSettings.gauntlet_best_rung == 3 and PlayerSettings.gauntlet_best_score == 500
	PlayerSettings.gauntlet_best_rung = saved[0]
	PlayerSettings.gauntlet_best_score = saved[1]
	PlayerSettings.gauntlet_cleared = saved[2]
	PlayerSettings._save_config()
	if not ok:
		_fail("gauntlet best record did not keep its maxima")
		return false
	print("AUTOTEST: gauntlet best record ok")
	return true


# -- Multi-NPC duels ---------------------------------------------------------------

## Slows every NPC so the fight stays under the test's control.
const MULTI_AI_SPEED := 0.05
const MULTI_CAPSULE_RADIUS := 0.3
const MULTI_CAPSULE_HEIGHT := 1.6
const MULTI_MIN_SPACING := 3.0
const MULTI_FLOOR_TOLERANCE := 0.3
const MULTI_WORLD_MASK := 1
## BUG-027: a spawn marker's floor may not rise above the sole (a sunk ragdoll is thrown
## out of the ground); a short hover is a harmless drop.
const SPAWN_FLOOR_ABOVE := 0.01
const SPAWN_FLOOR_BELOW := 0.05


func _test_multi() -> void:
	await _sleep(1.0)
	var saved_speed: float = GameManager.tuning["ai_speed_mult"]
	GameManager.tuning["ai_speed_mult"] = MULTI_AI_SPEED
	var ok: bool = await _multi_markers_ok() and await _multi_fight_ok() and await _multi_loss_ok() 			and _multi_ladder_menu_ok() and await _multi_rooftop_ok()
	GameManager.tuning["ai_speed_mult"] = saved_speed
	if ok:
		_pass()


func _test_horde() -> void:
	await _sleep(1.0)
	var saved_speed: float = GameManager.tuning["ai_speed_mult"]
	GameManager.tuning["ai_speed_mult"] = MULTI_AI_SPEED
	var ok := await _horde_run_ok()
	GameManager.tuning["ai_speed_mult"] = saved_speed
	if ok:
		_pass()


## Wave 1 (one Drunk focused on the player) through wave 2 (two Drunks, spawn-safe and
## no teleport), crossfire scoring nothing, the wave table's loop promotion, and a
## death that ends the run back to the menu with a recorded best.
func _horde_run_ok() -> bool:
	GameManager.start_horde(0)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail("horde: wave 1 never reached DRAW")
		return false
	if GameManager.current_ais.size() != 1:
		_fail("horde: wave 1 spawned %d NPCs, expected 1" % GameManager.current_ais.size())
		return false
	var ai1 := GameManager.current_ais[0]
	if not ai1.focus_player or ai1._target != GameManager.local_player:
		_fail("horde: wave 1 NPC is not focused on the player")
		return false

	var result := _arm_duel_listener()
	ai1.take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_HEAD, false, false, ReplayBuffer.ACTOR_HOST)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true:
		_fail("horde: wave 1 headshot did not win the round")
		return false
	if GameManager.horde.score != 100 + 50 + 100:
		_fail("horde: wave 1 score is %d, expected 250" % GameManager.horde.score)
		return false

	# Unit checks on the wave table: loop promotion and speed, independent of the live run.
	var waves: HordeWaves = GameManager.horde.waves
	var w9 := waves.lineup_for(9)
	if w9.size() != 1 or w9[0] != load("res://ai/archetypes/sheriff.tres"):
		_fail("horde: lineup_for(9) did not promote Drunk to Sheriff")
		return false
	if not is_equal_approx(waves.speed_for(9), 1.1):
		_fail("horde: speed_for(9) is %.2f, expected 1.1" % waves.speed_for(9))
		return false
	var w14 := waves.lineup_for(14)
	if w14.size() != 1 or w14[0] != load("res://ai/archetypes/ghost.tres"):
		_fail("horde: lineup_for(14) did not stay Ghost at the top tier")
		return false

	# Move into an EnemySpawns2 marker's radius before wave 2 spawns: the spawner must
	# skip it, and the player must not be moved to reset for the new wave.
	var marker := GameManager.current_scenario.get_node("EnemySpawns2").get_child(0) as Node3D
	var moved_pos: Vector3 = marker.global_position + Vector3(0.3, 0.0, 0.0)
	GameManager.local_player.global_position = moved_pos

	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail("horde: wave 2 never reached DRAW")
		return false
	if GameManager.current_ais.size() != 2:
		_fail("horde: wave 2 spawned %d NPCs, expected 2" % GameManager.current_ais.size())
		return false
	if GameManager.local_player.global_position.distance_to(moved_pos) > 0.01:
		_fail("horde: the player was moved between waves")
		return false
	if GameManager.local_player.health != GameManager.local_player.max_health:
		_fail("horde: HP was not restored between waves")
		return false
	if GameManager.local_player.revolver.rounds != GameManager.local_player.revolver.max_rounds:
		_fail("horde: the cylinder was not refilled between waves")
		return false
	for ai in GameManager.current_ais:
		var flat := Vector2(ai.global_position.x - moved_pos.x, ai.global_position.z - moved_pos.z).length()
		if flat < waves.spawn_min_distance:
			_fail("horde: NPC spawned %.1f m from the player, under spawn_min_distance" % flat)
			return false

	# Crossfire: one NPC kills the other. It still counts toward the clear but scores 0.
	var ais := GameManager.current_ais
	var score_before := GameManager.horde.score
	ais[0].take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_TORSO, false, false, ais[1].actor_id)
	if GameManager.horde.score != score_before:
		_fail("horde: a crossfire kill scored points")
		return false
	if GameManager.duel.state != DuelManager.State.DRAW:
		_fail("horde: a crossfire kill with an NPC still alive ended the wave")
		return false

	result = _arm_duel_listener()
	ais[1].take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_TORSO, false, false, ReplayBuffer.ACTOR_HOST)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true:
		_fail("horde: wave 2 did not clear once the last NPC died")
		return false

	# Death ends the run: same loss path as a free duel, then the menu with a best kept.
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail("horde: wave 3 never reached DRAW")
		return false
	GameManager.local_player.take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_HEAD,
			false, false, GameManager.current_ais[0].actor_id)
	if not await _wait_for(func() -> bool: return GameManager.mode == GameManager.GameMode.MENU, 90.0):
		_fail("horde: death did not return to the menu")
		return false
	if PlayerSettings.horde_best_wave < 2:
		_fail("horde: best wave is %d, expected at least 2" % PlayerSettings.horde_best_wave)
		return false
	print("AUTOTEST: horde waves, score, spawn safety, crossfire, and death-ends-run ok")
	return true


## Train Rooftop: a Sheriff must not jump when it re-draws after a disarm, and a corpse
## limb must not collide with the invisible guard walls.
func _multi_rooftop_ok() -> bool:
	var saved_disarm: float = GameManager.tuning["arm_disarm_duration"]
	GameManager.tuning["arm_disarm_duration"] = 0.5
	GameManager.start_free_duel(2, 1, 1)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail_rooftop("rooftop duel never reached DRAW", saved_disarm)
		return false
	var ai: DuelistAI = GameManager.current_ais[0]
	await _wait_for(func() -> bool: return ai.state != DuelistAI.AIState.IDLE, 20.0)
	await _sleep(1.0)
	ai.take_bullet_hit(0.0, PackedVector3Array(), CombatRules.REGION_ARM)
	var prev := ai.global_position
	var worst := 0.0
	var redrew := false
	for _frame in 400:
		await get_tree().process_frame
		worst = maxf(worst, ai.global_position.distance_to(prev))
		prev = ai.global_position
		if ai.state == DuelistAI.AIState.REACTING:
			redrew = true
		if redrew and ai.state != DuelistAI.AIState.REACTING:
			break
	if worst > 0.3:
		_fail_rooftop("Sheriff teleported %.2f m in one frame after a disarm" % worst, saved_disarm)
		return false
	GameManager.tuning["arm_disarm_duration"] = saved_disarm
	if get_tree().get_nodes_in_group(BodyRagdoll.IGNORE_GROUP).size() < 4:
		_fail("rooftop guard walls are not in the ragdoll ignore group")
		return false
	ai.take_bullet_hit(99.0, PackedVector3Array([Vector3(0, 4, 0), Vector3(0, 4, -1)]), CombatRules.REGION_HEAD)
	await get_tree().physics_frame
	var bodies: Array = ai._dummy._ragdoll._bodies
	if bodies.is_empty():
		_fail("rooftop corpse built no ragdoll bodies")
		return false
	for rigid in bodies:
		var skipped: Array = (rigid as RigidBody3D).get_collision_exceptions()
		if skipped.size() < 4:
			_fail("ragdoll body %s still collides with the guard walls" % rigid.name)
			return false
	print("AUTOTEST: rooftop strafe stays continuous and ragdolls ignore the guard walls")
	return true


func _fail_rooftop(message: String, saved_disarm: float) -> void:
	GameManager.tuning["arm_disarm_duration"] = saved_disarm
	_fail(message)


## Part A: every arena and count places its NPCs clear of geometry, on the floor, facing
## the lane, spaced out, with a readable lineup and distinct shades for duplicates.
func _multi_markers_ok() -> bool:
	if not await _spawn_floors_ok():
		return false
	for arena in GameManager.SCENARIOS.size():
		for count in [2, 3]:
			GameManager.start_free_duel(arena, 0, count)
			await get_tree().physics_frame
			await get_tree().physics_frame
			if not _multi_arena_ok(arena, count):
				return false
	GameManager.start_free_duel(0, 0, 3)
	await get_tree().physics_frame
	var shades: Array[Color] = []
	for ai in GameManager.current_ais:
		shades.append(ai._dummy._albedo)
	if shades[0].is_equal_approx(shades[1]) or shades[0].is_equal_approx(shades[2]) 			or shades[1].is_equal_approx(shades[2]):
		_fail("3x Drunk share a tint: %s" % [shades])
		return false
	var base := GameManager.archetype_at(0).body_color
	if not shades[0].is_equal_approx(base) or not shades[1].is_equal_approx(base.lightened(GameManager.NPC_TINT_SHIFT)) \
			or not shades[2].is_equal_approx(base.darkened(GameManager.NPC_TINT_SHIFT)) \
			or not GameManager.local_player.corpse_body()._albedo.is_equal_approx(Player.BODY_TINT):
		_fail("single-player tints should be the archetype colour, lighter, darker, and the player's own: %s" % [shades])
		return false
	var expected := "The Drunk, The Drunk & The Drunk"
	var shown := GameManager.hud.message_label.text
	if GameManager.lineup_text(GameManager.current_lineup) != expected or not shown.begins_with(expected):
		_fail("lineup message is '%s'" % shown)
		return false
	print("AUTOTEST: multi markers, floors, facing, spacing, tints, and lineup text ok")
	return true


## Part B: Main Street, 3x Drunk. Every NPC picks a rival at the bell, a mid-fight death
## counts down without ending the duel, bullets pass through the corpse, and the last one
## standing wins with the real shooter credited.
func _multi_fight_ok() -> bool:
	GameManager.start_free_duel(0, 0, 3)
	if not await _wait_for_state(DuelManager.State.DRAW, 25.0):
		_fail("multi fight: never reached DRAW")
		return false
	var ais := GameManager.current_ais
	for ai in ais:
		if not is_instance_valid(ai._target) or ai._target == ai or not ai._is_live(ai._target):
			_fail("multi fight: NPC %d has no live rival at the bell" % ai.actor_id)
			return false
	var npc1 := ais[0]
	var npc2 := ais[1]
	var npc3 := ais[2]
	npc1.take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_TORSO, false, false, 0)
	if GameManager.duel.state != DuelManager.State.DRAW or GameManager.hud.message_label.text != "2 left":
		_fail("multi fight: first death gave state %d, message '%s'" % [
				GameManager.duel.state, GameManager.hud.message_label.text])
		return false
	if ReplayBuffer.death_time_of(1) < 0.0:
		_fail("multi fight: the first death has no clip time")
		return false
	for hitbox in npc1._hitboxes():
		if not hitbox.is_corpse():
			_fail("multi fight: a dead NPC's %s volume is not a corpse" % hitbox.region)
			return false
	if not await _multi_bullet_passes_corpse(npc1, npc2):
		return false
	var result := _arm_duel_listener()
	npc3.take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_TORSO, false, false, 2)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true:
		_fail("multi fight: the last NPC's death was not a win")
		return false
	if ReplayBuffer.killer_id != 2 or ReplayBuffer.victim_id != 3:
		_fail("multi fight: credit is killer %d victim %d" % [ReplayBuffer.killer_id, ReplayBuffer.victim_id])
		return false
	if ReplayBuffer.death_time_of(1) < ReplayBuffer.clip_begin():
		_fail("multi fight: the first death fell outside the clip")
		return false
	var retrace := {"done": false, "error": ""}
	_multi_watch_retrace(npc1, retrace)
	if not await _assert_npc_falls(npc3):
		return false
	if not await _wait_for(func() -> bool: return retrace["done"], 10.0) or not String(retrace["error"]).is_empty():
		_fail("multi fight: %s" % retrace["error"])
		return false
	print("AUTOTEST: multi fight: rivals, N left, corpse pass-through, last-standing credit, and the earlier corpse retracing ok")
	return true


## An NPC that died inside the clip stands for the replay, plays its fall at its own
## death time, and is held again on the trailing orbit. Fills `report` when it is done.
func _multi_watch_retrace(ai: DuelistAI, report: Dictionary) -> void:
	var dummy := ai.corpse_body()
	await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 60.0)
	var lead := ReplayBuffer.death_time_of(ai.actor_id) - DeathCam._play_t
	if lead > 0.2 and dummy.corpse_state() != BodyRagdoll.State.RETRACE:
		report["error"] = "NPC %d is not retracing in the replay (state %d)" % [ai.actor_id, dummy.corpse_state()]
	elif not await _wait_for(func() -> bool: return DeathCam._play_t >= ReplayBuffer.death_time_of(ai.actor_id) + 0.3, 40.0):
		report["error"] = "playback never reached NPC %d's death" % ai.actor_id
	elif dummy.corpse_state() != BodyRagdoll.State.TRACK:
		report["error"] = "NPC %d's fall is not playing after its death (state %d)" % [ai.actor_id, dummy.corpse_state()]
	elif not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.TRAILING, 40.0):
		report["error"] = "playback never ended"
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		if dummy.corpse_state() != BodyRagdoll.State.HELD:
			report["error"] = "NPC %d is not held on the trailing orbit (state %d)" % [ai.actor_id, dummy.corpse_state()]
	report["done"] = true


## Part C: Mixed x3. Restart replays the lineup. A death with NPCs left is a loss that
## credits the shooter, the survivors stay frozen until the trailing orbit, then shoot
## each other without a second ending.
func _multi_loss_ok() -> bool:
	GameManager.start_free_duel(0, GameManager.ARCHETYPES.size(), 3)
	var lineup := GameManager.current_lineup.duplicate()
	GameManager.reset_current_duel()
	if GameManager.current_lineup != lineup or GameManager.current_ais.size() != 3:
		_fail("multi loss: restart changed the lineup")
		return false
	for i in 3:
		if GameManager.current_ais[i].archetype != lineup[i]:
			_fail("multi loss: restart spawned another archetype in slot %d" % i)
			return false
	if not await _wait_for_state(DuelManager.State.DRAW, 25.0):
		_fail("multi loss: never reached DRAW")
		return false
	var ais := GameManager.current_ais
	var finishes := [0]
	GameManager.duel.duel_finished.connect(func(_won: bool, _reason: String) -> void: finishes[0] += 1)
	GameManager.local_player.take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_TORSO, false, false, 1)
	if finishes[0] != 1 or GameManager.duel.state != DuelManager.State.RESOLUTION:
		_fail("multi loss: the player's death did not end the duel once")
		return false
	if ReplayBuffer.killer_id != 1 or ReplayBuffer.victim_id != ReplayBuffer.ACTOR_HOST:
		_fail("multi loss: credit is killer %d victim %d" % [ReplayBuffer.killer_id, ReplayBuffer.victim_id])
		return false
	if GameManager.duel.survivors_fighting():
		_fail("multi loss: the survivors fight before the trailing orbit")
		return false
	DeathCam.skip_to_trailing()
	if DeathCam.phase != DeathCam.Phase.TRAILING or not GameManager.duel.survivors_fighting():
		_fail("multi loss: the survivors do not fight on the trailing orbit")
		return false
	if not await _wait_for(func() -> bool: return ais[1]._target is DuelistAI and ais[1]._is_live(ais[1]._target), 5.0):
		_fail("multi loss: a survivor did not pick another NPC")
		return false
	ais[1].head_hitbox.receive_hit(PackedVector3Array(), false, false, ReplayBuffer.ACTOR_HOST)
	if not ais[1].is_alive():
		_fail("multi loss: a shot credited to the dead player landed")
		return false
	ais[0].head_hitbox.receive_hit(PackedVector3Array(), false, false, 2)
	if ais[0].is_alive():
		_fail("multi loss: an NPC-to-NPC shot did not land")
		return false
	await get_tree().process_frame
	if KillCam.is_playing or finishes[0] != 1 or GameManager.duel.state != DuelManager.State.RESOLUTION:
		_fail("multi loss: a survivor's death replayed the ending")
		return false
	print("AUTOTEST: multi loss: lineup restart, shooter credit, frozen then fighting survivors ok")
	return true


## Part D: rung 7 is the three-way on Main Street, NPC revolvers carry no haptic hand
## (BUG-017), and the menu offers Mixed, the opponent count, and the remembered pick.
func _multi_ladder_menu_ok() -> bool:
	var ladder: GauntletLadder = load(GameManager.GAUNTLET_LADDER)
	var finale := ladder.encounters[ladder.encounters.size() - 1]
	if ladder.encounters.size() != 7 or finale.lineup().size() != 3 or finale.scenario_index != 0:
		_fail("rung 7 is not a three-way on Main Street")
		return false
	for encounter in ladder.encounters.slice(0, 6):
		if encounter.lineup().size() != 1:
			_fail("rung '%s' lost its single opponent" % encounter.label)
			return false
	GameManager.begin_gauntlet_encounter(finale)
	if GameManager.current_ais.size() != 3 or GameManager.current_scenario_index != 0:
		_fail("rung 7 did not spawn three NPCs on Main Street")
		return false
	for ai in GameManager.current_ais:
		if ai.revolver.shooting_hand != &"":
			_fail("NPC %d's revolver would buzz a controller" % ai.actor_id)
			return false
	var saved := [PlayerSettings.free_duel_scenario, PlayerSettings.free_duel_enemy, PlayerSettings.free_duel_count]
	PlayerSettings.free_duel_scenario = 2
	PlayerSettings.free_duel_enemy = GameManager.ARCHETYPES.size()
	PlayerSettings.free_duel_count = 3
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	var ok: bool = menu.enemy_option.item_count == GameManager.ARCHETYPES.size() + 1 			and menu.count_option.item_count == GameManager.MAX_NPCS 			and menu.scenario_option.selected == 2 			and menu.enemy_option.selected == GameManager.ARCHETYPES.size() 			and menu.count_option.selected == 2
	menu.queue_free()
	PlayerSettings.free_duel_scenario = saved[0]
	PlayerSettings.free_duel_enemy = saved[1]
	PlayerSettings.free_duel_count = saved[2]
	if not ok:
		_fail("main menu did not offer Mixed, the count, or the remembered pick")
		return false
	print("AUTOTEST: multi ladder rung 7, NPC haptics off, and the menu's Mixed / count / remembered pick ok")
	return true


## A real shot from the player through the first corpse's chest drops the second NPC.
func _multi_bullet_passes_corpse(corpse_ai: DuelistAI, target: DuelistAI) -> bool:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var chest := _hitbox_center(corpse_ai.torso_hitbox)
	var aim := _hitbox_center(target.head_hitbox)
	var dir := (aim - chest).normalized()
	var origin := chest - dir * 1.5
	var query := PhysicsRayQueryParameters3D.create(origin, aim, Bullet.HIT_MASK)
	query.collide_with_areas = true
	var first: Dictionary = corpse_ai.get_world_3d().direct_space_state.intersect_ray(query)
	if first.is_empty() or not (first["collider"] is Hitbox and (first["collider"] as Hitbox).owner_entity == corpse_ai):
		_fail("multi fight: the shot line does not cross the corpse (%s)" % [first.get("collider")])
		return false
	Bullet.spawn(get_tree().current_scene, origin, dir, GameManager.tuning["bullet_speed"],
			true, [], false, 0.0, [], ReplayBuffer.ACTOR_HOST)
	if not await _wait_for(func() -> bool: return not target.is_alive(), 8.0):
		_fail("multi fight: the bullet did not pass through the corpse")
		return false
	return true


## World center of a hitbox's first shape (the Area3D node itself stays at the body root).
func _hitbox_center(hitbox: Hitbox) -> Vector3:
	for child in hitbox.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return hitbox.global_position


## Every spawn marker on every arena (PlayerSpawn, EnemySpawn, EnemySpawns*) stands flush
## on the world floor.
func _spawn_floors_ok() -> bool:
	for arena in GameManager.SCENARIOS.size():
		GameManager.start_free_duel(arena, 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var scenario := GameManager.current_scenario
		var markers: Array[Marker3D] = [scenario.get_node("PlayerSpawn"), scenario.get_node("EnemySpawn")]
		for group in scenario.get_children():
			if String(group.name).begins_with("EnemySpawns"):
				for marker in group.get_children():
					markers.append(marker as Marker3D)
		var space := scenario.get_world_3d().direct_space_state
		for marker in markers:
			var pos := marker.global_position
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5,
					pos + Vector3.DOWN * 1.0, MULTI_WORLD_MASK))
			if hit.is_empty():
				_fail("spawn floor: arena %d %s has no floor under it" % [arena, scenario.get_path_to(marker)])
				return false
			var floor_y: float = hit["position"].y
			if floor_y > pos.y + SPAWN_FLOOR_ABOVE or floor_y < pos.y - SPAWN_FLOOR_BELOW:
				_fail("spawn floor: arena %d %s at y %.3f, floor at y %.3f" % [arena,
						scenario.get_path_to(marker), pos.y, floor_y])
				return false
	print("AUTOTEST: spawn markers flush on the floor on every arena")
	return true


func _multi_arena_ok(arena: int, count: int) -> bool:
	var tag := "arena %d x%d" % [arena, count]
	var ais := GameManager.current_ais
	if ais.size() != count:
		_fail("%s: %d NPCs" % [tag, ais.size()])
		return false
	var scenario := GameManager.current_scenario
	var player_pos := scenario.get_player_spawn().origin
	var center := (player_pos + scenario.get_enemy_spawn().origin) * 0.5
	var space := scenario.get_world_3d().direct_space_state
	for i in count:
		var ai := ais[i]
		var pos := ai.global_position
		if ai.actor_id != i + 1:
			_fail("%s: NPC %d has actor id %d" % [tag, i, ai.actor_id])
			return false
		var down := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 1.5, MULTI_WORLD_MASK)
		var floor_hit := space.intersect_ray(down)
		if floor_hit.is_empty() or absf(float(floor_hit["position"].y) - pos.y) > MULTI_FLOOR_TOLERANCE:
			_fail("%s: marker %d is not on the floor (%s)" % [tag, i, floor_hit.get("position")])
			return false
		var capsule := CapsuleShape3D.new()
		capsule.radius = MULTI_CAPSULE_RADIUS
		capsule.height = MULTI_CAPSULE_HEIGHT
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = MULTI_WORLD_MASK
		query.transform = Transform3D(Basis.IDENTITY,
				Vector3(pos.x, float(floor_hit["position"].y) + 0.1 + MULTI_CAPSULE_HEIGHT * 0.5, pos.z))
		if not space.intersect_shape(query, 1).is_empty():
			_fail("%s: marker %d (%s) is inside geometry" % [tag, i, pos])
			return false
		var flat := Vector3(center.x - pos.x, 0.0, center.z - pos.z).normalized()
		var forward := -ai.global_transform.basis.z
		forward.y = 0.0
		if forward.normalized().dot(flat) < 0.98:
			_fail("%s: NPC %d does not face the lane center" % [tag, i])
			return false
		if pos.distance_to(player_pos) < MULTI_MIN_SPACING:
			_fail("%s: NPC %d is %.1f m from the player" % [tag, i, pos.distance_to(player_pos)])
			return false
		for j in i:
			if pos.distance_to(ais[j].global_position) < MULTI_MIN_SPACING:
				_fail("%s: NPCs %d and %d are closer than %.0f m" % [tag, j, i, MULTI_MIN_SPACING])
				return false
	return true


## The killed NPC drops its gun loose and its body falls: the recorded fall ends well
## below where the chest stood, and it stops simulating.
func _assert_npc_falls(ai: DuelistAI) -> bool:
	var dummy := ai.corpse_body()
	if not dummy.has_corpse():
		_fail("NPC death: the body did not collapse")
		return false
	if ai.revolver.held or ai.revolver.freeze or ai.revolver.get_parent() == ai.arm:
		_fail("NPC death: the revolver is still held or frozen in the arm")
		return false
	if not await _wait_for(func() -> bool: return dummy.corpse_state() != BodyRagdoll.State.SIMULATING, 30.0):
		_fail("NPC death: the fall never stopped")
		return false
	var track: BodyRagdoll = dummy._ragdoll
	var drop: float = track.track_at(0.0)[2].origin.y - track.track_at(track.track_length())[2].origin.y
	if drop < 0.3:
		_fail("NPC death: the chest only dropped %.2f m" % drop)
		return false
	print("AUTOTEST: NPC collapsed, chest dropped %.2f m, gun loose" % drop)
	return await _assert_replay(dummy, ai, "NPC")


## The replay stands the body up for the clip before the death, plays the recorded fall
## after it, and ends on the settled pose.
func _assert_replay(dummy: DummyBody, root: Node3D, label: String) -> bool:
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 40.0):
		_fail("%s replay: playback never started" % label)
		return false
	var standing := dummy.bone_global(&"Chest").origin.y - root.global_position.y
	var lead := ReplayBuffer.death_time - DeathCam._play_t
	if lead > 0.2 and (dummy.corpse_state() != BodyRagdoll.State.RETRACE or standing < 1.0):
		_fail("%s replay: the body is not standing before the death (state %d, chest %.2f m)" % [
				label, dummy.corpse_state(), standing])
		return false
	if not await _wait_for(func() -> bool: return DeathCam._play_t >= ReplayBuffer.death_time + 0.3, 40.0):
		_fail("%s replay: playback never reached the death" % label)
		return false
	if dummy.corpse_state() != BodyRagdoll.State.TRACK:
		_fail("%s replay: the fall is not playing after the death (state %d)" % [label, dummy.corpse_state()])
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.TRAILING, 40.0):
		_fail("%s replay: playback never ended" % label)
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var track: BodyRagdoll = dummy._ragdoll
	var held: Vector3 = track.track_at(track.track_length())[2].origin
	var skeleton := dummy.find_child("Skeleton3D", true, false) as Skeleton3D
	var chest := skeleton.get_bone_global_pose(skeleton.find_bone("Chest")).origin
	if dummy.corpse_state() != BodyRagdoll.State.HELD or chest.distance_to(held) > 0.01:
		_fail("%s replay: did not end on the settled pose (state %d, off by %.2f m)" % [
				label, dummy.corpse_state(), chest.distance_to(held)])
		return false
	print("AUTOTEST: %s replay stood up (%.1f s before the death), played the fall, and held the settled pose" % [label, lead])
	return true


## Every hit volume sits on its posed bone. A ray from outside each bone segment must
## meet that segment's Hitbox first. The chest probe covers the old neck-to-torso gap.
func _assert_hitboxes_follow(body: Node3D, dummy: DummyBody, label: String) -> bool:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hips := dummy.bone_global(&"Hips").origin
	var neck := dummy.bone_global(&"Neck").origin
	var front := dummy.global_transform.basis.z
	var probes: Array[Dictionary] = [
		{"name": "HeadHitbox", "at": dummy.bone_global(&"Head").origin + Vector3.UP * 0.03, "dir": front},
		{"name": "TorsoHitbox", "at": hips.lerp(neck, 0.5), "dir": front},
		{"name": "TorsoHitbox", "at": neck - Vector3.UP * 0.04, "dir": front},
	]
	for suffix: String in ["L", "R"]:
		var arm: String = "ArmHitbox" + suffix
		var leg: String = "LegHitbox" + suffix
		var shoulder := dummy.bone_global(StringName("UpperArm." + suffix)).origin
		var elbow := dummy.bone_global(StringName("Forearm." + suffix)).origin
		var wrist := dummy.bone_global(StringName("Hand." + suffix)).origin
		var hip := dummy.bone_global(StringName("UpperLeg." + suffix)).origin
		var knee := dummy.bone_global(StringName("LowerLeg." + suffix)).origin
		var ankle := dummy.bone_global(StringName("Foot." + suffix)).origin
		probes.append({"name": arm, "at": shoulder.lerp(elbow, 0.5), "dir": _outward(shoulder.lerp(elbow, 0.5), hips)})
		probes.append({"name": arm, "at": elbow.lerp(wrist, 0.4), "dir": _outward(elbow.lerp(wrist, 0.4), hips)})
		probes.append({"name": leg, "at": hip.lerp(knee, 0.5), "dir": _outward(hip.lerp(knee, 0.5), hips)})
		probes.append({"name": leg, "at": knee.lerp(ankle, 0.5), "dir": _outward(knee.lerp(ankle, 0.5), hips)})
	var space := get_tree().root.world_3d.direct_space_state
	for probe in probes:
		var at: Vector3 = probe["at"]
		var dir: Vector3 = probe["dir"]
		var query := PhysicsRayQueryParameters3D.create(at + dir, at, 0b100)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit := space.intersect_ray(query)
		var expected := body.get_node(NodePath(String(probe["name"])))
		if hit.is_empty() or hit["collider"] != expected:
			var got: Object = hit.get("collider") if not hit.is_empty() else null
			_fail("%s hitboxes: probe at %s expected %s, got %s" % [label, at, probe["name"], got])
			return false
	print("AUTOTEST: %s hitboxes follow the mesh (%d probes)" % [label, probes.size()])
	return true


func _outward(point: Vector3, center: Vector3) -> Vector3:
	var flat := point - center
	flat.y = 0.0
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT


## BUG-026: a flat draw puts the wrist on the grip the same frame the gun lands, and a
## holster puts it back at the hang. Slow-mo stretches the old ease, so it would show there.
func _assert_flat_draw_snap() -> bool:
	var player := GameManager.local_player
	if player == null or player.use_vr:
		return true
	const STEP := 0.016
	player._holster_gun()
	for i in 20:
		player.drive_wrists_late(STEP)
	player._draw_gun()
	var hand := player.draw_hand_name()
	player.drive_wrists_late(STEP)
	var grip := player._grip_anchor(player.revolver)
	var wrist := player._wrist_marker(hand)
	if grip == null or wrist.global_position.distance_to(grip.global_position) > 0.01:
		_fail("flat draw snap: the wrist trails the gun by %.3f m" % wrist.global_position.distance_to(grip.global_position))
		return false
	player._holster_gun()
	player.drive_wrists_late(STEP)
	var head: Transform3D = player.rig.get_head_transform()
	var yaw := Basis(Vector3.UP, head.basis.get_euler().y)
	var local_hang := Player.ARM_FLAT_HAND_LOCAL
	if hand == Player.HAND_LEFT:
		local_hang.x = -local_hang.x
	var hang := Vector3(head.origin.x, player.global_position.y + 1.1, head.origin.z) + yaw * local_hang
	if wrist.global_position.distance_to(hang) > 0.01:
		_fail("flat draw snap: the wrist trails the holster by %.3f m" % wrist.global_position.distance_to(hang))
		return false
	print("AUTOTEST: flat draw / holster snap the wrist with the gun")
	return true


## Arm hit flings a held gun and does not block an immediate catch. AI gun leaves the arm.
## An off-arm hit (BUG-025) keeps the gun and drops the off-hand prop instead.
func _assert_pain_jerk() -> bool:
	var player := GameManager.local_player
	if player == null or player.revolver == null:
		_fail("pain-jerk: no local player")
		return false
	player._draw_gun()
	if not player.revolver.held:
		_fail("pain-jerk: gun was not in hand")
		return false
	var gun_side := player._body_side(player.draw_hand_name())
	var off_side := &"L" if gun_side == &"R" else &"R"
	player.props.equip_item(PropController.ITEM_COIN)
	var coin: Node3D = player.props.current_prop()
	player.apply_wound(CombatRules.REGION_ARM, player.health, off_side)
	if not player.revolver.held:
		_fail("pain-jerk: an off-arm hit disarmed the player")
		return false
	if coin == null or not coin.is_loose():
		_fail("pain-jerk: an off-arm hit did not drop the coin")
		return false
	player.props.equip_item(PropController.ITEM_NONE)
	player.apply_wound(CombatRules.REGION_ARM, player.health, gun_side)
	if not player.revolver.drawn or player.revolver.held:
		_fail("pain-jerk: arm hit did not toss the player gun")
		return false
	if player.revolver.linear_velocity.y <= 0.0:
		_fail("pain-jerk: player toss had no upward velocity")
		return false
	player._attach_gun_to_hand(&"right_hand")
	if not player.revolver.held:
		_fail("pain-jerk: catch was blocked after the toss")
		return false
	var ai := GameManager.current_ais[0]
	if ai == null or ai.revolver == null:
		_fail("pain-jerk: no AI duelist")
		return false
	var ai_state := ai.state
	ai.take_bullet_hit(0.0, PackedVector3Array(), CombatRules.REGION_ARM, false, false, -1, {}, &"L")
	if ai.state != ai_state or ai.state == DuelistAI.AIState.DISARMED:
		_fail("pain-jerk: an AI off-arm hit disarmed it")
		return false
	ai.take_bullet_hit(0.0, PackedVector3Array(), CombatRules.REGION_ARM, false, false, -1, {}, &"R")
	if ai.revolver.get_parent() == ai.arm:
		_fail("pain-jerk: AI arm hit did not toss the gun")
		return false
	if ai.revolver.linear_velocity.y <= 0.0:
		_fail("pain-jerk: AI toss had no upward velocity")
		return false
	print("AUTOTEST: pain-jerk toss ok")
	return true


## A hinge spin survives the toss and resumes on a catch. An arm hit does not keep it.
func _assert_spin_throw() -> bool:
	var player := GameManager.local_player
	var gun: WeaponBase = player.revolver
	gun.begin_spin()
	gun.spin_omega = 12.0
	gun.release_into_world(get_tree().current_scene, Vector3.ZERO, Vector3.ZERO)
	if not gun.carrying_spin or absf(gun.angular_velocity.length() - 12.0) > 0.5:
		_fail("spin-throw: toss did not keep the hinge speed (%s)" % gun.angular_velocity)
		return false
	player._attach_gun_to_hand(&"right_hand")
	if not gun.is_spin_active() or gun.carrying_spin or absf(gun.spin_omega) < 11.0:
		_fail("spin-throw: catch did not resume the hinge (omega=%s)" % gun.spin_omega)
		return false
	gun.pain_jerk_into_world(get_tree().current_scene)
	if gun.carrying_spin:
		_fail("spin-throw: arm hit kept the hinge")
		return false
	player._attach_gun_to_hand(&"right_hand")
	if gun.is_spin_active():
		_fail("spin-throw: a plain toss resumed the hinge")
		return false
	print("AUTOTEST: spin throw and catch ok")
	return true


## BUG-027: how far the hips may rise above the standing pose in a gravity-only collapse.
const RAGDOLL_MAX_RISE := 0.03


func _test_ragdoll() -> void:
	await _sleep(0.5)
	print("AUTOTEST: physics engine setting=%s, %d ticks/s" % [
			ProjectSettings.get_setting("physics/3d/physics_engine"),
			Engine.physics_ticks_per_second])
	var origin := Vector3(40.0, 0.0, 40.0)
	_make_prop_floor(origin + Vector3(0.0, -0.1, 0.0))
	var dummy := DummyBody.spawn(self)
	dummy.global_position = origin
	await get_tree().process_frame
	await get_tree().physics_frame
	var skeleton := dummy.find_child("Skeleton3D", true, false) as Skeleton3D
	var chest_bone := skeleton.find_bone("Chest")
	var hips_bone := skeleton.find_bone("Hips")
	var start_chest := dummy.bone_global(&"Chest").origin
	var death_chest := skeleton.get_bone_global_pose(chest_bone)
	var death_hips := skeleton.get_bone_global_pose(hips_bone)
	# The mannequin faces -Z, so a shot from in front travels along +Z.
	var hit := start_chest + Vector3(0.0, 0.0, -0.16)
	dummy.collapse(PackedVector3Array([hit + Vector3(0.0, 0.0, -1.0), hit]))
	if not dummy.has_corpse():
		return _fail("ragdoll: collapse made no corpse")
	dummy.set_pose_driven(true)
	if dummy.is_processing():
		return _fail("ragdoll: set_pose_driven(true) woke the pose writers on a corpse")
	var joints: Array[Array] = [
		[&"UpperLeg.L", &"LowerLeg.L", &"Foot.L"], [&"UpperLeg.R", &"LowerLeg.R", &"Foot.R"],
		[&"UpperArm.L", &"Forearm.L", &"Hand.L"], [&"UpperArm.R", &"Forearm.R", &"Hand.R"]]
	var rest_bend: Array[float] = []
	for joint in joints:
		rest_bend.append(_hinge_angle(dummy, joint[0], joint[1], joint[2]))
	var knee_range := Vector2(INF, -INF)
	var elbow_range := Vector2(INF, -INF)
	var max_time := float(GameManager.tuning["ragdoll_max_time"])
	var deadline := Time.get_ticks_msec() + int((max_time + 1.0) * 1000.0)
	while dummy.corpse_state() == BodyRagdoll.State.SIMULATING and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		for i in joints.size():
			var bend := _hinge_angle(dummy, joints[i][0], joints[i][1], joints[i][2]) - rest_bend[i]
			if i < 2:
				knee_range = _widen(knee_range, bend)
			else:
				elbow_range = _widen(elbow_range, bend)
	if dummy.corpse_state() != BodyRagdoll.State.HELD:
		return _fail("ragdoll: still falling after max_time + 1 s (state %d)" % dummy.corpse_state())
	await get_tree().process_frame
	await get_tree().process_frame
	var moved := dummy.bone_global(&"Chest").origin - start_chest
	print("AUTOTEST: ragdoll chest moved %s, knee %.2f..%.2f rad, elbow %.2f..%.2f rad" % [
			moved, knee_range.x, knee_range.y, elbow_range.x, elbow_range.y])
	if moved.y > -0.3:
		return _fail("ragdoll: chest only dropped %.2f m" % -moved.y)
	if moved.z < 0.15:
		return _fail("ragdoll: chest moved %.2f m along the shot" % moved.z)
	# Bend is measured from the standing pose between bone origins, so an upper-arm twist
	# skews it by a few tenths. The wrong hinge sign reads a full radian or more.
	if knee_range.y > 0.4 or knee_range.x < deg_to_rad(-150.0):
		return _fail("ragdoll: knee left its fold-back range %s" % knee_range)
	if elbow_range.x < -0.4 or elbow_range.y > deg_to_rad(150.0):
		return _fail("ragdoll: elbow left its fold range %s" % elbow_range)
	var bodies := dummy.get_node("BodyRagdoll").get_child_count()
	if bodies != 0:
		return _fail("ragdoll: %d bodies or joints left after settling" % bodies)
	# The ink hulls ride the fallen skeleton: same skin and skeleton, still shown.
	if dummy._outline_parts.is_empty():
		return _fail("ragdoll: the body has no outline children")
	for line in dummy._outline_parts:
		if line.skin != dummy._mesh.skin or line.get_node(line.skeleton) != skeleton \
				or not line.is_visible_in_tree() or line.material_override == null:
			return _fail("ragdoll: the corpse's %s outline left the skeleton or is hidden" % line.get_parent().name)
	var held_chest := skeleton.get_bone_global_pose(chest_bone)
	var start_pose := dummy._ragdoll.track_at(0.0)
	var end_pose := dummy._ragdoll.track_at(dummy._ragdoll.track_length())
	if start_pose[2].origin.distance_to(death_chest.origin) > 0.01 			or start_pose[0].origin.distance_to(death_hips.origin) > 0.01:
		return _fail("ragdoll: track start is not the death pose")
	if end_pose[2].origin.distance_to(held_chest.origin) > 0.01:
		return _fail("ragdoll: track end %s is not the held pose %s" % [end_pose[2].origin, held_chest.origin])
	dummy.corpse_replay_begin()
	dummy.set_pose_driven(true)
	if not dummy.is_processing():
		return _fail("ragdoll: replay retrace did not give the skeleton back")
	dummy.corpse_replay_at(0.0)
	if skeleton.get_bone_global_pose(chest_bone).origin.distance_to(death_chest.origin) > 0.01:
		return _fail("ragdoll: replay at 0 is not the death pose")
	dummy.corpse_replay_at(1000.0)
	if skeleton.get_bone_global_pose(chest_bone).origin.distance_to(held_chest.origin) > 0.01:
		return _fail("ragdoll: replay past the end is not the held pose")
	dummy.corpse_hold_final()
	dummy.release_corpse()
	dummy.set_pose_driven(true)
	if dummy.has_corpse() or not dummy.is_processing():
		return _fail("ragdoll: release_corpse left the corpse locked")
	for bone in [chest_bone, hips_bone]:
		var rest := skeleton.get_bone_global_rest(bone)
		if skeleton.get_bone_global_pose(bone).origin.distance_to(rest.origin) > 0.01:
			return _fail("ragdoll: release_corpse did not restore bone %d" % bone)
	# No trail: gravity only. Disabled: the pose is held and nothing falls.
	dummy.collapse(PackedVector3Array())
	if not await _wait_for(func() -> bool: return dummy.corpse_state() == BodyRagdoll.State.HELD, max_time + 1.0):
		return _fail("ragdoll: a collapse without a trail never settled")
	if dummy.bone_global(&"Chest").origin.y > start_chest.y - 0.3:
		return _fail("ragdoll: a collapse without a trail did not fall")
	dummy.release_corpse()
	dummy.set_pose_driven(true)
	GameManager.tuning["ragdoll_enabled"] = 0.0
	dummy.collapse(PackedVector3Array([hit + Vector3(0.0, 0.0, -1.0), hit]))
	GameManager.tuning["ragdoll_enabled"] = 1.0
	if dummy.has_corpse():
		return _fail("ragdoll: ragdoll_enabled 0 still built a corpse")
	print("AUTOTEST: ragdoll core ok")
	if not await _ragdoll_player_ok():
		return
	if not await _ragdoll_npc_floor_ok():
		return
	_pass()


## The local player shot dead in single player: gun and coin drop loose, the body falls,
## and the next duel stands it up.
func _ragdoll_player_ok() -> bool:
	GameManager.start_free_duel(0, 0)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail("ragdoll: duel never reached DRAW")
		return false
	var player := GameManager.local_player
	var dummy := player.corpse_body()
	player._draw_gun()
	player.props.equip_item(PropController.ITEM_COIN)
	var coin := player.props.current_prop() as Coin
	var chest := dummy.bone_global(&"Chest").origin
	player.take_bullet_hit(99.0, PackedVector3Array([chest + Vector3(0.0, 0.0, -1.0), chest]),
			CombatRules.REGION_TORSO)
	if player.alive or not dummy.has_corpse():
		_fail("ragdoll: the player's death made no corpse")
		return false
	if dummy._flash_times.size() != 1 or not is_equal_approx(float(dummy._skin_material.get_shader_parameter("flash")), 1.0):
		_fail("ragdoll: the killing shot did not flash the body (%d logged)" % dummy._flash_times.size())
		return false
	if player.revolver.held or player.revolver.freeze:
		_fail("ragdoll: the dead player's revolver is still held or frozen")
		return false
	if coin == null or not coin.is_loose():
		_fail("ragdoll: the coin did not drop loose")
		return false
	if not await _wait_for(func() -> bool: return dummy.corpse_state() != BodyRagdoll.State.SIMULATING, 30.0):
		_fail("ragdoll: the player's fall never stopped")
		return false
	var track: BodyRagdoll = dummy._ragdoll
	var drop: float = track.track_at(0.0)[2].origin.y - track.track_at(track.track_length())[2].origin.y
	if drop < 0.3:
		_fail("ragdoll: the player's chest only dropped %.2f m" % drop)
		return false
	if not await _assert_replay(dummy, player, "Player"):
		return false
	player.reset_for_duel(player.global_transform)
	if dummy.has_corpse() or not dummy.is_processing():
		_fail("ragdoll: reset_for_duel left the player's corpse locked")
		return false
	print("AUTOTEST: player collapsed (chest dropped %.2f m), reset stands it up" % drop)
	return true


## BUG-027: an NPC on Main Street (arena 0) falls under gravity alone without the hips
## first rising out of the ground.
func _ragdoll_npc_floor_ok() -> bool:
	GameManager.start_free_duel(0, 0)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		_fail("ragdoll: NPC duel never reached DRAW")
		return false
	var dummy := GameManager.current_ais[0].corpse_body()
	var start := dummy.bone_global(&"Hips").origin.y
	var peak := 0.0
	dummy.collapse(PackedVector3Array())
	if not dummy.has_corpse():
		_fail("ragdoll: the NPC collapse made no corpse")
		return false
	var deadline := Time.get_ticks_msec() + int((float(GameManager.tuning["ragdoll_max_time"]) + 1.0) * 1000.0)
	while dummy.corpse_state() == BodyRagdoll.State.SIMULATING and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		peak = maxf(peak, dummy.bone_global(&"Hips").origin.y - start)
	print("AUTOTEST: NPC ragdoll on Main Street, hips peak rise %.3f m" % peak)
	if peak > RAGDOLL_MAX_RISE:
		_fail("ragdoll: the NPC's hips rose %.3f m when it ragdolled" % peak)
		return false
	return true


## Signed bend of `mid` against `upper` about the joint's hinge axis. Positive is the elbow's way
## (hand toward the face); the knee folds the other way.
func _hinge_angle(dummy: DummyBody, upper: StringName, mid: StringName, tip: StringName) -> float:
	var top := dummy.bone_global(upper).origin
	var joint := dummy.bone_global(mid).origin
	var end := dummy.bone_global(tip).origin
	return (joint - top).signed_angle_to(end - joint, dummy.hinge_axis(mid))


func _widen(bounds: Vector2, value: float) -> Vector2:
	return Vector2(minf(bounds.x, value), maxf(bounds.y, value))


# -- Hit chunks ------------------------------------------------------------------

## The bones a cut rides, head to shins. Each needs rest triangles for the skin snap.
const CHUNK_BONES: Array[StringName] = [&"Head", &"Chest", &"Spine", &"UpperArm.L", &"UpperArm.R",
		&"Forearm.L", &"Forearm.R", &"UpperLeg.L", &"UpperLeg.R", &"LowerLeg.L", &"LowerLeg.R"]
const CHUNK_MIN_TRIS := 8
## A cut's skin point lands this close to where the shot enters the CPU-skinned mesh.
const CHUNK_SNAP_TOLERANCE := 0.02
## Uniform centers may trail the live pose by the frame since the last refresh.
const CHUNK_UNIFORM_TOLERANCE := 0.01
const CHUNK_RADIUS_SAMPLES := 24
const CHUNK_CUT_SAMPLES := 20
const CHUNK_CUT_MIN := 0.05
const CHUNK_CUT_MAX := 0.10
const CHUNK_LIMB_MAX := 0.06


func _test_chunks() -> void:
	await _sleep(1.0)
	var saved := {}
	for key: String in ["ai_speed_mult", "chunk_chance", "gib_cap", "gib_speed", "cut_min", "cut_max",
			"cut_limb_max"]:
		saved[key] = GameManager.tuning[key]
	var saved_gore := PlayerSettings.gore_enabled
	GameManager.tuning["ai_speed_mult"] = MULTI_AI_SPEED
	GameManager.tuning["chunk_chance"] = 1.0
	GameManager.tuning["gib_cap"] = 16.0
	GameManager.tuning["cut_min"] = CHUNK_CUT_MIN
	GameManager.tuning["cut_max"] = CHUNK_CUT_MAX
	GameManager.tuning["cut_limb_max"] = CHUNK_LIMB_MAX
	PlayerSettings.gore_enabled = true
	var ok: bool = await _chunks_ok()
	for key: String in saved:
		GameManager.tuning[key] = saved[key]
	PlayerSettings.gore_enabled = saved_gore
	if ok:
		_pass()


func _chunks_ok() -> bool:
	GameManager.start_free_duel(0, 0)
	if not await _wait_for_state(DuelManager.State.DRAW, 25.0):
		_fail("chunks: duel never reached DRAW")
		return false
	var ai := GameManager.current_ais[0]
	var dummy := ai.corpse_body()
	ai.health = 1000.0
	if not _chunks_parse_ok(dummy) or not _chunks_outline_ok(dummy) or not await _chunks_warmup_ok():
		return false
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _chunks_snap_ok(ai, dummy) or not _chunks_radius_ok(dummy):
		return false

	# 4. A real bullet into the left upper arm: one cut on the bone, one gib off the arm.
	var upper := _shape_named(ai.arm_hitbox_l, &"Upper")
	var aim := upper.global_position
	var out := _outward(aim, dummy.bone_global(&"Hips").origin)
	var gibs_before := BodyGib.alive_count()
	Bullet.spawn(get_tree().current_scene, aim + out * 1.5, -out, GameManager.tuning["bullet_speed"],
			true, [], false, 0.0, [], ReplayBuffer.ACTOR_HOST)
	if not await _wait_for(func() -> bool: return dummy.chunk_count() > 0, 5.0):
		_fail("chunks: a bullet into the upper arm cut nothing (alive %s)" % ai.is_alive())
		return false
	var events: Array[Dictionary] = dummy._chunks._events
	var arm_cut: Dictionary = events.back()["cut"]
	var arm_bone := StringName(dummy._skeleton.get_bone_name(arm_cut["bone"]))
	if arm_bone != &"UpperArm.L" or float(arm_cut["radius"]) > CHUNK_LIMB_MAX + 0.0001 \
			or BodyGib.alive_count() != gibs_before + 1:
		_fail("chunks: the arm bullet cut %s r %.3f, gibs %d -> %d" % [arm_bone, arm_cut["radius"], gibs_before,
				BodyGib.alive_count()])
		return false
	if not _chunks_uniforms_ok(dummy, "after the arm bullet"):
		return false
	var gib: BodyGib = events.back()["gib"]
	var shoulder := dummy.bone_global(&"UpperArm.L").origin
	var elbow := dummy.bone_global(&"Forearm.L").origin
	var start := gib.track_at(0.0).origin
	var gap := start.distance_to(Geometry3D.get_closest_point_to_segment(start, shoulder, elbow))
	if gap > BodyHitboxes.UPPER_ARM_RADIUS + 0.05:
		_fail("chunks: the gib left %.3f m from the upper arm" % gap)
		return false
	print("AUTOTEST: chunks: bullet cut UpperArm.L (r %.3f), uniforms match, gib left %.3f m from the bone" % [
			arm_cut["radius"], gap])
	# Hit flash: the accepted hit logged one; flash() raises the skin uniform and never the hands'.
	if dummy._flash_times.size() != 1:
		_fail("chunks: the arm bullet logged %d flashes" % dummy._flash_times.size())
		return false
	dummy.flash(ReplayBuffer.clip_time())
	var hand_flash: Variant = dummy._hand_material.get_shader_parameter("flash")
	if not is_equal_approx(float(dummy._skin_material.get_shader_parameter("flash")), 1.0) 			or (hand_flash != null and float(hand_flash) != 0.0) 			or float(dummy._hand_material.get_shader_parameter("edge_strength")) != 0.0:
		_fail("chunks: flash() skin %s hand %s" % [dummy._skin_material.get_shader_parameter("flash"), hand_flash])
		return false
	dummy._flash_times.pop_back()
	dummy._flash_fired.pop_back()

	# 5. chunk_chance 0 cuts nothing.
	GameManager.tuning["chunk_chance"] = 0.0
	var front := dummy.front_dir()
	var knee := dummy.bone_global(&"LowerLeg.R").origin
	ai.leg_hitbox_r.receive_hit(PackedVector3Array([knee - front * 1.0, knee]), false, false,
			ReplayBuffer.ACTOR_HOST, _shape_index(ai.leg_hitbox_r, &"Thigh"))
	GameManager.tuning["chunk_chance"] = 1.0
	if dummy.chunk_count() != 1 or events.size() != 1:
		_fail("chunks: chunk_chance 0 still cut a hole")
		return false
	if dummy._flash_times.size() != 2:
		_fail("chunks: a hit with an empty cut logged %d flashes, wanted 2" % dummy._flash_times.size())
		return false

	# 6. The gib settles: frozen, with a track, on the ground.
	var max_time := float(GameManager.tuning["ragdoll_max_time"])
	if not await _wait_for(func() -> bool: return gib.is_settled(), max_time + 2.0):
		_fail("chunks: the gib never settled")
		return false
	if not gib.freeze or gib.track_length() <= 0.0:
		_fail("chunks: settled gib frozen %s, track %.2f s" % [gib.freeze, gib.track_length()])
		return false
	var rest := gib.global_position
	var down := PhysicsRayQueryParameters3D.create(rest + Vector3.UP * 0.3, rest + Vector3.DOWN * 0.3, MULTI_WORLD_MASK)
	if gib.get_world_3d().direct_space_state.intersect_ray(down).is_empty():
		_fail("chunks: the gib did not come to rest on the ground (%s, from %s)" % [rest, start])
		return false
	print("AUTOTEST: chunks: chance 0 ok, gib came to rest on the ground at %s" % rest)

	# 7. Replay hooks: the hole heals before its clip time, opens on it, and the gib re-flies.
	if not _chunks_replay_ok(dummy, events[0], gib):
		return false

	# 8. Nine overlapping torso cuts: eight holes, the oldest (the arm, then the first torso
	# cut) healed; each threw a gib, and gib_cap 3 freed the oldest gibs.
	GameManager.tuning["gib_cap"] = 3.0
	var dir := -front
	var chest := dummy.bone_index(&"Chest")
	var right := front.cross(Vector3.UP).normalized()
	var first: Dictionary = {}
	for i in BodyChunks.HOLE_CAP + 1:
		var point := dummy.bone_global(&"Chest").origin + right * (i % 3 - 1) * 0.06 \
				+ Vector3.UP * (i / 3 - 1) * 0.06 + front * DummyBody.SNAP_BACK
		var cut := dummy.cut_on_bone(chest, point, dir, CombatRules.REGION_TORSO)
		if i == 0:
			first = cut
		dummy.knock_chunk(cut, dir, ReplayBuffer.clip_time(), false)
	GameManager.tuning["gib_cap"] = 16.0
	var active := dummy._chunks.active_cuts()
	var first_gone := not active.any(func(c: Dictionary) -> bool: return is_same(c, first))
	var arm_gone := not active.any(func(c: Dictionary) -> bool: return is_same(c, arm_cut))
	if dummy.chunk_count() != BodyChunks.HOLE_CAP or not first_gone or not arm_gone \
			or events.size() != BodyChunks.HOLE_CAP + 2:
		_fail("chunks: 9 more cuts show %d holes (first gone %s, arm gone %s, %d events)" % [dummy.chunk_count(),
				first_gone, arm_gone, events.size()])
		return false
	if BodyGib.alive_count() != 3 or not gib.is_queued_for_deletion():
		_fail("chunks: gib_cap 3 left %d gibs, oldest freed %s" % [BodyGib.alive_count(), gib.is_queued_for_deletion()])
		return false
	if not _chunks_uniforms_ok(dummy, "at the hole cap"):
		return false
	var cut_usec := 0
	for i in CHUNK_CUT_SAMPLES:
		var t0 := Time.get_ticks_usec()
		dummy.cut_on_bone(chest, dummy.bone_global(&"Chest").origin + front * DummyBody.SNAP_BACK * 2.0, dir,
				CombatRules.REGION_TORSO)
		cut_usec += Time.get_ticks_usec() - t0
	print("AUTOTEST: chunks: cap %d holes, oldest healed, gib_cap frees the oldest; cut %.2f ms" % [
			BodyChunks.HOLE_CAP, cut_usec / 1000.0 / CHUNK_CUT_SAMPLES])

	# 9. Gore off heals every hole, frees the gibs, and blocks new cuts.
	var any_cut := dummy.cut_on_bone(chest, dummy.bone_global(&"Chest").origin + front * 0.3, dir,
			CombatRules.REGION_TORSO)
	PlayerSettings.set_gore_enabled(false)
	await get_tree().process_frame
	var cleared := dummy.chunk_count() == 0 and BodyGib.alive_count() == 0 and _chunks_uniforms_ok(dummy, "gore off")
	dummy.knock_chunk(any_cut, dir, ReplayBuffer.clip_time(), true)
	var blocked := dummy.chunk_count() == 0 and BodyGib.alive_count() == 0
	PlayerSettings.set_gore_enabled(true)
	if not cleared or not blocked:
		_fail("chunks: gore off cleared %s, blocked %s" % [cleared, blocked])
		return false

	# 10. Shelved: the hole opens with no gib; a lethal cut still throws one.
	dummy.set_body_shelved(true)
	dummy.knock_chunk(any_cut, dir, ReplayBuffer.clip_time(), false)
	var shelved_gibs := BodyGib.alive_count()
	var shelved_holes := dummy.chunk_count()
	dummy.knock_chunk(any_cut, dir, ReplayBuffer.clip_time(), true)
	var lethal_gibs := BodyGib.alive_count()
	dummy.set_body_shelved(false)
	if shelved_holes != 1 or shelved_gibs != 0 or lethal_gibs != 1:
		_fail("chunks: shelved cut holes %d gibs %d, lethal gibs %d" % [shelved_holes, shelved_gibs, lethal_gibs])
		return false
	print("AUTOTEST: chunks: gore off and shelved body ok")

	# 11. A wave heal closes the player's holes and leaves the gibs.
	var player := GameManager.local_player
	var player_body := player.corpse_body()
	var player_cut := player_body.cut_on_bone(player_body.bone_index(&"Chest"),
			player_body.bone_global(&"Chest").origin + player_body.front_dir() * 0.3, -player_body.front_dir(),
			CombatRules.REGION_TORSO)
	player_body.knock_chunk(player_cut, -player_body.front_dir(), ReplayBuffer.clip_time(), false)
	var player_gib: Variant = player_body._chunks._events.back()["gib"] if not player_body._chunks._events.is_empty() else null
	if player_body.chunk_count() != 1 or not is_instance_valid(player_gib):
		_fail("chunks: the player's torso cut made no hole or gib")
		return false
	player.reset_for_wave()
	if player_body.chunk_count() != 0 or not is_instance_valid(player_gib) \
			or (player_gib as BodyGib).is_queued_for_deletion():
		_fail("chunks: reset_for_wave did not heal the hole or freed the gib")
		return false
	dummy.reset_chunks()
	if dummy.chunk_count() != 0 or dummy._skin_material.next_pass != null:
		_fail("chunks: reset_chunks left %d holes (cavity %s)" % [dummy.chunk_count(), dummy._skin_material.next_pass])
		return false
	print("AUTOTEST: chunks: wave reset heals holes, gibs stay")

	# 12. A head kill: the replay shows the head whole before the death and holed after.
	if not await _chunks_head_kill_ok(ai, dummy):
		return false

	# 13. A new duel frees the gibs.
	var refs: Array[WeakRef] = []
	for alive: Variant in BodyGib._alive:
		if is_instance_valid(alive):
			refs.append(weakref(alive))
	if refs.is_empty():
		_fail("chunks: no gibs left to check the new duel frees them")
		return false
	GameManager.start_free_duel(0, 0)
	for ref in refs:
		if not await _wait_freed(ref, 3.0):
			_fail("chunks: a new duel kept a gib from the last one")
			return false
	if BodyGib.alive_count() != 0:
		_fail("chunks: %d gibs counted after a new duel" % BodyGib.alive_count())
		return false
	print("AUTOTEST: chunks: a new duel freed %d gibs" % refs.size())
	return true


## 1. Every cut bone has rest triangles for the skin snap. Body and head share the intact
## parts and wear the skin shader; the hands keep the solid material (never cut).
func _chunks_parse_ok(dummy: DummyBody) -> bool:
	var split: Dictionary = dummy._split
	var bind_tris: Dictionary = split.get("bind_tris", {})
	var line := PackedStringArray()
	for bone_name in CHUNK_BONES:
		var bind := DummyBody._skin_bind(dummy._mesh.skin, dummy._skeleton, bone_name)
		var tris := (bind_tris.get(bind, PackedVector3Array()) as PackedVector3Array).size() / 3
		if tris < CHUNK_MIN_TRIS:
			_fail("chunks: %s has %d rest triangles for the skin snap" % [bone_name, tris])
			return false
		line.append("%s %d" % [bone_name, tris])
	var intact: Dictionary = split.get("intact", {})
	if dummy._body_mesh.mesh != intact.get(&"body") or dummy._head_mesh.mesh != intact.get(&"head"):
		_fail("chunks: body and head do not share the intact part meshes")
		return false
	if dummy._body_mesh.material_override != dummy._skin_material \
			or dummy._head_mesh.material_override != dummy._skin_material:
		_fail("chunks: body and head do not wear the shared skin shader")
		return false
	for hand in dummy._hand_meshes:
		if hand.material_override != dummy._hand_material \
				or dummy._hand_material == dummy._skin_material:
			_fail("chunks: a hand wears %s, not its own banded skin" % hand.material_override)
			return false
	print("AUTOTEST: chunks: snap triangles (%s)" % ", ".join(line))
	return true


## 1b. Every part carries an "Outline" child: the cached welded copy on the part's skin and
## skeleton, wearing the ink shader. The weld closes the flat-shaded cracks (one normal per
## position) and keeps the part's vertex and index counts. The tuning knobs and the
## first-person clip reach it.
func _chunks_outline_ok(dummy: DummyBody) -> bool:
	var welded: Dictionary = dummy._split.get("outline", {})
	var parts: Array[MeshInstance3D] = [dummy._body_mesh, dummy._head_mesh]
	parts.append_array(dummy._hand_meshes)
	if dummy._outline_parts.size() != parts.size():
		_fail("chunks: %d outline children for %d parts" % [dummy._outline_parts.size(), parts.size()])
		return false
	var cracked := 0
	var worst := 0.0
	for part in parts:
		var line := part.get_node_or_null("Outline") as MeshInstance3D
		var ink: ShaderMaterial = dummy._hand_outline_material if dummy._hand_meshes.has(part) else dummy._outline_material
		if line == null or not dummy._outline_parts.has(line) or line.skin != part.skin \
				or line.get_node(line.skeleton) != dummy._skeleton \
				or line.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or line.layers != part.layers:
			_fail("chunks: %s has no outline child on its skin and skeleton" % part.name)
			return false
		if line.material_override != ink or ink.shader != BodyChunks.OUTLINE_SHADER:
			_fail("chunks: the %s outline wears %s, not its ink" % [part.name, line.material_override])
			return false
		if not welded.values().has(line.mesh):
			_fail("chunks: the %s outline is not the cached welded mesh" % part.name)
			return false
		var source := part.mesh.surface_get_arrays(0)
		var arrays := line.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != verts.size() \
				or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() != (source[Mesh.ARRAY_INDEX] as PackedInt32Array).size():
			_fail("chunks: the %s outline changed the vertex or index count" % part.name)
			return false
		var was: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var now: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var first_was := {}
		var first_now := {}
		for i in verts.size():
			var cell := Vector3i((verts[i] / DummyBody.WELD_EPSILON).round())
			if not first_now.has(cell):
				first_now[cell] = now[i]
				first_was[cell] = was[i]
				continue
			worst = maxf(worst, (now[i] - (first_now[cell] as Vector3)).length())
			if (was[i] - (first_was[cell] as Vector3)).length() > 0.1:
				cracked += 1
	if worst > 0.001:
		_fail("chunks: welded outline normals at one position still differ by %.4f" % worst)
		return false
	if cracked == 0:
		_fail("chunks: the source parts have no split normals, so the weld proves nothing")
		return false
	# The knobs: width on both inks, visibility on every child, clip on the body's ink only.
	var saved_on: Variant = GameManager.tuning.get("outline_enabled", 1.0)
	var saved_width: Variant = GameManager.tuning.get("outline_width", 0.004)
	GameManager.tuning["outline_width"] = 0.01
	GameManager.tuning_changed.emit("outline_width", 0.01)
	var width_ok := is_equal_approx(float(dummy._outline_material.get_shader_parameter("width")), 0.01) \
			and is_equal_approx(float(dummy._hand_outline_material.get_shader_parameter("width")), 0.01)
	GameManager.tuning["outline_enabled"] = 0.0
	GameManager.tuning_changed.emit("outline_enabled", 0.0)
	var hidden := dummy._outline_parts.all(func(line: MeshInstance3D) -> bool: return not line.visible)
	GameManager.tuning["outline_enabled"] = saved_on
	GameManager.tuning["outline_width"] = saved_width
	GameManager.tuning_changed.emit("outline_enabled", saved_on)
	GameManager.tuning_changed.emit("outline_width", saved_width)
	var shown := dummy._outline_parts.all(func(line: MeshInstance3D) -> bool: return line.visible)
	if not width_ok or not hidden or not shown:
		_fail("chunks: outline knobs: width %s, hidden at 0 %s, shown again %s" % [width_ok, hidden, shown])
		return false
	var before := dummy._fp_clip
	dummy.set_first_person_clip(true)
	var body_clip := float(dummy._outline_material.get_shader_parameter("clip_radius"))
	var hand_clip := float(dummy._hand_outline_material.get_shader_parameter("clip_radius"))
	dummy.set_first_person_clip(before)
	if body_clip != DummyBody.FP_CLIP_RADIUS or hand_clip != 0.0 \
			or float(dummy._outline_material.get_shader_parameter("clip_radius")) != (DummyBody.FP_CLIP_RADIUS if before else 0.0):
		_fail("chunks: outline clip body %.2f hand %.2f" % [body_clip, hand_clip])
		return false
	print("AUTOTEST: chunks: %d outline children, welded normals within %.5f (%d split in the source)" % [
			parts.size(), worst, cracked])
	return true


## 2. Boot warmup (skipped headless): a probe with both hole passes and an ink hull child,
## plus one frozen gib the cap does not count.
func _chunks_warmup_ok() -> bool:
	var warm := Node3D.new()
	add_child(warm)
	BodyChunks.spawn_for_compile(warm)
	var warm_gibs := warm.get_children().filter(func(node: Node) -> bool: return node is BodyGib)
	var probes := warm.get_children().filter(func(node: Node) -> bool: return node is MeshInstance3D)
	var warm_count := warm.get_child_count()
	var warm_frozen := not warm_gibs.is_empty() and (warm_gibs[0] as BodyGib).freeze
	var skin := (probes[0] as MeshInstance3D).material_override as ShaderMaterial if not probes.is_empty() else null
	var passes := skin != null and skin.shader == BodyChunks.SKIN_SHADER and skin.next_pass != null \
			and (skin.next_pass as ShaderMaterial).shader == BodyChunks.CAVITY_SHADER
	var hull := (probes[0] as Node).get_node_or_null("Outline") as MeshInstance3D if not probes.is_empty() else null
	var hull_ink := hull.material_override as ShaderMaterial if hull != null else null
	var inked := hull_ink != null and hull_ink.shader == BodyChunks.OUTLINE_SHADER \
			and int(hull_ink.get_shader_parameter("hole_count")) == 1
	# Probe first: the headless renderer logs a null material if the gib goes before it.
	await get_tree().process_frame
	if not probes.is_empty():
		(probes[0] as Node).free()
	warm.free()
	if warm_count != 2 or warm_gibs.size() != 1 or not warm_frozen or not passes or not inked \
			or BodyGib.alive_count() != 0:
		_fail("chunks: warmup drew %d nodes, %d gibs (frozen %s), both passes %s, ink hull %s, %d counted" % [
				warm_count, warm_gibs.size(), warm_frozen, passes, inked, BodyGib.alive_count()])
		return false
	return true


## 3. A shot into the head, the torso front and back, an arm, and a leg: the cut rides the
## struck bone and its skin point lands where the shot enters the CPU-skinned mesh.
func _chunks_snap_ok(ai: DuelistAI, dummy: DummyBody) -> bool:
	var front := dummy.front_dir()
	var torso := _shape_named(ai.torso_hitbox, &"Torso").global_position + Vector3.UP * 0.1
	var arm := _shape_named(ai.arm_hitbox_l, &"Upper").global_position
	var thigh := _shape_named(ai.leg_hitbox_r, &"Thigh").global_position
	var cases := [
		["head", ai.head_hitbox, _hitbox_center(ai.head_hitbox), -front, [&"Head"]],
		["torso front", ai.torso_hitbox, torso, -front, [&"Chest", &"Spine"]],
		["torso back", ai.torso_hitbox, torso, front, [&"Chest", &"Spine"]],
		["arm", ai.arm_hitbox_l, arm, -_outward(arm, dummy.bone_global(&"Hips").origin), [&"UpperArm.L"]],
		["leg", ai.leg_hitbox_r, thigh, -front, [&"UpperLeg.R"]],
	]
	var hitboxes: Array[Hitbox] = [ai.head_hitbox, ai.torso_hitbox, ai.arm_hitbox_l, ai.arm_hitbox_r,
			ai.leg_hitbox_l, ai.leg_hitbox_r]
	var space := ai.get_world_3d().direct_space_state
	var line := PackedStringArray()
	for case: Array in cases:
		var label: String = case[0]
		var hitbox: Hitbox = case[1]
		var target: Vector3 = case[2]
		var dir: Vector3 = case[3]
		var query := PhysicsRayQueryParameters3D.create(target - dir * 1.5, target + dir * 0.5, hitbox.collision_layer)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var exclude: Array[RID] = []
		for other in hitboxes:
			if other != hitbox:
				exclude.append(other.get_rid())
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] != hitbox:
			_fail("chunks: the %s ray missed its hit volume" % label)
			return false
		var shape := hitbox.shape_owner_get_owner(hitbox.shape_find_owner(hit["shape"]))
		var cut := dummy.cut_at(shape, hit["position"], dir, hitbox.region)
		if cut.is_empty():
			_fail("chunks: the %s hit made no cut" % label)
			return false
		var bone := StringName(dummy._skeleton.get_bone_name(cut["bone"]))
		if not (case[4] as Array).has(bone):
			_fail("chunks: the %s cut rides %s" % [label, bone])
			return false
		var skin := dummy.cut_world_center(cut) + dir * BodyChunks.CUT_LIFT * float(cut["radius"])
		var entry: Variant = _skinned_entry(dummy, cut["bone"], hit["position"] - dir * DummyBody.SNAP_BACK, dir,
				DummyBody.SNAP_BACK + DummyBody.SNAP_REACH)
		if entry == null:
			_fail("chunks: the %s ray enters no skinned triangle" % label)
			return false
		var miss := skin.distance_to(entry)
		if miss > CHUNK_SNAP_TOLERANCE:
			_fail("chunks: the %s cut sits %.3f m from the skin entry (snap from %.3f m)" % [label, miss,
					(hit["position"] as Vector3).distance_to(entry)])
			return false
		line.append("%s %s %.3f" % [label, bone, miss])
	print("AUTOTEST: chunks: cuts land on the skin (%s)" % ", ".join(line))
	return true


## Head and torso radii stay in `cut_min..cut_max`; arms and legs under `cut_limb_max`.
func _chunks_radius_ok(dummy: DummyBody) -> bool:
	var point := dummy.bone_global(&"Chest").origin + dummy.front_dir() * 0.3
	for i in CHUNK_RADIUS_SAMPLES:
		var torso := float(dummy.cut_on_bone(dummy.bone_index(&"Chest"), point, -dummy.front_dir(),
				CombatRules.REGION_TORSO)["radius"])
		var arm := float(dummy.cut_on_bone(dummy.bone_index(&"Forearm.R"), point, -dummy.front_dir(),
				CombatRules.REGION_ARM)["radius"])
		var leg := float(dummy.cut_on_bone(dummy.bone_index(&"LowerLeg.L"), point, -dummy.front_dir(),
				CombatRules.REGION_LEG)["radius"])
		if torso < CHUNK_CUT_MIN - 0.0001 or torso > CHUNK_CUT_MAX + 0.0001 \
				or arm > CHUNK_LIMB_MAX + 0.0001 or leg > CHUNK_LIMB_MAX + 0.0001:
			_fail("chunks: radii torso %.3f, arm %.3f, leg %.3f" % [torso, arm, leg])
			return false
	return true


## The showing cuts are the skin's `holes` / `hole_count` (and the cavity's), and the
## cavity pass rides the skin only while there is one.
func _chunks_uniforms_ok(dummy: DummyBody, label: String) -> bool:
	var skin: ShaderMaterial = dummy._skin_material
	var cavity: ShaderMaterial = dummy._cavity_material
	var cuts := dummy._chunks.active_cuts()
	var count := int(skin.get_shader_parameter("hole_count"))
	if count != cuts.size() or count != dummy.chunk_count() or int(cavity.get_shader_parameter("hole_count")) != count:
		_fail("chunks: %s hole_count %d, %d active cuts" % [label, count, cuts.size()])
		return false
	if (skin.next_pass == cavity) != (count > 0) or (count == 0 and skin.next_pass != null):
		_fail("chunks: %s cavity pass %s with %d holes" % [label, skin.next_pass, count])
		return false
	var holes: PackedVector4Array = skin.get_shader_parameter("holes")
	for i in cuts.size():
		var center := dummy.cut_world_center(cuts[i])
		var hole := holes[i]
		if Vector3(hole.x, hole.y, hole.z).distance_to(center) > CHUNK_UNIFORM_TOLERANCE \
				or absf(hole.w - float(cuts[i]["radius"])) > 0.0001:
			_fail("chunks: %s hole %d is %s, the cut is at %s r %.3f" % [label, i, hole, center, cuts[i]["radius"]])
			return false
	# The ink hull is cut by the same holes; the hands' ink never is.
	var ink: ShaderMaterial = dummy._outline_material
	if int(ink.get_shader_parameter("hole_count")) != count or ink.get_shader_parameter("holes") != holes \
			or int(dummy._hand_outline_material.get_shader_parameter("hole_count")) != 0:
		_fail("chunks: %s ink hull hole_count %d (skin %d), hands' ink %s" % [label,
				int(ink.get_shader_parameter("hole_count")), count,
				dummy._hand_outline_material.get_shader_parameter("hole_count")])
		return false
	return true


func _chunks_replay_ok(dummy: DummyBody, event: Dictionary, gib: BodyGib) -> bool:
	var t_hit: float = event["t"]
	if t_hit < 0.0:
		_fail("chunks: the cut has no clip time")
		return false
	dummy.chunks_replay_begin(t_hit - 1.0)
	if dummy.chunk_count() != 0 or gib.visible or not _chunks_uniforms_ok(dummy, "replay begin"):
		_fail("chunks: replay begin did not heal the hole and hide the gib")
		return false
	dummy._flash_tween.kill()
	dummy._skin_material.set_shader_parameter("flash", 0.0)
	dummy.chunks_replay_at(t_hit - 0.1)
	if dummy.chunk_count() != 0 or gib.visible 			or float(dummy._skin_material.get_shader_parameter("flash")) != 0.0:
		_fail("chunks: the hole opened or the body flashed before its clip time")
		return false
	dummy.chunks_replay_at(t_hit + 0.001)
	if not is_equal_approx(float(dummy._skin_material.get_shader_parameter("flash")), 1.0):
		_fail("chunks: the replay did not re-flash at the hit")
		return false
	dummy._flash_tween.kill()
	var since := minf(0.2, gib.track_length())
	dummy.chunks_replay_at(t_hit + since)
	if dummy.chunk_count() != 1 or not gib.visible or not _chunks_uniforms_ok(dummy, "replay pop") \
			or gib.global_position.distance_to(gib.track_at(since).origin) > 0.001:
		_fail("chunks: replay at the hit did not open the hole with the gib on its track")
		return false
	dummy.chunks_hold_final()
	if dummy.chunk_count() != 1 or gib.global_position.distance_to(gib.track_at(gib.track_length()).origin) > 0.001:
		_fail("chunks: hold final did not keep the hole and the settled gib")
		return false
	dummy.chunks_replay_begin(t_hit + 0.5)
	var kept := dummy.chunk_count() == 1 and gib.visible
	dummy.chunks_hold_final()
	if not kept:
		_fail("chunks: a cut from before the clip healed")
		return false
	print("AUTOTEST: chunks: gib settled (%.2f s track), replay heal / open / hold ok" % gib.track_length())
	return true


func _chunks_head_kill_ok(ai: DuelistAI, dummy: DummyBody) -> bool:
	await get_tree().physics_frame
	var head := _hitbox_center(ai.head_hitbox)
	var front := dummy.front_dir()
	var origin := head + front * 2.0 + Vector3.UP * 0.3
	var result := _arm_duel_listener()
	Bullet.spawn(get_tree().current_scene, origin, (head - origin).normalized(), GameManager.tuning["bullet_speed"],
			true, [], false, 0.0, [], ReplayBuffer.ACTOR_HOST)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true or not _has_head_cut(dummy):
		_fail("chunks: the head shot did not win with a head cut (%s, cut %s)" % [result, _has_head_cut(dummy)])
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 40.0):
		_fail("chunks: replay never started")
		return false
	var lead := ReplayBuffer.death_time - DeathCam._play_t
	if lead > 0.2 and _has_head_cut(dummy):
		_fail("chunks: the head is holed %.1f s before the death in the replay" % lead)
		return false
	if not await _wait_for(func() -> bool: return DeathCam._play_t >= ReplayBuffer.death_time + 0.3, 40.0):
		_fail("chunks: replay never reached the death")
		return false
	if not _has_head_cut(dummy):
		_fail("chunks: the head hole did not open after the death in the replay")
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.TRAILING, 40.0):
		_fail("chunks: replay never ended")
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	if not _has_head_cut(dummy):
		_fail("chunks: the head hole healed on the trailing orbit")
		return false
	print("AUTOTEST: chunks: head kill whole %.1f s before the death in the replay, holed after, kept on trailing" % lead)
	return true


func _has_head_cut(dummy: DummyBody) -> bool:
	var head := dummy.bone_index(&"Head")
	return dummy._chunks.active_cuts().any(func(cut: Dictionary) -> bool: return int(cut["bone"]) == head)


## Where a ray from `from` along `dir` (within `reach`) enters the body and head parts
## skinned on the CPU with every weight, over triangles with a corner `bone` or its parent
## dominates. Independent of the snap's per-bind rest cast. Null when it misses.
func _skinned_entry(dummy: DummyBody, bone: int, from: Vector3, dir: Vector3, reach: float) -> Variant:
	var skeleton := dummy._skeleton
	var skin := dummy._mesh.skin
	var near := [bone, skeleton.get_bone_parent(bone)]
	var mats := {}
	var bind_bones := {}
	for bind in skin.get_bind_count():
		var b := skin.get_bind_bone(bind)
		if b < 0:
			b = skeleton.find_bone(skin.get_bind_name(bind))
		bind_bones[bind] = b
		mats[bind] = dummy.bone_pose_world(b) * skin.get_bind_pose(bind)
	var best := reach
	var entry: Variant = null
	for part in [dummy._body_mesh, dummy._head_mesh]:
		var arrays := (part as MeshInstance3D).mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var stride := bones.size() / verts.size()
		var posed := PackedVector3Array()
		posed.resize(verts.size())
		var leans := PackedByteArray()
		leans.resize(verts.size())
		for v in verts.size():
			var sum := Vector3.ZERO
			var total := 0.0
			var top := -1
			var top_w := 0.0
			for s in stride:
				var w := weights[v * stride + s]
				if w <= 0.0:
					continue
				var bind := bones[v * stride + s]
				sum += (mats[bind] as Transform3D) * verts[v] * w
				total += w
				if w > top_w:
					top_w = w
					top = bind
			posed[v] = sum / total if total > 0.0 else verts[v]
			leans[v] = 1 if top >= 0 and near.has(bind_bones[top]) else 0
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			if leans[a] + leans[b] + leans[c] == 0:
				continue
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, posed[a], posed[b], posed[c])
			if hit == null:
				continue
			var t := ((hit as Vector3) - from).dot(dir)
			if t < best:
				best = t
				entry = hit
	return entry


func _shape_named(hitbox: Hitbox, shape_name: StringName) -> CollisionShape3D:
	return hitbox.get_node(NodePath(String(shape_name))) as CollisionShape3D


## The area shape index a ray would report for `shape_name`.
func _shape_index(hitbox: Hitbox, shape_name: StringName) -> int:
	var node := _shape_named(hitbox, shape_name)
	for owner_id in hitbox.get_shape_owners():
		if hitbox.shape_owner_get_owner(owner_id) == node:
			return hitbox.shape_owner_get_shape_index(owner_id, 0)
	return -1


func _test_host() -> void:
	await _sleep(0.5)
	if NetworkManager.host_lan() != OK:
		return _fail("could not host LAN")
	if not GameManager.in_mp_lobby() or NetworkManager.joinable_slots() != 1:
		return _fail("host: hosting did not open a waiting room with one open slot")
	if NetworkManager.host_start():
		return _fail("host: START worked with a slot still open")
	print("AUTOTEST: hosting, waiting for peer...")
	if not await _wait_for(func() -> bool: return NetworkManager.roster.can_start(), 40.0):
		return _fail("no peer joined")
	print("AUTOTEST: peer joined as '%s'" % NetworkManager.roster.slots[1]["name"])
	# Joining no longer starts the duel: both stand in the waiting room until START.
	await _sleep(1.0)
	if not GameManager.in_mp_lobby() or not (GameManager.actor_node(1) is RemoteAvatar):
		return _fail("host: no waiting room with the joiner's avatar (duel state %d)" % GameManager.duel.state)
	if not _lobby_tints_ok("host waiting room", 2):
		return
	if NetworkManager.joinable_slots() != 0 or NetworkManager.discovery._host_slots != "0/2":
		return _fail("host: a full lobby still advertises '%s'" % NetworkManager.discovery._host_slots)
	# The Lobby page: START is enabled once the joiner is in, with Kick on the joiner only.
	var pause := GameManager.hud.pause_menu
	pause.open()
	pause.show_lobby()
	var panel := pause.lobby_panel
	if not pause.is_lobby_open() or not panel.start_button.visible or panel.start_button.disabled \
			or panel.status_label.visible or panel.back_to_lobby_button.visible or panel.my_side_button.visible \
			or panel.rows.size() != 2 or panel.rows[0]["kick"] != null or panel.rows[1]["kick"] == null \
			or panel.rows[1]["kick"].disabled or pause.restart_button.visible:
		return _fail("host: the Lobby page should show an enabled START and a Kick on the joiner only")
	if panel.rows[1]["name"].text != NetworkManager.roster.slots[1]["name"] \
			or not (panel.rows[0]["name"].text as String).begins_with(NetworkManager.roster.slots[0]["name"]):
		return _fail("host: the Lobby page rows do not carry the roster's names")
	panel.start_button.pressed.emit()
	if pause.is_open or GameManager.duel.state != DuelManager.State.STANDOFF:
		return _fail("host: the page's START should start the duel and close the menu (state %d)" % GameManager.duel.state)
	print("AUTOTEST: host pressed START on the Lobby page")
	if not await _wait_for_state(DuelManager.State.DRAW, 30.0):
		return _fail("MP duel never reached DRAW (holster relay?)")
	var avatar: RemoteAvatar = GameManager.avatars[1]
	if GameManager.avatars.size() != 1 or avatar.slot != 1 or GameManager.local_actor_id() != 0 \
			or not ReplayBuffer.is_recording():
		return _fail("host: the 1v1 duel did not start on slots 0 and 1 with a clip recording")
	var spawn_gap := avatar.global_position.distance_to(GameManager.current_scenario.get_enemy_spawn().origin) \
			+ GameManager.local_player.global_position.distance_to(GameManager.current_scenario.get_player_spawn().origin)
	if spawn_gap > 0.05:
		return _fail("host: 1v1 no longer stands on PlayerSpawn / EnemySpawn (off by %.2f m)" % spawn_gap)
	if not _lobby_tints_ok("host", 2):
		return
	if not await _assert_hitboxes_follow(avatar, avatar._dummy, "remote avatar"):
		return
	print("AUTOTEST: MP DRAW reached, host shoots the avatar")
	var result := _arm_duel_listener()
	var head := avatar._dummy.bone_global(&"Head").origin
	var shot := Vector3(0.0, 0.0, 1.0)
	var cut := avatar._dummy.cut_on_bone(avatar._dummy.bone_index(&"Head"), head, shot, CombatRules.REGION_HEAD)
	if cut.is_empty():
		return _fail("host: no head cut to send")
	avatar.take_bullet_hit(99.0, PackedVector3Array([head - shot, head]), CombatRules.REGION_HEAD, false, false, 0, cut)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true:
		return _fail("host did not win the MP duel")
	if result[1] != "MSG_REASON_CLEAN_KILL" or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != 1 \
			or not DeathCam.is_active() or NetworkManager.roster.slots[0]["wins"] != 1:
		return _fail("host: the 1v1 kill should be a clean kill by slot 0 with the death cam and a win tallied (%s)" % [result])
	if GameManager.hud.message_label.text != "%s\n%s" % [tr("MSG_YOU_WIN"), tr("MSG_REASON_CLEAN_KILL")]:
		return _fail("host: a 1v1 win should read YOU WIN / Clean kill ('%s')" % GameManager.hud.message_label.text)
	if not avatar._dummy.has_corpse() or avatar.gun.get_parent() == avatar.holster:
		return _fail("host: the shot avatar did not collapse and drop its gun")
	print("AUTOTEST: shot avatar collapsed")
	if PlayerSettings.gore_enabled and (not _has_head_cut(avatar._dummy) or avatar._dummy.chunk_count() != 1):
		return _fail("host: the avatar has no hole on the head (%d holes)" % avatar._dummy.chunk_count())
	print("AUTOTEST: avatar head holed")
	await _sleep(1.0)  # let the RPC flush to the client before quitting
	_pass()


func _test_join() -> void:
	await _sleep(2.0)
	if NetworkManager.join_lan("127.0.0.1") != OK:
		return _fail("could not start joining")
	if not await _wait_for(func() -> bool: return NetworkManager.is_active(), 30.0):
		return _fail("never connected to host")
	print("AUTOTEST: connected to host")
	var in_room := func() -> bool:
		return GameManager.in_mp_lobby() and GameManager.actor_node(0) is RemoteAvatar
	if not await _wait_for(in_room, 10.0):
		return _fail("client never reached the waiting room (duel state %d)" % GameManager.duel.state)
	var roster := NetworkManager.roster
	if roster.local_slot() != 1 or roster.slots.size() != 2 or not roster.can_start():
		return _fail("client: bad roster in the waiting room: %s" % roster.pack())
	if not _lobby_tints_ok("client waiting room", 2):
		return
	if not _client_page_ok("client"):
		return
	if NetworkManager.host_start():
		return _fail("client: START must be host only")
	print("AUTOTEST: client in the waiting room on slot 1, host is '%s'" % roster.slots[0]["name"])
	var result := await _wait_duel_finished(60.0)
	if result.is_empty():
		return _fail("client never saw the duel resolve")
	if result[0] != false:
		return _fail("client unexpectedly won")
	if GameManager.local_actor_id() != 1 or ReplayBuffer.victim_id != 1 or not DeathCam.is_active() \
			or not DeathCam._local_is_victim():
		return _fail("client: the death cam is not on slot 1, the local victim")
	if result[1] != "MSG_REASON_CLEAN_KILL" or GameManager.hud.message_label.text != "%s\n%s" % [tr("MSG_YOU_LOSE"), tr(result[1])]:
		return _fail("client: a 1v1 loss should read YOU LOSE / Clean kill ('%s')" % GameManager.hud.message_label.text)
	if not _lobby_tints_ok("client", 2):
		return
	print("AUTOTEST: client correctly lost the duel (%s)" % result[1])
	var local := GameManager.local_player
	if not local.corpse_body().has_corpse() or local.revolver.held:
		return _fail("client: the shot player did not collapse and drop the gun")
	print("AUTOTEST: client body collapsed")
	if PlayerSettings.gore_enabled and (not _has_head_cut(local.corpse_body()) or local.corpse_body().chunk_count() != 1):
		return _fail("client: the shot player has no hole on the head (%d holes)" % local.corpse_body().chunk_count())
	print("AUTOTEST: client head holed")
	_pass()


# -- Lobbies of 3-4 ------------------------------------------------------------------

## The `lobbyhost` / `lobbyjoin` roster: the host, two joiners, and one NPC in the last slot.
const LOBBY_SLOTS := 4
const LOBBY_HUMANS := 3
const LOBBY_NPC_SLOT := 3
## The Sheriff: it strafes from the bell on, so its proxy's head has to move.
const LOBBY_NPC_ARCHETYPE := 1
## Seconds the host leaves between its kills of the two joiners, so each joiner can check
## the mid-duel state.
const LOBBY_KILL_GAP := 2.5
## Seconds the host leaves after the NPC draws, fires, and dies, for the joiners to see
## each on its proxy. Short: every death has to stay inside the final clip.
const LOBBY_NPC_GAP := 1.0
const LOBBY_FAKE_PEERS: Array[int] = [2001, 2002, 2003]
const LOBBY_FAKE_NAMES: Array[String] = ["Ann", "Bob", "Cy"]


## Three humans and an NPC, free-for-all: the host of `lobbyhost` + two `lobbyjoin`
## processes. The host runs the NPC, slowed, and scripts it: it draws, fires into the sky,
## and is the first to die, so it cannot decide the duel.
func _test_lobby_host() -> void:
	await _sleep(0.5)
	var heard := _hear_messages()
	GameManager.tuning["ai_speed_mult"] = MULTI_AI_SPEED
	GameManager.tuning["chunk_chance"] = 1.0
	if NetworkManager.host_lan() != OK:
		return _fail("lobbyhost: could not host LAN")
	if not NetworkManager.host_set_slot_count(LOBBY_SLOTS) \
			or not NetworkManager.host_set_slot_kind(LOBBY_NPC_SLOT, LobbyRoster.Kind.NPC) \
			or not NetworkManager.host_set_archetype(LOBBY_NPC_SLOT, LOBBY_NPC_ARCHETYPE) \
			or NetworkManager.joinable_slots() != LOBBY_HUMANS - 1:
		return _fail("lobbyhost: could not open a %d-slot lobby with an NPC" % LOBBY_SLOTS)
	print("AUTOTEST: hosting %d slots (one NPC), waiting for %d peers..." % [LOBBY_SLOTS, LOBBY_HUMANS - 1])
	var roster := NetworkManager.roster
	if not await _wait_for(func() -> bool: return roster.can_start(), 60.0):
		return _fail("lobbyhost: the lobby never filled: %s" % roster.pack())
	await _sleep(1.0)
	if roster.count_kind(LobbyRoster.Kind.HUMAN) != LOBBY_HUMANS or roster.count_kind(LobbyRoster.Kind.NPC) != 1 \
			or roster.local_slot() != 0:
		return _fail("lobbyhost: bad roster: %s" % roster.pack())
	if not _lobby_room_ok("lobbyhost"):
		return
	# Each joiner was announced to the host, and the one that filled the lobby again with the
	# "everyone is here" line.
	if _joined_count(heard) < LOBBY_HUMANS - 1 or _heard_count(heard, tr("MSG_LOBBY_READY")) != 1 \
			or _heard_count(heard, tr("MSG_LOBBY_JOINED") % roster.slots[2]["name"]) < 1:
		return _fail("lobbyhost: the host should hear each of the %d joiners announced (%s)" % [LOBBY_HUMANS - 1, heard])
	print("AUTOTEST: lobby full (%s, %s), avatars on their ring points" % [
			roster.slots[1]["name"], roster.slots[2]["name"]])
	if not await _lobby_voice_round("lobbyhost", "in the waiting room", true, [1, 2]):
		return
	if NetworkManager.start_refusal() != "" or not NetworkManager.host_start():
		return _fail("lobbyhost: host_start() refused three humans and an NPC (%s)" % NetworkManager.start_refusal())
	# Before the bell: the Sheriff still stands on its ring point.
	if not _lobby_npc_slot_ok(LOBBY_NPC_SLOT, "lobbyhost"):
		return
	if not await _wait_for_state(DuelManager.State.DRAW, 30.0):
		return _fail("lobbyhost: the duel never reached DRAW (holster relay?)")
	var duel := GameManager.duel
	if duel.snapshot == null or duel.snapshot.slots.size() != LOBBY_SLOTS or GameManager.local_actor_id() != 0 \
			or GameManager.avatars.size() != LOBBY_HUMANS - 1 or duel.live_slots() != [0, 1, 2, 3]:
		return _fail("lobbyhost: the duel did not start on a 4-slot snapshot")
	if not ReplayBuffer.is_recording() or ReplayBuffer.actor_count() != LOBBY_SLOTS:
		return _fail("lobbyhost: a 4-slot duel should record a 4-actor clip")
	var result := _arm_duel_listener()
	var npc := GameManager.actor_node(LOBBY_NPC_SLOT) as DuelistAI
	if npc.state != DuelistAI.AIState.REACTING or not npc._is_rival(npc._target):
		return _fail("lobbyhost: the NPC did not react to the bell with a live rival")
	# It draws now and its draw never completes: the only shot it fires is the one below.
	npc._timer = 0.0
	if not await _wait_for(func() -> bool: return npc.state == DuelistAI.AIState.DRAWING, 2.0):
		return _fail("lobbyhost: the NPC never drew (state %d)" % npc.state)
	_lobby_park(npc)
	await _sleep(LOBBY_NPC_GAP)
	if not npc.revolver.try_fire(true, Vector3.UP):
		return _fail("lobbyhost: the NPC's revolver did not fire")
	await _sleep(LOBBY_NPC_GAP)
	print("AUTOTEST: DRAW with four duelists, the NPC drew and fired, host shoots it")
	_lobby_shoot_npc(npc, npc.head_hitbox, 0)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 1, 2] \
			or GameManager.hud.message_label.text != _down_text(LOBBY_NPC_SLOT, 0, 3):
		return _fail("lobbyhost: the NPC's death gave state %d, live %s, message '%s'" % [
				duel.state, duel.live_slots(), GameManager.hud.message_label.text])
	if npc.is_alive() or npc.killed_by != 0 or not npc.corpse_body().has_corpse() or GameManager.avatars.has(LOBBY_NPC_SLOT) \
			or ReplayBuffer.death_time_of(LOBBY_NPC_SLOT) < 0.0 or KillCam.is_playing or DeathCam.phase != DeathCam.Phase.IDLE:
		return _fail("lobbyhost: the NPC should fall once, credited to the host, with no kill cam")
	if PlayerSettings.gore_enabled and npc.corpse_body().chunk_count() != 1:
		return _fail("lobbyhost: one hit cut %d holes in the host's NPC" % npc.corpse_body().chunk_count())
	print("AUTOTEST: NPC down mid-duel (3 left), host shoots slot 1")
	await _sleep(LOBBY_NPC_GAP)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW:
		return _fail("lobbyhost: the duel ended with three duelists standing")
	var first: RemoteAvatar = GameManager.avatars[1]
	var second: RemoteAvatar = GameManager.avatars[2]
	if first.is_dead() or first.torso_hitbox.is_corpse():
		return _fail("lobbyhost: a live avatar reads as a corpse")
	_lobby_shoot_head(first)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.slot_alive(1) \
			or duel.live_slots() != [0, 2] or GameManager.hud.message_label.text != _down_text(1, 0, 2):
		return _fail("lobbyhost: the first kill gave state %d, live %s, message '%s'" % [
				duel.state, duel.live_slots(), GameManager.hud.message_label.text])
	if KillCam.is_playing or DeathCam.is_active():
		return _fail("lobbyhost: a mid-duel death started a kill cam")
	if ReplayBuffer.death_time_of(1) < 0.0 or DeathCam.phase != DeathCam.Phase.IDLE or DeathCam.blocks_combat():
		return _fail("lobbyhost: the mid-duel death has no clip time, or it took the living host's view")
	if not first.is_dead() or not first._dummy.has_corpse() or first.gun.get_parent() == first.holster:
		return _fail("lobbyhost: the shot avatar did not collapse and drop its gun")
	for hitbox: Hitbox in [first.head_hitbox, first.torso_hitbox, first.arm_hitbox_l, first.arm_hitbox_r,
			first.leg_hitbox_l, first.leg_hitbox_r]:
		if not hitbox.is_corpse():
			return _fail("lobbyhost: a dead avatar's %s volume is not a corpse" % hitbox.region)
	if not await _bullet_passes_avatar(first, "lobbyhost"):
		return
	# A second hit on the dead slot changes nothing.
	_lobby_shoot_head(first)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 2]:
		return _fail("lobbyhost: a hit on a dead slot was not ignored")
	print("AUTOTEST: slot 1 down mid-duel (2 left, collapsed, bullets pass through)")
	# The living talk to the living and the dead one gets nothing.
	if not await _lobby_voice_round("lobbyhost", "with slot 1 dead", true, [2]):
		return
	# The round is part of the gap: slot 1's fall has to stay inside the clip of the final kill.
	await _sleep(LOBBY_KILL_GAP - 1.0)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW:
		return _fail("lobbyhost: the duel ended with two duelists standing")
	_lobby_shoot_head(second)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true or result[1] != "MSG_REASON_LAST_STANDING":
		return _fail("lobbyhost: the host did not win as the last one standing (%s)" % [result])
	if not second.is_dead() or not second._dummy.has_corpse() or duel.state != DuelManager.State.RESOLUTION:
		return _fail("lobbyhost: the last avatar did not collapse")
	if roster.slots[0]["wins"] != 1 or roster.slots[1]["wins"] != 0 or roster.slots[2]["wins"] != 0 \
			or roster.slots[LOBBY_NPC_SLOT]["wins"] != 0:
		return _fail("lobbyhost: win tally %s" % roster.pack())
	if not DeathCam.is_active() or not KillCam.is_playing or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != 2:
		return _fail("lobbyhost: a 4-slot finish should start the kill cam and the death cam (killer %d, victim %d)" % [
				ReplayBuffer.killer_id, ReplayBuffer.victim_id])
	if GameManager.hud.message_label.text != _result_text("MSG_YOU_WIN", "MSG_REASON_LAST_STANDING"):
		return _fail("lobbyhost: the winner reads '%s', not YOU WIN / Last one standing" % GameManager.hud.message_label.text)
	print("AUTOTEST: host won, win tally 1")
	if not await _lobby_final_clip_ok("lobbyhost") or not await _lobby_voice_round("lobbyhost", "after the finish", true, [1, 2]) \
			or not await _lobby_next_duel_ok("lobbyhost"):
		return
	if not await _lobby_teams_host_ok():
		return
	await _sleep(TEAMS_END + 1.0)  # let the RPCs flush and the clients finish checking before quitting
	_pass()


## Run twice against one `lobbyhost`. Each process checks what its own slot sees: the NPC
## as a proxy driven by the host's stream, then the host shooting the NPC, slot 1, and
## slot 2 in that order.
func _test_lobby_join() -> void:
	await _sleep(2.0)
	var heard := _hear_messages()
	if NetworkManager.join_lan("127.0.0.1") != OK:
		return _fail("lobbyjoin: could not start joining")
	if not await _wait_for(func() -> bool: return NetworkManager.is_active(), 30.0):
		return _fail("lobbyjoin: never connected to host")
	var in_room := func() -> bool:
		return GameManager.in_mp_lobby() and NetworkManager.roster.can_start() \
				and GameManager.avatars.size() == LOBBY_HUMANS - 1
	if not await _wait_for(in_room, 40.0):
		return _fail("lobbyjoin: never saw a full waiting room: %s, %d avatars" % [
				NetworkManager.roster.pack(), GameManager.avatars.size()])
	var roster := NetworkManager.roster
	var me := roster.local_slot()
	if (me != 1 and me != 2) or roster.slots.size() != LOBBY_SLOTS \
			or roster.count_kind(LobbyRoster.Kind.HUMAN) != LOBBY_HUMANS \
			or roster.slots[LOBBY_NPC_SLOT]["kind"] != LobbyRoster.Kind.NPC:
		return _fail("lobbyjoin: bad roster in the waiting room: %s" % roster.pack())
	if not _lobby_room_ok("lobbyjoin") or not _client_page_ok("lobbyjoin"):
		return
	# The first joiner hears the second one announced; the second walks into a lobby that is
	# already there and hears nothing.
	if _joined_count(heard) != (1 if me == 1 else 0):
		return _fail("lobbyjoin: slot %d heard %d joiners announced (%s)" % [me, _joined_count(heard), heard])
	# A joiner into a lobby that cannot start is told why (the line a failed rematch gives
	# the clients); one into a full lobby is told to wait for the host.
	var told_wait := tr("MSG_LOBBY_NOT_FULL") if me == 1 else tr("MSG_LOBBY_WAIT_HOST")
	if _heard_count(heard, told_wait) != 1:
		return _fail("lobbyjoin: slot %d should have been told '%s' on entering the room (%s)" % [me, told_wait, heard])
	print("AUTOTEST: in the waiting room on slot %d with two avatars and no NPC" % me)
	if not await _lobby_voice_round("lobbyjoin", "in the waiting room", true, [0, 3 - me]):
		return
	var result := _arm_duel_listener()
	# The tracer of the NPC's one shot, as `_npc_shot` spawned it (GameManager hears it first).
	var tracers: Array[Dictionary] = []
	NetworkManager.npc_shot_received.connect(func(slot: int, _origin: Vector3, _direction: Vector3) -> void:
		for node in get_tree().get_nodes_in_group(Bullet.GROUP):
			var bullet := node as Bullet
			if bullet.shooter == slot:
				tracers.append({"visual": not bullet.authoritative and not bullet.from_local_player,
						"exclude": bullet.exclude, "speed": bullet.speed}))
	if not await _wait_for_state(DuelManager.State.DRAW, 60.0):
		return _fail("lobbyjoin: the duel never reached DRAW")
	var duel := GameManager.duel
	var local := GameManager.local_player
	if duel.snapshot == null or duel.snapshot.local_slot() != me or GameManager.local_actor_id() != me \
			or GameManager.avatars.size() != LOBBY_SLOTS - 1 or GameManager.actor_node(me) != local \
			or not (GameManager.actor_node(0) is RemoteAvatar) or duel.live_slots() != [0, 1, 2, 3]:
		return _fail("lobbyjoin: slot %d did not get its duel actors" % me)
	var proxy := GameManager.actor_node(LOBBY_NPC_SLOT) as RemoteAvatar
	var sheriff := GameManager.archetype_at(LOBBY_NPC_ARCHETYPE)
	if proxy == null or not proxy.npc_proxy or proxy.slot != LOBBY_NPC_SLOT or proxy.is_dead() \
			or not GameManager.current_ais.is_empty() or GameManager.side_of(proxy) != LOBBY_NPC_SLOT:
		return _fail("lobbyjoin: slot %d has no live proxy for the NPC slot" % me)
	if duel.snapshot.slots[LOBBY_NPC_SLOT]["archetype"] != LOBBY_NPC_ARCHETYPE \
			or duel.slot_name(LOBBY_NPC_SLOT) != sheriff.display_name:
		return _fail("lobbyjoin: the snapshot's NPC is not the host's pick ('%s')" % duel.slot_name(LOBBY_NPC_SLOT))
	if VoiceChat.bound_peers().size() != LOBBY_HUMANS - 1 or not _voice_binds_ok("lobbyjoin"):
		return _fail("lobbyjoin: voice should be bound to each human's avatar, never the NPC proxy")
	# Everything the proxy shows comes from the host's stream: the Sheriff strafes off its
	# ring point, holds its drawn gun, and fires once.
	var ring: Vector3 = GameManager.current_scenario.get_duel_spawns(LOBBY_SLOTS)[LOBBY_NPC_SLOT].origin
	var strayed := func() -> float:
		var head := proxy.head.global_position
		return Vector2(head.x - ring.x, head.z - ring.z).length()
	var shown := func() -> bool:
		return proxy._has_pose and proxy._gun_drawn and not proxy._gun_free \
				and proxy.gun.get_parent() == proxy.right_hand and strayed.call() > 0.1 and not tracers.is_empty()
	if not await _wait_for(shown, 15.0):
		return _fail("lobbyjoin: the NPC proxy did not follow the host (posed %s, gun drawn %s, head moved %.2f m, tracers %d)" % [
				proxy._has_pose, proxy._gun_drawn, strayed.call(), tracers.size()])
	var tracer := tracers[0]
	if tracers.size() != 1 or not tracer["visual"] or tracer["exclude"] != proxy.hitbox_rids() \
			or not is_equal_approx(tracer["speed"], sheriff.bullet_speed):
		return _fail("lobbyjoin: the NPC's shot should be one visual tracer that skips its own proxy")
	print("AUTOTEST: slot %d sees the NPC proxy move, draw, and fire" % me)
	if not await _wait_for(func() -> bool: return not duel.slot_alive(LOBBY_NPC_SLOT), 30.0):
		return _fail("lobbyjoin: never saw the NPC go down")
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 1, 2] \
			or GameManager.hud.message_label.text != _down_text(LOBBY_NPC_SLOT, 0, 3):
		return _fail("lobbyjoin: the NPC's death gave state %d, live %s, message '%s'" % [
				duel.state, duel.live_slots(), GameManager.hud.message_label.text])
	if KillCam.is_playing or DeathCam.is_active() or DeathCam.is_spectating() or not local.alive:
		return _fail("lobbyjoin: the NPC's death started a kill cam or took a living duelist's view")
	if not proxy.is_dead() or not proxy._dummy.has_corpse() or not proxy.torso_hitbox.is_corpse() \
			or proxy.is_ancestor_of(proxy.gun) or not DeathCam.blocks_remote_pose(LOBBY_NPC_SLOT):
		return _fail("lobbyjoin: the NPC proxy did not collapse into a corpse and drop its gun")
	if PlayerSettings.gore_enabled and (not _has_head_cut(proxy._dummy) or proxy._dummy.chunk_count() != 1):
		return _fail("lobbyjoin: the NPC proxy has no hole on the head (%d holes)" % proxy._dummy.chunk_count())
	print("AUTOTEST: slot %d saw the NPC proxy fall (3 left)" % me)
	if not await _wait_for(func() -> bool: return not duel.slot_alive(1), 30.0):
		return _fail("lobbyjoin: never saw slot 1 go down")
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 2] \
			or GameManager.hud.message_label.text != _down_text(1, 0, 2):
		return _fail("lobbyjoin: slot 1's death gave state %d, live %s, message '%s'" % [
				duel.state, duel.live_slots(), GameManager.hud.message_label.text])
	if KillCam.is_playing or DeathCam.is_active():
		return _fail("lobbyjoin: a mid-duel death started a kill cam")
	if me == 1:
		if local.alive or not local.corpse_body().has_corpse() or local.revolver.held \
				or not local.head_hitbox.is_corpse():
			return _fail("lobbyjoin: the shot player did not collapse and drop the gun")
		if not await _lobby_held_ok(true):
			return
		print("AUTOTEST: slot 1 died mid-duel and spectates slot %d" % DeathCam.spectate_target())
	else:
		var fallen: RemoteAvatar = GameManager.avatars[1]
		if not fallen.is_dead() or not fallen._dummy.has_corpse() or not fallen.torso_hitbox.is_corpse():
			return _fail("lobbyjoin: slot 1's avatar did not collapse into a corpse")
		if not local.alive or DeathCam.blocks_combat() or DeathCam.is_spectating():
			return _fail("lobbyjoin: a living duelist is held")
		# The same input the held check blocks: here it must move the player.
		var from := local.rig.global_position
		Input.action_press("move_forward")
		await _sleep(0.3)
		Input.action_release("move_forward")
		if local.rig.global_position.distance_to(from) < 0.05:
			return _fail("lobbyjoin: a living duelist could not walk")
		print("AUTOTEST: slot 2 saw slot 1 fall and fights on")
	# Slot 1 is dead and alone: it sends nothing and hears nothing. The two living hear each other.
	var hears: Array[int] = []
	if me == 2:
		hears.append(0)
	if not await _lobby_voice_round("lobbyjoin", "with slot 1 dead", me == 2, hears):
		return
	await _await_result(result, 30.0)
	if result.is_empty() or result[0] != false or result[1] != "MSG_REASON_LAST_STANDING":
		return _fail("lobbyjoin: expected a loss to the last one standing (%s)" % [result])
	var told := "%s\n%s" % [_result_text("MSG_YOU_LOSE", "MSG_REASON_LAST_STANDING"), tr("MSG_LOBBY_WINNER") % duel.slot_name(0)]
	if GameManager.hud.message_label.text != told:
		return _fail("lobbyjoin: the loser reads '%s', not '%s'" % [GameManager.hud.message_label.text, told])
	if duel.live_slots() != [0] or not DeathCam.is_active() or DeathCam.is_spectating() \
			or GameManager.hud.spectate_tag.visible:
		return _fail("lobbyjoin: after the finish live %s, death cam phase %d" % [duel.live_slots(), DeathCam.phase])
	if me == 2:
		if local.alive or not local.corpse_body().has_corpse() or local.revolver.held:
			return _fail("lobbyjoin: the last one shot did not collapse and drop the gun")
		if not DeathCam._local_is_victim():
			return _fail("lobbyjoin: the last one shot is not the death cam's victim")
		if not await _lobby_held_ok(false):
			return
	elif not (GameManager.avatars[2] as RemoteAvatar).is_dead():
		return _fail("lobbyjoin: slot 2's avatar did not die with the finish")
	elif DeathCam._local_is_victim() or not DeathCam._local_is_down() or not DeathCam.blocks_combat():
		return _fail("lobbyjoin: the first one down should watch the final victim's corpse, still held")
	if not await _wait_for(func() -> bool: return roster.slots[0]["wins"] == 1, 5.0) \
			or roster.slots[1]["wins"] != 0 or roster.slots[2]["wins"] != 0 \
			or roster.slots[LOBBY_NPC_SLOT]["wins"] != 0:
		return _fail("lobbyjoin: win tally %s" % roster.pack())
	print("AUTOTEST: slot %d lost (%s), host tally 1" % [me, result[1]])
	if not await _lobby_final_clip_ok("lobbyjoin") or not await _lobby_voice_round("lobbyjoin", "after the finish", true, [0, 3 - me]) \
			or not await _lobby_next_duel_ok("lobbyjoin"):
		return
	if not await _lobby_teams_join_ok():
		return
	_pass()


## Seconds a peer waits before its voice burst, for the others to have seen the same state.
const VOICE_SETTLE := 0.2
## Synthetic packets in a burst, `VOICE_GAP` apart. A listener must take at least `VOICE_MIN_HEARD`.
## A whole round stays short: it runs between a death and the next one, and both must fit in the
## replay clip.
const VOICE_BURST := 8
const VOICE_GAP := 0.04
const VOICE_MIN_HEARD := 2
## Seconds a peer keeps counting after its own burst: the slowest peer's burst lands in it.
const VOICE_LISTEN := 1.0
## Packets taken per sender up to the last voice round, so a round reads its own delta.
var _voice_base := {}


## One moment of voice for `lobbyhost` / `lobbyjoin`. After a settle this peer sends a burst of
## synthetic packets through the microphone's send path (`sends`: whether anyone is eligible to
## get them; a dead duelist with no dead company sends none), then listens. It must have taken
## at least VOICE_MIN_HEARD from each slot in `heard` since the last round and none from any
## other human; this also proves a client's packet reaches the other client through the host.
func _lobby_voice_round(tag: String, moment: String, sends: bool, heard: Array[int]) -> bool:
	var roster := NetworkManager.roster
	var me := roster.local_slot()
	print("AUTOTEST: slot %d voice %s: sending to %s" % [me, moment, VoiceChat.voice_recipients()])
	await _sleep(VOICE_SETTLE)
	var pcm := PackedByteArray()
	pcm.resize(VoiceChat.FRAME_SAMPLES * 2)
	var sent := 0
	for _i in VOICE_BURST:
		if VoiceChat.send_test_packet(pcm):
			sent += 1
		await _sleep(VOICE_GAP)
	if sent != (VOICE_BURST if sends else 0):
		_fail("%s: slot %d sent %d of %d voice packets %s (recipients %s)" % [
				tag, me, sent, VOICE_BURST, moment, VoiceChat.voice_recipients()])
		return false
	await _sleep(VOICE_LISTEN)
	var report := PackedStringArray()
	for slot in roster.slots.size():
		if slot == me or roster.slots[slot]["kind"] != LobbyRoster.Kind.HUMAN:
			continue
		var peer_id := int(roster.slots[slot]["peer_id"])
		var got := int(VoiceChat.packets_accepted.get(peer_id, 0)) - int(_voice_base.get(peer_id, 0))
		if (heard.has(slot) and got < VOICE_MIN_HEARD) or (not heard.has(slot) and got != 0):
			_fail("%s: slot %d took %d voice packets from slot %d %s, expected %s" % [
					tag, me, got, slot, moment, "at least %d" % VOICE_MIN_HEARD if heard.has(slot) else "none"])
			return false
		report.append("slot %d: %d" % [slot, got])
	_voice_base = VoiceChat.packets_accepted.duplicate()
	print("AUTOTEST: slot %d voice %s ok (sent %d; took %s)" % [me, moment, sent, ", ".join(report)])
	return true


## The final kill of the 3-human + NPC duel as this peer sees it: a sealed 4-actor clip
## crediting slot 0 over slot 2, with the NPC's and slot 1's earlier deaths inside it; the
## replay everyone watches, in which the NPC (the host's own, or a client's proxy) and
## slot 1 stand and fall again at their own times; slot 1's trigger ending it on every
## peer; and each view ending where its player belongs.
func _lobby_final_clip_ok(tag: String) -> bool:
	var me := GameManager.local_actor_id()
	var local := GameManager.local_player
	if not await _wait_for(func() -> bool: return ReplayBuffer.is_sealed, 15.0):
		_fail("%s: slot %d never got a sealed clip" % [tag, me])
		return false
	var first_death := ReplayBuffer.death_time_of(1)
	var npc_death := ReplayBuffer.death_time_of(LOBBY_NPC_SLOT)
	if not ReplayBuffer.ready_to_play() or ReplayBuffer.actor_count() != LOBBY_SLOTS \
			or ReplayBuffer.sample_at(ReplayBuffer.clip_begin()).size() != LOBBY_SLOTS \
			or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != 2:
		_fail("%s: slot %d's clip has %d actors, killer %d, victim %d" % [tag, me,
				ReplayBuffer.sample_at(ReplayBuffer.clip_begin()).size(), ReplayBuffer.killer_id, ReplayBuffer.victim_id])
		return false
	if first_death < ReplayBuffer.clip_begin() or first_death >= ReplayBuffer.death_time \
			or ReplayBuffer.death_time_of(0) >= 0.0 \
			or absf(ReplayBuffer.death_time_of(2) - ReplayBuffer.death_time) > 0.001:
		_fail("%s: slot %d's clip death times are off (slot 1 at %.2f, final at %.2f, clip from %.2f)" % [
				tag, me, first_death, ReplayBuffer.death_time, ReplayBuffer.clip_begin()])
		return false
	if npc_death < ReplayBuffer.clip_begin() or npc_death >= first_death:
		_fail("%s: slot %d's clip has the NPC's death at %.2f (slot 1 at %.2f, clip from %.2f)" % [
				tag, me, npc_death, first_death, ReplayBuffer.clip_begin()])
		return false
	print("AUTOTEST: slot %d has the sealed 4-actor clip (the NPC fell at %.2f, slot 1 at %.2f, slot 2 at %.2f)" % [
			me, npc_death, first_death, ReplayBuffer.death_time])
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 20.0):
		_fail("%s: slot %d never watched the replay (phase %d)" % [tag, me, DeathCam.phase])
		return false
	if not DeathCam.blocks_combat() or not is_instance_valid(DeathCam._camera) or not GameManager.hud.replay_tag.visible \
			or not DeathCam._retraced.has(1) or not DeathCam._retraced.has(2) or DeathCam._retraced.has(0) \
			or not DeathCam._retraced.has(LOBBY_NPC_SLOT):
		_fail("%s: slot %d's replay is not the shared one (blocked %s, corpses %s)" % [
				tag, me, DeathCam.blocks_combat(), DeathCam._retraced])
		return false
	var early := _corpse_of(1)
	var npc_corpse := _corpse_of(LOBBY_NPC_SLOT)
	if early == null or (first_death - DeathCam._play_t > 0.2 and early.corpse_state() != BodyRagdoll.State.RETRACE):
		_fail("%s: slot 1's corpse does not stand up for slot %d's replay" % [tag, me])
		return false
	if npc_corpse == null or (npc_death - DeathCam._play_t > 0.2 and npc_corpse.corpse_state() != BodyRagdoll.State.RETRACE):
		_fail("%s: the NPC's corpse does not stand up for slot %d's replay" % [tag, me])
		return false
	var fell := func() -> bool:
		return DeathCam._play_t >= first_death + 0.3 or DeathCam.phase != DeathCam.Phase.PLAYBACK
	if not await _wait_for(fell, 20.0) or DeathCam.phase != DeathCam.Phase.PLAYBACK \
			or early.corpse_state() != BodyRagdoll.State.TRACK:
		_fail("%s: slot 1's fall does not replay at its own time for slot %d (phase %d, state %d)" % [
				tag, me, DeathCam.phase, early.corpse_state()])
		return false
	# The NPC fell before slot 1, so its fall is playing too by now.
	if npc_corpse.corpse_state() != BodyRagdoll.State.TRACK:
		_fail("%s: the NPC's fall does not replay for slot %d (state %d)" % [tag, me, npc_corpse.corpse_state()])
		return false
	if me == 1:
		# Anyone's trigger skips the replay for all: the first one down pulls it.
		await _wait_for(func() -> bool: return DeathCam._play_t >= first_death + 1.0, 10.0)
		local._on_trigger_changed(&"right_hand", true)
		local._on_trigger_changed(&"right_hand", false)
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.TRAILING, 30.0):
		_fail("%s: slot %d never reached the trailing orbit (phase %d)" % [tag, me, DeathCam.phase])
		return false
	if DeathCam._play_t >= ReplayBuffer.death_time:
		_fail("%s: slot 1's skip did not end slot %d's replay (played to %.2f of %.2f)" % [
				tag, me, DeathCam._play_t, ReplayBuffer.clip_end()])
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var down := not local.alive
	if DeathCam.blocks_combat() != down or is_instance_valid(DeathCam._camera) != down or GameManager.hud.replay_tag.visible:
		_fail("%s: slot %d's view after the replay is wrong (alive %s, held %s, orbit camera %s)" % [
				tag, me, local.alive, DeathCam.blocks_combat(), is_instance_valid(DeathCam._camera)])
		return false
	for avatar: RemoteAvatar in GameManager.avatars.values():
		if avatar.replay_locked != avatar.is_dead():
			_fail("%s: slot %d sees slot %d's body %s after the replay" % [
					tag, me, avatar.slot, "still held" if avatar.replay_locked else "released while dead"])
			return false
	print("AUTOTEST: slot %d watched the replay and reached the trailing orbit on the skip" % me)
	return true


## The auto-rematch after the replay starts clean on this peer: no death cam, nobody dead,
## fresh bodies, and only the host recording.
func _lobby_next_duel_ok(tag: String) -> bool:
	var duel := GameManager.duel
	var local := GameManager.local_player
	var hud := GameManager.hud
	var me := GameManager.local_actor_id()
	var fresh := func() -> bool:
		return duel.state == DuelManager.State.STANDOFF and duel.live_slots() == [0, 1, 2, 3]
	if not await _wait_for(fresh, 20.0):
		_fail("%s: slot %d never saw the rematch (state %d, live %s)" % [tag, me, duel.state, duel.live_slots()])
		return false
	if DeathCam.phase != DeathCam.Phase.IDLE or DeathCam.blocks_combat() or is_instance_valid(DeathCam._camera) \
			or ReplayBuffer.is_sealed or ReplayBuffer.death_time >= 0.0 or not ReplayBuffer.death_times.is_empty() \
			or hud.spectate_tag.visible or hud.replay_tag.visible:
		_fail("%s: the rematch did not clear slot %d's death cam (phase %d)" % [tag, me, DeathCam.phase])
		return false
	# The NPC is a fresh `DuelistAI` on the host and a fresh proxy on a client.
	var bodies := LOBBY_HUMANS - 1 if NetworkManager.is_host() else LOBBY_SLOTS - 1
	if not local.alive or local.corpse_body().has_corpse() or GameManager.avatars.size() != bodies \
			or ReplayBuffer.is_recording() != NetworkManager.is_host():
		_fail("%s: slot %d did not start the rematch alive on a fresh clip" % [tag, me])
		return false
	for avatar: RemoteAvatar in GameManager.avatars.values():
		if avatar.is_dead() or avatar.replay_locked or avatar._dummy.has_corpse():
			_fail("%s: slot %d sees slot %d's body still dead or held in the rematch" % [tag, me, avatar.slot])
			return false
	var npc_body := _corpse_of(LOBBY_NPC_SLOT)
	if npc_body == null or npc_body.has_corpse() or (GameManager.actor_node(LOBBY_NPC_SLOT) is DuelistAI) != NetworkManager.is_host():
		_fail("%s: slot %d has no fresh NPC in the rematch" % [tag, me])
		return false
	print("AUTOTEST: slot %d is in a clean rematch" % me)
	return true


## The Teams round of `lobbyhost` / `lobbyjoin`, after the free-for-all one. Every step
## hangs on a roster state all three peers see, so it runs the same whichever joiner took
## slot 1. Sides per slot (the host, slot 1, slot 2, the NPC):
## the default 2v2, as Teams is switched on.
const TEAMS_DEFAULT_SIDES: Array[int] = [0, 1, 0, 1]
## After slot 1's pick: the NPC alone against the three humans, so first on the ring.
const TEAMS_SOLO_SIDES: Array[int] = [0, 0, 0, 1]
const TEAMS_SOLO_ORDER: Array[int] = [3, 0, 1, 2]
## After the host's pick and its call for the NPC: the host alone, until slot 2 joins it.
const TEAMS_HOST_SIDES: Array[int] = [1, 0, 0, 0]
## After slot 2's pick: the host and slot 2 against slot 1 and the NPC, slot 1 first.
const TEAMS_PAIR_SIDES: Array[int] = [1, 0, 1, 0]
const TEAMS_PAIR_ORDER: Array[int] = [1, 3, 0, 2]
## Seconds a peer lets pass after the roster state it acts on, for the others to check it.
const TEAMS_STEP := 1.5
## Seconds the host leaves the 3v1 in its standoff: over before any bell (3 s at the least).
const TEAMS_STANDOFF := 2.0
## Seconds each peer stays after the last result, so no leaver's slot resets a tally a
## slower peer is still reading.
const TEAMS_END := 2.0
## The session tally after both rounds: the host won the free-for-all, then the 2v2 with slot 2.
const TEAMS_WINS: Array[int] = [2, 0, 1, 0]


## The host's side of the Teams round. It reopens the waiting room in Teams, starts a 3v1
## on slot 1's pick (the NPC alone on PlayerSpawn) and ends it in the standoff, makes its
## own pick and the NPC's, and starts the 2v2 on slot 2's. There the NPC, parked, has only
## the host and slot 2 to pick from; the host shoots slot 1 (the duel goes on with one of
## that side left), then its own teammate slot 2 (friendly fire; still on), then the NPC:
## its side wins, itself alive and slot 2 dead.
func _lobby_teams_host_ok() -> bool:
	var net := NetworkManager
	var roster := net.roster
	var duel := GameManager.duel
	var local := GameManager.local_player
	var hud := GameManager.hud
	await _sleep(TEAMS_STEP)
	if not net.host_back_to_lobby() or not net.host_set_mode(LobbyRoster.Mode.TEAMS) \
			or _roster_sides(roster) != TEAMS_DEFAULT_SIDES or net.start_refusal() != "":
		_fail("lobbyhost teams: could not reopen the waiting room in Teams: %s" % roster.pack())
		return false
	if not _lobby_room_ok("lobbyhost teams"):
		return false
	print("AUTOTEST: waiting room in Teams, side tints on, waiting for slot 1's pick")
	if not await _wait_for(func() -> bool: return _roster_sides(roster) == TEAMS_SOLO_SIDES, 20.0):
		_fail("lobbyhost teams: slot 1's side pick never arrived: %s" % [_roster_sides(roster)])
		return false
	if not _lobby_room_ok("lobbyhost teams, slot 1 picked"):
		return false
	await _sleep(TEAMS_STEP)
	if net.start_refusal() != "" or not net.host_start() or not duel.is_team_duel():
		_fail("lobbyhost teams: host_start() refused the 3v1 (%s)" % net.start_refusal())
		return false
	if not _lobby_points_ok("lobbyhost 3v1", TEAMS_SOLO_ORDER) or not _lobby_tints_ok("lobbyhost 3v1", LOBBY_SLOTS) \
			or not _lobby_npc_slot_ok(LOBBY_NPC_SLOT, "lobbyhost 3v1") or not await _lobby_heads_ok("lobbyhost 3v1"):
		return false
	print("AUTOTEST: 3v1 started, the NPC on PlayerSpawn, both joiners where the host put them")
	await _sleep(TEAMS_STANDOFF)
	if not net.host_back_to_lobby() or not _lobby_room_ok("lobbyhost teams, after the 3v1"):
		return false
	if not _press_own_side(1, "lobbyhost teams") or not net.host_set_npc_side(LOBBY_NPC_SLOT, 0) or net.host_set_npc_side(1, 1) or _roster_sides(roster) != TEAMS_HOST_SIDES:
		_fail("lobbyhost teams: the host's pick and the NPC's did not land: %s" % [_roster_sides(roster)])
		return false
	if not await _wait_for(func() -> bool: return _roster_sides(roster) == TEAMS_PAIR_SIDES, 20.0):
		_fail("lobbyhost teams: slot 2's side pick never arrived: %s" % [_roster_sides(roster)])
		return false
	if not _lobby_room_ok("lobbyhost teams, slot 2 picked"):
		return false
	await _sleep(TEAMS_STEP)
	if net.start_refusal() != "" or not net.host_start() or not duel.is_team_duel():
		_fail("lobbyhost teams: host_start() refused the 2v2 (%s)" % net.start_refusal())
		return false
	if not _lobby_points_ok("lobbyhost 2v2", TEAMS_PAIR_ORDER) or not _lobby_tints_ok("lobbyhost 2v2", LOBBY_SLOTS) \
			or not _lobby_npc_slot_ok(LOBBY_NPC_SLOT, "lobbyhost 2v2") or not await _lobby_heads_ok("lobbyhost 2v2"):
		return false
	if not await _wait_for_state(DuelManager.State.DRAW, 30.0):
		_fail("lobbyhost teams: the 2v2 never reached DRAW (state %d)" % duel.state)
		return false
	var result := _arm_duel_listener()
	var npc := GameManager.actor_node(LOBBY_NPC_SLOT) as DuelistAI
	var rival: RemoteAvatar = GameManager.avatars[1]
	var mate: RemoteAvatar = GameManager.avatars[2]
	if npc.state != DuelistAI.AIState.REACTING or not npc._is_rival(npc._target):
		_fail("lobbyhost teams: the NPC did not react to the bell with a live rival")
		return false
	_lobby_park(npc)
	var picked := _lobby_npc_picks(npc)
	if picked.size() != 2 or not picked.has(local) or not picked.has(mate) or GameManager.side_of(npc) != GameManager.side_of(rival) \
			or GameManager.side_of(mate) != GameManager.side_of(local):
		_fail("lobbyhost teams: the NPC should pick among the host and slot 2, never its teammate slot 1 (%d picked)" % picked.size())
		return false
	print("AUTOTEST: 2v2 at DRAW (host + slot 2 against slot 1 + the NPC), host shoots slot 1")
	await _sleep(TEAMS_STEP)
	_lobby_shoot_head(rival)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 2, 3] \
			or not _says_left(3) or not rival.is_dead():
		_fail("lobbyhost teams: slot 1's death gave state %d, live %s, message '%s'" % [
				duel.state, duel.live_slots(), hud.message_label.text])
		return false
	await _sleep(LOBBY_KILL_GAP)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW:
		_fail("lobbyhost teams: the 2v2 ended with one of each side standing")
		return false
	_lobby_shoot_head(mate)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 3] \
			or not _says_left(2) or not mate.is_dead() or not mate._dummy.has_corpse():
		_fail("lobbyhost teams: the host's bullet should kill its teammate and the duel go on (live %s, '%s')" % [
				duel.live_slots(), hud.message_label.text])
		return false
	print("AUTOTEST: slot 1 down, then the host's own teammate (friendly fire), host shoots the NPC")
	await _sleep(LOBBY_KILL_GAP)
	_lobby_shoot_npc(npc, npc.head_hitbox, 0)
	await _await_result(result, 10.0)
	if result != [true, "MSG_REASON_LAST_SIDE"] or duel.live_slots() != [0] or not local.alive \
			or hud.message_label.text != _result_text("MSG_SIDE_WON", "MSG_REASON_LAST_SIDE") \
			or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != LOBBY_NPC_SLOT:
		_fail("lobbyhost teams: the host's side should win the 2v2 (%s, '%s')" % [result, hud.message_label.text])
		return false
	if _roster_wins(roster) != TEAMS_WINS:
		_fail("lobbyhost teams: win tally %s" % [_roster_wins(roster)])
		return false
	print("AUTOTEST: host's side won the 2v2, tally %s" % [_roster_wins(roster)])
	return true


## A joiner's side of the Teams round. The waiting room turns to side colours with the mode
## and follows each pick, its own (its own-side button, pressed in this process) and the others'.
## The 3v1 has the NPC's proxy on PlayerSpawn, moved there by the host's stream. In the 2v2
## every actor stands where and in the colour the snapshot says. Slot 1, on the losing
## side, is shot first and spectates. Slot 2 lives on through that death, is then shot by
## its own teammate, and still reads the win.
func _lobby_teams_join_ok() -> bool:
	var roster := NetworkManager.roster
	var duel := GameManager.duel
	var local := GameManager.local_player
	var hud := GameManager.hud
	var me := roster.local_slot()
	var tag := "lobbyjoin teams (slot %d)" % me
	var in_teams := func() -> bool: return GameManager.in_mp_lobby() and roster.mode == LobbyRoster.Mode.TEAMS
	if not await _wait_for(in_teams, 30.0):
		_fail("%s: never saw the waiting room in Teams (duel state %d)" % [tag, duel.state])
		return false
	if _roster_sides(roster) != TEAMS_DEFAULT_SIDES or not _lobby_room_ok(tag):
		_fail("%s: Teams should open on the default sides: %s" % [tag, _roster_sides(roster)])
		return false
	print("AUTOTEST: slot %d in the Teams waiting room, bodies in side colours" % me)
	if me == 1:
		await _sleep(TEAMS_STEP)
		if not _press_own_side(0, tag):
			return false
	if not await _wait_for(func() -> bool: return _roster_sides(roster) == TEAMS_SOLO_SIDES, 20.0):
		_fail("%s: slot 1's side pick never came back from the host: %s" % [tag, _roster_sides(roster)])
		return false
	if not _corpse_of(1)._albedo.is_equal_approx(LobbyRoster.SIDE_TINTS[0]) or not _lobby_room_ok(tag + ", slot 1 picked"):
		_fail("%s: slot 1's body did not take its new side's colour" % tag)
		return false
	print("AUTOTEST: slot %d saw slot 1's pick recolour its body" % me)
	var in_solo := func() -> bool:
		return duel.snapshot != null and duel.state != DuelManager.State.IDLE and duel.snapshot.mode == LobbyRoster.Mode.TEAMS
	if not await _wait_for(in_solo, 30.0):
		_fail("%s: the 3v1 never started" % tag)
		return false
	var proxy := GameManager.actor_node(LOBBY_NPC_SLOT) as RemoteAvatar
	if _roster_sides(duel.snapshot) != TEAMS_SOLO_SIDES or not duel.is_team_duel() or proxy == null or not proxy.npc_proxy \
			or proxy.global_position.distance_to(GameManager.current_scenario.get_player_spawn().origin) > 0.05:
		_fail("%s: the 3v1 should stand the NPC's proxy on PlayerSpawn" % tag)
		return false
	if not _lobby_points_ok(tag + " 3v1", TEAMS_SOLO_ORDER) or not _lobby_tints_ok(tag + " 3v1", LOBBY_SLOTS) \
			or not await _lobby_heads_ok(tag + " 3v1"):
		return false
	print("AUTOTEST: slot %d in the 3v1: the NPC proxy on PlayerSpawn, everyone on the host's points" % me)
	var room_again := func() -> bool:
		return GameManager.in_mp_lobby() and roster.side_of(0) == TEAMS_HOST_SIDES[0] \
				and roster.side_of(LOBBY_NPC_SLOT) == TEAMS_HOST_SIDES[LOBBY_NPC_SLOT]
	if not await _wait_for(room_again, 30.0):
		_fail("%s: never saw the waiting room again with the host's picks: %s" % [tag, _roster_sides(roster)])
		return false
	if not _lobby_room_ok(tag + ", host picked"):
		return false
	if me == 2:
		await _sleep(TEAMS_STEP)
		if not _press_own_side(1, tag):
			return false
	if not await _wait_for(func() -> bool: return _roster_sides(roster) == TEAMS_PAIR_SIDES, 20.0):
		_fail("%s: slot 2's side pick never came back from the host: %s" % [tag, _roster_sides(roster)])
		return false
	if not GameManager.in_mp_lobby() or not _corpse_of(2)._albedo.is_equal_approx(LobbyRoster.SIDE_TINTS[1]) \
			or not _lobby_room_ok(tag + ", slot 2 picked"):
		_fail("%s: slot 2's body did not take its new side's colour in the waiting room" % tag)
		return false
	var result := _arm_duel_listener()
	var in_pairs := func() -> bool:
		return duel.snapshot != null and duel.state != DuelManager.State.IDLE and _roster_sides(duel.snapshot) == TEAMS_PAIR_SIDES
	if not await _wait_for(in_pairs, 30.0):
		_fail("%s: the 2v2 never started" % tag)
		return false
	if not duel.is_team_duel() or duel.snapshot.local_slot() != me or GameManager.side_of(local) != TEAMS_PAIR_SIDES[me] \
			or not _lobby_points_ok(tag + " 2v2", TEAMS_PAIR_ORDER) or not _lobby_tints_ok(tag + " 2v2", LOBBY_SLOTS) \
			or not await _lobby_heads_ok(tag + " 2v2"):
		_fail("%s: the 2v2 did not put every actor on its point in its side's colour" % tag)
		return false
	print("AUTOTEST: slot %d in the 2v2 on side %d, every actor on its point and in its colour" % [me, TEAMS_PAIR_SIDES[me]])
	if not await _wait_for_state(DuelManager.State.DRAW, 60.0) or duel.live_slots() != [0, 1, 2, 3]:
		_fail("%s: the 2v2 never reached DRAW" % tag)
		return false
	if not await _wait_for(func() -> bool: return not duel.slot_alive(1), 30.0):
		_fail("%s: never saw slot 1 go down" % tag)
		return false
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 2, 3] \
			or not _says_left(3) or KillCam.is_playing or DeathCam.is_active():
		_fail("%s: slot 1's death gave state %d, live %s, message '%s'" % [tag, duel.state, duel.live_slots(), hud.message_label.text])
		return false
	if me == 1:
		if local.alive or not local.corpse_body().has_corpse() or not await _lobby_held_ok(true):
			_fail("%s: the one shot should fall and spectate" % tag)
			return false
	elif not local.alive or DeathCam.is_spectating() or DeathCam.blocks_combat() or not (GameManager.avatars[1] as RemoteAvatar).is_dead():
		_fail("%s: the host's teammate should fight on through a death on the other side" % tag)
		return false
	print("AUTOTEST: slot %d saw slot 1 go down (3 left), slot 2 fights on" % me)
	if not await _wait_for(func() -> bool: return not duel.slot_alive(2), 30.0):
		_fail("%s: never saw slot 2 go down" % tag)
		return false
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 3] \
			or not _says_left(2) or KillCam.is_playing or DeathCam.is_active():
		_fail("%s: slot 2's death gave state %d, live %s, message '%s'" % [tag, duel.state, duel.live_slots(), hud.message_label.text])
		return false
	if me == 2:
		if local.alive or not local.corpse_body().has_corpse() or not await _lobby_held_ok(true):
			_fail("%s: shot by its own teammate, slot 2 should fall and spectate" % tag)
			return false
	elif not (GameManager.avatars[2] as RemoteAvatar).is_dead() or not DeathCam.is_spectating():
		_fail("%s: slot 2's avatar should fall while slot 1 keeps spectating" % tag)
		return false
	await _await_result(result, 30.0)
	var won := me == 2
	if result != [won, "MSG_REASON_LAST_SIDE"] or local.alive or duel.live_slots() != [0] \
			or hud.message_label.text != _result_text("MSG_SIDE_WON" if won else "MSG_SIDE_LOST", "MSG_REASON_LAST_SIDE") \
			or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != LOBBY_NPC_SLOT:
		_fail("%s: expected the host's side to win and to read '%s' (%s, '%s')" % [
				tag, "won" if won else "lost", result, hud.message_label.text])
		return false
	if not await _wait_for(func() -> bool: return _roster_wins(roster) == TEAMS_WINS, 5.0):
		_fail("%s: win tally %s" % [tag, _roster_wins(roster)])
		return false
	print("AUTOTEST: slot %d %s the 2v2 dead (%s), tally %s" % [me, "won" if won else "lost", result[1], _roster_wins(roster)])
	await _sleep(TEAMS_END)
	return true


func _corpse_of(actor_id: int) -> DummyBody:
	var node: Variant = GameManager.actor_node(actor_id)
	if is_instance_valid(node) and node.has_method("corpse_body"):
		return node.corpse_body()
	return null


## A joiner's Lobby page: one row per roster slot with the right name, and nothing the host
## alone may do: no START, BACK TO LOBBY, Kick, or picker, a waiting line, and the host's
## START refused. Opens the page and closes the menu again.
func _client_page_ok(tag: String) -> bool:
	var pause := GameManager.hud.pause_menu
	var roster := NetworkManager.roster
	var me := roster.local_slot()
	pause.open()
	pause.show_lobby()
	var panel := pause.lobby_panel
	var ok := panel.rows.size() == roster.slots.size() and not panel.start_button.visible \
			and not panel.back_to_lobby_button.visible and panel.slot_count_option.disabled \
			and panel.mode_option.disabled and panel.arena_option.disabled and not pause.restart_button.visible \
			and panel.status_label.visible and panel.status_label.text == tr("MSG_LOBBY_WAIT_HOST") \
			and panel.my_side_button.visible == (roster.mode == LobbyRoster.Mode.TEAMS)
	for row in panel.rows:
		var slot: int = row["slot"]
		var want := ""
		match int(roster.slots[slot]["kind"]):
			LobbyRoster.Kind.HUMAN:
				want = str(roster.slots[slot]["name"])
				want = tr("LOBBY_YOU") % want if slot == me else want
			LobbyRoster.Kind.NPC:
				want = GameManager.archetype_at(roster.slots[slot]["archetype"]).display_name
			_:
				want = tr("LOBBY_OPEN")
		ok = ok and row["kick"] == null and row["kind_option"] == null and row["name"].text == want \
				and (row["chip"] as ColorRect).color.is_equal_approx(roster.tint_of(slot))
	pause.close()
	if not ok or NetworkManager.host_start():
		_fail("%s: the Lobby page should be read-only, one named row per slot, with a waiting line" % tag)
		return false
	return true


## Presses the local player's own side button on its Lobby page, as a player would, and
## closes the menu again. `want` is the side the press has to move it to.
func _press_own_side(want: int, tag: String) -> bool:
	var pause := GameManager.hud.pause_menu
	var roster := NetworkManager.roster
	pause.open()
	pause.show_lobby()
	var button := pause.lobby_panel.my_side_button
	var side: int = roster.slots[roster.local_slot()]["side"]
	var ok := button.visible and 1 - side == want \
			and button.text == tr("LOBBY_MY_SIDE") % tr(LobbyPanel.SIDE_NAMES[side])
	if ok:
		button.pressed.emit()
	pause.close()
	if not ok:
		_fail("%s: the own-side button is '%s' (visible %s) with side %d, want a move to %d" % [
				tag, button.text, button.visible, side, want])
	return ok


## Every message put up from now on.
func _hear_messages() -> Array[String]:
	var heard: Array[String] = []
	GameManager.hud.message_shown.connect(func(text: String) -> void: heard.append(text))
	return heard


## How many "<name> joined the lobby." lines `heard` holds.
func _joined_count(heard: Array[String]) -> int:
	var suffix: String = tr("MSG_LOBBY_JOINED") % ""
	var count := 0
	for text in heard:
		for part in text.split("\n"):
			count += 1 if part.ends_with(suffix) else 0
	return count


## How many lines of `heard` are exactly `line`.
func _heard_count(heard: Array[String], line: String) -> int:
	var count := 0
	for text in heard:
		for part in text.split("\n"):
			count += 1 if part == line else 0
	return count


## The waiting room of a full lobby as this peer sees it: itself and one avatar per other
## human, each on its own slot's ring point (slot order in either mode) and in its roster
## colour. An NPC slot has no body until START.
func _lobby_room_ok(tag: String) -> bool:
	var roster := NetworkManager.roster
	var me := roster.local_slot()
	var spawns := GameManager.current_scenario.get_duel_spawns(roster.slots.size())
	if not GameManager.in_mp_lobby() or GameManager.avatars.size() != roster.count_kind(LobbyRoster.Kind.HUMAN) - 1 \
			or not GameManager.current_ais.is_empty():
		_fail("%s: waiting room has %d avatars (duel state %d)" % [tag, GameManager.avatars.size(), GameManager.duel.state])
		return false
	for slot in roster.slots.size():
		var node := GameManager.actor_node(slot)
		if roster.slots[slot]["kind"] == LobbyRoster.Kind.NPC:
			if node != null:
				_fail("%s: NPC slot %d has a body in the waiting room" % [tag, slot])
				return false
			continue
		if slot == me:
			if node != GameManager.local_player:
				_fail("%s: actor %d is not the local player" % [tag, slot])
				return false
		elif not (node is RemoteAvatar) or (node as RemoteAvatar).slot != slot \
				or GameManager.side_of(node) != roster.side_of(slot):
			_fail("%s: no avatar stands for slot %d" % [tag, slot])
			return false
		# The waiting room hands the ring out in slot order, whatever the sides.
		if node.global_position.distance_to(spawns[slot].origin) > 0.05:
			_fail("%s: slot %d stands %s, its ring point is %s" % [tag, slot, node.global_position, spawns[slot].origin])
			return false
		for other in slot:
			if spawns[slot].origin.distance_to(spawns[other].origin) < 1.0:
				_fail("%s: slots %d and %d share a ring point" % [tag, other, slot])
				return false
	return _lobby_tints_ok(tag, roster.count_kind(LobbyRoster.Kind.HUMAN))


## Every body this peer shows wears its roster colour: its side's in Teams, its slot's in
## free-for-all, whatever it is (the local player, an avatar, an NPC proxy, the host's own
## NPC). The duel's snapshot while one runs, else the live roster. `bodies` is how many
## must stand.
func _lobby_tints_ok(tag: String, bodies: int) -> bool:
	var roster := GameManager._mp_roster()
	var teams := roster.mode == LobbyRoster.Mode.TEAMS
	var seen := 0
	for slot in roster.slots.size():
		var body := _corpse_of(slot)
		if body == null:
			continue
		seen += 1
		var side: int = roster.slots[slot]["side"]
		var want := LobbyRoster.SIDE_TINTS[side] if teams else LobbyRoster.SLOT_TINTS[slot]
		if not body._albedo.is_equal_approx(want) or not roster.tint_of(slot).is_equal_approx(want):
			_fail("%s: slot %d's body is %s, not its %s colour %s" % [
					tag, slot, body._albedo, "side" if teams else "slot", want])
			return false
	if seen != bodies:
		_fail("%s: %d bodies stand, not %d" % [tag, seen, bodies])
		return false
	return true


## The running duel's placement as this peer sees it: every actor of the snapshot stands on
## the ring point `spawn_order()` gives its slot (PlayerSpawn first) and faces the lane
## centre, whoever it is. Teams: the smaller side comes first and each side's points are
## neighbours. `want_order`, if given, is the order the roster must produce.
func _lobby_points_ok(tag: String, want_order: Array = []) -> bool:
	var snapshot := GameManager.duel.snapshot
	var scenario := GameManager.current_scenario
	var order := snapshot.spawn_order()
	var count := order.size()
	var spawns := scenario.get_duel_spawns(count)
	var center := (scenario.get_player_spawn().origin + scenario.get_enemy_spawn().origin) * 0.5
	if (not want_order.is_empty() and order != want_order) or count != snapshot.slots.size() \
			or not spawns[0].is_equal_approx(scenario.get_player_spawn()):
		_fail("%s: the ring order is %s, not %s" % [tag, order, want_order])
		return false
	var sides: Array[int] = []
	for point in count:
		var slot := order[point]
		var node := GameManager.actor_node(slot)
		var spawn := spawns[point]
		sides.append(snapshot.side_of(slot))
		if node == null or node.global_position.distance_to(spawn.origin) > 0.05:
			_fail("%s: slot %d is not on ring point %d (%s, the point is %s)" % [
					tag, slot, point, node.global_position if node != null else Vector3.ZERO, spawn.origin])
			return false
		var lane := Vector3(center.x - spawn.origin.x, 0.0, center.z - spawn.origin.z).normalized()
		var facing: Array[Basis] = [node.global_transform.basis]
		if node == GameManager.local_player:
			facing.append(GameManager.local_player.rig.get_head_transform().basis)
		for look in facing:
			var forward := -look.z
			forward.y = 0.0
			if forward.normalized().dot(lane) < 0.98:
				_fail("%s: slot %d on ring point %d does not face the lane centre" % [tag, slot, point])
				return false
	if snapshot.mode != LobbyRoster.Mode.TEAMS:
		return true
	var switches := 0
	for point in range(1, count):
		if sides[point] != sides[point - 1]:
			switches += 1
	if switches != 1 or sides.count(sides[0]) > sides.count(sides[count - 1]):
		_fail("%s: sides along the ring are %s: teammates must be neighbours, the smaller side first" % [tag, sides])
		return false
	return true


## Each avatar's head, as its own process (a human) or the host's stream (an NPC proxy)
## puts it, is over the ring point this peer gave its slot and looks down the lane: the
## peers agree on who stands where. Before the bell only: a strafer leaves its point.
func _lobby_heads_ok(tag: String) -> bool:
	var snapshot := GameManager.duel.snapshot
	var scenario := GameManager.current_scenario
	var order := snapshot.spawn_order()
	var spawns := scenario.get_duel_spawns(order.size())
	var center := (scenario.get_player_spawn().origin + scenario.get_enemy_spawn().origin) * 0.5
	var wrong := [""]
	var settled := func() -> bool:
		for slot: int in GameManager.avatars:
			var avatar: RemoteAvatar = GameManager.avatars[slot]
			var point: Vector3 = spawns[order.find(slot)].origin
			var head := avatar.head.global_transform
			var forward := -head.basis.z
			forward.y = 0.0
			var lane := Vector3(center.x - point.x, 0.0, center.z - point.z).normalized()
			var off := Vector2(head.origin.x - point.x, head.origin.z - point.z).length()
			if not avatar._has_pose or off > 0.3 or forward.normalized().dot(lane) < 0.95:
				wrong[0] = "slot %d's head is %.2f m off ring point %d (posed %s)" % [slot, off, order.find(slot), avatar._has_pose]
				return false
		return true
	if not await _wait_for(settled, 2.0):
		_fail("%s: %s" % [tag, wrong[0]])
		return false
	return true


## A shot straight to `avatar`'s head with a hole, as a bullet would report it. `shooter`
## is the slot credited; -1 is the host's own.
func _lobby_shoot_head(avatar: RemoteAvatar, shooter := -1) -> void:
	var head := avatar._dummy.bone_global(&"Head").origin
	var shot := Vector3(0.0, 0.0, 1.0)
	var cut := avatar._dummy.cut_on_bone(avatar._dummy.bone_index(&"Head"), head, shot, CombatRules.REGION_HEAD)
	avatar.take_bullet_hit(99.0, PackedVector3Array([head - shot, head]), CombatRules.REGION_HEAD,
			false, false, shooter if shooter >= 0 else GameManager.local_actor_id(), cut)


## A duelist who is down cannot draw, fire, or walk. `spectating` (down while the duel goes
## on): the trigger moves the camera to a living duelist instead, named in the corner.
## Otherwise (the final sequence) the trigger is left alone: there it skips for everyone.
func _lobby_held_ok(spectating: bool) -> bool:
	var local := GameManager.local_player
	var duel := GameManager.duel
	if local.alive or DeathCam.is_spectating() != spectating or not DeathCam.blocks_combat() \
			or not local._combat_blocked():
		_fail("lobby: a dead duelist is not held (phase %d)" % DeathCam.phase)
		return false
	var rounds := local.revolver.rounds
	var from := local.rig.global_position
	local._on_grip_changed(&"right_hand", true)
	if spectating:
		local._on_trigger_changed(&"right_hand", true)
		local._on_trigger_changed(&"right_hand", false)
	Input.action_press("move_forward")
	await _sleep(0.3)
	Input.action_release("move_forward")
	if local.revolver.held or local.revolver.rounds != rounds or local.rig.global_position.distance_to(from) > 0.01:
		_fail("lobby: a dead duelist could still act (held %s, rounds %d -> %d, moved %.2f m)" % [
				local.revolver.held, rounds, local.revolver.rounds, local.rig.global_position.distance_to(from)])
		return false
	if not spectating:
		return true
	var target := DeathCam.spectate_target()
	if target == GameManager.local_actor_id() or not duel.slot_alive(target) or not _watching(target) \
			or not _orbit_on(DeathCam._chest(target), 0.2):
		_fail("lobby: a dead duelist is not watching a living one (target %d, label '%s')" % [
				target, GameManager.hud.spectate_tag.text])
		return false
	return true


## The spectate camera is on `slot` and the corner names it.
func _watching(slot: int) -> bool:
	var tag := GameManager.hud.spectate_tag
	return DeathCam.is_spectating() and DeathCam.spectate_target() == slot and tag.visible \
			and tag.text == tr("HUD_SPECTATING") % GameManager.duel.slot_name(slot)


## The death cam's orbit camera is the view, one orbit radius from `pivot`, looking at it.
func _orbit_on(pivot: Vector3, slack := 0.05) -> bool:
	var camera := DeathCam._camera
	if not is_instance_valid(camera) or get_viewport().get_camera_3d() != camera:
		return false
	var to_pivot := pivot - camera.global_position
	return absf(to_pivot.length() - DeathCam._radius) <= slack \
			and (-camera.global_transform.basis.z).dot(to_pivot.normalized()) > 0.99


## A bullet aimed through a dead or out avatar's chest flies on instead of stopping there.
## Visual-only, so it cannot wound whoever stands behind.
func _bullet_passes_avatar(avatar: RemoteAvatar, tag: String) -> bool:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var scenario := GameManager.current_scenario
	var chest := _hitbox_center(avatar.torso_hitbox)
	var center := (scenario.get_player_spawn().origin + scenario.get_enemy_spawn().origin) * 0.5
	var dir := Vector3(center.x - chest.x, 0.0, center.z - chest.z).normalized()
	var origin := chest - dir * 0.6
	var query := PhysicsRayQueryParameters3D.create(origin, chest + dir * 0.5, Bullet.HIT_MASK)
	query.collide_with_areas = true
	var first: Dictionary = avatar.get_world_3d().direct_space_state.intersect_ray(query)
	if first.is_empty() or not (first["collider"] is Hitbox and (first["collider"] as Hitbox).owner_entity == avatar):
		_fail("%s: the shot line does not cross the avatar (%s)" % [tag, first.get("collider")])
		return false
	var bullet := Bullet.spawn(get_tree().current_scene, origin, dir, GameManager.tuning["bullet_speed"],
			false, [], false, 0.0, [], GameManager.local_actor_id())
	# A bullet that stops on the avatar never completes a free step.
	var reach := [0.0]
	bullet.tree_exiting.connect(func() -> void: reach[0] = bullet._travelled)
	await _wait_for(func() -> bool: return not is_instance_valid(bullet) or bullet._travelled >= 2.5, 3.0)
	var travelled: float = bullet._travelled if is_instance_valid(bullet) else reach[0]
	if travelled < 0.5:
		_fail("%s: the bullet stopped on a dead avatar" % tag)
		return false
	return true


## One process, the host alone: ring spawns on every arena, then hand-made rosters whose
## other humans are peers that never connect, so the host's resolve runs without a network.
## NPC slots are the host's own `DuelistAI`s, slowed as in `multi` so the test decides
## every death.
func _test_lobby() -> void:
	await _sleep(0.5)
	var saved_speed: float = GameManager.tuning["ai_speed_mult"]
	GameManager.tuning["ai_speed_mult"] = MULTI_AI_SPEED
	# A single-player lineup line first: no lobby standoff may show it (`_lobby_start`).
	GameManager.start_free_duel(0, 0, 2)
	var local := GameManager.local_player
	if GameManager.duel._lineup_text.is_empty() or not local.corpse_body()._albedo.is_equal_approx(Player.BODY_TINT):
		return _fail("lobby: the single-player duel before hosting has no lineup line, or a tinted player")
	if NetworkManager.host_lan() != OK:
		return _fail("lobby: could not host LAN")
	var ok: bool = _lobby_replay_wire_ok() and _lobby_spawns_ok() and _lobby_room_routing_ok() \
			and await _lobby_voice_ok() and await _lobby_foul_ok() and await _lobby_leaver_ok() and await _lobby_two_slot_ok() \
			and await _lobby_sides_ok() and await _lobby_spectate_ok() and await _lobby_npcs_ok() \
			and await _lobby_teams_ok() and await _lobby_page_ok() and await _lobby_auto_open_ok() \
			and _lobby_vr_spectate_tag_ok() and _lobby_npc_gate_ok(true) and _lobby_npc_block_ok(true)
	if ok:
		var worn := local.corpse_body()._albedo
		NetworkManager.leave("autotest")
		ok = _lobby_npc_gate_ok(false) and _lobby_npc_block_ok(false)
		if ok and (not VoiceChat._senders.is_empty() or not VoiceChat.bound_peers().is_empty()):
			_fail("lobby: leaving the session should clear every sender's voice state")
			ok = false
		if ok and (worn.is_equal_approx(Player.BODY_TINT) or not local.corpse_body()._albedo.is_equal_approx(Player.BODY_TINT)):
			_fail("lobby: leaving the session should give the player's body its own colour back (%s -> %s)" % [
					worn, local.corpse_body()._albedo])
			ok = false
		ok = ok and await _lobby_session_open_ok()
	GameManager.tuning["ai_speed_mult"] = saved_speed
	if ok:
		_pass()


const LOBBY_WIRE_XFORMS: Array[String] = ["root", "head", "left", "right", "gun", "prop", "round"]


## The clip wire format for 2, 3, and 4 actors: a packed sample is `sample_floats(count)`
## long and unpacks to the same poses, samples chain inside one chunk, an actor the sample
## lacks packs blank, a chunk never outgrows today's two-actor one, and the header's death
## times come back per actor.
func _lobby_replay_wire_ok() -> bool:
	if ReplayBuffer.sample_floats(2) != 103 or ReplayBuffer.samples_per_chunk(2) != 8 \
			or ReplayBuffer.CHUNK_FLOATS != 8 * ReplayBuffer.sample_floats(2):
		_fail("lobby wire: a two-actor clip no longer packs as it did (%d floats, %d per chunk)" % [
				ReplayBuffer.sample_floats(2), ReplayBuffer.samples_per_chunk(2)])
		return false
	for count: int in [2, 3, 4]:
		var stride := ReplayBuffer.sample_floats(count)
		var per_chunk := ReplayBuffer.samples_per_chunk(count)
		if stride != 1 + ReplayBuffer.ACTOR_FLOATS * count or per_chunk < 1 or per_chunk * stride > ReplayBuffer.CHUNK_FLOATS:
			_fail("lobby wire: %d samples of %d floats do not fit a %d-float chunk (x%d)" % [
					per_chunk, stride, ReplayBuffer.CHUNK_FLOATS, count])
			return false
		# The second sample's last actor has left: a blank, not-PRESENT pose.
		var samples := [_wire_sample(0.5, count, -1), _wire_sample(0.5 + 1.0 / ReplayBuffer.HZ, count, count - 1)]
		var buf := PackedFloat32Array()
		for sample: Dictionary in samples:
			ReplayBuffer._pack_sample(buf, sample, count)
		if buf.size() != 2 * stride:
			_fail("lobby wire: two %d-actor samples packed to %d floats, not %d" % [count, buf.size(), 2 * stride])
			return false
		var offset := 0
		for sample: Dictionary in samples:
			var parsed := ReplayBuffer._unpack_sample(buf, offset, count)
			if not _wire_sample_equal(sample, parsed, count):
				_fail("lobby wire: a %d-actor sample did not survive pack -> unpack" % count)
				return false
			offset = int(parsed["next"])
		if offset != buf.size():
			_fail("lobby wire: unpacking %d actors read %d of %d floats" % [count, offset, buf.size()])
			return false
	var short := PackedFloat32Array()
	ReplayBuffer._pack_sample(short, _wire_sample(1.0, 2, -1), 4)
	var padded: Array = ReplayBuffer._unpack_sample(short, 0, 4)["actors"]
	if short.size() != ReplayBuffer.sample_floats(4) or int(padded[1]["flags"]) & ReplayBuffer.PRESENT == 0 \
			or int(padded[2]["flags"]) != 0 or int(padded[3]["flags"]) != 0:
		_fail("lobby wire: actors missing from a sample should pack blank")
		return false
	var saved := ReplayBuffer.death_times.duplicate()
	ReplayBuffer.death_times = {0: 1.5, 2: 3.25}
	var times := ReplayBuffer._pack_death_times(4)
	ReplayBuffer.death_times.clear()
	ReplayBuffer._unpack_death_times(times, 4)
	var times_ok := times == PackedFloat32Array([1.5, -1.0, 3.25, -1.0]) and ReplayBuffer.death_times.size() == 2 \
			and ReplayBuffer.death_time_of(0) == 1.5 and ReplayBuffer.death_time_of(1) == -1.0 \
			and ReplayBuffer.death_time_of(2) == 3.25 and ReplayBuffer.death_time_of(3) == -1.0
	ReplayBuffer.death_times = saved
	if not times_ok:
		_fail("lobby wire: the header death times did not round trip (%s)" % [times])
		return false
	print("AUTOTEST: lobby clip wire ok (2 / 3 / 4 actor samples, chunk budget %d floats, death times)" % ReplayBuffer.CHUNK_FLOATS)
	return true


## A sample of `count` distinct poses. `blank` (-1: none) is an actor with no body.
func _wire_sample(t: float, count: int, blank: int) -> Dictionary:
	var actors: Array = []
	for i in count:
		if i == blank:
			actors.append(ReplayBuffer._blank_pose())
			continue
		var pose := {}
		for n in LOBBY_WIRE_XFORMS.size():
			pose[LOBBY_WIRE_XFORMS[n]] = Transform3D(
					Basis(Vector3(0.3, 1.0, -0.2).normalized(), 0.4 * (n + 1) + i + t),
					Vector3(i * 4.0 + n, 1.0 + 0.1 * n, -3.0 * i + t))
		pose["flags"] = ReplayBuffer.PRESENT | NetworkManager.POSE_FLAG_GUN_DRAWN \
				| (i << NetworkManager.POSE_FLAG_CHAMBER_SHIFT)
		pose["objects"] = (i + 1) | (ReplayBuffer.PROP_PLACE_HAND << ReplayBuffer.PROP_PLACE_SHIFT) \
				| ReplayBuffer.ROUND_HELD
		actors.append(pose)
	return {"t": t, "actors": actors}


func _wire_sample_equal(sample: Dictionary, parsed: Dictionary, count: int) -> bool:
	var want: Array = sample["actors"]
	var got: Array = parsed["actors"]
	if absf(float(sample["t"]) - float(parsed["t"])) > 0.0001 or want.size() != count or got.size() != count:
		return false
	for i in count:
		var a: Dictionary = want[i]
		var b: Dictionary = got[i]
		if int(a["flags"]) != int(b["flags"]) or int(a["objects"]) != int(b["objects"]):
			return false
		for key in LOBBY_WIRE_XFORMS:
			var xa: Transform3D = a[key]
			var xb: Transform3D = b[key]
			if xa.origin.distance_to(xb.origin) > 0.001 \
					or xa.basis.get_rotation_quaternion().angle_to(xb.basis.get_rotation_quaternion()) > 0.01:
				return false
	return true


## `get_duel_spawns` on every arena: 2 is PlayerSpawn / EnemySpawn exactly, 3 and 4 add
## the EnemySpawns markers, and no two duelists share a point.
func _lobby_spawns_ok() -> bool:
	var home := GameManager.current_scenario_index
	for arena in GameManager.SCENARIOS.size():
		if not NetworkManager.host_set_scenario(arena) or GameManager.current_scenario_index != arena:
			_fail("lobby: could not move the waiting room to arena %d" % arena)
			return false
		var scenario := GameManager.current_scenario
		for count in [2, 3, 4]:
			var spawns := scenario.get_duel_spawns(count)
			if spawns.size() != count or not spawns[0].is_equal_approx(scenario.get_player_spawn()) \
					or spawns.slice(1) != scenario.get_enemy_spawns(count - 1):
				_fail("lobby: arena %d get_duel_spawns(%d) is not PlayerSpawn + get_enemy_spawns" % [arena, count])
				return false
			if count == 2 and not spawns[1].is_equal_approx(scenario.get_enemy_spawn()):
				_fail("lobby: arena %d puts the second duelist off EnemySpawn" % arena)
				return false
			for a in count:
				for b in a:
					if spawns[a].origin.distance_to(spawns[b].origin) < MULTI_MIN_SPACING:
						_fail("lobby: arena %d x%d points %d and %d are %.2f m apart" % [
								arena, count, b, a, spawns[a].origin.distance_to(spawns[b].origin)])
						return false
	NetworkManager.host_set_scenario(home)
	print("AUTOTEST: lobby ring spawns ok (2 / 3 / 4 on every arena)")
	return true


## Fills the open slots of the live roster with humans that never connect, as the
## handshake would, and syncs. Nothing is sent: no peer is verified. `npcs` maps a slot to
## an archetype (an ARCHETYPES index, or LobbyRoster.ARCHETYPE_MIXED): those are NPC slots
## instead, set through the host API. An NPC slot has no body in the waiting room.
func _lobby_fill(count: int, npcs := {}) -> bool:
	var net := NetworkManager
	net.roster.slots[0]["wins"] = 0
	for slot in range(1, net.roster.slots.size()):
		net.roster.vacate_peer(net.roster.slots[slot]["peer_id"], false)
		net.host_set_slot_kind(slot, LobbyRoster.Kind.OPEN)
	if not net.host_set_mode(LobbyRoster.Mode.FFA) or not net.host_set_slot_count(count):
		_fail("lobby: could not size the roster to %d" % count)
		return false
	for slot in range(1, count):
		if not npcs.has(slot):
			net.roster.assign_peer(LOBBY_FAKE_PEERS[slot - 1], LOBBY_FAKE_NAMES[slot - 1])
		elif not net.host_set_slot_kind(slot, LobbyRoster.Kind.NPC) or not net.host_set_archetype(slot, npcs[slot]):
			_fail("lobby: could not make slot %d an NPC" % slot)
			return false
	net._sync_roster()
	var humans := count - 1 - npcs.size()
	if not net.host_back_to_lobby() or not GameManager.in_mp_lobby() or GameManager.avatars.size() != humans \
			or not GameManager.current_ais.is_empty():
		_fail("lobby: no waiting room with %d avatars and no NPCs" % humans)
		return false
	return true


## Starts a duel on the live roster and reports every absent human holstered. Whatever the
## roster, every slot stands on its ring point in its roster colour, and the standoff
## message carries no lineup left over from a single-player duel.
func _lobby_start(tag: String) -> bool:
	if not NetworkManager.host_start() or GameManager.duel.state != DuelManager.State.STANDOFF:
		_fail("lobby %s: host_start() refused (%s)" % [tag, NetworkManager.start_refusal()])
		return false
	GameManager.duel._holstered.fill(true)
	if GameManager.hud.message_label.text != tr("MSG_HOLSTER"):
		_fail("lobby %s: the standoff message is '%s'" % [tag, GameManager.hud.message_label.text])
		return false
	return _lobby_points_ok("lobby " + tag) and _lobby_tints_ok("lobby " + tag, GameManager.duel.snapshot.slots.size())


## Waiting room of 4: one avatar per other human on its ring point, poses and shots
## routed by sender, unknown senders dropped.
func _lobby_room_routing_ok() -> bool:
	if not _lobby_fill(4) or not _lobby_room_ok("lobby"):
		return false
	var net := NetworkManager
	if net._accepts_sender(LOBBY_FAKE_PEERS[0]) or GameManager.avatar_of_peer(999) != null:
		_fail("lobby: an unverified or unknown sender is accepted")
		return false
	var head := Transform3D(Basis.IDENTITY, Vector3(1.0, 1.6, 2.0))
	var none := Transform3D.IDENTITY
	GameManager._on_pose_received(999, head, none, none, 0, none, 0, 0, none, none)
	GameManager._on_pose_received(LOBBY_FAKE_PEERS[1], head, none, none, 0, none, 0, 0, none, none)
	for slot: int in GameManager.avatars:
		var avatar: RemoteAvatar = GameManager.avatars[slot]
		if avatar._has_pose != (slot == 2) or (slot == 2 and not avatar._target_head.is_equal_approx(head)):
			_fail("lobby: a pose from slot 2's peer drove slot %d" % slot)
			return false
	var before := get_tree().get_nodes_in_group(Bullet.GROUP).size()
	GameManager._on_shot_received(999, Vector3(0.0, 50.0, 0.0), Vector3.UP)
	if get_tree().get_nodes_in_group(Bullet.GROUP).size() != before:
		_fail("lobby: a shot from an unknown sender spawned a bullet")
		return false
	GameManager._on_shot_received(LOBBY_FAKE_PEERS[2], Vector3(0.0, 50.0, 0.0), Vector3.UP)
	var shot: Bullet = null
	for node in get_tree().get_nodes_in_group(Bullet.GROUP):
		if (node as Bullet).shooter == 3:
			shot = node
	if shot == null or get_tree().get_nodes_in_group(Bullet.GROUP).size() != before + 1 or shot.from_local_player \
			or shot.exclude != (GameManager.avatars[3] as RemoteAvatar).hitbox_rids():
		_fail("lobby: slot 3's shot did not spawn with shooter 3 and its own volumes excluded")
		return false
	Bullet.clear_all()
	# A waiting-room leaver just loses the avatar.
	net.roster.vacate_peer(LOBBY_FAKE_PEERS[2], false)
	net._sync_roster()
	if GameManager.avatars.size() != 2 or GameManager.avatars.has(3) or GameManager.duel.host_peer_left(LOBBY_FAKE_PEERS[2]):
		_fail("lobby: a waiting-room leaver's avatar stayed")
		return false
	if not _voice_binds_ok("lobby") or VoiceChat.bound_peers().size() != 2 \
			or VoiceChat.bound_player(LOBBY_FAKE_PEERS[2]) != null:
		_fail("lobby: voice is not bound to each remaining human's avatar, or the leaver's is")
		return false
	print("AUTOTEST: lobby waiting room ok (4 slots, ring points, pose / shot routing, leaver)")
	return true


## Every avatar of a human plays that human's voice through the one shared stream on the
## Voice bus, no NPC proxy plays anyone's, and nothing else is bound.
func _voice_binds_ok(tag: String) -> bool:
	var snapshot := GameManager.duel.snapshot
	var roster := snapshot if snapshot != null else NetworkManager.roster
	var want: Array[int] = []
	for slot: int in GameManager.avatars:
		var avatar: RemoteAvatar = GameManager.avatars[slot]
		if avatar.npc_proxy:
			continue
		var peer_id := int(roster.slots[slot]["peer_id"])
		want.append(peer_id)
		var player := avatar.voice_player
		if VoiceChat.bound_player(peer_id) != player or player.bus != &"Voice" or player.stream != VoiceChat._generator:
			_fail("%s: slot %d's avatar does not play peer %d's voice on the Voice bus through the shared stream" % [
					tag, slot, peer_id])
			return false
	var bound := VoiceChat.bound_peers()
	bound.sort()
	want.sort()
	if bound != want:
		_fail("%s: voice is bound for peers %s, not %s" % [tag, bound, want])
		return false
	return true


## The routing the voice code answers right now, as seen from this machine's slot: who gets
## its packets (`voice_recipients`) and whose it takes (`accepts_voice_from`). `sends` and
## `hears` are peers; every other peer the test knows, the unknown 999, and this machine's own
## id must be refused.
func _voice_routing_ok(tag: String, sends: Array[int], hears: Array[int]) -> bool:
	if VoiceChat.voice_recipients() != sends:
		_fail("%s: voice goes to %s, not %s" % [tag, VoiceChat.voice_recipients(), sends])
		return false
	var asked: Array[int] = LOBBY_FAKE_PEERS.duplicate()
	asked.append_array([999, multiplayer.get_unique_id()])
	for peer_id in asked:
		if VoiceChat.accepts_voice_from(peer_id) != hears.has(peer_id):
			_fail("%s: voice from peer %d is %s, expected %s" % [
					tag, peer_id, VoiceChat.accepts_voice_from(peer_id), hears.has(peer_id)])
			return false
	return true


## After a frame (`VoiceChat._process` refreshes it): the speakers in `flat` play without
## distance falloff, the rest with the tuned one.
func _voice_falloff_ok(tag: String, flat: Array[int], normal: Array[int]) -> bool:
	await get_tree().process_frame
	for peer_id in flat + normal:
		var player := VoiceChat.bound_player(peer_id)
		if player == null:
			_fail("%s: no voice player is bound for peer %d" % [tag, peer_id])
			return false
		var is_flat := player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED
		var tuned := is_equal_approx(player.max_distance, float(GameManager.tuning["voice_max_distance"])) \
				and is_equal_approx(player.unit_size, float(GameManager.tuning["voice_unit_size"]))
		if is_flat != flat.has(peer_id) or (is_flat and player.max_distance != 0.0) or (not is_flat and not tuned):
			_fail("%s: peer %d plays %s falloff (model %d, max %.1f)" % [tag, peer_id,
					"without" if is_flat else "with", player.attenuation_model, player.max_distance])
			return false
	return true


## Voice in a lobby of four, from the host's seat with three humans who never connect (so
## packets are fed to the receive path directly, as the RPCs would): who is sent to and heard
## in the waiting room and at each point of a duel (the dead and the living split between
## the standoff and the draw; a void keeps the split; the finish and the next duel join them),
## no NPC or unknown sender ever, a dead speaker flat among the dead, per-sender sequence
## numbers, queues and mute, and a leaver's or rebuilt avatar's state dropped.
func _lobby_voice_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var a := LOBBY_FAKE_PEERS[0]
	var b := LOBBY_FAKE_PEERS[1]
	var c := LOBBY_FAKE_PEERS[2]
	var all: Array[int] = [a, b, c]
	if not _lobby_fill(4, {1: 0}) or not _voice_binds_ok("lobby voice npc") \
			or not _voice_routing_ok("lobby voice npc", [b, c], [b, c]):
		return false
	if not _lobby_fill(4) or not _voice_binds_ok("lobby voice room") or not _voice_routing_ok("lobby voice room", all, all):
		return false
	# One state per sender: sequence numbers, queues, and the mute X do not touch each other.
	var pcm := PackedByteArray()
	pcm.resize(VoiceChat.FRAME_SAMPLES * 2)
	VoiceChat.packets_accepted.clear()
	for seq in [1, 2, 3]:
		if not VoiceChat._take_packet(a, seq, pcm):
			_fail("lobby voice: sender A's packet %d was dropped" % seq)
			return false
	if not VoiceChat._take_packet(b, 1, pcm) or VoiceChat._take_packet(a, 2, pcm) or VoiceChat._take_packet(a, 3, pcm):
		_fail("lobby voice: sender B's first packet should not depend on A's numbers, and A's stragglers should drop")
		return false
	if VoiceChat._take_packet(999, 1, pcm) or VoiceChat._take_packet(net.multiplayer.get_unique_id(), 9, pcm) \
			or VoiceChat.packets_accepted != {a: 3, b: 1}:
		_fail("lobby voice: unknown senders or the tally are off (%s)" % [VoiceChat.packets_accepted])
		return false
	if VoiceChat._senders[a].rx.size() != VoiceChat.MAX_RX_QUEUE or VoiceChat._senders[b].rx.size() != 1 \
			or VoiceChat._senders[a].last_seq != 3 or VoiceChat._senders[b].last_seq != 1:
		_fail("lobby voice: the queues or sequence numbers are shared between senders")
		return false
	# A sender that restarts its counter resyncs.
	if not VoiceChat._take_packet(a, 500, pcm) or not VoiceChat._take_packet(a, 1, pcm) or VoiceChat._senders[a].last_seq != 1:
		_fail("lobby voice: a sender that restarted its sequence did not resync")
		return false
	var x: Array[RemoteAvatar] = [GameManager.avatars[1], GameManager.avatars[2], GameManager.avatars[3]]
	VoiceChat._take_mute(a, true)
	VoiceChat._take_mute(999, true)
	if not x[0].mute_icon.visible or x[1].mute_icon.visible or x[2].mute_icon.visible or VoiceChat._senders.has(999):
		_fail("lobby voice: A's mute should mark A's avatar only")
		return false
	VoiceChat._take_mute(b, true)
	VoiceChat._take_mute(a, false)
	if x[0].mute_icon.visible or not x[1].mute_icon.visible or x[2].mute_icon.visible:
		_fail("lobby voice: clearing A's mute should leave B's X up")
		return false
	VoiceChat._take_mute(b, false)
	# The same human on a new avatar (every duel rebuilds them) starts a clean sender.
	var old := VoiceChat.bound_player(a)
	GameManager._spawn_avatar(1, GameManager._mp_spawns(net.roster, true)[1])
	GameManager._bind_voice()
	if VoiceChat.bound_player(a) == old or VoiceChat.bound_player(a) != (GameManager.avatars[1] as RemoteAvatar).voice_player \
			or VoiceChat._senders[a].last_seq != 0 or not VoiceChat._senders[a].rx.is_empty() \
			or not _voice_binds_ok("lobby voice rebind"):
		_fail("lobby voice: a rebuilt avatar should replace the old player and reset its sender")
		return false
	print("AUTOTEST: lobby voice per sender ok (own sequence, queue, mute; unknown and NPC refused)")
	# The duel: with everyone alive nobody is split off.
	if not _lobby_start("voice") or not _voice_binds_ok("lobby voice duel"):
		return false
	for state: int in [DuelManager.State.STANDOFF, DuelManager.State.WAIT_SIGNAL, DuelManager.State.DRAW]:
		duel.state = state
		if not _voice_routing_ok("lobby voice state %d" % state, all, all):
			return false
	duel.state = DuelManager.State.STANDOFF
	var dead_old := VoiceChat.bound_player(a)
	# Slot 1 fouls twice (the first voids the standoff, which keeps everyone together) and is out.
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby voice: never waited for the bell")
		return false
	duel._host_foul(1)
	if duel.state != DuelManager.State.STANDOFF or not _voice_routing_ok("lobby voice void", all, all):
		return false
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby voice: the voided standoff never waited for the bell again")
		return false
	duel._host_foul(1)
	if duel.slot_alive(1) or duel.state != DuelManager.State.WAIT_SIGNAL \
			or not _voice_routing_ok("lobby voice foul", [b, c], [b, c]):
		_fail("lobby voice: slot 1 should be out and split off (state %d)" % duel.state)
		return false
	if not await _voice_falloff_ok("lobby voice foul", [a], [b, c]):
		return false
	# The same split from the other side: a dead listener hears the dead only.
	duel._alive[0] = false
	if not _voice_routing_ok("lobby voice dead host", [a], [a]):
		return false
	duel._alive[0] = true
	# A killed duelist joins the dead; the host and slot 3 are the living.
	duel._enter(DuelManager.State.DRAW)
	_lobby_shoot_head(GameManager.avatars[2], 0)
	if duel.live_slots() != [0, 3] or not _voice_routing_ok("lobby voice kill", [c], [c]):
		_fail("lobby voice: slot 2's death should leave the host and slot 3 together (live %s)" % [duel.live_slots()])
		return false
	if not await _voice_falloff_ok("lobby voice kill", [a, b], [c]):
		return false
	duel._alive[0] = false
	if not _voice_routing_ok("lobby voice dead host", [a, b], [a, b]):
		return false
	duel._alive[0] = true
	duel._mp_void(3)
	if duel.state != DuelManager.State.STANDOFF or not _voice_routing_ok("lobby voice void split", [c], [c]):
		_fail("lobby voice: a void restart should keep the split (state %d)" % duel.state)
		return false
	duel._enter(DuelManager.State.DRAW)
	# Slot 3 leaves: its sender is gone, nothing goes to it, and the host wins at once.
	net._verified_peers[c] = LOBBY_FAKE_NAMES[2]
	net._on_peer_disconnected(c)
	if duel.state != DuelManager.State.RESOLUTION or VoiceChat.bound_player(c) != null or VoiceChat._senders.has(c) \
			or VoiceChat._take_packet(c, 600, pcm):
		_fail("lobby voice: a leaver's sender survived (state %d)" % duel.state)
		return false
	# The finish joins everyone left, and the dead speakers get their falloff back.
	if not _voice_routing_ok("lobby voice finish", [a, b], [a, b]):
		return false
	if not await _voice_falloff_ok("lobby voice finish", [], [a, b]):
		return false
	# The waiting room, then the next duel: everyone again, on avatars that are rebuilt.
	if not _lobby_fill(4) or not _voice_routing_ok("lobby voice room again", all, all):
		return false
	if not _lobby_start("voice again") or not _voice_binds_ok("lobby voice duel again") \
			or VoiceChat.bound_player(a) == dead_old or not _voice_routing_ok("lobby voice duel again", all, all):
		return false
	if not await _voice_falloff_ok("lobby voice duel again", [], all):
		return false
	print("AUTOTEST: lobby voice channels ok (dead and living split, void, leaver, finish, next duel)")
	return true


## Three duelists: a first foul voids the standoff and names the fouler, the same slot's
## second foul puts it out standing, the host's own first foul voids again, and the
## last kill wins with no replay.
func _lobby_foul_ok() -> bool:
	var duel := GameManager.duel
	var roster := NetworkManager.roster
	var local := GameManager.local_player
	if not _lobby_fill(3) or not _lobby_start("foul"):
		return false
	if GameManager.side_of(local) != 0 or GameManager.side_of(GameManager.avatars[2]) != 2 \
			or GameManager.side_of(self) != -1 or duel.slot_name(1) != "Ann" or not ReplayBuffer.is_recording():
		_fail("lobby foul: sides, names, or the clip recording are off at the start")
		return false
	var result := _arm_duel_listener()
	var out: RemoteAvatar = GameManager.avatars[1]
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby foul: never waited for the bell")
		return false
	duel._host_foul(1)
	if duel.state != DuelManager.State.STANDOFF or duel.live_slots() != [0, 1, 2] or duel._fouls != [0, 1, 0] \
			or not GameManager.hud.message_label.text.contains("Ann") or not result.is_empty():
		_fail("lobby foul: a first foul should void the standoff (state %d, '%s')" % [
				duel.state, GameManager.hud.message_label.text])
		return false
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby foul: the voided standoff never waited for the bell again")
		return false
	var gun_parent := out.gun.get_parent()
	duel._host_foul(1)
	var shown := GameManager.hud.message_label.text
	if duel.state != DuelManager.State.WAIT_SIGNAL or duel.live_slots() != [0, 2] or not result.is_empty() \
			or not shown.contains("Ann") or not shown.ends_with("2 left"):
		_fail("lobby foul: a second foul should put the slot out and go on (state %d, '%s')" % [duel.state, shown])
		return false
	if not out.is_dead() or not out._out or out._dummy.has_corpse() or out.gun.get_parent() != gun_parent \
			or not out.head_hitbox.is_corpse() or not out.leg_hitbox_l.is_corpse():
		_fail("lobby foul: an out avatar should stand frozen, gun kept, bullets passing")
		return false
	if not await _bullet_passes_avatar(out, "lobby foul"):
		return false
	# An out duelist cannot holster: it must not hold the standoff up.
	duel._holstered[1] = false
	local._draw_gun()
	if not await _wait_for_state(DuelManager.State.STANDOFF, 2.0) or duel._fouls != [1, 2, 0] \
			or not GameManager.hud.message_label.text.contains(roster.slots[0]["name"]):
		_fail("lobby foul: the host's first foul should void the standoff (state %d)" % duel.state)
		return false
	local._holster_gun()
	if not await _wait_for_state(DuelManager.State.DRAW, 12.0):
		_fail("lobby foul: never reached DRAW with a slot out")
		return false
	duel.mp_report_hit(1, PackedVector3Array(), CombatRules.REGION_HEAD, 99.0, 0)
	if duel.state != DuelManager.State.DRAW or not result.is_empty():
		_fail("lobby foul: a hit on an out slot was not ignored")
		return false
	_lobby_shoot_head(GameManager.avatars[2])
	if result != [true, "MSG_REASON_LAST_STANDING"] or roster.slots[0]["wins"] != 1 or roster.slots[2]["wins"] != 0:
		_fail("lobby foul: the last kill gave %s, tally %s" % [result, roster.pack()])
		return false
	if not DeathCam.is_active() or not KillCam.is_playing or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != 2 \
			or ReplayBuffer.death_time < 0.0 or ReplayBuffer.death_time_of(1) >= 0.0:
		_fail("lobby foul: a 3-slot finish should run the kill cam and the death cam, with no fall for the one fouled out")
		return false
	if not await _wait_for(func() -> bool: return ReplayBuffer.is_sealed, 8.0) or not ReplayBuffer.ready_to_play():
		_fail("lobby foul: the 3-slot duel never sealed its clip")
		return false
	var last: Array = ReplayBuffer.sample_at(ReplayBuffer.clip_end())
	if last.size() != 3 or last.any(func(pose: Dictionary) -> bool: return int(pose["flags"]) & ReplayBuffer.PRESENT == 0):
		_fail("lobby foul: the sealed clip should hold all 3 actors (%d)" % last.size())
		return false
	print("AUTOTEST: lobby fouls ok (void, out standing, host void, last kill, sealed 3-actor clip)")
	return true


## A human dropping mid-duel: counts as dead, the avatar goes, the duel goes on while two
## sides stand, and the slot is a Mixed NPC from the next duel.
func _lobby_leaver_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	if not _lobby_fill(3) or not _lobby_start("leaver"):
		return false
	var result := _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	net._verified_peers[LOBBY_FAKE_PEERS[0]] = LOBBY_FAKE_NAMES[0]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[0])
	var shown := GameManager.hud.message_label.text
	if duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 2] or GameManager.avatars.has(1) \
			or not result.is_empty() or not shown.contains("Ann") or not shown.ends_with("2 left"):
		_fail("lobby leaver: a mid-duel leaver should count as dead and vanish (state %d, '%s')" % [duel.state, shown])
		return false
	if net.roster.slots[1]["kind"] != LobbyRoster.Kind.NPC or duel.snapshot.slots[1]["kind"] != LobbyRoster.Kind.HUMAN:
		_fail("lobby leaver: the live roster should turn the slot into an NPC and the snapshot keep it")
		return false
	# From here on the clip records the leaver blank, and the others as before.
	await _sleep(0.15)
	var after: Array = ReplayBuffer.sample_at(ReplayBuffer.clip_end())
	if after.size() != 3 or int(after[1]["flags"]) & ReplayBuffer.PRESENT != 0 \
			or int(after[0]["flags"]) & ReplayBuffer.PRESENT == 0 or int(after[2]["flags"]) & ReplayBuffer.PRESENT == 0:
		_fail("lobby leaver: a leaver should record as a blank actor")
		return false
	net._verified_peers[LOBBY_FAKE_PEERS[1]] = LOBBY_FAKE_NAMES[1]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[1])
	if result != [true, "MSG_OPPONENT_LEFT"] or not GameManager.avatars.is_empty() or net.roster.slots[0]["wins"] != 1:
		_fail("lobby leaver: the last rival leaving should win it for the host (%s)" % [result])
		return false
	# Both leavers' slots are Mixed NPCs now, and the auto-rematch runs with them.
	for slot: int in [1, 2]:
		if net.roster.slots[slot]["kind"] != LobbyRoster.Kind.NPC \
				or net.roster.slots[slot]["archetype"] != LobbyRoster.ARCHETYPE_MIXED:
			_fail("lobby leaver: slot %d should be a Mixed NPC after its human left: %s" % [slot, net.roster.pack()])
			return false
	if net.start_refusal() != "":
		_fail("lobby leaver: a roster of the host and the leavers' NPCs should start (%s)" % net.start_refusal())
		return false
	var rematched := func() -> bool:
		return duel.state == DuelManager.State.STANDOFF and GameManager.current_ais.size() == 2
	if not await _wait_for(rematched, 9.0):
		_fail("lobby leaver: the rematch never started with the leavers' slots as NPCs (state %d, %d NPCs)" % [
				duel.state, GameManager.current_ais.size()])
		return false
	if duel.live_slots() != [0, 1, 2] or not GameManager.avatars.is_empty() or net.roster.slots[0]["wins"] != 1:
		_fail("lobby leaver: the rematch should be the host against two NPCs (live %s)" % [duel.live_slots()])
		return false
	for slot: int in [1, 2]:
		if not _lobby_npc_slot_ok(slot, "lobby leaver"):
			return false
	print("AUTOTEST: lobby leaver ok (dead mid-duel, avatar gone, slot becomes a Mixed NPC, the rematch runs with it)")
	return true


## Two duelists keep today's rules: a foul loses at once, either way round, and the
## duel records a clip.
func _lobby_two_slot_ok() -> bool:
	var duel := GameManager.duel
	var roster := NetworkManager.roster
	var local := GameManager.local_player
	if not _lobby_fill(2) or not _lobby_start("1v1"):
		return false
	var result := _arm_duel_listener()
	if not ReplayBuffer.is_recording() or ReplayBuffer.actor_count() != 2 or DeathCam.is_spectating():
		_fail("lobby 1v1: a 2-slot duel should record its 2-actor clip")
		return false
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby 1v1: never waited for the bell")
		return false
	var rival: RemoteAvatar = GameManager.avatars[1]
	duel._host_foul(1)
	if result != [true, "MSG_REASON_FOUL_OPPONENT"] or duel.state != DuelManager.State.RESOLUTION \
			or rival.is_dead() or rival._dummy.has_corpse() or roster.slots[0]["wins"] != 1 or DeathCam.is_active():
		_fail("lobby 1v1: the joiner's foul should lose it at once, nobody falling (%s)" % [result])
		return false
	if not _lobby_start("1v1 rematch"):
		return false
	result = _arm_duel_listener()
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby 1v1: the rematch never waited for the bell")
		return false
	local._draw_gun()
	await _await_result(result, 2.0)
	if result != [false, "MSG_REASON_FOUL_HOST"] or local.alive or local.corpse_body().has_corpse() \
			or roster.slots[1]["wins"] != 1 or roster.slots[0]["wins"] != 1 \
			or DeathCam.phase != DeathCam.Phase.IDLE or DeathCam.blocks_combat():
		_fail("lobby 1v1: the host's foul should lose it at once (%s)" % [result])
		return false
	print("AUTOTEST: lobby 1v1 fouls ok (fouler loses, clip recorded)")
	return true


## The win check counts sides, not slots: a Teams duel (2v2, four humans) ends when one side
## is down while a teammate of the dead host still stands, and the dead host reads the win.
func _lobby_sides_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var local := GameManager.local_player
	if not _lobby_fill(4):
		return false
	net.host_set_mode(LobbyRoster.Mode.TEAMS)
	for slot in 4:
		net.roster.set_side(slot, slot % 2)
	if not net.roster.can_start() or net.start_refusal() != "" or not _lobby_start("sides"):
		_fail("lobby sides: host_start() should start a 2v2 (%s)" % net.start_refusal())
		return false
	if duel.state != DuelManager.State.STANDOFF or GameManager.avatars.size() != 3 or not duel.is_team_duel() \
			or duel.snapshot.spawn_order() != [0, 2, 1, 3] \
			or GameManager.side_of(local) != 0 or GameManager.side_of(GameManager.avatars[2]) != 0 \
			or GameManager.side_of(GameManager.avatars[3]) != 1:
		_fail("lobby sides: the Teams snapshot did not build two sides")
		return false
	var result := _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	_lobby_shoot_head(GameManager.avatars[1])
	if not result.is_empty() or duel.live_slots() != [0, 2, 3]:
		_fail("lobby sides: one death on a side of two ended the duel")
		return false
	# The host dies to slot 3: its side still has slot 2, so the duel goes on.
	var head := local.get_head_position()
	local.take_bullet_hit(99.0, PackedVector3Array([head - Vector3.FORWARD, head]), CombatRules.REGION_HEAD,
			false, false, 3)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [2, 3] \
			or local.alive or not local.head_hitbox.is_corpse() or not _says_left(2):
		_fail("lobby sides: the host's death should leave its teammate fighting (live %s)" % [duel.live_slots()])
		return false
	if not await _lobby_held_ok(true):
		return false
	_lobby_shoot_head(GameManager.avatars[3])
	if result != [true, "MSG_REASON_LAST_SIDE"] or duel.live_slots() != [2] or local.alive \
			or GameManager.hud.message_label.text != "%s\n%s" % [tr("MSG_SIDE_WON"), tr("MSG_REASON_LAST_SIDE")]:
		_fail("lobby sides: the dead host's side should win when the other is down (%s, '%s')" % [
				result, GameManager.hud.message_label.text])
		return false
	if DeathCam.is_spectating() or not DeathCam.is_active() or not DeathCam._local_is_down() \
			or GameManager.hud.spectate_tag.visible:
		_fail("lobby sides: the last kill should take a dead winner from spectating into the death cam")
		return false
	if net.roster.slots[0]["wins"] != 1 or net.roster.slots[2]["wins"] != 1 or net.roster.slots[1]["wins"] != 0 \
			or net.roster.slots[3]["wins"] != 0:
		_fail("lobby sides: every slot of the winning side should get the win: %s" % net.roster.pack())
		return false
	print("AUTOTEST: lobby win check by sides ok (a 2v2 through START, a dead duelist's side wins and reads it, both slots tallied)")
	return true


const LOBBY_SPECTATE_HOLD := 0.5


## Spectating with the hold on the own corpse shortened: a kill, then a foul.
func _lobby_spectate_ok() -> bool:
	var saved_hold: float = GameManager.tuning["death_cam_hold"]
	GameManager.tuning["death_cam_hold"] = LOBBY_SPECTATE_HOLD
	var ok: bool = await _lobby_spectate_kill_ok() and await _lobby_leaver_replay_ok() \
			and await _lobby_spectate_foul_ok()
	GameManager.tuning["death_cam_hold"] = saved_hold
	return ok


## A leaver's slot stays in the clip as a blank actor from the moment it left: the final
## kill still seals 3 actors, and the replay runs with that body gone.
func _lobby_leaver_replay_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var local := GameManager.local_player
	if not _lobby_fill(3) or not _lobby_start("leaver replay"):
		return false
	var result := _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	await _sleep(0.3)
	net._verified_peers[LOBBY_FAKE_PEERS[0]] = LOBBY_FAKE_NAMES[0]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[0])
	await _sleep(0.2)
	var last_rival: RemoteAvatar = GameManager.avatars[2]
	_lobby_shoot_head(last_rival)
	if result != [true, "MSG_REASON_LAST_STANDING"] or not DeathCam.is_active() or GameManager.avatars.has(1):
		_fail("lobby leaver replay: the host should win the kill with the leaver's body gone (%s)" % [result])
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 12.0):
		_fail("lobby leaver replay: the replay never started (sealed %s)" % ReplayBuffer.is_sealed)
		return false
	var first: Array = ReplayBuffer.sample_at(ReplayBuffer.clip_begin())
	var last: Array = ReplayBuffer.sample_at(ReplayBuffer.clip_end())
	if first.size() != 3 or last.size() != 3 or int(first[1]["flags"]) & ReplayBuffer.PRESENT == 0 \
			or int(last[1]["flags"]) & ReplayBuffer.PRESENT != 0 or ReplayBuffer.death_time_of(1) >= 0.0:
		_fail("lobby leaver replay: the leaver should be in the clip until it left, and blank after")
		return false
	if DeathCam._stashed.size() != 3 or not (DeathCam._stashed[1] as Dictionary).is_empty() or DeathCam._retraced != [2]:
		_fail("lobby leaver replay: the replay should skip the missing body (retraced %s)" % [DeathCam._retraced])
		return false
	if not await _wait_for(func() -> bool: return DeathCam._play_t >= ReplayBuffer.death_time + 0.2, 12.0) \
			or DeathCam.phase != DeathCam.Phase.PLAYBACK or last_rival.corpse_body().corpse_state() != BodyRagdoll.State.TRACK:
		_fail("lobby leaver replay: the replay did not play through the kill (phase %d)" % DeathCam.phase)
		return false
	local._on_trigger_changed(&"right_hand", true)
	local._on_trigger_changed(&"right_hand", false)
	await get_tree().process_frame
	await get_tree().process_frame
	if DeathCam.phase != DeathCam.Phase.TRAILING or DeathCam.blocks_combat() or is_instance_valid(DeathCam._camera) \
			or not last_rival.replay_locked or last_rival.corpse_body().corpse_state() != BodyRagdoll.State.HELD:
		_fail("lobby leaver replay: the living winner should be back in first person after the replay (phase %d)" % DeathCam.phase)
		return false
	print("AUTOTEST: lobby leaver replay ok (blank actor in a sealed 3-actor clip, replay with the body gone)")
	return true


## Four duelists, the host shot first by slot 2: it orbits its own corpse for the hold,
## moves to its killer, cycles the living on the trigger (never itself or the dead,
## wrapping), moves on by itself when the watched one dies, and cannot act. The last kill
## (slot 1 over slot 3) takes over: fly-along, the victim's orbit, a sealed 4-actor clip in
## which the earlier corpses fall again, and the trailing orbit.
func _lobby_spectate_kill_ok() -> bool:
	var duel := GameManager.duel
	var local := GameManager.local_player
	var hud := GameManager.hud
	if not _lobby_fill(4) or not _lobby_start("spectate"):
		return false
	var own_camera := get_viewport().get_camera_3d()
	var result := _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	# A few samples first, so the host's fall lands inside the clip.
	await _sleep(0.3)
	if not ReplayBuffer.is_recording() or ReplayBuffer.actor_count() != 4 or DeathCam.phase != DeathCam.Phase.IDLE \
			or DeathCam.blocks_remote_pose(2) or own_camera == null:
		_fail("lobby spectate: a 4-slot duel should record 4 actors with nobody watching yet")
		return false
	var head := local.get_head_position()
	var died_at := Time.get_ticks_msec()
	local.take_bullet_hit(99.0, PackedVector3Array([head - Vector3.FORWARD, head]), CombatRules.REGION_HEAD,
			false, false, 2)
	if not result.is_empty() or duel.live_slots() != [1, 2, 3] or local.alive or KillCam.is_playing:
		_fail("lobby spectate: the host's death should leave three fighting (live %s)" % [duel.live_slots()])
		return false
	if not DeathCam.is_spectating() or DeathCam.is_active() or DeathCam.spectate_target() != 0 or hud.spectate_tag.visible \
			or not _orbit_on(DeathCam._chest(0)):
		_fail("lobby spectate: one shot mid-duel should orbit its own corpse first (phase %d, target %d)" % [
				DeathCam.phase, DeathCam.spectate_target()])
		return false
	if not DeathCam.blocks_combat() or not DeathCam.locks_recorded_body() or not DeathCam.consumes_look() \
			or DeathCam.can_skip() or DeathCam.blocks_npcs() or ReplayBuffer.death_time_of(0) < 0.0:
		_fail("lobby spectate: a spectator should be held, latched in the clip, steering the orbit, with NPCs running")
		return false
	if not await _wait_for(func() -> bool: return DeathCam.spectate_target() != 0, LOBBY_SPECTATE_HOLD + 3.0):
		_fail("lobby spectate: the hold on the own corpse never ended")
		return false
	var held := (Time.get_ticks_msec() - died_at) / 1000.0
	if held < LOBBY_SPECTATE_HOLD - 0.15 or not _watching(2) or not _orbit_on(DeathCam._chest(2)):
		_fail("lobby spectate: after %.2f s the camera is on slot %d, not on the killer (slot 2) after the hold" % [
				held, DeathCam.spectate_target()])
		return false
	# All three alive: 2 -> 3 -> 1 (past itself) -> 2. The same pulls must not draw or fire.
	var rounds := local.revolver.rounds
	var from := local.rig.global_position
	local._on_grip_changed(&"right_hand", true)
	for want: int in [3, 1, 2]:
		if not await _spectate_pull_ok(want):
			return false
	Input.action_press("move_forward")
	await _sleep(0.3)
	Input.action_release("move_forward")
	if local.revolver.held or local.revolver.rounds != rounds or local.rig.global_position.distance_to(from) > 0.01:
		_fail("lobby spectate: a spectator could still act (held %s, rounds %d -> %d, moved %.2f m)" % [
				local.revolver.held, rounds, local.revolver.rounds, local.rig.global_position.distance_to(from)])
		return false
	var yaw := DeathCam._yaw
	DeathCam.add_look(Vector2(40.0, 0.0))
	if is_equal_approx(DeathCam._yaw, yaw):
		_fail("lobby spectate: look does not steer the spectate orbit")
		return false
	# The watched one dies with two others standing: the camera moves on by itself.
	_lobby_shoot_head(GameManager.avatars[2], 3)
	if not result.is_empty() or duel.live_slots() != [1, 3] or not DeathCam.blocks_remote_pose(2) \
			or DeathCam.blocks_remote_pose(1) or ReplayBuffer.death_time_of(2) < 0.0:
		_fail("lobby spectate: slot 2's death should leave two fighting (live %s)" % [duel.live_slots()])
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	if not _watching(3) or not _orbit_on(DeathCam._chest(3)):
		_fail("lobby spectate: the camera should leave a dead duelist by itself (on %d)" % DeathCam.spectate_target())
		return false
	# Two left: 3 -> 1 -> 3, past itself and the dead.
	for want: int in [1, 3]:
		if not await _spectate_pull_ok(want):
			return false
	_lobby_shoot_head(GameManager.avatars[3], 1)
	if result != [false, "MSG_REASON_LAST_STANDING"] or duel.live_slots() != [1]:
		_fail("lobby spectate: slot 1 should win as the last one standing (%s)" % [result])
		return false
	if DeathCam.is_spectating() or DeathCam.phase != DeathCam.Phase.FLYING or not KillCam.is_playing \
			or hud.spectate_tag.visible or KillCam._restore_camera != own_camera:
		_fail("lobby spectate: the last kill should take the view from the spectator into the fly-along (phase %d)" % DeathCam.phase)
		return false
	if ReplayBuffer.killer_id != 1 or ReplayBuffer.victim_id != 3 or DeathCam._local_is_victim() \
			or not DeathCam._local_is_down() or not DeathCam.blocks_combat() or not DeathCam.locks_recorded_body():
		_fail("lobby spectate: one who died earlier should stay held through the final sequence")
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.ORBIT, 8.0):
		_fail("lobby spectate: the fly-along never handed over to the orbit (phase %d)" % DeathCam.phase)
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	if not _orbit_on(DeathCam._chest(3), 0.4) or not DeathCam.consumes_look() or not DeathCam.can_skip():
		_fail("lobby spectate: one who died earlier should watch the final victim's corpse orbit")
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 12.0):
		_fail("lobby spectate: the replay never started (sealed %s)" % ReplayBuffer.is_sealed)
		return false
	var begin := ReplayBuffer.clip_begin()
	var killer_head := (GameManager.avatars[1] as RemoteAvatar).head.global_position
	if not ReplayBuffer.is_sealed or ReplayBuffer.sample_at(begin).size() != 4 or ReplayBuffer.death_time_of(1) >= 0.0 \
			or DeathCam._retraced.has(1) or not DeathCam.blocks_remote_pose(1) or not DeathCam.blocks_npcs():
		_fail("lobby spectate: the final kill should seal a 4-actor clip that everyone watches")
		return false
	for corpse: int in [0, 2, 3]:
		if ReplayBuffer.death_time_of(corpse) < begin or not DeathCam._retraced.has(corpse):
			_fail("lobby spectate: slot %d's fall is not in the clip (%.2f, clip from %.2f)" % [
					corpse, ReplayBuffer.death_time_of(corpse), begin])
			return false
	if DeathCam._camera.global_position.distance_to(killer_head) > 0.3:
		_fail("lobby spectate: the replay does not open on the killer's eyes")
		return false
	var own := local.corpse_body()
	var own_death := ReplayBuffer.death_time_of(0)
	var second := _corpse_of(2)
	if (own_death - DeathCam._play_t > 0.2 and own.corpse_state() != BodyRagdoll.State.RETRACE) \
			or (ReplayBuffer.death_time_of(2) - DeathCam._play_t > 0.2 and second.corpse_state() != BodyRagdoll.State.RETRACE):
		_fail("lobby spectate: the earlier corpses do not stand up for the replay")
		return false
	if not await _wait_for(func() -> bool: return DeathCam._play_t >= own_death + 0.3, 12.0) \
			or DeathCam.phase != DeathCam.Phase.PLAYBACK or own.corpse_state() != BodyRagdoll.State.TRACK:
		_fail("lobby spectate: the host's own fall does not replay at its time (state %d)" % own.corpse_state())
		return false
	# The dead host's trigger skips the rest, as anyone's does.
	local._on_trigger_changed(&"right_hand", true)
	local._on_trigger_changed(&"right_hand", false)
	await get_tree().process_frame
	await get_tree().process_frame
	if DeathCam.phase != DeathCam.Phase.TRAILING or not DeathCam.blocks_combat() or not _orbit_on(DeathCam._chest(3), 0.4) \
			or hud.replay_tag.visible or DeathCam.blocks_npcs():
		_fail("lobby spectate: the skip should leave the dead host on the trailing orbit (phase %d)" % DeathCam.phase)
		return false
	for corpse: int in [0, 2, 3]:
		if _corpse_of(corpse).corpse_state() != BodyRagdoll.State.HELD:
			_fail("lobby spectate: slot %d's corpse is not held after the replay (state %d)" % [
					corpse, _corpse_of(corpse).corpse_state()])
			return false
	if (GameManager.avatars[1] as RemoteAvatar).replay_locked or not (GameManager.avatars[2] as RemoteAvatar).replay_locked \
			or not (GameManager.avatars[3] as RemoteAvatar).replay_locked:
		_fail("lobby spectate: only the living should get their bodies back after the replay")
		return false
	print("AUTOTEST: lobby spectate ok (hold, killer, cycle, auto-advance, hand-off, sealed 4-actor clip, retrace, skip)")
	return true


## One trigger pull while spectating puts the orbit on `want`. `slack` allows for a
## target that keeps moving (a strafing NPC).
func _spectate_pull_ok(want: int, slack := 0.05) -> bool:
	var local := GameManager.local_player
	local._on_trigger_changed(&"right_hand", true)
	local._on_trigger_changed(&"right_hand", false)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _watching(want) or not _orbit_on(DeathCam._chest(want), slack):
		_fail("lobby spectate: the trigger should move the camera to slot %d (on %d, label '%s')" % [
				want, DeathCam.spectate_target(), GameManager.hud.spectate_tag.text])
		return false
	return true


## Fouled out with others still in: no hold and no fall, straight to the next living
## duelist. A watched duelist who leaves is dropped too, a finish with no kill keeps the
## spectator watching, and the waiting room ends it.
func _lobby_spectate_foul_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var local := GameManager.local_player
	if not _lobby_fill(4) or not _lobby_start("spectate foul"):
		return false
	var own_camera := get_viewport().get_camera_3d()
	for foul in DuelManager.FOULS_OUT:
		if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
			_fail("lobby spectate foul: never waited for the bell (foul %d)" % foul)
			return false
		duel._host_foul(0)
	if duel.state != DuelManager.State.WAIT_SIGNAL or duel.live_slots() != [1, 2, 3] or local.alive \
			or local.corpse_body().has_corpse():
		_fail("lobby spectate foul: the host's second foul should put it out standing (live %s)" % [duel.live_slots()])
		return false
	if not _watching(1) or DeathCam._spectate_holding or not DeathCam.blocks_combat() or ReplayBuffer.death_time_of(0) >= 0.0:
		_fail("lobby spectate foul: one fouled out should go straight to the next living duelist (on %d)" % DeathCam.spectate_target())
		return false
	net._verified_peers[LOBBY_FAKE_PEERS[0]] = LOBBY_FAKE_NAMES[0]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[0])
	await get_tree().process_frame
	await get_tree().process_frame
	if duel.live_slots() != [2, 3] or not _watching(2) or not _orbit_on(DeathCam._chest(2)):
		_fail("lobby spectate foul: the camera should leave a duelist who left (on %d)" % DeathCam.spectate_target())
		return false
	# A finish with no kill runs no death cam: the spectator stays on the last one standing.
	var result := _arm_duel_listener()
	net._verified_peers[LOBBY_FAKE_PEERS[1]] = LOBBY_FAKE_NAMES[1]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[1])
	await get_tree().process_frame
	await get_tree().process_frame
	if result != [false, "MSG_OPPONENT_LEFT"] or DeathCam.is_active() or KillCam.is_playing or not _watching(3):
		_fail("lobby spectate foul: a finish with no kill should leave the spectator on the winner (%s, on %d)" % [
				result, DeathCam.spectate_target()])
		return false
	if not net.host_back_to_lobby() or DeathCam.phase != DeathCam.Phase.IDLE or DeathCam.spectate_target() != -1 \
			or DeathCam.blocks_combat() or is_instance_valid(DeathCam._camera) or GameManager.hud.spectate_tag.visible \
			or get_viewport().get_camera_3d() != own_camera:
		_fail("lobby spectate foul: the waiting room should end spectating (phase %d)" % DeathCam.phase)
		return false
	print("AUTOTEST: lobby spectate foul ok (no hold, leaver dropped, kept through a finish with no kill, cleared by the waiting room)")
	return true


# -- NPC slots -----------------------------------------------------------------------

## Parks an NPC's reaction timer and its draw, so it does nothing more until the test says.
const LOBBY_NPC_PARK := 600.0
## Random target picks sampled to see every rival an NPC may choose.
const LOBBY_NPC_PICKS := 60


## NPC slots, with the hold on the own corpse shortened and every hit cutting a hole.
func _lobby_npcs_ok() -> bool:
	var saved_hold: float = GameManager.tuning["death_cam_hold"]
	var saved_chance: float = GameManager.tuning["chunk_chance"]
	GameManager.tuning["death_cam_hold"] = LOBBY_SPECTATE_HOLD
	GameManager.tuning["chunk_chance"] = 1.0
	var ok: bool = await _lobby_npc_duel_ok() and await _lobby_npc_proxy_ok()
	GameManager.tuning["death_cam_hold"] = saved_hold
	GameManager.tuning["chunk_chance"] = saved_chance
	return ok


func _lobby_park(ai: DuelistAI) -> void:
	ai._timer = LOBBY_NPC_PARK
	ai._draw_progress = -LOBBY_NPC_PARK


## A hit on one of `ai`'s volumes from its front, from the bullet's impact on
## (`Hitbox.receive_hit`): the DRAW gate, the hole on the struck shape, then the NPC's own
## resolve. `shooter` is the slot credited.
func _lobby_shoot_npc(ai: DuelistAI, hitbox: Hitbox, shooter: int) -> void:
	var point := _hitbox_center(hitbox)
	var shot := ai.global_transform.basis.z
	hitbox.receive_hit(PackedVector3Array([point - shot, point]), false, false, shooter, 0)


## Every rival `ai` picked in LOBBY_NPC_PICKS random picks. Leaves it on the last one.
func _lobby_npc_picks(ai: DuelistAI) -> Dictionary:
	var picked := {}
	for _pick in LOBBY_NPC_PICKS:
		ai._pick_target()
		picked[ai._target] = true
	return picked


## On the host: `slot` of the running duel is an NPC slot whose snapshot row carries a
## rolled archetype and that archetype's name, and a live `DuelistAI` with that actor id,
## archetype, and HP stands on the slot's ring point, with no avatar for it. Before the
## bell only: a strafer leaves its point after it.
func _lobby_npc_slot_ok(slot: int, tag: String) -> bool:
	var duel := GameManager.duel
	var row: Dictionary = duel.snapshot.slots[slot]
	var index: int = row["archetype"]
	if row["kind"] != LobbyRoster.Kind.NPC or index < 0 or index >= GameManager.ARCHETYPES.size():
		_fail("%s: snapshot slot %d is not an NPC with a rolled archetype (%s)" % [tag, slot, row])
		return false
	var archetype := GameManager.archetype_at(index)
	if row["name"] != archetype.display_name or duel.slot_name(slot) != archetype.display_name:
		_fail("%s: NPC slot %d is named '%s', not '%s'" % [tag, slot, row["name"], archetype.display_name])
		return false
	var ai := GameManager.actor_node(slot) as DuelistAI
	var order := duel.snapshot.spawn_order()
	var spawn: Transform3D = GameManager.current_scenario.get_duel_spawns(order.size())[order.find(slot)]
	if ai == null or GameManager.avatars.has(slot) or ai.actor_id != slot or ai.archetype != archetype \
			or not is_equal_approx(ai.health, archetype.health) or not ai.is_alive() \
			or GameManager.side_of(ai) != duel.snapshot.side_of(slot) or ai.global_position.distance_to(spawn.origin) > 0.05 \
			or is_instance_valid(ai._target):
		_fail("%s: the host does not run slot %d as %s on its ring point" % [tag, slot, archetype.display_name])
		return false
	return true


## The host and three NPC slots (the Drunk, the Sheriff, Mixed), free-for-all, through the
## real RPC path. The standoff does not wait on an NPC's holster. At the bell every NPC
## reacts and picks among all its rivals, the other NPCs included. A wound cuts one hole
## and turns the NPC on its attacker. The Drunk's death is `_mp_down` ("3 left", no kill
## cam) with the shooter credited, and it falls once. The host then dies to the Sheriff and
## spectates it by name while the two NPCs left turn on each other and keep running (the
## Sheriff draws). The Sheriff's kill of the last NPC is `_mp_finish`: its slot wins and is
## tallied, and the sealed 4-actor clip replays with the three corpses retracing.
func _lobby_npc_duel_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var local := GameManager.local_player
	var hud := GameManager.hud
	if not _lobby_fill(4, {1: 0, 2: 1, 3: LobbyRoster.ARCHETYPE_MIXED}):
		return false
	# No `_lobby_start`: nobody reports a holster for an NPC slot.
	if net.start_refusal() != "" or not net.host_start() or duel.state != DuelManager.State.STANDOFF:
		_fail("lobby npcs: host_start() refused the host and three NPCs (%s)" % net.start_refusal())
		return false
	var ais: Array[DuelistAI] = GameManager.current_ais.duplicate()
	if ais.size() != 3 or duel.snapshot.slots.size() != 4 or ReplayBuffer.actor_count() != 4 \
			or not ReplayBuffer.is_recording() or not VoiceChat.bound_peers().is_empty():
		_fail("lobby npcs: the duel did not start on 4 slots with three host NPCs (%d)" % ais.size())
		return false
	for slot in range(1, 4):
		if not _lobby_npc_slot_ok(slot, "lobby npcs"):
			return false
	# Free-for-all: slot order on the ring, and each NPC in its slot's colour, not its archetype's.
	if not _lobby_points_ok("lobby npcs", [0, 1, 2, 3]) or not _lobby_tints_ok("lobby npcs", 4):
		return false
	if duel.snapshot.slots[1]["archetype"] != 0 or duel.snapshot.slots[2]["archetype"] != 1 \
			or net.roster.slots[3]["archetype"] != LobbyRoster.ARCHETYPE_MIXED or net.roster.slots[3]["name"] != "":
		_fail("lobby npcs: a picked archetype should hold, and the live roster keep Mixed to roll again")
		return false
	var result := _arm_duel_listener()
	if not await _wait_for_state(DuelManager.State.DRAW, 12.0):
		_fail("lobby npcs: the standoff waited on the NPCs (state %d)" % duel.state)
		return false
	for ai in ais:
		if ai.state != DuelistAI.AIState.REACTING or not ai._is_rival(ai._target):
			_fail("lobby npcs: NPC %d did not react to the bell with a live rival" % ai.actor_id)
			return false
		_lobby_park(ai)
		var picked := _lobby_npc_picks(ai)
		if picked.size() != 3 or picked.has(ai) or picked.has(null):
			_fail("lobby npcs: NPC %d should pick among the host and both other NPCs (%d picked)" % [ai.actor_id, picked.size()])
			return false
	var drunk := ais[0]
	var sheriff := ais[1]
	var last := ais[2]
	var deaths := [0]
	drunk.died.connect(func(_trail: PackedVector3Array) -> void: deaths[0] += 1)
	# Wounds: the hole is cut once, and the NPC turns on whoever shot it.
	_lobby_shoot_npc(drunk, drunk.torso_hitbox, 2)
	sheriff._target = last
	_lobby_shoot_npc(sheriff, sheriff.torso_hitbox, 0)
	if not drunk.is_alive() or not is_equal_approx(drunk.health, 1.0) or drunk._target != sheriff \
			or not is_equal_approx(sheriff.health, 2.0) or sheriff._target != local \
			or duel.live_slots() != [0, 1, 2, 3] or not result.is_empty():
		_fail("lobby npcs: a torso hit should wound an NPC and turn it on its attacker (hp %.1f, %.1f)" % [
				drunk.health, sheriff.health])
		return false
	if PlayerSettings.gore_enabled and (drunk.corpse_body().chunk_count() != 1 or sheriff.corpse_body().chunk_count() != 1):
		_fail("lobby npcs: one hit cut %d holes in the host's NPC" % drunk.corpse_body().chunk_count())
		return false
	# A mid-duel NPC death.
	_lobby_shoot_npc(drunk, drunk.head_hitbox, 3)
	if drunk.is_alive() or deaths[0] != 1 or drunk.killed_by != 3 or duel.state != DuelManager.State.DRAW \
			or duel.live_slots() != [0, 2, 3] or not _says_left(3) or not result.is_empty():
		_fail("lobby npcs: the Drunk's death gave state %d, live %s, killer %d, message '%s'" % [
				duel.state, duel.live_slots(), drunk.killed_by, hud.message_label.text])
		return false
	if KillCam.is_playing or DeathCam.phase != DeathCam.Phase.IDLE or ReplayBuffer.death_time_of(1) < 0.0 \
			or GameManager.avatars.has(1) or GameManager.actor_node(1) != drunk or not drunk.corpse_body().has_corpse() \
			or not drunk.torso_hitbox.is_corpse() or drunk.revolver.held or drunk.revolver.get_parent() == drunk.arm:
		_fail("lobby npcs: a mid-duel NPC death should be a plain fall with a clip time and no kill cam")
		return false
	_lobby_shoot_npc(drunk, drunk.head_hitbox, 3)
	if deaths[0] != 1 or duel.live_slots() != [0, 2, 3] or not result.is_empty():
		_fail("lobby npcs: a hit on a dead NPC was not ignored")
		return false
	if PlayerSettings.gore_enabled and drunk.corpse_body().chunk_count() != 2:
		_fail("lobby npcs: two hits cut %d holes in the host's NPC" % drunk.corpse_body().chunk_count())
		return false
	# The host dies to the Sheriff: it spectates, and the NPCs it runs carry on.
	var head := local.get_head_position()
	local.take_bullet_hit(99.0, PackedVector3Array([head - Vector3.FORWARD, head]), CombatRules.REGION_HEAD,
			false, false, 2)
	if not result.is_empty() or duel.live_slots() != [2, 3] or local.alive or not _says_left(2) \
			or not DeathCam.is_spectating() or not DeathCam.blocks_combat() or DeathCam.blocks_npcs():
		_fail("lobby npcs: the host's death should leave the two NPCs fighting (live %s, phase %d)" % [
				duel.live_slots(), DeathCam.phase])
		return false
	if not await _wait_for(func() -> bool: return _watching(2), LOBBY_SPECTATE_HOLD + 3.0) \
			or not _orbit_on(DeathCam._chest(2), 0.3) or duel.slot_name(2) != sheriff.archetype.display_name:
		_fail("lobby npcs: the dead host should watch its killer, the Sheriff (on %d, label '%s')" % [
				DeathCam.spectate_target(), hud.spectate_tag.text])
		return false
	if sheriff._target != last or last._target != sheriff:
		_fail("lobby npcs: the two NPCs left should turn on each other")
		return false
	sheriff._timer = 0.0
	var drawing := func() -> bool:
		return sheriff.state == DuelistAI.AIState.DRAWING and sheriff.revolver.drawn and sheriff._draw_progress > 0.0
	if not await _wait_for(drawing, 2.0):
		_fail("lobby npcs: a spectating host froze its NPCs (state %d)" % sheriff.state)
		return false
	_lobby_park(sheriff)
	# An NPC's shot is the host's to resolve and carries its slot.
	var shots := ReplayBuffer._shots.size()
	sheriff._on_fired(sheriff.get_head_position() + Vector3.UP * 30.0, Vector3.UP)
	var bullets := get_tree().get_nodes_in_group(Bullet.GROUP)
	var slug: Bullet = bullets[0] if bullets.size() == 1 else null
	if slug == null or slug.shooter != 2 or not slug.authoritative or slug.from_local_player \
			or slug.exclude != sheriff.hitbox_rids() or ReplayBuffer._shots.size() != shots + 1 \
			or int(ReplayBuffer._shots[shots]["shooter"]) != 2:
		_fail("lobby npcs: an NPC's shot should be one authoritative bullet recorded under its slot")
		return false
	Bullet.clear_all()
	for want: int in [3, 2]:
		if not await _spectate_pull_ok(want, 0.3):
			return false
	# The last kill, NPC on NPC.
	_lobby_shoot_npc(last, last.head_hitbox, 2)
	if result != [false, "MSG_REASON_LAST_STANDING"] or duel.live_slots() != [2] \
			or duel.state != DuelManager.State.RESOLUTION:
		_fail("lobby npcs: the Sheriff should win as the last one standing (%s, live %s)" % [result, duel.live_slots()])
		return false
	if ReplayBuffer.killer_id != 2 or ReplayBuffer.victim_id != 3 or DeathCam.is_spectating() \
			or DeathCam.phase != DeathCam.Phase.FLYING or not KillCam.is_playing or not DeathCam.blocks_npcs() \
			or hud.spectate_tag.visible:
		_fail("lobby npcs: the last kill should run the kill cam for killer 2 over victim 3 (killer %d, victim %d, phase %d)" % [
				ReplayBuffer.killer_id, ReplayBuffer.victim_id, DeathCam.phase])
		return false
	for slot in 4:
		if net.roster.slots[slot]["wins"] != (1 if slot == 2 else 0):
			_fail("lobby npcs: only the Sheriff's slot should be tallied: %s" % net.roster.pack())
			return false
	if not sheriff.is_alive() or sheriff.state != DuelistAI.AIState.IDLE or last.is_alive() \
			or not last.corpse_body().has_corpse() or last.revolver.held or last.revolver.get_parent() == last.arm \
			or GameManager.actor_node(3) != last:
		_fail("lobby npcs: the finish should stand the winner down and leave the loser where it fell")
		return false
	if not await _wait_for(func() -> bool: return DeathCam.phase == DeathCam.Phase.PLAYBACK, 14.0):
		_fail("lobby npcs: the replay never started (sealed %s, phase %d)" % [ReplayBuffer.is_sealed, DeathCam.phase])
		return false
	var begin := ReplayBuffer.clip_begin()
	var first: Array = ReplayBuffer.sample_at(begin)
	if not ReplayBuffer.is_sealed or first.size() != 4 or ReplayBuffer.death_time_of(2) >= 0.0 \
			or first.any(func(pose: Dictionary) -> bool: return int(pose["flags"]) & ReplayBuffer.PRESENT == 0) \
			or DeathCam._retraced.has(2) or not DeathCam.blocks_npcs():
		_fail("lobby npcs: the last kill should seal a 4-actor clip (%d actors)" % first.size())
		return false
	for corpse: int in [0, 1, 3]:
		if ReplayBuffer.death_time_of(corpse) < begin or not DeathCam._retraced.has(corpse):
			_fail("lobby npcs: slot %d's fall is not in the clip (%.2f, clip from %.2f)" % [
					corpse, ReplayBuffer.death_time_of(corpse), begin])
			return false
	var early := drunk.corpse_body()
	var early_death := ReplayBuffer.death_time_of(1)
	if (early_death - DeathCam._play_t > 0.2 and early.corpse_state() != BodyRagdoll.State.RETRACE) \
			or (ReplayBuffer.death_time - DeathCam._play_t > 0.2 and last.corpse_body().corpse_state() != BodyRagdoll.State.RETRACE):
		_fail("lobby npcs: the NPC corpses do not stand up for the replay")
		return false
	if not await _wait_for(func() -> bool: return DeathCam._play_t >= early_death + 0.3, 12.0) \
			or DeathCam.phase != DeathCam.Phase.PLAYBACK or early.corpse_state() != BodyRagdoll.State.TRACK:
		_fail("lobby npcs: the Drunk's fall does not replay at its own time (state %d)" % early.corpse_state())
		return false
	local._on_trigger_changed(&"right_hand", true)
	local._on_trigger_changed(&"right_hand", false)
	await get_tree().process_frame
	await get_tree().process_frame
	if DeathCam.phase != DeathCam.Phase.TRAILING or DeathCam.blocks_npcs() or not DeathCam.blocks_combat():
		_fail("lobby npcs: the skip should leave the dead host on the trailing orbit (phase %d)" % DeathCam.phase)
		return false
	for corpse: int in [0, 1, 3]:
		if _corpse_of(corpse).corpse_state() != BodyRagdoll.State.HELD:
			_fail("lobby npcs: slot %d's corpse is not held after the replay (state %d)" % [
					corpse, _corpse_of(corpse).corpse_state()])
			return false
	print("AUTOTEST: lobby NPC duel ok (%s, %s, %s: no holster wait, rivals, wounds, _mp_down, spectating host, last standing, 4-actor clip)" % [
			duel.slot_name(1), duel.slot_name(2), duel.slot_name(3)])
	return true


## What a client makes of an NPC slot, staged on the host. Slot 1 is the Sheriff; slots 2
## and 3 are humans who never connect. First the host's NPC and a human's avatar: it may
## pick one, aims at its head, drops it once it is down, and turns on one that shoots it.
## Then a proxy avatar is stood up for slot 1, as a client has in place of the NPC. Voice
## never binds to it. `_npc_pose` / `_npc_shot` for any other slot do nothing. The NPC's
## own pose puts the proxy's head, body, and held gun where the NPC's are, hands at the
## hips and the wrist on the grip; a tossed gun follows the stream and a holstered one
## sits on the hip. A shot is one visual tracer at the archetype's speed. A replay sample
## applies by head, flags, and gun, twice over. The NPC's death drops the proxy through
## `_mp_chunk` / `_mp_down`, and a dead proxy takes no more poses or shots.
func _lobby_npc_proxy_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var local := GameManager.local_player
	if not _lobby_fill(4, {1: 1}) or not _lobby_start("npc proxy"):
		return false
	duel._enter(DuelManager.State.DRAW)
	var npc := GameManager.actor_node(1) as DuelistAI
	var human: RemoteAvatar = GameManager.avatars[2]
	var doomed: RemoteAvatar = GameManager.avatars[3]
	if npc == null or GameManager.avatars.size() != 2 or VoiceChat.bound_player(LOBBY_FAKE_PEERS[1]) != human.voice_player:
		_fail("lobby proxy: the duel did not start with one host NPC and two human avatars")
		return false
	_lobby_park(npc)
	var picked := _lobby_npc_picks(npc)
	var live := GameManager.live_duelists()
	if live.size() != 4 or not live.has(human) or picked.size() != 3 or not picked.has(human) \
			or not picked.has(doomed) or not picked.has(local):
		_fail("lobby proxy: the host's NPC should pick among the host and both humans' avatars (%d picked)" % picked.size())
		return false
	npc._target = doomed
	if not npc._target_head().is_equal_approx(doomed.get_head_position()):
		_fail("lobby proxy: an NPC does not aim at an avatar's head")
		return false
	_lobby_shoot_head(doomed, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	picked = _lobby_npc_picks(npc)
	if duel.live_slots() != [0, 1, 2] or npc._is_live(doomed) or GameManager.live_duelists().has(doomed) \
			or picked.size() != 2 or picked.has(doomed):
		_fail("lobby proxy: an NPC should drop an avatar that is down (live %s)" % [duel.live_slots()])
		return false
	npc._target = local
	_lobby_shoot_npc(npc, npc.torso_hitbox, 2)
	if npc._target != human or not is_equal_approx(npc.health, 2.0):
		_fail("lobby proxy: an NPC should turn on the human who shot it (hp %.1f)" % npc.health)
		return false
	# From here the host also stands in for a client: a proxy for slot 1 beside the real NPC.
	var proxy := GameManager._spawn_avatar(1, GameManager._mp_spawns(duel.snapshot)[1], true)
	GameManager._bind_voice()
	if GameManager.actor_node(1) != proxy or GameManager._npc_proxy(1) != proxy or GameManager._npc_proxy(2) != null \
			or not _voice_binds_ok("lobby proxy") or VoiceChat.bound_peers().size() != 2 \
			or VoiceChat.bound_player(LOBBY_FAKE_PEERS[1]) != human.voice_player or GameManager.live_duelists().has(proxy):
		_fail("lobby proxy: a proxy should stand for the NPC slot only, with no voice and no place among an NPC's targets")
		return false
	var none := Transform3D.IDENTITY
	var far := Transform3D(Basis.IDENTITY, Vector3(1.0, 1.6, 2.0))
	var human_head := human._target_head
	for slot: int in [-1, 0, 2, 3, 4]:
		GameManager._on_npc_pose_received(slot, far, NetworkManager.POSE_FLAG_GUN_DRAWN, none)
		GameManager._on_npc_shot_received(slot, Vector3(0.0, 50.0, 0.0), Vector3.UP)
	if human._has_pose or human._target_head != human_head or proxy._has_pose \
			or not get_tree().get_nodes_in_group(Bullet.GROUP).is_empty():
		_fail("lobby proxy: _npc_pose / _npc_shot for a slot that is no NPC should do nothing")
		return false
	# The NPC draws; its own stream drives the proxy.
	npc._timer = 0.0
	if not await _wait_for(func() -> bool: return npc.state == DuelistAI.AIState.DRAWING, 2.0):
		_fail("lobby proxy: the NPC never drew (state %d)" % npc.state)
		return false
	_lobby_park(npc)
	var pose := npc.capture_replay_pose()
	var pose_head: Transform3D = pose["head"]
	var pose_gun: Transform3D = pose["gun"]
	var pose_root: Transform3D = pose["root"]
	var hip := proxy._hip_hand(pose_head, true)
	GameManager._on_npc_pose_received(1, pose_head, pose["flags"], pose_gun)
	if not proxy._has_pose or not proxy._gun_drawn or proxy._gun_free or proxy.gun.get_parent() != proxy.right_hand \
			or not proxy._target_head.is_equal_approx(pose_head) or not proxy._target_right.is_equal_approx(hip) \
			or not proxy._target_gun.is_equal_approx(pose_gun):
		_fail("lobby proxy: the NPC's pose should give the proxy its head, a held gun, and hands at the hips")
		return false
	await _sleep(0.6)
	var grip := proxy.gun.find_child("GripAnchor", true, false) as Node3D
	var body := proxy._dummy.global_position
	var off_body := Vector2(body.x - pose_root.origin.x, body.z - pose_root.origin.z).length()
	if proxy.head.global_position.distance_to(pose_head.origin) > 0.02 or proxy.gun.global_position.distance_to(pose_gun.origin) > 0.02 \
			or proxy.right_hand.global_position.distance_to(hip.origin) > 0.02 or off_body > 0.03 \
			or grip == null or proxy._snap_r.global_position.distance_to(grip.global_position) > 0.02:
		_fail("lobby proxy: the proxy did not settle on the NPC's head, body (%.2f m off), and gun, wrist on the grip" % off_body)
		return false
	var tossed := pose_gun.translated(Vector3.UP * 0.6)
	GameManager._on_npc_pose_received(1, pose_head,
			NetworkManager.POSE_FLAG_GUN_DRAWN | NetworkManager.POSE_FLAG_GUN_FREE, tossed)
	if not proxy._gun_free or proxy._gun_steadied or proxy.gun.get_parent() != proxy or not proxy._target_gun.is_equal_approx(tossed):
		_fail("lobby proxy: a tossed gun should leave the hand and follow the stream")
		return false
	GameManager._on_npc_pose_received(1, pose_head, 0, pose_gun)
	if proxy._gun_drawn or proxy._gun_free or proxy.gun.get_parent() != proxy.holster:
		_fail("lobby proxy: a gun that is not drawn should sit on the hip")
		return false
	GameManager._on_npc_shot_received(1, Vector3(0.0, 50.0, 0.0), Vector3.UP)
	var bullets := get_tree().get_nodes_in_group(Bullet.GROUP)
	var tracer: Bullet = bullets[0] if bullets.size() == 1 else null
	if tracer == null or tracer.shooter != 1 or tracer.authoritative or tracer.from_local_player \
			or tracer.exclude != proxy.hitbox_rids() or not is_equal_approx(tracer.speed, npc.archetype.bullet_speed):
		_fail("lobby proxy: _npc_shot should spawn one visual tracer that skips the proxy")
		return false
	Bullet.clear_all()
	# A replay sample is the host's `DuelistAI.capture_replay_pose`; what the proxy stashes
	# before a replay goes back on unchanged.
	var sample := npc.capture_replay_pose()
	var sample_head: Transform3D = sample["head"]
	var sample_gun: Transform3D = sample["gun"]
	var sample_arm: Transform3D = sample["right"]
	hip = proxy._hip_hand(sample_head, true)
	for pass_index in 2:
		proxy.apply_replay_pose(sample if pass_index == 0 else proxy.capture_replay_pose())
		if not proxy.replay_locked or not proxy.head.global_transform.is_equal_approx(sample_head) \
				or proxy.right_hand.global_position.distance_to(hip.origin) > 0.001 \
				or proxy.right_hand.global_position.distance_to(sample_arm.origin) < 0.05 \
				or proxy.gun.global_position.distance_to(sample_gun.origin) > 0.001 or not proxy._gun_drawn:
			_fail("lobby proxy: a replay sample should apply by head, flags, and gun only (pass %d)" % pass_index)
			return false
	proxy.clear_replay_pose()
	# The NPC dies: on a client the proxy is the body that is cut and falls.
	var result := _arm_duel_listener()
	_lobby_shoot_npc(npc, npc.head_hitbox, 0)
	if npc.is_alive() or duel.live_slots() != [0, 2] or duel.state != DuelManager.State.DRAW or not result.is_empty() \
			or not _says_left(2):
		_fail("lobby proxy: the NPC's death should be a mid-duel _mp_down (live %s)" % [duel.live_slots()])
		return false
	if not proxy.is_dead() or not proxy._dummy.has_corpse() or not proxy.torso_hitbox.is_corpse() \
			or proxy.is_ancestor_of(proxy.gun) or not DeathCam.blocks_remote_pose(1):
		_fail("lobby proxy: _mp_down should drop the proxy and its gun")
		return false
	if PlayerSettings.gore_enabled and (not _has_head_cut(proxy._dummy) or proxy._dummy.chunk_count() != 1):
		_fail("lobby proxy: _mp_chunk should cut the proxy's head (%d holes)" % proxy._dummy.chunk_count())
		return false
	var settled := proxy._target_head
	# The tracer cleared above is only freed at the end of this frame.
	var flying := get_tree().get_nodes_in_group(Bullet.GROUP).size()
	GameManager._on_npc_pose_received(1, far, 0, none)
	GameManager._on_npc_shot_received(1, Vector3(0.0, 50.0, 0.0), Vector3.UP)
	if proxy._target_head != settled or get_tree().get_nodes_in_group(Bullet.GROUP).size() != flying:
		_fail("lobby proxy: a dead proxy should take no more poses or shots")
		return false
	if not net.host_back_to_lobby() or not GameManager.in_mp_lobby() or DeathCam.phase != DeathCam.Phase.IDLE \
			or not GameManager.current_ais.is_empty() or GameManager.avatars.size() != 2:
		_fail("lobby proxy: the waiting room should clear the NPC and its proxy")
		return false
	print("AUTOTEST: lobby NPC proxy ok (avatar targets, non-NPC slots rejected, pose / toss / holster, tracer, replay sample, fall)")
	return true


## `_npc_pose` / `_npc_shot` reach the game only inside a session.
func _lobby_npc_gate_ok(in_session: bool) -> bool:
	var heard := [0]
	var on_pose := func(_slot: int, _head: Transform3D, _flags: int, _gun: Transform3D) -> void: heard[0] += 1
	var on_shot := func(_slot: int, _origin: Vector3, _direction: Vector3) -> void: heard[0] += 1
	NetworkManager.npc_pose_received.connect(on_pose)
	NetworkManager.npc_shot_received.connect(on_shot)
	NetworkManager._npc_pose(1, Transform3D.IDENTITY, 0, Transform3D.IDENTITY)
	NetworkManager._npc_shot(1, Vector3.ZERO, Vector3.UP)
	NetworkManager.npc_pose_received.disconnect(on_pose)
	NetworkManager.npc_shot_received.disconnect(on_shot)
	if NetworkManager.is_active() != in_session or heard[0] != (2 if in_session else 0):
		_fail("lobby npcs: _npc_pose / _npc_shot were heard %d times %s a session" % [
				heard[0], "in" if in_session else "outside"])
		return false
	print("AUTOTEST: _npc_pose / _npc_shot gate ok %s a session" % ("in" if in_session else "outside"))
	return true


## `DeathCam.blocks_npcs()` by phase. In a session only the fly-along and the replay stop
## the NPCs, whoever died. Single player: also the dead player's orbit, where it matches
## `blocks_combat()` as before.
func _lobby_npc_block_ok(in_session: bool) -> bool:
	if DeathCam.phase != DeathCam.Phase.IDLE or NetworkManager.is_active() != in_session:
		_fail("lobby npcs: not idle %s a session (phase %d)" % ["in" if in_session else "outside", DeathCam.phase])
		return false
	var saved_victim := ReplayBuffer.victim_id
	var local := GameManager.local_actor_id()
	var wrong := ""
	for local_dies: bool in [true, false]:
		ReplayBuffer.victim_id = local if local_dies else local + 1
		for phase: int in DeathCam.Phase.values():
			var want := phase == DeathCam.Phase.FLYING or phase == DeathCam.Phase.PLAYBACK
			if not in_session and local_dies and (phase == DeathCam.Phase.ORBIT or phase == DeathCam.Phase.TRAILING):
				want = true
			DeathCam.phase = phase
			var matches_combat := in_session or phase == DeathCam.Phase.SPECTATE \
					or DeathCam.blocks_npcs() == DeathCam.blocks_combat()
			if DeathCam.blocks_npcs() != want or not matches_combat:
				wrong = "phase %d, local victim %s" % [phase, local_dies]
	DeathCam.phase = DeathCam.Phase.IDLE
	ReplayBuffer.victim_id = saved_victim
	if not wrong.is_empty():
		_fail("lobby npcs: blocks_npcs() is wrong %s a session (%s)" % ["in" if in_session else "outside", wrong])
		return false
	print("AUTOTEST: DeathCam.blocks_npcs ok %s a session" % ("in" if in_session else "outside"))
	return true


# -- Lobby page ----------------------------------------------------------------------

## Every body standing in the waiting room is on its slot's point of the ring for the
## roster's slot count, whether or not the lobby is full.
func _lobby_ring_ok(tag: String) -> bool:
	var roster := NetworkManager.roster
	var spawns := GameManager.current_scenario.get_duel_spawns(roster.slots.size())
	var seen := 0
	for slot in roster.slots.size():
		var node := GameManager.actor_node(slot)
		if node == null:
			continue
		seen += 1
		if node.global_position.distance_to(spawns[slot].origin) > 0.05:
			_fail("%s: slot %d stands %s, its ring point is %s" % [tag, slot, node.global_position, spawns[slot].origin])
			return false
	if seen != roster.count_kind(LobbyRoster.Kind.HUMAN):
		_fail("%s: %d bodies stand for %d humans" % [tag, seen, roster.count_kind(LobbyRoster.Kind.HUMAN)])
		return false
	return true


## Picks `index` in an option button the way a click does.
func _pick(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


## The Lobby page of the pause overlay, driven only through its own controls: the pickers
## call the host API and the roster follows, the host's own side button, START and BACK TO
## LOBBY, Kick held while a duel runs, the refusal text under START, the per-side wins
## derived from the slots, and the page rebuilding itself on `roster_changed` and on the
## duel's state. The setup is remembered for the next host.
func _lobby_page_ok() -> bool:
	var net := NetworkManager
	var roster := net.roster
	var duel := GameManager.duel
	var pause := GameManager.hud.pause_menu
	var panel := pause.lobby_panel
	var host_name: String = roster.slots[0]["name"]
	if not _lobby_fill(3):
		return false
	pause.open()
	pause.show_lobby()
	var rows := panel.rows
	# A full free-for-all of three: START waits, nothing is refused, no side to pick.
	if rows.size() != 3 or not panel.start_button.visible or panel.start_button.disabled \
			or panel.back_to_lobby_button.visible or panel.my_side_button.visible or panel.team_wins_label.visible \
			or panel.status_label.visible or panel.slot_count_option.disabled or panel.mode_option.disabled \
			or panel.arena_option.disabled or pause.restart_button.visible:
		_fail("lobby page: a full waiting room should offer an enabled START and the host's pickers")
		return false
	if rows[0]["name"].text != tr("LOBBY_YOU") % host_name or rows[1]["name"].text != "Ann" or rows[2]["name"].text != "Bob" \
			or rows[0]["kick"] != null or rows[1]["kick"] == null or rows[2]["kick"] == null \
			or rows[1]["kick"].disabled or rows[1]["side"] != null or rows[1]["wins"].text != tr("LOBBY_WINS") % 0 \
			or rows[1]["kind_option"] != null or rows[1]["kind"].text != tr("LOBBY_KIND_HUMAN"):
		_fail("lobby page: the rows should name the host (you), Ann and Bob, with a Kick on the joiners only")
		return false
	for slot in 3:
		if not (rows[slot]["chip"] as ColorRect).color.is_equal_approx(LobbyRoster.SLOT_TINTS[slot]):
			_fail("lobby page: slot %d's chip is not its slot colour" % slot)
			return false
	# Two duelists would drop Bob's slot: that count is shown as refused.
	if not panel.slot_count_option.is_item_disabled(0) or panel.slot_count_option.is_item_disabled(1) \
			or panel.slot_count_option.selected != 1:
		_fail("lobby page: the slot count should refuse a count that drops an occupied slot")
		return false
	_pick(panel.slot_count_option, 0)
	if roster.slots.size() != 3 or panel.slot_count_option.selected != 1 or panel.rows.size() != 3:
		_fail("lobby page: lowering the slot count onto Bob should do nothing (%d slots)" % roster.slots.size())
		return false
	# More slots: the room re-forms on the four-point ring with everyone on their slot's point.
	_pick(panel.slot_count_option, 2)
	rows = panel.rows
	if roster.slots.size() != 4 or rows.size() != 4 or rows[3]["name"].text != tr("LOBBY_OPEN") or rows[3]["kind_option"] == null \
			or rows[3]["kind_option"].selected != 0 or rows[3]["archetype_option"] != null or rows[3]["wins"] != null \
			or not panel.start_button.disabled or panel.status_label.text != tr("MSG_LOBBY_NOT_FULL"):
		_fail("lobby page: a fourth, open slot should hold START with the lobby-not-full line")
		return false
	if not _lobby_ring_ok("lobby page, raised to 4 slots"):
		return false
	# An open slot becomes an NPC, then picks its archetype; Mixed maps both ways.
	_pick(rows[3]["kind_option"], 1)
	rows = panel.rows
	if roster.slots[3]["kind"] != LobbyRoster.Kind.NPC or roster.slots[3]["archetype"] != LobbyRoster.ARCHETYPE_MIXED \
			or rows[3]["archetype_option"] == null or rows[3]["archetype_option"].selected != GameManager.ARCHETYPES.size() \
			or rows[3]["name"].text != tr("MENU_ENEMY_MIXED") or panel.start_button.disabled or panel.status_label.visible:
		_fail("lobby page: an NPC slot should start as Mixed and let START through")
		return false
	_pick(rows[3]["archetype_option"], 1)
	rows = panel.rows
	if roster.slots[3]["archetype"] != 1 or rows[3]["name"].text != GameManager.archetype_at(1).display_name \
			or rows[3]["archetype_option"].selected != 1:
		_fail("lobby page: picking archetype 1 gave %d" % roster.slots[3]["archetype"])
		return false
	_pick(rows[3]["archetype_option"], GameManager.ARCHETYPES.size())
	rows = panel.rows
	if roster.slots[3]["archetype"] != LobbyRoster.ARCHETYPE_MIXED or rows[3]["name"].text != tr("MENU_ENEMY_MIXED") \
			or rows[3]["archetype_option"].selected != GameManager.ARCHETYPES.size():
		_fail("lobby page: picking Mixed gave %d" % roster.slots[3]["archetype"])
		return false
	_pick(rows[3]["kind_option"], 0)
	if roster.slots[3]["kind"] != LobbyRoster.Kind.OPEN or not panel.start_button.disabled:
		_fail("lobby page: the NPC slot did not go back to open")
		return false
	_pick(panel.rows[3]["kind_option"], 1)
	# The arena moves everyone now: the waiting room is the arena.
	_pick(panel.arena_option, 1)
	if roster.scenario_index != 1 or GameManager.current_scenario_index != 1 or not _lobby_room_ok("lobby page, arena 1"):
		_fail("lobby page: the arena picker did not move the waiting room")
		return false
	# Teams: a side button for the host, side labels, an NPC side picker, derived wins.
	_pick(panel.mode_option, 1)
	rows = panel.rows
	if roster.mode != LobbyRoster.Mode.TEAMS or not panel.my_side_button.visible or not panel.team_wins_label.visible \
			or panel.my_side_button.text != tr("LOBBY_MY_SIDE") % tr("LOBBY_SIDE_RED") \
			or rows[1]["side"].text != tr("LOBBY_SIDE_BLUE") or rows[3]["side_option"] == null or rows[1]["side_option"] != null \
			or panel.team_wins_label.text != tr("LOBBY_TEAM_WINS") % [0, 0] or _roster_sides(roster) != [0, 1, 0, 1]:
		_fail("lobby page: Teams should show the side button, side labels, and an NPC side picker")
		return false
	panel.my_side_button.pressed.emit()
	if _roster_sides(roster) != [1, 1, 0, 1] or panel.my_side_button.text != tr("LOBBY_MY_SIDE") % tr("LOBBY_SIDE_BLUE") \
			or panel.rows[0]["side"].text != tr("LOBBY_SIDE_BLUE") or not _lobby_room_ok("lobby page, host on blue"):
		_fail("lobby page: the host's side button did not move its own side (%s)" % [_roster_sides(roster)])
		return false
	# Bob picks blue too (what his `_request_side` runs): the NPC is the last on red, then moved.
	net._apply_side(2, 1)
	if _roster_sides(roster) != [1, 1, 1, 1] or not panel.start_button.disabled \
			or panel.status_label.text != tr("MSG_LOBBY_EMPTY_SIDE"):
		_fail("lobby page: START should refuse an empty side with its line (%s)" % [_roster_sides(roster)])
		return false
	_pick(panel.rows[3]["side_option"], 0)
	if _roster_sides(roster) != [1, 1, 1, 0] or panel.start_button.disabled or panel.status_label.visible:
		_fail("lobby page: the NPC's side picker did not fill the empty side (%s)" % [_roster_sides(roster)])
		return false
	# The tally is per slot; each side's figure is derived. A win for blue, then Bob moves to red
	# and blue wins again without him.
	net.host_add_wins([0, 1, 2])
	rows = panel.rows
	if panel.team_wins_label.text != tr("LOBBY_TEAM_WINS") % [0, 1] or rows[2]["wins"].text != tr("LOBBY_WINS") % 1 \
			or rows[3]["wins"].text != tr("LOBBY_WINS") % 0:
		_fail("lobby page: after a blue win the tally reads '%s'" % panel.team_wins_label.text)
		return false
	net._apply_side(2, 0)
	net.host_add_wins([0, 1])
	if panel.team_wins_label.text != tr("LOBBY_TEAM_WINS") % [1, 2] or LobbyPanel.side_wins(roster, 0) != 1 \
			or LobbyPanel.side_wins(roster, 1) != 2:
		_fail("lobby page: the derived per-side wins read '%s'" % panel.team_wins_label.text)
		return false
	# The page follows the roster without being told.
	roster.slots[1]["name"] = "Zed"
	net._sync_roster()
	if panel.rows[1]["name"].text != "Zed":
		_fail("lobby page: the rows did not rebuild on roster_changed")
		return false
	# What the host set is the next session's setup; the humans are not.
	if PlayerSettings.lobby_slot_count != 4 or PlayerSettings.lobby_mode != LobbyRoster.Mode.TEAMS \
			or PlayerSettings.lobby_scenario != 1 or PlayerSettings.lobby_kinds[1] != LobbyRoster.Kind.OPEN \
			or PlayerSettings.lobby_kinds[3] != LobbyRoster.Kind.NPC or PlayerSettings.lobby_sides[3] != 0:
		_fail("lobby page: the host's edits were not remembered for the next session")
		return false
	# START, through the page. It closes the menu and the duel runs on the snapshot.
	panel.start_button.pressed.emit()
	if pause.is_open or duel.state != DuelManager.State.STANDOFF or not duel.is_team_duel():
		_fail("lobby page: START should start the Teams duel and close the menu (state %d)" % duel.state)
		return false
	duel._holstered.fill(true)
	pause.open()
	pause.show_lobby()
	rows = panel.rows
	if panel.start_button.visible or not panel.back_to_lobby_button.visible or rows[1]["kick"] == null \
			or not rows[1]["kick"].disabled or not rows[2]["kick"].disabled:
		_fail("lobby page: during a duel BACK TO LOBBY replaces START and Kick is held")
		return false
	# A roster edit during the duel changes the page and leaves the duel on its snapshot.
	_pick(panel.mode_option, 0)
	if panel.mode_option.selected != 0 or panel.rows[1]["side"] != null or not duel.is_team_duel() \
			or duel.snapshot.mode != LobbyRoster.Mode.TEAMS:
		_fail("lobby page: a mode change during the duel should show on the page and wait for the next duel")
		return false
	panel.back_to_lobby_button.pressed.emit()
	if not GameManager.in_mp_lobby() or not panel.start_button.visible or panel.back_to_lobby_button.visible \
			or panel.rows[1]["kick"] == null or panel.rows[1]["kick"].disabled:
		_fail("lobby page: BACK TO LOBBY did not return to the waiting room with START and Kick back")
		return false
	if not _lobby_room_ok("lobby page, back in the waiting room"):
		return false
	# Kick, in the waiting room: the joiner's slot reopens and the host is told it went.
	var kicked_name: String = roster.slots[2]["name"]
	panel.rows[2]["kick"].pressed.emit()
	if roster.slots[2]["kind"] != LobbyRoster.Kind.OPEN or roster.slots[1]["kind"] != LobbyRoster.Kind.HUMAN \
			or GameManager.hud.message_label.text != tr("MSG_LOBBY_KICKED") % kicked_name or panel.rows[2]["kick"] != null \
			or panel.rows[2]["name"].text != tr("LOBBY_OPEN") or not panel.start_button.disabled:
		_fail("lobby page: Kick should reopen Bob's slot and name him ('%s')" % GameManager.hud.message_label.text)
		return false
	# The page is the same one the host's menu reaches through its Lobby button.
	pause.show_pause_root()
	if not pause.lobby_button.visible or pause.lobby_page.visible:
		_fail("lobby page: the pause root should offer a Lobby button")
		return false
	pause.lobby_button.pressed.emit()
	if not pause.is_lobby_open() or pause.pause_root.visible or not pause.is_subpage_open():
		_fail("lobby page: the Lobby button did not open the page")
		return false
	pause.close()
	print("AUTOTEST: lobby page ok (pickers, side button, START / BACK TO LOBBY, Kick held, derived wins, rebuilds)")
	return true


## The Lobby page opens by itself for the host: when the lobby fills, once per event, never
## over a page that is open and never during a duel.
func _lobby_auto_open_ok() -> bool:
	var net := NetworkManager
	var roster := net.roster
	var pause := GameManager.hud.pause_menu
	if not _lobby_fill(3):
		return false
	roster.vacate_peer(LOBBY_FAKE_PEERS[1], false)
	net._sync_roster()
	pause.close()
	pause.auto_open_lobby = true
	await get_tree().process_frame
	if pause.is_open:
		_fail("lobby auto-open: the page opened with a slot still open")
		return false
	roster.assign_peer(LOBBY_FAKE_PEERS[1], "Bob")
	net._sync_roster()
	await get_tree().process_frame
	if not pause.is_open or not pause.is_lobby_open():
		_fail("lobby auto-open: the page did not open when the lobby filled")
		return false
	# The player shut it: edits that fill nothing new do not bring it back.
	pause.close()
	net.host_set_mode(LobbyRoster.Mode.TEAMS)
	net.host_set_mode(LobbyRoster.Mode.FFA)
	await get_tree().process_frame
	if pause.is_open:
		_fail("lobby auto-open: the page came back with no new event")
		return false
	# The next event does not take over a menu that is already open on another page.
	roster.vacate_peer(LOBBY_FAKE_PEERS[1], false)
	net._sync_roster()
	pause.open()
	roster.assign_peer(LOBBY_FAKE_PEERS[1], "Bob")
	net._sync_roster()
	await get_tree().process_frame
	if not pause.is_open or pause.is_lobby_open():
		_fail("lobby auto-open: an open menu was switched to the Lobby page")
		return false
	pause.close()
	# Never during a duel.
	if not _lobby_start("auto-open"):
		return false
	roster.vacate_peer(LOBBY_FAKE_PEERS[1], false)
	net._sync_roster()
	roster.assign_peer(LOBBY_FAKE_PEERS[1], "Bob")
	net._sync_roster()
	await get_tree().process_frame
	var opened := pause.is_open
	pause.auto_open_lobby = false
	if opened:
		_fail("lobby auto-open: the page opened during a live duel")
		return false
	if not net.host_back_to_lobby():
		return false
	print("AUTOTEST: lobby page auto-opens once per event, never over a page or in a duel")
	return true


## A new session opens the host's Lobby page.
func _lobby_session_open_ok() -> bool:
	var pause := GameManager.hud.pause_menu
	pause.auto_open_lobby = true
	if NetworkManager.host_lan() != OK:
		_fail("lobby auto-open: could not host again")
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var opened := pause.is_open and pause.is_lobby_open()
	pause.close()
	pause.auto_open_lobby = false
	NetworkManager.leave("autotest")
	if not opened:
		_fail("lobby auto-open: the Lobby page did not open with the session")
		return false
	print("AUTOTEST: lobby page opens with the session")
	return true


## The VR spectate tag hangs on the spectator camera, not on the player's rig. Staged: a
## camera stands in for the XR one.
func _lobby_vr_spectate_tag_ok() -> bool:
	var camera := XRCamera3D.new()
	add_child(camera)
	var saved_vr := GameManager.is_vr
	GameManager.is_vr = true
	DeathCam._spectator_cam = camera
	DeathCam._show_spectate_label("Watching Ann")
	var label := DeathCam._spectate_label
	var shown := is_instance_valid(label) and label.get_parent() == camera and label.text == "Watching Ann"
	DeathCam._show_spectate_label("Watching Bob")
	var replaced := is_instance_valid(DeathCam._spectate_label) and DeathCam._spectate_label.text == "Watching Bob" \
			and camera.get_child_count() >= 1
	DeathCam._clear_spectate()
	var cleared := DeathCam._spectate_label == null
	GameManager.is_vr = saved_vr
	DeathCam._spectator_cam = null
	camera.queue_free()
	if not shown or not replaced or not cleared:
		_fail("lobby: the VR spectate tag should hang on the spectator camera (shown %s, replaced %s, cleared %s)" % [
				shown, replaced, cleared])
		return false
	print("AUTOTEST: VR spectate tag sits on the spectator camera")
	return true


## What the saved host setup was when this process began, so a run leaves it as found.
var _saved_lobby_setup := {}


func _lobby_setup_snapshot() -> Dictionary:
	return {
		"count": PlayerSettings.lobby_slot_count, "mode": PlayerSettings.lobby_mode,
		"scenario": PlayerSettings.lobby_scenario, "kinds": PlayerSettings.lobby_kinds.duplicate(),
		"archetypes": PlayerSettings.lobby_archetypes.duplicate(), "sides": PlayerSettings.lobby_sides.duplicate(),
	}


## Puts a `_lobby_setup_snapshot()` back, in memory and on disk, if it differs.
func _apply_lobby_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or _lobby_setup_snapshot() == snapshot:
		return
	PlayerSettings.lobby_slot_count = snapshot["count"]
	PlayerSettings.lobby_mode = snapshot["mode"]
	PlayerSettings.lobby_scenario = snapshot["scenario"]
	PlayerSettings.lobby_kinds.assign(snapshot["kinds"])
	PlayerSettings.lobby_archetypes.assign(snapshot["archetypes"])
	PlayerSettings.lobby_sides.assign(snapshot["sides"])
	PlayerSettings._save_config()


## `[lobby]` in settings.cfg: the first-run default, a round trip through a file, and bad
## values clamped on load. The real settings file is not touched (a temp path is).
func _lobby_settings_ok() -> bool:
	var first: Node = (load("res://autoload/player_settings.gd") as GDScript).new()
	var roster := LobbyRoster.new()
	first.fill_lobby_setup(roster)
	if first.lobby_slot_count != 2 or first.lobby_mode != LobbyRoster.Mode.FFA or roster.slots.size() != 2 \
			or roster.mode != LobbyRoster.Mode.FFA or roster.count_kind(LobbyRoster.Kind.NPC) != 0 \
			or roster.open_human_slots() != 1:
		first.free()
		_fail("lobby settings: a first run should be 2 slots, free-for-all, no NPCs")
		return false
	first.free()
	var path := "user://autotest_lobby.cfg"
	var want := LobbyRoster.new()
	want.mode = LobbyRoster.Mode.TEAMS
	want.scenario_index = GameManager.SCENARIOS.size() - 1
	want.set_slot_count(LobbyRoster.max_slots())
	want.set_slot_kind(1, LobbyRoster.Kind.NPC)
	want.set_archetype(1, GameManager.ARCHETYPES.size() - 1)
	want.set_side(1, 0)
	want.set_slot_kind(2, LobbyRoster.Kind.NPC)
	want.set_archetype(2, LobbyRoster.ARCHETYPE_MIXED)
	want.set_side(2, 1)
	want.assign_peer(2001, "Ann")
	var before := _lobby_setup_snapshot()
	PlayerSettings.set_lobby_setup(want)
	var saved := _lobby_setup_snapshot()
	PlayerSettings._save_config(path)
	PlayerSettings.lobby_slot_count = 3
	PlayerSettings.lobby_mode = LobbyRoster.Mode.FFA
	PlayerSettings.lobby_kinds[1] = LobbyRoster.Kind.OPEN
	PlayerSettings.lobby_archetypes[2] = 0
	PlayerSettings.lobby_sides[2] = 0
	PlayerSettings._load_config(path)
	var loaded := _lobby_setup_snapshot()
	var back := LobbyRoster.new()
	PlayerSettings.fill_lobby_setup(back)
	if loaded != saved or saved["count"] != LobbyRoster.max_slots() or saved["mode"] != LobbyRoster.Mode.TEAMS \
			or saved["kinds"][1] != LobbyRoster.Kind.NPC or saved["kinds"][3] != LobbyRoster.Kind.OPEN \
			or saved["archetypes"][1] != GameManager.ARCHETYPES.size() - 1 or saved["archetypes"][2] != LobbyRoster.ARCHETYPE_MIXED \
			or saved["sides"][1] != 0 or saved["sides"][2] != 1 or back.pack() != _lobby_filled_pack(want):
		_fail("lobby settings: the setup did not survive a round trip (%s -> %s)" % [saved, loaded])
		return false
	# Bad values: the same clamps the other picks get, and no human survives.
	var cfg := ConfigFile.new()
	cfg.set_value("lobby", "slots", 99)
	cfg.set_value("lobby", "mode", 7)
	cfg.set_value("lobby", "scenario", 99)
	cfg.set_value("lobby", "kind_1", LobbyRoster.Kind.HUMAN)
	cfg.set_value("lobby", "archetype_1", 99)
	cfg.set_value("lobby", "side_1", 5)
	cfg.set_value("lobby", "kind_2", -3)
	cfg.set_value("lobby", "archetype_2", -9)
	cfg.set_value("lobby", "side_2", -1)
	cfg.set_value("lobby", "kind_3", LobbyRoster.Kind.NPC)
	cfg.save(path)
	PlayerSettings._load_config(path)
	var bad := _lobby_setup_snapshot()
	if bad["count"] != LobbyRoster.max_slots() or bad["mode"] != LobbyRoster.Mode.FFA \
			or bad["scenario"] != GameManager.SCENARIOS.size() - 1 or bad["kinds"][1] != LobbyRoster.Kind.OPEN \
			or bad["kinds"][2] != LobbyRoster.Kind.OPEN or bad["kinds"][3] != LobbyRoster.Kind.NPC \
			or bad["archetypes"][1] != GameManager.ARCHETYPES.size() - 1 or bad["archetypes"][2] != LobbyRoster.ARCHETYPE_MIXED \
			or bad["sides"][1] != 1 or bad["sides"][2] != 0:
		_fail("lobby settings: bad saved values were not clamped (%s)" % [bad])
		return false
	cfg.set_value("lobby", "slots", 0)
	cfg.save(path)
	PlayerSettings._load_config(path)
	if PlayerSettings.lobby_slot_count != LobbyRoster.MIN_SLOTS:
		_fail("lobby settings: a slot count of 0 loaded as %d" % PlayerSettings.lobby_slot_count)
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_apply_lobby_snapshot(before)
	print("AUTOTEST: [lobby] settings ok (first-run default, round trip, clamps)")
	return true


## The roster a saved setup fills: `want` with its human gone.
func _lobby_filled_pack(want: LobbyRoster) -> Dictionary:
	var expected := LobbyRoster.new()
	expected.unpack(want.pack())
	for slot in range(1, expected.slots.size()):
		if expected.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN:
			expected.open_slot(slot)
	return expected.pack()


## The setup block on the Multiplayer page: its pickers, slot rows that follow the slot
## count, a side picker only in Teams, Mixed mapped both ways, every edit remembered, and
## HOST applying the saved setup to the roster it opens.
func _lobby_setup_ok() -> bool:
	var before := _lobby_setup_snapshot()
	for slot in range(1, LobbyRoster.MAX_SLOTS):
		PlayerSettings.lobby_kinds[slot] = LobbyRoster.Kind.OPEN
		PlayerSettings.lobby_archetypes[slot] = LobbyRoster.ARCHETYPE_MIXED
		PlayerSettings.lobby_sides[slot] = slot % 2
	PlayerSettings.lobby_slot_count = LobbyRoster.MIN_SLOTS
	PlayerSettings.lobby_mode = LobbyRoster.Mode.FFA
	PlayerSettings.lobby_scenario = 0
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	menu.get_node("%MultiplayerButton").pressed.emit()
	var panel: LobbyPanel = menu.lobby_setup
	var mixed := GameManager.ARCHETYPES.size()
	if LobbyPanel.archetype_to_index(LobbyRoster.ARCHETYPE_MIXED) != mixed or LobbyPanel.archetype_to_index(1) != 1 \
			or LobbyPanel.index_to_archetype(mixed) != LobbyRoster.ARCHETYPE_MIXED or LobbyPanel.index_to_archetype(1) != 1:
		menu.queue_free()
		_fail("lobby setup: Mixed does not map between the single-player picker and the roster")
		return false
	if panel.use != LobbyPanel.Use.SETUP or panel.slot_count_option.item_count != LobbyRoster.max_slots() - 1 \
			or panel.mode_option.item_count != 2 or panel.arena_option.item_count != GameManager.SCENARIOS.size() \
			or panel.slot_count_option.selected != 0 or panel.mode_option.selected != 0 or panel.arena_option.selected != 0 \
			or panel.rows.size() != 1 or panel.rows[0]["kind_option"].selected != 0 or panel.rows[0]["archetype_option"] != null \
			or panel.rows[0]["side_option"] != null or panel.start_button.visible or panel.back_to_lobby_button.visible \
			or panel.my_side_button.visible or panel.slot_count_option.disabled:
		menu.queue_free()
		_fail("lobby setup: the block should open on the first-run setup, one slot to fill")
		return false
	# Slot rows follow the slot count.
	_pick(panel.slot_count_option, LobbyRoster.max_slots() - LobbyRoster.MIN_SLOTS)
	if panel.rows.size() != LobbyRoster.max_slots() - 1 or PlayerSettings.lobby_slot_count != LobbyRoster.max_slots():
		menu.queue_free()
		_fail("lobby setup: the slot rows did not follow the slot count (%d rows)" % panel.rows.size())
		return false
	_pick(panel.slot_count_option, 1)
	if panel.rows.size() != 2 or PlayerSettings.lobby_slot_count != 3:
		menu.queue_free()
		_fail("lobby setup: three duelists should be two slot rows (%d rows)" % panel.rows.size())
		return false
	# A slot becomes an NPC: its archetype picker appears on Mixed, and each pick lands.
	_pick(panel.rows[0]["kind_option"], 1)
	var picker: OptionButton = panel.rows[0]["archetype_option"]
	if PlayerSettings.lobby_kinds[1] != LobbyRoster.Kind.NPC or picker == null or picker.selected != mixed \
			or picker.item_count != mixed + 1 or panel.rows[1]["archetype_option"] != null:
		menu.queue_free()
		_fail("lobby setup: an NPC slot should show an archetype picker on Mixed")
		return false
	_pick(picker, 1)
	if PlayerSettings.lobby_archetypes[1] != 1 or panel.rows[0]["archetype_option"].selected != 1:
		menu.queue_free()
		_fail("lobby setup: picking archetype 1 saved %d" % PlayerSettings.lobby_archetypes[1])
		return false
	_pick(panel.rows[0]["archetype_option"], mixed)
	if PlayerSettings.lobby_archetypes[1] != LobbyRoster.ARCHETYPE_MIXED or panel.rows[0]["archetype_option"].selected != mixed:
		menu.queue_free()
		_fail("lobby setup: picking Mixed saved %d" % PlayerSettings.lobby_archetypes[1])
		return false
	# Sides are a Teams matter, and only an NPC's is the host's to set.
	if panel.rows[0]["side_option"] != null:
		menu.queue_free()
		_fail("lobby setup: a side picker showed in free-for-all")
		return false
	_pick(panel.mode_option, 1)
	if PlayerSettings.lobby_mode != LobbyRoster.Mode.TEAMS or panel.rows[0]["side_option"] == null \
			or panel.rows[1]["side_option"] != null:
		menu.queue_free()
		_fail("lobby setup: Teams should add a side picker to the NPC slot only")
		return false
	_pick(panel.rows[0]["side_option"], 0)
	if PlayerSettings.lobby_sides[1] != 0 or panel.rows[0]["side_option"].selected != 0:
		menu.queue_free()
		_fail("lobby setup: the NPC's side was not saved")
		return false
	# Last slot an NPC too, and a second arena; shown again from what was saved.
	_pick(panel.slot_count_option, 2)
	_pick(panel.rows[1]["kind_option"], 1)
	_pick(panel.rows[1]["archetype_option"], 0)
	_pick(panel.rows[1]["side_option"], 1)
	var arena := mini(1, GameManager.SCENARIOS.size() - 1)
	_pick(panel.arena_option, arena)
	panel.refresh()
	if panel.rows[1]["archetype_option"].selected != 0 or panel.rows[1]["side_option"].selected != 1 \
			or panel.arena_option.selected != arena or panel.mode_option.selected != 1 \
			or panel.slot_count_option.selected != 2:
		menu.queue_free()
		_fail("lobby setup: the block does not show what was saved")
		return false
	# HOST (LAN) opens the session with that setup on the roster, through the host API.
	menu.get_node("%HostLanButton").pressed.emit()
	var net := NetworkManager
	var roster := net.roster
	if not net.is_active() or roster.slots.size() != 4 or roster.mode != LobbyRoster.Mode.TEAMS \
			or roster.scenario_index != arena or GameManager.current_scenario_index != arena \
			or roster.slots[0]["kind"] != LobbyRoster.Kind.HUMAN or roster.slots[1]["kind"] != LobbyRoster.Kind.NPC \
			or roster.slots[1]["archetype"] != LobbyRoster.ARCHETYPE_MIXED or roster.side_of(1) != 0 \
			or roster.slots[2]["kind"] != LobbyRoster.Kind.NPC or roster.slots[2]["archetype"] != 0 or roster.side_of(2) != 1 \
			or roster.slots[3]["kind"] != LobbyRoster.Kind.OPEN or net.joinable_slots() != 1 or not GameManager.in_mp_lobby():
		var packed := roster.pack()
		net.leave("autotest")
		menu.queue_free()
		_fail("lobby setup: HOST (LAN) did not open the saved setup: %s" % [packed])
		return false
	net.leave("autotest")
	menu.queue_free()
	_apply_lobby_snapshot(before)
	print("AUTOTEST: lobby setup block ok (pickers, rows follow the count, Teams sides, Mixed, HOST applies it)")
	return true


# -- Teams ---------------------------------------------------------------------------

## Rosters for the placement check: `npcs` (slot -> archetype; every other slot is a human
## who never connects), each slot's side, and the ring order those sides must give.
const LOBBY_TEAM_SPLITS: Array[Dictionary] = [
	{"tag": "1v3, the host alone", "npcs": {1: 0, 2: 0, 3: 0}, "sides": [1, 0, 0, 0], "order": [0, 1, 2, 3]},
	{"tag": "1v3, an NPC alone", "npcs": {1: 0, 2: 0, 3: 0}, "sides": [0, 0, 0, 1], "order": [3, 0, 1, 2]},
	{"tag": "1v3, a human alone", "npcs": {1: 0, 3: 0}, "sides": [0, 0, 1, 0], "order": [2, 0, 1, 3]},
	{"tag": "2v2", "npcs": {1: 0, 2: 0, 3: 0}, "sides": [1, 0, 0, 1], "order": [1, 2, 0, 3]},
	{"tag": "1v2", "npcs": {1: 0}, "sides": [0, 0, 1], "order": [2, 0, 1]},
	{"tag": "1v1", "npcs": {}, "sides": [1, 0], "order": [1, 0]},
]


## Teams, with the hold on the own corpse shortened and every hit cutting a hole.
func _lobby_teams_ok() -> bool:
	var saved_hold: float = GameManager.tuning["death_cam_hold"]
	var saved_chance: float = GameManager.tuning["chunk_chance"]
	GameManager.tuning["death_cam_hold"] = LOBBY_SPECTATE_HOLD
	GameManager.tuning["chunk_chance"] = 1.0
	var ok: bool = _lobby_team_room_ok() and _lobby_team_spawns_ok() and await _lobby_team_solo_ok() \
			and await _lobby_team_pairs_ok() and await _lobby_team_foul_ok() and await _lobby_team_leaver_ok()
	GameManager.tuning["death_cam_hold"] = saved_hold
	GameManager.tuning["chunk_chance"] = saved_chance
	return ok


func _roster_sides(roster: LobbyRoster) -> Array[int]:
	var sides: Array[int] = []
	for slot in roster.slots:
		sides.append(slot["side"])
	return sides


func _roster_wins(roster: LobbyRoster) -> Array[int]:
	var wins: Array[int] = []
	for slot in roster.slots:
		wins.append(slot["wins"])
	return wins


## What the finish shows: the headline over the reason.
func _result_text(headline: String, reason: String) -> String:
	return "%s\n%s" % [tr(headline), tr(reason)]


## A mid-duel death names the victim, and the killer when there is one, over the count.
func _down_text(victim: int, killer: int, left: int) -> String:
	var duel := GameManager.duel
	var who := tr("MSG_DUELIST_DOWN") % duel.slot_name(victim)
	if killer >= 0 and killer != victim:
		who = tr("MSG_DUELIST_SHOT") % [duel.slot_name(victim), duel.slot_name(killer)]
	return "%s\n%s" % [who, tr("MSG_NPCS_LEFT") % left]


## The message ends on the count of the duelists left; the line above names who went.
func _says_left(left: int) -> bool:
	return GameManager.hud.message_label.text.ends_with("\n" + tr("MSG_NPCS_LEFT") % left)


## Switches the live roster to Teams with `sides[slot]` per slot, each set the way its
## kind is picked: the host's own pick, the host's call for an NPC slot, and for an absent
## human what `_request_side` runs for a client's pick.
func _lobby_set_sides(sides: Array) -> bool:
	var net := NetworkManager
	var set_ok := net.host_set_mode(LobbyRoster.Mode.TEAMS)
	for slot in sides.size():
		if slot == 0:
			net.request_side(sides[slot])
		elif net.roster.slots[slot]["kind"] == LobbyRoster.Kind.NPC:
			set_ok = net.host_set_npc_side(slot, sides[slot]) and set_ok
		else:
			net._apply_side(slot, sides[slot])
	if not set_ok or _roster_sides(net.roster) != sides:
		_fail("lobby teams: could not set sides %s (%s)" % [sides, _roster_sides(net.roster)])
		return false
	return true


## The waiting room of four humans. A pick in free-for-all is ignored. Teams colours every
## body by its side at once and leaves everyone on their slot's point, also when the room
## re-forms on sides whose ring order is not slot order. The host's own pick and a client's
## (`_apply_side`, what `_request_side` runs for its sender) recolour and sync. A pick may
## empty a side: START then refuses until one is filled. A bad pick does nothing, and the
## host cannot pick for a human. Free-for-all brings the slot colours back.
func _lobby_team_room_ok() -> bool:
	var net := NetworkManager
	var roster := net.roster
	if not _lobby_fill(4):
		return false
	for slot in 4:
		roster.set_side(slot, slot % 2)
	if not _lobby_room_ok("lobby teams, free-for-all"):
		return false
	var syncs := [0]
	var on_sync := func() -> void: syncs[0] += 1
	net.roster_changed.connect(on_sync)
	net.request_side(1)
	net._apply_side(2, 1)
	if syncs[0] != 0 or _roster_sides(roster) != [0, 1, 0, 1]:
		_fail("lobby teams: a side pick in free-for-all should be ignored (%s)" % [_roster_sides(roster)])
		return false
	if not net.host_set_mode(LobbyRoster.Mode.TEAMS) or net.start_refusal() != "" or syncs[0] != 1:
		_fail("lobby teams: the default sides are a 2v2 that may start (%s)" % net.start_refusal())
		return false
	if not _lobby_room_ok("lobby teams, 2v2"):
		return false
	# The host joins side 1: slot 2 is alone, and first on the ring of the next duel.
	net.request_side(1)
	if syncs[0] != 2 or _roster_sides(roster) != [1, 1, 0, 1] or roster.spawn_order() != [2, 0, 1, 3] \
			or net.start_refusal() != "" or not net.host_back_to_lobby():
		_fail("lobby teams: the host's pick should make it 3v1 (%s)" % [_roster_sides(roster)])
		return false
	if not _lobby_room_ok("lobby teams, 3v1"):
		return false
	# Slot 2's human follows: side 0 is empty.
	var edits: int = syncs[0]
	net._apply_side(2, 1)
	if syncs[0] != edits + 1 or roster.side_of(2) != 1 or roster.can_start() or net.start_refusal() != "MSG_LOBBY_EMPTY_SIDE" \
			or net.host_start() or not GameManager.in_mp_lobby() \
			or GameManager.hud.message_label.text != tr("MSG_LOBBY_EMPTY_SIDE"):
		_fail("lobby teams: a pick may empty a side, and START should then refuse (%s)" % net.start_refusal())
		return false
	if not _lobby_room_ok("lobby teams, a side empty"):
		return false
	edits = syncs[0]
	net.request_side(2)
	net.request_side(-1)
	net._apply_side(-1, 0)
	net._apply_side(4, 0)
	if net.host_set_npc_side(2, 0) or syncs[0] != edits or _roster_sides(roster) != [1, 1, 1, 1]:
		_fail("lobby teams: a bad pick, or the host's for a human, should do nothing (%s)" % [_roster_sides(roster)])
		return false
	net._apply_side(2, 0)
	if net.start_refusal() != "" or not _lobby_room_ok("lobby teams, the side filled again"):
		_fail("lobby teams: filling the empty side should let START through (%s)" % net.start_refusal())
		return false
	if not net.host_set_mode(LobbyRoster.Mode.FFA) or _roster_sides(roster) != [1, 1, 0, 1] \
			or not _lobby_room_ok("lobby teams, back to free-for-all"):
		_fail("lobby teams: free-for-all should keep the picks and bring the slot colours back")
		return false
	net.roster_changed.disconnect(on_sync)
	print("AUTOTEST: lobby Teams waiting room ok (picks, side / slot tints on every change, slot points, empty side refused)")
	return true


## Every arena, every split of LOBBY_TEAM_SPLITS through START: each slot stands on the ring
## point `spawn_order()` gives it, facing the lane, in its side's colour, whoever it is. The
## one on PlayerSpawn is the host, a human's avatar, the host's NPC, or (staged) the proxy a
## client has for that NPC.
func _lobby_team_spawns_ok() -> bool:
	var net := NetworkManager
	var duel := GameManager.duel
	var home := GameManager.current_scenario_index
	for arena in GameManager.SCENARIOS.size():
		if not net.host_set_scenario(arena):
			_fail("lobby teams: could not pick arena %d" % arena)
			return false
		for split: Dictionary in LOBBY_TEAM_SPLITS:
			var tag := "lobby teams arena %d (%s)" % [arena, split["tag"]]
			var sides: Array = split["sides"]
			var order: Array = split["order"]
			var npcs: Dictionary = split["npcs"]
			if not _lobby_fill(sides.size(), npcs) or not _lobby_set_sides(sides):
				return false
			if net.start_refusal() != "" or not net.host_start() or duel.state != DuelManager.State.STANDOFF \
					or GameManager.current_scenario_index != arena or GameManager.current_ais.size() != npcs.size() \
					or duel.is_team_duel() != (sides.size() > 2):
				_fail("%s: host_start() did not start it (%s)" % [tag, net.start_refusal()])
				return false
			if not _lobby_points_ok(tag, order) or not _lobby_tints_ok(tag, sides.size()):
				return false
			for slot: int in npcs:
				if not _lobby_npc_slot_ok(slot, tag):
					return false
			if npcs.has(order[0]) and not _lobby_proxy_first_ok(tag, order[0]):
				return false
	net.host_set_scenario(home)
	print("AUTOTEST: lobby Teams ring points ok (%d splits on every arena: order, facing, side tints; host, avatar, NPC, and proxy on PlayerSpawn)" % LOBBY_TEAM_SPLITS.size())
	return true


## What a client stands on PlayerSpawn when the NPC in `slot` is first on the ring, staged
## on the host beside the real NPC: a proxy on the point, facing the lane, in the side's
## colour, whose head is over the point once the NPC's own pose drives it.
func _lobby_proxy_first_ok(tag: String, slot: int) -> bool:
	var duel := GameManager.duel
	var npc := GameManager.actor_node(slot) as DuelistAI
	var spawn := GameManager.current_scenario.get_player_spawn()
	var proxy := GameManager._spawn_avatar(slot, GameManager._mp_spawns(duel.snapshot)[slot], true)
	GameManager._apply_lobby_tints()
	var pose := npc.capture_replay_pose()
	GameManager._on_npc_pose_received(slot, pose["head"], pose["flags"], pose["gun"])
	var head := proxy._target_head
	var staged: bool = GameManager.actor_node(slot) == proxy and proxy.global_transform.is_equal_approx(spawn) \
			and proxy._has_pose and Vector2(head.origin.x - spawn.origin.x, head.origin.z - spawn.origin.z).length() < 0.05 \
			and (-head.basis.z).dot(-spawn.basis.z) > 0.98
	var shown: bool = staged and _lobby_points_ok(tag + ", proxy") and _lobby_tints_ok(tag + ", proxy", duel.snapshot.slots.size())
	GameManager.free_avatar(slot)
	if not staged:
		_fail("%s: a client's proxy of NPC slot %d does not stand on PlayerSpawn facing the lane" % [tag, slot])
	return shown and GameManager.actor_node(slot) == npc


## 1v3 through START: the host alone (side 1) against a Drunk, the Sheriff, and a Drunk
## (side 0). At the bell every NPC has the host as its only rival. Crossfire still lands:
## one NPC's bullet wounds its teammate, who does not turn on it, and the next kills it
## (`_mp_down`, credited, "3 left"). The duel goes on while each side has someone, and ends
## when the host has shot the other two: its side wins, and only its slot is tallied.
func _lobby_team_solo_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var local := GameManager.local_player
	var hud := GameManager.hud
	if not _lobby_fill(4, {1: 0, 2: 1, 3: 0}) or not _lobby_set_sides([1, 0, 0, 0]):
		return false
	if net.start_refusal() != "" or not net.host_start() or not duel.is_team_duel():
		_fail("lobby 1v3: host_start() refused the host against three NPCs (%s)" % net.start_refusal())
		return false
	if not _lobby_points_ok("lobby 1v3", [0, 1, 2, 3]) or not _lobby_tints_ok("lobby 1v3", 4):
		return false
	var ais: Array[DuelistAI] = GameManager.current_ais.duplicate()
	var result := _arm_duel_listener()
	if not await _wait_for_state(DuelManager.State.DRAW, 12.0):
		_fail("lobby 1v3: never reached DRAW (state %d)" % duel.state)
		return false
	for ai in ais:
		if ai.state != DuelistAI.AIState.REACTING or ai._target != local:
			_fail("lobby 1v3: NPC %d did not react to the bell on the host" % ai.actor_id)
			return false
		_lobby_park(ai)
		var picked := _lobby_npc_picks(ai)
		if picked.size() != 1 or not picked.has(local):
			_fail("lobby 1v3: NPC %d should have the host as its only rival (%d picked)" % [ai.actor_id, picked.size()])
			return false
	var mate := ais[1]
	_lobby_shoot_npc(mate, mate.torso_hitbox, 1)
	if not mate.is_alive() or not is_equal_approx(mate.health, 2.0) or mate._target != local \
			or duel.live_slots() != [0, 1, 2, 3] or not result.is_empty():
		_fail("lobby 1v3: a teammate's bullet should wound an NPC and not be answered (hp %.1f)" % mate.health)
		return false
	if PlayerSettings.gore_enabled and mate.corpse_body().chunk_count() != 1:
		_fail("lobby 1v3: a teammate's hit cut %d holes" % mate.corpse_body().chunk_count())
		return false
	_lobby_shoot_npc(mate, mate.head_hitbox, 1)
	if mate.is_alive() or mate.killed_by != 1 or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 1, 3] \
			or not _says_left(3) or not result.is_empty() or KillCam.is_playing \
			or not mate.corpse_body().has_corpse():
		_fail("lobby 1v3: a team kill should count as any other death (live %s, killer %d, '%s')" % [
				duel.live_slots(), mate.killed_by, hud.message_label.text])
		return false
	for ai: DuelistAI in [ais[0], ais[2]]:
		var picked := _lobby_npc_picks(ai)
		if picked.size() != 1 or not picked.has(local):
			_fail("lobby 1v3: NPC %d should still have only the host to shoot" % ai.actor_id)
			return false
	_lobby_shoot_npc(ais[0], ais[0].head_hitbox, 0)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 3] \
			or not _says_left(2):
		_fail("lobby 1v3: the duel should go on while each side has someone (live %s)" % [duel.live_slots()])
		return false
	_lobby_shoot_npc(ais[2], ais[2].head_hitbox, 0)
	if result != [true, "MSG_REASON_LAST_SIDE"] or duel.state != DuelManager.State.RESOLUTION or duel.live_slots() != [0] \
			or hud.message_label.text != _result_text("MSG_SIDE_WON", "MSG_REASON_LAST_SIDE") \
			or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != 3:
		_fail("lobby 1v3: the host should win it for its side (%s, '%s')" % [result, hud.message_label.text])
		return false
	if _roster_wins(net.roster) != [1, 0, 0, 0]:
		_fail("lobby 1v3: only the host's slot should be tallied: %s" % [_roster_wins(net.roster)])
		return false
	print("AUTOTEST: lobby 1v3 ok (one rival for three NPCs, crossfire wound unanswered, team kill counted, side wiped, tally)")
	return true


## 2v2 through START: the host and the Sheriff in slot 3 (side 1) against two Drunks (side
## 0), slot 1 first on the ring. The host's teammate never picks the host, takes the host's
## bullet as a wound without turning on it, and does turn on a rival who shoots it. The duel
## goes on through a death on each side, and the dead host watches either side. Its
## teammate's kill of the last rival wins it for both: the dead host reads the win, and its
## slot and the NPC's are tallied. Sides picked in that duel's standoff leave it alone and
## shape the next one (the host and slot 2 against slots 1 and 3), which the host's side
## loses to its own bullet: the host dies, and its shot still in the air kills its teammate. A
## slot's tally is its occupant's: a new one starts from zero.
func _lobby_team_pairs_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var roster := net.roster
	var local := GameManager.local_player
	var hud := GameManager.hud
	if not _lobby_fill(4, {1: 0, 2: 0, 3: 1}) or not _lobby_set_sides([1, 0, 0, 1]):
		return false
	if net.start_refusal() != "" or not net.host_start() or not duel.is_team_duel():
		_fail("lobby 2v2: host_start() refused two against two (%s)" % net.start_refusal())
		return false
	if not _lobby_points_ok("lobby 2v2", [1, 2, 0, 3]) or not _lobby_tints_ok("lobby 2v2", 4):
		return false
	for slot in range(1, 4):
		if not _lobby_npc_slot_ok(slot, "lobby 2v2"):
			return false
	var rival_a := GameManager.actor_node(1) as DuelistAI
	var rival_b := GameManager.actor_node(2) as DuelistAI
	var mate := GameManager.actor_node(3) as DuelistAI
	# Picks made once the duel runs are for the next one: this one keeps its sides, colours,
	# and points, and its NPCs choose by them at the bell.
	var running := duel.snapshot
	net.request_side(0)
	if not net.host_set_npc_side(1, 1) or _roster_sides(roster) != [0, 1, 0, 1] or duel.snapshot != running \
			or _roster_sides(duel.snapshot) != [1, 0, 0, 1] or GameManager.side_of(local) != 1 \
			or GameManager.side_of(rival_a) != 0 or mate._is_rival(local) or not rival_a._is_rival(local):
		_fail("lobby 2v2: a pick during a duel should change the live roster only (%s, snapshot %s)" % [
				_roster_sides(roster), _roster_sides(duel.snapshot)])
		return false
	if not _lobby_tints_ok("lobby 2v2, after a pick", 4) or not _lobby_points_ok("lobby 2v2, after a pick", [1, 2, 0, 3]):
		return false
	var result := _arm_duel_listener()
	if not await _wait_for_state(DuelManager.State.DRAW, 12.0):
		_fail("lobby 2v2: never reached DRAW (state %d)" % duel.state)
		return false
	for ai in GameManager.current_ais:
		if ai.state != DuelistAI.AIState.REACTING or not ai._is_rival(ai._target):
			_fail("lobby 2v2: NPC %d did not react to the bell with a live rival" % ai.actor_id)
			return false
		_lobby_park(ai)
	var mate_picks := _lobby_npc_picks(mate)
	if mate_picks.size() != 2 or not mate_picks.has(rival_a) or not mate_picks.has(rival_b) or mate._is_rival(local):
		_fail("lobby 2v2: the host's teammate should pick among the two rivals only (%d picked)" % mate_picks.size())
		return false
	for rival: DuelistAI in [rival_a, rival_b]:
		var picked := _lobby_npc_picks(rival)
		if picked.size() != 2 or not picked.has(local) or not picked.has(mate):
			_fail("lobby 2v2: NPC %d should pick among the host and its teammate only" % rival.actor_id)
			return false
	# Friendly fire is on, and a teammate's bullet is not answered.
	mate._target = rival_b
	_lobby_shoot_npc(mate, mate.torso_hitbox, 0)
	if not mate.is_alive() or not is_equal_approx(mate.health, 2.0) or mate._target != rival_b or not result.is_empty():
		_fail("lobby 2v2: the host's bullet should wound its teammate, who does not turn on it (hp %.1f)" % mate.health)
		return false
	if PlayerSettings.gore_enabled and mate.corpse_body().chunk_count() != 1:
		_fail("lobby 2v2: the host's hit cut %d holes in its teammate" % mate.corpse_body().chunk_count())
		return false
	_lobby_shoot_npc(mate, mate.torso_hitbox, 1)
	if not is_equal_approx(mate.health, 1.0) or mate._target != rival_a:
		_fail("lobby 2v2: an NPC should still turn on a rival who shoots it")
		return false
	# A death on each side.
	_lobby_shoot_npc(rival_a, rival_a.head_hitbox, 0)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 2, 3] \
			or not _says_left(3):
		_fail("lobby 2v2: one rival down should leave three fighting (live %s)" % [duel.live_slots()])
		return false
	var head := local.get_head_position()
	local.take_bullet_hit(99.0, PackedVector3Array([head - Vector3.FORWARD, head]), CombatRules.REGION_HEAD,
			false, false, 2)
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [2, 3] or local.alive \
			or not _says_left(2) or not DeathCam.is_spectating() or DeathCam.blocks_npcs():
		_fail("lobby 2v2: the host's death should leave its teammate fighting (live %s, phase %d)" % [
				duel.live_slots(), DeathCam.phase])
		return false
	# The dead watch anyone alive: the killer (a rival), then the teammate, then back.
	if not await _wait_for(func() -> bool: return _watching(2), LOBBY_SPECTATE_HOLD + 3.0):
		_fail("lobby 2v2: the dead host should watch its killer first (on %d)" % DeathCam.spectate_target())
		return false
	for want: int in [3, 2]:
		if not await _spectate_pull_ok(want, 0.3):
			return false
	if mate._target != rival_b or rival_b._target != mate:
		_fail("lobby 2v2: the last two, one of each side, should be on each other")
		return false
	_lobby_shoot_npc(rival_b, rival_b.head_hitbox, 3)
	if result != [true, "MSG_REASON_LAST_SIDE"] or duel.live_slots() != [3] or local.alive \
			or hud.message_label.text != _result_text("MSG_SIDE_WON", "MSG_REASON_LAST_SIDE"):
		_fail("lobby 2v2: the teammate's kill should win it for the dead host too (%s, '%s')" % [result, hud.message_label.text])
		return false
	if DeathCam.is_spectating() or not DeathCam.is_active() or ReplayBuffer.killer_id != 3 or ReplayBuffer.victim_id != 2:
		_fail("lobby 2v2: the last kill should take the dead winner into the death cam (killer %d, victim %d)" % [
				ReplayBuffer.killer_id, ReplayBuffer.victim_id])
		return false
	if _roster_wins(roster) != [1, 0, 0, 1]:
		_fail("lobby 2v2: the dead host's slot and its NPC teammate's should be tallied: %s" % [_roster_wins(roster)])
		return false
	# The next duel runs on the picks: the host and slot 2 against slots 1 and 3.
	if net.start_refusal() != "" or not net.host_start() or duel.snapshot == running \
			or _roster_sides(duel.snapshot) != [0, 1, 0, 1] or _roster_wins(duel.snapshot) != [1, 0, 0, 1]:
		_fail("lobby 2v2: the next duel should take the sides picked during the last (%s)" % [_roster_sides(duel.snapshot)])
		return false
	if not _lobby_points_ok("lobby 2v2, next duel", [0, 2, 1, 3]) or not _lobby_tints_ok("lobby 2v2, next duel", 4) \
			or not local.alive or DeathCam.phase != DeathCam.Phase.IDLE:
		return false
	result = _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	mate = GameManager.actor_node(2) as DuelistAI
	for ai in GameManager.current_ais:
		_lobby_park(ai)
	mate_picks = _lobby_npc_picks(mate)
	if mate_picks.size() != 2 or mate_picks.has(local) or mate_picks.has(mate) or mate_picks.has(null):
		_fail("lobby 2v2: the new teammate should pick among its two rivals only")
		return false
	head = local.get_head_position()
	local.take_bullet_hit(99.0, PackedVector3Array([head - Vector3.FORWARD, head]), CombatRules.REGION_HEAD,
			false, false, 1)
	if not result.is_empty() or duel.live_slots() != [1, 2, 3] or local.alive:
		_fail("lobby 2v2: the host's death should leave three fighting (live %s)" % [duel.live_slots()])
		return false
	# A team kill that empties the side: the other side wins.
	_lobby_shoot_npc(mate, mate.head_hitbox, 0)
	if result != [false, "MSG_REASON_LAST_SIDE"] or mate.is_alive() or mate.killed_by != 0 or duel.live_slots() != [1, 3] \
			or hud.message_label.text != _result_text("MSG_SIDE_LOST", "MSG_REASON_LAST_SIDE") \
			or ReplayBuffer.killer_id != 0 or ReplayBuffer.victim_id != 2:
		_fail("lobby 2v2: a team kill that empties a side should give the other side the win (%s, '%s')" % [
				result, hud.message_label.text])
		return false
	if _roster_wins(roster) != [1, 1, 0, 2]:
		_fail("lobby 2v2: both slots of the winning side should be tallied on top of the last duel: %s" % [_roster_wins(roster)])
		return false
	# A slot the host reopens, and the human who then takes it, start from zero.
	if not net.host_set_slot_kind(3, LobbyRoster.Kind.OPEN) or _roster_wins(roster) != [1, 1, 0, 0] \
			or roster.assign_peer(LOBBY_FAKE_PEERS[2], LOBBY_FAKE_NAMES[2]) != 3 or _roster_wins(roster) != [1, 1, 0, 0]:
		_fail("lobby 2v2: a slot's tally should reset with its occupant: %s" % [_roster_wins(roster)])
		return false
	print("AUTOTEST: lobby 2v2 ok (teammate never targeted, friendly fire unanswered, mid-duel pick held for the next duel, dead winner, team kill loses it, tally per slot)")
	return true


## Fouls go by roster size, not by side. 1v2 (the host and slot 2 against slot 1): the
## solo's first foul voids the standoff and its second puts it out, which empties its side,
## so the other side wins with nobody shot. A 2-slot Teams lobby is a 1v1: the joiner stands
## on PlayerSpawn here, a foul loses at once, and the result reads as a 1v1's.
func _lobby_team_foul_ok() -> bool:
	var duel := GameManager.duel
	var roster := NetworkManager.roster
	var hud := GameManager.hud
	if not _lobby_fill(3) or not _lobby_set_sides([0, 1, 0]) or not _lobby_start("1v2 foul"):
		return false
	if not duel.is_team_duel() or duel.snapshot.spawn_order() != [1, 0, 2]:
		_fail("lobby 1v2: three slots in Teams should put the solo first (%s)" % [duel.snapshot.spawn_order()])
		return false
	var result := _arm_duel_listener()
	var solo: RemoteAvatar = GameManager.avatars[1]
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby 1v2: never waited for the bell")
		return false
	duel._host_foul(1)
	if duel.state != DuelManager.State.STANDOFF or duel.live_slots() != [0, 1, 2] or not result.is_empty() \
			or not hud.message_label.text.contains("Ann"):
		_fail("lobby 1v2: a first foul should void the standoff (state %d, '%s')" % [duel.state, hud.message_label.text])
		return false
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby 1v2: the voided standoff never waited for the bell again")
		return false
	duel._host_foul(1)
	if result != [true, "MSG_REASON_LAST_SIDE"] or duel.state != DuelManager.State.RESOLUTION or duel.live_slots() != [0, 2] \
			or solo._dummy.has_corpse() or DeathCam.is_active() or KillCam.is_playing \
			or hud.message_label.text != _result_text("MSG_SIDE_WON", "MSG_REASON_LAST_SIDE"):
		_fail("lobby 1v2: a foul-out that empties a side should win it for the other, nobody falling (%s, '%s')" % [
				result, hud.message_label.text])
		return false
	if _roster_wins(roster) != [1, 0, 1]:
		_fail("lobby 1v2: both winners should be tallied: %s" % [_roster_wins(roster)])
		return false
	if not _lobby_fill(2) or not _lobby_set_sides([1, 0]) or not _lobby_start("teams 1v1"):
		return false
	if duel.is_team_duel() or duel.snapshot.mode != LobbyRoster.Mode.TEAMS or duel.snapshot.spawn_order() != [1, 0] \
			or GameManager.actor_node(1).global_position.distance_to(GameManager.current_scenario.get_player_spawn().origin) > 0.05:
		_fail("lobby teams 1v1: two slots in Teams should be a 1v1 with slot 1 on PlayerSpawn")
		return false
	result = _arm_duel_listener()
	if not await _wait_for_state(DuelManager.State.WAIT_SIGNAL, 6.0):
		_fail("lobby teams 1v1: never waited for the bell")
		return false
	duel._host_foul(1)
	if result != [true, "MSG_REASON_FOUL_OPPONENT"] or duel.state != DuelManager.State.RESOLUTION \
			or hud.message_label.text != _result_text("MSG_YOU_WIN", "MSG_REASON_FOUL_OPPONENT"):
		_fail("lobby teams 1v1: the joiner's foul should lose it at once and read as a 1v1 (%s, '%s')" % [
				result, hud.message_label.text])
		return false
	if not _lobby_start("teams 1v1 rematch"):
		return false
	result = _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	_lobby_shoot_head(GameManager.avatars[1])
	if result != [true, "MSG_REASON_CLEAN_KILL"] or _roster_wins(roster) != [2, 0] \
			or hud.message_label.text != _result_text("MSG_YOU_WIN", "MSG_REASON_CLEAN_KILL"):
		_fail("lobby teams 1v1: a kill should read as a 1v1's (%s, '%s')" % [result, hud.message_label.text])
		return false
	print("AUTOTEST: lobby Teams fouls ok (1v2: void, then out empties the side; 2 slots: a 1v1 in wording and rules)")
	return true


## 2v2 of humans (the host and slot 2 against slots 1 and 3). The host's teammate leaves:
## dead, gone, and the duel goes on. The host shoots slot 1, then slot 3 leaves, which
## empties its side: the host's side wins. Each leaver's slot is an NPC by then, on the
## side it had: a new occupant, so it gets no win for the duel its human left.
func _lobby_team_leaver_ok() -> bool:
	var duel := GameManager.duel
	var net := NetworkManager
	var hud := GameManager.hud
	if not _lobby_fill(4) or not _lobby_set_sides([0, 1, 0, 1]) or not _lobby_start("2v2 leaver"):
		return false
	var result := _arm_duel_listener()
	duel._enter(DuelManager.State.DRAW)
	net._verified_peers[LOBBY_FAKE_PEERS[1]] = LOBBY_FAKE_NAMES[1]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[1])
	if duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 1, 3] or GameManager.avatars.has(2) \
			or not result.is_empty() or not hud.message_label.text.contains("Bob"):
		_fail("lobby 2v2 leaver: a teammate leaving should count as dead and the duel go on (live %s, '%s')" % [
				duel.live_slots(), hud.message_label.text])
		return false
	_lobby_shoot_head(GameManager.avatars[1])
	if not result.is_empty() or duel.state != DuelManager.State.DRAW or duel.live_slots() != [0, 3]:
		_fail("lobby 2v2 leaver: one of each side should fight on (live %s)" % [duel.live_slots()])
		return false
	net._verified_peers[LOBBY_FAKE_PEERS[2]] = LOBBY_FAKE_NAMES[2]
	net._on_peer_disconnected(LOBBY_FAKE_PEERS[2])
	if result != [true, "MSG_REASON_LAST_SIDE"] or duel.live_slots() != [0] or GameManager.avatars.has(3) \
			or hud.message_label.text != _result_text("MSG_SIDE_WON", "MSG_REASON_LAST_SIDE"):
		_fail("lobby 2v2 leaver: a leaver who empties a side should give the other the win (%s, '%s')" % [
				result, hud.message_label.text])
		return false
	for slot: int in [2, 3]:
		if net.roster.slots[slot]["kind"] != LobbyRoster.Kind.NPC or net.roster.slots[slot]["side"] != slot - 2:
			_fail("lobby 2v2 leaver: slot %d should be an NPC on its human's side: %s" % [slot, net.roster.pack()])
			return false
	if _roster_wins(net.roster) != [1, 0, 0, 0] or net.start_refusal() != "":
		_fail("lobby 2v2 leaver: only the host should be tallied, not the NPC in its teammate's slot: %s" % [
				_roster_wins(net.roster)])
		return false
	if not net.host_back_to_lobby() or not GameManager.in_mp_lobby() or DeathCam.phase != DeathCam.Phase.IDLE:
		_fail("lobby 2v2 leaver: the waiting room should clear the duel")
		return false
	print("AUTOTEST: lobby Teams leavers ok (a teammate gone mid-duel, a side emptied by a leaver, no win for a slot's new occupant)")
	return true


func _test_practice() -> void:
	await _sleep(1.0)
	if not GameManager.is_menu_backdrop():
		return _fail("flat boot is not on the menu backdrop")
	if GameManager.current_scenario.process_mode != Node.PROCESS_MODE_DISABLED:
		return _fail("flat menu backdrop is not frozen")
	if GameManager.in_practice():
		return _fail("flat menu loaded the hub instead of a duel arena")
	GameManager.start_practice()
	await _sleep(0.5)
	var hub := GameManager.practice_hub()
	if hub == null or GameManager.mode != GameManager.GameMode.PRACTICE:
		return _fail("start_practice did not load the hub")
	if hub.bottles().size() != 12:
		return _fail("hub spawned %d bottles, expected 12" % hub.bottles().size())
	if hub.slot_machine == null:
		return _fail("hub has no slot machine")
	if hub.tutorial_board == null:
		return _fail("hub has no tutorial board")
	var board_text: String = hub.tutorial_board.copy_text()
	if not board_text.contains("LMB") or not board_text.contains("RMB"):
		return _fail("board missing default flat fire/draw labels")
	if not board_text.contains("Space"):
		return _fail("board missing default cock bind")
	var previous_cock := PlayerSettings.get_flat_bind_event(&"cock_hammer")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_K
	PlayerSettings.set_flat_bind(&"cock_hammer", rebound)
	board_text = hub.tutorial_board.copy_text()
	if not board_text.contains("K"):
		PlayerSettings.set_flat_bind(&"cock_hammer", previous_cock)
		return _fail("board did not follow a cock rebind")
	PlayerSettings.set_flat_bind(&"cock_hammer", previous_cock)
	if not hub.tutorial_board.copy_text().contains("Space"):
		return _fail("board did not restore the cock bind")
	if hub.get_node_or_null("LotPad") == null or hub.get_node_or_null("DesertPad") == null:
		return _fail("hub is missing LotPad / DesertPad")
	if hub.get_node_or_null("PorchDeck") == null:
		return _fail("hub is missing PorchDeck")
	var space := hub.get_world_3d().direct_space_state
	var lot_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(0.0, 2.0, -10.0), Vector3(0.0, -2.0, -10.0), 1))
	if lot_hit.is_empty() or absf(lot_hit.position.y) > 0.05:
		return _fail("lot ground is not at walk height (hit=%s)" % lot_hit)
	var sand_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(20.0, 2.0, 0.0), Vector3(20.0, -2.0, 0.0), 1))
	if sand_hit.is_empty() or absf(sand_hit.position.y + 0.12) > 0.05:
		return _fail("desert ground is not at the sand visual (hit=%s)" % sand_hit)
	var porch_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(1.2, 2.0, 3.6), Vector3(1.2, -1.0, 3.6), 1))
	if porch_hit.is_empty() or absf(porch_hit.position.y - 0.06) > 0.015:
		return _fail("porch deck is not at plank height (hit=%s)" % porch_hit)

	var player := GameManager.local_player
	# Dropped revolver must rest on the planks, not the lot under them (BUG-011).
	var gun := player.revolver
	gun.axis_lock_angular_x = true
	gun.axis_lock_angular_y = true
	gun.axis_lock_angular_z = true
	gun.release_into_world(hub, Vector3.ZERO, Vector3.ZERO)
	gun.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.2, 0.45, 3.6))
	gun.linear_velocity = Vector3.ZERO
	gun.angular_velocity = Vector3.ZERO
	if not await _wait_for(func() -> bool:
		return gun.linear_velocity.length() < 0.05 and _body_bottom_y(gun) < 0.2, 3.0):
		gun.axis_lock_angular_x = false
		gun.axis_lock_angular_y = false
		gun.axis_lock_angular_z = false
		gun.holster_to(player.get_node("Holster") as Node3D)
		return _fail("revolver did not settle on the porch (bottom y=%s)" % _body_bottom_y(gun))
	var deck_bottom := _body_bottom_y(gun)
	gun.axis_lock_angular_x = false
	gun.axis_lock_angular_y = false
	gun.axis_lock_angular_z = false
	gun.holster_to(player.get_node("Holster") as Node3D)
	if deck_bottom < 0.045:
		return _fail("revolver sank through the porch deck (bottom y=%s)" % deck_bottom)
	var hp := player.health
	player.take_bullet_hit(99.0, PackedVector3Array(), CombatRules.REGION_HEAD)
	if not player.alive or player.health != hp:
		return _fail("practice wound was not ignored")

	# A real slug from 2 m in front of a rail bottle.
	var target: PracticeBottle = hub.bottles()[0]
	var aim := target.center()
	Bullet.spawn(get_tree().current_scene, aim + Vector3(0.0, 0.0, 2.0), Vector3.FORWARD,
			55.0, true, [], true)
	if not await _wait_for(func() -> bool: return target.state == PracticeBottle.State.BROKEN, 2.0):
		return _fail("bullet did not shatter the bottle")
	if hub.broken != 1:
		return _fail("counter %d after one shot" % hub.broken)
	if not await _wait_for(func() -> bool: return target.state == PracticeBottle.State.HOME, 4.0):
		return _fail("shot bottle did not respawn")
	if target.global_position.distance_to(target.home_transform().origin) > 0.001:
		return _fail("respawn is not on the rail pose")

	# Pick up, shoot it in the hand, then throw the respawned bottle down range.
	var thrown: PracticeBottle = hub.bottles()[1]
	if not player._grab_bottle(thrown, player.off_hand_name(), Transform3D.IDENTITY):
		return _fail("could not pick up a bottle")
	await _sleep(0.1)
	if not player.is_holding_bottle() or thrown.state != PracticeBottle.State.HELD:
		return _fail("bottle is not held after pickup")
	if (thrown.collision_layer & PracticeBottle.LAYER) == 0:
		return _fail("held bottle dropped its bullet layer")
	var from := thrown.center() + Vector3(0.0, 0.0, -0.2)
	Bullet.spawn(get_tree().current_scene, from, Vector3(0.0, 0.0, 1.0),
			55.0, true, player.hitbox_rids(), true)
	if not await _wait_for(func() -> bool: return thrown.state == PracticeBottle.State.BROKEN, 2.0):
		return _fail("bullet did not shatter the held bottle")
	if hub.broken != 2:
		return _fail("counter %d after shot + held shot" % hub.broken)
	if not await _wait_for(func() -> bool: return thrown.state == PracticeBottle.State.HOME, 4.0):
		return _fail("held bottle did not respawn")
	if not player._grab_bottle(thrown, player.off_hand_name(), Transform3D.IDENTITY):
		return _fail("could not pick the respawned bottle back up")
	player._throw_held_bottle()
	if thrown.state != PracticeBottle.State.LOOSE:
		return _fail("thrown bottle is not loose")
	if not await _wait_for(func() -> bool: return thrown.state == PracticeBottle.State.BROKEN, 4.0):
		return _fail("thrown bottle never shattered (at %s)" % thrown.global_position)
	if hub.broken != 3:
		return _fail("counter %d after shot + held shot + throw" % hub.broken)
	if not await _wait_for(func() -> bool: return thrown.state == PracticeBottle.State.HOME, 4.0):
		return _fail("thrown bottle did not respawn")
	if thrown.global_position.distance_to(thrown.home_transform().origin) > 0.001:
		return _fail("thrown bottle respawned off its rail pose")

	# A gentle set-down stays whole.
	var soft: PracticeBottle = hub.bottles()[2]
	player._grab_bottle(soft, player.off_hand_name(), Transform3D.IDENTITY)
	soft.throw(Vector3.ZERO, Vector3.ZERO)
	player._held_bottle = null
	soft.global_position = Vector3(3.0, 0.08, 2.0)
	await _sleep(1.0)
	if soft.state != PracticeBottle.State.LOOSE:
		return _fail("soft set-down broke the bottle")

	GameManager.reset_current_duel()
	if hub.broken != 0 or soft.state != PracticeBottle.State.HOME:
		return _fail("reset range did not clear the counter and send bottles home")

	if not hub.slot_machine.pull():
		return _fail("slot lever did not pull")
	if hub.slot_machine.pull():
		return _fail("slot pulled again mid-spin")
	if not await _wait_for(func() -> bool: return not hub.slot_machine.spinning, 4.0):
		return _fail("slot reels never stopped")

	GameManager.go_to_menu()
	await _sleep(0.3)
	if GameManager.in_practice() or not GameManager.is_menu_backdrop():
		return _fail("quit from practice did not return to the flat backdrop")
	print("AUTOTEST: practice hub ok")
	_pass()


## Off-hand props on a live flat player: equip through the radial, throw the
## cigarette, and catch it back onto the hand attach.
func _test_props() -> void:
	await _sleep(1.0)
	GameManager.start_free_duel(0, 0)
	await _sleep(1.0)
	var player := GameManager.local_player
	var props: PropController = player.props
	var hand := player.off_hand_name()
	var attach: Node3D = player.rig.get_prop_attach(hand)
	if attach == null:
		return _fail("flat rig has no PropAttach")

	# Mouse up must land on the first wedge; centred must cancel.
	var up := FlatRig.radial_vector_from_motion(Vector2.ZERO, Vector2(0.0, -400.0))
	if PropController.highlight_index(up, PropController.ITEMS.size()) != 0:
		return _fail("mouse up should highlight the top wedge, got %s" % up)

	props.on_radial_changed(hand, true)
	if not props.is_radial_open():
		return _fail("radial did not open")
	props.on_radial_changed(hand, false)
	if props.is_radial_open():
		return _fail("radial did not close on release")
	if props.has_prop():
		return _fail("release at centre should cancel, not equip")

	props.equip_item(PropController.ITEM_CIGARETTE)
	if not props.has_prop():
		return _fail("cigarette was not equipped")
	print("AUTOTEST: cigarette equipped on the off hand")

	# Hold to charge, release to throw.
	props.on_fire_changed(true)
	await _sleep(0.4)
	if props.is_prop_flying():
		return _fail("cigarette left the hand before the button was released")
	var charge := props.charge_ratio()
	if charge <= 0.0:
		return _fail("holding the throw button did not charge")
	props.on_fire_changed(false)
	if not await _wait_for(func() -> bool: return props.is_prop_flying(), 3.0):
		return _fail("cigarette never launched on release")
	if not await _wait_for(func() -> bool: return not props.is_prop_flying(), 15.0):
		return _fail("cigarette never returned to the hand")
	print("AUTOTEST: charged to %.2f, thrown, and caught" % charge)

	props.equip_item(PropController.ITEM_COIN)
	var first := props.current_prop()
	if first == null:
		return _fail("coin was not equipped")
	props.on_fire_changed(true)
	if not first.is_loose():
		return _fail("G press did not flip the coin")
	props.on_fire_changed(false)
	if not first.is_loose():
		return _fail("G release after a flip should not recatch immediately")
	props.equip_item(PropController.ITEM_COIN)
	await get_tree().process_frame
	var second := props.current_prop()
	if second == null or second == first:
		return _fail("reselecting the coin did not spawn a new instance")
	if is_instance_valid(first):
		return _fail("reselecting the coin did not despawn the older one")

	props.equip_item(PropController.ITEM_BOTTLE)
	var first_bottle := props.current_prop()
	if first_bottle == null:
		return _fail("bottle was not equipped")
	props.equip_item(PropController.ITEM_BOTTLE)
	await get_tree().process_frame
	var second_bottle := props.current_prop()
	if second_bottle == null or second_bottle == first_bottle:
		return _fail("reselecting the bottle did not spawn a new instance")
	if is_instance_valid(first_bottle):
		return _fail("reselecting the bottle did not despawn the older one")

	props.equip_item(PropController.ITEM_NONE)
	if props.has_prop():
		return _fail("empty-hand wedge did not clear the prop")
	if not await _bottle_ok():
		return
	_pass()


## Instantiate every scene and load every resource the flat tests don't cover.
func _test_load_all() -> void:
	await _sleep(0.5)
	var scenes := [
		"res://ui/hud.tscn",
		"res://ui/settings_menu.tscn",
		"res://ui/pause_menu.tscn",
		"res://player/vr_rig.tscn",
		"res://player/remote_avatar.tscn",
		"res://ai/duelist.tscn",
		"res://weapons/revolver/revolver.tscn",
		"res://props/cigarette.tscn",
		"res://props/coin.tscn",
		"res://props/ace.tscn",
		"res://scenarios/main_street/main_street.tscn",
		"res://scenarios/saloon/saloon.tscn",
		"res://scenarios/train_rooftop/train_rooftop.tscn",
		"res://scenarios/canyon/canyon.tscn",
		"res://scenarios/practice_hub/practice_hub.tscn",
		"res://practice/practice_bottle.tscn",
		"res://practice/slot_machine.tscn",
		"res://practice/tutorial_board.tscn",
	]
	for path in scenes:
		var instance: Node = (load(path) as PackedScene).instantiate()
		add_child(instance)
		await get_tree().process_frame
		if path.ends_with("train_rooftop.tscn"):
			var scenery := instance.get_node_or_null("Scenery")
			# Tracks + cacti + both horizon bands. See scenery_belt.gd.
			if scenery == null or scenery.get_child_count() < 80:
				var count := 0 if scenery == null else scenery.get_child_count()
				instance.queue_free()
				return _fail("train rooftop scenery belt built %d pieces" % count)
		instance.queue_free()
		print("AUTOTEST: loaded %s" % path)
	if not _bullet_trail_ok():
		return
	if not _puff_cues_ok():
		return
	if not _world_globals_ok():
		return
	if not _world_surface_ok():
		return
	var resources: Array = []
	resources.append_array(GameManager.SCENARIOS)
	resources.append_array(GameManager.ARCHETYPES)
	resources.append(GameManager.GAUNTLET_LADDER)
	resources.append(GameManager.PRACTICE_HUB)
	for path in resources:
		if load(path) == null:
			return _fail("resource failed to load: %s" % path)
		print("AUTOTEST: loaded %s" % path)
	var ladder: GauntletLadder = load(GameManager.GAUNTLET_LADDER)
	if ladder.encounters.size() != 7:
		return _fail("ladder has %d encounters, expected 7" % ladder.encounters.size())
	if not _main_menu_split_ok():
		return
	if not _lobby_settings_ok() or not _lobby_setup_ok():
		return
	if not _steam_transport_ok():
		return
	if not _binds_ok():
		return
	if not await _props_ok():
		return
	if not _version_check_ok():
		return
	if not _roster_ok():
		return
	if not await _voice_ok():
		return
	if not _leave_rejoin_ok():
		return
	if not _time_of_day_ok():
		return
	if not await _wind_ok():
		return
	if not await _vr_rig_ok():
		return
	if not ImpactFeedback.has_warmed_up():
		return _fail("boot warmup did not run")
	if Bullet.ensure_mesh() == null or AudioCatalog.get_stream(&"gunshot") == null:
		return _fail("warmup missed slug mesh or gunshot")
	_pass()


## The trail is a ShaderMaterial on the trail shader and its ribbon carries UVs
## (UV.y 0 at the tail, 1 at the bullet). Headless skips shader compiles: wiring only.
func _bullet_trail_ok() -> bool:
	var mat := BulletTrail.make_material(Color.WHITE)
	if mat == null or mat.shader != BulletTrail.SHADER:
		_fail("bullet trail material is not a ShaderMaterial on bullet_trail.gdshader")
		return false
	var trail := BulletTrail.new()
	add_child(trail)
	for i in 4:
		trail.add_point(Vector3(0.0, 0.0, -float(i)))
	trail._rebuild_ribbon()
	var arrays := (trail.mesh as ImmediateMesh).surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var lo := 1.0
	var hi := 0.0
	for uv in uvs:
		lo = minf(lo, uv.y)
		hi = maxf(hi, uv.y)
	trail.queue_free()
	if uvs.size() != 8 or not is_zero_approx(lo) or not is_equal_approx(hi, 1.0):
		_fail("bullet trail ribbon UVs: %d verts, UV.y %.2f..%.2f" % [uvs.size(), lo, hi])
		return false
	return true


## The world shader globals are declared in project.godot, and F3 `band_low` / `band_soft`
## reach them (one value for skin, cavity, hands, and the world). The headless renderer keeps
## the declared names but returns null on a read, so the value is compared only when it exists.
func _world_globals_ok() -> bool:
	var declared := RenderingServer.global_shader_parameter_get_list()
	for key in ["band_low", "band_soft", "grain_strength_mult", "grain_scale_mult",
			"wind_ambient", "wind_gust"]:
		if not declared.has(StringName(key)):
			_fail("shader global %s is not declared in project.godot" % key)
			return false
	var saved_low: float = GameManager.tuning["band_low"]
	GameManager.set_tuning("band_low", 0.4)
	var pushed: Variant = RenderingServer.global_shader_parameter_get(&"band_low")
	GameManager.set_tuning("band_low", saved_low)
	if pushed != null and not is_equal_approx(float(pushed), 0.4):
		_fail("band_low tuning did not reach the shader global (%s)" % pushed)
		return false
	print("AUTOTEST: world shader globals declared; band tuning drives them")
	return true


## Every scenario GLB surface (the five scenes, which also hold the Train Rooftop belt's GLB
## instances) wears `world_surface.gdshader`: the swap is made at import, so a missing
## reimport shows up here as a StandardMaterial3D. Sway sits only on plants and hay, the hinge
## only on the four named slabs, and collision proxies stay bare. Headless skips the compile.
func _world_surface_ok() -> bool:
	var shader := load("res://assets/shaders/world_surface.gdshader") as Shader
	var plants := ["M_Yucca", "M_Scrub", "M_ScrubDry", "M_Hay"]
	var slabs := [&"Sign", &"PorchSign", &"Canopy", &"ShedAwning"]
	var hinged := {}
	var swayed := 0
	var surfaces := 0
	for path in [
		"res://scenarios/main_street/main_street.tscn",
		"res://scenarios/saloon/saloon.tscn",
		"res://scenarios/train_rooftop/train_rooftop.tscn",
		"res://scenarios/canyon/canyon.tscn",
		"res://scenarios/practice_hub/practice_hub.tscn",
	]:
		var instance := (load(path) as PackedScene).instantiate()
		add_child(instance)
		for node in instance.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not _in_scenario_glb(mi):
				continue
			for surface in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(surface)
				if mat == null:
					continue
				surfaces += 1
				var label := "%s %s surface %d" % [path.get_file(), mi.name, surface]
				if not (mat is ShaderMaterial and (mat as ShaderMaterial).shader == shader):
					_fail("%s is not on world_surface.gdshader (reimport the GLBs?)" % label)
					return false
				var sm := mat as ShaderMaterial
				if sm.get_shader_parameter("grain_local") != true:
					_fail("%s does not use grain_local" % label)
					return false
				var sway: Variant = sm.get_shader_parameter("sway_amount")
				var swaying: bool = sway != null and float(sway) > 0.0
				if swaying != plants.has(String(sm.resource_name)):
					_fail("%s sway_amount does not follow its material %s" % [label, sm.resource_name])
					return false
				if swaying:
					swayed += 1
					if path.ends_with("train_rooftop.tscn") and instance.get_node("Scenery").is_ancestor_of(mi):
						_fail("%s: a belt piece sways" % label)
						return false
				var hinge: Variant = sm.get_shader_parameter("hinge_amount")
				var hinging: bool = hinge != null and float(hinge) > 0.0
				if hinging != slabs.has(StringName(mi.name)):
					_fail("%s hinge_amount does not follow its node name" % label)
					return false
				if hinging:
					hinged[mi.name] = true
		for body in instance.find_children("*", "StaticBody3D", true, false):
			if _in_scenario_glb(body) and body.find_children("*", "MeshInstance3D", false, false).size() > 0:
				_fail("%s collision proxy %s grew a mesh" % [path.get_file(), body.name])
				return false
		instance.queue_free()
	if surfaces < 500 or swayed == 0 or hinged.size() != slabs.size():
		_fail("world surface: %d surfaces, %d swaying, hinges on %s" % [surfaces, swayed, hinged.keys()])
		return false
	print("AUTOTEST: %d scenario surfaces wear world_surface.gdshader (%d sway, hinges %s)" % [
			surfaces, swayed, hinged.keys()])
	return true


## True under an instanced scenario GLB (a scene or a belt piece), not for nodes authored in a .tscn.
func _in_scenario_glb(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		var file := parent.scene_file_path
		if file.ends_with(".glb"):
			return file.contains("/models/scenarios/")
		parent = parent.get_parent()
	return false


## The smoke and dust cues draw puff.gdshader on a QuadMesh with a spin range, so the
## shader reads an angle and the scale is the puff diameter. Wiring only: headless skips compiles.
func _puff_cues_ok() -> bool:
	var shader := load("res://assets/vfx/puff.gdshader") as Shader
	if shader == null:
		_fail("puff.gdshader failed to load")
		return false
	for cue in [&"muzzle_smoke", &"world_dust", &"barrel_smoke"]:
		var node := (load("res://assets/vfx/%s.tscn" % cue) as PackedScene).instantiate() as GPUParticles3D
		var mesh := node.draw_pass_1 as QuadMesh
		var mat := mesh.material as ShaderMaterial if mesh != null else null
		var proc := node.process_material as ParticleProcessMaterial
		var ok := mat != null and mat.shader == shader and proc != null 				and proc.angle_max > proc.angle_min and proc.scale_curve != null
		node.free()
		if not ok:
			_fail("%s does not draw puff.gdshader on a quad with a spin range" % cue)
			return false
	return true


## Outdoor times recolor the sky but keep the fog distances and shadow fade
## that hide the canyon plain and the train belt. Saloon has no sun.
## Outdoor arenas build a wind bed and gust timer from their ScenarioResource; the
## Saloon builds none. A forced gust spawns the `wind_gust` cue and a 3D player.
func _wind_ok() -> bool:
	var paths: Array[String] = GameManager.SCENARIOS.duplicate()
	paths.append(GameManager.PRACTICE_HUB)
	for path in paths:
		var res := load(path) as ScenarioResource
		var instance := res.scene.instantiate() as ScenarioBase
		instance.scenario_resource = res
		add_child(instance)
		var wind := res.wind_volume_db > ScenarioBase.WIND_OFF_DB
		if instance.has_wind() != wind or (instance._wind_player != null) != wind:
			instance.queue_free()
			_fail("%s wind setup does not match its resource" % res.display_name)
			return false
		# `world_surface.gdshader` sway: the wind globals follow the arena, and zero in the Saloon.
		if (instance.get_wind_ambient() > 0.0) != instance.has_wind() or instance.get_wind_gust() != 0.0:
			instance.queue_free()
			_fail("%s wind globals: ambient %.2f, gust %.2f, wind %s" % [res.display_name,
					instance.get_wind_ambient(), instance.get_wind_gust(), instance.has_wind()])
			return false
		if wind:
			var saved_scale: float = GameManager.tuning["sway_scale"]
			GameManager.set_tuning("sway_scale", 0.0)
			var held := instance.get_wind_ambient()
			GameManager.set_tuning("sway_scale", saved_scale)
			if held != 0.0 or instance.get_wind_ambient() <= 0.0:
				instance.queue_free()
				_fail("%s sway_scale does not scale the ambient wind" % res.display_name)
				return false
			var before := instance.get_child_count()
			instance.fire_gust()
			await get_tree().process_frame
			await get_tree().process_frame
			if instance.get_wind_gust() <= 0.0:
				instance.queue_free()
				_fail("%s gust did not pulse wind_gust" % res.display_name)
				return false
			var gust := false
			var spatial := false
			for child in instance.get_children():
				gust = gust or (child is OneShotParticles and child.name == &"WindGust")
				spatial = spatial or child is AudioStreamPlayer3D
			if instance.get_child_count() != before + 2 or not gust or not spatial:
				instance.queue_free()
				_fail("%s forced gust did not spawn dust and a 3D player" % res.display_name)
				return false
		instance.queue_free()
	print("AUTOTEST: wind bed and gusts follow the scenario resource")
	return true


## BUG-024: the VR head lands on the spawn whatever the playspace offset, waits for
## tracking, and stick walking slides along Train Rooftop's side guard wall. Headless
## has no XR interface, so the camera keeps the pose the test writes.
func _vr_rig_ok() -> bool:
	var arena := (load("res://scenarios/train_rooftop/train_rooftop.tscn") as PackedScene) \
			.instantiate() as ScenarioBase
	add_child(arena)
	var body := Node3D.new()
	add_child(body)
	var rig := (load("res://player/vr_rig.tscn") as PackedScene).instantiate() as VRRig
	body.add_child(rig)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ok := await _vr_rig_checks(arena, body, rig)
	body.queue_free()
	arena.queue_free()
	return ok


func _vr_rig_checks(arena: ScenarioBase, body: Node3D, rig: VRRig) -> bool:
	# EnemySpawn is yawed 180°: the joiner's facing must survive the recentre too.
	for spawn: Transform3D in [arena.get_enemy_spawn(), arena.get_player_spawn()]:
		body.global_transform = spawn
		rig.camera.position = Vector3(1.8, 1.6, 0.9)
		rig.camera.rotation = Vector3(0.0, 0.7, 0.0)
		rig.reset_locomotion()
		if not _vr_head_on_spawn(rig, spawn, "offset playspace"):
			return false
	var spawn := arena.get_player_spawn()
	rig.camera.position = Vector3(1.2, 0.0, -0.6)
	rig.reset_locomotion()
	if not rig._spawn_align_pending:
		_fail("vr rig: an untracked head did not defer the spawn alignment")
		return false
	rig.camera.position.y = 1.6
	# process_frame fires before nodes process: the second one follows the rig's _process.
	await get_tree().process_frame
	await get_tree().process_frame
	if rig._spawn_align_pending:
		_fail("vr rig: the deferred spawn alignment never ran once tracked")
		return false
	if not _vr_head_on_spawn(rig, spawn, "deferred"):
		return false
	# GuardSideR's inner face is x = 1.64; the 0.28 m capsule must stop by 1.36.
	var start_z := rig.camera.global_position.z
	for i in 40:
		rig.global_position += rig.collide_stick_motion(Vector3(0.1, 0.0, -0.05))
	var head := rig.camera.global_position
	if head.x > 1.4:
		_fail("vr rig: stick walked through GuardSideR (head x %.2f)" % head.x)
		return false
	if start_z - head.z < 1.0:
		_fail("vr rig: stick stuck on GuardSideR instead of sliding (z moved %.2f)" % (start_z - head.z))
		return false
	print("AUTOTEST: vr rig recentres on spawn, stick slides on the guard wall (x %.2f, z -%.2f)"
			% [head.x, start_z - head.z])
	return true


func _vr_head_on_spawn(rig: VRRig, spawn: Transform3D, label: String) -> bool:
	var head := rig.camera.global_position
	var off := Vector2(head.x - spawn.origin.x, head.z - spawn.origin.z).length()
	var look := -rig.camera.global_basis.z
	var want := -spawn.basis.z
	var facing := Vector2(look.x, look.z).normalized().dot(Vector2(want.x, want.z).normalized())
	if off > 0.01 or facing < 0.999:
		_fail("vr rig (%s): head %.2f m off the spawn, facing dot %.3f" % [label, off, facing])
		return false
	return true


func _time_of_day_ok() -> bool:
	var outdoor := [
		"res://scenarios/main_street/main_street.tscn",
		"res://scenarios/train_rooftop/train_rooftop.tscn",
		"res://scenarios/canyon/canyon.tscn",
	]
	for path in outdoor:
		if not _outdoor_time_ok(path):
			return false
	for path in ["res://scenarios/practice_hub/practice_hub.tscn", GameManager.MESH_LAB_SCENE]:
		if not _sky_scene_ok(path):
			return false
	if not _saloon_time_ok():
		return false
	print("AUTOTEST: time of day keeps the horizon contract")
	return true


func _outdoor_time_ok(path: String) -> bool:
	var instance := (load(path) as PackedScene).instantiate() as ScenarioBase
	add_child(instance)
	if _sky_shader(instance) == null:
		instance.queue_free()
		_fail("%s sky is not sky_western.gdshader" % path)
		return false
	var snap := _horizon_snapshot(instance)
	var cover := -1.0
	var offset := Vector2.ZERO
	for t in [0.0, 0.5, 1.0]:
		instance.apply_time(t)
		if not _horizon_unchanged(instance, snap, path):
			instance.queue_free()
			return false
		var world := instance.get_node("WorldEnvironment") as WorldEnvironment
		var mat := _sky_shader(instance)
		var ground: Color = mat.get_shader_parameter(&"ground_horizon")
		if not world.environment.fog_light_color.is_equal_approx(ground):
			instance.queue_free()
			_fail("%s fog tint drifted from the sky ground at t=%.1f" % [path, t])
			return false
		var sun := instance.get_node("Sun") as DirectionalLight3D
		if sun.light_energy < 0.85 or sun.light_energy > 1.3:
			instance.queue_free()
			_fail("%s sun energy %.2f is outside the readable band" % [path, sun.light_energy])
			return false
		var yaw := atan2(sun.global_transform.basis.z.x, sun.global_transform.basis.z.z)
		if absf(angle_difference(yaw, float(snap["yaw"]))) > 0.02:
			instance.queue_free()
			_fail("%s sun yaw moved off the authored azimuth" % path)
			return false
		var want_cloud := sun.light_color.lerp(Color.WHITE, TimeOfDay.CLOUD_WHITE_MIX)
		var got_cloud: Color = mat.get_shader_parameter(&"cloud_color")
		if not got_cloud.is_equal_approx(want_cloud):
			instance.queue_free()
			_fail("%s cloud tint does not follow the sun color at t=%.1f" % [path, t])
			return false
		var rolled := float(mat.get_shader_parameter(&"cloud_cover"))
		var rolled_offset: Vector2 = mat.get_shader_parameter(&"cloud_offset")
		if cover < 0.0:
			cover = rolled
			offset = rolled_offset
			if cover < ScenarioBase.CLOUD_COVER_MIN - 0.001 \
					or cover > ScenarioBase.CLOUD_COVER_MAX + 0.001:
				instance.queue_free()
				_fail("%s cloud cover %.2f is outside the rolled band" % [path, cover])
				return false
		elif not is_equal_approx(rolled, cover) or not rolled_offset.is_equal_approx(offset):
			instance.queue_free()
			_fail("%s cloud roll changed while scrubbing time of day" % path)
			return false
		if t == 0.0 or t == 1.0:
			var elev := rad_to_deg(asin(clampf(sun.global_transform.basis.z.y, -1.0, 1.0)))
			var expect: float = TimeOfDay.DUSK_ELEVATION_DEG
			if is_equal_approx(t, 0.0):
				expect = TimeOfDay.DAWN_ELEVATION_DEG
			if absf(elev - expect) > 1.0:
				instance.queue_free()
				_fail("%s sun elevation %.1f, expected %.1f" % [path, elev, expect])
				return false
	var ok := _cloud_drift_ok(instance, path)
	instance.queue_free()
	return ok


## The deck moves `cloud_speed` per second in one direction, wraps inside [0, 1), and
## stops (no `_process`) at speed 0.
func _cloud_drift_ok(instance: ScenarioBase, path: String) -> bool:
	var mat := _sky_shader(instance)
	var before: Vector2 = mat.get_shader_parameter(&"cloud_offset")
	instance._process(1.0)
	var after: Vector2 = mat.get_shader_parameter(&"cloud_offset")
	var moved := Vector2(wrapf(after.x - before.x, -0.5, 0.5), wrapf(after.y - before.y, -0.5, 0.5))
	if absf(moved.length() - instance.cloud_speed) > 0.0005:
		_fail("%s clouds drifted %.4f in 1 s, expected %.4f" % [path, moved.length(), instance.cloud_speed])
		return false
	if after.x < 0.0 or after.x >= 1.0 or after.y < 0.0 or after.y >= 1.0:
		_fail("%s cloud offset %s left [0, 1)" % [path, after])
		return false
	instance.set_cloud_speed(0.0)
	instance._process(1.0)
	var frozen: Vector2 = mat.get_shader_parameter(&"cloud_offset")
	if instance.is_processing() or not frozen.is_equal_approx(after):
		_fail("%s clouds still drift at cloud_speed 0" % path)
		return false
	return true


## Scenes the time test does not instance (the hub and the mesh lab spin up gameplay on
## `_ready`): only check that their sky is the western shader.
func _sky_scene_ok(path: String) -> bool:
	var instance := (load(path) as PackedScene).instantiate()
	var ok := _sky_shader(instance) != null
	instance.free()
	if not ok:
		_fail("%s sky is not sky_western.gdshader" % path)
	return ok


func _sky_shader(root: Node) -> ShaderMaterial:
	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null or world.environment.sky == null:
		return null
	var mat := world.environment.sky.sky_material as ShaderMaterial
	if mat == null or mat.shader == null \
			or not mat.shader.resource_path.ends_with("sky_western.gdshader"):
		return null
	return mat


func _saloon_time_ok() -> bool:
	var instance := (load("res://scenarios/saloon/saloon.tscn") as PackedScene).instantiate() as ScenarioBase
	add_child(instance)
	var lamp := instance.get_node("Chandelier") as OmniLight3D
	var env := (instance.get_node("WorldEnvironment") as WorldEnvironment).environment
	var energy := lamp.light_energy
	var color := lamp.light_color
	var background := env.background_color
	var ambient := env.ambient_light_energy
	instance.apply_time(0.25)
	var unchanged := instance.get_node_or_null("Sun") == null \
			and is_equal_approx(lamp.light_energy, energy) \
			and lamp.light_color.is_equal_approx(color) \
			and env.background_color.is_equal_approx(background) \
			and is_equal_approx(env.ambient_light_energy, ambient) \
			and not instance.is_processing()
	instance.queue_free()
	if not unchanged:
		_fail("saloon lighting changed with time of day")
		return false
	return true


func _horizon_snapshot(root: Node) -> Dictionary:
	var env := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	var mat := _sky_shader(root)
	var sun := root.get_node("Sun") as DirectionalLight3D
	var toward_sun := sun.global_transform.basis.z
	return {
		"fog_mode": env.fog_mode,
		"fog_density": env.fog_density,
		"fog_depth_begin": env.fog_depth_begin,
		"fog_depth_end": env.fog_depth_end,
		"fog_depth_curve": env.fog_depth_curve,
		"fog_aerial_perspective": env.fog_aerial_perspective,
		"fog_sky_affect": env.fog_sky_affect,
		"sky_curve": mat.get_shader_parameter(&"sky_curve"),
		"ground_curve": mat.get_shader_parameter(&"ground_curve"),
		"shadow_max": sun.directional_shadow_max_distance,
		"shadow_fade": sun.directional_shadow_fade_start,
		"split1": sun.directional_shadow_split_1,
		"split2": sun.directional_shadow_split_2,
		"split3": sun.directional_shadow_split_3,
		"yaw": atan2(toward_sun.x, toward_sun.z),
	}


func _horizon_unchanged(root: Node, snap: Dictionary, path: String) -> bool:
	var now := _horizon_snapshot(root)
	for key in snap:
		if key == "yaw":
			continue
		var before: Variant = snap[key]
		var after: Variant = now[key]
		var same: bool = before == after
		if before is float and after is float:
			same = is_equal_approx(before, after)
		if not same:
			_fail("%s changed %s when applying time of day" % [path, key])
			return false
	return true


## Proximity voice plumbing: the bus layout, the mute-X on the avatar, and the
## codec round trip. Headless CI has no mic, so capture itself is not asserted —
## only that everything downstream of it is wired and that voice stays off.
func _voice_ok() -> bool:
	for bus_name in ["Master", "Voice", "Mic"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("audio bus %s missing (default_bus_layout.tres not loaded?)" % bus_name)
			return false
	var mic_bus := AudioServer.get_bus_index("Mic")
	if not AudioServer.is_bus_mute(mic_bus):
		_fail("the Mic bus must stay muted or players hear themselves")
		return false
	var has_capture := false
	for i in AudioServer.get_bus_effect_count(mic_bus):
		if AudioServer.get_bus_effect(mic_bus, i) is AudioEffectCapture:
			has_capture = true
			break
	if not has_capture:
		_fail("the Mic bus has no AudioEffectCapture")
		return false
	# Headless CI has no microphone, so only the dummy-driver case is asserted;
	# on a real driver this doubles as a live check that capture starts.
	var dummy_audio := OS.has_feature("headless") or AudioServer.get_driver_name() == "Dummy"
	if dummy_audio and VoiceChat.is_available():
		_fail("voice should report unavailable on the dummy audio driver")
		return false
	VoiceChat.add_monitor()
	await get_tree().process_frame
	if VoiceChat.is_capturing() != VoiceChat.is_available():
		VoiceChat.remove_monitor()
		_fail("a mic monitor should capture exactly when voice is available")
		return false
	VoiceChat.remove_monitor()
	if VoiceChat.is_capturing():
		_fail("dropping the last mic monitor should stop capture")
		return false
	print("AUTOTEST: audio driver %s, voice available=%s" % [
		AudioServer.get_driver_name(), VoiceChat.is_available()])
	if not _voice_codec_ok():
		return false
	var scene := load("res://player/remote_avatar.tscn") as PackedScene
	var avatar: RemoteAvatar = scene.instantiate()
	var other: RemoteAvatar = scene.instantiate()
	add_child(avatar)
	add_child(other)
	await get_tree().process_frame
	var ok := _voice_avatars_ok(avatar, other)
	VoiceChat.bind_voice_player(VOICE_TEST_PEERS[0], null)
	VoiceChat.bind_voice_player(VOICE_TEST_PEERS[1], null)
	avatar.queue_free()
	other.queue_free()
	if not ok:
		return false
	if not VoiceChat.bound_peers().is_empty():
		_fail("unbinding both senders should leave no voice bound")
		return false
	print("AUTOTEST: voice buses, per-peer binding, mute X, and availability gate ok")
	return true


const VOICE_TEST_PEERS: Array[int] = [101, 102]


## Two avatars, two senders: each sender plays from its own mouth on the Voice bus through the
## one shared stream (BUG-021: no stream per sender), a mute raises the X on its own avatar
## only, a sender with no session is dropped, and binding a peer again replaces its player.
func _voice_avatars_ok(avatar: RemoteAvatar, other: RemoteAvatar) -> bool:
	if avatar.voice_player == null or avatar.mute_icon == null:
		_fail("remote avatar is missing VoicePlayer / MuteX under the mouth")
		return false
	var generator := VoiceChat._generator
	VoiceChat.bind_voice_player(VOICE_TEST_PEERS[0], avatar.voice_player)
	VoiceChat.bind_voice_player(VOICE_TEST_PEERS[1], other.voice_player)
	var bound := VoiceChat.bound_peers()
	bound.sort()
	if bound != VOICE_TEST_PEERS or VoiceChat.bound_player(VOICE_TEST_PEERS[0]) != avatar.voice_player 			or VoiceChat.bound_player(VOICE_TEST_PEERS[1]) != other.voice_player or VoiceChat.bound_player(999) != null:
		_fail("voice is not bound per peer (%s)" % [bound])
		return false
	for player: AudioStreamPlayer3D in [avatar.voice_player, other.voice_player]:
		if player.bus != &"Voice" or player.stream != generator or generator == null:
			_fail("avatar voice player is on bus %s with stream %s, expected Voice and the shared generator" % [
					player.bus, player.stream])
			return false
	if VoiceChat._take_packet(VOICE_TEST_PEERS[0], 1, PackedByteArray()) or not VoiceChat.packets_accepted.is_empty():
		_fail("a voice packet was taken with no session")
		return false
	avatar.apply_pose(Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY,
			NetworkManager.POSE_FLAG_VOICE_MUTED)
	if not avatar.mute_icon.visible or other.mute_icon.visible:
		_fail("POSE_FLAG_VOICE_MUTED did not raise the mouth X on that avatar only")
		return false
	avatar.apply_pose(Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, 0)
	if avatar.mute_icon.visible:
		_fail("clearing the mute flag did not hide the mouth X")
		return false
	# The same peer on a new avatar (every duel rebuilds them) drops the old one.
	VoiceChat.bind_voice_player(VOICE_TEST_PEERS[0], other.voice_player)
	if VoiceChat.bound_player(VOICE_TEST_PEERS[0]) != other.voice_player or VoiceChat.bound_peers().size() != 2 			or VoiceChat._generator != generator:
		_fail("binding a peer again should replace its player and keep the one generator")
		return false
	VoiceChat.bind_voice_player(VOICE_TEST_PEERS[0], null)
	if VoiceChat.bound_player(VOICE_TEST_PEERS[0]) != null or VoiceChat.bound_peers() != [VOICE_TEST_PEERS[1]]:
		_fail("unbinding a peer should leave only the other one")
		return false
	return true


## Codec round trip with a synthetic tone, so the wire format is checked without
## a microphone: driver-rate stereo in, one 20 ms mono PCM16 packet out.
func _voice_codec_ok() -> bool:
	const AMPLITUDE := 0.5
	var rate := AudioServer.get_mix_rate()
	var count := int(round(rate * float(VoiceChat.FRAME_SAMPLES) / float(VoiceChat.SEND_RATE)))
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in count:
		var sample := sin(TAU * 440.0 * float(i) / rate) * AMPLITUDE
		frames[i] = Vector2(sample, sample)
	VoiceChat._hp_x = 0.0
	VoiceChat._hp_y = 0.0
	var pcm: PackedByteArray = VoiceChat._encode(frames)
	var expected := VoiceChat.FRAME_SAMPLES * 2
	if pcm.size() != expected:
		_fail("voice packet is %d bytes, expected %d" % [pcm.size(), expected])
		return false
	var peak := 0.0
	for i in VoiceChat.FRAME_SAMPLES:
		peak = maxf(peak, absf(float(pcm.decode_s16(i * 2)) / 32767.0))
	# Box-averaging a 440 Hz tone barely attenuates it, so the peak must survive.
	# The high-pass sits at 180 Hz, well below this, and the noise-gate expander
	# is a no-op above the cutoff.
	if absf(peak - AMPLITUDE) > 0.08:
		_fail("voice codec peak %.3f drifted from %.3f" % [peak, AMPLITUDE])
		return false
	if VoiceChat.last_rms < 0.2:
		_fail("440 Hz tone RMS %.3f should look like speech" % VoiceChat.last_rms)
		return false
	# Room-tone should sit under the default gate so it is not transmitted.
	var saved_gate := PlayerSettings.voice_gate_cutoff
	PlayerSettings.voice_gate_cutoff = 0.08
	var noise := PackedVector2Array()
	noise.resize(count)
	for i in count:
		noise[i] = Vector2(0.01, 0.01)
	VoiceChat._hp_x = 0.0
	VoiceChat._hp_y = 0.0
	var quiet: PackedByteArray = VoiceChat._encode(noise)
	PlayerSettings.voice_gate_cutoff = saved_gate
	if quiet.size() != expected:
		_fail("quiet packet is %d bytes, expected %d" % [quiet.size(), expected])
		return false
	if VoiceChat.last_rms >= 0.08:
		_fail("0.01 DC / rumble RMS %.3f should be below the default noise gate" % VoiceChat.last_rms)
		return false
	if VoiceChat._encode(PackedVector2Array()).size() != 0:
		_fail("an empty capture buffer should not produce a packet")
		return false
	print("AUTOTEST: voice codec ok (%d frames @ %d Hz -> %d B, peak %.3f)" % [
		count, int(rate), pcm.size(), peak])
	return true


## BUG-009: transports are reused for the whole process, so leaving a session
## has to put NetworkManager back where host / join work again. Each session also
## starts from the default roster and takes edits through the host API.
func _leave_rejoin_ok() -> bool:
	for attempt in 2:
		if NetworkManager.host_lan() != OK:
			_fail("host_lan() failed on attempt %d (leave did not release the transport)" % (attempt + 1))
			return false
		if not NetworkManager.is_active():
			_fail("session not active after host_lan()")
			return false
		if not _host_roster_api_ok():
			return false
		NetworkManager.leave("autotest")
		if NetworkManager.host_set_slot_count(3) or NetworkManager.host_start() \
				or NetworkManager.discovery._host_slots != "":
			_fail("the host roster API still works after leave()")
			return false
		if NetworkManager.is_active() or NetworkManager.transport != null:
			_fail("leave() left the session active")
			return false
		if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			_fail("leave() did not reset the multiplayer peer to offline")
			return false
	print("AUTOTEST: host -> leave -> host again ok, peer reset to offline")
	return true


## A hosted session with nobody in it: the default roster, the host_* edits, and the
## `open/total` field the beacon advertises.
func _host_roster_api_ok() -> bool:
	var net := NetworkManager
	var roster := net.roster
	if roster.slots.size() != 2 or roster.local_slot() != 0 or roster.mode != LobbyRoster.Mode.FFA \
			or roster.slots[0]["name"] != net.local_player_name() or roster.open_human_slots() != 1:
		_fail("a new session did not start from the default roster: %s" % roster.pack())
		return false
	if not GameManager.in_mp_lobby() or net.joinable_slots() != 1 or net.discovery._host_slots != "1/2":
		_fail("hosting did not open a joinable waiting room (beacon '%s')" % net.discovery._host_slots)
		return false
	var syncs := [0]
	var on_sync := func() -> void: syncs[0] += 1
	net.roster_changed.connect(on_sync)
	var applied := net.host_set_slot_count(4) and net.host_set_slot_kind(3, LobbyRoster.Kind.NPC) \
			and net.host_set_archetype(3, 1) and net.host_set_npc_side(3, 0) \
			and net.host_set_mode(LobbyRoster.Mode.TEAMS)
	net.request_side(1)
	net.roster_changed.disconnect(on_sync)
	if not applied or syncs[0] != 6:
		_fail("host roster edits: applied=%s, %d syncs for 6 edits" % [applied, syncs[0]])
		return false
	if roster.slots.size() != 4 or roster.slots[3]["kind"] != LobbyRoster.Kind.NPC \
			or roster.slots[3]["archetype"] != 1 or roster.side_of(3) != 0 or roster.side_of(0) != 1:
		_fail("host roster edits did not land: %s" % roster.pack())
		return false
	if net.host_set_slot_count(1) or net.host_set_slot_count(5) or net.host_set_slot_kind(0, LobbyRoster.Kind.NPC) \
			or net.host_set_slot_kind(1, LobbyRoster.Kind.HUMAN) or net.host_set_npc_side(1, 0) \
			or net.host_set_archetype(3, GameManager.ARCHETYPES.size()) or net.host_kick(1) \
			or net.host_kick(0) or net.host_set_mode(7) or net.host_set_scenario(GameManager.SCENARIOS.size()):
		_fail("the host roster API accepted an invalid edit: %s" % roster.pack())
		return false
	net._refresh_advert()
	if net.joinable_slots() != 2 or net.discovery._host_slots != "2/3":
		_fail("the beacon advertises '%s' for 2 open of 3 human slots" % net.discovery._host_slots)
		return false
	if net.start_refusal() != "MSG_LOBBY_NOT_FULL" or net.host_start() or not GameManager.in_mp_lobby():
		_fail("host_start() should refuse while a slot is open (%s)" % net.start_refusal())
		return false
	# No open slot left: the host and three NPCs, Teams, sides 1 / 1 / 0 / 0. A lobby with no
	# other human may start, in either mode, unless a side is empty.
	net.host_set_slot_kind(1, LobbyRoster.Kind.NPC)
	net.host_set_slot_kind(2, LobbyRoster.Kind.NPC)
	if not roster.can_start() or net.start_refusal() != "" or not GameManager.in_mp_lobby():
		_fail("a Teams lobby of the host and NPC slots, both sides filled, should be able to start (%s)" % net.start_refusal())
		return false
	if not net.host_set_npc_side(2, 1) or not net.host_set_npc_side(3, 1) or roster.can_start() \
			or net.start_refusal() != "MSG_LOBBY_EMPTY_SIDE" or net.host_start() or not GameManager.in_mp_lobby():
		_fail("host_start() should refuse Teams with an empty side (%s)" % net.start_refusal())
		return false
	if not net.host_set_mode(LobbyRoster.Mode.FFA) or net.start_refusal() != "" or not GameManager.in_mp_lobby():
		_fail("a lobby of the host and NPC slots should be able to start (%s)" % net.start_refusal())
		return false
	var other := (GameManager.current_scenario_index + 1) % GameManager.SCENARIOS.size()
	var back := GameManager.current_scenario_index
	if not net.host_set_scenario(other) or GameManager.current_scenario_index != other \
			or not GameManager.in_mp_lobby():
		_fail("host_set_scenario() in the waiting room did not move the arena")
		return false
	if not net.host_set_scenario(back) or not net.host_back_to_lobby() or not GameManager.in_mp_lobby():
		_fail("host_back_to_lobby() did not reopen the waiting room")
		return false
	print("AUTOTEST: host roster API ok (edits, refusals, beacon slots, START guard)")
	return true


## Landing is Singleplayer / Multiplayer / Settings / Quit. LAN/Steam browse
## only starts while the MP page is showing.
func _main_menu_split_ok() -> bool:
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	if not menu.get_node("%Landing").visible:
		menu.queue_free()
		_fail("main menu landing is hidden on open")
		return false
	if menu.get_node("%SingleplayerPage").visible or menu.get_node("%MultiplayerPage").visible:
		menu.queue_free()
		_fail("SP / MP pages should start hidden")
		return false
	if NetworkManager.discovery._role != LanDiscovery.Role.IDLE:
		menu.queue_free()
		_fail("LAN browse started on the landing page")
		return false
	menu.get_node("%SingleplayerButton").pressed.emit()
	if not menu.get_node("%SingleplayerPage").visible or menu.get_node("%Landing").visible:
		menu.queue_free()
		_fail("Singleplayer button did not open the SP page")
		return false
	for mode in [["%GauntletModeButton", "%GauntletPage"], ["%DuelModeButton", "%DuelPage"],
			["%HordeModeButton", "%HordePage"]]:
		menu.get_node(mode[0]).pressed.emit()
		if not menu.get_node(mode[1]).visible or menu.get_node("%SingleplayerPage").visible:
			menu.queue_free()
			_fail("%s did not open %s" % mode)
			return false
		if not menu.go_back() or not menu.get_node("%SingleplayerPage").visible:
			menu.queue_free()
			_fail("Back from %s did not return to the SP list" % mode[1])
			return false
	if not menu.go_back() or not menu.get_node("%Landing").visible:
		menu.queue_free()
		_fail("Back from Singleplayer did not return to landing")
		return false
	menu.get_node("%MultiplayerButton").pressed.emit()
	if not menu.get_node("%MultiplayerPage").visible:
		menu.queue_free()
		_fail("Multiplayer button did not open the MP page")
		return false
	if NetworkManager.discovery._role != LanDiscovery.Role.BROWSE:
		menu.queue_free()
		_fail("LAN browse did not start on the Multiplayer page")
		return false
	if not OS.has_feature("android") and NetworkManager.steam_available() and not NetworkManager._steam_browse:
		menu.queue_free()
		_fail("Steam browse did not start on the Multiplayer page")
		return false
	# Rows show open/total; a lobby with no open slot is disabled.
	var version := NetworkManager.game_version()
	menu._on_lan_hosts([
		{"ip": "192.168.1.10", "name": "Open", "version": version, "open": 1, "total": 2},
		{"ip": "192.168.1.11", "name": "Full", "version": version, "open": 0, "total": 4},
	])
	menu._on_steam_lobbies([
		{"id": 1, "name": "Open", "version": version, "compatible": true, "open": 2, "total": 3},
		{"id": 2, "name": "Full", "version": version, "compatible": true, "open": 0, "total": 2},
	])
	var lan := menu.lan_list
	var steam := menu.steam_list
	var rows_ok := lan.item_count == 2 and steam.item_count == 2 \
			and not lan.is_item_disabled(0) and lan.is_item_disabled(1) \
			and not steam.is_item_disabled(0) and steam.is_item_disabled(1) \
			and lan.get_item_text(0).contains("1/2") and lan.get_item_text(1).contains("0/4") \
			and steam.get_item_text(0).contains("2/3") and steam.get_item_text(1).contains("0/2")
	var row_text := "%s | %s" % [lan.get_item_text(0), steam.get_item_text(0)]
	menu._on_lan_hosts([])
	menu._on_steam_lobbies([])
	if not rows_ok:
		menu.queue_free()
		_fail("LAN / Steam rows should show open/total and disable full lobbies (%s)" % row_text)
		return false
	if not menu.go_back():
		menu.queue_free()
		_fail("Back from Multiplayer did not return to landing")
		return false
	if NetworkManager.discovery._role != LanDiscovery.Role.IDLE:
		menu.queue_free()
		_fail("LAN browse kept running after leaving the Multiplayer page")
		return false
	if NetworkManager._steam_browse:
		menu.queue_free()
		_fail("Steam browse kept running after leaving the Multiplayer page")
		return false
	menu.queue_free()
	print("AUTOTEST: main menu SP / MP split ok")
	return true


## Radial wedge picking plus the cigarette's hold → throw → catch cycle.
func _props_ok() -> bool:
	var wheel_font: Font = preload("res://ui/theme_duello.tres").default_font
	if wheel_font == null:
		_fail("duello theme has no font for the prop wheel")
		return false
	var wheel := PropRadialOverlay.new()
	add_child(wheel)
	wheel.show_wheel(PackedStringArray(["Empty Hand", "Cigarette", "Coin", "Ace of Spades", "Bottle"]))
	wheel.notification(CanvasItem.NOTIFICATION_DRAW)
	wheel.free()

	var count := PropController.ITEMS.size()
	if PropController.highlight_index(Vector2.ZERO, count) != -1:
		_fail("centered stick should cancel, not highlight")
		return false
	if PropController.highlight_index(Vector2(0.0, 1.0), count) != 0:
		_fail("up should highlight the first wedge")
		return false
	if count != 5:
		_fail("radial should list Empty Hand, Cigarette, Coin, Ace of Spades, Bottle")
		return false
	if PropController.highlight_index(Vector2(0.0, -1.0), count) != 3:
		_fail("down should highlight wedge 3")
		return false

	var attach := Node3D.new()
	add_child(attach)
	attach.global_position = Vector3(0.0, 1.2, 0.0)
	var cig := Cigarette.spawn_held(attach)
	if cig.is_flying() or cig.get_parent() != attach:
		_fail("a fresh cigarette should be held on its attach")
		return false
	var aabb: AABB = (cig.get_node("Model/MSC_Cigarette") as MeshInstance3D).get_aabb()
	if aabb.size.y < aabb.size.x * 4.0:
		_fail("cigarette long axis should be +Y, got %s" % aabb.size)
		return false

	cig.begin_charge()
	if cig.is_flying():
		_fail("charging should keep the cigarette in hand")
		return false
	var started := Time.get_ticks_msec()
	cig.release_charge(self, Vector3.FORWARD)
	if not cig.is_flying():
		_fail("cigarette did not launch on release")
		return false
	var caught := await _wait_for(func() -> bool: return not cig.is_flying(), 10.0)
	if not caught:
		_fail("cigarette never came back to the hand")
		return false
	if cig.get_parent() != attach:
		_fail("caught cigarette did not re-seat on the attach")
		return false
	# A tap covers `cig_min_range` but must still hover out the rest of
	# `cig_flight_time`, so every throw reads at the same pace.
	var tap_flight := float(Time.get_ticks_msec() - started) / 1000.0
	var want: float = float(GameManager.tuning["cig_flight_time"])
	if absf(tap_flight - want) > 0.3:
		_fail("tap throw took %.2fs, expected ~%.2fs" % [tap_flight, want])
		return false

	# Same again at full charge: much further, but the same time on the clock.
	cig.begin_charge()
	await _sleep(float(GameManager.tuning["cig_charge_time"]) + 0.2)
	if cig.charge_ratio() < 1.0:
		_fail("holding past cig_charge_time did not reach full charge")
		return false
	started = Time.get_ticks_msec()
	cig.release_charge(self, Vector3.FORWARD)
	if not await _wait_for(func() -> bool: return not cig.is_flying(), 10.0):
		_fail("charged cigarette never came back to the hand")
		return false
	var full_flight := float(Time.get_ticks_msec() - started) / 1000.0
	if absf(full_flight - tap_flight) > 0.25:
		_fail("tap took %.2fs but a full throw took %.2fs" % [tap_flight, full_flight])
		return false
	print("AUTOTEST: throw length normalized (tap %.2fs, charged %.2fs)"
			% [tap_flight, full_flight])

	# A wall on the outbound path skips the hover and comes home early.
	var wall := _make_prop_wall(Vector3(0.0, 1.2, -0.45))
	await _sleep(0.05)
	started = Time.get_ticks_msec()
	cig.begin_charge()
	cig.release_charge(self, Vector3.FORWARD)
	if not await _wait_for(func() -> bool: return not cig.is_flying(), 4.0):
		_fail("cigarette that hit a wall never came home")
		return false
	var wall_flight := float(Time.get_ticks_msec() - started) / 1000.0
	if wall_flight > 0.8:
		_fail("wall throw took %.2fs, should have skipped the hover" % wall_flight)
		return false
	if cig.get_parent() != attach:
		_fail("wall throw did not re-seat the cigarette")
		return false
	wall.free()

	# A practice bottle on the path shatters, then the cig still homes.
	var bottle: PracticeBottle = preload("res://practice/practice_bottle.tscn").instantiate()
	add_child(bottle)
	bottle.set_home(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.085, -0.5)))
	_fatten_bottle(bottle)
	bottle.collision_layer = PracticeBottle.LAYER | 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	cig.begin_charge()
	cig.release_charge(self, Vector3.FORWARD)
	if not await _wait_for(func() -> bool: return bottle.state == PracticeBottle.State.BROKEN, 3.0):
		_fail("cigarette did not shatter a practice bottle (state=%s flying=%s)" % [
			bottle.state, cig.is_flying()])
		return false
	if not await _wait_for(func() -> bool: return not cig.is_flying(), 4.0):
		_fail("cigarette never came home after shattering a bottle")
		return false
	bottle.queue_free()

	# Return-path bottle: wait until the cig is at the far end, then plant one
	# between it and the hand so only the home leg can hit.
	cig.begin_charge()
	cig.release_charge(self, Vector3.FORWARD)
	if not await _wait_for(func() -> bool:
			return cig.state == Cigarette.State.HOVERING \
					or cig.state == Cigarette.State.RETURNING, 3.0):
		_fail("cigarette never reached the far end for a return-path bottle")
		return false
	var home_bottle: PracticeBottle = preload("res://practice/practice_bottle.tscn").instantiate()
	add_child(home_bottle)
	home_bottle.set_home(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.085, -0.35)))
	_fatten_bottle(home_bottle)
	home_bottle.collision_layer = PracticeBottle.LAYER | 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not await _wait_for(func() -> bool: return home_bottle.state == PracticeBottle.State.BROKEN, 3.0):
		_fail("returning cigarette did not shatter a bottle (state=%s flying=%s)" % [
			home_bottle.state, cig.is_flying()])
		return false
	if not await _wait_for(func() -> bool: return not cig.is_flying(), 4.0):
		_fail("cigarette never came home after a return-path shatter")
		return false
	home_bottle.queue_free()
	cig.queue_free()
	print("AUTOTEST: cigarette wall return + bottle shatter ok")

	if not await _coin_ok():
		return false
	if not await _ace_ok():
		return false
	if not await _bottle_ok():
		return false

	attach.queue_free()
	print("AUTOTEST: prop radial picking + cigarette / coin / ace / bottle ok")
	return true


func _palm_up_basis() -> Basis:
	# Coin palm is attach -Z, so -Z must be world up.
	return Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN)


func _fatten_bottle(bottle: PracticeBottle) -> void:
	var extra := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	extra.shape = box
	extra.position = Vector3(0.0, 0.115, 0.0)
	bottle.add_child(extra)


func _make_prop_floor(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.2, 8.0)
	col.shape = box
	body.add_child(col)
	add_child(body)
	body.global_position = pos
	return body


func _make_prop_wall(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 0.16)
	col.shape = box
	body.add_child(col)
	add_child(body)
	body.global_position = pos
	return body


func _coin_ok() -> bool:
	var floor := _make_prop_floor(Vector3(2.0, 0.0, 0.0))
	var attach := Node3D.new()
	add_child(attach)
	attach.global_position = Vector3(2.0, 1.2, 0.0)
	attach.basis = _palm_up_basis()
	var coin := Coin.spawn_held(attach)
	coin.balance_drop = false
	if coin.get_parent() != attach or coin.is_loose():
		_fail("a fresh coin should rest on its attach")
		return false
	await _sleep(0.12)
	# Flat: looking around / a tilted attach must not dump the coin.
	attach.basis = Basis.IDENTITY
	await _sleep(0.2)
	if coin.is_loose():
		_fail("flat coin should stay in hand until it is flipped")
		return false
	attach.basis = _palm_up_basis()

	# G flip: toss up. It should either land back on the hand or rest on the floor.
	var world_root := Node3D.new()
	add_child(world_root)
	coin.begin_charge()
	coin.release_charge(world_root, Vector3.UP)
	if not coin.is_loose():
		_fail("coin flip did not launch on release")
		return false
	if not await _wait_for(func() -> bool:
			return coin.is_in_hand() or (coin.is_loose() and not coin.is_flying() and coin.global_position.y > 0.0), 4.0):
		_fail("flipped coin neither landed on the hand nor rested on the floor (y=%s)" % coin.global_position.y)
		return false
	if coin.is_loose():
		coin.hold_at(attach)
	if not coin.is_in_hand() or coin.get_parent() != attach:
		_fail("coin did not return to the hand after the flip")
		return false
	coin.choose_toss_face(-1.0)
	coin.begin_charge()
	coin.release_charge(world_root, Vector3.UP)
	if not await _wait_for(func() -> bool: return coin.is_in_hand(), 4.0):
		_fail("forced heads toss did not land back on the hand")
		return false
	if not coin.showing_heads():
		_fail("forced heads toss still showed tails")
		return false
	coin.choose_toss_face(1.0)
	coin.begin_charge()
	coin.release_charge(world_root, Vector3.UP)
	if not await _wait_for(func() -> bool: return coin.is_in_hand(), 4.0):
		_fail("forced tails toss did not land back on the hand")
		return false
	if coin.showing_heads():
		_fail("forced tails toss still showed heads")
		return false

	# VR balance: a tilted palm drops it as a solid that rests on the floor.
	coin.balance_drop = true
	attach.basis = Basis.IDENTITY
	if not await _wait_for(func() -> bool: return coin.is_loose(), 1.0):
		_fail("tilting the VR palm did not drop the coin")
		return false
	if not await _wait_for(func() -> bool: return not coin.is_flying() and coin.global_position.y > 0.0, 3.0):
		_fail("dropped coin clipped through the floor (y=%s)" % coin.global_position.y)
		return false
	if not coin.can_pick_up():
		_fail("resting coin should be pickable")
		return false
	coin.hold_at(attach)
	if not coin.is_in_hand():
		_fail("picked-up coin did not return to the hand")
		return false
	world_root.queue_free()
	floor.queue_free()
	coin.queue_free()
	attach.queue_free()
	print("AUTOTEST: coin flat flip + solid drop + pickup ok")
	return true


func _ace_ok() -> bool:
	var world_root := Node3D.new()
	add_child(world_root)
	var floor := _make_prop_floor(Vector3(4.0, 0.0, 0.0))
	var attach := Node3D.new()
	add_child(attach)
	attach.global_position = Vector3(4.0, 1.2, 0.0)
	var ace := AceOfSpades.spawn_held(attach)
	if ace.is_flying() or ace.get_parent() != attach:
		_fail("a fresh ace should be held on its attach")
		return false
	var wall := _make_prop_wall(Vector3(4.0, 1.2, -0.5))
	await _sleep(0.05)
	ace.begin_charge()
	await _sleep(0.2)
	ace.release_charge(world_root, Vector3.FORWARD)
	if not ace.is_loose():
		_fail("ace did not launch on release")
		return false
	if not await _wait_for(func() -> bool: return ace.is_loose() and not ace.is_flying(), 4.0):
		_fail("ace never came to rest as a physics object")
		return false
	if ace.get_parent() == attach:
		_fail("thrown ace should not reparent home")
		return false
	if not ace.can_pick_up():
		_fail("resting ace should be pickable")
		return false
	ace.hold_at(attach)
	if not ace.is_in_hand() or ace.get_parent() != attach:
		_fail("picked-up ace did not return to the hand")
		return false
	wall.free()

	# A bottle in front of a second ace shatters and the card stays in the world.
	var ace2 := AceOfSpades.spawn_held(attach)
	var bottle: PracticeBottle = preload("res://practice/practice_bottle.tscn").instantiate()
	add_child(bottle)
	bottle.set_home(Transform3D(Basis.IDENTITY, Vector3(4.0, 1.085, -0.5)))
	_fatten_bottle(bottle)
	bottle.collision_layer = PracticeBottle.LAYER | 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	ace2.begin_charge()
	ace2.release_charge(world_root, Vector3.FORWARD)
	if not await _wait_for(func() -> bool: return bottle.state == PracticeBottle.State.BROKEN, 3.0):
		_fail("ace did not shatter a practice bottle (state=%s flying=%s)" % [
			bottle.state, ace2.is_flying()])
		return false
	if ace2.get_parent() == attach:
		_fail("ace that hit a bottle should stay in the world")
		return false
	bottle.queue_free()
	ace.queue_free()
	ace2.queue_free()
	floor.queue_free()
	world_root.queue_free()
	attach.queue_free()
	print("AUTOTEST: ace physics throw + pickup + bottle shatter ok")
	return true


func _bottle_ok() -> bool:
	var world_root := Node3D.new()
	add_child(world_root)
	var floor := _make_prop_floor(Vector3(8.0, 0.0, 0.0))
	var attach := Node3D.new()
	add_child(attach)
	attach.global_position = Vector3(8.0, 1.2, 0.0)
	var bottle := Longneck.spawn_held(attach)
	if bottle.is_flying() or bottle.get_parent() != attach:
		_fail("a fresh bottle should be held on its attach")
		return false
	await _sleep(0.05)
	bottle.begin_charge()
	await _sleep(0.2)
	bottle.release_charge(world_root, Vector3.FORWARD)
	if not bottle.is_loose():
		_fail("bottle did not launch on release")
		return false
	if bottle.get_parent() == attach:
		_fail("thrown bottle should not reparent home")
		return false
	# A charge throw is faster than BREAK_SPEED, so park it for the pickup check.
	bottle.global_position = Vector3(8.0, 0.12, 0.0)
	bottle.linear_velocity = Vector3.ZERO
	bottle.angular_velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(bottle) or not bottle.can_pick_up():
		_fail("a set-down bottle should stay whole and pickable")
		return false
	bottle.hold_at(attach)
	if not bottle.is_in_hand() or bottle.get_parent() != attach:
		_fail("picked-up bottle did not return to the hand")
		return false

	var shot: WeakRef = weakref(bottle)
	bottle.take_bullet(bottle.center(), Vector3.FORWARD)
	if not await _wait_freed(shot, 1.0):
		_fail("a shot bottle should shatter and stay gone")
		return false

	var bottle2 := Longneck.spawn_held(attach)
	var rail: PracticeBottle = preload("res://practice/practice_bottle.tscn").instantiate()
	add_child(rail)
	rail.set_home(Transform3D(Basis.IDENTITY, Vector3(8.0, 1.085, -0.5)))
	_fatten_bottle(rail)
	rail.collision_layer = PracticeBottle.LAYER | 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	bottle2.begin_charge()
	await _sleep(0.2)
	bottle2.release_charge(world_root, Vector3.FORWARD)
	var thrown: WeakRef = weakref(bottle2)
	if not await _wait_for(func() -> bool: return rail.state == PracticeBottle.State.BROKEN, 3.0):
		_fail("thrown bottle did not shatter a practice bottle (state=%s)" % rail.state)
		return false
	if not await _wait_freed(thrown, 1.0):
		_fail("a fast bottle that hit glass should shatter itself")
		return false
	rail.queue_free()

	var bottle3 := Longneck.spawn_held(attach)
	var hit := {"collider": bottle3, "position": bottle3.center()}
	var queried: WeakRef = weakref(bottle3)
	if not PropFlight.shatter_if_bottle(hit):
		_fail("shatter_if_bottle should accept a longneck")
		return false
	if not await _wait_freed(queried, 1.0):
		_fail("shatter_if_bottle did not free the longneck")
		return false

	floor.queue_free()
	world_root.queue_free()
	attach.queue_free()
	print("AUTOTEST: bottle charge throw + pickup + shatter ok")
	return true


func _version_check_ok() -> bool:
	var local := NetworkManager.game_version()
	if local.is_empty():
		_fail("game_version() empty")
		return false
	if not NetworkManager.versions_match(local, local):
		_fail("versions_match should accept identical non-empty strings")
		return false
	if NetworkManager.versions_match("", local):
		_fail("versions_match should reject empty host version")
		return false
	if NetworkManager.versions_match(local, "9.9.9-alpha"):
		_fail("versions_match should reject different versions")
		return false
	var msg := NetworkManager.version_mismatch_message("0.1.0-alpha", "0.2.0-alpha")
	if not msg.contains("0.1.0-alpha") or not msg.contains("0.2.0-alpha"):
		_fail("mismatch message missing version strings: %s" % msg)
		return false
	var unknown := NetworkManager.version_mismatch_message("", local)
	if not unknown.contains("unknown (older build)"):
		_fail("empty host should read as older build: %s" % unknown)
		return false

	var with_ver := LanDiscovery.parse_pong_packet(
			"GUNSLINGER_HOST:192.168.1.10|DeskPC|0.5.2-alpha", "192.168.1.99")
	if with_ver.get("ip") != "192.168.1.10" or with_ver.get("name") != "DeskPC" \
			or with_ver.get("version") != "0.5.2-alpha":
		_fail("parse ip|name|version failed: %s" % with_ver)
		return false
	var legacy := LanDiscovery.parse_pong_packet(
			"GUNSLINGER_HOST:192.168.1.10|DeskPC", "192.168.1.99")
	if legacy.get("version") != "" or legacy.get("name") != "DeskPC":
		_fail("legacy ip|name parse failed: %s" % legacy)
		return false
	var bare := LanDiscovery.parse_pong_packet("GUNSLINGER_HOST:DeskPC", "192.168.1.10")
	if bare.get("ip") != "192.168.1.10" or bare.get("name") != "DeskPC" \
			or bare.get("version") != "":
		_fail("bare name parse failed: %s" % bare)
		return false
	var name_ver := LanDiscovery.parse_pong_packet(
			"GUNSLINGER_HOST:DeskPC|0.5.2-alpha", "192.168.1.10")
	if name_ver.get("name") != "DeskPC" or name_ver.get("version") != "0.5.2-alpha":
		_fail("name|version parse failed: %s" % name_ver)
		return false
	for old_form: Dictionary in [with_ver, legacy, bare, name_ver]:
		if old_form.get("total") != 0 or old_form.get("open") != 0:
			_fail("a beacon without a slot field should read total 0: %s" % old_form)
			return false
	var with_slots := LanDiscovery.parse_pong_packet(
			"GUNSLINGER_HOST:192.168.1.10|DeskPC|0.5.2-alpha|1/2", "192.168.1.99")
	if with_slots.get("ip") != "192.168.1.10" or with_slots.get("name") != "DeskPC" \
			or with_slots.get("version") != "0.5.2-alpha" or with_slots.get("open") != 1 \
			or with_slots.get("total") != 2:
		_fail("parse ip|name|version|open/total failed: %s" % with_slots)
		return false
	var piped := LanDiscovery.parse_pong_packet(
			"GUNSLINGER_HOST:192.168.1.10|Desk|PC|0.5.2-alpha|0/4", "192.168.1.99")
	if piped.get("name") != "Desk|PC" or piped.get("version") != "0.5.2-alpha" \
			or piped.get("open") != 0 or piped.get("total") != 4:
		_fail("parse of a piped name with a slot field failed: %s" % piped)
		return false
	var no_ip := LanDiscovery.parse_pong_packet(
			"GUNSLINGER_HOST:DeskPC|0.5.2-alpha|3/4", "192.168.1.10")
	if no_ip.get("ip") != "192.168.1.10" or no_ip.get("name") != "DeskPC" \
			or no_ip.get("version") != "0.5.2-alpha" or no_ip.get("open") != 3 or no_ip.get("total") != 4:
		_fail("parse name|version|open/total failed: %s" % no_ip)
		return false
	# What the beacon really sends must read back the same.
	var beacon := LanDiscovery.new()
	beacon._host_name = "DeskPC"
	beacon._host_version = local
	beacon.set_beacon_slots(LobbyRoster.format_slots(2, 3))
	var payloads := beacon._pong_payloads()
	beacon.free()
	if payloads.is_empty():
		_fail("the beacon built no payload")
		return false
	for payload in payloads:
		var sent := LanDiscovery.parse_pong_packet(payload.get_string_from_utf8(), "192.168.1.10")
		if sent.get("name") != "DeskPC" or sent.get("version") != local \
				or sent.get("open") != 2 or sent.get("total") != 3:
			_fail("beacon payload '%s' parsed as %s" % [payload.get_string_from_utf8(), sent])
			return false
	print("AUTOTEST: MP version helpers + LAN pong parse ok (slot field and legacy forms)")
	return true


## LobbyRoster is data only, so every rule is checked without a session.
## Least RGB distance between two lobby body tints.
const ROSTER_TINT_APART := 0.3


func _roster_ok() -> bool:
	var human := LobbyRoster.Kind.HUMAN
	var npc := LobbyRoster.Kind.NPC
	var open := LobbyRoster.Kind.OPEN
	if LobbyRoster.SLOT_TINTS.size() != LobbyRoster.MAX_SLOTS or LobbyRoster.SIDE_TINTS.size() != LobbyRoster.SIDES \
			or LobbyRoster.QUEST_MAX_SLOTS > LobbyRoster.MAX_SLOTS or ENetTransport.MAX_PLAYERS != 4 \
			or SteamTransport.MAX_PLAYERS != 4:
		_fail("roster constants: tints or caps do not cover 4 slots")
		return false
	for tints: Array[Color] in [LobbyRoster.SLOT_TINTS, LobbyRoster.SIDE_TINTS]:
		for a in tints.size():
			for b in a:
				var apart := Vector3(tints[a].r - tints[b].r, tints[a].g - tints[b].g, tints[a].b - tints[b].b).length()
				if apart < ROSTER_TINT_APART:
					_fail("roster tints %d and %d are too alike to tell apart (%.2f)" % [b, a, apart])
					return false
	var roster := LobbyRoster.new("Host")
	if roster.slots.size() != 2 or roster.slots[0]["kind"] != human or roster.slots[0]["peer_id"] != 1 \
			or roster.slots[1]["kind"] != open or roster.mode != LobbyRoster.Mode.FFA \
			or roster.open_human_slots() != 1 or roster.human_slots() != 2 or roster.can_start():
		_fail("default roster should be the host plus one open slot: %s" % roster.pack())
		return false
	# Slot assignment: the first OPEN slot, refused when none is left.
	if roster.assign_peer(77, "Ann") != 1 or roster.slot_of_peer(77) != 1 or roster.slot_of_peer(5) != -1 \
			or not roster.can_start() or roster.open_human_slots() != 0:
		_fail("assign_peer should give the joiner slot 1: %s" % roster.pack())
		return false
	if roster.assign_peer(88, "Bob") != -1 or roster.slot_of_peer(88) != -1:
		_fail("assign_peer should refuse a full lobby: %s" % roster.pack())
		return false
	if roster.set_slot_count(1) or roster.set_slot_count(5) or not roster.set_slot_count(4) \
			or roster.slots.size() != 4 or roster.can_start():
		_fail("set_slot_count should take 2-4 only: %s" % roster.pack())
		return false
	if not roster.set_slot_kind(2, npc) or roster.assign_peer(88, "Bob") != 3 or roster.human_slots() != 3 \
			or not roster.can_start():
		_fail("an NPC slot should be skipped by assign_peer: %s" % roster.pack())
		return false
	if roster.set_slot_count(3) or roster.set_slot_kind(3, npc) or roster.set_slot_kind(0, npc) \
			or roster.set_slot_kind(2, human) or roster.slots.size() != 4:
		_fail("a human's slot must not be removed or retyped: %s" % roster.pack())
		return false
	# Free-for-all: every slot its own side, spawn order is slot order.
	if roster.side_of(3) != 3 or roster.spawn_order() != [0, 1, 2, 3]:
		_fail("free-for-all sides / spawn order: %s" % [roster.spawn_order()])
		return false
	# Body colour: the slot's own in free-for-all, its side's in Teams.
	roster.set_side(3, 0)
	var ffa_tint := roster.tint_of(3)
	roster.mode = LobbyRoster.Mode.TEAMS
	if ffa_tint != LobbyRoster.SLOT_TINTS[3] or roster.tint_of(3) != LobbyRoster.SIDE_TINTS[0] \
			or roster.tint_of(1) != LobbyRoster.SIDE_TINTS[1]:
		_fail("roster tint_of should be per slot in free-for-all and per side in Teams")
		return false
	# Wire round trip, with every field off its default.
	roster.mode = LobbyRoster.Mode.TEAMS
	roster.scenario_index = 2
	roster.set_archetype(2, 1)
	roster.slots[3]["wins"] = 5
	for slot in 4:
		roster.set_side(slot, [1, 1, 0, 1][slot])
	var copy := LobbyRoster.new()
	if not copy.unpack(roster.pack()) or copy.pack() != roster.pack() or copy.slots[1]["name"] != "Ann" \
			or copy.slots[3]["wins"] != 5 or copy.slots[2]["archetype"] != 1 or copy.scenario_index != 2:
		_fail("roster pack / unpack round trip: %s -> %s" % [roster.pack(), copy.pack()])
		return false
	var before := copy.pack()
	var too_many := roster.pack()
	too_many["slots"] = (too_many["slots"] as Array) + [[0, 0, "", 0, -1, 0]]
	if copy.unpack({}) or copy.unpack({"slots": [[1, 1, "x", 0, -1, 0]]}) or copy.unpack(too_many) \
			or copy.unpack({"slots": [[1, 1], [0, 0]]}) or copy.pack() != before:
		_fail("unpack should refuse a malformed roster and change nothing")
		return false
	# Teams: 1v3 puts the solo on the first point, 2v2 keeps side 0 first and teammates adjacent.
	if roster.side_of(2) != 0 or roster.side_of(0) != 1 or roster.spawn_order() != [2, 0, 1, 3]:
		_fail("1v3 spawn order should start with the solo: %s" % [roster.spawn_order()])
		return false
	for slot in 4:
		roster.set_side(slot, [1, 0, 1, 0][slot])
	if roster.spawn_order() != [1, 3, 0, 2]:
		_fail("2v2 spawn order should keep side 0 first: %s" % [roster.spawn_order()])
		return false
	for slot in 4:
		roster.set_side(slot, 1)
	if roster.can_start() or roster.set_side(0, 2) or roster.set_side(4, 0):
		_fail("Teams with an empty side must not start")
		return false
	roster.set_side(2, 0)
	if not roster.can_start():
		_fail("Teams with both sides filled should start")
		return false
	# Leaver rule: waiting room reopens the slot, mid-duel leaves a Mixed NPC.
	if roster.vacate_peer(77, false) != 1 or roster.slots[1]["kind"] != open or roster.slots[1]["peer_id"] != 0 \
			or roster.can_start():
		_fail("a waiting-room leaver should reopen the slot: %s" % roster.pack())
		return false
	if roster.vacate_peer(88, true) != 3 or roster.slots[3]["kind"] != npc or roster.slots[3]["wins"] != 0 \
			or roster.slots[3]["archetype"] != LobbyRoster.ARCHETYPE_MIXED:
		_fail("a mid-duel leaver should leave a Mixed NPC: %s" % roster.pack())
		return false
	if roster.vacate_peer(1, true) != -1 or roster.vacate_peer(99, false) != -1 or roster.slots[0]["kind"] != human:
		_fail("the host's slot must never be vacated")
		return false
	if LobbyRoster.format_slots(1, 2) != "1/2" or LobbyRoster.parse_slots("3/4") != Vector2i(3, 4) \
			or LobbyRoster.parse_slots("0.9.1") != Vector2i.ZERO or LobbyRoster.parse_slots("a/b") != Vector2i.ZERO \
			or LobbyRoster.parse_slots("-1/2") != Vector2i.ZERO or LobbyRoster.parse_slots("1/2/3") != Vector2i.ZERO:
		_fail("open/total slot field format / parse")
		return false
	print("AUTOTEST: lobby roster ok (assign, refuse, pack, can_start, spawn order, leaver)")
	return true


func _binds_ok() -> bool:
	PlayerSettings.reset_binds()
	if PlayerSettings.get_vr_bind(&"cock") != "stick_down":
		_fail("default VR cock should be stick_down")
		return false
	if PlayerSettings.get_vr_bind(&"trick_shot") != "ax_button":
		_fail("default VR trick_shot should be ax_button")
		return false
	PlayerSettings.set_vr_bind(&"cock", "ax_button")
	if PlayerSettings.get_vr_bind(&"cock") != "ax_button":
		_fail("VR cock rebind failed")
		return false
	if PlayerSettings.get_vr_bind(&"trick_shot") != "stick_down":
		_fail("VR bind conflict should swap")
		return false
	PlayerSettings.reset_binds()
	if PlayerSettings.get_vr_bind(&"cock") != "stick_down":
		_fail("reset_binds did not restore VR defaults")
		return false
	if PlayerSettings.get_vr_bind(&"prop_radial") != "primary_click":
		_fail("default VR prop_radial should be primary_click")
		return false
	if PlayerSettings.get_vr_bind(&"pause") != "primary_click":
		_fail("default VR pause should share stick click")
		return false
	PlayerSettings.set_vr_bind(&"pause", "ax_button")
	if PlayerSettings.get_vr_bind(&"pause") != "ax_button":
		_fail("VR pause rebind failed")
		return false
	if PlayerSettings.get_vr_bind(&"trick_shot") != "primary_click":
		_fail("pause rebind should move trick shot onto stick click")
		return false
	if PlayerSettings.get_vr_bind(&"prop_radial") != "primary_click":
		_fail("prop radial should stay on stick click when pause leaves it")
		return false
	PlayerSettings.reset_binds()
	if PlayerSettings.flat_event_label(PlayerSettings.get_flat_bind_event(&"cock_hammer")) != "Space":
		_fail("default flat cock should be Space")
		return false
	if PlayerSettings.flat_event_label(PlayerSettings.get_flat_bind_event(&"prop_radial")) != "Tab":
		_fail("default flat prop_radial should be Tab")
		return false
	if PlayerSettings.flat_event_label(PlayerSettings.get_flat_bind_event(&"prop_fire")) != "G":
		_fail("default flat prop_fire should be G")
		return false
	var key_f := InputEventKey.new()
	key_f.physical_keycode = KEY_F
	PlayerSettings.set_flat_bind(&"cock_hammer", key_f)
	var found := false
	for ev in InputMap.action_get_events("cock_hammer"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_F:
			found = true
			break
	if not found:
		_fail("flat cock InputMap not updated")
		return false
	PlayerSettings.reset_binds()
	var player := GameManager.local_player
	if player != null:
		var saved_side := int(GameManager.tuning["holster_side"])
		GameManager.tuning["holster_side"] = 0
		if player.dominant_hand_name() != &"right_hand" or player.draw_hand_name() != &"right_hand":
			GameManager.tuning["holster_side"] = saved_side
			_fail("right holster should draw with the right hand")
			return false
		GameManager.tuning["holster_side"] = 1
		if player.dominant_hand_name() != &"left_hand" or player.off_hand_name() != &"right_hand":
			GameManager.tuning["holster_side"] = saved_side
			_fail("left holster should draw with the left hand")
			return false
		GameManager.tuning["holster_side"] = saved_side
	print("AUTOTEST: bind table swap/reset ok")
	return true


## SteamTransport must parse without GodotSteam. CI has no addon, so
## is_available() is false and host/join stay ERR_UNAVAILABLE.
func _test_steam() -> void:
	await _sleep(0.2)
	if not _steam_transport_ok():
		return
	_pass()


## BUG-009: create → leave → create and join-failure recovery against a real
## Steam client. Every step has to work in one process; before the fix the
## second HOST silently never produced a lobby. No-op without Steam (CI).
func _test_steam_cycle() -> void:
	await _sleep(0.5)
	if not NetworkManager.steam_available():
		print("AUTOTEST: Steam unavailable, nothing to cycle")
		return _pass()

	var first := await _steam_host_lobby("first HOST")
	if first == 0:
		return
	if not _steam_left_cleanly(first):
		return

	var second := await _steam_host_lobby("HOST after leave")
	if second == 0:
		return
	if second == first:
		return _fail("HOST after leave reused lobby %d" % first)
	if not _steam_left_cleanly(second):
		return

	# Abandon a create before it is even sent, and again while Steam is still
	# answering it. The orphan lobby has to be dropped instead of leaving the
	# process stuck "already in a lobby".
	for wait in [0.0, 0.25]:
		NetworkManager.host_steam()
		if wait > 0.0:
			await _sleep(wait)
		else:
			await get_tree().process_frame
		NetworkManager.leave("autotest")
		var third := await _steam_host_lobby("HOST after a create abandoned at %.2fs" % wait)
		if third == 0:
			return
		if not _steam_left_cleanly(third):
			return

	# A join that cannot resolve must report an error and still leave HOST usable.
	var errors: Array = []
	var on_error := func(message: String) -> void: errors.append(message)
	NetworkManager.network_error.connect(on_error)
	NetworkManager.join_steam(1)
	await _wait_for(func() -> bool: return not errors.is_empty(), 20.0)
	NetworkManager.network_error.disconnect(on_error)
	if errors.is_empty():
		return _fail("join_steam() on a dead lobby never reported an error")
	print("AUTOTEST: dead join reported '%s'" % errors[0])
	if NetworkManager.steam_lobby_id() != 0:
		return _fail("failed join left lobby %d behind" % NetworkManager.steam_lobby_id())

	var fourth := await _steam_host_lobby("HOST after a failed join")
	if fourth == 0:
		return
	if not _steam_left_cleanly(fourth):
		return
	_pass()


func _steam_host_lobby(label: String) -> int:
	if NetworkManager.host_steam() != OK:
		_fail("%s: host_steam() refused" % label)
		return 0
	if not await _wait_for(func() -> bool: return NetworkManager.steam_lobby_id() != 0, 20.0):
		_fail("%s: Steam never produced a lobby" % label)
		return 0
	var id := NetworkManager.steam_lobby_id()
	print("AUTOTEST: %s -> lobby %d" % [label, id])
	return id


func _steam_left_cleanly(id: int) -> bool:
	NetworkManager.leave("autotest")
	if NetworkManager.steam_lobby_id() != 0:
		_fail("leave() did not release Steam lobby %d" % id)
		return false
	if NetworkManager.transport != null or NetworkManager.is_active():
		_fail("leave() left the session active")
		return false
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		_fail("leave() did not reset the multiplayer peer to offline")
		return false
	return true


func _steam_transport_ok() -> bool:
	var steam := SteamTransport.new(multiplayer)
	if steam.kind() != "steam":
		_fail("SteamTransport.kind() was '%s'" % steam.kind())
		return false
	# BUG-009: close() must be idempotent and leave no lobby or peer behind, or
	# the next create / join in the same process inherits dead Steam state.
	steam.close()
	steam.close()
	if steam.lobby_id != 0 or steam.is_lobby_host or steam.peer_connected():
		_fail("SteamTransport.close() left lobby or peer state behind")
		return false
	if SteamTransport.is_available():
		print("AUTOTEST: GodotSteam present; SteamTransport.is_available() true")
		return true
	print("AUTOTEST: SteamTransport loads; is_available() false (no addon)")
	if steam.host() != ERR_UNAVAILABLE:
		_fail("SteamTransport.host() should be ERR_UNAVAILABLE without Steam")
		return false
	if steam.join(0) != ERR_UNAVAILABLE:
		_fail("SteamTransport.join() should be ERR_UNAVAILABLE without Steam")
		return false
	if NetworkManager.steam_available():
		_fail("NetworkManager.steam_available() true without GodotSteam")
		return false
	return true


# -- Helpers ---------------------------------------------------------------------

func _wait_for_state(state: int, timeout: float) -> bool:
	return await _wait_for(func() -> bool: return GameManager.duel.state == state, timeout)


func _wait_for(predicate: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


func _wait_freed(ref: WeakRef, timeout: float) -> bool:
	return await _wait_for(func() -> bool: return ref.get_ref() == null, timeout)


## Returns a shared array that fills with [won, reason] on duel_finished.
func _arm_duel_listener() -> Array:
	var result: Array = []
	GameManager.duel.duel_finished.connect(
		func(won: bool, reason: String) -> void: result.append_array([won, reason]),
		CONNECT_ONE_SHOT)
	return result


func _await_result(result: Array, timeout: float) -> bool:
	return await _wait_for(func() -> bool: return not result.is_empty(), timeout)


func _wait_duel_finished(timeout: float) -> Array:
	var result := _arm_duel_listener()
	await _await_result(result, timeout)
	return result


## Lowest world Y of a rigid body's `BodyCollision` box corners.
func _body_bottom_y(body: Node3D) -> float:
	var shape_node := body.get_node("BodyCollision") as CollisionShape3D
	var box := shape_node.shape as BoxShape3D
	var xf := shape_node.global_transform
	var h := box.size * 0.5
	var min_y := INF
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				min_y = minf(min_y, (xf * Vector3(h.x * sx, h.y * sy, h.z * sz)).y)
	return min_y


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _fail(message: String) -> void:
	print("AUTOTEST FAIL: %s" % message)
	_apply_lobby_snapshot(_saved_lobby_setup)
	get_tree().quit(1)


func _pass() -> void:
	_apply_lobby_snapshot(_saved_lobby_setup)
	print("AUTOTEST PASS")
	get_tree().quit(0)


# -- Translations ---------------------------------------------------------------

const I18N_CSV := "res://translations/translations.csv"
const I18N_SKIP_DIRS := ["addons", "android", "dev", "docs", "assets", "translations"]
const I18N_PREFIXES := ["UI_", "LOADING_", "MENU_", "PAUSE_", "SETTINGS_", "BIND_", "HUD_", "RADIAL_",
		"RELOAD_", "MSG_", "NET_", "BOARD_", "SLOT_", "LOBBY_"]


## Keys used in code (tr("KEY") literals, prefixed key constants, scene text keys)
## must exist in translations.csv, and the imported translation must resolve them.
func _test_i18n() -> void:
	var error := _i18n_error()
	if not error.is_empty():
		return _fail("i18n: " + error)
	_pass()


func _i18n_error() -> String:
	var csv := FileAccess.open(I18N_CSV, FileAccess.READ)
	if csv == null:
		return "missing " + I18N_CSV
	var known := {}
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		if row[1].is_empty():
			return "empty English text for " + row[0]
		known[row[0]] = row[1]
	var prefixes := "|".join(I18N_PREFIXES)
	var tr_call := RegEx.create_from_string("\\btr\\(\"([A-Z][A-Z0-9_]+)\"\\)")
	var literal := RegEx.create_from_string("\"((?:" + prefixes + ")[A-Z0-9_]+)\"")
	var scene_text := RegEx.create_from_string(
			"(?m)^(?:text|placeholder_text|tooltip_text) = \"((?:" + prefixes + ")[A-Z0-9_]+)\"")
	var missing := PackedStringArray()
	var used := 0
	for path in _i18n_files("res://"):
		var source := FileAccess.get_file_as_string(path)
		var found: Array[RegExMatch] = []
		if path.ends_with(".gd"):
			found.append_array(tr_call.search_all(source))
			found.append_array(literal.search_all(source))
		else:
			found.append_array(scene_text.search_all(source))
		for hit in found:
			var key := hit.get_string(1)
			used += 1
			var label := "%s (%s)" % [key, path.get_file()]
			if not known.has(key) and not missing.has(label):
				missing.append(label)
	if not missing.is_empty():
		return "keys missing from translations.csv: " + ", ".join(missing)
	if used == 0:
		return "found no translation keys in code"
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var resolved := TranslationServer.translate("MENU_QUIT")
	TranslationServer.set_locale(previous)
	if resolved != known["MENU_QUIT"]:
		return "translation not registered in project.godot (MENU_QUIT -> %s)" % resolved
	print("AUTOTEST: i18n %d keys in CSV, %d key uses in code" % [known.size(), used])
	return ""


func _i18n_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		if sub.begins_with(".") or (dir_path == "res://" and sub in I18N_SKIP_DIRS):
			continue
		out.append_array(_i18n_files(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir_path.path_join(file))
	return out
