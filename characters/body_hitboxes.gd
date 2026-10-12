class_name BodyHitboxes
extends Node
## Drives a combatant's six `Hitbox` areas from the posed mannequin bones, after arm
## IK and the finger pass (`DummyBody.HITBOX_PRIORITY`). One owner of hit geometry for
## the local player, the remote avatar, and NPCs. Regions and damage stay in
## `CombatRules`; this only decides where each region sits.
## Capsules are given by their two outer tips. `CapsuleShape3D.height` includes the caps.
## The wrist bone is already `DummyBody.WRIST_INSET` behind the grip, so the forearm
## stops at the wrist (a hand is not a target). The gun arm stops short of it again.

const HEAD_RADIUS := 0.125
const HEAD_CENTER_LOCAL := Vector3(0.0, 0.035, 0.01)
const TORSO_RADIUS := 0.15
const TORSO_NECK_REACH := 0.05
const UPPER_ARM_RADIUS := 0.07
const FOREARM_RADIUS := 0.045
const FOREARM_GUN_RADIUS := 0.035
const WRIST_INSET := 0.0
const GUN_WRIST_INSET := 0.10
const THIGH_RADIUS := 0.09
const THIGH_HIP_REACH := 0.10
const SHIN_RADIUS := 0.075
const SOLE_REACH := 0.07
## Skip a height write below this change (IK stretch, gun-arm flip).
const HEIGHT_EPSILON := 0.005

var _body: DummyBody
var _head: CollisionShape3D
var _torso: CollisionShape3D
var _upper: Dictionary = {}
var _fore: Dictionary = {}
var _thigh: Dictionary = {}
var _shin: Dictionary = {}
var _gun_arm: StringName = &""
var _ok := false
## Shape node -> the bone a cut on it rides. The torso is stored as Spine.
var _bones := {}


## `arms` and `legs` map `&"L"` / `&"R"` to the Hitbox for that side.
func setup(body: DummyBody, head: Hitbox, torso: Hitbox, arms: Dictionary, legs: Dictionary) -> void:
	_body = body
	for suffix in [&"L", &"R"]:
		for bone in ["UpperArm.", "Forearm.", "Hand.", "UpperLeg.", "LowerLeg.", "Foot."]:
			if not body.has_bone(StringName(bone + suffix)):
				push_error("BodyHitboxes missing bone %s%s" % [bone, suffix])
				return
	for bone in [&"Hips", &"Neck", &"Head"]:
		if not body.has_bone(bone):
			push_error("BodyHitboxes missing bone %s" % bone)
			return
	_head = _rebuild(head, &"Head", SphereShape3D.new())
	_torso = _rebuild(torso, &"Torso", CapsuleShape3D.new())
	_bones[_head] = &"Head"
	_bones[_torso] = &"Spine"
	for suffix in arms:
		_upper[suffix] = _rebuild(arms[suffix], &"Upper", CapsuleShape3D.new())
		_fore[suffix] = _rebuild(arms[suffix], &"Fore", CapsuleShape3D.new(), false)
		_bones[_upper[suffix]] = StringName("UpperArm." + suffix)
		_bones[_fore[suffix]] = StringName("Forearm." + suffix)
	for suffix in legs:
		_thigh[suffix] = _rebuild(legs[suffix], &"Thigh", CapsuleShape3D.new())
		_shin[suffix] = _rebuild(legs[suffix], &"Shin", CapsuleShape3D.new(), false)
		_bones[_thigh[suffix]] = StringName("UpperLeg." + suffix)
		_bones[_shin[suffix]] = StringName("LowerLeg." + suffix)
	_ok = true
	update()


## `&"L"`, `&"R"`, or `&""` for no gun hand.
func set_gun_arm(side: StringName) -> void:
	_gun_arm = side


