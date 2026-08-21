class_name WeaponBase
extends RigidBody3D
## Base for all firearms. Subclasses provide the muzzle and visuals; owners
## (player / AI / remote avatar) drive drawing, cocking, firing, and reload.
## Frozen kinematic while holstered or held; simulates as a RigidBody when tossed.

signal fired(origin: Vector3, direction: Vector3)
signal state_changed
## Emitted when shells leave the cylinder; `ejected` is rounds cleared.
signal shells_ejected(ejected: int)
## Empty cylinder, open gate, or uncocked hammer — trigger pulled with no shot.
signal dry_fired(reason: StringName)

const COLLISION_LAYER_WORLD := 1
const COLLISION_LAYER_WEAPON := 32  # physics layer 6

@export var max_rounds := 6
## Single-action: must cock the hammer before each shot.
@export var needs_cocking := true

var rounds := 6
var cocked := false
## Not holstered (in-hand or airborne). Duel fouls / STANDOFF use this.
var drawn := false
## Parented to a hand attach. Fire, cock, and reload require this.
var held := false
## Loading gate / cylinder open — fire blocked until closed.
var gate_open := false
## XR rumble tracker for the holding hand.
var shooting_hand: StringName = &"right_hand"
## Frozen bodies do not inherit parent motion; copy parent pose while attached.
var follow_parent := true

@onready var _shot_audio: AudioStreamPlayer3D = _make_audio()


func get_muzzle() -> Marker3D:
	return get_node("Muzzle") as Marker3D


func can_fire() -> bool:
	return held and not gate_open


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


## Opens the loading gate without dumping. Returns false if not held or already open.
func open_gate() -> bool:
	if not held or gate_open:
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
	if held and not gate_open and not cocked:
		cocked = true
		_play(AudioCatalog.get_stream(&"click"))
		state_changed.emit()


## Snap to a hand attach. Keeps global pose only if `keep_pose` (unused; identity).
func attach_to(hand_attach: Node3D, rumble_hand: StringName = &"right_hand") -> void:
	_freeze_attached()
	follow_parent = true
	shooting_hand = rumble_hand
	reparent(hand_attach, false)
	transform = Transform3D.IDENTITY
	held = true
	drawn = true
	_sync_follow_parent()


## Toss into the world with the given velocities. Stays `drawn` (not holstered).
func release_into_world(parent: Node, velocity: Vector3, spin: Vector3) -> void:
	var xf := global_transform
	reparent(parent, true)
	global_transform = xf
	held = false
	drawn = true
	follow_parent = false
	freeze = false
	continuous_cd = true
	collision_layer = COLLISION_LAYER_WEAPON
	collision_mask = COLLISION_LAYER_WORLD
	sleeping = false
	linear_velocity = velocity
	angular_velocity = spin


func holster_to(holster: Node3D) -> void:
	_freeze_attached()
	follow_parent = true
	reparent(holster, false)
	transform = Transform3D.IDENTITY
	held = false
	drawn = false
	_sync_follow_parent()


func _freeze_attached() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	continuous_cd = false
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false


func _sync_follow_parent() -> void:
	if not follow_parent or not freeze:
		return
	var p := get_parent() as Node3D
	if p == null:
		return
	global_transform = p.global_transform


func _process(_delta: float) -> void:
	_sync_follow_parent()


func _physics_process(_delta: float) -> void:
	_sync_follow_parent()


## Returns true if a shot was fired. `override_direction` lets flat mode
## shoot along the camera ray instead of the muzzle axis.
func try_fire(auto_cock: bool, override_direction := Vector3.ZERO) -> bool:
	if not held:
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
	ImpactFeedback.shot_fired(muzzle.global_transform, shooting_hand)
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
