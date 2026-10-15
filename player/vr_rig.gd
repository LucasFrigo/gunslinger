class_name VRRig
extends XROrigin3D
## VR rig: OpenXR camera + controllers, laser pointer for 3D UI panels,
## continuous thumbstick locomotion (left stick move, right stick turn;
## the right stick scrolls instead while the laser is on a scrollable window),
## and physical + stick motion reporting for the Superhot slow-mo mode.
## Combat buttons dispatch through PlayerSettings bind table.
## Controller box meshes stay hidden. The mannequin hands are the visible hands.

signal trigger_changed(hand: StringName, pressed: bool)
signal grip_changed(hand: StringName, pressed: bool)
signal cock_pressed(hand: StringName)
signal gate_pressed(hand: StringName)
signal trick_shot_changed(hand: StringName, pressed: bool)
signal prop_radial_changed(hand: StringName, pressed: bool)
signal menu_button_pressed

const HAND_LEFT := &"left_hand"
const HAND_RIGHT := &"right_hand"
const POINTER_LENGTH := 6.0
## Below this, camera Y is still the identity pose and must not shift the origin.
const MIN_TRACKED_HEAD_Y := 0.05
## Stick-walk body: flat's capsule radius, raised off the floor so lips and seams don't snag.
const STICK_BODY_RADIUS := 0.28
const STICK_STEP_CLEARANCE := 0.35
const STICK_BODY_TOP := 1.6
const STICK_SLIDE_PASSES := 2
const WORLD_LAYER := 1
const DIGITAL_SOURCES: Array[String] = [
	"trigger_click",
	"grip_click",
	"ax_button",
	"by_button",
	"primary_click",
]

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand
@onready var pointer_ray: RayCast3D = $RightHand/PointerRay
@onready var laser: MeshInstance3D = $RightHand/PointerRay/Laser

var _prev_head := Vector3.ZERO
var _prev_right := Vector3.ZERO
var _prev_left := Vector3.ZERO
var _prev_right_basis := Basis.IDENTITY
var _prev_left_basis := Basis.IDENTITY
var _motion_initialized := false
var _hands_motion_initialized := false
var _pointer_panel: UIPanel3D
var _trigger_down := false
var _snap_armed := true
var _yaw_offset := 0.0
## m/s of controller motion (real time), updated each frame.
var right_hand_speed := 0.0
var left_hand_speed := 0.0
var right_hand_velocity := Vector3.ZERO
var left_hand_velocity := Vector3.ZERO
var right_hand_angular_velocity := Vector3.ZERO
var left_hand_angular_velocity := Vector3.ZERO

## Stick-down edge / hold state per hand (cock edge + trick-shot analog).
var _stick_down_latched := {HAND_LEFT: false, HAND_RIGHT: false}
var _stick_trick_active := {HAND_LEFT: false, HAND_RIGHT: false}
## Hand whose stick is driving the prop radial, or empty when it is closed.
var _prop_radial_hand: StringName = &""
## True until a saved eye height has been written onto origin Y.
var _eye_height_pending := false
## True until the head has been put on the spawn marker (waits for tracking).
var _spawn_align_pending := false
var _stick_query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	left_hand.button_pressed.connect(_on_left_button.bind())
	left_hand.button_released.connect(_on_left_button_released.bind())
	right_hand.button_pressed.connect(_on_right_button.bind())
	right_hand.button_released.connect(_on_right_button_released.bind())
	if PlayerSettings.has_eye_height():
		_eye_height_pending = true


func get_head_transform() -> Transform3D:
	return camera.global_transform


## Headset is publishing a floor-relative pose, not the identity pose from boot.
## Godot 4.7 XRCamera3D is a Camera3D, not an XRNode3D, so it has no tracking
## query. The runtime leaves local Y at the scene origin until a pose arrives.
func headset_height_ready() -> bool:
	return camera != null and camera.position.y > MIN_TRACKED_HEAD_Y


## Eye height above the player root, including any origin Y already applied.
func measured_eye_height_m() -> float:
	var floor_y := 0.0
	var body := get_parent() as Node3D
	if body != null:
		floor_y = body.global_position.y
	return camera.global_position.y - floor_y


## One shot. Crouch and stand still move the headset after this.
## Returns false and stays pending when tracking has not arrived.
func apply_saved_eye_height() -> bool:
	if not PlayerSettings.has_eye_height():
		_eye_height_pending = false
		return false
	if not headset_height_ready():
		_eye_height_pending = true
		return false
	position.y = PlayerSettings.eye_height_meters() - camera.position.y
	_eye_height_pending = false
	return true


