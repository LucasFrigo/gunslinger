class_name RemoteAvatar
extends Node3D
## Visual proxy for the other player in multiplayer: head (with hat), hands,
## and gun, driven by the pose stream. On the host its hitboxes are the
## authoritative target for the local player's bullets.

const LERP_SPEED := 18.0

@onready var head: Node3D = $Head
@onready var left_hand: Node3D = $LeftHand
@onready var right_hand: Node3D = $RightHand
@onready var gun: Node3D = $RightHand/Revolver
@onready var head_hitbox: Hitbox = $Head/HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox

var _target_head: Transform3D
var _target_left: Transform3D
var _target_right: Transform3D
var _has_pose := false


func _ready() -> void:
	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	gun.visible = false
	# Initial guess before the first pose arrives.
	_target_head = global_transform.translated_local(Vector3.UP * 1.7)
	_target_left = _target_head
	_target_right = _target_head


func apply_pose(head_t: Transform3D, left_t: Transform3D, right_t: Transform3D, flags: int) -> void:
	_target_head = head_t
	_target_left = left_t
	_target_right = right_t
	gun.visible = flags & NetworkManager.POSE_FLAG_GUN_DRAWN != 0
	_has_pose = true


func _process(delta: float) -> void:
	var weight := clampf(LERP_SPEED * delta / maxf(Engine.time_scale, 0.001), 0.0, 1.0)
	head.global_transform = head.global_transform.interpolate_with(_target_head, weight)
	left_hand.global_transform = left_hand.global_transform.interpolate_with(_target_left, weight)
	right_hand.global_transform = right_hand.global_transform.interpolate_with(_target_right, weight)
	# Torso hangs under the head, yaw only.
	var yaw := Basis(Vector3.UP, head.global_transform.basis.get_euler().y)
	torso_hitbox.global_transform = Transform3D(
		yaw, head.global_position + Vector3.DOWN * 0.55)


func take_bullet_hit(_damage_mult: float, trail_points: PackedVector3Array) -> void:
	if NetworkManager.is_host():
		GameManager.duel.mp_report_hit(false, trail_points)


func hitbox_rids() -> Array[RID]:
	return [head_hitbox.get_rid(), torso_hitbox.get_rid()]
