class_name Player
extends Node3D
## The local player: shared body (health, hitboxes, holster, revolver) with a
## swappable rig -- VR (XROrigin3D) or flat (mouse-look test harness).

signal died(trail_points: PackedVector3Array)
signal holstered_changed(holstered: bool)

const VR_RIG := "res://player/vr_rig.tscn"
const FLAT_RIG := "res://player/flat_rig.tscn"
const HOLSTER_GRAB_RADIUS := 0.45
const HOLSTER_HIP := Vector3(0.25, 0.0, 0.05)
const ARM_SHOULDER_LOCAL := Vector3(0.20, 0.22, 0.0)
## Flat rest pose: hanging hand relative to torso center (no tracked controllers).
const ARM_FLAT_HAND_LOCAL := Vector3(0.28, -0.32, 0.04)
const POSE_SEND_HZ := 30.0
const RELOAD_VIZ_NAME := "_ReloadVolumeViz"
const GUN_RECOVER_Y := -5.0
const GUN_RECOVER_DIST := 20.0
const HAND_LEFT := &"left_hand"
const HAND_RIGHT := &"right_hand"
## Practice-hub bottles. VR holds the bottle upright with the fist round its middle.
const BOTTLE_HOLD_VR := Transform3D(Basis.IDENTITY, Vector3(0.0, -0.11, 0.0))
const BOTTLE_GRAB_RADIUS_MIN := 0.2
const BOTTLE_FLAT_REACH := 2.5
const BOTTLE_FLAT_RADIUS := 0.2
const BOTTLE_FLAT_THROW_SPEED := 10.0
const BOTTLE_FLAT_THROW_LIFT := 1.2
const BOTTLE_FLAT_THROW_SPIN := 9.0

enum GunHand { NONE, LEFT, RIGHT }

var use_vr := false
var rig: Node3D
## Off-hand misc props: equip radial + cigarette / coin / ace.
var props: PropController
var health := CombatRules.DEFAULT_HEALTH
var max_health := CombatRules.DEFAULT_HEALTH
var alive := true
var move_speed_mult := 1.0
var killed_by_self := false

@onready var rig_holder: Node3D = $RigHolder
@onready var holster: Node3D = $Holster
@onready var revolver: Revolver = $Holster/Revolver
@onready var head_hitbox: Hitbox = $HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox
@onready var arm_hitbox_l: Hitbox = $ArmHitboxL
@onready var arm_hitbox_r: Hitbox = $ArmHitboxR
@onready var leg_hitbox: Hitbox = $LegHitbox
@onready var ammo_belt: Area3D = $AmmoBelt

var _pose_accum := 0.0
var _menu_panel: UIPanel3D
var _vr_message: Label3D
var _vr_message_timer := 0.0
var _boot_cover: MeshInstance3D
var _boot_label: Label3D
var _holding_hand: int = GunHand.NONE
var _held_cartridge: CartridgePhysical = null
var _reload_event := ""
var _reload_event_timer := 0.0
var _vr_reload_label: Label3D
var _prev_gate_open := false
var _trick_down_hands := {}
var _trick_release_ignored := false
var _dump_armed := true
var _close_armed := true
var _dump_hold_accum := 0.0
var _leg_remaining := 0.0
var _jam_clear_accum := 0.0
var _held_bottle: PracticeBottle
var _held_bottle_hand: StringName = &""
var _replay_latched := false
var _replay_latch: Dictionary = {}
var _replay_body_driven := false
var _replay_travel: Marker3D
var _replay_objects: ReplayObjects
var _dummy: DummyBody
var _wrist_l: Marker3D
var _wrist_r: Marker3D
var _grip_down: Dictionary = {}
var _trigger_down: Dictionary = {}
var _wrist_synced: Dictionary = {}
var _wrist_lock: Dictionary = {}
var _wrist_from_local: Dictionary = {}
var _wrist_blend: Dictionary = {}
var _mesh_lab_parked := false
var _mesh_lab_head_held := false
var _mesh_lab_body_yaw := 0.0
var _mesh_lab_pitch := 0.0
var _mesh_lab_roll := 0.0
var _mesh_lab_hands_held := false
var _mesh_lab_freeze_l: Marker3D
var _mesh_lab_freeze_r: Marker3D
var _mesh_lab_cull_saved := false
var _mesh_lab_cull_mask := 0


func _ready() -> void:
	rig = load(VR_RIG if use_vr else FLAT_RIG).instantiate()
	rig_holder.add_child(rig)
	rig.trigger_changed.connect(_on_trigger_changed)
	rig.grip_changed.connect(_on_grip_changed)
	rig.cock_pressed.connect(_on_cock_pressed)
	rig.menu_button_pressed.connect(_on_menu_button)
	if rig.has_signal("reload_pressed"):
		rig.reload_pressed.connect(_on_reload_pressed)
	if rig.has_signal("gate_pressed"):
		rig.gate_pressed.connect(_on_gate_pressed)
	if rig.has_signal("trick_shot_changed"):
		rig.trick_shot_changed.connect(_on_trick_shot_changed)

	props = PropController.new()
	props.name = "PropController"
	add_child(props)
	props.setup(self)
	if rig.has_signal("prop_radial_changed"):
		rig.prop_radial_changed.connect(_on_prop_radial_changed)
	if rig.has_signal("prop_fire_changed"):
		rig.prop_fire_changed.connect(_on_prop_fire_changed)
	if rig.has_signal("interact_pressed"):
		rig.interact_pressed.connect(_on_interact_pressed)

	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	arm_hitbox_l.owner_entity = self
	arm_hitbox_r.owner_entity = self
	leg_hitbox.owner_entity = self
	revolver.fired.connect(_on_revolver_fired)
	revolver.shells_ejected.connect(_on_shells_ejected)
	revolver.state_changed.connect(_on_revolver_state_changed)
	revolver.dry_fired.connect(_on_revolver_dry_fired)
	_prev_gate_open = revolver.gate_open
	ammo_belt.visible = use_vr
	revolver.jam_enabled = not use_vr
	revolver.holster_to(holster)
	_holding_hand = GunHand.NONE
	_refresh_reload_status()
	set_reload_volume_debug(DebugMenu.show_reload_volumes)
	_dummy = DummyBody.spawn(self)
	_dummy.follow_travel(rig)
	_dummy.set_tint(Color(0.62, 0.60, 0.58))
	_wrist_l = _make_wrist_marker("WristL")
	_wrist_r = _make_wrist_marker("WristR")
	# After the mannequin's 180° yaw, +X is the right arm.
	_dummy.drive_arm(false, _wrist_l, true, DummyBody.WRIST_INSET)
	_dummy.drive_arm(true, _wrist_r, true, DummyBody.WRIST_INSET)
	_dummy.set_head_hidden(true)
	_dummy.set_first_person_clip(true)
	if use_vr:
		_dummy.set_body_shelved(true)
		_dummy.set_hand_scale(DummyBody.VR_HAND_SCALE)
		_hide_vr_hand_boxes()
	var drive := WristDrive.new()
	drive.host = self
	drive.process_priority = DummyBody.WRIST_PRIORITY
	add_child(drive)


func _physics_process(delta: float) -> void:
	_follow_body()
	_recover_free_gun()
	_update_vr_reload(delta)
	_update_wound_status(delta)
	_update_jam_clear(delta)
	_update_held_bottle()


func _process(delta: float) -> void:
	_broadcast_pose(delta)
	_update_vr_message(delta)
	_update_reload_event(delta)


# -- Body / hitboxes ------------------------------------------------------------

