class_name FlatRig
extends Node3D
## Non-VR test harness for the notebook: mouse-look, WASD walk, Q/E lean,
## RMB draw/holster, LMB fire, Space cock. Deliberately minimal -- it exists
## so multiplayer can be tested against the Quest without a second headset.
## Walk / look / lean speeds come from MovementConfig (debug panel).

signal trigger_changed(pressed: bool)
signal grip_pressed
signal cock_pressed
signal menu_button_pressed

const EYE_HEIGHT := 1.7

@onready var camera: Camera3D = $Pivot/Camera3D
@onready var pivot: Node3D = $Pivot

var _yaw := 0.0
var _pitch := 0.0
var _lean := 0.0


func _ready() -> void:
	pivot.position.y = EYE_HEIGHT


func get_head_transform() -> Transform3D:
	return camera.global_transform


func get_left_hand_transform() -> Transform3D:
	# Virtual off-hand near the chest.
	return camera.global_transform.translated_local(Vector3(-0.2, -0.3, -0.3))


func get_right_hand_transform() -> Transform3D:
	return ($Pivot/Camera3D/GunAttach as Node3D).global_transform


func get_gun_attach() -> Node3D:
	return $Pivot/Camera3D/GunAttach


func get_wrist_attach() -> Node3D:
	return null


## Flat mode fires along the camera ray, not the viewmodel muzzle.
func get_aim_override() -> Vector3:
	return -camera.global_transform.basis.z


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = MovementConfig.mouse_sensitivity
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.4, 1.4)
	elif event.is_action_pressed("fire"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not _pointer_over_ui():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			trigger_changed.emit(true)
	elif event.is_action_released("fire"):
		trigger_changed.emit(false)
	elif event.is_action_pressed("draw_toggle"):
		grip_pressed.emit()
	elif event.is_action_pressed("cock_hammer"):
		cock_pressed.emit()
	elif event.is_action_pressed("toggle_debug"):
		menu_button_pressed.emit()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Look.
	rotation.y = _yaw
	camera.rotation.x = _pitch

	# Walk (scaled time is fine here; it is gameplay movement, not physical).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var motion := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)) \
			* MovementConfig.walk_speed * delta
	position += motion

	# Lean.
	var lean_target := Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	_lean = lerpf(_lean, lean_target, clampf(10.0 * delta, 0.0, 1.0))
	pivot.position.x = _lean * MovementConfig.lean_offset
	pivot.rotation.z = -_lean * deg_to_rad(MovementConfig.lean_angle)

	# Drive MOVEMENT slow-mo mode from walk + lean speed.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if real_delta > 0.0:
		TimeManager.report_player_motion(motion.length() / real_delta)


func face_yaw(yaw: float) -> void:
	_yaw = yaw
	_pitch = 0.0
	rotation.y = yaw
