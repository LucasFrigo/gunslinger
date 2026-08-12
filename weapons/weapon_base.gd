class_name WeaponBase
extends Node3D
## Base for all firearms. Subclasses provide the muzzle and visuals; owners
## (player / AI / remote avatar) drive drawing, cocking and firing.

signal fired(origin: Vector3, direction: Vector3)
signal state_changed

@export var max_rounds := 6
## Single-action: must cock the hammer before each shot.
@export var needs_cocking := true

var rounds := 6
var cocked := false
var drawn := false

@onready var _shot_audio: AudioStreamPlayer3D = _make_audio()


func get_muzzle() -> Marker3D:
	return get_node("Muzzle") as Marker3D


func reset() -> void:
	rounds = max_rounds
	cocked = false
	state_changed.emit()


func cock() -> void:
	if drawn and not cocked:
		cocked = true
		_play(AudioCatalog.get_stream(&"click"))
		state_changed.emit()


## Returns true if a shot was fired. `override_direction` lets flat mode
## shoot along the camera ray instead of the muzzle axis.
func try_fire(auto_cock: bool, override_direction := Vector3.ZERO) -> bool:
	if not drawn:
		return false
	if rounds <= 0:
		_play(AudioCatalog.get_stream(&"dry_fire"))
		return false
	if needs_cocking and not cocked:
		if auto_cock:
			cocked = true
		else:
			_play(AudioCatalog.get_stream(&"dry_fire"))
			return false
	rounds -= 1
	cocked = false
	var muzzle := get_muzzle()
	var direction := override_direction
	if direction.is_zero_approx():
		direction = -muzzle.global_transform.basis.z
	_play(AudioCatalog.get_stream(&"gunshot"))
	_muzzle_flash()
	ImpactFeedback.shot_fired(muzzle.global_transform, &"right_hand")
	fired.emit(muzzle.global_position, direction.normalized())
	state_changed.emit()
	return true


func _muzzle_flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 3.0
	light.omni_range = 3.0
	add_child(light)
	light.position = get_muzzle().position
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.08)
	tween.tween_callback(light.queue_free)


func _make_audio() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.max_distance = 80.0
	add_child(player)
	return player


func _play(stream: AudioStream) -> void:
	_shot_audio.stream = stream
	_shot_audio.play()