## The bone a cut at `world_point` on `shape` rides, or `&""`. The torso is Chest above
## the Chest joint (along the torso), else Spine.
func bone_of(shape: Object, world_point: Vector3) -> StringName:
	if not _bones.has(shape):
		return &""
	if shape == _torso:
		var chest := _body.bone_global(&"Chest").origin
		return &"Chest" if (world_point - chest).dot(_torso.global_basis.y) > 0.0 else &"Spine"
	return _bones[shape]


func _process(_delta: float) -> void:
	update()


func update() -> void:
	if not _ok or _body == null:
		return
	var head := _body.bone_global(&"Head")
	var head_center := head.origin + head.basis.orthonormalized() * HEAD_CENTER_LOCAL
	_place_sphere(_head, head_center, HEAD_RADIUS)
	var hips := _body.bone_global(&"Hips").origin
	var neck := _body.bone_global(&"Neck")
	var neck_up := neck.basis.y.normalized()
	_place_capsule(_torso, hips, neck.origin + neck_up * TORSO_NECK_REACH, TORSO_RADIUS)
	for suffix in _upper:
		var shoulder := _body.bone_global(StringName("UpperArm." + suffix)).origin
		var elbow := _body.bone_global(StringName("Forearm." + suffix)).origin
		var wrist := _body.bone_global(StringName("Hand." + suffix)).origin
		var gun: bool = suffix == _gun_arm
		var forearm_dir := (wrist - elbow).normalized()
		var wrist_tip := wrist - forearm_dir * (GUN_WRIST_INSET if gun else WRIST_INSET)
		_place_capsule(_upper[suffix], shoulder, elbow, UPPER_ARM_RADIUS)
		_place_capsule(_fore[suffix], elbow, wrist_tip, FOREARM_GUN_RADIUS if gun else FOREARM_RADIUS)
	for suffix in _thigh:
		var hip := _body.bone_global(StringName("UpperLeg." + suffix))
		var knee := _body.bone_global(StringName("LowerLeg." + suffix)).origin
		var ankle := _body.bone_global(StringName("Foot." + suffix)).origin
		var thigh_dir := (knee - hip.origin).normalized()
		var shin_dir := (ankle - knee).normalized()
		_place_capsule(_thigh[suffix], hip.origin - thigh_dir * THIGH_HIP_REACH, knee, THIGH_RADIUS)
		_place_capsule(_shin[suffix], knee, ankle + shin_dir * SOLE_REACH, SHIN_RADIUS)


## Replace the hitbox's scene shapes with one shape node per segment. A hitbox with a
## second segment keeps what the first call made (`clear` false).
func _rebuild(hitbox: Hitbox, shape_name: StringName, shape: Shape3D, clear := true) -> CollisionShape3D:
	if clear:
		for child in hitbox.get_children():
			if child is CollisionShape3D:
				hitbox.remove_child(child)
				child.queue_free()
	var node := CollisionShape3D.new()
	node.name = shape_name
	node.shape = shape
	hitbox.add_child(node)
	return node


func _place_sphere(node: CollisionShape3D, center: Vector3, radius: float) -> void:
	var sphere := node.shape as SphereShape3D
	if not is_equal_approx(sphere.radius, radius):
		sphere.radius = radius
	node.global_transform = Transform3D(Basis.IDENTITY, center)


func _place_capsule(node: CollisionShape3D, tip_a: Vector3, tip_b: Vector3, radius: float) -> void:
	var capsule := node.shape as CapsuleShape3D
	var span := tip_b - tip_a
	var dist := span.length()
	var dir := span / dist if dist > 0.0001 else Vector3.UP
	var length := maxf(dist, radius * 2.0)
	if not is_equal_approx(capsule.radius, radius):
		capsule.radius = radius
	if absf(capsule.height - length) > HEIGHT_EPSILON:
		capsule.height = length
	var x_axis := dir.cross(Vector3.UP)
	if x_axis.length_squared() < 0.0001:
		x_axis = dir.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(dir)
	node.global_transform = Transform3D(Basis(x_axis, dir, z_axis), tip_a.lerp(tip_b, 0.5))
