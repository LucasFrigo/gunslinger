extends Node
## Headless smoke tests, launched via `--autotest=<mode>` after `--`:
##   duel     - free duel vs AI; passes when bullets actually resolve the duel
##   props    - equips the cigarette from the radial and throws/catches it
##   gauntlet - clears two gauntlet rungs by force-killing the AI;
##              first rung also checks the pain-jerk toss
##   host     - hosts a LAN game, waits for a peer, wins the MP duel
##   join     - joins 127.0.0.1, expects to lose the MP duel
##   steam    - SteamTransport parses; is_available() is false without GodotSteam
##   steamcycle - create/leave/create + join recovery against a live Steam
##              client (BUG-009); passes as a no-op when Steam is absent
##   load     - loads every scene/resource, then bind, prop, version,
##              main-menu SP/MP split, and host/leave/re-host (BUG-009) checks
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
		if rung == 0 and not _assert_pain_jerk():
			return
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
	var ai := GameManager.current_ai
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
	for path in resources:
		if load(path) == null:
			return _fail("resource failed to load: %s" % path)
		print("AUTOTEST: loaded %s" % path)
	var ladder: GauntletLadder = load(GameManager.GAUNTLET_LADDER)
	if ladder.encounters.size() != 6:
		return _fail("ladder has %d encounters, expected 6" % ladder.encounters.size())
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
