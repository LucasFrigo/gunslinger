class_name BodyRagdoll
extends Node
## Plain rigid bodies and joints that drop a dead `DummyBody`. A `PhysicalBoneSimulator3D`
## would need a SkeletonModifier3D tick this imported skeleton does not give (see
## `dummy_arm_ik.gd`), so bodies are built from the posed bones and a writer puts the
## bones back after the fingers (`DummyBody.RAGDOLL_PRIORITY`), parent first.
## Bodies collide with the world only. They are freed when the fall settles; the fall is
## kept as a track (skeleton-space bone poses at 30 Hz of game time) for the replay.
## A bone with no body (Head, Hand, Foot, fingers) keeps its local pose under its parent.
## An entry whose bone name ends in "." is built for both sides (`.L`, `.R`).

enum State { NONE, SIMULATING, RETRACE, TRACK, HELD }
enum JointKind { NONE, CONE, HINGE }

## Physics layer 8, "ragdoll". Nothing else masks it.
const COLLISION_LAYER := 1 << 7
const WORLD_MASK := 1
## Static bodies in this group (invisible guard walls) never touch a ragdoll.
const IGNORE_GROUP := &"ragdoll_ignore"
const TRACK_STEP := 1.0 / 30.0
## Every body slower than the settle speed for this long ends the fall.
const SETTLE_HOLD := 0.4
## Standing still on the first ticks is not settling.
const SETTLE_MIN_TIME := 0.5
const LINEAR_DAMP := 0.1
const FRICTION := 0.9
## Limit correction per step on the cone joints (engine default 0.3). The kill-cam slow-mo
## scales the physics step, and at 0.3 the limits blow the body apart when it speeds back up.
const CONE_BIAS := 0.1
## A thin limb has almost no inertia about its own axis, and the joint limits spin it
## apart. Inertia is figured as if the body were at least this thick.
const INERTIA_RADIUS := 0.1
## Hinge limits are signed about `DummyBody.hinge_axis`, which swings the bone toward the face.
const BODIES := [
	{"bone": &"Hips", "end": &"Spine", "reach": 0.0, "radius": 0.15, "mass": 12.0},
	{"bone": &"Spine", "end": &"Chest", "reach": 0.0, "radius": 0.14, "mass": 8.0,
			"parent": &"Hips", "joint": JointKind.CONE, "swing": 20.0, "twist": 15.0},
	{"bone": &"Chest", "end": &"Neck", "reach": 0.0, "radius": 0.16, "mass": 14.0,
			"parent": &"Spine", "joint": JointKind.CONE, "swing": 20.0, "twist": 15.0},
	{"bone": &"Neck", "end": &"Head", "reach": 0.145, "radius": 0.11, "mass": 6.0,
			"parent": &"Chest", "joint": JointKind.CONE, "swing": 40.0, "twist": 45.0},
	{"bone": &"UpperArm.", "end": &"Forearm.", "reach": 0.0, "radius": BodyHitboxes.UPPER_ARM_RADIUS,
			"mass": 2.5, "parent": &"Chest", "joint": JointKind.CONE, "swing": 85.0, "twist": 45.0},
	{"bone": &"Forearm.", "end": &"Hand.", "reach": 0.06, "radius": BodyHitboxes.FOREARM_RADIUS,
			"mass": 2.0, "parent": &"UpperArm.", "joint": JointKind.HINGE, "lower": 0.0, "upper": 140.0},
	{"bone": &"UpperLeg.", "end": &"LowerLeg.", "reach": 0.0, "radius": BodyHitboxes.THIGH_RADIUS,
			"mass": 9.0, "parent": &"Hips", "joint": JointKind.CONE, "swing": 60.0, "twist": 20.0},
	{"bone": &"LowerLeg.", "end": &"Foot.", "reach": BodyHitboxes.SOLE_REACH, "radius": BodyHitboxes.SHIN_RADIUS,
			"mass": 5.0, "parent": &"UpperLeg.", "joint": JointKind.HINGE, "lower": -140.0, "upper": 0.0},
]
## Bodies that take the torso shove, split by mass.
const TORSO_BONES: Array[StringName] = [&"Hips", &"Spine", &"Chest"]

