class_name Coin
extends RigidBody3D
## Off-hand prop. Held mesh is shapeless. A tap of the throw bind flips it
## into a spin; on flat that toss is straight up so it can land heads or tails
## back on the hand, or miss and fall. Loose motion is this rigid body against
## world + bottles, so it rests on the floor instead of clipping through.
## VR still drops the coin if the palm tilts or the hand jerks.

signal caught

enum State { HELD, CHARGING, LOOSE }

const LOST_Y := -10.0
const LAYER := 1 << 6
const LAYER_WORLD := 1
const AIRBORNE_SPEED := 0.35

var state: int = State.HELD

## VR: drop when the palm tilts. Flat: stay seated until G flips it.
var balance_drop := false

var _attach: Node3D
var _charge := 0.0
var _prev_attach_pos := Vector3.ZERO
var _have_attach_pos := false
var _settle_frames := 0
## +1 seats silver tails up (the default hold). -1 seats gold heads up.
var _face := 1.0
var _toss_face := 0.0
var _forced_toss_face := 0.0
var _catch_locked_until_ms := 0
var _pending_linear := Vector3.ZERO
var _pending_angular := Vector3.ZERO
var _has_pending_launch := false


static func spawn_held(attach: Node3D) -> Coin:
	var scene := preload("res://props/coin.tscn")
	var coin: Coin = scene.instantiate()
	attach.add_child(coin)
	coin.hold_at(attach)
	return coin


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	_hold_body()


func is_flying() -> bool:
	return state == State.LOOSE and _airborne()


func is_charging() -> bool:
	return state == State.CHARGING


func is_loose() -> bool:
	return state == State.LOOSE


func is_in_hand() -> bool:
	return state == State.HELD or state == State.CHARGING


func blocks_radial() -> bool:
	return state == State.CHARGING


func can_pick_up() -> bool:
	return state == State.LOOSE


func charge_ratio() -> float:
	return _charge


func configure_for_rig(use_vr: bool) -> void:
	balance_drop = use_vr


func flips_on_press() -> bool:
	return true


func showing_heads() -> bool:
	return _face < 0.0


## Autotest / debug: next flip lands this face (`1` tails, `-1` heads).
func choose_toss_face(face: float) -> void:
	_forced_toss_face = 1.0 if face >= 0.0 else -1.0


func is_near(point: Vector3, radius: float) -> bool:
	return can_pick_up() and global_position.distance_to(point) <= radius


func is_along_ray(origin: Vector3, direction: Vector3, reach: float, radius: float) -> bool:
	if not can_pick_up():
		return false
	var to := global_position - origin
	var along := to.dot(direction)
	if along < 0.0 or along > reach:
		return false
	return (to - direction * along).length() <= radius


func hold_at(attach: Node3D, keep_face := false) -> void:
	if state == State.LOOSE and not keep_face:
		_face = _face_from_world()
	_toss_face = 0.0
	_has_pending_launch = false
	_attach = attach
	_charge = 0.0
	state = State.HELD
	_have_attach_pos = false
	_settle_frames = 2
	if attach != null and is_inside_tree() and get_parent() != attach:
		reparent(attach, false)
	_hold_body()
	_seat_on_palm()


func set_attach(attach: Node3D) -> void:
	if attach == null or attach == _attach:
		return
	_attach = attach
	if state == State.LOOSE:
		return
	if get_parent() != attach:
		reparent(attach, false)
	_seat_on_palm()


func begin_charge() -> void:
	if state != State.HELD or _attach == null:
		return
	_charge = 0.0
	state = State.CHARGING
	_seat_on_palm()


func release_charge(world: Node, direction: Vector3) -> void:
	if state != State.CHARGING:
		return
	if world == null:
		cancel_charge()
		return
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var pose := global_transform
	reparent(world, true)
	global_transform = pose
	_release_body()
	var speed := OffhandProp.tune("coin_speed", 4.0)
	var kick := OffhandProp.tune("coin_up", 3.5)
	if balance_drop:
		_pending_linear = dir * speed + Vector3.UP * kick
	else:
		_pending_linear = Vector3.UP * kick
	var axis := dir.cross(Vector3.UP)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	_toss_face = _forced_toss_face if not is_zero_approx(_forced_toss_face) \
			else (1.0 if randf() < 0.5 else -1.0)
	_forced_toss_face = 0.0
	var half_turns := 4 + (0 if is_equal_approx(_toss_face, _face) else 1)
	var flight := _expected_catch_s()
	var spin_sign := 1.0 if randf() < 0.5 else -1.0
	_pending_angular = axis.normalized() * (float(half_turns) * PI / flight) * spin_sign
	linear_velocity = _pending_linear
	angular_velocity = _pending_angular
	_has_pending_launch = true
	_catch_locked_until_ms = Time.get_ticks_msec() + 450
	state = State.LOOSE
	reset_physics_interpolation()


