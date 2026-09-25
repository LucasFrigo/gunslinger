extends Node
## Autoload. Central coordinator: game modes, scenario loading, player and
## enemy spawning, HUD messages, and gameplay tuning values. The duel state
## machine and gauntlet controller live as children so their node paths are
## stable for RPCs.

signal mode_changed(mode: int)
signal tuning_changed(key: String, value: Variant)

enum GameMode { BOOT, MENU, FREE_DUEL, GAUNTLET, MULTIPLAYER, PRACTICE }

const TUNING_PATH := "user://tuning.cfg"

## Scenario registry -- add new scenarios here and they appear in every menu.
const SCENARIOS: Array[String] = [
	"res://scenarios/main_street/main_street.tres",
	"res://scenarios/saloon/saloon.tres",
	"res://scenarios/train_rooftop/train_rooftop.tres",
	"res://scenarios/canyon/canyon.tres",
]

## Local warmup lot. Deliberately not in SCENARIOS, so no menu offers it as a duel.
const PRACTICE_HUB := "res://scenarios/practice_hub/practice_hub.tres"

const ARCHETYPES: Array[String] = [
	"res://ai/archetypes/drunk.tres",
	"res://ai/archetypes/sheriff.tres",
	"res://ai/archetypes/ghost.tres",
]

const PLAYER_SCENE := "res://player/player.tscn"
const AI_SCENE := "res://ai/duelist.tscn"
const AVATAR_SCENE := "res://player/remote_avatar.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
const GAUNTLET_LADDER := "res://gauntlet/ladder_default.tres"

