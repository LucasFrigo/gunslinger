class_name ShellCasingPlaceholder
extends RigidBody3D
## Short-lived spent casing for gravity-drop VFX. Swap mesh later for real art.

const LIFETIME := 2.0


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_callback(queue_free)


static func spawn(parent: Node, origin: Vector3, count: int) -> void:
	if parent == null or count <= 0:
		return
	var scene := preload("res://weapons/shell_casing_placeholder.tscn")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var casing: RigidBody3D = scene.instantiate()
		parent.add_child(casing)
		casing.global_position = origin + Vector3(
			rng.randf_range(-0.02, 0.02),
			rng.randf_range(0.0, 0.02),
			rng.randf_range(-0.02, 0.02))
		casing.linear_velocity = Vector3(
			rng.randf_range(-0.4, 0.4),
			rng.randf_range(-0.2, 0.1),
			rng.randf_range(-0.4, 0.4))
		casing.angular_velocity = Vector3(
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(-8.0, 8.0),
			rng.randf_range(-8.0, 8.0))