func cancel_charge() -> void:
	if state != State.CHARGING:
		return
	hold_at(_attach)


func recall() -> void:
	if state != State.HELD and _attach != null:
		hold_at(_attach)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_attach):
		if state == State.LOOSE and global_position.y < LOST_Y:
			queue_free()
		return
	_update_attach_sample()
	if state == State.CHARGING:
		_seat_on_palm()
		return
	if state == State.HELD:
		_held_tick()
		return
	if global_position.y < LOST_Y:
		queue_free()
		return
	PropFlight.snap_out_of_ground(self, 0.004)
	if _can_catch():
		_catch_on_face()


func _held_tick() -> void:
	if _settle_frames > 0:
		_settle_frames -= 1
		_seat_on_palm()
		return
	if balance_drop and not _palm_ready():
		_drop_from_palm()
		return
	_seat_on_palm()


func _drop_from_palm() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var pose := global_transform
	reparent(world, true)
	global_transform = pose
	_release_body()
	linear_velocity = _attach_velocity() + Vector3.DOWN * 0.4
	angular_velocity = Vector3.ZERO
	_catch_locked_until_ms = Time.get_ticks_msec() + 250
	state = State.LOOSE


func _catch_on_face() -> void:
	if not is_zero_approx(_toss_face):
		_face = _toss_face
	else:
		_face = _face_from_world()
	hold_at(_attach, true)
	caught.emit()


## +1 = tails up on the palm. Coin mesh +Y is heads.
func _face_from_world() -> float:
	return -1.0 if global_basis.y.dot(Vector3.UP) >= 0.0 else 1.0


func _expected_catch_s() -> float:
	var kick := OffhandProp.tune("coin_up", 3.5)
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	g = maxf(g, 0.1)
	var catch_h := 0.12
	var disc := kick * kick - 2.0 * g * catch_h
	if disc <= 0.0:
		return 2.0 * kick / g
	return (kick + sqrt(disc)) / g


func _integrate_forces(physics: PhysicsDirectBodyState3D) -> void:
	if not _has_pending_launch:
		return
	physics.linear_velocity = _pending_linear
	physics.angular_velocity = _pending_angular
	_has_pending_launch = false


func _can_catch() -> bool:
	if not is_instance_valid(_attach):
		return false
	if Time.get_ticks_msec() < _catch_locked_until_ms:
		return false
	if linear_velocity.y > 0.15:
		return false
	if balance_drop and not _palm_ready():
		return false
	var offset := global_position - _palm_origin()
	if offset.length() > maxf(OffhandProp.tune("coin_catch_radius", 0.2), 0.02):
		return false
	return offset.dot(_palm_up()) >= -0.03


func _palm_ready() -> bool:
	if not is_instance_valid(_attach):
		return false
	if _palm_up().dot(Vector3.UP) < OffhandProp.tune("coin_palm_dot", 0.75):
		return false
	return _attach_velocity().length() <= OffhandProp.tune("coin_hand_speed", 0.8)


func _palm_up() -> Vector3:
	if not is_instance_valid(_attach):
		return Vector3.UP
	return (-_attach.global_basis.z).normalized()


func _palm_origin() -> Vector3:
	return _attach.global_position


func _seat_on_palm() -> void:
	if not is_instance_valid(_attach) or get_parent() != _attach:
		return
	var y := Vector3(0.0, 0.0, -_face)
	var x := Vector3.RIGHT
	var z := x.cross(y)
	if z.length_squared() < 0.0001:
		x = Vector3.FORWARD
		z = x.cross(y)
	transform = Transform3D(Basis(x, y, z).orthonormalized(), Vector3.ZERO)


func _airborne() -> bool:
	return not sleeping and linear_velocity.length() > AIRBORNE_SPEED


func _hold_body() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	sleeping = true


func _release_body() -> void:
	freeze = false
	collision_layer = LAYER
	collision_mask = LAYER_WORLD | LAYER
	sleeping = false


func _on_body_entered(body: Node) -> void:
	if state != State.LOOSE:
		return
	PropFlight.shatter_body(body, global_position)


func _update_attach_sample() -> void:
	if not is_instance_valid(_attach):
		return
	var pos := _attach.global_position
	if not _have_attach_pos:
		_prev_attach_pos = pos
		_have_attach_pos = true


func _attach_velocity() -> Vector3:
	if not is_instance_valid(_attach):
		return Vector3.ZERO
	var pos := _attach.global_position
	var dt := get_physics_process_delta_time()
	var vel := Vector3.ZERO
	if _have_attach_pos and dt > 0.0001:
		vel = (pos - _prev_attach_pos) / dt
	_prev_attach_pos = pos
	_have_attach_pos = true
	return vel
