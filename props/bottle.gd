class_name Longneck
extends RigidBody3D
## Off-hand longneck. Charge throw matches the ace; shatter matches a practice
## bottle (glass VFX / sound) then this instance is gone. No rail respawn.

enum State { HELD, CHARGING, LOOSE }

const LOST_Y := -10.0
const LAYER := 1 << 6
const LAYER_WORLD := 1
const AIRBORNE_SPEED := 0.4
const CHARGE_PULL := 0.05
const CHARGE_TILT_DEG := 20.0
const CENTER := Vector3(0.0, 0.115, 0.0)
const SNAP_LIFT := 0.01
## PropAttach maps a child's +Y forward (cigarette). The longneck stands on +Y,
## so this turns it upright in the same seat.
const HOLD := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3.ZERO)

var state: int = State.HELD
var _attach: Node3D
var _charge := 0.0
var _prev_speed := 0.0
var _breaking := false

@onready var _model: Node3D = $Model


static func spawn_held(attach: Node3D) -> Longneck:
	var scene := preload("res://props/bottle.tscn")
	var bottle: Longneck = scene.instantiate()
	attach.add_child(bottle)
	bottle.hold_at(attach)
	return bottle


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	_hold_body()


func is_flying() -> bool:
	return state == State.LOOSE and not _breaking and _airborne()


func is_charging() -> bool:
	return state == State.CHARGING and not _breaking


func is_loose() -> bool:
	return state == State.LOOSE and not _breaking


func is_in_hand() -> bool:
	return not _breaking and (state == State.HELD or state == State.CHARGING)


func blocks_radial() -> bool:
	return state == State.CHARGING and not _breaking


func can_pick_up() -> bool:
	return state == State.LOOSE and not _breaking


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


func center() -> Vector3:
	return global_transform * CENTER


func hold_at(attach: Node3D) -> void:
	if _breaking:
		return
	_attach = attach
	_charge = 0.0
	_prev_speed = 0.0
	state = State.HELD
	if attach != null and is_inside_tree() and get_parent() != attach:
		reparent(attach, false)
	transform = HOLD
	_hold_body()


func set_attach(attach: Node3D) -> void:
	if attach == null or attach == _attach:
		return
	_attach = attach
	if state == State.LOOSE or _breaking:
		return
	if get_parent() != attach:
		reparent(attach, false)
	transform = HOLD


func begin_charge() -> void:
	if _breaking or state != State.HELD or _attach == null:
		return
	_charge = 0.0
	state = State.CHARGING


func release_charge(world: Node, direction: Vector3) -> void:
	if _breaking or state != State.CHARGING:
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
	_prev_speed = linear_velocity.length()
	state = State.LOOSE
	reset_physics_interpolation()


func cancel_charge() -> void:
	if state != State.CHARGING:
		return
	hold_at(_attach)


func recall() -> void:
	if state == State.LOOSE and not _breaking and _attach != null:
		hold_at(_attach)


func take_bullet(point: Vector3, _direction: Vector3) -> void:
	shatter(point)


func shatter(at := Vector3.INF) -> void:
	if _breaking:
		return
	_breaking = true
	var origin := center() if at == Vector3.INF else at
	if _model != null:
		_model.visible = false
	_disable_body.call_deferred()
	ImpactFeedback.glass_shatter(origin)


func _disable_body() -> void:
	if not is_instance_valid(self):
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	queue_free()


func _physics_process(delta: float) -> void:
	if _breaking:
		return
	if state == State.HELD:
		return
	if state == State.CHARGING:
		if not is_instance_valid(_attach):
			queue_free()
			return
		var charge_time := maxf(OffhandProp.tune("cig_charge_time", 1.0), 0.05)
		_charge = clampf(_charge + delta / maxf(Engine.time_scale, 0.001) / charge_time, 0.0, 1.0)
		# Charge is in attach space (draw back / cock) so the bottle stays upright.
		transform = Transform3D(
			Basis(Vector3.RIGHT, deg_to_rad(CHARGE_TILT_DEG) * _charge),
			Vector3(0.0, CHARGE_PULL * _charge, 0.0)) * HOLD
		return
	if global_position.y < LOST_Y:
		queue_free()
		return
	_prev_speed = linear_velocity.length()
	PropFlight.snap_out_of_ground(self, SNAP_LIFT)


func _airborne() -> bool:
	return not sleeping and linear_velocity.length() > AIRBORNE_SPEED


func _hold_body() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Stay on the bullet layer so a held or charging bottle still shatters.
	collision_layer = LAYER
	collision_mask = 0
	sleeping = true


func _release_body() -> void:
	freeze = false
	collision_layer = LAYER
	collision_mask = LAYER_WORLD | LAYER
	sleeping = false


func _on_body_entered(body: Node) -> void:
	if _breaking or state != State.LOOSE or _prev_speed < PracticeBottle.BREAK_SPEED:
		return
	PropFlight.shatter_body(body)
	shatter()
