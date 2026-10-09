extends Node
## Autoload. Central coordinator: game modes, scenario loading, player and
## enemy spawning, HUD messages, and gameplay tuning values. The duel state
## machine and gauntlet controller live as children so their node paths are
## stable for RPCs.

signal mode_changed(mode: int)
signal tuning_changed(key: String, value: Variant)

enum GameMode { BOOT, MENU, FREE_DUEL, GAUNTLET, MULTIPLAYER, PRACTICE, MESH_LAB, HORDE }

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

## Debug-only mannequin stage. Not in SCENARIOS, so no menu offers it as a duel.
const MESH_LAB_SCENE := "res://dev/mesh_lab/mesh_lab.tscn"

const ARCHETYPES: Array[String] = [
	"res://ai/archetypes/drunk.tres",
	"res://ai/archetypes/sheriff.tres",
	"res://ai/archetypes/ghost.tres",
]

## Most NPCs in one SP standoff.
const MAX_NPCS := 3
## Body-color shift between copies of one archetype: lighter for the 2nd, darker for the 3rd.
const NPC_TINT_SHIFT := 0.25

const PLAYER_SCENE := "res://player/player.tscn"
const AI_SCENE := "res://ai/duelist.tscn"
const AVATAR_SCENE := "res://player/remote_avatar.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
const GAUNTLET_LADDER := "res://gauntlet/ladder_default.tres"
const HORDE_WAVES := "res://gauntlet/horde_default.tres"

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
	## Hinge speed (rad/s) applied when the spin bind is pressed, signed so the
	## muzzle tip moves upward. 0 disables the kick.
	"spin_start_boost": 6.0,
	## Hinge damping (1/s). Higher = spin dies faster. 0 = coasts forever.
	"spin_damping": 0.0,
	## Gravity torque scale on the hanging barrel (0 = inertial only).
	## Lower makes the first loop easier to pump over the top.
	"spin_gravity": 1.6,
	## Moment of inertia for whip / gravity (kg·m²-ish). Lower = snappier start.
	"spin_inertia": 0.02,
	## How quickly a fast wrist flick transfers into residual spin. While the
	## hinge is still slow, WeaponBase scales this down so the first motion
	## breaks the barrel free instead of sticking to the hand.
	"spin_coupling": 3.0,
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
	## Seconds of corpse orbit between the kill-cam fly-along and the replay.
	"death_cam_hold": 2.0,
	## Seconds of duel kept before the lethal hit.
	"replay_pre_death": 5.0,
	## Seconds of duel kept after the lethal hit.
	"replay_post_death": 2.0,
	## Tail of the clip that plays back in slow motion.
	"replay_slow_seconds": 2.0,
	## Playback rate during that tail (1 = normal speed).
	"replay_slow_factor": 0.35,
	## Corpse ragdoll. 0 holds the death pose; the NPC tips over stiff again.
	"ragdoll_enabled": 1.0,
	## Kick (N·s) at the body nearest the hit, along the shot.
	"ragdoll_hit_impulse": 30.0,
	## Shove (N·s) shared by hips, spine, and chest along the shot.
	"ragdoll_torso_push": 90.0,
	## Share of the torso shove that goes up instead of along the shot.
	"ragdoll_lift": 0.25,
	"ragdoll_angular_damp": 2.0,
	## Every body slower than this (m/s) for 0.4 s ends the fall.
	"ragdoll_settle_speed": 0.12,
	## Seconds before the fall is cut off and the pose is kept.
	"ragdoll_max_time": 3.5,
	## Speed (m/s) a dying gun is flung with.
	"ragdoll_gun_fling": 7.0,
	## Share of accepted hits that cut a hole where the bullet landed.
	"chunk_chance": 1.0,
	## Hole radius (m) rolled between these on the head and torso.
	"cut_min": 0.05,
	"cut_max": 0.10,
	## Arm and leg holes are no wider than this (m).
	"cut_limb_max": 0.06,
	## Speed (m/s) a knocked chunk leaves along the shot.
	"gib_speed": 3.5,
	## Gibs alive at once. The oldest is freed past this.
	"gib_cap": 16.0,
}

