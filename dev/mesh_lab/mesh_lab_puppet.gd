class_name MeshLabPuppet
extends Node3D
## Flat mesh-lab stand-in. Same mannequin path as a VR player: head pose into
## DummyBody.place_toward_head, hands as IK targets. Walks a small circle.
## Each channel holds its last pose while MeshLabMotion turns it off.

const RADIUS := 1.25
const WALK_SPEED := 1.2
const EYE_HEIGHT := 1.7
const APPROACH := 3.0

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