func _follow_body() -> void:
	var head: Transform3D = rig.get_head_transform()
	var yaw := Basis(Vector3.UP, head.basis.get_euler().y)

	head_hitbox.global_transform = Transform3D(yaw, head.origin)
	# Floor offsets. VR standing height moves the XR origin so the headset
	# lines up with these; the capsules do not follow the live head Y.
	var torso_pos := Vector3(head.origin.x, global_position.y + 1.1, head.origin.z)
	torso_hitbox.global_transform = Transform3D(yaw, torso_pos)

	var left_shoulder := torso_pos + yaw * Vector3(-ARM_SHOULDER_LOCAL.x, ARM_SHOULDER_LOCAL.y, 0.0)
	var right_shoulder := torso_pos + yaw * Vector3(ARM_SHOULDER_LOCAL.x, ARM_SHOULDER_LOCAL.y, 0.0)
	var left_hand := torso_pos + yaw * Vector3(
		-ARM_FLAT_HAND_LOCAL.x, ARM_FLAT_HAND_LOCAL.y, ARM_FLAT_HAND_LOCAL.z)
	var right_hand := torso_pos + yaw * ARM_FLAT_HAND_LOCAL
	if use_vr:
		left_hand = rig.get_left_hand_transform().origin
		right_hand = rig.get_right_hand_transform().origin
	var gun_hand := held_gun_hand()
	arm_hitbox_l.place_along_limb(left_shoulder, left_hand,
			Hitbox.ARM_GUN_HAND_WRIST_INSET if gun_hand == HAND_LEFT else Hitbox.ARM_WRIST_INSET,
			Hitbox.ARM_GUN_HAND_RADIUS_SCALE if gun_hand == HAND_LEFT else Hitbox.ARM_RADIUS_SCALE)
	arm_hitbox_r.place_along_limb(right_shoulder, right_hand,
			Hitbox.ARM_GUN_HAND_WRIST_INSET if gun_hand == HAND_RIGHT else Hitbox.ARM_WRIST_INSET,
			Hitbox.ARM_GUN_HAND_RADIUS_SCALE if gun_hand == HAND_RIGHT else Hitbox.ARM_RADIUS_SCALE)
	leg_hitbox.global_transform = Transform3D(
		yaw, Vector3(head.origin.x, global_position.y + 0.4, head.origin.z))

	# Alive: the mannequin stands under the head. Death freezes that pose for the orbit.
	if _dummy != null and alive:
		var body_yaw := PI + wrapf(head.basis.get_euler().y - global_rotation.y, -PI, PI)
		var look_pitch := DummyBody.pitch_from_basis(head.basis)
		if use_vr:
			var look_roll := DummyBody.roll_from_basis(head.basis)
			if GameManager.in_mesh_lab() and not MeshLabMotion.head:
				if not _mesh_lab_head_held:
					_mesh_lab_head_held = true
					_mesh_lab_body_yaw = body_yaw
					_mesh_lab_pitch = look_pitch
					_mesh_lab_roll = look_roll
				body_yaw = _mesh_lab_body_yaw
				look_pitch = _mesh_lab_pitch
				look_roll = _mesh_lab_roll
			else:
				_mesh_lab_head_held = false
			_dummy.place_toward_head(
				head.origin, body_yaw, look_pitch, rig.global_position, look_roll)
		else:
			_dummy.place_on_floor(head.origin, body_yaw)
			_dummy.drive_look(look_pitch)

	# Holster rides the chosen hip, following the head's yaw.
	var hip := HOLSTER_HIP
	if int(GameManager.tuning["holster_side"]) != 0:
		hip.x = -hip.x
	holster.global_transform = Transform3D(
		yaw,
		Vector3(head.origin.x, global_position.y + 1.0, head.origin.z) + yaw * hip)

	# Ammo belt around the waist / lower torso.
	ammo_belt.global_transform = Transform3D(yaw, torso_pos)


func _make_wrist_marker(marker_name: String) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	add_child(marker)
	return marker


func _hide_vr_hand_boxes() -> void:
	for path in ["LeftHand/HandMesh", "RightHand/HandMesh"]:
		var box: MeshInstance3D = rig.get_node_or_null(path) as MeshInstance3D
		if box != null:
			box.visible = false


## Runs after the camera and the revolver, before arm IK.
func drive_wrists_late(delta: float) -> void:
	if _dummy == null or not alive or rig == null:
		return
	var head: Transform3D = rig.get_head_transform()
	var yaw := Basis(Vector3.UP, head.basis.get_euler().y)
	var torso_pos := Vector3(head.origin.x, global_position.y + 1.1, head.origin.z)
	if use_vr and rig is VRRig:
		var vr := rig as VRRig
		if GameManager.in_mesh_lab() and not MeshLabMotion.hands:
			_drive_frozen_wrists(vr)
			return
		_mesh_lab_hands_held = false
		_drive_vr_wrist(HAND_LEFT, vr, delta)
		_drive_vr_wrist(HAND_RIGHT, vr, delta)
		return
	var left_hang := torso_pos + yaw * Vector3(
			-ARM_FLAT_HAND_LOCAL.x, ARM_FLAT_HAND_LOCAL.y, ARM_FLAT_HAND_LOCAL.z)
	var right_hang := torso_pos + yaw * ARM_FLAT_HAND_LOCAL
	_drive_flat_wrist(HAND_LEFT, left_hang, yaw, delta)
	_drive_flat_wrist(HAND_RIGHT, right_hang, yaw, delta)


func _drive_frozen_wrists(vr: VRRig) -> void:
	# Parent to the mannequin so a frozen pose stays on the body while the
	# playspace walks. The player root itself does not move with the stick.
	if _mesh_lab_freeze_l == null:
		_mesh_lab_freeze_l = Marker3D.new()
		_mesh_lab_freeze_l.name = "MeshLabFreezeL"
		_mesh_lab_freeze_r = Marker3D.new()
		_mesh_lab_freeze_r.name = "MeshLabFreezeR"
		_dummy.add_child(_mesh_lab_freeze_l)
		_dummy.add_child(_mesh_lab_freeze_r)
	if not _mesh_lab_hands_held:
		_mesh_lab_hands_held = true
		_mesh_lab_freeze_l.global_transform = _mesh_lab_hand_source(HAND_LEFT, vr).global_transform
		_mesh_lab_freeze_r.global_transform = _mesh_lab_hand_source(HAND_RIGHT, vr).global_transform
	_dummy.set_arm_target(false, _mesh_lab_freeze_l, true, DummyBody.WRIST_INSET, Vector3.ZERO)
	_dummy.set_arm_target(true, _mesh_lab_freeze_r, true, DummyBody.WRIST_INSET, Vector3.ZERO)


func _mesh_lab_hand_source(hand_name: StringName, vr: VRRig) -> Node3D:
	if held_gun_hand() == hand_name and revolver != null and not revolver.is_spin_active():
		return revolver
	return vr.get_hand_node(hand_name)


## Flat mesh lab parks this body so the fly camera owns WASD and the view.
func set_mesh_lab_parked(parked: bool) -> void:
	if parked == _mesh_lab_parked:
		return
	_mesh_lab_parked = parked
	visible = not parked
	process_mode = Node.PROCESS_MODE_DISABLED if parked else Node.PROCESS_MODE_INHERIT
	if rig is FlatRig:
		(rig as FlatRig).camera.current = not parked


## VR mesh lab: the desktop camera sees the full mannequin. The headset does not.
func set_mesh_lab_preview(enabled: bool) -> void:
	if _dummy == null:
		return
	_mesh_lab_head_held = false
	_mesh_lab_hands_held = false
	if enabled:
		_dummy.set_body_shelved(false)
		_dummy.set_head_hidden(false)
		_dummy.set_first_person_clip(false)
		_dummy.set_body_render_layers(DummyBody.SPECTATOR_BODY_LAYER)
		if rig is VRRig:
			var cam := (rig as VRRig).camera
			if not _mesh_lab_cull_saved:
				_mesh_lab_cull_mask = cam.cull_mask
				_mesh_lab_cull_saved = true
			cam.cull_mask = _mesh_lab_cull_mask & ~DummyBody.SPECTATOR_BODY_LAYER
		return
	_dummy.set_body_render_layers(1)
	if rig is VRRig and _mesh_lab_cull_saved:
		(rig as VRRig).camera.cull_mask = _mesh_lab_cull_mask
	_mesh_lab_cull_saved = false
	_dummy.set_head_hidden(true)
	_dummy.set_body_shelved(use_vr)
	_dummy.set_first_person_clip(true)


func _drive_vr_wrist(hand_name: StringName, vr: VRRig, delta: float) -> void:
	var positive_x := hand_name == HAND_RIGHT
	var curl := _hand_curl(hand_name)
	var anchor: Node3D = curl["anchor"]
	var goal := vr.get_hand_node(hand_name).global_transform
	if anchor != null:
		goal = anchor.global_transform
	_place_wrist(hand_name, goal, delta, _wrist_lock_id(anchor))
	_dummy.set_arm_target(positive_x, _wrist_marker(hand_name), true, DummyBody.WRIST_INSET)
	_dummy.set_hand_curl(positive_x, int(curl["pose"]), float(curl["trigger"]))


func _drive_flat_wrist(hand_name: StringName, hang_pos: Vector3, yaw: Basis, delta: float) -> void:
	var positive_x := hand_name == HAND_RIGHT
	var curl := _hand_curl(hand_name)
	var anchor: Node3D = curl["anchor"]
	var twist := false
	var inset := 0.0
	var goal := Transform3D(yaw, hang_pos)
	if anchor != null:
		goal = anchor.global_transform
		twist = true
		inset = DummyBody.WRIST_INSET
	_place_wrist(hand_name, goal, delta, _wrist_lock_id(anchor))
	_dummy.set_arm_target(positive_x, _wrist_marker(hand_name), twist, inset)
	_dummy.set_hand_curl(positive_x, int(curl["pose"]), float(curl["trigger"]))


