class_name Hitbox
extends Area3D
## Damage-receiving zone (head/torso/limb). Bullets raycast against these.
## The entity that owns this hitbox must implement
## take_bullet_hit(damage: float, trail_points: PackedVector3Array, region: StringName).
## `region` drives AV feedback and CombatRules (head kill, arm disarm, leg slow).
## Damage is ignored unless `DuelManager.accepts_hits()` (DRAW only).
##
## Arm volumes are capsules along shoulder → hand (`place_along_limb`). The
## gun-hand uses extra wrist inset + a thinner radius so a forward muzzle shot
## does not clip the forearm; torso/head/off-hand stay hittable at close range.

## Rest height of the arm CapsuleShape3D in player / remote_avatar scenes.
const LIMB_CAPSULE_HEIGHT := 1.0
const ARM_RADIUS_SCALE := 1.0
const ARM_GUN_HAND_RADIUS_SCALE := 0.7
## Stop short of the hand so the fist / grip is outside the volume.
const ARM_WRIST_INSET := 0.10
## Extra gap so the revolver + muzzle sit past the gun-hand capsule.
const ARM_GUN_HAND_WRIST_INSET := 0.18

@export_range(0.1, 4.0, 0.05) var damage_mult := 1.0
@export var region: StringName = &"torso"

var owner_entity: Node


func _init() -> void:
	collision_layer = 0b100  # hitbox layer (3)
	collision_mask = 0
	monitoring = false
	monitorable = true


## Capsule along `from` → `to`, stopping `wrist_inset` short of `to`. Y of the
## scene capsule is the long axis (height `LIMB_CAPSULE_HEIGHT`).
func place_along_limb(from: Vector3, to: Vector3, wrist_inset: float, radius_scale := 1.0) -> void:
	var delta := to - from
	var length := delta.length()
	var inset := minf(maxf(wrist_inset, 0.0), maxf(length - 0.08, 0.0))
	var end := to
	if length > 0.001:
		end = from + delta * ((length - inset) / length)
	var span := end - from
	var span_len := maxf(span.length(), 0.08)
	var y_axis := span / span_len
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length_squared() < 0.0001:
		x_axis = y_axis.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis)
	global_transform = Transform3D(
		Basis(x_axis, y_axis, z_axis).scaled(
			Vector3(radius_scale, span_len / LIMB_CAPSULE_HEIGHT, radius_scale)),
		from.lerp(end, 0.5))


func receive_hit(trail_points: PackedVector3Array, self_inflicted := false) -> void:
	if GameManager == null or GameManager.duel == null or not GameManager.duel.accepts_hits():
		return
	if owner_entity != null and owner_entity.has_method("take_bullet_hit"):
		owner_entity.take_bullet_hit(damage_mult, trail_points, region, self_inflicted)
