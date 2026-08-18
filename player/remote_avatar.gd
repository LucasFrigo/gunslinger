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
@onready var left_hand: Node3D = $LeftHand
@onready var right_hand: Node3D = $RightHand
@onready var left_arm: MeshInstance3D = $LeftArm
@onready var right_arm: MeshInstance3D = $RightArm
@onready var holster: Node3D = $Holster
@onready var gun: Node3D = $Holster/Revolver
@onready var head_hitbox: Hitbox = $Head/HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox
@onready var arm_hitbox_l: Hitbox = $LeftHand/ArmHitbox
@onready var arm_hitbox_r: Hitbox = $RightHand/ArmHitbox
@onready var leg_hitbox: Hitbox = $LegHitbox

var _target_head: Transform3D
var _target_left: Transform3D
var _target_right: Transform3D
var _has_pose := false
var _gun_drawn := false


func _ready() -> void:
	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	arm_hitbox_l.owner_entity = self
	arm_hitbox_r.owner_entity = self
	leg_hitbox.owner_entity = self
	gun.visible = true
	# Rest pose before the first packet: head at spawn, hands by the hips.
	_target_head = global_transform.translated_local(Vector3.UP * 1.7)
	_target_left = global_transform.translated_local(Vector3(-0.25, 1.15, 0.05))
	_target_right = global_transform.translated_local(Vector3(0.25, 1.15, 0.05))
	head.global_transform = _target_head
	left_hand.global_transform = _target_left
	right_hand.global_transform = _target_right


func apply_pose(head_t: Transform3D, left_t: Transform3D, right_t: Transform3D, flags: int) -> void:
	_target_head = head_t
	_target_left = left_t
	_target_right = right_t
	_set_gun_drawn(flags & NetworkManager.POSE_FLAG_GUN_DRAWN != 0)
	_has_pose = true


func _set_gun_drawn(drawn: bool) -> void:
	if drawn == _gun_drawn and gun.get_parent() == (right_hand if drawn else holster):
		return
	_gun_drawn = drawn
	gun.visible = true
	if drawn:
		if gun.get_parent() != right_hand:
			gun.reparent(right_hand)
		gun.transform = Transform3D.IDENTITY
	else:
		if gun.get_parent() != holster:
			gun.reparent(holster)
		gun.transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	var weight := clampf(LERP_SPEED * delta / maxf(Engine.time_scale, 0.001), 0.0, 1.0)
	head.global_transform = head.global_transform.interpolate_with(_target_head, weight)
	left_hand.global_transform = left_hand.global_transform.interpolate_with(_target_left, weight)
	right_hand.global_transform = right_hand.global_transform.interpolate_with(_target_right, weight)
	# Torso hangs under the head, yaw only.
	var yaw := Basis(Vector3.UP, head.global_transform.basis.get_euler().y)
	var head_pos := head.global_position
	torso_hitbox.global_transform = Transform3D(
		yaw, head_pos + Vector3.DOWN * 0.55)
	leg_hitbox.global_transform = Transform3D(
		yaw, head_pos + Vector3.DOWN * 1.3)
	holster.global_transform = Transform3D(
		yaw, Vector3(head_pos.x, global_position.y + 0.9, head_pos.z) + yaw * HOLSTER_LOCAL)
	var torso_pos := torso_hitbox.global_position
	_place_limb(left_arm, torso_pos + yaw * Vector3(-SHOULDER_LOCAL.x, SHOULDER_LOCAL.y, 0.0),
			left_hand.global_position)
	_place_limb(right_arm, torso_pos + yaw * Vector3(SHOULDER_LOCAL.x, SHOULDER_LOCAL.y, 0.0),
			right_hand.global_position)


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
		region: StringName = CombatRules.REGION_TORSO) -> void:
	if NetworkManager.is_host():
		GameManager.duel.mp_report_hit(false, trail_points, region, damage_mult)


func hitbox_rids() -> Array[RID]:
	return [
		head_hitbox.get_rid(),
		torso_hitbox.get_rid(),
		arm_hitbox_l.get_rid(),
		arm_hitbox_r.get_rid(),
		leg_hitbox.get_rid(),
	]