var state: State = State.NONE

var _body: DummyBody
var _skeleton: Skeleton3D
var _ok := false
var _specs: Array[Dictionary] = []
var _bodies: Array[RigidBody3D] = []
var _joints: Array[Joint3D] = []
var _offsets: Array[Transform3D] = []
var _prev: Array[Transform3D] = []
var _curr: Array[Transform3D] = []
var _frames: Array = []
var _times := PackedFloat32Array()
var _elapsed := 0.0
var _still := 0.0
var _track_clock := 0.0
var _ticks := 0
## The shot waits one physics step: a body's mass properties only exist after its first step.
var _shot := false
var _shot_hit := Vector3.ZERO
var _shot_dir := Vector3.ZERO


func setup(body: DummyBody, skeleton: Skeleton3D) -> void:
	_body = body
	_skeleton = skeleton
	for spec: Dictionary in BODIES:
		for suffix: String in (["L", "R"] if String(spec["bone"]).ends_with(".") else [""]):
			var bone := _bone_name(spec["bone"], suffix)
			if skeleton.find_bone(bone) < 0:
				push_error("BodyRagdoll missing bone %s" % bone)
				return
			var built := spec.duplicate()
			built["name"] = bone
			built["suffix"] = suffix
			built["bone_index"] = skeleton.find_bone(bone)
			_specs.append(built)
	_ok = true
	set_process(false)
	set_physics_process(false)


## The ragdoll or its held pose has the skeleton. `DummyBody` ignores pose writers then.
func owns_skeleton() -> bool:
	return state == State.SIMULATING or state == State.TRACK or state == State.HELD


func has_track() -> bool:
	return not _frames.is_empty()


func track_length() -> float:
	return _times[_times.size() - 1] if not _times.is_empty() else 0.0


## `trail` is the killing bullet's points. The last segment gives the shot; fewer than
## two points leave the body to gravity.
func collapse(trail: PackedVector3Array) -> void:
	if not _ok or state != State.NONE:
		return
	for bone in _skeleton.get_bone_count():
		_skeleton.set_bone_pose_scale(bone, Vector3.ONE)
	_build()
	_shot = trail.size() >= 2
	if _shot:
		_shot_hit = trail[trail.size() - 1]
		_shot_dir = (_shot_hit - trail[trail.size() - 2]).normalized()
	_ticks = 0
	_elapsed = 0.0
	_still = 0.0
	_track_clock = 0.0
	_frames.clear()
	_times.clear()
	_record(_current_frame(), 0.0)
	state = State.SIMULATING
	set_process(true)
	set_physics_process(true)


## End the fall now: keep the pose reached so far as the track's last frame.
func settle() -> void:
	if state != State.SIMULATING:
		return
	var frame := _current_frame()
	_record(frame, _elapsed)
	_write(frame)
	_free_bodies()
	state = State.HELD
	set_process(false)
	set_physics_process(false)


## The track's skeleton-space bone poses at `t` seconds into the fall. Clamped to the ends.
func track_at(t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if _frames.is_empty():
		return out
	var at := clampf(t, 0.0, _times[_times.size() - 1])
	var hi := mini(_times.bsearch(at), _times.size() - 1)
	var lo := maxi(hi - 1, 0)
	var span := _times[hi] - _times[lo]
	var weight := clampf((at - _times[lo]) / span, 0.0, 1.0) if span > 0.0001 else 1.0
	var a: Array = _frames[lo]
	var b: Array = _frames[hi]
	for i in a.size():
		var from: Transform3D = a[i]
		var to: Transform3D = b[i]
		var basis := Basis(from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), weight))
		out.append(Transform3D(basis, from.origin.lerp(to.origin, weight)))
	return out


## Replay: the bones show the recorded fall at `t`. Written now so a camera reading the
## bones this frame sees them.
func play_track(t: float) -> void:
	if _frames.is_empty() or state == State.SIMULATING:
		return
	state = State.TRACK
	_write(track_at(t))


## The settled pose, kept.
func hold_final() -> void:
	if _frames.is_empty() or state == State.SIMULATING or state == State.NONE:
		return
	state = State.HELD
	_write(track_at(track_length()))