func _wrist_marker(hand_name: StringName) -> Marker3D:
	return _wrist_r if hand_name == HAND_RIGHT else _wrist_l


func _wrist_lock_id(anchor: Node3D) -> String:
	return str(anchor.get_instance_id()) if anchor != null else "hang"


## Ease only when the hold changes. After that the marker copies the goal, so
## walking and looking do not leave the hand trailing the object.
func _place_wrist(hand_name: StringName, goal: Transform3D, delta: float, lock_id: String) -> void:
	var marker := _wrist_marker(hand_name)
	var prev := str(_wrist_lock.get(hand_name, ""))
	if prev != lock_id or not _wrist_synced.get(hand_name, false):
		var current := marker.global_transform if _wrist_synced.get(hand_name, false) else goal
		_wrist_from_local[hand_name] = global_transform.affine_inverse() * current
		_wrist_blend[hand_name] = 0.0
		_wrist_lock[hand_name] = lock_id
		_wrist_synced[hand_name] = true
	var t := float(_wrist_blend.get(hand_name, 1.0))
	if t >= 1.0:
		marker.global_transform = goal
		return
	t = minf(1.0, t + delta / DummyBody.WRIST_BLEND_SEC)
	_wrist_blend[hand_name] = t
	var start: Transform3D = global_transform * (_wrist_from_local[hand_name] as Transform3D)
	marker.global_transform = start.interpolate_with(goal, t)


## VR closes while the grab button is down. Flat closes once something is in that hand.
func _hand_curl(hand_name: StringName) -> Dictionary:
	var held := _held_curl(hand_name)
	var pose := HandFingers.Pose.OPEN
	var anchor: Node3D = null
	if use_vr:
		if _grip_down.get(hand_name, false):
			if held.is_empty():
				pose = HandFingers.Pose.FIST
			else:
				pose = int(held["pose"])
				anchor = held["anchor"]
	elif not held.is_empty():
		pose = int(held["pose"])
		anchor = held["anchor"]
	var trigger := 0.0
	if pose == HandFingers.Pose.PISTOL:
		trigger = _trigger_pull(hand_name)
	return {"pose": pose, "trigger": trigger, "anchor": anchor}


func _held_curl(hand_name: StringName) -> Dictionary:
	if revolver != null and revolver.held and _holding_hand_name() == hand_name:
		var anchor: Node3D = null
		if not revolver.is_spin_active():
			anchor = _grip_anchor(revolver)
		return {"pose": HandFingers.Pose.PISTOL, "anchor": anchor}
	if _holding_bottle() and hand_name == _held_bottle_hand:
		return {"pose": HandFingers.Pose.BOTTLE, "anchor": _grip_anchor(_held_bottle)}
	if _holding_cartridge() and hand_name == off_hand_name():
		return {"pose": HandFingers.Pose.PINCH, "anchor": _grip_anchor(_held_cartridge)}
	if props != null and props.is_prop_in_hand() and hand_name == off_hand_name():
		var pose := HandFingers.Pose.PINCH
		if props.equipped_item() == PropController.ITEM_BOTTLE:
			pose = HandFingers.Pose.BOTTLE
		return {"pose": pose, "anchor": _grip_anchor(props.current_prop())}
	return {}


func _grip_anchor(node: Node) -> Node3D:
	if node == null:
		return null
	var anchor := node.find_child("GripAnchor", true, false) as Node3D
	return anchor if anchor != null else node as Node3D


func _trigger_pull(hand_name: StringName) -> float:
	if use_vr and rig is VRRig and PlayerSettings.get_vr_bind(&"fire") == "trigger_click":
		return (rig as VRRig).trigger_amount(hand_name)
	return 1.0 if _trigger_down.get(hand_name, false) else 0.0


func _packed_hands() -> int:
	var left := _hand_curl(HAND_LEFT)
	var right := _hand_curl(HAND_RIGHT)
	return HandFingers.pack(int(left["pose"]), int(right["pose"]), float(left["trigger"]), float(right["trigger"]))


func get_head_position() -> Vector3:
	return rig.get_head_transform().origin


func headset_height_ready() -> bool:
	return use_vr and rig is VRRig and (rig as VRRig).headset_height_ready()


func measured_eye_height_m() -> float:
	if not use_vr or not rig is VRRig:
		return 0.0
	return (rig as VRRig).measured_eye_height_m()


func apply_saved_eye_height() -> void:
	if use_vr and rig is VRRig:
		(rig as VRRig).apply_saved_eye_height()


func is_gun_drawn() -> bool:
	return revolver.drawn


func held_gun_hand() -> StringName:
	if revolver != null and revolver.held and _holding_hand != GunHand.NONE:
		return _holding_hand_name()
	return &""


func hitbox_rids() -> Array[RID]:
	return [
		head_hitbox.get_rid(),
		torso_hitbox.get_rid(),
		arm_hitbox_l.get_rid(),
		arm_hitbox_r.get_rid(),
		leg_hitbox.get_rid(),
	]


func gun_hand_hitbox_rids() -> Array[RID]:
	match held_gun_hand():
		HAND_LEFT:
			return [arm_hitbox_l.get_rid()]
		HAND_RIGHT:
			return [arm_hitbox_r.get_rid()]
		_:
			return [arm_hitbox_l.get_rid(), arm_hitbox_r.get_rid()]


# -- Duel lifecycle ---------------------------------------------------------------

func reset_for_duel(spawn: Transform3D) -> void:
	global_transform = spawn
	max_health = CombatRules.player_max_health()
	health = max_health
	alive = true
	killed_by_self = false
	_replay_body_driven = false
	_end_replay_loadout()
	if _dummy != null:
		_dummy.follow_travel(rig)
		_dummy.set_pose_driven(true)
		_dummy.set_head_hidden(true)
		_dummy.set_body_shelved(use_vr)
		_dummy.set_first_person_clip(true)
	_replay_latched = false
	move_speed_mult = 1.0
	_leg_remaining = 0.0
	_clear_held_cartridge(true)
	_release_held_bottle()
	props.reset_for_duel()
	_holster_gun()
	revolver.reset()
	_refresh_health_hud()
	_dump_armed = true
	_close_armed = true
	_dump_hold_accum = 0.0
	_jam_clear_accum = 0.0
	_reload_event = ""
	_reload_event_timer = 0.0
	_prev_gate_open = revolver.gate_open
	_refresh_reload_status()
	if rig is FlatRig:
		# World yaw: FlatRig subtracts the Player root's spawn rotation so the
		# joiner is not spun 180° twice (BUG-004).
		(rig as FlatRig).face_yaw(spawn.basis.get_euler().y)
		rig.position = Vector3.ZERO
	elif rig is VRRig:
		(rig as VRRig).reset_locomotion()


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO, self_inflicted := false,
		shooter_is_local := false) -> void:
	if not alive or GameManager.in_practice():
		return
	if NetworkManager.is_active():
		# MP: host resolves HP/status; application arrives via _mp_wound / _mp_finish.
		if NetworkManager.is_host():
			GameManager.duel.mp_report_hit(true, trail_points, region, damage_mult, shooter_is_local)
		return
	var result := CombatRules.resolve(region, health, damage_mult)
	health = result["health"]
	_refresh_health_hud()
	if result["died"]:
		killed_by_self = self_inflicted
		play_death_feedback()
		died.emit(trail_points)
		return
	_apply_nonfatal(region)


## Host/client wound RPC: set HP and apply arm/leg status without re-resolving.
func apply_wound(region: StringName, new_health: float) -> void:
	if not alive:
		return
	health = new_health
	_refresh_health_hud()
	_apply_nonfatal(region)


func play_death_feedback() -> void:
	alive = false
	if _dummy != null:
		_dummy.set_pose_driven(false)
		_dummy.set_body_shelved(false)
		_dummy.set_head_hidden(false)
		_dummy.set_first_person_clip(false)
	move_speed_mult = 1.0
	_leg_remaining = 0.0
	ImpactFeedback.player_hurt(true)
	GameManager.hud.flash_red()
	_refresh_health_hud()


# -- Gun handling -----------------------------------------------------------------

func _on_grip_changed(hand: StringName, pressed: bool) -> void:
	if use_vr:
		_grip_down[hand] = pressed
	if _combat_blocked():
		return
	if not use_vr:
		if pressed:
			_toggle_gun()
		return
	if pressed:
		_on_vr_grip_press(hand)
	else:
		_on_vr_grip_release(hand)