var mode: int = GameMode.BOOT
var is_vr := false
var world_root: Node3D
var main_root: Node3D
var local_player: Player
var remote_avatar: RemoteAvatar
var current_scenario: ScenarioBase
var current_scenario_index := 0
## The free-duel lineup the restart replays.
var current_lineup: Array[AIArchetype] = []
var current_ais: Array[DuelistAI] = []
var hud: Hud

var duel: DuelManager
var gauntlet: GauntletController
var horde: HordeController
var _action_generation := 0
var _mesh_lab_open := false
var _mesh_lab_puppet: MeshLabPuppet
var _mesh_lab_flycam: MeshLabFlycam
var _mesh_lab_menu: MeshLabMotionMenu


func _ready() -> void:
	duel = DuelManager.new()
	duel.name = "DuelManager"
	add_child(duel)
	gauntlet = GauntletController.new()
	gauntlet.name = "GauntletController"
	add_child(gauntlet)
	horde = HordeController.new()
	horde.name = "HordeController"
	add_child(horde)
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
	_close_mesh_lab_view()
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	KillCam.cancel()
	NetworkManager.leave()
	duel.stop()
	gauntlet.stop()
	horde.stop()
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


func in_mesh_lab() -> bool:
	return mode == GameMode.MESH_LAB


## Debug stage. Flat: a scripted mannequin and a fly camera. VR: the headset
## player stays in control and the desktop window is the fly camera.
## Leaving always returns to the main menu.
func enter_mesh_lab() -> void:
	if in_mesh_lab():
		return
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	# Set the mode before leave(), so a multiplayer session_ended does not
	# bounce through the main menu on the way in.
	_set_mode(GameMode.MESH_LAB)
	KillCam.cancel()
	NetworkManager.leave()
	duel.stop()
	gauntlet.stop()
	horde.stop()
	TimeManager.reset()
	_clear_combatants()
	if is_instance_valid(hud):
		hud.hide_menu()
	_remove_vr_menu_panel()
	_instance_mesh_lab()
	MeshLabMotion.reset()
	_mesh_lab_open = true
	_mesh_lab_flycam = MeshLabFlycam.new()
	_mesh_lab_flycam.name = "MeshLabFlycam"
	main_root.add_child(_mesh_lab_flycam)
	_mesh_lab_menu = MeshLabMotionMenu.new()
	_mesh_lab_menu.name = "MeshLabMotionMenu"
	if is_vr:
		_place_local_player(current_scenario.get_player_spawn())
		local_player.set_mesh_lab_preview(true)
		var env := _mesh_lab_environment()
		_mesh_lab_flycam.attach_vr(main_root, world_root.get_world_3d(), env)
		_mesh_lab_flycam.mount_menu(_mesh_lab_menu)
	else:
		local_player.set_mesh_lab_parked(true)
		_mesh_lab_puppet = MeshLabPuppet.new()
		_mesh_lab_puppet.name = "MeshLabPuppet"
		current_scenario.add_child(_mesh_lab_puppet)
		_mesh_lab_flycam.attach_flat(world_root)
		main_root.add_child(_mesh_lab_menu)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func leave_mesh_lab() -> void:
	if not in_mesh_lab():
		return
	_close_mesh_lab_view()
	go_to_menu()


func _close_mesh_lab_view() -> void:
	if not _mesh_lab_open:
		return
	_mesh_lab_open = false
	if is_instance_valid(_mesh_lab_puppet):
		_mesh_lab_puppet.queue_free()
	_mesh_lab_puppet = null
	if is_instance_valid(_mesh_lab_menu):
		_mesh_lab_menu.queue_free()
	_mesh_lab_menu = null
	if is_instance_valid(_mesh_lab_flycam):
		_mesh_lab_flycam.shutdown()
	_mesh_lab_flycam = null
	if is_instance_valid(local_player):
		local_player.set_mesh_lab_preview(false)
		local_player.set_mesh_lab_parked(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _instance_mesh_lab() -> void:
	if current_scenario != null:
		current_scenario.queue_free()
		current_scenario = null
	var packed: PackedScene = load(MESH_LAB_SCENE)
	current_scenario = packed.instantiate()
	current_scenario.time_of_day = 1.0
	world_root.add_child(current_scenario)


func _mesh_lab_environment() -> Environment:
	var world := current_scenario.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null:
		return null
	return world.environment


func practice_hub() -> PracticeHub:
	return current_scenario as PracticeHub


## Flat main menu: the arena behind it is a frozen picture, not a level.
func is_menu_backdrop() -> bool:
	return mode == GameMode.MENU and not is_vr


## `archetype_index == ARCHETYPES.size()` is Mixed: each slot rolls its own archetype.
func start_free_duel(scenario_index: int, archetype_index: int, count := 1) -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.FREE_DUEL)
	hud.hide_menu()
	_remove_vr_menu_panel()
	current_lineup = _roll_lineup(archetype_index, count)
	_begin_ai_duel(scenario_index, current_lineup, 1.0)