func get_left_hand_transform() -> Transform3D:
	return left_hand.global_transform


func get_right_hand_transform() -> Transform3D:
	return right_hand.global_transform


func get_hand_transform(hand: StringName) -> Transform3D:
	if hand == HAND_LEFT:
		return left_hand.global_transform
	return right_hand.global_transform


## Node the revolver attaches to when drawn. `hand` is `left_hand` or `right_hand`.
func get_gun_attach(hand: StringName = HAND_RIGHT) -> Node3D:
	if hand == HAND_LEFT:
		return $LeftHand/GunAttach
	return $RightHand/GunAttach


func get_wrist_attach() -> Node3D:
	return $LeftHand/WristAttach


func get_cartridge_attach(hand: StringName = HAND_LEFT) -> Node3D:
	if hand == HAND_RIGHT:
		return $RightHand/CartridgeAttach
	return $LeftHand/CartridgeAttach


func get_reload_probe(hand: StringName = HAND_LEFT) -> Area3D:
	if hand == HAND_RIGHT:
		return $RightHand/ReloadProbe as Area3D
	return $LeftHand/ReloadProbe as Area3D


## Where an equipped misc prop rides on the off hand.
func get_prop_attach(hand: StringName = HAND_LEFT) -> Node3D:
	if hand == HAND_RIGHT:
		return $RightHand/PropAttach
	return $LeftHand/PropAttach


## Parking spot for a prop while the off hand is busy with a belt cartridge.
func get_mouth_attach() -> Node3D:
	return $XRCamera3D/MouthAttach


## Practice-hub bottle hold: the controller itself (Player adds the grip offset).
func get_bottle_attach(hand: StringName = HAND_LEFT) -> Node3D:
	return get_hand_node(hand)


## The controller node itself, for hanging world-space UI off a hand.
func get_hand_node(hand: StringName) -> Node3D:
	return left_hand if hand == HAND_LEFT else right_hand


## Analog trigger squeeze, 0–1. Only valid while fire is bound to the trigger.
func trigger_amount(hand: StringName) -> float:
	var ctrl := get_hand_node(hand) as XRController3D
	if ctrl == null:
		return 0.0
	return clampf(ctrl.get_float(&"trigger"), 0.0, 1.0)


## While the prop radial is open, that stick is stolen from locomotion.
func set_prop_radial_active(active: bool, hand: StringName = &"") -> void:
	_prop_radial_hand = hand if active else &""


func get_prop_radial_vector() -> Vector2:
	if _prop_radial_hand == &"":
		return Vector2.ZERO
	return get_stick(_prop_radial_hand)


func hand_speed(hand: StringName) -> float:
	return left_hand_speed if hand == HAND_LEFT else right_hand_speed


func hand_velocity(hand: StringName) -> Vector3:
	return left_hand_velocity if hand == HAND_LEFT else right_hand_velocity


func hand_angular_velocity(hand: StringName) -> Vector3:
	return left_hand_angular_velocity if hand == HAND_LEFT else right_hand_angular_velocity


## Flat mode aims along the camera; VR aims along the muzzle.
func get_aim_override() -> Vector3:
	return Vector3.ZERO


## Called when a duel places the player at a spawn; clears stick locomotion and
## moves the origin so the HMD stands on the spawn looking along its -Z (BUG-024).
func reset_locomotion() -> void:
	position = Vector3.ZERO
	rotation.y = 0.0
	_yaw_offset = 0.0
	_snap_armed = true
	_motion_initialized = false
	_hands_motion_initialized = false
	right_hand_speed = 0.0
	left_hand_speed = 0.0
	right_hand_velocity = Vector3.ZERO
	left_hand_velocity = Vector3.ZERO
	right_hand_angular_velocity = Vector3.ZERO
	left_hand_angular_velocity = Vector3.ZERO
	_stick_down_latched[HAND_LEFT] = false
	_stick_down_latched[HAND_RIGHT] = false
	_stick_trick_active[HAND_LEFT] = false
	_stick_trick_active[HAND_RIGHT] = false
	_prop_radial_hand = &""
	_spawn_align_pending = true
	_align_to_spawn()
	# position = 0 above cleared any standing-height correction.
	apply_saved_eye_height()


## Yaw around the head, then shift XZ so the head is on the Player root (the spawn).
## The playspace offset would otherwise carry into the arena. Waits for tracking:
## the identity pose would align the wrong point.
func _align_to_spawn() -> bool:
	if not headset_height_ready():
		return false
	var body := get_parent() as Node3D
	if body == null:
		_spawn_align_pending = false
		return false
	var desired_yaw := body.global_basis.get_euler().y
	var head_yaw := camera.global_transform.basis.get_euler().y
	_rotate_around_head(wrapf(desired_yaw - head_yaw, -PI, PI))
	var head := camera.global_position
	global_position += Vector3(body.global_position.x - head.x, 0.0, body.global_position.z - head.z)
	_spawn_align_pending = false
	return true