func _on_vr_grip_press(hand: StringName) -> void:
	if not alive:
		return
	if revolver.held and _holding_hand_name() == hand:
		return
	var near_gun := _hand_near_gun(hand)
	var near_holster := _hand_near_holster(hand)
	if revolver.drawn and near_gun:
		if _holding_cartridge() and rig is VRRig:
			var attach := (rig as VRRig).get_cartridge_attach(hand)
			if _held_cartridge.get_parent() == attach:
				_drop_held_cartridge()
		_attach_gun_to_hand(hand)
		return
	if not revolver.drawn and near_holster:
		_attach_gun_to_hand(hand)
		return
	if _try_pick_prop_vr(hand):
		return
	if _try_grab_bottle_vr(hand):
		return
	if revolver.held:
		_try_grab_from_belt()


func _on_vr_grip_release(hand: StringName) -> void:
	if _holding_bottle() and hand == _held_bottle_hand:
		_throw_held_bottle()
		return
	if revolver.held and _holding_hand_name() == hand:
		var speed := 0.0
		if rig is VRRig:
			speed = (rig as VRRig).hand_speed(hand)
		var max_speed := float(GameManager.tuning["gun_holster_max_speed"])
		var near_holster := _hand_near_holster(hand)
		if near_holster and speed < max_speed:
			_holster_gun()
		else:
			_toss_gun(hand)
		return
	_release_held_cartridge()


func _toggle_gun() -> void:
	if revolver.drawn and not revolver.held:
		if _flat_looking_at_loose_gun():
			_attach_gun_to_hand(dominant_hand_name())
		return
	if revolver.drawn:
		_holster_gun()
	else:
		_attach_gun_to_hand(dominant_hand_name())


func _attach_gun_to_hand(hand: StringName) -> void:
	var was_holstered := not revolver.drawn
	revolver.use_aim_steady = use_vr
	revolver.attach_to(_gun_attach_node(hand), hand)
	_holding_hand = GunHand.LEFT if hand == HAND_LEFT else GunHand.RIGHT
	# A trick-shot bind already down at a spinning catch must not relock when it lifts.
	_trick_release_ignored = revolver.is_spin_active() and _trick_shot_held(hand)
	_dump_armed = true
	_close_armed = true
	_dump_hold_accum = 0.0
	if was_holstered:
		holstered_changed.emit(false)
	else:
		CombatHaptics.catch_gun(hand)
	_refresh_reload_status()


func _toss_gun(hand: StringName) -> void:
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	if rig is VRRig:
		var vr := rig as VRRig
		vel = vr.hand_velocity(hand) * float(GameManager.tuning["gun_throw_scale"])
		spin = vr.hand_angular_velocity(hand) * float(GameManager.tuning["gun_throw_spin_scale"])
	revolver.release_into_world(get_tree().current_scene, vel, spin)
	_holding_hand = GunHand.NONE
	_refresh_reload_status()


func _gun_attach_node(hand: StringName) -> Node3D:
	if rig is VRRig:
		return (rig as VRRig).get_gun_attach(hand)
	return rig.get_gun_attach()


func _holding_hand_name() -> StringName:
	return HAND_LEFT if _holding_hand == GunHand.LEFT else HAND_RIGHT


func _on_trick_shot_changed(hand: StringName, pressed: bool) -> void:
	if DeathCam.blocks_combat():
		return
	if not use_vr:
		return
	_trick_down_hands[hand] = pressed
	if not revolver.held or _holding_hand == GunHand.NONE:
		_trick_release_ignored = false
		if revolver.is_spin_active():
			revolver.end_spin(true)
		return
	if hand != _holding_hand_name():
		return
	if pressed:
		revolver.begin_spin()
	elif _trick_release_ignored:
		_trick_release_ignored = false
	else:
		revolver.end_spin(false)


func _trick_shot_held(hand: StringName) -> bool:
	if PlayerSettings.get_vr_bind(&"trick_shot") == "stick_down":
		return rig is VRRig and (rig as VRRig).get_stick(hand).y <= -float(
				GameManager.tuning.get("spin_stick_threshold", 0.55))
	return _trick_down_hands.get(hand, false)


## Hip side from Settings. Right unless Holster Side is Left.
func dominant_hand_name() -> StringName:
	if int(GameManager.tuning.get("holster_side", 0)) != 0:
		return HAND_LEFT
	return HAND_RIGHT


## Hand that owns gun-hand binds. The holding hand once drawn, otherwise the
## holster side (right stick while the hip is on the right).
func draw_hand_name() -> StringName:
	if revolver != null and revolver.held and _holding_hand != GunHand.NONE:
		return _holding_hand_name()
	return dominant_hand_name()


## The hand that is not on the gun. Opposite the holster side while holstered.
func off_hand_name() -> StringName:
	return HAND_LEFT if draw_hand_name() == HAND_RIGHT else HAND_RIGHT


func _hand_position(hand: StringName) -> Vector3:
	if rig is VRRig:
		return (rig as VRRig).get_hand_transform(hand).origin
	return rig.get_right_hand_transform().origin


func _hand_near_holster(hand: StringName) -> bool:
	return _hand_position(hand).distance_to(holster.global_position) <= HOLSTER_GRAB_RADIUS


func _hand_near_gun(hand: StringName) -> bool:
	var radius := float(GameManager.tuning["gun_catch_radius"])
	return _hand_position(hand).distance_to(revolver.global_position) <= radius


func _recover_free_gun() -> void:
	if not revolver.drawn or revolver.held:
		return
	if revolver.global_position.y < GUN_RECOVER_Y:
		_holster_gun()
		return
	if revolver.global_position.distance_to(global_position) > GUN_RECOVER_DIST:
		_holster_gun()


func _pain_toss_gun() -> void:
	revolver.pain_jerk_into_world(get_tree().current_scene)
	_holding_hand = GunHand.NONE
	_refresh_reload_status()


## Flat draw bind while the revolver is loose: true when the camera ray can take it.
func _flat_looking_at_loose_gun() -> bool:
	if not (rig is FlatRig):
		return false
	var flat := rig as FlatRig
	var origin := flat.get_head_transform().origin
	var direction := flat.get_aim_override()
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()
	var reach := maxf(float(GameManager.tuning["gun_flat_grab_range"]), 0.05)
	var radius := maxf(float(GameManager.tuning["gun_flat_grab_radius"]), 0.0)
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var end := origin + direction * reach
	var mask := WeaponBase.COLLISION_LAYER_WORLD | WeaponBase.COLLISION_LAYER_WEAPON
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and _hit_is_revolver(hit["collider"]):
		return true
	var to_gun := revolver.global_position - origin
	var along := clampf(to_gun.dot(direction), 0.0, reach)
	var closest := origin + direction * along
	if revolver.global_position.distance_to(closest) > radius:
		return false
	if not hit.is_empty():
		var hit_along := (hit["position"] as Vector3 - origin).dot(direction)
		if hit_along < along - 0.02:
			return false
	return true


func _hit_is_revolver(collider: Object) -> bool:
	if collider == revolver:
		return true
	return collider is Node and revolver.is_ancestor_of(collider)


func _apply_nonfatal(region: StringName) -> void:
	ImpactFeedback.player_hurt(false)
	if region == CombatRules.REGION_ARM:
		if revolver.held:
			_pain_toss_gun()
			GameManager.show_message("Disarmed!", 1.5)
	elif region == CombatRules.REGION_LEG:
		_leg_remaining = float(GameManager.tuning["leg_slow_duration"])
		move_speed_mult = float(GameManager.tuning["leg_speed_mult"])
		GameManager.show_message("Limp!", 1.5)


