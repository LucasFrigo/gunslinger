class_name Cigarette
extends Node3D
## Off-hand prop. Rides a hand attach while held. Holding the throw button winds
## it back and charges the range; releasing flicks it out in a straight line
## along the hand's forward (bend that with `cig_curve`), it hangs spinning at
## the far end for whatever is left of `cig_flight_time`, then homes back to the
## attach and re-parents on catch. The imported mesh runs along local +Y
## (`assets/models/props/msc_cigarette.glb`), filter end toward the player. No
## collision shape -- it must never block the `ReloadProbe` / belt overlaps.

signal caught

enum State { HELD, CHARGING, OUTBOUND, HOVERING, RETURNING }

## Snap back to the hand if a flight somehow never resolves.
const FLIGHT_TIMEOUT := 8.0
## How far the cig draws back along its own axis at full charge.
const CHARGE_PULL := 0.05
## Wrist cock at full charge.
const CHARGE_TILT_DEG := 20.0

var state: int = State.HELD

var _attach: Node3D
var _direction := Vector3.FORWARD
var _charge := 0.0
var _travelled := 0.0
var _turnaround := 0.0
var _hover_left := 0.0
var _spin_angle := 0.0
var _flight_time := 0.0


static func spawn_held(attach: Node3D) -> Cigarette:
	var scene := preload("res://props/cigarette.tscn")
	var cig: Cigarette = scene.instantiate()
	attach.add_child(cig)
	cig.hold_at(attach)
	return cig


func is_flying() -> bool:
	return state == State.OUTBOUND or state == State.HOVERING or state == State.RETURNING


func is_charging() -> bool:
	return state == State.CHARGING


## 0 → 1 windup, the fraction of `cig_max_range` the next throw will cover.
func charge_ratio() -> float:
	return _charge


## Seat on a hand attach. Also used when the revolver swaps hands or when VR
## reload parks the cig at the mouth.
func hold_at(attach: Node3D) -> void:
	_attach = attach
	state = State.HELD
	_charge = 0.0
	_spin_angle = 0.0
	if get_parent() != attach:
		reparent(attach, false)
	transform = Transform3D.IDENTITY


## Retarget without disturbing a cig that is mid-flight.
func set_attach(attach: Node3D) -> void:
	if attach == null or attach == _attach:
		return
	_attach = attach
	if state == State.OUTBOUND or state == State.RETURNING:
		return
	if get_parent() != attach:
		reparent(attach, false)
	# A charging cig re-applies its windup on the next frame.
	transform = Transform3D.IDENTITY


func begin_charge() -> void:
	if state != State.HELD or _attach == null:
		return
	_charge = 0.0
	state = State.CHARGING


## Throw released: range scales with how long the button was held.
func release_charge(world: Node, direction: Vector3) -> void:
	if state != State.CHARGING:
		return
	if world == null or direction.length_squared() < 0.0001:
		cancel_charge()
		return
	var pose := global_transform
	reparent(world, true)
	global_transform = pose
	_direction = direction.normalized()
	_turnaround = lerpf(_tune("cig_min_range", 1.2), _tune("cig_max_range", 6.0), _charge)
	# Every throw lasts `cig_flight_time`: a short one simply hangs there
	# spinning for longer before it turns around.
	var speed := maxf(_tune("cig_speed", 9.0), 0.1)
	_hover_left = maxf(_tune("cig_flight_time", 1.5) - 2.0 * _turnaround / speed, 0.0)
	_travelled = 0.0
	_flight_time = 0.0
	state = State.OUTBOUND


## Drop the windup without throwing (pause, death, prop swapped away).
func cancel_charge() -> void:
	if state != State.CHARGING:
		return
	hold_at(_attach)


## Force the cig back into the hand (duel reset, stuck flight).
func recall() -> void:
	if state != State.HELD:
		_catch()


func _physics_process(delta: float) -> void:
	if state == State.HELD:
		return
	if not is_instance_valid(_attach):
		queue_free()
		return
	if state == State.CHARGING:
		_wind_up(delta)
		return
	_flight_time += delta / maxf(Engine.time_scale, 0.001)
	if _flight_time >= FLIGHT_TIMEOUT:
		_catch()
		return
	var speed := maxf(_tune("cig_speed", 9.0), 0.1)
	match state:
		State.OUTBOUND:
			_fly_outbound(delta, speed)
		State.HOVERING:
			_hover(delta)
		_:
			_fly_home(delta, speed)
	if state == State.HELD:
		return
	_spin_angle = wrapf(_spin_angle + _tune("cig_spin", 38.0) * delta, -PI, PI)
	global_basis = _flight_basis()


## Draw back along the cig's own axis and cock the wrist while the button is
## held, so the charge is readable without any HUD.
func _wind_up(delta: float) -> void:
	var charge_time := maxf(_tune("cig_charge_time", 1.0), 0.05)
	_charge = clampf(_charge + delta / maxf(Engine.time_scale, 0.001) / charge_time, 0.0, 1.0)
	transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(CHARGE_TILT_DEG) * _charge),
		Vector3(0.0, CHARGE_PULL * _charge, 0.0))


func _fly_outbound(delta: float, speed: float) -> void:
	var curve := _tune("cig_curve", 0.0)
	if not is_zero_approx(curve):
		_direction = _direction.rotated(Vector3.UP, curve * delta).normalized()
	var step := speed * delta
	global_position += _direction * step
	_travelled += step
	if _travelled >= _turnaround:
		state = State.HOVERING if _hover_left > 0.0 else State.RETURNING


## Hang at the far end, still spinning, so a tap and a full throw take the same
## time overall.
func _hover(delta: float) -> void:
	_hover_left -= delta
	if _hover_left <= 0.0:
		state = State.RETURNING


func _fly_home(delta: float, speed: float) -> void:
	var to_hand := _attach.global_position - global_position
	var distance := to_hand.length()
	if distance <= maxf(_tune("cig_catch_radius", 0.28), 0.01):
		_catch()
		return
	_direction = to_hand / distance
	global_position += _direction * minf(speed * delta, distance)


func _catch() -> void:
	hold_at(_attach)
	caught.emit()


## `cig_spin_axis` 1 (the default) sweeps the cig around its middle like a
## thrown baton; 0 rolls it around its own length, which is near-invisible on a
## mesh this symmetric. The spin never damps -- it stops only on catch.
func _flight_basis() -> Basis:
	if int(_tune("cig_spin_axis", 0.0)) == 1:
		return _basis_along(_direction.rotated(Vector3.UP, _spin_angle))
	return _basis_along(_direction).rotated(_direction, _spin_angle)


## Orthonormal basis whose +Y (the cig's long axis) runs along `y_axis`.
func _basis_along(y_axis: Vector3) -> Basis:
	var up := y_axis.normalized()
	var reference := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(up).normalized()
	return Basis(x, up, x.cross(up))


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))
