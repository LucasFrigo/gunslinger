extends Node
## Headless smoke tests, launched via `--autotest=<mode>` after `--`:
##   duel     - free duel vs AI; passes when bullets actually resolve the duel
##   props    - equips the cigarette / coin / ace / bottle and throws them
##   gauntlet - clears two gauntlet rungs by force-killing the AI;
##              first rung also checks the pain-jerk toss
##   host     - hosts a LAN game, waits for a peer, wins the MP duel
##   join     - joins 127.0.0.1, expects to lose the MP duel
##   steam    - SteamTransport parses; is_available() is false without GodotSteam
##   steamcycle - create/leave/create + join recovery against a live Steam
##              client (BUG-009); passes as a no-op when Steam is absent
##   load     - loads every scene/resource, then bind, prop, version,
##              main-menu SP/MP split, and host/leave/re-host (BUG-009) checks
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
	match mode:
		"duel":
			_test_duel()
		"gauntlet":
			_test_gauntlet()
		"host":
			_test_host()
		"join":
			_test_join()
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
	GameManager.start_free_duel(0, 0)
	if not await _wait_for_state(DuelManager.State.DRAW, 20.0):
		return _fail("duel never reached DRAW")
	print("AUTOTEST: DRAW reached, waiting for bullets to decide it...")
	var result := await _wait_duel_finished(60.0)
	if result.is_empty():
		return _fail("duel did not resolve (no bullet hit landed)")
	print("AUTOTEST: duel finished, local won=%s (%s)" % [result[0], result[1]])
	_pass()


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
			if not (_assert_pain_jerk() and _assert_spin_throw()):
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


## Arm hit flings a held gun and does not block an immediate catch. AI gun leaves the arm.
func _assert_pain_jerk() -> bool:
	var player := GameManager.local_player
	if player == null or player.revolver == null:
		_fail("pain-jerk: no local player")
		return false
	player._draw_gun()
	if not player.revolver.held:
		_fail("pain-jerk: gun was not in hand")
		return false
	player.apply_wound(CombatRules.REGION_ARM, player.health)
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
	ai.take_bullet_hit(0.0, PackedVector3Array(), CombatRules.REGION_ARM)
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
	if not _chunks_parse_ok(dummy) or not await _chunks_warmup_ok():
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
		if not hand.material_override is StandardMaterial3D:
			_fail("chunks: a hand wears %s, not the solid material" % hand.material_override)
			return false
	print("AUTOTEST: chunks: snap triangles (%s)" % ", ".join(line))
	return true


## 2. Boot warmup (skipped headless): a probe with both hole passes plus one frozen gib the
## cap does not count.
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
	# Probe first: the headless renderer logs a null material if the gib goes before it.
	await get_tree().process_frame
	if not probes.is_empty():
		(probes[0] as Node).free()
	warm.free()
	if warm_count != 2 or warm_gibs.size() != 1 or not warm_frozen or not passes or BodyGib.alive_count() != 0:
		_fail("chunks: warmup drew %d nodes, %d gibs (frozen %s), both passes %s, %d counted" % [warm_count,
				warm_gibs.size(), warm_frozen, passes, BodyGib.alive_count()])
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
	dummy.chunks_replay_at(t_hit - 0.1)
	if dummy.chunk_count() != 0 or gib.visible:
		_fail("chunks: the hole opened before its clip time")
		return false
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
	print("AUTOTEST: hosting, waiting for peer...")
	if not await _wait_for(func() -> bool: return NetworkManager.peer_count() > 0, 40.0):
		return _fail("no peer joined")
	print("AUTOTEST: peer joined")
	if not await _wait_for_state(DuelManager.State.DRAW, 30.0):
		return _fail("MP duel never reached DRAW (holster relay?)")
	var avatar := GameManager.remote_avatar
	if not await _assert_hitboxes_follow(avatar, avatar._dummy, "remote avatar"):
		return
	print("AUTOTEST: MP DRAW reached, host shoots the avatar")
	var result := _arm_duel_listener()
	var head := avatar._dummy.bone_global(&"Head").origin
	var shot := Vector3(0.0, 0.0, 1.0)
	var cut := avatar._dummy.cut_on_bone(avatar._dummy.bone_index(&"Head"), head, shot, CombatRules.REGION_HEAD)
	if cut.is_empty():
		return _fail("host: no head cut to send")
	avatar.take_bullet_hit(99.0, PackedVector3Array([head - shot, head]), CombatRules.REGION_HEAD, false, false, -1, cut)
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true:
		return _fail("host did not win the MP duel")
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
	var result := await _wait_duel_finished(60.0)
	if result.is_empty():
		return _fail("client never saw the duel resolve")
	if result[0] != false:
		return _fail("client unexpectedly won")
	print("AUTOTEST: client correctly lost the duel (%s)" % result[1])
	var local := GameManager.local_player
	if not local.corpse_body().has_corpse() or local.revolver.held:
		return _fail("client: the shot player did not collapse and drop the gun")
	print("AUTOTEST: client body collapsed")
	if PlayerSettings.gore_enabled and (not _has_head_cut(local.corpse_body()) or local.corpse_body().chunk_count() != 1):
		return _fail("client: the shot player has no hole on the head (%d holes)" % local.corpse_body().chunk_count())
	print("AUTOTEST: client head holed")
	_pass()


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
	if not _steam_transport_ok():
		return
	if not _binds_ok():
		return
	if not await _props_ok():
		return
	if not _version_check_ok():
		return
	if not await _voice_ok():
		return
	if not _leave_rejoin_ok():
		return
	if not _time_of_day_ok():
		return
	if not ImpactFeedback.has_warmed_up():
		return _fail("boot warmup did not run")
	if Bullet.ensure_mesh() == null or AudioCatalog.get_stream(&"gunshot") == null:
		return _fail("warmup missed slug mesh or gunshot")
	_pass()


