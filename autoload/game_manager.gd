extends Node
## Autoload. Central coordinator: game modes, scenario loading, player and
## enemy spawning, HUD messages, and gameplay tuning values. The duel state
## machine and gauntlet controller live as children so their node paths are
## stable for RPCs.

signal mode_changed(mode: int)
signal tuning_changed(key: String, value: Variant)

enum GameMode { BOOT, MENU, FREE_DUEL, GAUNTLET, MULTIPLAYER }

const TUNING_PATH := "user://tuning.cfg"

## Scenario registry -- add new scenarios here and they appear in every menu.
const SCENARIOS: Array[String] = [
	"res://scenarios/main_street/main_street.tres",
	"res://scenarios/saloon/saloon.tres",
	"res://scenarios/train_rooftop/train_rooftop.tres",
	"res://scenarios/canyon/canyon.tres",
]

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
	"ai_speed_mult": 1.0,    # global multiplier on AI reaction/draw speed
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
	## Seconds the gun stays holstered after an arm hit.
	"arm_disarm_duration": 1.5,
	## Seconds a leg hit slows locomotion.
	"leg_slow_duration": 2.5,
	## Move-speed multiplier while limping (1 = no penalty).
	"leg_speed_mult": 0.45,
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


## Called once by main.tscn after XR init.
func setup(main: Node3D, use_vr: bool) -> void:
	main_root = main
	world_root = main.get_node("WorldRoot")
	is_vr = use_vr

	hud = load(HUD_SCENE).instantiate()
	main.add_child(hud)

	local_player = load(PLAYER_SCENE).instantiate()
	local_player.use_vr = use_vr
	main.add_child(local_player)

	DebugMenu.setup(use_vr)
	go_to_menu()


# -- Mode transitions ---------------------------------------------------------

func go_to_menu() -> void:
	_bump_action_generation()
	KillCam.cancel()
	NetworkManager.leave()
	duel.stop()
	gauntlet.stop()
	TimeManager.reset()
	_clear_combatants()
	_set_mode(GameMode.MENU)
	_load_scenario(0)
	_place_local_player(current_scenario.get_player_spawn())
	hud.show_menu(is_vr)
	if is_vr:
		_spawn_vr_menu_panel()


func start_free_duel(scenario_index: int, archetype_index: int) -> void:
	_bump_action_generation()
	_set_mode(GameMode.FREE_DUEL)
	hud.hide_menu()
	_remove_vr_menu_panel()
	current_archetype_index = clampi(archetype_index, 0, ARCHETYPES.size() - 1)
	var archetype: AIArchetype = load(ARCHETYPES[current_archetype_index])
	_begin_ai_duel(scenario_index, archetype, 1.0)


func start_gauntlet() -> void:
	_bump_action_generation()
	_set_mode(GameMode.GAUNTLET)
	hud.hide_menu()
	_remove_vr_menu_panel()
	gauntlet.start(load(GAUNTLET_LADDER))


## Restart the active free duel, gauntlet encounter, or (host) MP rematch.
func reset_current_duel() -> void:
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
	_bump_action_generation()
	_set_mode(GameMode.MULTIPLAYER)
	hud.hide_menu()
	_remove_vr_menu_panel()
	duel.stop()
	_clear_combatants()
	if as_host:
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
func setup_mp_duel(scenario_index: int) -> void:
	_clear_combatants()
	_load_scenario(scenario_index)
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


func _despawn_avatar() -> void:
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
	if is_instance_valid(remote_avatar):
		exclude = remote_avatar.hitbox_rids()
	Bullet.spawn(main_root, origin, direction, tuning["bullet_speed"],
			NetworkManager.is_host(), exclude, false)


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
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if mode == mode_at_schedule and _action_generation == generation_at_schedule:
			callable.call())


func _bump_action_generation() -> void:
	_action_generation += 1


func _set_mode(new_mode: int) -> void:
	mode = new_mode
	mode_changed.emit(mode)


# -- Scenario / player helpers -------------------------------------------------

func _load_scenario(index: int) -> void:
	if current_scenario != null:
		current_scenario.queue_free()
		current_scenario = null
	current_scenario_index = clampi(index, 0, SCENARIOS.size() - 1)
	var resource: ScenarioResource = load(SCENARIOS[current_scenario_index])
	current_scenario = resource.scene.instantiate()
	current_scenario.scenario_resource = resource
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
