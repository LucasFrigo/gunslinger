class_name RemoteAvatar
extends Node3D
## Visual proxy for the other player in multiplayer: head (with hat), greybox
## torso/legs/arms, and a revolver that sits on the hip until drawn. Driven by
## the pose stream. On the host its hitboxes are the authoritative target for
## the local player's bullets.

const LERP_SPEED := 18.0
const ARM_MESH_HEIGHT := 1.0
const SHOULDER_LOCAL := Vector3(0.18, 0.22, 0.0)
const HOLSTER_LOCAL := Vector3(0.25, 0.0, 0.05)

@onready var head: Node3D = $Head
## Proximity voice comes out of the mouth, so falloff is plain 3D attenuation.
@onready var voice_player: AudioStreamPlayer3D = $Head/MouthMarker/VoicePlayer
@onready var mute_icon: Label3D = $Head/MouthMarker/MuteX
@onready var left_hand: Node3D = $LeftHand
@onready var right_hand: Node3D = $RightHand
@onready var left_arm: MeshInstance3D = $LeftArm
@onready var right_arm: MeshInstance3D = $RightArm
@onready var holster: Node3D = $Holster
@onready var gun: Node3D = $Holster/Revolver
@onready var head_hitbox: Hitbox = $Head/HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox
@onready var arm_hitbox_l: Hitbox = $ArmHitboxL
@onready var arm_hitbox_r: Hitbox = $ArmHitboxR
@onready var leg_hitbox: Hitbox = $LegHitbox

var _target_head: Transform3D
var _target_left: Transform3D
var _target_right: Transform3D
var _target_gun: Transform3D
var _has_pose := false
var _gun_drawn := false
var _gun_free := false
var _gun_spinning := false
var _gun_steadied := false
var _gun_held_left := false
var _holster_left := false
var _hands := 0
var _snap_l: Marker3D
var _snap_r: Marker3D
var _snap_lock: Dictionary = {}
var _snap_from_local: Dictionary = {}
var _snap_blend: Dictionary = {}
var replay_locked := false
var _dummy: DummyBody
var _replay_objects: ReplayObjects
var _objects := 0
var _prop_xf := Transform3D.IDENTITY
var _round_xf := Transform3D.IDENTITY


func _ready() -> void:
	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	arm_hitbox_l.owner_entity = self
	arm_hitbox_r.owner_entity = self
	leg_hitbox.owner_entity = self
	gun.visible = true
	_freeze_gun()
	_attach_dummy()
	# Rest pose before the first packet: head at spawn, hands by the hips.
	_target_head = global_transform.translated_local(Vector3.UP * 1.7)
	_target_left = global_transform.translated_local(Vector3(-0.25, 1.15, 0.05))
	_target_right = global_transform.translated_local(Vector3(0.25, 1.15, 0.05))
	head.global_transform = _target_head
	left_hand.global_transform = _target_left
	right_hand.global_transform = _target_right


func _attach_dummy() -> void:
	_dummy = DummyBody.spawn(self)
	_dummy.follow_travel(head)
	_dummy.set_tint(Color(0.30, 0.25, 0.35))
	for path in [
		"Head/HeadMesh", "Head/HatBrim",
		"LeftHand/HandMesh", "RightHand/HandMesh",
		"LeftArm", "RightArm",
		"TorsoHitbox/TorsoMesh", "LegHitbox/LegMesh",
	]:
		var mesh: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
		if mesh != null:
			mesh.visible = false
	# Hand markers sit on -X (left node) and +X (right node). The snap markers
	# sit on a held revolver's grip; otherwise they stay on the streamed hand.
	_snap_l = _make_snap("SnapL")
	_snap_r = _make_snap("SnapR")
	_snap_l.global_transform = left_hand.global_transform
	_snap_r.global_transform = right_hand.global_transform
	_snap_lock["SnapL"] = "hand"
	_snap_lock["SnapR"] = "hand"
	_snap_blend["SnapL"] = 1.0
	_snap_blend["SnapR"] = 1.0
	_dummy.drive_arm(false, _snap_l, true, DummyBody.WRIST_INSET)
	_dummy.drive_arm(true, _snap_r, true, DummyBody.WRIST_INSET)


func _make_snap(snap_name: String) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = snap_name
	add_child(marker)
	return marker


func capture_replay_pose() -> Dictionary:
	var flags := 0
	if _gun_drawn:
		flags |= NetworkManager.POSE_FLAG_GUN_DRAWN
	if _gun_free:
		flags |= NetworkManager.POSE_FLAG_GUN_FREE
	if _gun_spinning:
		flags |= NetworkManager.POSE_FLAG_GUN_SPINNING
	if _gun_steadied:
		flags |= NetworkManager.POSE_FLAG_GUN_STEADIED
	if _gun_held_left:
		flags |= NetworkManager.POSE_FLAG_GUN_HELD_LEFT
	if _holster_left:
		flags |= NetworkManager.POSE_FLAG_HOLSTER_LEFT
	return {
		"root": global_transform,
		"head": head.global_transform,
		"left": left_hand.global_transform,
		"right": right_hand.global_transform,
		"gun": gun.global_transform,
		"flags": flags,
		"hands": _hands,
		"objects": _objects,
		"prop": _prop_xf,
		"round": _round_xf,
	}