## Outdoor times recolor the sky but keep the fog distances and shadow fade
## that hide the canyon plain and the train belt. Saloon has no sun.
func _time_of_day_ok() -> bool:
	var outdoor := [
		"res://scenarios/main_street/main_street.tscn",
		"res://scenarios/train_rooftop/train_rooftop.tscn",
		"res://scenarios/canyon/canyon.tscn",
	]
	for path in outdoor:
		if not _outdoor_time_ok(path):
			return false
	if not _saloon_time_ok():
		return false
	print("AUTOTEST: time of day keeps the horizon contract")
	return true


func _outdoor_time_ok(path: String) -> bool:
	var instance := (load(path) as PackedScene).instantiate() as ScenarioBase
	add_child(instance)
	var snap := _horizon_snapshot(instance)
	for t in [0.0, 0.5, 1.0]:
		instance.apply_time(t)
		if not _horizon_unchanged(instance, snap, path):
			instance.queue_free()
			return false
		var world := instance.get_node("WorldEnvironment") as WorldEnvironment
		var mat := world.environment.sky.sky_material as ProceduralSkyMaterial
		if not world.environment.fog_light_color.is_equal_approx(mat.ground_horizon_color):
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
		if t == 0.0 or t == 1.0:
			var elev := rad_to_deg(asin(clampf(sun.global_transform.basis.z.y, -1.0, 1.0)))
			var expect: float = TimeOfDay.DUSK_ELEVATION_DEG
			if is_equal_approx(t, 0.0):
				expect = TimeOfDay.DAWN_ELEVATION_DEG
			if absf(elev - expect) > 1.0:
				instance.queue_free()
				_fail("%s sun elevation %.1f, expected %.1f" % [path, elev, expect])
				return false
	instance.queue_free()
	return true


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
			and is_equal_approx(env.ambient_light_energy, ambient)
	instance.queue_free()
	if not unchanged:
		_fail("saloon lighting changed with time of day")
		return false
	return true


func _horizon_snapshot(root: Node) -> Dictionary:
	var env := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	var mat := env.sky.sky_material as ProceduralSkyMaterial
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
		"sky_curve": mat.sky_curve,
		"ground_curve": mat.ground_curve,
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
	var avatar: RemoteAvatar = (load("res://player/remote_avatar.tscn") as PackedScene).instantiate()
	add_child(avatar)
	await get_tree().process_frame
	if avatar.voice_player == null or avatar.mute_icon == null:
		avatar.queue_free()
		_fail("remote avatar is missing VoicePlayer / MuteX under the mouth")
		return false
	if avatar.voice_player.bus != &"Voice":
		avatar.queue_free()
		_fail("avatar voice player is on bus %s, expected Voice" % avatar.voice_player.bus)
		return false
	avatar.apply_pose(Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY,
			NetworkManager.POSE_FLAG_VOICE_MUTED)
	if not avatar.mute_icon.visible:
		avatar.queue_free()
		_fail("POSE_FLAG_VOICE_MUTED did not raise the mouth X")
		return false
	avatar.apply_pose(Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, 0)
	if avatar.mute_icon.visible:
		avatar.queue_free()
		_fail("clearing the mute flag did not hide the mouth X")
		return false
	avatar.queue_free()
	print("AUTOTEST: voice buses, mute X, and availability gate ok")
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
## has to put NetworkManager back where host / join work again.
func _leave_rejoin_ok() -> bool:
	for attempt in 2:
		if NetworkManager.host_lan() != OK:
			_fail("host_lan() failed on attempt %d (leave did not release the transport)" % (attempt + 1))
			return false
		if not NetworkManager.is_active():
			_fail("session not active after host_lan()")
			return false
		NetworkManager.leave("autotest")
		if NetworkManager.is_active() or NetworkManager.transport != null:
			_fail("leave() left the session active")
			return false
		if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			_fail("leave() did not reset the multiplayer peer to offline")
			return false
	print("AUTOTEST: host -> leave -> host again ok, peer reset to offline")
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
	print("AUTOTEST: MP version helpers + LAN pong parse ok")
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
	get_tree().quit(1)


func _pass() -> void:
	print("AUTOTEST PASS")
	get_tree().quit(0)


# -- Translations ---------------------------------------------------------------

const I18N_CSV := "res://translations/translations.csv"
const I18N_SKIP_DIRS := ["addons", "android", "dev", "docs", "assets", "translations"]
const I18N_PREFIXES := ["UI_", "LOADING_", "MENU_", "PAUSE_", "SETTINGS_", "BIND_", "HUD_", "RADIAL_",
		"RELOAD_", "MSG_", "NET_", "BOARD_", "SLOT_"]


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