func _process(delta: float) -> void:
	if _spawn_align_pending:
		_align_to_spawn()
	if _eye_height_pending:
		apply_saved_eye_height()
	_update_pointer()
	_apply_menu_scroll(delta)
	if GameManager.is_pause_open() or get_tree().paused:
		# Still poll stick-down while settings listen (pause / menu).
		_update_stick_binds()
		return
	var stick_speed := _apply_locomotion(delta)
	_update_hand_speeds(delta)
	_report_motion(delta, stick_speed)
	_update_stick_binds()


func get_stick(hand: StringName) -> Vector2:
	if hand == HAND_LEFT:
		return left_hand.get_vector2("primary")
	return right_hand.get_vector2("primary")


func _apply_locomotion(delta: float) -> float:
	if KillCam.is_playing or DeathCam.blocks_combat():
		if DeathCam.consumes_look():
			DeathCam.add_stick(right_hand.get_vector2("primary"), delta)
		return 0.0
	var move_input := _deadzone(left_hand.get_vector2("primary"), MovementConfig.stick_deadzone)
	if GameManager.in_mesh_lab() and not MeshLabMotion.walk:
		move_input = Vector2.ZERO
	var gun_hand := _held_gun_hand()
	# Steal gun-hand stick Y when a combat bind uses stick_down (cock or spin).
	if PlayerSettings.vr_uses_stick_down() and gun_hand == HAND_LEFT:
		move_input.y = 0.0
	# An open prop radial owns that stick outright.
	if _prop_radial_hand == HAND_LEFT:
		move_input = Vector2.ZERO
	var head_yaw := camera.global_transform.basis.get_euler().y
	var basis := Basis(Vector3.UP, head_yaw)
	# World XZ from HMD yaw, applied via global_position. Adding that vector to
	# local `position` under EnemySpawn's 180° Player yaw inverted strafe (BUG-006).
	var motion := (basis * Vector3(move_input.x, 0.0, -move_input.y)) \
			* MovementConfig.vr_move_speed * _move_speed_mult() * delta
	motion = collide_stick_motion(motion)
	global_position += motion

	var turn_input := right_hand.get_vector2("primary")
	if _prop_radial_hand == HAND_RIGHT or _menu_scroll_focused():
		turn_input = Vector2.ZERO
	_apply_turn(delta, turn_input)

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


## Stick step against world geometry: a capsule at the head's XZ slides along what
## it hits, like flat's move_and_slide. Room-scale walking is not checked, so a
## head already inside a wall keeps only the part of the step that leads out.
func collide_stick_motion(motion: Vector3) -> Vector3:
	var step := Vector3(motion.x, 0.0, motion.z)
	if step.is_zero_approx() or not is_inside_tree():
		return step
	var space := get_world_3d().direct_space_state
	var query := _stick_shape_query()
	var body := get_parent() as Node3D
	var floor_y := body.global_position.y if body != null else global_position.y
	var head := camera.global_position
	var start := Vector3(head.x, floor_y + (STICK_STEP_CLEARANCE + STICK_BODY_TOP) * 0.5, head.z)
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = Vector3.ZERO
	var overlap := space.get_rest_info(query)
	if not overlap.is_empty():
		return _strip_into(step, overlap.normal)
	var pos := start
	for i in STICK_SLIDE_PASSES:
		if step.is_zero_approx():
			break
		query.transform = Transform3D(Basis.IDENTITY, pos)
		query.motion = step
		var fractions := space.cast_motion(query)
		if fractions[1] >= 1.0:
			pos += step
			break
		var contact := pos + step * fractions[1]
		pos += step * fractions[0]
		var remaining := step * (1.0 - fractions[0])
		query.transform = Transform3D(Basis.IDENTITY, contact)
		query.motion = Vector3.ZERO
		var hit := space.get_rest_info(query)
		if hit.is_empty():
			break
		step = _strip_into(remaining, hit.normal)
	return pos - start


## Drop the part of `v` that pushes into a surface with normal `n` (XZ only).
## A floor or ceiling normal has no XZ part and leaves `v` alone.
func _strip_into(v: Vector3, n: Vector3) -> Vector3:
	var flat := Vector3(n.x, 0.0, n.z)
	if flat.is_zero_approx():
		return v
	flat = flat.normalized()
	return v - flat * minf(v.dot(flat), 0.0)