## Live gameplay tuning, editable from the debug menu, persisted to disk.
var tuning := {
	"bullet_speed": 55.0,    # m/s
	"auto_cock": true,       # double-action revolver (no manual hammer)
	"ai_speed_mult": 1.0,    # global multiplier on AI reaction/draw/reload speed
	## VR reload: gun-hand speed (m/s) that must be sustained to dump shells.
	"reload_dump_speed": 4.5,
	## Seconds the dump speed must be held before shells eject.
	"reload_dump_hold": 0.25,
	## VR reload: gun-hand flick speed (m/s) that closes the gate.
	"reload_swing_close": 6.0,
	## VR reload: off-hand bump speed (m/s) near chamber that closes the gate.
	"reload_bump_close": 2.8,
	## 0 = right hip, 1 = left hip. Draw/holster snap use this side.
	"holster_side": 0,
	## VR catch: hand-to-gun distance (m) to grab a tossed or held gun.
	"gun_catch_radius": 0.22,
	## VR holster: gun-hand speed (m/s) below which a hip release snaps holster.
	"gun_holster_max_speed": 1.2,
	## Multiplier on controller linear velocity when tossing.
	"gun_throw_scale": 1.0,
	## Multiplier on controller angular velocity when tossing.
	"gun_throw_spin_scale": 1.0,
	## Starting HP so one torso/limb hit is not fatal (head is always lethal).
	"player_health": 2.0,
	## Seconds before a disarmed AI snatches its revolver back. Players have no redraw lock.
	"arm_disarm_duration": 1.5,
	## Pain-jerk: upward speed (m/s) when an arm hit flings the revolver.
	"gun_pain_toss_up": 4.0,
	## Pain-jerk: tumble (rad/s) around the gun's local X.
	"gun_pain_toss_spin": 8.0,
	## Flat pickup: look-ray length (m) that can grab a loose revolver.
	"gun_flat_grab_range": 3.0,
	## Flat pickup: gun origin within this distance (m) of the look ray still counts.
	"gun_flat_grab_radius": 0.28,
	## Seconds a leg hit slows locomotion.
	"leg_slow_duration": 2.5,
	## Move-speed multiplier while limping (1 = no penalty).
	"leg_speed_mult": 0.45,
	## Flat jam: shots slower than this add no heat (seconds).
	"jam_safe_interval": 0.35,
	"jam_heat_per_shot": 0.45,
	## Heat lost per second of pause beyond jam_safe_interval.
	"jam_heat_decay": 1.2,
	"jam_heat_threshold": 0.5,
	"jam_chance_scale": 1.2,
	"jam_max_chance": 0.85,
	## Seconds looking down + holding Space to clear a jam.
	"jam_clear_hold": 1.5,
	## Look-down pitch (radians) required to clear; Flat camera x is negative down.
	"jam_clear_pitch": 0.55,
	## VR Ocelot: |stick Y| to unlock (down) / relock (up) the gun-hand stick.
	"spin_stick_threshold": 0.55,
	## Hinge damping (1/s). Higher = spin dies faster. 0 = coasts forever.
	"spin_damping": 0.0,
	## Gravity torque scale on the hanging barrel (0 = inertial only).
	"spin_gravity": 2.0,
	## Moment of inertia for whip / gravity (kg·m²-ish). Lower = snappier.
	"spin_inertia": 0.03,
	## How quickly a fast wrist flick transfers into residual spin.
	"spin_coupling": 8.0,
	## Seconds to tween back to the locked pose after stick-up.
	"spin_relock_time": 0.12,
	## Cigarette boomerang: flight speed (m/s), same outbound and homing.
	"cig_speed": 9.0,
	## Range of a tap (m): zero charge still throws this far.
	"cig_min_range": 1.2,
	## Range at full charge (m).
	"cig_max_range": 6.0,
	## Seconds of holding the throw button to charge from min to max range.
	"cig_charge_time": 1.0,
	## Total seconds out and back, so a tap and a full throw take the same time:
	## a short throw hangs spinning at the far end to make up the difference. A
	## throw too long to fit in this window just takes as long as it takes.
	"cig_flight_time": 1.5,
	## Hand-to-cig distance (m) that counts as a catch.
	"cig_catch_radius": 0.28,
	## Outbound bend (rad/s) around world up. 0 is a straight line; raise it for
	## a boomerang arc, negative bends the other way.
	"cig_curve": 0.0,
	## Flick spin (rad/s) snapped on at launch; it never damps before the catch.
	"cig_spin": 38.0,
	## 1 = sweep around the middle like a thrown baton (the default: the mesh is
	## near enough rotationally symmetric that it is the only spin that reads).
	## 0 = roll around the paper tube.
	"cig_spin_axis": 1,
	## Coin toss: forward speed (m/s) of a tap. Hold length does not change it.
	"coin_speed": 4.0,
	## Extra upward kick (m/s) so the toss arcs instead of flying flat.
	"coin_up": 3.5,
	## Diameter spin (rad/s) so both faces flip in flight.
	"coin_spin": 18.0,
	## Palm-up dot vs world up. Below this the coin slides off.
	"coin_palm_dot": 0.75,
	## Hand speed (m/s) that still counts as steady enough to rest / catch.
	"coin_hand_speed": 0.8,
	## Disc above the palm (m) that reseats a flying coin.
	"coin_catch_radius": 0.2,
	## Gravity (m/s²) on a tossed coin or a falling ace.
	"coin_gravity": 9.8,
	## Proximity voice: metres past which the peer is inaudible. The duel lane is
	## 16 m, so the default keeps a standoff conversation clear and fades anyone
	## who wanders off.
	"voice_max_distance": 26.0,
	## Distance (m) at which voice plays at full volume before it falls off.
	"voice_unit_size": 6.0,
	## Metres from muzzle before a shot can hit the shooter's gun-hand arm.
	## Torso / head / off-hand / legs are not covered — a muzzle into the body
	## still counts. Arm capsules also inset from the wrist so a normal forward
	## shot clears the forearm.
	"self_hit_grace": 0.28,
}

var mode: int = GameMode.BOOT
var is_vr := false
var world_root: Node3D
var main_root: Node3D
var local_player: Player
var remote_avatar: RemoteAvatar
var current_scenario: ScenarioBase
var current_scenario_index := 0
var current_archetype_index := 0
var current_ai: DuelistAI
var hud: Hud

var duel: DuelManager
var gauntlet: GauntletController
var _action_generation := 0


func _ready() -> void:
	duel = DuelManager.new()
	duel.name = "DuelManager"
	add_child(duel)
	gauntlet = GauntletController.new()
	gauntlet.name = "GauntletController"
	add_child(gauntlet)
	_load_tuning()

	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.pose_received.connect(_on_pose_received)
	NetworkManager.shot_received.connect(_on_shot_received)
	duel.duel_finished.connect(_on_duel_finished)


## Called once by main.tscn after XR init. Await: the loading screen compiles
## combat AV, then the main menu opens.
func setup(main: Node3D, use_vr: bool) -> void:
	main_root = main
	world_root = main.get_node("WorldRoot")
	is_vr = use_vr
	PlayerSettings.apply_window()

	hud = load(HUD_SCENE).instantiate()
	main.add_child(hud)

	local_player = load(PLAYER_SCENE).instantiate()
	local_player.use_vr = use_vr
	main.add_child(local_player)

	DebugMenu.setup(use_vr)
	await _run_boot_loading()
	go_to_menu()