func _roll_lineup(archetype_index: int, count: int) -> Array[AIArchetype]:
	var lineup: Array[AIArchetype] = []
	var mixed := archetype_index >= ARCHETYPES.size()
	var fixed := clampi(archetype_index, 0, ARCHETYPES.size() - 1)
	for _slot in clampi(count, 1, MAX_NPCS):
		lineup.append(load(ARCHETYPES[randi() % ARCHETYPES.size() if mixed else fixed]))
	return lineup


func start_gauntlet() -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.GAUNTLET)
	hud.hide_menu()
	_remove_vr_menu_panel()
	gauntlet.start(load(GAUNTLET_LADDER))


## Endless single-player survival on one arena, one life. `scenario_index` is the
## Horde row's own remembered pick (separate from the free-duel row).
func start_horde(scenario_index: int) -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.HORDE)
	hud.hide_menu()
	_remove_vr_menu_panel()
	TimeManager.reset()
	_clear_combatants()
	_load_scenario(scenario_index)
	_place_local_player(current_scenario.get_player_spawn())
	horde.start(load(HORDE_WAVES))


## Restart the active free duel, gauntlet encounter, or (host) MP rematch.
func reset_current_duel() -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	match mode:
		GameMode.FREE_DUEL:
			_bump_action_generation()
			TimeManager.reset()
			_begin_ai_duel(current_scenario_index, current_lineup, 1.0)
			show_message(tr("MSG_DUEL_RESET"), 1.5)
		GameMode.GAUNTLET:
			if not gauntlet.running:
				return
			_bump_action_generation()
			TimeManager.reset()
			var encounter := gauntlet.ladder.encounters[gauntlet.encounter_index]
			begin_gauntlet_encounter(encounter)
			show_message(tr("MSG_ENCOUNTER_RESET"), 1.5)
		GameMode.MULTIPLAYER:
			if not NetworkManager.is_host():
				show_message(tr("MSG_HOST_ONLY_RESET"), 2.0)
				return
			if NetworkManager.peer_count() <= 0:
				show_message(tr("MSG_NO_OPPONENT"), 2.0)
				return
			_bump_action_generation()
			TimeManager.reset()
			duel.host_start_mp_duel(current_scenario_index, 0)
			show_message(tr("MSG_DUEL_RESET"), 1.5)
		GameMode.PRACTICE:
			if in_practice():
				practice_hub().reset_range()
				show_message(tr("MSG_RANGE_RESET"), 1.5)
		GameMode.HORDE:
			_bump_action_generation()
			start_horde(current_scenario_index)
			show_message(tr("MSG_HORDE_RESTARTED"), 1.5)
		_:
			show_message(tr("MSG_NO_ACTIVE_DUEL"), 1.5)


## Called by the gauntlet controller for each rung of the ladder.
func begin_gauntlet_encounter(encounter: DuelEncounter) -> void:
	_begin_ai_duel(encounter.scenario_index, encounter.lineup(), encounter.health_mult)


func _begin_ai_duel(scenario_index: int, lineup: Array[AIArchetype], health_mult: float) -> void:
	_clear_combatants()
	_load_scenario(scenario_index)
	_place_local_player(current_scenario.get_player_spawn())

	var spawns := current_scenario.get_enemy_spawns(lineup.size())
	_spawn_npcs(lineup, spawns, health_mult, 1.0)

	# One NPC faces you before the bell; several pick their targets at the bell.
	if current_ais.size() == 1:
		current_ais[0].set_target(local_player)
	var text := lineup_text(lineup)
	show_message(text, 2.0)
	duel.start_ai_duel(current_ais, text if lineup.size() >= 2 else "")