## Replay start: the fall is done, the pose writers get the skeleton back, the track stays.
func begin_retrace() -> void:
	if state == State.SIMULATING:
		settle()
	if state == State.NONE:
		return
	state = State.RETRACE
	_skeleton.reset_bone_poses()


## Free everything and forget the fall. The caller resets the bones.
func release() -> void:
	_free_bodies()
	_frames.clear()
	_times.clear()
	state = State.NONE
	set_process(false)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if state != State.SIMULATING or _bodies.is_empty():
		return
	if _shot and _ticks > 0:
		_shot = false
		_apply_impulses(_shot_hit, _shot_dir)
	_ticks += 1
	var slow := true
	for i in _bodies.size():
		_prev[i] = _curr[i]
		_curr[i] = _bodies[i].global_transform
		if _bodies[i].linear_velocity.length() >= _tune("ragdoll_settle_speed", 0.12):
			slow = false
	_still = _still + delta if slow else 0.0
	_track_clock += delta
	if _track_clock >= TRACK_STEP - 0.0001:
		_track_clock -= TRACK_STEP
		_record(_frame_from(_curr), _elapsed)
	_elapsed += delta
	if _elapsed >= SETTLE_MIN_TIME and (_still >= SETTLE_HOLD or _elapsed >= _tune("ragdoll_max_time", 3.5)):
		settle()


## Render frames and physics ticks do not line up, so blend the last two ticks.
func _process(_delta: float) -> void:
	if state != State.SIMULATING or _bodies.is_empty():
		return
	var fraction := Engine.get_physics_interpolation_fraction()
	var blended: Array[Transform3D] = []
	for i in _bodies.size():
		blended.append(_prev[i].interpolate_with(_curr[i], fraction))
	_write(_frame_from(blended))


func _build() -> void:
	_free_bodies()
	_offsets.clear()
	_prev.clear()
	_curr.clear()
	var by_name := {}
	var material := PhysicsMaterial.new()
	material.friction = FRICTION
	material.bounce = 0.0
	for spec in _specs:
		var bone: StringName = spec["name"]
		var from_world := _body.bone_global(bone)
		var end_bone := _bone_name(spec["end"], spec["suffix"])
		var to_world := _body.bone_global(end_bone).origin
		var span := to_world - from_world.origin
		var axis := span.normalized() if span.length_squared() > 0.000001 else from_world.basis.y.normalized()
		var tip := to_world + axis * float(spec["reach"])
		var radius: float = spec["radius"]
		var length := maxf(from_world.origin.distance_to(tip), radius * 2.0)
		var side := from_world.basis.x.slide(axis)
		if side.length_squared() < 0.000001:
			side = axis.cross(Vector3.UP)
		side = side.normalized()
		var xf := Transform3D(Basis(side, axis, side.cross(axis)), from_world.origin.lerp(tip, 0.5))
		var rigid := RigidBody3D.new()
		rigid.name = "Ragdoll_" + String(bone)
		rigid.top_level = true
		rigid.mass = spec["mass"]
		rigid.collision_layer = COLLISION_LAYER
		rigid.collision_mask = WORLD_MASK
		rigid.linear_damp = LINEAR_DAMP
		rigid.angular_damp = _tune("ragdoll_angular_damp", 2.0)
		rigid.continuous_cd = true
		var thick := maxf(radius, INERTIA_RADIUS)
		var mass: float = spec["mass"]
		var across := mass * (3.0 * thick * thick + length * length) / 12.0
		rigid.inertia = Vector3(across, mass * thick * thick * 0.5, across)
		rigid.physics_material_override = material
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = length
		var collider := CollisionShape3D.new()
		collider.shape = shape
		rigid.add_child(collider)
		add_child(rigid)
		for wall in get_tree().get_nodes_in_group(IGNORE_GROUP):
			rigid.add_collision_exception_with(wall as PhysicsBody3D)
		rigid.global_transform = xf
		_bodies.append(rigid)
		_offsets.append(xf.affine_inverse() * from_world)
		_prev.append(xf)
		_curr.append(xf)
		by_name[bone] = rigid
		if int(spec.get("joint", JointKind.NONE)) != JointKind.NONE:
			var parent: RigidBody3D = by_name[_bone_name(spec["parent"], spec["suffix"])]
			_joints.append(_make_joint(spec, parent, rigid, xf, from_world.origin))


