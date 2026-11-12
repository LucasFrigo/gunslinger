extends Node
## Autoload. Central coordinator: game modes, scenario loading, player and
## enemy spawning, HUD messages, and gameplay tuning values. The duel state
## machine and gauntlet controller live as children so their node paths are
## stable for RPCs.

signal mode_changed(mode: int)
signal tuning_changed(key: String, value: Variant)

enum GameMode { BOOT, MENU, FREE_DUEL, GAUNTLET, MULTIPLAYER, PRACTICE, MESH_LAB, HORDE }

const TUNING_PATH := "user://tuning.cfg"
## Tuning keys that are also `[shader_globals]` in project.godot: skin, cavity, and world
## surfaces read them, so one F3 value covers every banded shader.
const WORLD_GLOBALS: Array[StringName] = [
	&"band_low", &"band_soft", &"grain_strength_mult", &"grain_scale_mult",
	&"sheet_mix"]

## Scenario registry -- add new scenarios here and they appear in every menu.
const SCENARIOS: Array[String] = [
	"res://scenarios/main_street/main_street.tres",
	"res://scenarios/saloon/saloon.tres",
	"res://scenarios/train_rooftop/train_rooftop.tres",
	"res://scenarios/canyon/canyon.tres",
	"res://scenarios/oilfield_train/oilfield_train.tres",
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
	## Barrel smoke wisp length multiplier (1 = ~2.4 s). 0 turns the wisp off.
	"barrel_smoke_lifetime": 1.0,
	## Bullet trail ribbon width (m) and the share of its length the tail takes to thin out.
	"trail_width": 0.035,
	"trail_tail_share": 0.35,
	## Hurt vignette peak (0..1) on the local player: arm or leg hit, torso hit, kill.
	"hurt_limb": 0.3,
	"hurt_torso": 0.6,
	"hurt_kill": 0.9,
	## Seconds the kill-cam iris takes to close, and to open on the next view.
	"iris_time": 0.3,
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
	## Cartoon spin: the blaster mesh turns this many times faster than the real
	## hinge. Visual only; catch, throw, and fire still use the real hinge.
	"spin_visual_mult": 3.0,
	## Flat twirl flourish (rad/s) while the twirl key is held.
	"twirl_rate": 25.0,
	## Spin effect (smear wedge + ink arcs): 0 off, 1 on.
	"spin_fx_mode": 1,
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
	## Banded body light: share the first band passes, and the step softness.
	"band_low": 0.65,
	"band_soft": 0.03,
	## World surface shader: grain strength and tile scale multipliers, how far the trim sheet
	## replaces the flat color (0 is the old look), and the share of the wind that moves
	## plants, hay, signs, and awnings (0 holds them still).
	"grain_strength_mult": 1.0,
	"grain_scale_mult": 1.0,
	"sheet_mix": 1.0,
	"sway_scale": 1.0,
	## Train Rooftop engine smoke: 1 is the default plume, 0 turns it off, 3 is thrice the
	## particles. Length, speed, and puff size do not change.
	"engine_smoke_density": 1.0,
	## Oil field flame columns (`FlameColumn`): 1 shows them, 0 hides every one. The dark
	## plume meshes stay.
	"flame_columns": 1.0,
	## Skin silhouette rim: strength and falloff exponent (hands get none).
	"edge_strength": 0.35,
	"edge_power": 3.0,
	## Ink outline around every duelist: 1 on, 0 off. Width is metres of line per metre of
	## view distance (held between 1 m and 14 m).
	"outline_enabled": 1.0,
	"outline_width": 0.004,
	## Same line on the revolver, offhand props, and brass: metres per metre of view
	## distance (held between 0.3 m and 6 m). `outline_enabled` hides these too.
	"object_outline_width": 0.0015,
}

var mode: int = GameMode.BOOT
var is_vr := false
var world_root: Node3D
var main_root: Node3D
var local_player: Player
## Multiplayer: lobby slot -> the RemoteAvatar standing for it: every human but this one,
## and on a client the proxy of each NPC the host runs (in `current_ais` there).
var avatars := {}
var current_scenario: ScenarioBase
var current_scenario_index := 0
## Flat main-menu backdrop: a fixed camera on one of the scenario's MenuCameras
## markers, with the player (and its shadow) hidden. Torn down by the next real spawn.
var _menu_backdrop_camera: Camera3D
## The free-duel lineup the restart replays.
var current_lineup: Array[AIArchetype] = []
var current_ais: Array[DuelistAI] = []
var hud: Hud