## Spawns `lineup` on `spawns` (actor ids, tint shades for repeated archetypes,
## current_ais). Shared by the free duel / gauntlet path and Horde's wave spawner.
func _spawn_npcs(lineup: Array[AIArchetype], spawns: Array[Transform3D],
		health_mult: float, speed_mult: float) -> void:
	var copies := {}
	for slot in lineup.size():
		var ai: DuelistAI = load(AI_SCENE).instantiate()
		ai.actor_id = slot + 1
		world_root.add_child(ai)
		ai.global_transform = spawns[slot]
		ai.capture_spawn()
		var seen: int = copies.get(lineup[slot], 0)
		copies[lineup[slot]] = seen + 1
		ai.setup(lineup[slot], health_mult, [0.0, NPC_TINT_SHIFT, -NPC_TINT_SHIFT][seen], speed_mult)
		current_ais.append(ai)


## Called by HordeController for each wave: clears the last wave's corpses/bullets/trails,
## heals and reloads the player in place (no teleport), spawns the lineup clear of the
## player, points every NPC at the player, and starts the round.
func begin_horde_wave(lineup: Array[AIArchetype], speed_mult: float, wave: int) -> void:
	_clear_combatants()
	local_player.reset_for_wave()
	_capture_flat_mouse()
	var spawns := current_scenario.get_horde_spawns(
			lineup.size(), local_player.get_head_position(), horde.waves.spawn_min_distance)
	lineup = lineup.slice(0, spawns.size())
	_spawn_npcs(lineup, spawns, 1.0, speed_mult)
	for ai in current_ais:
		ai.focus_player = true
		ai.set_target(local_player)
		ai.died.connect(horde.note_kill.bind(ai))
	var text := tr("MSG_HORDE_WAVE") % [wave, lineup_text(lineup)]
	show_message(text, 2.0)
	duel.start_ai_duel(current_ais, text if lineup.size() >= 2 else "", false)


## "A", "A & B", or "A, B & C" from the archetype display names.
func lineup_text(lineup: Array[AIArchetype]) -> String:
	var names: PackedStringArray = []
	for archetype in lineup:
		names.append(archetype.display_name)
	if names.size() <= 1:
		return "".join(names)
	return tr("MSG_LINEUP_AND") % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## The local player (if alive) plus every NPC still standing.
func live_duelists() -> Array[Node3D]:
	var live: Array[Node3D] = []
	if is_instance_valid(local_player) and local_player.alive:
		live.append(local_player)
	for ai in current_ais:
		if is_instance_valid(ai) and ai.is_alive():
			live.append(ai)
	return live


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
					tr("MSG_WAIT_STEAM")
					% NetworkManager.steam_lobby_label(), 12.0)
		else:
			var ips := NetworkManager.lan_addresses()
			var ip_hint := ", ".join(ips) if not ips.is_empty() else tr("MSG_NO_LAN_IP")
			show_message(tr("MSG_WAIT_LAN") % ip_hint, 12.0)
		_load_scenario(current_scenario_index)
		_place_local_player(current_scenario.get_player_spawn())
	else:
		show_message(tr("MSG_CONNECTED"))


func _on_peer_joined(peer_id: int) -> void:
	if NetworkManager.is_host() and mode == GameMode.MULTIPLAYER:
		# Host picks the arena and kicks off the duel for everyone.
		duel.host_start_mp_duel(current_scenario_index, peer_id)


func _on_peer_left(_peer_id: int) -> void:
	if mode == GameMode.MULTIPLAYER:
		duel.stop()
		_despawn_avatar()
		show_message(tr("MSG_OPPONENT_LEFT"))


func _on_session_ended(reason: String) -> void:
	if mode == GameMode.MULTIPLAYER:
		show_message(tr("MSG_SESSION_ENDED") % reason)
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
		right: Transform3D, flags: int, gun: Transform3D, hands: int, objects: int,
		prop: Transform3D, round_xf: Transform3D) -> void:
	if DeathCam.blocks_remote_pose():
		return
	if is_instance_valid(remote_avatar):
		remote_avatar.apply_pose(head, left, right, flags, gun, hands, objects, prop, round_xf)