func apply_replay_pose(pose: Dictionary) -> void:
	replay_locked = true
	var objects := int(pose.get("objects", 0))
	var prop_xf: Transform3D = pose.get("prop", Transform3D.IDENTITY)
	var round_xf: Transform3D = pose.get("round", Transform3D.IDENTITY)
	apply_pose(pose["head"], pose["left"], pose["right"], int(pose["flags"]), pose["gun"],
			int(pose.get("hands", 0)), objects, prop_xf, round_xf)
	head.global_transform = pose["head"]
	left_hand.global_transform = pose["left"]
	right_hand.global_transform = pose["right"]
	if gun is Revolver:
		(gun as Revolver).hold_replay_pose(pose["gun"], int(pose.get("flags", 0)))
	else:
		gun.global_transform = pose["gun"]
	_replay_objects_node().show_snapshot(objects, prop_xf, round_xf)


func clear_replay_pose() -> void:
	replay_locked = false
	if _replay_objects != null:
		_replay_objects.dismiss()


func apply_pose(head_t: Transform3D, left_t: Transform3D, right_t: Transform3D, flags: int,
		gun_t := Transform3D.IDENTITY, hands := 0, objects := 0,
		prop_t := Transform3D.IDENTITY, round_t := Transform3D.IDENTITY) -> void:
	_target_head = head_t
	_target_left = left_t
	_target_right = right_t
	_target_gun = gun_t
	_hands = hands
	_objects = objects
	_prop_xf = prop_t
	_round_xf = round_t
	_gun_free = flags & NetworkManager.POSE_FLAG_GUN_FREE != 0
	_gun_spinning = flags & NetworkManager.POSE_FLAG_GUN_SPINNING != 0
	_gun_steadied = flags & NetworkManager.POSE_FLAG_GUN_STEADIED != 0
	_gun_held_left = flags & NetworkManager.POSE_FLAG_GUN_HELD_LEFT != 0
	_holster_left = flags & NetworkManager.POSE_FLAG_HOLSTER_LEFT != 0
	set_voice_muted(flags & NetworkManager.POSE_FLAG_VOICE_MUTED != 0)
	_apply_gun_parent(flags & NetworkManager.POSE_FLAG_GUN_DRAWN != 0)
	_has_pose = true


func _replay_objects_node() -> ReplayObjects:
	if _replay_objects == null:
		_replay_objects = ReplayObjects.new()
		_replay_objects.name = "ReplayObjects"
		add_child(_replay_objects)
	return _replay_objects


## Mute state has to read at a glance across the duel lane, so it is an X over
## the mouth rather than a HUD line.
func set_voice_muted(muted: bool) -> void:
	if mute_icon != null:
		mute_icon.visible = muted


func _freeze_gun() -> void:
	if gun is RigidBody3D:
		var body := gun as RigidBody3D
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.collision_layer = 0
		body.collision_mask = 0


func _apply_gun_parent(drawn: bool) -> void:
	_freeze_gun()
	gun.visible = true
	if _gun_free:
		if gun is WeaponBase:
			(gun as WeaponBase).follow_parent = false
		if gun.get_parent() != self:
			gun.reparent(self, true)
		_gun_drawn = true
		return
	var attach: Node3D = holster
	if drawn:
		attach = left_hand if _gun_held_left else right_hand
	if _gun_spinning or _gun_steadied:
		if gun is WeaponBase:
			(gun as WeaponBase).follow_parent = false
		if gun.get_parent() != attach:
			gun.reparent(attach, true)
		_gun_drawn = true
		return
	if gun is WeaponBase:
		(gun as WeaponBase).follow_parent = true
	if gun.get_parent() != attach:
		gun.reparent(attach)
	gun.transform = Transform3D.IDENTITY
	_gun_drawn = drawn


