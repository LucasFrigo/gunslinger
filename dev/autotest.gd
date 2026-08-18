extends Node
## Headless smoke tests, launched via `--autotest=<mode>` after `--`:
##   duel     - free duel vs AI; passes when bullets actually resolve the duel
##   gauntlet - clears two gauntlet rungs by force-killing the AI
##   host     - hosts a LAN game, waits for a peer, wins the MP duel
##   join     - joins 127.0.0.1, expects to lose the MP duel
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
		# Arm the listener before the kill: duel_finished fires synchronously.
		var result := _arm_duel_listener()
		GameManager.current_ai.take_bullet_hit(99.0, PackedVector3Array())
		await _await_result(result, 10.0)
		if result.is_empty() or result[0] != true:
			return _fail("gauntlet rung %d did not resolve as a win" % (rung + 1))
		print("AUTOTEST: gauntlet rung %d cleared, score=%d" % [rung + 1, GameManager.gauntlet.score])
	if GameManager.gauntlet.encounter_index < 1:
		return _fail("gauntlet did not advance")
	_pass()


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
	print("AUTOTEST: MP DRAW reached, host shoots the avatar")
	var result := _arm_duel_listener()
	GameManager.remote_avatar.take_bullet_hit(99.0, PackedVector3Array(), &"head")
	await _await_result(result, 10.0)
	if result.is_empty() or result[0] != true:
		return _fail("host did not win the MP duel")
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
	_pass()


## Instantiate every scene and load every resource the flat tests don't cover.
func _test_load_all() -> void:
	await _sleep(0.5)
	var scenes := [
		"res://player/vr_rig.tscn",
		"res://player/remote_avatar.tscn",
		"res://ai/duelist.tscn",
		"res://weapons/revolver/revolver.tscn",
		"res://scenarios/main_street/main_street.tscn",
		"res://scenarios/saloon/saloon.tscn",
		"res://scenarios/train_rooftop/train_rooftop.tscn",
		"res://scenarios/canyon/canyon.tscn",
	]
	for path in scenes:
		var instance: Node = (load(path) as PackedScene).instantiate()
		add_child(instance)
		await get_tree().process_frame
		instance.queue_free()
		print("AUTOTEST: loaded %s" % path)
	var resources: Array = []
	resources.append_array(GameManager.SCENARIOS)
	resources.append_array(GameManager.ARCHETYPES)
	resources.append(GameManager.GAUNTLET_LADDER)
	for path in resources:
		if load(path) == null:
			return _fail("resource failed to load: %s" % path)
		print("AUTOTEST: loaded %s" % path)
	var ladder: GauntletLadder = load(GameManager.GAUNTLET_LADDER)
	if ladder.encounters.size() != 6:
		return _fail("ladder has %d encounters, expected 6" % ladder.encounters.size())
	_pass()


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


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _fail(message: String) -> void:
	print("AUTOTEST FAIL: %s" % message)
	get_tree().quit(1)


func _pass() -> void:
	print("AUTOTEST PASS")
	get_tree().quit(0)