var duel: DuelManager
var gauntlet: GauntletController
var horde: HordeController
var _action_generation := 0
## The multiplayer arena is loaded (set by the first `_mp_lobby` of a session).
var _mp_room := false
## Slot count the waiting room's ring points were laid out for.
var _lobby_ring := 0
## Lobby humans the last roster showed, peer id -> { name, slot }. Empty until this peer
## holds a slot, so a joiner is not told about everyone already there.
var _lobby_humans := {}
## The join announcement the host's "everyone is here" line carries with it.
var _join_line := ""
## While the title cards play: `show_message` lines wait here for the standoff.
var _holding_messages := false
var _held_messages: PackedStringArray = []
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
	for key in WORLD_GLOBALS:
		RenderingServer.global_shader_parameter_set(key, float(tuning[key]))

	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.roster_changed.connect(_sync_lobby_avatars)
	NetworkManager.roster_changed.connect(_announce_roster_changes)
	NetworkManager.pose_received.connect(_on_pose_received)
	NetworkManager.shot_received.connect(_on_shot_received)
	NetworkManager.npc_pose_received.connect(_on_npc_pose_received)
	NetworkManager.npc_shot_received.connect(_on_npc_shot_received)
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
	if not is_vr:
		_show_menu_backdrop_camera()
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
	_begin_ai_duel(scenario_index, current_lineup, 1.0, duel.intro_enabled())


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
			var restarting := not in_mp_lobby()
			if NetworkManager.host_start() and restarting:
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


## Called by the gauntlet controller for each rung of the ladder. `play_intro` for a new
## rung; a retry after a loss and Reset Duel go straight to the standoff.
func begin_gauntlet_encounter(encounter: DuelEncounter, play_intro := false) -> void:
	_begin_ai_duel(encounter.scenario_index, encounter.lineup(), encounter.health_mult, play_intro)


## `play_intro`: the title cards first (a free duel from the menu, a new gauntlet rung).
## Their messages wait for the standoff.
func _begin_ai_duel(scenario_index: int, lineup: Array[AIArchetype], health_mult: float,
		play_intro := false) -> void:
	if play_intro:
		hold_messages()
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
	duel.start_ai_duel(current_ais, text if lineup.size() >= 2 else "", true, play_intro)


## Spawns `lineup` on `spawns` (actor ids, tint shades for repeated archetypes,
## current_ais). Shared by the free duel / gauntlet path, Horde's wave spawner, and a
## lobby host's NPC slots. `actor_ids` gives each NPC its id (its lobby slot); empty is
## single player, where NPC i is actor i + 1.
func _spawn_npcs(lineup: Array[AIArchetype], spawns: Array[Transform3D],
		health_mult: float, speed_mult: float, actor_ids: Array[int] = []) -> void:
	var copies := {}
	for slot in lineup.size():
		var ai: DuelistAI = load(AI_SCENE).instantiate()
		ai.actor_id = actor_ids[slot] if slot < actor_ids.size() else slot + 1
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


## The node this machine shows for a ReplayBuffer actor id, or null. Multiplayer: the
## local player for its own lobby slot; for any other, that slot's avatar (a human, or a
## client's NPC proxy), else the NPC the host runs in it. Single player: the player (0)
## or NPC i (i + 1).
func actor_node(actor_id: int) -> Node3D:
	if NetworkManager.is_active():
		if actor_id == local_actor_id():
			return local_player
		var avatar: RemoteAvatar = avatars.get(actor_id)
		if is_instance_valid(avatar):
			return avatar
		for ai in current_ais:
			if is_instance_valid(ai) and ai.actor_id == actor_id:
				return ai
		return null
	if actor_id == 0:
		return local_player
	if actor_id >= 1 and actor_id <= current_ais.size() and is_instance_valid(current_ais[actor_id - 1]):
		return current_ais[actor_id - 1]
	return null


