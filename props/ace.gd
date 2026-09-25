class_name AceOfSpades
extends RigidBody3D
## Off-hand prop. Same hold-to-charge throw as the cigarette, then this rigid
## body bounces, rests, and can be picked up again. Held mesh stays shapeless.

enum State { HELD, CHARGING, LOOSE }

const LOST_Y := -10.0
const LAYER := 1 << 6
const LAYER_WORLD := 1
const AIRBORNE_SPEED := 0.4
const CHARGE_PULL := 0.05
const CHARGE_TILT_DEG := 20.0

var state: int = State.HELD
var _attach: Node3D
var _charge := 0.0


static func spawn_held(attach: Node3D) -> AceOfSpades:
	var scene := preload("res://props/ace.tscn")
	var ace: AceOfSpades = scene.instantiate()
	attach.add_child(ace)
	ace.hold_at(attach)
	return ace


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


func configure_for_rig(_use_vr: bool) -> void:
	pass


func flips_on_press() -> bool:
	return false


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


func hold_at(attach: Node3D) -> void:
	_attach = attach
	_charge = 0.0
	state = State.HELD
	if attach != null and is_inside_tree() and get_parent() != attach:
		reparent(attach, false)
	transform = Transform3D.IDENTITY
	_hold_body()


func set_attach(attach: Node3D) -> void:
	if attach == null or attach == _attach:
		return
	_attach = attach
	if state == State.LOOSE:
		return
	if get_parent() != attach:
		reparent(attach, false)
	transform = Transform3D.IDENTITY


func begin_charge() -> void:
	if state != State.HELD or _attach == null:
		return
	_charge = 0.0
	state = State.CHARGING


func release_charge(world: Node, direction: Vector3) -> void:
	if state != State.CHARGING:
		return
	if world == null or direction.length_squared() < 0.0001:
		cancel_charge()
		return
	var pose := global_transform
	reparent(world, true)
	global_transform = pose
	_release_body()
	var dir := direction.normalized()
	var speed := maxf(OffhandProp.tune("cig_speed", 9.0), 0.1) * lerpf(0.45, 1.0, _charge)
	linear_velocity = dir * speed + Vector3.UP * (0.6 + _charge * 0.8)
	var axis := dir.cross(Vector3.UP)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	angular_velocity = axis.normalized() * OffhandProp.tune("cig_spin", 38.0)
	state = State.LOOSE
	reset_physics_interpolation()


func cancel_charge() -> void:
	if state != State.CHARGING:
		return
	hold_at(_attach)


func recall() -> void:
	if state == State.LOOSE and _attach != null:
		hold_at(_attach)


func _physics_process(delta: float) -> void:
	if state == State.HELD:
		return
	if state == State.CHARGING:
		if not is_instance_valid(_attach):
			queue_free()
			return
		var charge_time := maxf(OffhandProp.tune("cig_charge_time", 1.0), 0.05)
		_charge = clampf(_charge + delta / maxf(Engine.time_scale, 0.001) / charge_time, 0.0, 1.0)
		transform = Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(CHARGE_TILT_DEG) * _charge),
			Vector3(0.0, CHARGE_PULL * _charge, 0.0))
		return
	if global_position.y < LOST_Y:
		queue_free()
		return
	PropFlight.snap_out_of_ground(self, 0.008)


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
