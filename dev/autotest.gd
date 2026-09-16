extends Node
## Headless smoke tests, launched via `--autotest=<mode>` after `--`:
##   duel     - free duel vs AI; passes when bullets actually resolve the duel
##   props    - equips the cigarette from the radial and throws/catches it
##   gauntlet - clears two gauntlet rungs by force-killing the AI
##   host     - hosts a LAN game, waits for a peer, wins the MP duel
##   join     - joins 127.0.0.1, expects to lose the MP duel
##   steam    - SteamTransport parses; is_available() is false without GodotSteam
##   steamcycle - create/leave/create + join recovery against a live Steam
##              client (BUG-009); passes as a no-op when Steam is absent
##   load     - loads every scene/resource, then bind, prop, version, and
##              host/leave/re-host (BUG-009) checks
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

	props.equip_item(PropController.ITEM_NONE)
	if props.has_prop():
		return _fail("empty-hand wedge did not clear the prop")
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
	if not _steam_transport_ok():
		return
	if not _binds_ok():
		return
	if not await _props_ok():
		return
	if not _version_check_ok():
		return
	if not _leave_rejoin_ok():
		return
	_pass()


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


## Radial wedge picking plus the cigarette's hold → throw → catch cycle.
func _props_ok() -> bool:
	var count := PropController.ITEMS.size()
	if PropController.highlight_index(Vector2.ZERO, count) != -1:
		_fail("centered stick should cancel, not highlight")
		return false
	if PropController.highlight_index(Vector2(0.0, 1.0), count) != 0:
		_fail("up should highlight the first wedge")
		return false
	if PropController.highlight_index(Vector2(0.0, -1.0), count) != count / 2:
		_fail("down should highlight the opposite wedge")
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
	cig.queue_free()
	attach.queue_free()
	print("AUTOTEST: prop radial picking + cigarette boomerang ok")
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