## The local player's ReplayBuffer actor id (and shooter id): its lobby slot in
## multiplayer, 0 in single player.
func local_actor_id() -> int:
	return maxi(_mp_roster().local_slot(), 0) if NetworkManager.is_active() else 0


## The side `node` fights on, or -1 for a node that is no duelist. Multiplayer: its
## slot's `LobbyRoster.side_of`. Single player: its own actor id (everyone for themselves).
func side_of(node: Node) -> int:
	var actor_id := -1
	if node == local_player:
		actor_id = local_actor_id()
	elif node is RemoteAvatar:
		actor_id = (node as RemoteAvatar).slot
	elif node is DuelistAI:
		actor_id = (node as DuelistAI).actor_id
	if actor_id < 0 or not NetworkManager.is_active():
		return actor_id
	var roster := _mp_roster()
	return roster.side_of(actor_id) if actor_id < roster.slots.size() else -1


## What an NPC may aim at: the local player (if alive), every NPC still standing, and on
## a lobby host every other human still in the duel.
func live_duelists() -> Array[Node3D]:
	var live: Array[Node3D] = []
	if is_instance_valid(local_player) and local_player.alive:
		live.append(local_player)
	for ai in current_ais:
		if is_instance_valid(ai) and ai.is_alive():
			live.append(ai)
	for slot: int in avatars:
		var avatar: RemoteAvatar = avatars[slot]
		if is_instance_valid(avatar) and not avatar.npc_proxy and duel.slot_alive(slot):
			live.append(avatar)
	return live


## `index` into ARCHETYPES, clamped.
func archetype_at(index: int) -> AIArchetype:
	return load(ARCHETYPES[clampi(index, 0, ARCHETYPES.size() - 1)])


# -- Multiplayer flow ---------------------------------------------------------

func _on_session_started(as_host: bool) -> void:
	if is_instance_valid(hud):
		hud.close_pause()
	_bump_action_generation()
	_set_mode(GameMode.MULTIPLAYER)
	_mp_room = false
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
		duel.host_open_lobby()
	else:
		show_message(tr("MSG_CONNECTED"))


## Host: the joiner has a slot. Send it to the waiting room; the duel waits for START.
func _on_peer_joined(peer_id: int) -> void:
	if not NetworkManager.is_host() or mode != GameMode.MULTIPLAYER:
		return
	duel.host_open_lobby(peer_id)
	if NetworkManager.roster.can_start():
		var ready_line := tr("MSG_LOBBY_READY")
		show_message(ready_line if _join_line.is_empty() else _join_line + "\n" + ready_line, 8.0)


## Host: a peer that held a slot is gone. Mid-duel it counts as dead (`_mp_down`); in
## the waiting room the roster sync that follows just removes its avatar.
func _on_peer_left(peer_id: int) -> void:
	if mode == GameMode.MULTIPLAYER:
		duel.host_peer_left(peer_id)


func _on_session_ended(reason: String) -> void:
	drop_held_messages()
	_lobby_humans.clear()
	_join_line = ""
	if is_instance_valid(local_player):
		local_player.set_body_tint(Player.BODY_TINT)
	if mode == GameMode.MULTIPLAYER:
		show_message(tr("MSG_SESSION_ENDED") % reason)
		go_to_menu()


## True in the multiplayer waiting room: the arena is loaded and no duel runs.
func in_mp_lobby() -> bool:
	return mode == GameMode.MULTIPLAYER and _mp_room and duel.state == DuelManager.State.IDLE


## Host: start or restart the duel for everyone. `NetworkManager.host_start()` is the
## gate; nothing else calls this.
func begin_mp_duel() -> void:
	_bump_action_generation()
	TimeManager.reset()
	duel.host_start_mp_duel(NetworkManager.roster.scenario_index)


