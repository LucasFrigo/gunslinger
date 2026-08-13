class_name CartridgePhysical
extends RigidBody3D
## Placeholder live round for belt → chamber feed. Freeze while held; unfreeze
## to drop. Swap mesh later for real art.

const LIFETIME_DROPPED := 8.0


func grab_to(attach: Node3D) -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	reparent(attach, false)
	transform = Transform3D.IDENTITY


func drop_into_world(parent: Node, world_pos: Vector3, velocity := Vector3.ZERO) -> void:
	reparent(parent, true)
	global_position = world_pos
	freeze = false
	collision_layer = 1
	collision_mask = 1
	linear_velocity = velocity
	angular_velocity = Vector3(
		randf_range(-6.0, 6.0),
		randf_range(-6.0, 6.0),
		randf_range(-6.0, 6.0))
	var tween := create_tween()
	tween.tween_interval(LIFETIME_DROPPED)
	tween.tween_callback(queue_free)


static func spawn_held(attach: Node3D) -> CartridgePhysical:
	var scene := preload("res://weapons/cartridge_physical.tscn")
	var cartridge: CartridgePhysical = scene.instantiate()
	attach.add_child(cartridge)
	cartridge.grab_to(attach)
	return cartridge