func _run_boot_loading() -> void:
	var headless := OS.has_feature("headless")
	if not headless and is_instance_valid(hud):
		hud.show_loading()
	if not headless and is_vr and is_instance_valid(local_player):
		local_player.show_boot_loading()
	if not ImpactFeedback.warmup_progress.is_connected(_on_warmup_progress):
		ImpactFeedback.warmup_progress.connect(_on_warmup_progress)
	await ImpactFeedback.warmup()
	if ImpactFeedback.warmup_progress.is_connected(_on_warmup_progress):
		ImpactFeedback.warmup_progress.disconnect(_on_warmup_progress)
	if is_vr and is_instance_valid(local_player):
		local_player.hide_boot_loading()
	if is_instance_valid(hud):
		hud.hide_loading()


func _on_warmup_progress(amount: float, status: String) -> void:
	if is_instance_valid(hud):
		hud.set_loading_progress(amount, status)
	if is_vr and is_instance_valid(local_player):
		local_player.set_boot_loading_text(status)


# -- Mode transitions ---------------------------------------------------------

func is_pause_open() -> bool:
	return is_instance_valid(hud) and hud.is_pause_open()


## Flat: a random duel arena, frozen, behind the fullscreen menu. VR: the
## practice hub, live, with the menu floating in front of the player.
func go_to_menu() -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	KillCam.cancel()
	NetworkManager.leave()
	duel.stop()
	gauntlet.stop()
	TimeManager.reset()
	_clear_combatants()
	_set_mode(GameMode.MENU)
	if is_vr:
		_instance_scenario(load(PRACTICE_HUB))
	else:
		_instance_scenario(load(SCENARIOS[randi() % SCENARIOS.size()]))
		current_scenario.process_mode = Node.PROCESS_MODE_DISABLED
	_place_local_player(current_scenario.get_player_spawn())
	hud.show_menu(is_vr)
	if is_vr:
		_spawn_vr_menu_panel()


## Tutorial / Practice. VR is already standing in the hub, so this only drops
## the menu and keeps the range as it is.
func start_practice() -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	var already_there := in_practice()
	_set_mode(GameMode.PRACTICE)
	hud.hide_menu()
	_remove_vr_menu_panel()
	if already_there:
		return
	KillCam.cancel()
	TimeManager.reset()
	_clear_combatants()
	_instance_scenario(load(PRACTICE_HUB))
	_place_local_player(current_scenario.get_player_spawn())


## True whenever the practice hub is loaded, including under the VR menu.
func in_practice() -> bool:
	return current_scenario is PracticeHub


func practice_hub() -> PracticeHub:
	return current_scenario as PracticeHub


## Flat main menu: the arena behind it is a frozen picture, not a level.
func is_menu_backdrop() -> bool:
	return mode == GameMode.MENU and not is_vr


func start_free_duel(scenario_index: int, archetype_index: int) -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.FREE_DUEL)
	hud.hide_menu()
	_remove_vr_menu_panel()
	current_archetype_index = clampi(archetype_index, 0, ARCHETYPES.size() - 1)
	var archetype: AIArchetype = load(ARCHETYPES[current_archetype_index])
	_begin_ai_duel(scenario_index, archetype, 1.0)


func start_gauntlet() -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.GAUNTLET)
	hud.hide_menu()
	_remove_vr_menu_panel()
	gauntlet.start(load(GAUNTLET_LADDER))


## Restart the active free duel, gauntlet encounter, or (host) MP rematch.
func reset_current_duel() -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	match mode:
		GameMode.FREE_DUEL:
			_bump_action_generation()
			TimeManager.reset()
			var archetype: AIArchetype = load(ARCHETYPES[current_archetype_index])
			_begin_ai_duel(current_scenario_index, archetype, 1.0)
			show_message("Duel reset", 1.5)
		GameMode.GAUNTLET:
			if not gauntlet.running:
				return
			_bump_action_generation()
			TimeManager.reset()
			var encounter := gauntlet.ladder.encounters[gauntlet.encounter_index]
			begin_gauntlet_encounter(encounter)
			show_message("Encounter reset", 1.5)
		GameMode.MULTIPLAYER:
			if not NetworkManager.is_host():
				show_message("Only the host can reset the duel.", 2.0)
				return
			if NetworkManager.peer_count() <= 0:
				show_message("No opponent connected.", 2.0)
				return
			_bump_action_generation()
			TimeManager.reset()
			duel.host_start_mp_duel(current_scenario_index, 0)
			show_message("Duel reset", 1.5)
		GameMode.PRACTICE:
			if in_practice():
				practice_hub().reset_range()
				show_message("Range reset", 1.5)
		_:
			show_message("No active duel to reset.", 1.5)