func _on_shot_received(_peer_id: int, origin: Vector3, direction: Vector3) -> void:
	# Remote player fired. Everyone spawns the tracer; only the host's
	# simulation is authoritative for damage.
	var exclude: Array[RID] = []
	var grace: Array[RID] = []
	if is_instance_valid(remote_avatar):
		exclude = remote_avatar.hitbox_rids()
		grace = remote_avatar.gun_hand_hitbox_rids()
	ReplayBuffer.record_shot(origin, direction, ReplayBuffer.ACTOR_OTHER)
	Bullet.spawn(main_root, origin, direction, tuning["bullet_speed"],
			NetworkManager.is_host(), exclude, false,
			float(tuning.get("self_hit_grace", 0.28)), grace)


# -- Duel results -------------------------------------------------------------

func _on_duel_finished(local_player_won: bool, reason: String) -> void:
	var headline := tr("MSG_YOU_WIN") if local_player_won else tr("MSG_YOU_LOSE")
	var message := "%s\n%s" % [headline, tr(reason)]
	if mode == GameMode.HORDE and local_player_won:
		message = horde.clear_wave()
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
			GameMode.HORDE:
				_after_delay(horde.break_seconds() if local_player_won else 3.5,
						horde.on_duel_finished.bind(local_player_won))
			GameMode.MULTIPLAYER:
				if NetworkManager.is_host():
					_after_delay(5.0, _mp_rematch)
	if DeathCam.is_active():
		DeathCam.trailing_started.connect(schedule_next, CONNECT_ONE_SHOT)
		if delay_vr_banner:
			var banner_shown := [false]
			var show_banner := func() -> void:
				if banner_shown[0] or _action_generation != generation_at_finish:
					return
				banner_shown[0] = true
				if is_instance_valid(local_player):
					local_player.show_vr_message(message, 3.0)
			if KillCam.is_playing:
				KillCam.finished.connect(show_banner, CONNECT_ONE_SHOT)
			DeathCam.skipped.connect(show_banner, CONNECT_ONE_SHOT)
	elif KillCam.is_playing:
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
	_capture_flat_mouse()


## Flat play owns the cursor from the first frame of a match or wave, so look
## works without a click to re-capture. Menus, pause, the debug panel, and the
## mesh lab (its own toggle) keep the cursor.
func _capture_flat_mouse() -> void:
	if is_vr or OS.has_feature("headless"):
		return
	if mode in [GameMode.BOOT, GameMode.MENU, GameMode.MESH_LAB]:
		return
	if is_pause_open() or DebugMenu.panel.visible:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _clear_combatants() -> void:
	DeathCam.stop()
	ReplayBuffer.abort()
	for ai in current_ais:
		if is_instance_valid(ai):
			ai.queue_free()
	current_ais = []
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
	cfg.load(TUNING_PATH)
	for key in tuning:
		cfg.set_value("tuning", key, tuning[key])
	cfg.save(TUNING_PATH)


func _load_tuning() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(TUNING_PATH) != OK:
		return
	for key in tuning:
		tuning[key] = cfg.get_value("tuning", key, tuning[key])
	if cfg.get_value("meta", "spin_startup", false):
		return
	# Saved copies of the old spin defaults would hide the easier startup.
	# Only replace a value that is still that old default, and only once.
	const SPIN_DEFAULT_MIGRATION := {
		"spin_gravity": [2.0, 1.6],
		"spin_inertia": [0.03, 0.02],
		"spin_coupling": [8.0, 3.0],
	}
	for key in SPIN_DEFAULT_MIGRATION:
		var pair: Array = SPIN_DEFAULT_MIGRATION[key]
		if is_equal_approx(float(tuning.get(key, pair[1])), float(pair[0])):
			tuning[key] = pair[1]
			cfg.set_value("tuning", key, pair[1])
	cfg.set_value("meta", "spin_startup", true)
	cfg.save(TUNING_PATH)
