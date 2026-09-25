class_name OffhandProp
extends Node3D
## Shared seat / charge / attach API for miscellaneous off-hand props.
## `PropController` talks only to this surface. Held meshes stay shapeless.

signal caught

## How far a charging prop draws back along its own axis at full charge.
const CHARGE_PULL := 0.05
## Wrist cock at full charge.
const CHARGE_TILT_DEG := 20.0

var _attach: Node3D
var _charge := 0.0


func is_flying() -> bool:
	return false


func is_charging() -> bool:
	return false


## True while the prop is a loose physics object in the world.
func is_loose() -> bool:
	return false


## Seated on the attach (held or winding up), not in the world.
func is_in_hand() -> bool:
	return not is_flying() and not is_loose()


## Cigarette mid-boomerang owns the hand; a coin/ace on the ground does not.
func blocks_radial() -> bool:
	return is_flying()


func can_pick_up() -> bool:
	return is_loose()


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


## Flat vs VR: subclasses that balance or flip use this.
func configure_for_rig(_use_vr: bool) -> void:
	pass


## Coin flips on the press; cigarette / ace wait for release.
func flips_on_press() -> bool:
	return false


func charge_ratio() -> float:
	return _charge


## Seat on a hand (or mouth) attach. Subclasses reset their own flight state.
func hold_at(attach: Node3D) -> void:
	_attach = attach
	_charge = 0.0
	if attach == null:
		return
	if is_inside_tree() and get_parent() != attach:
		reparent(attach, false)
	transform = Transform3D.IDENTITY


## Retarget without disturbing a prop that is mid-flight.
func set_attach(attach: Node3D) -> void:
	if attach == null or attach == _attach:
		return
	_attach = attach
	if is_flying() or not is_inside_tree():
		return
	if get_parent() != attach:
		reparent(attach, false)
	transform = Transform3D.IDENTITY


func begin_charge() -> void:
	pass


func release_charge(_world: Node, _direction: Vector3) -> void:
	pass


func cancel_charge() -> void:
	if is_charging() and _attach != null:
		hold_at(_attach)


func recall() -> void:
	if _attach != null:
		hold_at(_attach)


func _tune(key: String, fallback: float) -> float:
	return tune(key, fallback)


static func tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))


func _wind_up_pose(delta: float) -> void:
	var charge_time := maxf(_tune("cig_charge_time", 1.0), 0.05)
	_charge = clampf(_charge + delta / maxf(Engine.time_scale, 0.001) / charge_time, 0.0, 1.0)
	transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(CHARGE_TILT_DEG) * _charge),
		Vector3(0.0, CHARGE_PULL * _charge, 0.0))


func _reparent_to_world(world: Node) -> void:
	var pose := global_transform
	reparent(world, true)
	global_transform = pose


## Orthonormal basis whose +Y runs along `y_axis`.
static func basis_along(y_axis: Vector3) -> Basis:
	var up := y_axis.normalized()
	if up.length_squared() < 0.0001:
		return Basis.IDENTITY
	var reference := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(up).normalized()
	return Basis(x, up, x.cross(up))