## Called by the gauntlet controller for each rung of the ladder.
func begin_gauntlet_encounter(encounter: DuelEncounter) -> void:
	_begin_ai_duel(encounter.scenario_index, encounter.archetype, encounter.health_mult)


func _begin_ai_duel(scenario_index: int, archetype: AIArchetype, health_mult: float) -> void:
	_clear_combatants()
	_load_scenario(scenario_index)
	_place_local_player(current_scenario.get_player_spawn())

	current_ai = load(AI_SCENE).instantiate()
	world_root.add_child(current_ai)
	current_ai.global_transform = current_scenario.get_enemy_spawn()
	current_ai.capture_spawn()
	current_ai.setup(archetype, health_mult, local_player)

	duel.start_ai_duel(current_ai)


# -- Multiplayer flow ---------------------------------------------------------

func _on_session_started(as_host: bool) -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.MULTIPLAYER)
	hud.hide_menu()
	_remove_vr_menu_panel()
	duel.stop()
	_clear_combatants()
	if as_host:
		if NetworkManager.transport_kind() == "steam":
			show_message(
					"Waiting for a challenger… Steam lobby (%s). Esc → Invite friends, or Shift+Tab."
					% NetworkManager.steam_lobby_label(), 12.0)
		else:
			var ips := NetworkManager.lan_addresses()
			var ip_hint := ", ".join(ips) if not ips.is_empty() else "(no LAN IPv4)"
			show_message("Waiting for a challenger… LAN %s" % ip_hint, 12.0)
		_load_scenario(current_scenario_index)
		_place_local_player(current_scenario.get_player_spawn())
	else:
		show_message("Connected. Waiting for the host...")


func _on_peer_joined(peer_id: int) -> void:
	if NetworkManager.is_host() and mode == GameMode.MULTIPLAYER:
		# Host picks the arena and kicks off the duel for everyone.
		duel.host_start_mp_duel(current_scenario_index, peer_id)


func _on_peer_left(_peer_id: int) -> void:
	if mode == GameMode.MULTIPLAYER:
		duel.stop()
		_despawn_avatar()
		show_message("Opponent left.")


func _on_session_ended(reason: String) -> void:
	if mode == GameMode.MULTIPLAYER:
		show_message("Session ended: %s" % reason)
		go_to_menu()


## Called by DuelManager on every peer when an MP duel begins.
## `time_of_day` is the host's roll so both peers share one sky.
func setup_mp_duel(scenario_index: int, time_of_day: float) -> void:
	_clear_combatants()
	_load_scenario(scenario_index, time_of_day)
	var my_spawn := current_scenario.get_player_spawn() if NetworkManager.is_host() \
			else current_scenario.get_enemy_spawn()
	var their_spawn := current_scenario.get_enemy_spawn() if NetworkManager.is_host() \
			else current_scenario.get_player_spawn()
	_place_local_player(my_spawn)
	_spawn_avatar(their_spawn)


func _spawn_avatar(spawn: Transform3D) -> void:
	_despawn_avatar()
	remote_avatar = load(AVATAR_SCENE).instantiate()
	world_root.add_child(remote_avatar)
	remote_avatar.global_transform = spawn
	VoiceChat.bind_voice_player(remote_avatar.voice_player)


func _despawn_avatar() -> void:
	VoiceChat.bind_voice_player(null)
	if is_instance_valid(remote_avatar):
		remote_avatar.queue_free()
	remote_avatar = null


func _on_pose_received(_peer_id: int, head: Transform3D, left: Transform3D,
		right: Transform3D, flags: int, gun: Transform3D) -> void:
	if is_instance_valid(remote_avatar):
		remote_avatar.apply_pose(head, left, right, flags, gun)


func _on_shot_received(_peer_id: int, origin: Vector3, direction: Vector3) -> void:
	# Remote player fired. Everyone spawns the tracer; only the host's
	# simulation is authoritative for damage.
	var exclude: Array[RID] = []
	var grace: Array[RID] = []
	if is_instance_valid(remote_avatar):
		exclude = remote_avatar.hitbox_rids()
		grace = remote_avatar.gun_hand_hitbox_rids()
	Bullet.spawn(main_root, origin, direction, tuning["bullet_speed"],
			NetworkManager.is_host(), exclude, false,
			float(tuning.get("self_hit_grace", 0.28)), grace)


