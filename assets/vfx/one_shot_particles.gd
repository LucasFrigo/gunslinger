class_name OneShotParticles
extends GPUParticles3D
## One-shot burst that frees itself when finished. Used by placeholder VFX scenes.


func _ready() -> void:
	one_shot = true
	emitting = true
	finished.connect(queue_free)
	# Safety if finished never fires (e.g. zero lifetime).
	get_tree().create_timer(lifetime + 0.5, true, false, true).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				queue_free()
	)