## Called by DuelManager on every peer entering the waiting room.
func setup_mp_lobby(scenario_index: int, time_of_day: float) -> void:
	# Drops a rematch still waiting on its timer.
	_bump_action_generation()
	KillCam.cancel()
	TimeManager.reset()
	_clear_combatants()
	_load_scenario(scenario_index, time_of_day)
	var roster := NetworkManager.roster
	_place_local_player(_mp_spawns(roster, true).get(roster.local_slot(), current_scenario.get_player_spawn()))
	_lobby_ring = roster.slots.size()
	_mp_room = true
	_sync_lobby_avatars()
	if not NetworkManager.is_host():
		# A rematch that could not start falls back here: say why, as the host's message does.
		var refusal := NetworkManager.roster_refusal()
		show_message(tr(refusal if not refusal.is_empty() else "MSG_LOBBY_WAIT_HOST"), 8.0)


## The roster the arena is built from: the running duel's snapshot, else the live roster
## (the waiting room).
func _mp_roster() -> LobbyRoster:
	return duel.snapshot if duel.snapshot != null else NetworkManager.roster


## Slot -> spawn on the loaded arena for a duel on `roster` (the title-card cameras).
func slot_spawns(roster: LobbyRoster) -> Dictionary:
	return _mp_spawns(roster)


## Slot -> spawn on the loaded arena. A duel hands the ring points (`get_duel_spawns`) out
## in `roster.spawn_order()`: slot order in free-for-all, so two slots stand on PlayerSpawn
## / EnemySpawn; in Teams the smaller side first, teammates on neighbouring points. The
## waiting room (`in_room`) is always slot order, so a side pick there never leaves two
## players on one point.
func _mp_spawns(roster: LobbyRoster, in_room := false) -> Dictionary:
	var spawns := current_scenario.get_duel_spawns(roster.slots.size())
	var order := roster.spawn_order()
	var by_slot := {}
	for point in order.size():
		by_slot[point if in_room else order[point]] = spawns[point]
	return by_slot


## Lobby body colours, the same for one actor on every peer (`LobbyRoster.tint_of`: per
## side in Teams, per slot in free-for-all): the local body, every avatar and NPC proxy,
## and the host's NPCs, whose archetype colour is single-player only. Read from the duel's
## snapshot while one runs, else from the live roster (the waiting room).
func _apply_lobby_tints() -> void:
	var roster := _mp_roster()
	var local := roster.local_slot()
	if local >= 0 and is_instance_valid(local_player):
		local_player.set_body_tint(roster.tint_of(local))
	for slot: int in avatars:
		var avatar: RemoteAvatar = avatars[slot]
		if is_instance_valid(avatar) and slot < roster.slots.size():
			avatar.set_tint(roster.tint_of(slot))
	for ai in current_ais:
		if is_instance_valid(ai) and ai.actor_id < roster.slots.size():
			ai.set_tint(roster.tint_of(ai.actor_id))


## Tells this peer who joined or left the waiting room, from the roster alone. A kick in the
## waiting room reads as a leave here; one in the rematch gap (when a leaver becomes an NPC
## instead) reads as a removal. A leaver mid-duel is named by `DuelManager._mp_down`.
func _announce_roster_changes() -> void:
	var roster := NetworkManager.roster
	if not NetworkManager.is_active() or roster.local_slot() < 0:
		return
	var humans := {}
	for slot in roster.slots.size():
		if roster.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN:
			humans[int(roster.slots[slot]["peer_id"])] = {"name": str(roster.slots[slot]["name"]), "slot": slot}
	var before := _lobby_humans
	_lobby_humans = humans
	if before.is_empty():
		return
	var joined := PackedStringArray()
	var gone := PackedStringArray()
	for peer_id: int in humans:
		if not before.has(peer_id):
			joined.append(tr("MSG_LOBBY_JOINED") % humans[peer_id]["name"])
	var key := "MSG_LOBBY_REMOVED" if duel.state == DuelManager.State.RESOLUTION else "MSG_LOBBY_LEFT"
	for peer_id: int in before:
		var slot: int = before[peer_id]["slot"]
		if not humans.has(peer_id) and slot < roster.slots.size() \
				and roster.slots[slot]["kind"] == LobbyRoster.Kind.OPEN:
			gone.append(tr(key) % before[peer_id]["name"])
	_join_line = "\n".join(joined)
	var lines := joined + gone
	if not lines.is_empty():
		show_message("\n".join(lines), 3.0)