func _stick_shape_query() -> PhysicsShapeQueryParameters3D:
	if _stick_query == null:
		var capsule := CapsuleShape3D.new()
		capsule.radius = STICK_BODY_RADIUS
		capsule.height = STICK_BODY_TOP - STICK_STEP_CLEARANCE
		_stick_query = PhysicsShapeQueryParameters3D.new()
		_stick_query.shape = capsule
		_stick_query.collision_mask = WORLD_LAYER
	return _stick_query


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
	var right_basis := right_hand.global_transform.basis
	var left_basis := left_hand.global_transform.basis
	if _hands_motion_initialized and real_delta > 0.0:
		right_hand_velocity = (right_pos - _prev_right) / real_delta
		left_hand_velocity = (left_pos - _prev_left) / real_delta
		right_hand_speed = right_hand_velocity.length()
		left_hand_speed = left_hand_velocity.length()
		right_hand_angular_velocity = _angular_velocity(_prev_right_basis, right_basis, real_delta)
		left_hand_angular_velocity = _angular_velocity(_prev_left_basis, left_basis, real_delta)
	else:
		right_hand_speed = 0.0
		left_hand_speed = 0.0
		right_hand_velocity = Vector3.ZERO
		left_hand_velocity = Vector3.ZERO
		right_hand_angular_velocity = Vector3.ZERO
		left_hand_angular_velocity = Vector3.ZERO
	_prev_right = right_pos
	_prev_left = left_pos
	_prev_right_basis = right_basis
	_prev_left_basis = left_basis
	_hands_motion_initialized = true


func _angular_velocity(prev: Basis, current: Basis, dt: float) -> Vector3:
	if dt <= 0.0:
		return Vector3.ZERO
	var q := (current * prev.transposed()).get_rotation_quaternion()
	if q.w < 0.0:
		q = -q
	var xyz := Vector3(q.x, q.y, q.z)
	var xyz_len := xyz.length()
	if xyz_len < 0.00001:
		return Vector3.ZERO
	var angle := 2.0 * atan2(xyz_len, q.w)
	return xyz * (angle / (xyz_len * dt))


# -- Buttons -------------------------------------------------------------------

func _on_left_button(button: String) -> void:
	if button == "menu_button":
		if PlayerSettings.is_listening():
			PlayerSettings.cancel_listen()
			return
		menu_button_pressed.emit()
		return
	_dispatch_button(HAND_LEFT, button, true)


func _on_left_button_released(button: String) -> void:
	_dispatch_button(HAND_LEFT, button, false)


func _on_right_button(button: String) -> void:
	if button == "menu_button":
		if PlayerSettings.is_listening():
			PlayerSettings.cancel_listen()
			return
		menu_button_pressed.emit()
		return
	# UI laser always uses right trigger while pointing at a panel.
	if button == "trigger_click":
		_trigger_down = true
		if _pointer_panel != null:
			_pointer_panel.pointer_click(pointer_ray.get_collision_point(), true)
			return
	_dispatch_button(HAND_RIGHT, button, true)


func _on_right_button_released(button: String) -> void:
	if button == "trigger_click":
		if _trigger_down and _pointer_panel != null:
			_pointer_panel.pointer_click(pointer_ray.get_collision_point(), false)
			_trigger_down = false
			return
		_trigger_down = false
	_dispatch_button(HAND_RIGHT, button, false)


func _dispatch_button(hand: StringName, button: String, pressed: bool) -> void:
	if button not in DIGITAL_SOURCES:
		return
	if pressed and PlayerSettings.try_capture_vr_source(button):
		return
	if PlayerSettings.is_listening():
		return
	var action := _action_for_hand(hand, button)
	if action == &"":
		return
	if action == &"pause":
		if pressed:
			menu_button_pressed.emit()
		return
	_emit_action(hand, action, pressed)


## Stick click defaults to pause on the draw hand and the prop wheel on the off
## hand. A rebind keeps that split: the draw hand gets the non-radial action.
func _action_for_hand(hand: StringName, button: String) -> StringName:
	var actions := PlayerSettings.vr_actions_for_source(button)
	if actions.is_empty():
		return &""
	var draw_hand := _pause_hand()
	if hand == draw_hand:
		if &"pause" in actions:
			return &"pause"
		for action in actions:
			if action != &"prop_radial":
				return action
		return &""
	if &"prop_radial" in actions:
		return &"prop_radial"
	for action in actions:
		if action != &"pause":
			return action
	return &""


func _pause_hand() -> StringName:
	var player := GameManager.local_player
	if player != null and player.has_method("draw_hand_name"):
		return player.draw_hand_name()
	return HAND_RIGHT