func _process(delta: float) -> void:
	var weight := 1.0 if replay_locked else clampf(LERP_SPEED * delta / maxf(Engine.time_scale, 0.001), 0.0, 1.0)
	head.global_transform = head.global_transform.interpolate_with(_target_head, weight)
	left_hand.global_transform = left_hand.global_transform.interpolate_with(_target_left, weight)
	right_hand.global_transform = right_hand.global_transform.interpolate_with(_target_right, weight)
	# Torso yaws with the head and stays in the rest pose. The neck takes the look.
	var yaw := Basis(Vector3.UP, head.global_transform.basis.get_euler().y)
	if _dummy != null:
		var root_yaw := global_transform.basis.get_euler().y
		var body_yaw := PI + wrapf(yaw.get_euler().y - root_yaw, -PI, PI)
		var head_basis := head.global_transform.basis
		_dummy.place_toward_head(
			head.global_position, body_yaw, DummyBody.pitch_from_basis(head_basis),
			head.global_position, DummyBody.roll_from_basis(head_basis))
	var head_pos := head.global_position
	torso_hitbox.global_transform = Transform3D(
		yaw, head_pos + Vector3.DOWN * 0.55)
	leg_hitbox.global_transform = Transform3D(
		yaw, head_pos + Vector3.DOWN * 1.3)
	var hip := HOLSTER_LOCAL
	hip.x = -absf(hip.x) if _holster_left else absf(hip.x)
	holster.global_transform = Transform3D(
		yaw, Vector3(head_pos.x, global_position.y + 1.0, head_pos.z) + yaw * hip)
	var torso_pos := torso_hitbox.global_position
	var left_shoulder := torso_pos + yaw * Vector3(-SHOULDER_LOCAL.x, SHOULDER_LOCAL.y, 0.0)
	var right_shoulder := torso_pos + yaw * Vector3(SHOULDER_LOCAL.x, SHOULDER_LOCAL.y, 0.0)
	_place_limb(left_arm, left_shoulder, left_hand.global_position)
	_place_limb(right_arm, right_shoulder, right_hand.global_position)
	var gun_left := _gun_drawn and not _gun_free and _gun_held_left
	var gun_right := _gun_drawn and not _gun_free and not _gun_held_left
	arm_hitbox_l.place_along_limb(left_shoulder, left_hand.global_position,
			Hitbox.ARM_GUN_HAND_WRIST_INSET if gun_left else Hitbox.ARM_WRIST_INSET,
			Hitbox.ARM_GUN_HAND_RADIUS_SCALE if gun_left else Hitbox.ARM_RADIUS_SCALE)
	arm_hitbox_r.place_along_limb(right_shoulder, right_hand.global_position,
			Hitbox.ARM_GUN_HAND_WRIST_INSET if gun_right else Hitbox.ARM_WRIST_INSET,
			Hitbox.ARM_GUN_HAND_RADIUS_SCALE if gun_right else Hitbox.ARM_RADIUS_SCALE)
	if _gun_free or _gun_spinning or _gun_steadied:
		gun.global_transform = gun.global_transform.interpolate_with(_target_gun, weight)
	if replay_locked:
		gun.global_transform = _target_gun
	_drive_remote_hands(delta)


func _drive_remote_hands(delta: float) -> void:
	if _dummy == null or _snap_l == null:
		return
	var gun_left := _gun_drawn and not _gun_free and not _gun_spinning and _gun_held_left
	var gun_right := _gun_drawn and not _gun_free and not _gun_spinning and not _gun_held_left
	_place_snap(_snap_l, _wrist_goal(left_hand, gun_left), delta, "gun" if gun_left else "hand")
	_place_snap(_snap_r, _wrist_goal(right_hand, gun_right), delta, "gun" if gun_right else "hand")
	_dummy.set_hand_curl(false, HandFingers.unpack_pose(_hands, false), HandFingers.unpack_trigger(_hands, false))
	_dummy.set_hand_curl(true, HandFingers.unpack_pose(_hands, true), HandFingers.unpack_trigger(_hands, true))


func _wrist_goal(hand_node: Node3D, on_gun: bool) -> Transform3D:
	if on_gun:
		var anchor := gun.find_child("GripAnchor", true, false) as Node3D
		if anchor != null:
			return anchor.global_transform
	return hand_node.global_transform


func _place_snap(marker: Marker3D, goal: Transform3D, delta: float, lock_id: String) -> void:
	var prev := str(_snap_lock.get(marker.name, ""))
	if prev != lock_id:
		_snap_from_local[marker.name] = global_transform.affine_inverse() * marker.global_transform
		_snap_blend[marker.name] = 0.0
		_snap_lock[marker.name] = lock_id
	var t := float(_snap_blend.get(marker.name, 1.0))
	if t >= 1.0:
		marker.global_transform = goal
		return
	t = minf(1.0, t + delta / DummyBody.WRIST_BLEND_SEC)
	_snap_blend[marker.name] = t
	var start: Transform3D = global_transform * (_snap_from_local[marker.name] as Transform3D)
	marker.global_transform = start.interpolate_with(goal, t)


func _place_limb(node: Node3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := maxf(delta.length(), 0.04)
	var y_axis := delta / length
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length_squared() < 0.0001:
		x_axis = y_axis.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis)
	node.global_transform = Transform3D(
		Basis(x_axis, y_axis, z_axis).scaled(Vector3(1.0, length / ARM_MESH_HEIGHT, 1.0)),
		from.lerp(to, 0.5))


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO, _self_inflicted := false,
		shooter_is_local := false) -> void:
	if NetworkManager.is_host():
		GameManager.duel.mp_report_hit(false, trail_points, region, damage_mult, shooter_is_local)


func hitbox_rids() -> Array[RID]:
	return [
		head_hitbox.get_rid(),
		torso_hitbox.get_rid(),
		arm_hitbox_l.get_rid(),
		arm_hitbox_r.get_rid(),
		leg_hitbox.get_rid(),
	]


func gun_hand_hitbox_rids() -> Array[RID]:
	if not _gun_drawn or _gun_free:
		return [arm_hitbox_l.get_rid(), arm_hitbox_r.get_rid()]
	if _gun_held_left:
		return [arm_hitbox_l.get_rid()]
	return [arm_hitbox_r.get_rid()]