func _update_wound_status(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _leg_remaining > 0.0:
		_leg_remaining -= real_delta
		if _leg_remaining <= 0.0:
			_leg_remaining = 0.0
			move_speed_mult = 1.0


func _update_jam_clear(delta: float) -> void:
	if use_vr or not revolver.jammed:
		_jam_clear_accum = 0.0
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var pitch := 0.0
	if rig is FlatRig:
		pitch = (rig as FlatRig).get_look_pitch()
	var looking_down := pitch <= -float(GameManager.tuning["jam_clear_pitch"])
	var holding := alive and revolver.held and Input.is_action_pressed("cock_hammer")
	if looking_down and holding:
		_jam_clear_accum += real_delta
		_refresh_reload_status()
		if _jam_clear_accum >= float(GameManager.tuning["jam_clear_hold"]):
			revolver.clear_jam()
			_jam_clear_accum = 0.0
			_flash_reload_event("CLEARED — ready")
	elif _jam_clear_accum > 0.0:
		_jam_clear_accum = 0.0
		_refresh_reload_status()


func _refresh_health_hud() -> void:
	if GameManager.hud == null:
		return
	if GameManager.mode in [GameManager.GameMode.MENU, GameManager.GameMode.BOOT, GameManager.GameMode.PRACTICE] \
			or GameManager.in_practice():
		GameManager.hud.set_health(0.0, 0.0)
		return
	GameManager.hud.set_health(health, max_health)


func _draw_gun() -> void:
	_attach_gun_to_hand(dominant_hand_name())


func _holster_gun() -> void:
	_clear_held_cartridge(true)
	if revolver.gate_open:
		revolver.close_gate()
	revolver.holster_to(holster)
	_holding_hand = GunHand.NONE
	holstered_changed.emit(true)
	_refresh_reload_status()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.mode == GameManager.GameMode.BOOT:
		return
	if use_vr and event.is_action_pressed("toggle_debug"):
		DebugMenu.toggle()
		get_viewport().set_input_as_handled()


func _on_menu_button() -> void:
	if GameManager.mode == GameManager.GameMode.BOOT:
		return
	if use_vr:
		# Controller menu / pause never opens the debug panel. That is F3.
		if GameManager.mode == GameManager.GameMode.MENU:
			return
		if is_instance_valid(GameManager.hud) and GameManager.hud.pause_menu != null:
			GameManager.hud.pause_menu.toggle()
	else:
		DebugMenu.toggle()


func _combat_blocked() -> bool:
	return GameManager.is_pause_open() or GameManager.mode == GameManager.GameMode.BOOT \
			or GameManager.is_menu_backdrop() or DeathCam.blocks_combat()


func _on_trigger_changed(hand: StringName, pressed: bool) -> void:
	_trigger_down[hand] = pressed
	if pressed and DeathCam.can_skip():
		DeathCam.request_skip()
		return
	if DeathCam.blocks_combat():
		return
	# VR: the off-hand trigger throws the equipped prop instead of firing.
	if use_vr and hand == off_hand_name() and props.has_prop():
		props.on_fire_changed(pressed)
		return
	if not pressed or not alive or _combat_blocked():
		return
	# A hand on the slot lever pulls it; that press never fires.
	if use_vr and _try_pull_slot_lever(hand):
		return
	if use_vr and (not revolver.held or hand != _holding_hand_name()):
		return
	if use_vr:
		revolver.hold_steady_aim()
	revolver.try_fire(GameManager.tuning["auto_cock"], rig.get_aim_override())


func _on_prop_radial_changed(hand: StringName, pressed: bool) -> void:
	if DeathCam.blocks_combat():
		return
	# VR: only the off-hand stick click opens the wheel. Releases carry the real
	# hand so a gun swap mid-wheel cannot strand it open.
	if use_vr:
		if pressed and hand != off_hand_name():
			return
		props.on_radial_changed(hand, pressed)
		return
	props.on_radial_changed(off_hand_name(), pressed)


func _on_prop_fire_changed(_hand: StringName, pressed: bool) -> void:
	if DeathCam.blocks_combat():
		return
	props.on_fire_changed(pressed)


# -- Practice hub: bottles + slot machine -------------------------------------------

func is_holding_bottle() -> bool:
	return _holding_bottle()


func _holding_bottle() -> bool:
	return _held_bottle != null and is_instance_valid(_held_bottle)


## A reset range or a respawn takes the bottle back; drop the stale reference.
func _update_held_bottle() -> void:
	if _held_bottle == null:
		return
	if not is_instance_valid(_held_bottle) or not _held_bottle.is_held_by(_bottle_attach(_held_bottle_hand)):
		_held_bottle = null
		_held_bottle_hand = &""


func _release_held_bottle() -> void:
	if _holding_bottle() and _held_bottle.state == PracticeBottle.State.HELD:
		_held_bottle.go_home()
	_held_bottle = null
	_held_bottle_hand = &""


func _bottle_attach(hand: StringName) -> Node3D:
	if rig != null and rig.has_method("get_bottle_attach"):
		return rig.get_bottle_attach(hand)
	return null


## The off hand only, and only when it is empty (no prop, no belt round).
func _off_hand_free_for_bottle(hand: StringName) -> bool:
	return hand == off_hand_name() and not props.is_prop_in_hand() and not _holding_cartridge() \
			and not _holding_bottle()


func _grab_bottle(bottle: PracticeBottle, hand: StringName, local: Transform3D) -> bool:
	if bottle == null or not bottle.hold(_bottle_attach(hand), local):
		return false
	_held_bottle = bottle
	_held_bottle_hand = hand
	return true


func _try_pick_prop_vr(hand: StringName) -> bool:
	if hand != off_hand_name() or _holding_cartridge() or _holding_bottle():
		return false
	var radius := maxf(float(GameManager.tuning["gun_catch_radius"]), BOTTLE_GRAB_RADIUS_MIN)
	return props.try_pick_near(_hand_position(hand), radius)


func _try_grab_bottle_vr(hand: StringName) -> bool:
	var hub := GameManager.practice_hub()
	if hub == null or not alive or not _off_hand_free_for_bottle(hand):
		return false
	var radius := maxf(float(GameManager.tuning["gun_catch_radius"]), BOTTLE_GRAB_RADIUS_MIN)
	var bottle := hub.nearest_bottle(_hand_position(hand), radius)
	return _grab_bottle(bottle, hand, BOTTLE_HOLD_VR)


func _throw_held_bottle() -> void:
	if not _holding_bottle():
		return
	var bottle := _held_bottle
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	if rig is VRRig:
		var vr := rig as VRRig
		vel = vr.hand_velocity(_held_bottle_hand) * float(GameManager.tuning["gun_throw_scale"])
		spin = vr.hand_angular_velocity(_held_bottle_hand) * float(GameManager.tuning["gun_throw_spin_scale"])
	else:
		var aim: Vector3 = rig.get_aim_override().normalized()
		vel = aim * BOTTLE_FLAT_THROW_SPEED + Vector3.UP * BOTTLE_FLAT_THROW_LIFT
		spin = -rig.get_head_transform().basis.x * BOTTLE_FLAT_THROW_SPIN
	_held_bottle = null
	_held_bottle_hand = &""
	bottle.throw(vel, spin)


func _try_pull_slot_lever(hand: StringName) -> bool:
	var hub := GameManager.practice_hub()
	if hub == null or hub.slot_machine == null:
		return false
	if not hub.slot_machine.is_hand_on_lever(_hand_position(hand)):
		return false
	hub.slot_machine.pull()
	return true


## Flat `interact` (F): throw the held bottle, else pick up the bottle under the
## look ray, else pull the slot machine you are looking at.
func _on_interact_pressed() -> void:
	var hub := GameManager.practice_hub()
	if hub == null or not alive or _combat_blocked():
		return
	if _holding_bottle():
		_throw_held_bottle()
		return
	var origin: Vector3 = rig.get_head_transform().origin
	var direction: Vector3 = rig.get_aim_override().normalized()
	var bottle := hub.bottle_along_ray(origin, direction, BOTTLE_FLAT_REACH, BOTTLE_FLAT_RADIUS)
	if props.try_pick_along_ray(origin, direction, BOTTLE_FLAT_REACH, BOTTLE_FLAT_RADIUS):
		return
	if bottle != null:
		if props.is_prop_in_hand():
			GameManager.show_message("Off hand is full", 1.2)
			return
		_grab_bottle(bottle, off_hand_name(), Transform3D.IDENTITY)
		return
	if hub.slot_machine != null and hub.slot_machine.is_looked_at(origin, direction, BOTTLE_FLAT_REACH):
		hub.slot_machine.pull()


func _on_cock_pressed(hand: StringName) -> void:
	if _combat_blocked():
		return
	if use_vr and (not revolver.held or hand != _holding_hand_name()):
		return
	if revolver.gate_open:
		_close_gate_from_player("closed")
	elif not revolver.jammed:
		revolver.cock()


func _on_gate_pressed(hand: StringName) -> void:
	if _combat_blocked():
		return
	if not use_vr:
		return
	if revolver.held and hand == _holding_hand_name():
		if not alive:
			return
		if revolver.gate_open:
			return
		if revolver.open_gate():
			_dump_armed = true
			_close_armed = true
			_dump_hold_accum = 0.0
			_flash_reload_event("GATE OPEN — shake to dump, belt to load")


func _on_reload_pressed() -> void:
	# Flat: R opens + dumps, or chambers one while open.
	if not alive or not revolver.held or _combat_blocked():
		return
	if revolver.gate_open:
		if revolver.try_chamber():
			_flash_reload_event("CHAMBERED — round seated (%d/%d)" % [
				revolver.rounds, revolver.max_rounds])
	else:
		if revolver.open_gate():
			var ejected := revolver.dump_rounds()
			if ejected <= 0:
				_flash_reload_event("GATE OPEN — empty, R to chamber")


func _on_shells_ejected(ejected: int) -> void:
	var origin := revolver.get_chamber_point()
	ShellCasingPlaceholder.spawn(get_tree().current_scene, origin, ejected)
	_flash_reload_event("DUMPED — %d shell(s)" % ejected)


func _on_revolver_dry_fired(reason: StringName) -> void:
	match reason:
		&"empty":
			_flash_reload_event("CLICK — EMPTY")
		&"gate_open":
			_flash_reload_event("CAN'T FIRE — gate open")
		&"uncocked":
			_flash_reload_event("CLICK — hammer not cocked")
		&"jammed":
			_flash_reload_event("JAMMED — look down, hold Space")
		_:
			_flash_reload_event("CLICK — no shot")


func _on_revolver_state_changed() -> void:
	if _prev_gate_open and not revolver.gate_open:
		if _reload_event.is_empty() or not _reload_event.begins_with("GATE CLOSED"):
			_flash_reload_event("GATE CLOSED — ready (%d/%d)" % [
				revolver.rounds, revolver.max_rounds])
	elif (not _prev_gate_open) and revolver.gate_open and _reload_event.is_empty():
		_flash_reload_event("GATE OPEN")
	_prev_gate_open = revolver.gate_open
	_refresh_reload_status()


func _on_revolver_fired(origin: Vector3, direction: Vector3) -> void:
	var shooter := ReplayBuffer.ACTOR_HOST
	if NetworkManager.is_active() and not NetworkManager.is_host():
		shooter = ReplayBuffer.ACTOR_OTHER
	ReplayBuffer.record_shot(origin, direction, shooter)
	var authoritative := not NetworkManager.is_active() or NetworkManager.is_host()
	Bullet.spawn(get_tree().current_scene, origin, direction,
			GameManager.tuning["bullet_speed"], authoritative, hitbox_rids(), true,
			float(GameManager.tuning.get("self_hit_grace", 0.28)), gun_hand_hitbox_rids())
	NetworkManager.send_shot(origin, direction)
	_refresh_reload_status()


# -- VR reload gestures -----------------------------------------------------------

func _try_grab_from_belt() -> void:
	if not revolver.held or not revolver.gate_open:
		return
	if _holding_cartridge():
		return
	if revolver.rounds >= revolver.max_rounds:
		_flash_reload_event("CYLINDER FULL — bump/swing to close")
		return
	if not _hand_in_ammo_belt():
		_flash_reload_event("MISS BELT — hand must be near waist belt")
		return
	var attach := _cartridge_attach()
	if attach == null:
		return
	_held_cartridge = CartridgePhysical.spawn_held(attach)
	_flash_reload_event("ROUND IN HAND — release near cylinder")
	_refresh_reload_status()


func _release_held_cartridge() -> void:
	if not _holding_cartridge():
		return
	var chambered := false
	if revolver.gate_open and revolver.held and _probe_overlaps(revolver.chamber_area):
		chambered = revolver.try_chamber()
	if chambered:
		_held_cartridge.queue_free()
		_held_cartridge = null
		_flash_reload_event("CHAMBERED — round seated (%d/%d)" % [
			revolver.rounds, revolver.max_rounds])
	else:
		_drop_held_cartridge()
		_flash_reload_event("DROPPED — release near cylinder to chamber")
	_refresh_reload_status()


func _update_vr_reload(delta: float) -> void:
	if not use_vr or not alive:
		return
	if not revolver.held:
		if not revolver.drawn:
			if _holding_cartridge():
				_clear_held_cartridge(true)
				_refresh_reload_status()
			_dump_hold_accum = 0.0
		else:
			_dump_hold_accum = 0.0
		return
	if not revolver.gate_open:
		_dump_hold_accum = 0.0
		return
	if not (rig is VRRig):
		return
	var vr := rig as VRRig
	var gun_speed: float = vr.hand_speed(_holding_hand_name())
	var off_speed: float = vr.hand_speed(off_hand_name())
	# Thresholds live in GameManager.tuning (debug panel → Gunplay / AI).
	var dump_speed: float = float(GameManager.tuning["reload_dump_speed"])
	var dump_hold: float = float(GameManager.tuning["reload_dump_hold"])
	var swing_close: float = float(GameManager.tuning["reload_swing_close"])
	var bump_close: float = float(GameManager.tuning["reload_bump_close"])
	var real_delta := delta / maxf(Engine.time_scale, 0.001)

	# Motion dump: sustain a deliberate shake — brief aim wobble should not eject.
	if revolver.rounds > 0 and _dump_armed:
		if gun_speed >= dump_speed:
			_dump_hold_accum += real_delta
			if _dump_hold_accum >= dump_hold:
				revolver.dump_rounds()
				_dump_armed = false
				_dump_hold_accum = 0.0
		else:
			_dump_hold_accum = 0.0
	elif gun_speed < dump_speed * 0.4:
		_dump_armed = true
		_dump_hold_accum = 0.0

	# Close: swing gun-hand or bump off-hand into the bump volume.
	var bump := _probe_overlaps(revolver.bump_area) and off_speed >= bump_close
	var swing := gun_speed >= swing_close
	if (bump or swing) and _close_armed:
		var how := "bumped shut" if bump else "swung shut"
		_close_gate_from_player(how)
		_close_armed = false
	elif gun_speed < swing_close * 0.35 and off_speed < bump_close * 0.35:
		_close_armed = true


func _close_gate_from_player(how: String) -> void:
	if not revolver.gate_open:
		return
	_clear_held_cartridge(false)
	revolver.close_gate()
	_flash_reload_event("GATE CLOSED — %s (%d/%d)" % [
		how, revolver.rounds, revolver.max_rounds])


func _hand_in_ammo_belt() -> bool:
	return _probe_overlaps(ammo_belt)


func _reload_probe() -> Area3D:
	if not (rig is VRRig):
		return null
	var vr := rig as VRRig
	return vr.get_reload_probe(off_hand_name())


func _probe_overlaps(area: Area3D) -> bool:
	var probe := _reload_probe()
	if probe == null or area == null:
		return false
	return probe.overlaps_area(area)


func set_reload_volume_debug(show: bool) -> void:
	for shape in _reload_volume_shapes():
		_set_reload_shape_viz(shape, show)


func _reload_volume_shapes() -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	_collect_reload_shape(shapes, ammo_belt)
	if revolver != null:
		_collect_reload_shape(shapes, revolver.chamber_area)
		_collect_reload_shape(shapes, revolver.bump_area)
	if rig is VRRig:
		var vr := rig as VRRig
		_collect_reload_shape(shapes, vr.get_reload_probe(HAND_LEFT))
		_collect_reload_shape(shapes, vr.get_reload_probe(HAND_RIGHT))
	return shapes


func _collect_reload_shape(shapes: Array[CollisionShape3D], area: Area3D) -> void:
	if area == null:
		return
	var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		shapes.append(shape_node)


func _set_reload_shape_viz(shape_node: CollisionShape3D, show: bool) -> void:
	var existing := shape_node.get_node_or_null(RELOAD_VIZ_NAME)
	if not show:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var mesh := _mesh_for_reload_shape(shape_node.shape)
	if mesh == null:
		return
	var vis := MeshInstance3D.new()
	vis.name = RELOAD_VIZ_NAME
	vis.mesh = mesh
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _reload_viz_color(shape_node)
	mat.no_depth_test = true
	vis.material_override = mat
	shape_node.add_child(vis)


func _mesh_for_reload_shape(shape: Shape3D) -> Mesh:
	if shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = (shape as SphereShape3D).radius
		sphere.height = (shape as SphereShape3D).radius * 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		return sphere
	if shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		return box
	if shape is CapsuleShape3D:
		var capsule := CapsuleMesh.new()
		var cap := shape as CapsuleShape3D
		capsule.radius = cap.radius
		capsule.height = cap.height
		return capsule
	return null


func _reload_viz_color(shape_node: CollisionShape3D) -> Color:
	var area := shape_node.get_parent()
	if area == ammo_belt:
		return Color(0.85, 0.55, 0.2, 0.35)
	if revolver != null and area == revolver.chamber_area:
		return Color(0.2, 0.9, 0.35, 0.4)
	if revolver != null and area == revolver.bump_area:
		return Color(0.2, 0.7, 1.0, 0.35)
	return Color(0.95, 0.3, 0.85, 0.4)


func _cartridge_attach() -> Node3D:
	if rig is VRRig:
		var hand := off_hand_name()
		return (rig as VRRig).get_cartridge_attach(hand)
	if rig.has_method("get_wrist_attach"):
		return rig.get_wrist_attach()
	return null


func _drop_held_cartridge() -> void:
	if not _holding_cartridge():
		return
	var pos := _held_cartridge.global_position
	var vel := Vector3.ZERO
	if rig is VRRig:
		var vr := rig as VRRig
		var off := off_hand_name()
		vel = vr.hand_velocity(off) * 0.25
	_held_cartridge.drop_into_world(get_tree().current_scene, pos, vel)
	_held_cartridge = null


func _clear_held_cartridge(destroy: bool) -> void:
	if not _holding_cartridge():
		_held_cartridge = null
		return
	if destroy:
		_held_cartridge.queue_free()
	else:
		_drop_held_cartridge()
		return
	_held_cartridge = null


# -- Reload status HUD ------------------------------------------------------------

func _flash_reload_event(text: String) -> void:
	_reload_event = text
	_reload_event_timer = 2.0
	_refresh_reload_status()


func _update_reload_event(delta: float) -> void:
	if _reload_event_timer <= 0.0:
		return
	_reload_event_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _reload_event_timer <= 0.0:
		_reload_event = ""
		_refresh_reload_status()


func _holding_cartridge() -> bool:
	return _held_cartridge != null and is_instance_valid(_held_cartridge)


## A belt round owns the off hand, so an equipped prop parks at the mouth.
func is_holding_cartridge() -> bool:
	return _holding_cartridge()


func _build_reload_status_text() -> String:
	var ammo_line := "AMMO %d / %d" % [revolver.rounds, revolver.max_rounds]
	if revolver.rounds <= 0:
		ammo_line += "  (EMPTY)"
	var gate_line := "GATE OPEN" if revolver.gate_open else "GATE CLOSED"
	var hand_line := "ROUND IN HAND" if _holding_cartridge() else "HAND EMPTY"
	var ready_line := "READY TO FIRE"
	if revolver.jammed:
		ready_line = "JAMMED — look down, hold Space"
		var hold := float(GameManager.tuning["jam_clear_hold"])
		if hold > 0.0 and _jam_clear_accum > 0.0:
			ready_line += " (%d%%)" % int(100.0 * _jam_clear_accum / hold)
	elif not revolver.drawn:
		ready_line = "HOLSTERED"
	elif not revolver.held:
		if use_vr:
			ready_line = "GUN IN AIR — catch to fire"
		else:
			ready_line = "GUN IN AIR — look at it, RMB"
	elif revolver.gate_open:
		if use_vr:
			ready_line = "RELOADING — shake dump / belt grab / bump-swing close"
		else:
			ready_line = "RELOADING — R chamber / Space close"
	elif revolver.rounds <= 0:
		if use_vr:
			ready_line = "EMPTY — B open, shake dump, belt load"
		else:
			ready_line = "EMPTY — R open+dump, R load, Space close"
	var lines := [ammo_line, gate_line, hand_line, ready_line]
	if not _reload_event.is_empty():
		lines.append("> " + _reload_event)
	return "\n".join(lines)


func _refresh_reload_status() -> void:
	var text := _build_reload_status_text()
	if GameManager.hud != null:
		GameManager.hud.set_reload_status(text)
	_update_vr_reload_label(text)


func _update_vr_reload_label(text: String) -> void:
	if not use_vr:
		return
	if _vr_reload_label == null:
		var camera: Node3D = rig.get_node_or_null("XRCamera3D")
		if camera == null:
			return
		_vr_reload_label = Label3D.new()
		_vr_reload_label.font_size = 42
		_vr_reload_label.pixel_size = 0.0018
		_vr_reload_label.outline_size = 12
		_vr_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_vr_reload_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_vr_reload_label.no_depth_test = true
		_vr_reload_label.position = Vector3(-0.55, -0.25, -1.4)
		camera.add_child(_vr_reload_label)
	_vr_reload_label.text = text
	_vr_reload_label.visible = true


# -- Multiplayer pose broadcast ------------------------------------------------------

func pose_flags() -> int:
	var flags := 0
	if revolver.drawn:
		flags |= NetworkManager.POSE_FLAG_GUN_DRAWN
	if revolver.cocked:
		flags |= NetworkManager.POSE_FLAG_GUN_COCKED
	if revolver.drawn and not revolver.held:
		flags |= NetworkManager.POSE_FLAG_GUN_FREE
	if revolver.is_spin_active():
		flags |= NetworkManager.POSE_FLAG_GUN_SPINNING
	if _holding_hand == GunHand.LEFT:
		flags |= NetworkManager.POSE_FLAG_GUN_HELD_LEFT
	if int(GameManager.tuning["holster_side"]) != 0:
		flags |= NetworkManager.POSE_FLAG_HOLSTER_LEFT
	if revolver.gate_open:
		flags |= NetworkManager.POSE_FLAG_GATE_OPEN
	flags |= revolver.chamber_index() << NetworkManager.POSE_FLAG_CHAMBER_SHIFT
	if PlayerSettings.voice_muted:
		flags |= NetworkManager.POSE_FLAG_VOICE_MUTED
	var steadied := revolver.use_aim_steady and revolver.held and not revolver.is_spin_active() \
			and PlayerSettings.aim_steady > 0.0
	if steadied:
		flags |= NetworkManager.POSE_FLAG_GUN_STEADIED
	return flags


## Death-cam latch: the dead body stays still in the clip. The winner keeps
## sending live poses once the fly-along is over.
func capture_replay_pose() -> Dictionary:
	if not DeathCam.locks_recorded_body():
		_replay_latched = false
		_replay_latch = {}
		return _live_replay_pose()
	if _replay_latched:
		return _replay_latch.duplicate(true)
	var pose := _live_replay_pose()
	_replay_latch = pose.duplicate(true)
	_replay_latched = true
	return pose


func capture_live_replay_pose() -> Dictionary:
	return _live_replay_pose()


func apply_replay_pose(pose: Dictionary) -> void:
	var head: Transform3D = pose["head"]
	if rig is FlatRig:
		var euler := head.basis.get_euler()
		var flat := rig as FlatRig
		flat.global_position = Vector3(head.origin.x, head.origin.y - FlatRig.EYE_HEIGHT, head.origin.z)
		flat.set_replay_look(euler.y, euler.x)
	revolver.hold_replay_pose(pose["gun"], int(pose.get("flags", 0)))
	_apply_replay_loadout(pose)
	# A living winner keeps the live wrist writers. Only the corpse is posed from the clip.
	if not alive:
		_pose_dummy_from_replay(pose, head)


func clear_replay_pose() -> void:
	_replay_latched = false
	_replay_latch = {}
	freeze_replay_body()
	_end_replay_loadout()
	if _dummy != null and rig != null:
		_dummy.follow_travel(rig)
	revolver.release_replay_hold()


## Stop the replay writers after the last pose has been applied. No-op unless
## this corpse was driven by the clip. Legs stay on the rig again.
func freeze_replay_body() -> void:
	if not _replay_body_driven:
		return
	_replay_body_driven = false
	if _dummy != null and rig != null:
		_dummy.follow_travel(rig)
	if _dummy != null and not alive:
		_dummy.set_pose_driven(false)
	_end_replay_loadout()


func _pose_dummy_from_replay(pose: Dictionary, head: Transform3D) -> void:
	if _dummy == null:
		return
	var starting := not _replay_body_driven
	_replay_body_driven = true
	# Corpse visibility stays as play_death_feedback left it.
	_dummy.set_pose_driven(true)
	if starting:
		_ensure_replay_travel()
		_dummy.follow_travel(_replay_travel)
	_replay_travel.global_position = head.origin
	var head_basis := head.basis
	var yaw := Basis(Vector3.UP, head_basis.get_euler().y)
	var root_yaw := global_transform.basis.get_euler().y
	var body_yaw := PI + wrapf(yaw.get_euler().y - root_yaw, -PI, PI)
	_dummy.place_toward_head(
		head.origin, body_yaw, DummyBody.pitch_from_basis(head_basis),
		head.origin, DummyBody.roll_from_basis(head_basis))
	var flags := int(pose.get("flags", 0))
	var drawn := flags & NetworkManager.POSE_FLAG_GUN_DRAWN != 0
	var free := flags & NetworkManager.POSE_FLAG_GUN_FREE != 0
	var spinning := flags & NetworkManager.POSE_FLAG_GUN_SPINNING != 0
	var held_left := flags & NetworkManager.POSE_FLAG_GUN_HELD_LEFT != 0
	var gun_in_hand := drawn and not free and not spinning
	var objects := int(pose.get("objects", 0))
	var prop_id := objects & ReplayBuffer.PROP_ID_MASK
	var prop_place := (objects >> ReplayBuffer.PROP_PLACE_SHIFT) & ReplayBuffer.PROP_PLACE_MASK
	var round_held := objects & ReplayBuffer.ROUND_HELD != 0
	var holster_left := flags & NetworkManager.POSE_FLAG_HOLSTER_LEFT != 0
	var off_is_left := not holster_left
	var off_curl := HandFingers.Pose.OPEN
	if prop_place == ReplayBuffer.PROP_PLACE_HAND:
		off_curl = HandFingers.Pose.BOTTLE if prop_id == ReplayBuffer.PROP_BOTTLE else HandFingers.Pose.PINCH
	elif round_held:
		off_curl = HandFingers.Pose.PINCH
	_snap_replay_wrist(_wrist_l, pose["left"], gun_in_hand and held_left)
	_snap_replay_wrist(_wrist_r, pose["right"], gun_in_hand and not held_left)
	_dummy.set_arm_target(false, _wrist_l, true, DummyBody.WRIST_INSET)
	_dummy.set_arm_target(true, _wrist_r, true, DummyBody.WRIST_INSET)
	var left_curl := HandFingers.Pose.PISTOL if gun_in_hand and held_left else HandFingers.Pose.OPEN
	var right_curl := HandFingers.Pose.PISTOL if gun_in_hand and not held_left else HandFingers.Pose.OPEN
	if off_is_left and not (gun_in_hand and held_left):
		left_curl = off_curl
	if not off_is_left and not (gun_in_hand and not held_left):
		right_curl = off_curl
	_dummy.set_hand_curl(false, left_curl, 0.0)
	_dummy.set_hand_curl(true, right_curl, 0.0)


func _ensure_replay_travel() -> void:
	if _replay_travel != null:
		return
	_replay_travel = Marker3D.new()
	_replay_travel.name = "ReplayTravel"
	add_child(_replay_travel)


func _snap_replay_wrist(marker: Marker3D, recorded: Transform3D, on_gun: bool) -> void:
	if marker == null:
		return
	if on_gun:
		var anchor := revolver.find_child("GripAnchor", true, false) as Node3D
		if anchor != null:
			marker.global_transform = anchor.global_transform
			return
	marker.global_transform = recorded


func _live_replay_pose() -> Dictionary:
	var head := global_transform
	var left := global_transform
	var right := global_transform
	if rig != null:
		head = rig.get_head_transform()
		left = rig.get_left_hand_transform()
		right = rig.get_right_hand_transform()
	return {
		"root": global_transform,
		"head": head,
		"left": left,
		"right": right,
		"gun": revolver.global_transform,
		"flags": pose_flags(),
		"objects": _replay_object_word(),
		"prop": _replay_prop_transform(),
		"round": _replay_round_transform(),
	}


func _apply_replay_loadout(pose: Dictionary) -> void:
	var objects := int(pose.get("objects", 0))
	var prop_xf: Transform3D = pose.get("prop", Transform3D.IDENTITY)
	var round_xf: Transform3D = pose.get("round", Transform3D.IDENTITY)
	if props != null:
		props.set_replay_suspended(true)
	if is_instance_valid(_held_cartridge):
		_held_cartridge.visible = false
	_replay_objects_node().show_snapshot(objects, prop_xf, round_xf)


func _end_replay_loadout() -> void:
	if _replay_objects != null:
		_replay_objects.dismiss()
	if props != null:
		props.set_replay_suspended(false)
	if is_instance_valid(_held_cartridge):
		_held_cartridge.visible = true


func _replay_objects_node() -> ReplayObjects:
	if _replay_objects == null:
		_replay_objects = ReplayObjects.new()
		_replay_objects.name = "ReplayObjects"
		add_child(_replay_objects)
	return _replay_objects


func _replay_object_word() -> int:
	var word := 0
	if props != null and props.has_prop():
		var id := _replay_prop_id(props.equipped_item())
		if id != ReplayBuffer.PROP_NONE:
			var place := ReplayBuffer.PROP_PLACE_WORLD
			if props.is_prop_in_hand() and not _holding_cartridge():
				place = ReplayBuffer.PROP_PLACE_HAND
			word = id | (place << ReplayBuffer.PROP_PLACE_SHIFT)
	if _holding_cartridge():
		word |= ReplayBuffer.ROUND_HELD
	return word


func _replay_prop_id(item: StringName) -> int:
	match item:
		PropController.ITEM_CIGARETTE:
			return ReplayBuffer.PROP_CIGARETTE
		PropController.ITEM_COIN:
			return ReplayBuffer.PROP_COIN
		PropController.ITEM_ACE:
			return ReplayBuffer.PROP_ACE
		PropController.ITEM_BOTTLE:
			return ReplayBuffer.PROP_BOTTLE
	return ReplayBuffer.PROP_NONE


func _replay_prop_transform() -> Transform3D:
	if props != null and props.has_prop():
		return props.current_prop().global_transform
	return Transform3D.IDENTITY


func _replay_round_transform() -> Transform3D:
	if _holding_cartridge() and is_instance_valid(_held_cartridge):
		return _held_cartridge.global_transform
	return Transform3D.IDENTITY


func _broadcast_pose(delta: float) -> void:
	if not NetworkManager.is_active():
		return
	_pose_accum += delta / maxf(Engine.time_scale, 0.001)
	if _pose_accum < 1.0 / POSE_SEND_HZ:
		return
	_pose_accum = 0.0
	var flags := pose_flags()
	var gun_xf := Transform3D.IDENTITY
	var steadied := revolver.use_aim_steady and revolver.held and not revolver.is_spin_active() \
			and PlayerSettings.aim_steady > 0.0
	if revolver.drawn and (not revolver.held or revolver.is_spin_active() or steadied):
		gun_xf = revolver.global_transform
	NetworkManager.send_pose(
		rig.get_head_transform(),
		rig.get_left_hand_transform(),
		rig.get_right_hand_transform(),
		flags,
		gun_xf,
		_packed_hands(),
		_replay_object_word(),
		_replay_prop_transform(),
		_replay_round_transform())


# -- VR UI ------------------------------------------------------------------------

func show_menu_panel(menu_control: Control) -> void:
	hide_menu_panel()
	_menu_panel = UIPanel3D.new()
	_menu_panel.panel_size = Vector2(1.0, 0.8)
	add_child(_menu_panel)
	var head := get_head_position()
	var forward := -Basis(Vector3.UP, rig.get_head_transform().basis.get_euler().y).z
	_menu_panel.global_position = Vector3(head.x, global_position.y + 1.4, head.z) + forward * 1.8
	_menu_panel.look_at(head, Vector3.UP, true)
	_menu_panel.set_control(menu_control)


func hide_menu_panel() -> void:
	if is_instance_valid(_menu_panel):
		var control := _menu_panel.release_control()
		if control != null:
			GameManager.hud.reclaim_menu(control)
		_menu_panel.queue_free()
	_menu_panel = null


## Dark FOV cover + status text on the HMD while boot shaders compile.
func show_boot_loading(status := "Loading...") -> void:
	hide_boot_loading()
	if not use_vr or not is_instance_valid(rig):
		return
	var camera: Node3D = rig.get("camera") as Node3D
	if camera == null:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.0, 3.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.09, 0.06, 0.04, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	_boot_cover = MeshInstance3D.new()
	_boot_cover.name = "BootLoadingCover"
	_boot_cover.mesh = mesh
	_boot_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boot_cover.position = Vector3(0.0, 0.0, -0.95)
	camera.add_child(_boot_cover)
	_boot_label = Label3D.new()
	_boot_label.name = "BootLoadingLabel"
	_boot_label.font_size = 64
	_boot_label.pixel_size = 0.002
	_boot_label.outline_size = 12
	_boot_label.modulate = Color(0.92, 0.86, 0.74, 1.0)
	_boot_label.position = Vector3(0.0, 0.04, -0.9)
	_boot_label.text = status
	camera.add_child(_boot_label)


func set_boot_loading_text(status: String) -> void:
	if is_instance_valid(_boot_label) and not status.is_empty():
		_boot_label.text = status


func hide_boot_loading() -> void:
	if is_instance_valid(_boot_cover):
		_boot_cover.queue_free()
	_boot_cover = null
	if is_instance_valid(_boot_label):
		_boot_label.queue_free()
	_boot_label = null


func show_vr_message(text: String, duration: float) -> void:
	if _vr_message == null:
		_vr_message = Label3D.new()
		_vr_message.font_size = 64
		_vr_message.pixel_size = 0.002
		_vr_message.outline_size = 16
		_vr_message.no_depth_test = true
		_vr_message.position = Vector3(0, -0.15, -1.6)
		var camera: Node3D = rig.get_node("XRCamera3D") if use_vr else null
		if camera != null:
			camera.add_child(_vr_message)
		else:
			return
	_vr_message.text = text
	_vr_message.visible = true
	_vr_message_timer = duration


func _update_vr_message(delta: float) -> void:
	if _vr_message == null or not _vr_message.visible:
		return
	_vr_message_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _vr_message_timer <= 0.0:
		_vr_message.visible = false


## Samples wrists after FlatRig look and WeaponBase follow, before arm IK.
class WristDrive extends Node:
	var host: Player

	func _process(delta: float) -> void:
		if host != null:
			host.drive_wrists_late(delta)
