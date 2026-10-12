class_name MeshLabPuppet
extends Node3D
## Flat mesh-lab stand-in. Same mannequin path as a VR player: head pose into
## DummyBody.place_toward_head, hands as IK targets. Walks a small circle.
## Each channel holds its last pose while MeshLabMotion turns it off. The drop test
## shoots the puppet's chest from the fly camera and lets it fall; turning it off stands it up.
## The chunk key cuts the next bone (head to right shin) with a shot from in front, then
## heals them all.

const RADIUS := 1.25
const WALK_SPEED := 1.2
const EYE_HEIGHT := 1.7
const APPROACH := 3.0
## Chunk key targets, head to shins: [bone, toward bone, region]. The shot aims at the
## middle of the two joints; the head aims a little above its joint.
const CUT_TARGETS := [
	[&"Head", &"", &"head"],
	[&"Chest", &"Neck", &"torso"],
	[&"Spine", &"Chest", &"torso"],
	[&"UpperArm.L", &"Forearm.L", &"arm"],
	[&"UpperArm.R", &"Forearm.R", &"arm"],
	[&"Forearm.L", &"Hand.L", &"arm"],
	[&"Forearm.R", &"Hand.R", &"arm"],
	[&"UpperLeg.L", &"LowerLeg.L", &"leg"],
	[&"UpperLeg.R", &"LowerLeg.R", &"leg"],
	[&"LowerLeg.L", &"Foot.L", &"leg"],
	[&"LowerLeg.R", &"Foot.R", &"leg"],
]
const HEAD_AIM := Vector3(0.0, 0.1, 0.0)

var _angle := 0.0
var _head: Marker3D
var _left: Marker3D
var _right: Marker3D
var _dummy: DummyBody
var _head_pitch := 0.0
var _head_yaw := 0.0
var _head_roll := 0.0
var _head_pitch_target := 0.0
var _head_yaw_target := 0.0
var _head_roll_target := 0.0
var _head_timer := 0.4
var _left_pos := Vector3(-0.28, 1.05, 0.05)
var _right_pos := Vector3(0.28, 1.05, 0.05)
var _left_target := Vector3(-0.28, 1.05, 0.05)
var _right_target := Vector3(0.28, 1.05, 0.05)
var _hand_timer := 0.6
var _dropped := false
var _chunk_seen := 0


func _ready() -> void:
	_head = _marker("Head")
	_left = _marker("LeftHand")
	_right = _marker("RightHand")
	_left.position = _left_pos
	_right.position = _right_pos
	_apply_head_local()
	_dummy = DummyBody.spawn(self)
	_dummy.follow_travel(self)
	_dummy.set_tint(Color(0.62, 0.60, 0.58))
	_dummy.drive_arm(false, _left, true, DummyBody.WRIST_INSET)
	_dummy.drive_arm(true, _right, true, DummyBody.WRIST_INSET)
	_layout(0.0)


func _process(delta: float) -> void:
	while _chunk_seen < MeshLabMotion.chunk_step:
		_chunk_seen += 1
		_knock_next(_chunk_seen)
	if MeshLabMotion.drop != _dropped:
		_set_dropped(MeshLabMotion.drop)
	if _dropped:
		return
	if MeshLabMotion.walk:
		_angle += (WALK_SPEED / RADIUS) * delta
		_layout(delta)
	if MeshLabMotion.head:
		_head_timer -= delta
		if _head_timer <= 0.0:
			_head_pitch_target = randf_range(-DummyBody.NOD_LIMIT, DummyBody.NOD_LIMIT)
			_head_yaw_target = randf_range(deg_to_rad(-50.0), deg_to_rad(50.0))
			_head_roll_target = randf_range(deg_to_rad(-20.0), deg_to_rad(20.0))
			_head_timer = randf_range(1.2, 2.2)
		_head_pitch = _approach(_head_pitch, _head_pitch_target, delta)
		_head_yaw = _approach(_head_yaw, _head_yaw_target, delta)
		_head_roll = _approach(_head_roll, _head_roll_target, delta)
		_apply_head_local()
	if MeshLabMotion.hands:
		_hand_timer -= delta
		if _hand_timer <= 0.0:
			_left_target = _random_hand(false)
			_right_target = _random_hand(true)
			_hand_timer = randf_range(0.8, 1.6)
		_left_pos = _left_pos.lerp(_left_target, _blend(delta))
		_right_pos = _right_pos.lerp(_right_target, _blend(delta))
		_left.position = _left_pos
		_right.position = _right_pos
	_pose_dummy()


## Press n cuts target (n - 1) mod 12. Presses 9 to 11 heal the oldest holes
## (`BodyChunks.HOLE_CAP`); the 12th press of each cycle heals them all.
func _knock_next(press: int) -> void:
	var step := (press - 1) % (CUT_TARGETS.size() + 1)
	if step >= CUT_TARGETS.size():
		_dummy.reset_chunks()
		return
	var target: Array = CUT_TARGETS[step]
	var joint := _dummy.bone_global(target[0])
	var aim := joint.origin + joint.basis.orthonormalized() * HEAD_AIM
	if target[1] != &"":
		aim = joint.origin.lerp(_dummy.bone_global(target[1]).origin, 0.5)
	var dir := -_dummy.front_dir()
	var bone := _dummy.bone_index(target[0])
	var cut := _dummy.cut_on_bone(bone, aim - dir * DummyBody.SNAP_BACK, dir, target[2])
	_dummy.knock_chunk(cut, dir, -1.0, false)


func _set_dropped(dropped: bool) -> void:
	_dropped = dropped
	if not dropped:
		_dummy.release_corpse()
		_dummy.set_pose_driven(true)
		return
	var chest := _dummy.bone_global(&"Chest").origin
	var camera := get_viewport().get_camera_3d()
	var from := camera.global_position if camera != null else chest + Vector3(0.0, 0.0, 3.5)
	var dir := (chest - from).normalized()
	_dummy.collapse(PackedVector3Array([chest - dir * 0.5, chest]))


func _layout(_delta: float) -> void:
	global_position = Vector3(cos(_angle), 0.0, sin(_angle)) * RADIUS
	# Tangent of the circle, facing the walk. -Z is this node's forward.
	rotation.y = _angle + PI


func _apply_head_local() -> void:
	_head.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	_head.rotation = Vector3(_head_pitch, _head_yaw, _head_roll)


func _pose_dummy() -> void:
	if _dummy == null:
		return
	var head_basis := _head.global_transform.basis
	var body_yaw := PI + wrapf(head_basis.get_euler().y - global_rotation.y, -PI, PI)
	_dummy.place_toward_head(
			_head.global_position,
			body_yaw,
			DummyBody.pitch_from_basis(head_basis),
			global_position,
			DummyBody.roll_from_basis(head_basis))


func _random_hand(positive_x: bool) -> Vector3:
	var x := randf_range(0.12, 0.48)
	if not positive_x:
		x = -x
	return Vector3(x, randf_range(0.85, 1.6), randf_range(-0.45, 0.25))


func _approach(current: float, target: float, delta: float) -> float:
	return lerpf(current, target, _blend(delta))


func _blend(delta: float) -> float:
	return clampf(1.0 - exp(-APPROACH * delta), 0.0, 1.0)


func _marker(marker_name: String) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	add_child(marker)
	return marker