## Waiting room: one avatar per other human, each on its own slot's spawn, and every
## body in its roster colour, kept in step with the live roster (a side pick or a mode
## change recolours at once). A duel builds its own from the snapshot in `setup_mp_duel`.
func _sync_lobby_avatars() -> void:
	if not in_mp_lobby():
		return
	var roster := NetworkManager.roster
	var local := roster.local_slot()
	var spawns := _mp_spawns(roster, true)
	# Another slot count is another ring: everyone goes to their slot's point on it.
	if roster.slots.size() != _lobby_ring:
		_lobby_ring = roster.slots.size()
		if local >= 0:
			_place_local_player(spawns[local])
		for slot: int in avatars.keys():
			free_avatar(slot)
	for slot: int in avatars.keys():
		if slot == local or slot >= roster.slots.size() or roster.slots[slot]["kind"] != LobbyRoster.Kind.HUMAN:
			free_avatar(slot)
	for slot in roster.slots.size():
		if slot != local and roster.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN and not avatars.has(slot):
			_spawn_avatar(slot, spawns[slot])
	_apply_lobby_tints()
	_bind_voice()


## Called by DuelManager on every peer when an MP duel begins: the local player and an
## avatar for every other human, each on its slot's ring point. An NPC slot is a
## `DuelistAI` on the host, which runs it, and a proxy avatar on a client. Any of them may
## be the one on PlayerSpawn (`_mp_spawns`). `time_of_day` is the host's roll so every
## peer shares one sky.
func setup_mp_duel(scenario_index: int, time_of_day: float) -> void:
	_clear_combatants()
	_load_scenario(scenario_index, time_of_day)
	var roster := duel.snapshot
	var local := roster.local_slot()
	var spawns := _mp_spawns(roster)
	var npc_lineup: Array[AIArchetype] = []
	var npc_spawns: Array[Transform3D] = []
	var npc_slots: Array[int] = []
	for slot in roster.slots.size():
		var kind: int = roster.slots[slot]["kind"]
		if slot == local:
			_place_local_player(spawns[slot])
		elif kind == LobbyRoster.Kind.HUMAN:
			_spawn_avatar(slot, spawns[slot])
		elif kind == LobbyRoster.Kind.NPC and not NetworkManager.is_host():
			_spawn_avatar(slot, spawns[slot], true)
		elif kind == LobbyRoster.Kind.NPC:
			npc_lineup.append(archetype_at(roster.slots[slot]["archetype"]))
			npc_spawns.append(spawns[slot])
			npc_slots.append(slot)
	_spawn_npcs(npc_lineup, npc_spawns, 1.0, 1.0, npc_slots)
	_apply_lobby_tints()
	_bind_voice()


func _spawn_avatar(slot: int, spawn: Transform3D, npc_proxy := false) -> RemoteAvatar:
	free_avatar(slot)
	var avatar: RemoteAvatar = load(AVATAR_SCENE).instantiate()
	avatar.slot = slot
	avatar.npc_proxy = npc_proxy
	# Placed before it enters the tree: its `_ready` takes the rest pose from here.
	avatar.transform = world_root.global_transform.affine_inverse() * spawn
	world_root.add_child(avatar)
	avatars[slot] = avatar
	return avatar


## Removes one slot's avatar (a leaver).
func free_avatar(slot: int) -> void:
	var avatar: RemoteAvatar = avatars.get(slot)
	avatars.erase(slot)
	if is_instance_valid(avatar):
		avatar.queue_free()
	_bind_voice()


func _despawn_avatars() -> void:
	for avatar: RemoteAvatar in avatars.values():
		if is_instance_valid(avatar):
			avatar.queue_free()
	avatars.clear()
	_bind_voice()