func _make_joint(spec: Dictionary, parent: RigidBody3D, child: RigidBody3D, child_xf: Transform3D,
		origin: Vector3) -> Joint3D:
	var joint: Joint3D
	var frame := child_xf.basis
	if int(spec["joint"]) == JointKind.CONE:
		var cone := ConeTwistJoint3D.new()
		cone.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(spec["swing"]))
		cone.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(spec["twist"]))
		cone.set_param(ConeTwistJoint3D.PARAM_BIAS, CONE_BIAS)
		joint = cone
		# Twist runs along joint X: the limb.
		frame = child_xf.basis * Basis(Vector3.BACK, PI * 0.5)
	else:
		var hinge := HingeJoint3D.new()
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(spec["lower"]))
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(spec["upper"]))
		joint = hinge
		# The engine measures a hinge angle against the joint's Z the other way round.
		var pin := -_body.hinge_axis(spec["name"]).normalized()
		var along := child_xf.basis.y
		var x := along.cross(pin).normalized()
		frame = Basis(x, pin.cross(x), pin)
	joint.top_level = true
	add_child(joint)
	joint.global_transform = Transform3D(frame, origin)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	return joint


## Nearest body to the hit takes the kick; the torso takes a shove along the shot with
## some lift. Both peers read the same trail, so no region is sent.
func _apply_impulses(hit: Vector3, dir: Vector3) -> void:
	var nearest := 0
	var nearest_gap := INF
	for i in _bodies.size():
		var gap := _surface_gap(i, hit)
		if gap < nearest_gap:
			nearest_gap = gap
			nearest = i
	var kicked := _bodies[nearest]
	kicked.apply_impulse(dir * _tune("ragdoll_hit_impulse", 30.0), hit - kicked.global_position)
	var lift := _tune("ragdoll_lift", 0.25)
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length_squared() > 0.000001 else dir
	var shove := (flat * (1.0 - lift) + Vector3.UP * lift).normalized() * _tune("ragdoll_torso_push", 90.0)
	var torso: Array[RigidBody3D] = []
	var mass := 0.0
	for i in _bodies.size():
		if TORSO_BONES.has(_specs[i]["name"]):
			torso.append(_bodies[i])
			mass += _bodies[i].mass
	for rigid in torso:
		rigid.apply_central_impulse(shove * (rigid.mass / mass))


## Distance from `point` to the body's capsule surface.
func _surface_gap(index: int, point: Vector3) -> float:
	var rigid := _bodies[index]
	var shape := (rigid.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	var half := maxf(shape.height * 0.5 - shape.radius, 0.0)
	var axis := rigid.global_transform.basis.y
	var along := clampf((point - rigid.global_position).dot(axis), -half, half)
	return point.distance_to(rigid.global_position + axis * along) - shape.radius


func _current_frame() -> Array[Transform3D]:
	var frame: Array[Transform3D] = []
	for i in _bodies.size():
		frame.append(_bodies[i].global_transform)
	return _frame_from(frame)


## Skeleton-space bone poses for the given body transforms.
func _frame_from(body_xfs: Array[Transform3D]) -> Array[Transform3D]:
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var frame: Array[Transform3D] = []
	for i in body_xfs.size():
		frame.append(to_skeleton * (body_xfs[i] * _offsets[i]))
	return frame


func _record(frame: Array[Transform3D], time: float) -> void:
	_frames.append(frame)
	_times.append(time)


## Parent first, so each global pose lands under a parent already in place.
func _write(frame: Array[Transform3D]) -> void:
	for i in frame.size():
		_skeleton.set_bone_global_pose(_specs[i]["bone_index"], frame[i])


func _free_bodies() -> void:
	for joint in _joints:
		joint.queue_free()
	for rigid in _bodies:
		rigid.queue_free()
	_joints.clear()
	_bodies.clear()


func _bone_name(base: StringName, suffix: String) -> StringName:
	return StringName(String(base) + suffix) if String(base).ends_with(".") else base


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))
