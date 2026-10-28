class_name OneShotParticles
extends GPUParticles3D
## One-shot burst that frees itself when finished. Used by placeholder VFX scenes.

## Boot warmup sets this false before add_child so `_ready` does not fire a
## world-space burst in front of the loading cover.
var auto_play := true
## Set by `VfxCatalog` for cues fired every shot: a finished burst calls this with
## itself to park for reuse, so the next shot skips instancing the scene and
## allocating particle buffers. Unset, the burst frees itself.
var park := Callable()

var _plays := 0


func _ready() -> void:
	one_shot = true
	if auto_play:
		play()


## Fire the burst. A parked node calls this again once it is back in the tree.
func play() -> void:
	_plays += 1
	restart()
	emitting = true
	if not finished.is_connected(_retire):
		finished.connect(_retire)
	var play_id := _plays
	# Safety if finished never fires (e.g. zero lifetime). A newer play or a park
	# means this timer belongs to an earlier burst.
	get_tree().create_timer(lifetime * 2.0 + 0.5, true, false, true).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and _plays == play_id and is_inside_tree():
				_retire()
	)


func _retire() -> void:
	if park.is_valid():
		park.call_deferred(self)
	else:
		queue_free()