## Brings `VoiceChat` in step with `avatars`: each human's avatar plays that human's voice,
## and a gone avatar lets go of its sender. A bound avatar is left alone (rebinding
## restarts the stream). An NPC proxy has no voice.
func _bind_voice() -> void:
	var roster := _mp_roster()
	var wanted := {}
	for slot: int in avatars:
		var avatar: RemoteAvatar = avatars[slot]
		if is_instance_valid(avatar) and not avatar.npc_proxy and slot < roster.slots.size() \
				and roster.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN:
			wanted[int(roster.slots[slot]["peer_id"])] = avatar.voice_player
	for peer_id in VoiceChat.bound_peers():
		if wanted.get(peer_id) != VoiceChat.bound_player(peer_id):
			VoiceChat.bind_voice_player(peer_id, null)
	for peer_id: int in wanted:
		if VoiceChat.bound_player(peer_id) != wanted[peer_id]:
			VoiceChat.bind_voice_player(peer_id, wanted[peer_id])


## The avatar standing for `peer_id`, or null: an unknown sender, or one with no avatar here.
func avatar_of_peer(peer_id: int) -> RemoteAvatar:
	var avatar: RemoteAvatar = avatars.get(_mp_roster().slot_of_peer(peer_id))
	return avatar if is_instance_valid(avatar) else null


func _on_pose_received(peer_id: int, head: Transform3D, left: Transform3D,
		right: Transform3D, flags: int, gun: Transform3D, hands: int, objects: int,
		prop: Transform3D, round_xf: Transform3D) -> void:
	var avatar := avatar_of_peer(peer_id)
	if avatar != null and not DeathCam.blocks_remote_pose(avatar.slot):
		avatar.apply_pose(head, left, right, flags, gun, hands, objects, prop, round_xf)


func _on_shot_received(peer_id: int, origin: Vector3, direction: Vector3) -> void:
	# A remote player fired. Everyone spawns the tracer; only the host's simulation is
	# authoritative for damage. The sender's slot is the shooter id; a sender with no
	# slot, or one already out of the duel, fires nothing.
	var slot := _mp_roster().slot_of_peer(peer_id)
	if slot < 0 or (duel.snapshot != null and not duel.slot_alive(slot)):
		return
	var exclude: Array[RID] = []
	var grace: Array[RID] = []
	var avatar: RemoteAvatar = avatars.get(slot)
	if is_instance_valid(avatar):
		exclude = avatar.hitbox_rids()
		grace = avatar.gun_hand_hitbox_rids()
	ReplayBuffer.record_shot(origin, direction, slot)
	Bullet.spawn(main_root, origin, direction, tuning["bullet_speed"],
			NetworkManager.is_host(), exclude, false,
			float(tuning.get("self_hit_grace", 0.28)), grace, slot)


## The proxy standing for the NPC in `slot` of the running duel, or null: a slot that is
## no NPC in the snapshot, or no proxy on this machine (the host runs the NPC itself).
func _npc_proxy(slot: int) -> RemoteAvatar:
	var snapshot := duel.snapshot
	if snapshot == null or slot < 0 or slot >= snapshot.slots.size() \
			or snapshot.slots[slot]["kind"] != LobbyRoster.Kind.NPC:
		return null
	var avatar: RemoteAvatar = avatars.get(slot)
	return avatar if is_instance_valid(avatar) and avatar.npc_proxy else null


func _on_npc_pose_received(slot: int, head: Transform3D, flags: int, gun: Transform3D) -> void:
	var proxy := _npc_proxy(slot)
	if proxy != null and not DeathCam.blocks_remote_pose(slot):
		proxy.apply_npc_pose(head, flags, gun)


func _on_npc_shot_received(slot: int, origin: Vector3, direction: Vector3) -> void:
	# The host's NPC fired: a tracer only, the hit is the host's. A dead NPC fires nothing.
	var proxy := _npc_proxy(slot)
	if proxy == null or not duel.slot_alive(slot):
		return
	Bullet.spawn(main_root, origin, direction,
			archetype_at(duel.snapshot.slots[slot]["archetype"]).bullet_speed,
			false, proxy.hitbox_rids(), false, 0.0, [], slot)


# -- Duel results -------------------------------------------------------------

