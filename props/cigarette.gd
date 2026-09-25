class_name Cigarette
extends OffhandProp
## Off-hand prop. Rides a hand attach while held. Holding the throw button winds
## it back and charges the range; releasing flicks it out in a straight line
## along the hand's forward (bend that with `cig_curve`), it hangs spinning at
## the far end for whatever is left of `cig_flight_time`, then homes back to the
## attach and re-parents on catch. The imported mesh runs along local +Y
## (`assets/models/props/msc_cigarette.glb`), filter end toward the player. No
## collision shape -- it must never block the `ReloadProbe` / belt overlaps.
## Flight raycasts world + practice bottles. Outbound: a solid skips the hover
## and heads home; a bottle shatters first. Return: bottles still shatter, but
## walls do not block the catch.

enum State { HELD, CHARGING, OUTBOUND, HOVERING, RETURNING }

## Snap back to the hand if a flight somehow never resolves.
const FLIGHT_TIMEOUT := 8.0

var state: int = State.HELD

var _direction := Vector3.FORWARD
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


func hold_at(attach: Node3D) -> void:
	super.hold_at(attach)
	state = State.HELD
	_spin_angle = 0.0


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
	_reparent_to_world(world)
	_direction = direction.normalized()
	_turnaround = lerpf(_tune("cig_min_range", 1.2), _tune("cig_max_range", 6.0), _charge)
	# Every throw lasts `cig_flight_time`: a short one simply hangs there
	# spinning for longer before it turns around.
	var speed := maxf(_tune("cig_speed", 9.0), 0.1)
	_hover_left = maxf(_tune("cig_flight_time", 1.5) - 2.0 * _turnaround / speed, 0.0)
	_travelled = 0.0
	_flight_time = 0.0
	state = State.OUTBOUND


func cancel_charge() -> void:
	if state != State.CHARGING:
		return
	hold_at(_attach)


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
		_wind_up_pose(delta)
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


func _fly_outbound(delta: float, speed: float) -> void:
	var curve := _tune("cig_curve", 0.0)
	if not is_zero_approx(curve):
		_direction = _direction.rotated(Vector3.UP, curve * delta).normalized()
	var step := speed * delta
	var from := global_position
	var to := from + _direction * step
	var hit := PropFlight.cast(get_world_3d(), from, to)
	if not hit.is_empty():
		global_position = hit.get("position", to)
		PropFlight.shatter_if_bottle(hit)
		state = State.RETURNING
		return
	global_position = to
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
	var step := minf(speed * delta, distance)
	var from := global_position
	var to := from + _direction * step
	var hit := PropFlight.cast(get_world_3d(), from, to)
	if PropFlight.shatter_if_bottle(hit):
		# Keep flying; the broken bottle is no longer in the way.
		global_position = hit.get("position", to)
		return
	global_position = to


func _catch() -> void:
	hold_at(_attach)
	caught.emit()


## `cig_spin_axis` 1 (the default) sweeps the cig around its middle like a
## thrown baton; 0 rolls it around its own length, which is near-invisible on a
## mesh this symmetric. The spin never damps -- it stops only on catch.
func _flight_basis() -> Basis:
	if int(_tune("cig_spin_axis", 0.0)) == 1:
		return basis_along(_direction.rotated(Vector3.UP, _spin_angle))
	return basis_along(_direction).rotated(_direction, _spin_angle)
