class_name FlatRig
extends CharacterBody3D
## Non-VR test harness for the notebook: mouse-look, WASD walk, Q/E lean,
## RMB draw/holster, LMB fire, Space cock (or close gate), R reload. Deliberately
## minimal -- it exists so multiplayer can be tested against the Quest without a
## second headset. Walk / look / lean speeds come from MovementConfig (debug panel).
## Collides with static world (layer 1) so greybox buildings / ground / step ramps matter.

signal trigger_changed(hand: StringName, pressed: bool)
signal grip_changed(hand: StringName, pressed: bool)
signal cock_pressed(hand: StringName)
signal reload_pressed
signal prop_radial_changed(hand: StringName, pressed: bool)
signal prop_fire_changed(hand: StringName, pressed: bool)
signal menu_button_pressed

const EYE_HEIGHT := 1.7
const GRAVITY := 24.0
const OFF_HAND := &"left_hand"
## Mouse pixels for a full deflection on the prop radial.
const RADIAL_MOUSE_RANGE := 260.0

@onready var camera: Camera3D = $Pivot/Camera3D
@onready var pivot: Node3D = $Pivot

var _yaw := 0.0
var _pitch := 0.0
var _lean := 0.0
var _prop_radial_active := false
var _prop_radial_vector := Vector2.ZERO


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


## Virtual off hand: props sit left of the camera, never on `GunAttach`.
func get_prop_attach(_hand: StringName = OFF_HAND) -> Node3D:
	return $Pivot/Camera3D/PropAttach


## Flat reload is R / Space, so there is nothing to stow for.
func get_mouth_attach() -> Node3D:
	return null


## While the wheel is open the mouse steers it and look freezes, so the aim
## you come back to is the one you left.
func set_prop_radial_active(active: bool, _hand: StringName = &"") -> void:
	_prop_radial_active = active
	_prop_radial_vector = Vector2.ZERO


func get_prop_radial_vector() -> Vector2:
	return _prop_radial_vector


## Mouse travel while the wheel is open, as a unit-clamped wheel vector
## (screen up is wheel up).
static func radial_vector_from_motion(current: Vector2, relative: Vector2) -> Vector2:
	return (current + Vector2(relative.x, -relative.y) / RADIAL_MOUSE_RANGE).limit_length(1.0)


## Flat mode fires along the camera ray, not the viewmodel muzzle.
func get_aim_override() -> Vector3:
	return -camera.global_transform.basis.z


## Look pitch in radians; negative is down (used to clear a jam).
func get_look_pitch() -> float:
	return _pitch


func _unhandled_input(event: InputEvent) -> void:
	if PlayerSettings.is_listening() and not PlayerSettings.listen_is_vr:
		# SettingsMenu._input owns flat rebind capture while listening.
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _prop_radial_active:
			_prop_radial_vector = radial_vector_from_motion(
					_prop_radial_vector, (event as InputEventMouseMotion).relative)
			return
		var sens: float = MovementConfig.mouse_sensitivity
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.4, 1.4)
	elif event.is_action_pressed("prop_radial"):
		prop_radial_changed.emit(OFF_HAND, true)
	elif event.is_action_released("prop_radial"):
		prop_radial_changed.emit(OFF_HAND, false)
	elif event.is_action_pressed("prop_fire"):
		prop_fire_changed.emit(OFF_HAND, true)
	elif event.is_action_released("prop_fire"):
		prop_fire_changed.emit(OFF_HAND, false)
	elif event.is_action_pressed("fire"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not _pointer_over_ui():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			trigger_changed.emit(&"right_hand", true)
	elif event.is_action_released("fire"):
		trigger_changed.emit(&"right_hand", false)
	elif event.is_action_pressed("draw_toggle"):
		grip_changed.emit(&"right_hand", true)
	elif event.is_action_pressed("cock_hammer"):
		cock_pressed.emit(&"right_hand")
	elif event.is_action_pressed("reload"):
		reload_pressed.emit()
	elif event.is_action_pressed("toggle_debug"):
		menu_button_pressed.emit()


func _pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# Look + lean only — walk lives in _physics_process so move_and_slide sees world.
	rotation.y = _yaw
	camera.rotation.x = _pitch
	var lean_target := Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	_lean = lerpf(_lean, lean_target, clampf(10.0 * _delta, 0.0, 1.0))
	pivot.position.x = _lean * MovementConfig.lean_offset
	pivot.rotation.z = -_lean * deg_to_rad(MovementConfig.lean_angle)


func _physics_process(delta: float) -> void:
	# Walk in world XZ from look yaw (not local basis + local position). The
	# joiner's Player root is yawed 180° with EnemySpawn; mixing a world-facing
	# camera with parent-local motion inverted A/D (BUG-006).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var look_yaw := atan2(global_transform.basis.z.x, global_transform.basis.z.z)
	var wish := (Basis(Vector3.UP, look_yaw) * Vector3(input_dir.x, 0, input_dir.y)) \
			* MovementConfig.walk_speed * _move_speed_mult()
	velocity.x = wish.x
	velocity.z = wish.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Stick to ramps / boardwalks instead of launching off lips.
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

	# Drive MOVEMENT slow-mo mode from walk + lean speed.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if real_delta > 0.0:
		var horizontal := Vector3(velocity.x, 0.0, velocity.z).length()
		TimeManager.report_player_motion(horizontal)


## Face a world-space yaw (radians). The Player root already carries the spawn
## marker rotation, so this stores the *local* remainder — applying the marker
## yaw as local would double it (joiner 180°+180° = looking away).
func face_yaw(world_yaw: float) -> void:
	var parent_yaw := 0.0
	var parent_node := get_parent() as Node3D
	if parent_node != null:
		parent_yaw = parent_node.global_transform.basis.get_euler().y
	_yaw = wrapf(world_yaw - parent_yaw, -PI, PI)
	_pitch = 0.0
	rotation.y = _yaw


func _move_speed_mult() -> float:
	var player := GameManager.local_player
	if player != null:
		return player.move_speed_mult
	return 1.0
