class_name VRRig
extends XROrigin3D
## VR rig: OpenXR camera + controllers, laser pointer for 3D UI panels,
## continuous thumbstick locomotion (left stick move, right stick turn), and
## physical + stick motion reporting for the Superhot slow-mo mode.
## Placeholder hand meshes -- swap for real hand models under LeftHand /
## RightHand without touching this script.

signal trigger_changed(pressed: bool)
signal grip_pressed
signal left_grip_changed(pressed: bool)
signal cock_pressed
signal gate_pressed
signal menu_button_pressed

const POINTER_LENGTH := 6.0

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand
@onready var pointer_ray: RayCast3D = $RightHand/PointerRay
@onready var laser: MeshInstance3D = $RightHand/PointerRay/Laser

var _prev_head := Vector3.ZERO
var _prev_right := Vector3.ZERO
var _prev_left := Vector3.ZERO
var _motion_initialized := false
var _hands_motion_initialized := false
var _pointer_panel: UIPanel3D
var _trigger_down := false
var _snap_armed := true
var _yaw_offset := 0.0
## m/s of controller motion (real time), updated each frame.
var right_hand_speed := 0.0
var left_hand_speed := 0.0


func _ready() -> void:
	left_hand.button_pressed.connect(_on_left_button.bind())
	left_hand.button_released.connect(_on_left_button_released.bind())
	right_hand.button_pressed.connect(_on_right_button.bind())
	right_hand.button_released.connect(_on_right_button_released.bind())


func get_head_transform() -> Transform3D:
	return camera.global_transform


func get_left_hand_transform() -> Transform3D:
	return left_hand.global_transform


func get_right_hand_transform() -> Transform3D:
	return right_hand.global_transform


## Node the revolver attaches to when drawn.
func get_gun_attach() -> Node3D:
	return $RightHand/GunAttach


func get_wrist_attach() -> Node3D:
	return $LeftHand/WristAttach


func get_cartridge_attach() -> Node3D:
	return $LeftHand/CartridgeAttach


## Flat mode aims along the camera; VR aims along the muzzle.
func get_aim_override() -> Vector3:
	return Vector3.ZERO


## Called when a duel places the player at a spawn; clears artificial locomotion.
func reset_locomotion() -> void:
	position = Vector3.ZERO
	rotation.y = 0.0
	_yaw_offset = 0.0
	_snap_armed = true
	_motion_initialized = false
	_hands_motion_initialized = false
	right_hand_speed = 0.0
	left_hand_speed = 0.0


func _process(delta: float) -> void:
	var stick_speed := _apply_locomotion(delta)
	_update_hand_speeds(delta)
	_report_motion(delta, stick_speed)
	_update_pointer()


func _apply_locomotion(delta: float) -> float:
	var move_input := _deadzone(left_hand.get_vector2("primary"), MovementConfig.stick_deadzone)
	var head_yaw := camera.global_transform.basis.get_euler().y
	var basis := Basis(Vector3.UP, head_yaw)
	var motion := (basis * Vector3(move_input.x, 0.0, -move_input.y)) \
			* MovementConfig.vr_move_speed * _move_speed_mult() * delta
	position += motion

	_apply_turn(delta, right_hand.get_vector2("primary"))

	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if real_delta <= 0.0:
		return 0.0
	return motion.length() / real_delta


func _apply_turn(delta: float, stick: Vector2) -> void:
	match MovementConfig.turn_mode:
		MovementConfig.TurnMode.OFF:
			return
		MovementConfig.TurnMode.SMOOTH:
			if absf(stick.x) < MovementConfig.turn_deadzone:
				return
			var sign_x := signf(stick.x)
			var strength := (absf(stick.x) - MovementConfig.turn_deadzone) \
					/ maxf(1.0 - MovementConfig.turn_deadzone, 0.001)
			# Positive stick X → turn right → negative Y rotation in Godot.
			var yaw_delta := -deg_to_rad(MovementConfig.smooth_turn_speed) * strength * sign_x * delta
			_rotate_around_head(yaw_delta)
		MovementConfig.TurnMode.SNAP:
			if absf(stick.x) < MovementConfig.turn_deadzone:
				_snap_armed = true
				return
			if not _snap_armed:
				return
			_snap_armed = false
			_rotate_around_head(-deg_to_rad(MovementConfig.snap_turn_angle) * signf(stick.x))