func _emit_action(hand: StringName, action: StringName, pressed: bool) -> void:
	match action:
		&"fire":
			trigger_changed.emit(hand, pressed)
		&"grip":
			grip_changed.emit(hand, pressed)
		&"cock":
			if pressed:
				cock_pressed.emit(hand)
		&"gate":
			if pressed:
				gate_pressed.emit(hand)
		&"trick_shot":
			trick_shot_changed.emit(hand, pressed)
		&"prop_radial":
			prop_radial_changed.emit(hand, pressed)
		_:
			pass


func _update_stick_binds() -> void:
	var thresh := float(GameManager.tuning.get("spin_stick_threshold", 0.55))
	var gun_hand := _held_gun_hand()
	for hand in [HAND_LEFT, HAND_RIGHT]:
		var stick := get_stick(hand)
		if hand == HAND_RIGHT and _menu_scroll_focused():
			stick = Vector2.ZERO
		var down := stick.y <= -thresh
		var up := stick.y >= thresh
		var latched: bool = _stick_down_latched[hand]
		if down and not latched:
			_stick_down_latched[hand] = true
			if PlayerSettings.try_capture_vr_source("stick_down"):
				continue
			if PlayerSettings.is_listening():
				continue
			# Combat stick-down only on the hand holding the gun.
			if hand != gun_hand:
				continue
			_on_stick_down_edge(hand)
		elif not down and latched:
			_stick_down_latched[hand] = false
			if hand == gun_hand and not PlayerSettings.is_listening():
				_on_stick_down_release(hand)
		# Trick-shot on stick_down: hang while down, relock on stick up.
		if hand != gun_hand or PlayerSettings.is_listening():
			continue
		if PlayerSettings.get_vr_bind(&"trick_shot") != "stick_down":
			continue
		var active: bool = _stick_trick_active[hand]
		if down and not active:
			_stick_trick_active[hand] = true
			trick_shot_changed.emit(hand, true)
		elif up and active:
			_stick_trick_active[hand] = false
			trick_shot_changed.emit(hand, false)

func _on_stick_down_edge(hand: StringName) -> void:
	var cock_src := PlayerSettings.get_vr_bind(&"cock")
	var gate_src := PlayerSettings.get_vr_bind(&"gate")
	var fire_src := PlayerSettings.get_vr_bind(&"fire")
	var grip_src := PlayerSettings.get_vr_bind(&"grip")
	if cock_src == "stick_down":
		cock_pressed.emit(hand)
	elif gate_src == "stick_down":
		gate_pressed.emit(hand)
	elif fire_src == "stick_down":
		trigger_changed.emit(hand, true)
	elif grip_src == "stick_down":
		grip_changed.emit(hand, true)
	# trick_shot stick_down is handled as hold in _update_stick_binds


func _on_stick_down_release(hand: StringName) -> void:
	if PlayerSettings.get_vr_bind(&"fire") == "stick_down":
		trigger_changed.emit(hand, false)
	if PlayerSettings.get_vr_bind(&"grip") == "stick_down":
		grip_changed.emit(hand, false)


# -- UI laser pointer -----------------------------------------------------------

func _update_pointer() -> void:
	pointer_ray.force_raycast_update()
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
	if _pointer_panel != panel and _pointer_panel != null and _trigger_down:
		_pointer_panel.pointer_cancel()
	_pointer_panel = panel
	if panel != null:
		panel.pointer_move(hit_point)
		var distance := right_hand.global_position.distance_to(hit_point)
		laser.visible = true
		laser.scale = Vector3(1, 1, distance / POINTER_LENGTH)
		laser.position.z = -distance / 2.0
	else:
		laser.visible = false


## Laser is on a window that should take the turn stick.
func _menu_scroll_focused() -> bool:
	if _pointer_panel == null or not _pointer_panel.has_scroll_target():
		return false
	if _prop_radial_hand == HAND_RIGHT:
		return false
	if KillCam.is_playing or DeathCam.consumes_look():
		return false
	return true


func _apply_menu_scroll(delta: float) -> void:
	if not _menu_scroll_focused():
		return
	var stick := _deadzone(get_stick(HAND_RIGHT), MovementConfig.stick_deadzone)
	_pointer_panel.apply_stick_scroll(stick.y, delta)


func _move_speed_mult() -> float:
	var player := GameManager.local_player
	if player != null:
		return player.move_speed_mult
	return 1.0


func _held_gun_hand() -> StringName:
	var player := GameManager.local_player
	if player == null or not player.has_method("held_gun_hand"):
		return &""
	return player.held_gun_hand()