func _on_duel_finished(local_player_won: bool, reason: String) -> void:
	var headline := tr("MSG_YOU_WIN") if local_player_won else tr("MSG_YOU_LOSE")
	if duel.is_team_duel():
		headline = tr("MSG_SIDE_WON") if local_player_won else tr("MSG_SIDE_LOST")
	var message := "%s\n%s" % [headline, tr(reason)]
	if mode == GameMode.MULTIPLAYER and not local_player_won and not duel.is_team_duel() \
			and duel.snapshot != null and duel.snapshot.slots.size() > 2 and duel.live_slots().size() == 1:
		# Free-for-all of 3-4: the loser is told who took it (the one duelist left standing).
		message += "\n" + tr("MSG_LOBBY_WINNER") % duel.slot_name(duel.live_slots()[0])
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


## Host: the same roster again, or back to the waiting room when it can no longer start.
func _mp_rematch() -> void:
	if mode == GameMode.MULTIPLAYER and not NetworkManager.host_start():
		NetworkManager.host_back_to_lobby()


func _after_delay(seconds: float, callable: Callable) -> void:
	var mode_at_schedule := mode
	var generation_at_schedule := _action_generation
	get_tree().create_timer(seconds, false, false, true).timeout.connect(func() -> void:
		if mode == mode_at_schedule and _action_generation == generation_at_schedule:
			callable.call())


func _bump_action_generation() -> void:
	_action_generation += 1
	drop_held_messages()


func _set_mode(new_mode: int) -> void:
	mode = new_mode
	mode_changed.emit(mode)


# -- Scenario / player helpers -------------------------------------------------

## The t the MP host sends for a fresh load of arena `index`: its fixed time, or a roll.
func roll_time_of_day(index: int) -> float:
	var resource := load(SCENARIOS[clampi(index, 0, SCENARIOS.size() - 1)]) as ScenarioResource
	return resource.roll_time_of_day()


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
	# Negative means this load picks its own time (SP, menu, host waiting): the arena's
	# fixed one, or a roll. MP passes the host's pick so the client does not roll again.
	if time_of_day < 0.0:
		time_of_day = resource.roll_time_of_day()
	current_scenario.time_of_day = time_of_day
	world_root.add_child(current_scenario)


func _place_local_player(spawn: Transform3D) -> void:
	_teardown_menu_backdrop()
	local_player.reset_for_duel(spawn)
	_capture_flat_mouse()


## Flat only: a fixed camera on a random `MenuCameras` marker (falls back to the player
## spawn when the scenario has none authored yet), with the player hidden so no one
## (and no shadow) stands in the shot. Torn down by the next real `_place_local_player`.
func _show_menu_backdrop_camera() -> void:
	var cameras := current_scenario.get_menu_cameras()
	var eye := cameras[randi() % cameras.size()] if not cameras.is_empty() \
			else current_scenario.get_player_spawn()
	_menu_backdrop_camera = Camera3D.new()
	_menu_backdrop_camera.name = "MenuBackdropCamera"
	main_root.add_child(_menu_backdrop_camera)
	_menu_backdrop_camera.global_transform = eye
	_menu_backdrop_camera.current = true
	local_player.set_backdrop_hidden(true)


func _teardown_menu_backdrop() -> void:
	if is_instance_valid(_menu_backdrop_camera):
		_menu_backdrop_camera.current = false
		_menu_backdrop_camera.queue_free()
	_menu_backdrop_camera = null
	if is_instance_valid(local_player):
		local_player.set_backdrop_hidden(false)


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
	_despawn_avatars()
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
	if _holding_messages:
		if not _held_messages.has(text):
			_held_messages.append(text)
		return
	hud.show_message(text, duration)
	if is_vr and is_instance_valid(local_player):
		local_player.show_vr_message(text, duration)


## Title cards ahead: `show_message` keeps its lines for the standoff line
## (`DuelManager._show_standoff_message`) instead of showing them over the cards.
func hold_messages() -> void:
	_holding_messages = true


## The held lines, oldest first; showing resumes.
func take_held_messages() -> PackedStringArray:
	var lines := _held_messages
	drop_held_messages()
	return lines


func drop_held_messages() -> void:
	_holding_messages = false
	_held_messages = PackedStringArray()


# -- Tuning -------------------------------------------------------------------

func set_tuning(key: String, value: Variant) -> void:
	tuning[key] = value
	if WORLD_GLOBALS.has(key):
		RenderingServer.global_shader_parameter_set(key, float(value))
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