## Rotate the XR origin around the camera's vertical axis so the head stays put.
func _rotate_around_head(yaw_delta: float) -> void:
	if is_zero_approx(yaw_delta):
		return
	var head_pos := camera.global_position
	var offset := global_position - head_pos
	offset = offset.rotated(Vector3.UP, yaw_delta)
	global_position = head_pos + offset
	rotation.y += yaw_delta
	_yaw_offset += yaw_delta


func _deadzone(v: Vector2, zone: float) -> Vector2:
	var mag := v.length()
	if mag < zone:
		return Vector2.ZERO
	var scaled := (mag - zone) / maxf(1.0 - zone, 0.001)
	return v.normalized() * clampf(scaled, 0.0, 1.0)


func _report_motion(delta: float, stick_speed: float) -> void:
	# Physical head/hand speed drives MOVEMENT (Superhot) slow-mo. Use real
	# (unscaled) time: the player's body is not affected by Engine.time_scale.
	# Stick locomotion is also reported so Superhot responds while sliding.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var head := camera.global_position
	var hand := right_hand.global_position
	var speed := stick_speed
	if _motion_initialized and real_delta > 0.0:
		speed += head.distance_to(_prev_head) / real_delta
		speed += right_hand_speed
	TimeManager.report_player_motion(speed)
	_prev_head = head
	_motion_initialized = true


func _update_hand_speeds(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var right_pos := right_hand.global_position
	var left_pos := left_hand.global_position
	if _hands_motion_initialized and real_delta > 0.0:
		right_hand_speed = right_pos.distance_to(_prev_right) / real_delta
		left_hand_speed = left_pos.distance_to(_prev_left) / real_delta
	else:
		right_hand_speed = 0.0
		left_hand_speed = 0.0
	_prev_right = right_pos
	_prev_left = left_pos
	_hands_motion_initialized = true


# -- Buttons -------------------------------------------------------------------

func _on_left_button(button: String) -> void:
	match button:
		"by_button", "menu_button":
			menu_button_pressed.emit()
		"grip_click":
			left_grip_changed.emit(true)


func _on_left_button_released(button: String) -> void:
	match button:
		"grip_click":
			left_grip_changed.emit(false)


func _on_right_button(button: String) -> void:
	match button:
		"trigger_click":
			_trigger_down = true
			if _pointer_panel != null:
				_pointer_panel.pointer_click(pointer_ray.get_collision_point(), true)
			else:
				trigger_changed.emit(true)
		"grip_click":
			grip_pressed.emit()
		"ax_button":
			cock_pressed.emit()
		"by_button":
			gate_pressed.emit()


func _on_right_button_released(button: String) -> void:
	match button:
		"trigger_click":
			if _trigger_down and _pointer_panel != null:
				_pointer_panel.pointer_click(pointer_ray.get_collision_point(), false)
			else:
				trigger_changed.emit(false)
			_trigger_down = false


# -- UI laser pointer -----------------------------------------------------------

func _update_pointer() -> void:
	var panel: UIPanel3D = null
	var hit_point := Vector3.ZERO
	if pointer_ray.is_colliding():
		var collider := pointer_ray.get_collider()
		if collider is Area3D:
			for candidate in get_tree().get_nodes_in_group(UIPanel3D.GROUP):
				if (candidate as UIPanel3D).owns_area(collider):
					panel = candidate
					hit_point = pointer_ray.get_collision_point()
					break
	_pointer_panel = panel
	if panel != null:
		panel.pointer_move(hit_point)
		var distance := right_hand.global_position.distance_to(hit_point)
		laser.visible = true
		laser.scale = Vector3(1, 1, distance / POINTER_LENGTH)
		laser.position.z = -distance / 2.0
	else:
		laser.visible = false


func _move_speed_mult() -> float:
	var player := GameManager.local_player
	if player != null:
		return player.move_speed_mult
	return 1.0