# -- Duel results -------------------------------------------------------------

func _on_duel_finished(local_player_won: bool, reason: String) -> void:
	var headline := "YOU WIN" if local_player_won else "YOU LOSE"
	var message := "%s\n%s" % [headline, reason]
	var generation_at_finish := _action_generation
	var delay_vr_banner := is_vr and KillCam.is_playing
	if delay_vr_banner:
		hud.show_message(message, 3.0)
	else:
		show_message(message, 3.0)
	var schedule_next := func() -> void:
		if _action_generation != generation_at_finish:
			return
		match mode:
			GameMode.FREE_DUEL:
				_after_delay(4.0, go_to_menu)
			GameMode.GAUNTLET:
				_after_delay(3.5, gauntlet.on_duel_finished.bind(local_player_won))
			GameMode.MULTIPLAYER:
				if NetworkManager.is_host():
					_after_delay(5.0, _mp_rematch)
	if KillCam.is_playing:
		if delay_vr_banner:
			KillCam.finished.connect(func() -> void:
				if _action_generation != generation_at_finish:
					return
				if is_instance_valid(local_player):
					local_player.show_vr_message(message, 3.0)
			, CONNECT_ONE_SHOT)
		KillCam.finished.connect(schedule_next, CONNECT_ONE_SHOT)
	else:
		schedule_next.call()


func _mp_rematch() -> void:
	if mode == GameMode.MULTIPLAYER and NetworkManager.peer_count() > 0:
		duel.host_start_mp_duel(current_scenario_index, 0)


func _after_delay(seconds: float, callable: Callable) -> void:
	var mode_at_schedule := mode
	var generation_at_schedule := _action_generation
	get_tree().create_timer(seconds, false, false, true).timeout.connect(func() -> void:
		if mode == mode_at_schedule and _action_generation == generation_at_schedule:
			callable.call())


func _bump_action_generation() -> void:
	_action_generation += 1


func _set_mode(new_mode: int) -> void:
	mode = new_mode
	mode_changed.emit(mode)


# -- Scenario / player helpers -------------------------------------------------

func _load_scenario(index: int, time_of_day := -1.0) -> void:
	current_scenario_index = clampi(index, 0, SCENARIOS.size() - 1)
	_instance_scenario(load(SCENARIOS[current_scenario_index]), time_of_day)


## Swap the live scenario without touching `current_scenario_index` (the menu
## backdrop and the practice hub must not change which arena MP hosts on).
func _instance_scenario(resource: ScenarioResource, time_of_day := -1.0) -> void:
	if current_scenario != null:
		current_scenario.queue_free()
		current_scenario = null
	current_scenario = resource.scene.instantiate()
	current_scenario.scenario_resource = resource
	# Negative means this load picks its own time (SP, menu, host waiting).
	# MP passes the host's roll so the client does not roll again.
	if time_of_day < 0.0:
		time_of_day = randf()
	current_scenario.time_of_day = time_of_day
	world_root.add_child(current_scenario)


func _place_local_player(spawn: Transform3D) -> void:
	local_player.reset_for_duel(spawn)


func _clear_combatants() -> void:
	if is_instance_valid(current_ai):
		current_ai.queue_free()
	current_ai = null
	_despawn_avatar()
	# Free live projectiles before trails — otherwise clear_all frees the trail
	# while Bullet._physics_process still calls add_point on it.
	Bullet.clear_all()
	BulletTrail.clear_all()


func _spawn_vr_menu_panel() -> void:
	local_player.show_menu_panel(hud.get_menu_control())


func _remove_vr_menu_panel() -> void:
	if is_instance_valid(local_player):
		local_player.hide_menu_panel()


func show_message(text: String, duration := 2.5) -> void:
	hud.show_message(text, duration)
	if is_vr and is_instance_valid(local_player):
		local_player.show_vr_message(text, duration)


# -- Tuning -------------------------------------------------------------------

func set_tuning(key: String, value: Variant) -> void:
	tuning[key] = value
	tuning_changed.emit(key, value)
	_save_tuning()


func _save_tuning() -> void:
	var cfg := ConfigFile.new()
	for key in tuning:
		cfg.set_value("tuning", key, tuning[key])
	cfg.save(TUNING_PATH)


func _load_tuning() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TUNING_PATH) != OK:
		return
	for key in tuning:
		tuning[key] = cfg.get_value("tuning", key, tuning[key])
