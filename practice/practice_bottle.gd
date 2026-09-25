class_name PracticeBottle
extends RigidBody3D
## Practice-hub longneck (`assets/models/props/msc_longneck.glb`, origin at the
## base). Stands frozen on its rail pose until it is shot or picked up. While
## held, the mesh is parented to the hand (a frozen body that copies the attach
## every tick stutters against the camera) and the body stays on layer 7 so a
## shot still shatters it. Thrown, it simulates: a bullet always shatters it, a
## contact only when it was moving past `BREAK_SPEED` the frame before, and a
## fast bottle that hits another one breaks both. Broken bottles come back on
## their rail pose after `RESPAWN_DELAY`, never where they broke.

signal shattered(bottle: PracticeBottle)

enum State { HOME, HELD, LOOSE, BROKEN }

## Physics layer 7 (`practice_prop`). Bullets and the flat grab ray include it;
## the player capsules do not, so a bottle on the ground never blocks walking.
const LAYER := 1 << 6
const LAYER_WORLD := 1
const BREAK_SPEED := 3.5
const RESPAWN_DELAY := 2.0
const CENTER := Vector3(0.0, 0.115, 0.0)
## Lost bottles (off the ground plane, or far past the fence) go home uncounted.
const LOST_Y := -10.0
const LOST_DISTANCE := 80.0

var state: int = State.HOME

var _home := Transform3D.IDENTITY
var _attach: Node3D
var _hold_local := Transform3D.IDENTITY
var _prev_speed := 0.0
var _respawn_left := 0.0

@onready var _model: Node3D = $Model


func _ready() -> void:
	# Run after the flat camera so the collider catches this frame's look.
	process_priority = -20
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)


func set_home(xf: Transform3D) -> void:
	_home = xf
	go_home()


func home_transform() -> Transform3D:
	return _home


## Mid-height of the bottle, for reach and aim checks.
func center() -> Vector3:
	return global_transform * CENTER


func is_grabbable() -> bool:
	return state == State.HOME or state == State.LOOSE


func is_held_by(attach: Node3D) -> bool:
	return state == State.HELD and _attach == attach


func go_home() -> void:
	state = State.HOME
	_attach = null
	_respawn_left = 0.0
	_prev_speed = 0.0
	_restore_model()
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _home
	collision_layer = LAYER
	collision_mask = 0
	if _model != null:
		_model.visible = true


## Ride `attach` at `local` until thrown. False if it is broken or already held.
func hold(attach: Node3D, local: Transform3D) -> bool:
	if not is_grabbable() or attach == null:
		return false
	state = State.HELD
	_attach = attach
	_hold_local = local
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	# Stay on the bullet layer. Mask stays empty so the held bottle does not
	# push the player or the ground.
	collision_layer = LAYER
	collision_mask = 0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_park_model(attach, local)
	_follow()
	reset_physics_interpolation()
	return true


func throw(velocity: Vector3, spin: Vector3) -> void:
	if state != State.HELD:
		return
	_follow()
	_restore_model()
	state = State.LOOSE
	_attach = null
	freeze = false
	collision_layer = LAYER
	collision_mask = LAYER_WORLD | LAYER
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	sleeping = false
	linear_velocity = velocity
	angular_velocity = spin
	_prev_speed = velocity.length()
	reset_physics_interpolation()


## Called by `Bullet` on impact.
func take_bullet(point: Vector3, _direction: Vector3) -> void:
	shatter(point)


func shatter(at := Vector3.INF) -> void:
	if state == State.BROKEN:
		return
	var origin := center() if at == Vector3.INF else at
	state = State.BROKEN
	_attach = null
	_restore_model()
	_respawn_left = RESPAWN_DELAY
	if _model != null:
		_model.visible = false
	# Contact callbacks run while physics flushes; body state must wait.
	_disable_body.call_deferred()
	ImpactFeedback.glass_shatter(origin)
	shattered.emit(self)


func _disable_body() -> void:
	if state != State.BROKEN:
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0


func _process(_delta: float) -> void:
	# After the camera. A physics-rate copy of the hand is what stuttered on flat.
	if state == State.HELD:
		_follow()


func _physics_process(delta: float) -> void:
	match state:
		State.LOOSE:
			if global_position.y < LOST_Y or global_position.distance_to(_home.origin) > LOST_DISTANCE:
				go_home()
				return
			_prev_speed = linear_velocity.length()
		State.BROKEN:
			_respawn_left -= delta
			if _respawn_left <= 0.0:
				go_home()


func _follow() -> void:
	if not is_instance_valid(_attach):
		go_home()
		return
	global_transform = _attach.global_transform * _hold_local


## The mesh rides the hand as a plain node. The body still tracks for bullet hits.
func _park_model(attach: Node3D, local: Transform3D) -> void:
	if _model == null or _model.get_parent() == attach:
		return
	_model.reparent(attach)
	_model.transform = local


func _restore_model() -> void:
	if _model == null or _model.get_parent() == self:
		return
	_model.reparent(self)
	_model.transform = Transform3D.IDENTITY


func _on_body_entered(body: Node) -> void:
	if state != State.LOOSE or _prev_speed < BREAK_SPEED:
		return
	var other := body as PracticeBottle
	if other != null:
		other.shatter()
	shatter()
