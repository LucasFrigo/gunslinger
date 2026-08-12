class_name Hitbox
extends Area3D
## Damage-receiving zone (head/torso/limb). Bullets raycast against these.
## The entity that owns this hitbox must implement
## take_bullet_hit(damage: float, trail_points: PackedVector3Array).
## `region` is for AV feedback and future regional gameplay (arm/leg rules).

@export_range(0.1, 4.0, 0.05) var damage_mult := 1.0
@export var region: StringName = &"torso"

var owner_entity: Node


func _init() -> void:
	collision_layer = 0b100  # hitbox layer (3)
	collision_mask = 0
	monitoring = false
	monitorable = true


func receive_hit(trail_points: PackedVector3Array) -> void:
	if owner_entity != null and owner_entity.has_method("take_bullet_hit"):
		owner_entity.take_bullet_hit(damage_mult, trail_points)
