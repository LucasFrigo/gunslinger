class_name BodyGib
extends RigidBody3D
## A chunk a hit knocked out: a lump of skin over flesh as one closed body, thrown
## along the shot. World-only collision on the ragdoll layer. Keeps a 30 Hz world-space
## track on game time for the replay and freezes once it settles, by the ragdoll's rule.
## At most `gib_cap` live at once; the oldest goes first. It lives under the scenario, so
## a new duel, the menu, practice, or the mesh lab frees it; a horde wave does not.

## m/s of upward kick on top of the shot.
const GIB_LIFT := 1.2
const MASS := 0.25
const ANGULAR_DAMP := 3.0

static var _alive: Array = []

var _frames: Array[Transform3D] = []
var _times := PackedFloat32Array()
var _elapsed := 0.0
var _still := 0.0
var _track_clock := 0.0
var _settled := false


## A live gib under `parent` at `xf`. Null when `gib_cap` is below 1. `view_scale` sizes
## the mesh only; `shape` and `shape_offset` are already at that size.
static func spawn(parent: Node, mesh: Mesh, skin_material: Material, shape: Shape3D,
		shape_offset: Vector3, xf: Transform3D, velocity: Vector3, spin: Vector3,
		view_scale := 1.0) -> BodyGib:
	var cap := int(GameManager.tuning.get("gib_cap", 16.0))
	if parent == null or cap < 1:
		return null
	_prune()
	while _alive.size() >= cap:
		var oldest: Variant = _alive.pop_front()
		if is_instance_valid(oldest):
			(oldest as Node).queue_free()
	var gib := make(mesh, skin_material, shape, shape_offset, view_scale)
	parent.add_child(gib)
	gib.global_transform = xf
	gib.linear_velocity = velocity
	gib.angular_velocity = spin
	for wall in gib.get_tree().get_nodes_in_group(BodyRagdoll.IGNORE_GROUP):
		gib.add_collision_exception_with(wall as PhysicsBody3D)
	gib._record()
	_alive.append(gib)
	return gib


## The body and its view, not yet in the tree and not counted toward the cap.
static func make(mesh: Mesh, skin_material: Material, shape: Shape3D, shape_offset: Vector3,
		view_scale := 1.0) -> BodyGib:
	var gib := BodyGib.new()
	gib.name = "BodyGib"
	gib.mass = MASS
	gib.collision_layer = BodyRagdoll.COLLISION_LAYER
	gib.collision_mask = BodyRagdoll.WORLD_MASK
	gib.continuous_cd = true
	gib.linear_damp = BodyRagdoll.LINEAR_DAMP
	gib.angular_damp = ANGULAR_DAMP
	gib.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	gib.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	gib.center_of_mass = shape_offset
	var material := PhysicsMaterial.new()
	material.friction = BodyRagdoll.FRICTION
	gib.physics_material_override = material
	var view := MeshInstance3D.new()
	view.name = "View"
	view.mesh = mesh
	view.scale = Vector3.ONE * view_scale
	view.set_surface_override_material(0, skin_material)
	gib.add_child(view)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = shape_offset
	gib.add_child(collider)
	return gib


static func free_all() -> void:
	for gib: Variant in _alive:
		if is_instance_valid(gib):
			(gib as Node).queue_free()
	_alive.clear()


## Gibs counted toward the cap that are still alive and not on their way out.
static func alive_count() -> int:
	_prune()
	return _alive.size()


static func _prune() -> void:
	for i in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]) or (_alive[i] as Node).is_queued_for_deletion():
			_alive.remove_at(i)


func is_settled() -> bool:
	return _settled


## Stop now and keep where it is as the track's last frame.
func settle() -> void:
	if _settled:
		return
	_settled = true
	_record()
	freeze = true
	set_physics_process(false)


## Replay start: settle and hide until the chunk's clip time.
func replay_hide() -> void:
	settle()
	visible = false


## Replay: `t` seconds into the recorded flight.
func replay_at(t: float) -> void:
	visible = true
	global_transform = track_at(t)


func hold_final() -> void:
	visible = true
	global_transform = track_at(track_length())


func track_length() -> float:
	return _times[_times.size() - 1] if not _times.is_empty() else 0.0


## World transform at `t` seconds into the flight. Clamped to the ends.
func track_at(t: float) -> Transform3D:
	if _frames.is_empty():
		return global_transform
	var at := clampf(t, 0.0, track_length())
	var hi := mini(_times.bsearch(at), _times.size() - 1)
	var lo := maxi(hi - 1, 0)
	var span := _times[hi] - _times[lo]
	var weight := clampf((at - _times[lo]) / span, 0.0, 1.0) if span > 0.0001 else 1.0
	var from := _frames[lo]
	var to := _frames[hi]
	var basis := Basis(from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), weight))
	return Transform3D(basis, from.origin.lerp(to.origin, weight))


func _physics_process(delta: float) -> void:
	if _settled:
		return
	_still = _still + delta if linear_velocity.length() < _tune("ragdoll_settle_speed", 0.12) else 0.0
	_elapsed += delta
	_track_clock += delta
	if _track_clock >= BodyRagdoll.TRACK_STEP - 0.0001:
		_track_clock -= BodyRagdoll.TRACK_STEP
		_record()
	if _elapsed >= BodyRagdoll.SETTLE_MIN_TIME and (_still >= BodyRagdoll.SETTLE_HOLD \
			or _elapsed >= _tune("ragdoll_max_time", 3.5)):
		settle()


func _record() -> void:
	_frames.append(global_transform)
	_times.append(_elapsed)


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))
