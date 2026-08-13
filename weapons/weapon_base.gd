class_name WeaponBase
extends Node3D
## Base for all firearms. Subclasses provide the muzzle and visuals; owners
## (player / AI / remote avatar) drive drawing, cocking, firing, and reload.

signal fired(origin: Vector3, direction: Vector3)
signal state_changed
## Emitted when shells leave the cylinder; `ejected` is rounds cleared.
signal shells_ejected(ejected: int)
## Empty cylinder, open gate, or uncocked hammer — trigger pulled with no shot.
signal dry_fired(reason: StringName)

@export var max_rounds := 6
## Single-action: must cock the hammer before each shot.
@export var needs_cocking := true

var rounds := 6
var cocked := false
var drawn := false
## Loading gate / cylinder open — fire blocked until closed.
var gate_open := false

@onready var _shot_audio: AudioStreamPlayer3D = _make_audio()


func get_muzzle() -> Marker3D:
	return get_node("Muzzle") as Marker3D


func can_fire() -> bool:
	return drawn and not gate_open


func reset() -> void:
	rounds = max_rounds
	cocked = false
	gate_open = false
	_on_gate_changed()
	state_changed.emit()


func close_gate() -> void:
	if not gate_open:
		return
	gate_open = false
	_on_gate_changed()
	state_changed.emit()


## Opens the loading gate without dumping. Returns false if not drawn or already open.
func open_gate() -> bool:
	if not drawn or gate_open:
		return false
	gate_open = true
	cocked = false
	_on_gate_changed()
	_play(AudioCatalog.get_stream(&"click"))
	state_changed.emit()
	return true


## Ejects all live rounds while the gate is open. Returns how many were ejected.
func dump_rounds() -> int:
	if not gate_open or rounds <= 0:
		return 0
	var ejected := rounds
	rounds = 0
	cocked = false
	_play(AudioCatalog.get_stream(&"shell_eject"))
	shells_ejected.emit(ejected)
	state_changed.emit()
	return ejected


## Flat convenience: open gate and dump immediately.
func begin_gravity_drop() -> bool:
	if not open_gate():
		return false
	dump_rounds()
	return true


## Chambers one live round while the gate is open. Does not auto-close when full.
func try_chamber() -> bool:
	if not gate_open or rounds >= max_rounds:
		return false
	rounds += 1
	_play(AudioCatalog.get_stream(&"chamber"))
	state_changed.emit()
	return true


func cock() -> void:
	if drawn and not gate_open and not cocked:
		cocked = true
		_play(AudioCatalog.get_stream(&"click"))
		state_changed.emit()


## Returns true if a shot was fired. `override_direction` lets flat mode
## shoot along the camera ray instead of the muzzle axis.
func try_fire(auto_cock: bool, override_direction := Vector3.ZERO) -> bool:
	if not drawn:
		return false
	if gate_open:
		dry_fired.emit(&"gate_open")
		return false
	if rounds <= 0:
		_play(AudioCatalog.get_stream(&"dry_fire"))
		dry_fired.emit(&"empty")
		return false
	if needs_cocking and not cocked:
		if auto_cock:
			cocked = true
		else:
			_play(AudioCatalog.get_stream(&"dry_fire"))
			dry_fired.emit(&"uncocked")
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


## Override in subclasses for gate visuals (cylinder tilt, etc.).
func _on_gate_changed() -> void:
	pass


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
