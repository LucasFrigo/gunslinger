class_name DummyBody
extends Node3D
## Skinned mannequin (`assets/models/characters/dummy.glb`).
## The glTF faces +Z; this node yaws 180° so the mesh faces -Z like every combatant.
## `drive_arm(true, …)` is the arm that ends up on +X after that yaw.
## Pose writes live here. `set_pose_driven(false)` leaves the last bone poses so the
## ragdoll (`collapse`) takes the skeleton without this writer fighting it.
## Legs take an in-place step from `follow_travel`. Hips stay planted.
## The knee folds the shin back.

const MODEL := preload("res://assets/models/characters/dummy.glb")
## Pull the wrist back from a grip so the palm, not the bone origin, meets it.
const WRIST_INSET := 0.08
const NOD_LIMIT := deg_to_rad(35.0)
## Most of the look lives in the neck; the head takes the rest.
const NECK_SHARE := 0.65
## Shift the shell back so the eye sits in front of the chest, not inside it.
const EYE_SETBACK := 0.10
## Fragments closer than this to the first-person camera are the neck cavity.
const FP_CLIP_RADIUS := 0.18
## After the rig and the revolver (priority 0). Arm IK runs later still.
## Finger curls run after the wrist so they are not wiped by the hand pose.
const WRIST_PRIORITY := 10
const IK_PRIORITY := 20
const FINGER_PRIORITY := 30
## The ragdoll writes the fallen bones before the hit volumes read them.
const RAGDOLL_PRIORITY := 35
## Hit volumes read the bones last, after IK, fingers, and the ragdoll.
const HITBOX_PRIORITY := 40
const WRIST_BLEND_SEC := 0.1
## m/s of upward kick on a gun dropped by a dying duelist.
const GUN_FLING_LIFT := 0.4
## Tumble (rad/s) per m/s of fling, about the axis across the shot.
const GUN_TUMBLE := 1.6
## Visual layer 20. Mesh lab draws the body here so the headset camera can skip it.
const SPECTATOR_BODY_LAYER := 1 << 19
## Local VR hands. Same size as the imported mesh.
const VR_HAND_SCALE := 1.0
## One full left-right cycle per this much horizontal travel.
const WALK_STRIDE := 0.8
## Slower than this, the legs ease back to the rest pose.
const WALK_SPEED_MIN := 0.35
## A duel reset or spawn snap. That sample does not kick the cycle.
const WALK_TELEPORT := 1.5
## Seconds to blend the swing in or out.
const WALK_EASE := 0.12
const THIGH_SWING := deg_to_rad(28.0)
const KNEE_BEND := deg_to_rad(40.0)
const PART_BODY := &"body"
const PART_HEAD := &"head"
const PART_HAND := &"hand"
const SKIN_ROUGHNESS := 0.9
## The skin snap casts the shot from this far before the hit volume's point, up to this
## far past it. Hit volumes sit off the skin (the torso by up to its radius).
const SNAP_BACK := 0.15
const SNAP_REACH := 0.3
const SNAP_NUDGE := 0.001

var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _body_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _hand_meshes: Array[MeshInstance3D] = []
var _parts: Array[MeshInstance3D] = []
var _body_shelved := false
var _head_hidden := false
var _ik: Dictionary = {}
var _fingers: HandFingers
var _hitboxes: BodyHitboxes
var _ragdoll: BodyRagdoll
var _face := Vector3.BACK
var _spine := -1
var _chest := -1
var _neck := -1
var _head := -1
var _look_pitch := 0.0
var _pose_driven := true
var _albedo := Color(0.62, 0.60, 0.58)
var _fp_clip := false
## Body and head share one skin; the cavity is its `next_pass` while there are holes.
var _skin_material: ShaderMaterial
var _cavity_material: ShaderMaterial
## Parsed `Reto` per mesh resource: the intact part meshes every body shares and each
## skin bind's rest triangles for the skin snap.
static var _split_cache := {}
var _split: Dictionary = {}
var _chunks: BodyChunks
var _legs: Array[Dictionary] = []
var _travel: Node3D
var _travel_ready := false
var _travel_prev := Vector3.ZERO
var _walk_phase := 0.0
var _walk_weight := 0.0


static func spawn(parent: Node) -> DummyBody:
	var body := DummyBody.new()
	body.name = "DummyBody"
	parent.add_child(body)
	var visual: Node = MODEL.instantiate()
	body.add_child(visual)
	body.rotation.y = PI
	body._bind(visual)
	return body


## Horizon pitch of a camera basis. Positive looks up (`forward.y`).
static func pitch_from_basis(basis: Basis) -> float:
	return asin(clampf((-basis.z).y, -1.0, 1.0))


## Head tilt. Positive when the camera's right side drops.
static func roll_from_basis(basis: Basis) -> float:
	return asin(clampf(-basis.x.y, -1.0, 1.0))


func set_tint(color: Color) -> void:
	_albedo = color
	_apply_material()


## Local first person only. Drops fragments inside the clip sphere so the
## open neck does not show the hollow torso. Remote, AI, and the corpse stay solid.
func set_first_person_clip(enabled: bool) -> void:
	_fp_clip = enabled
	_apply_material()


## Stop or resume neck, arm, and leg writes. The last poses stay when this turns off.
## Turning it back on clears the step so a respawn stands. A corpse keeps the skeleton:
## only `release_corpse` and `corpse_replay_begin` give it back.
func set_pose_driven(enabled: bool) -> void:
	if enabled and _ragdoll != null and _ragdoll.owns_skeleton():
		return
	var resume := enabled and not _pose_driven
	_pose_driven = enabled
	set_process(enabled)
	for suffix in _ik:
		(_ik[suffix] as Node).set_process(enabled)
	if _fingers != null:
		_fingers.set_process(enabled)
	if resume:
		_clear_walk()


## Whether corpses fall under physics (`ragdoll_enabled`).
static func ragdoll_on() -> bool:
	return float(GameManager.tuning.get("ragdoll_enabled", 1.0)) >= 0.5


## Direction of the last segment of a bullet's `trail`, or zero with fewer than two points.
static func shot_dir(trail: PackedVector3Array) -> Vector3:
	if trail.size() < 2:
		return Vector3.ZERO
	return (trail[trail.size() - 1] - trail[trail.size() - 2]).normalized()


## Velocity a dying duelist's gun leaves with: along the shot, plus a little lift.
static func gun_fling(trail: PackedVector3Array) -> Vector3:
	return shot_dir(trail) * float(GameManager.tuning.get("ragdoll_gun_fling", 7.0)) + Vector3.UP * GUN_FLING_LIFT


## Spin a dying duelist's gun leaves with: it tumbles across the shot as it is flung.
static func gun_spin(trail: PackedVector3Array) -> Vector3:
	var along := gun_fling(trail) - Vector3.UP * GUN_FLING_LIFT
	var axis := along.cross(Vector3.UP)
	return axis.normalized() * along.length() * GUN_TUMBLE if axis.length_squared() > 0.0001 else Vector3.ZERO


## Lethal hit: stop the writers and drop the body under physics, kicked along the last
## segment of `trail`. With `ragdoll_enabled` off the last pose is simply held.
func collapse(trail: PackedVector3Array) -> void:
	set_pose_driven(false)
	if _ragdoll != null and ragdoll_on():
		_ragdoll.collapse(trail)


func has_corpse() -> bool:
	return _ragdoll != null and _ragdoll.state != BodyRagdoll.State.NONE


func corpse_state() -> BodyRagdoll.State:
	return _ragdoll.state if _ragdoll != null else BodyRagdoll.State.NONE


## The orbit pivot: the fallen chest.
func corpse_pivot() -> Vector3:
	return bone_global(&"Chest").origin


## Replay start. A fall still running is cut short, the track stays, and the writers
## stand the body up for the clip before the death.
func corpse_replay_begin() -> void:
	if _ragdoll != null:
		_ragdoll.begin_retrace()


## Replay after the death: `since_death` seconds into the recorded fall.
func corpse_replay_at(since_death: float) -> void:
	if _ragdoll == null or not _ragdoll.has_track() or _ragdoll.state == BodyRagdoll.State.SIMULATING:
		return
	set_pose_driven(false)
	_ragdoll.play_track(since_death)


## The replay ended: keep the settled pose. A fall that never stopped keeps running.
func corpse_hold_final() -> void:
	if not has_corpse() or _ragdoll.state == BodyRagdoll.State.SIMULATING:
		return
	set_pose_driven(false)
	_ragdoll.hold_final()


## A new duel: drop the corpse, reset every bone (nothing else resets `Hips`), and unlock.
func release_corpse() -> void:
	if _ragdoll == null or _ragdoll.state == BodyRagdoll.State.NONE:
		return
	_ragdoll.release()
	_skeleton.reset_bone_poses()


## Cut `cut` (`cut_at`) out of the skin (cosmetic): a hole and a gib along `dir` unless the
## body is shelved and the hit is not `lethal`. An empty cut, or Gore off, does nothing.
## `clip_t` is `ReplayBuffer.clip_time()` (the host's in MP).
func knock_chunk(cut: Dictionary, dir: Vector3, clip_t: float, lethal: bool) -> void:
	if _chunks != null and int(cut.get("bone", -1)) >= 0:
		_chunks.knock(cut, dir, clip_t, lethal)


## Holes showing now (at this point of a replay), at most `BodyChunks.HOLE_CAP`.
func chunk_count() -> int:
	return _chunks.hole_count() if _chunks != null else 0


## Every hole healed. Thrown gibs stay where they lie.
func reset_chunks() -> void:
	if _chunks != null:
		_chunks.reset()


## Replay start: holes cut inside the clip heal until their clip time.
func chunks_replay_begin(clip_begin: float) -> void:
	if _chunks != null:
		_chunks.replay_begin(clip_begin)


## Replay at clip time `t`: holes open and their gibs re-fly.
func chunks_replay_at(t: float) -> void:
	if _chunks != null:
		_chunks.replay_at(t)


## The replay ended: every hole open, every gib settled. No-op outside a replay.
func chunks_hold_final() -> void:
	if _chunks != null:
		_chunks.hold_final()


func is_body_shelved() -> bool:
	return _body_shelved


## World pose of skeleton bone `bone`, scale included (arm IK stretches it).
func bone_pose_world(bone: int) -> Transform3D:
	if _skeleton == null or bone < 0 or bone >= _skeleton.get_bone_count():
		return global_transform
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)


## World center of a cut's sphere on the current pose.
func cut_world_center(cut: Dictionary) -> Vector3:
	return bone_pose_world(int(cut.get("bone", -1))) * (cut.get("local", Vector3.ZERO) as Vector3)


## Face direction in the world (`+Z` of the glTF after this node's yaw).
func front_dir() -> Vector3:
	return global_transform.basis.z.normalized()


## The cut a bullet along `shot` makes where it struck hit volume `shape` at `world_point`,
## or `{}` when the shape is not one of this body's. See `cut_on_bone`.
func cut_at(shape: Object, world_point: Vector3, shot: Vector3, region: StringName) -> Dictionary:
	if _hitboxes == null or _skeleton == null:
		return {}
	var bone_name := _hitboxes.bone_of(shape, world_point)
	if bone_name == &"":
		return {}
	return cut_on_bone(_skeleton.find_bone(bone_name), world_point, shot, region)


## A cut on `bone`: `{bone, local, radius}`. The shot is snapped from `world_point` onto the
## skin, the radius rolled from `cut_min..cut_max` (arms and legs capped at `cut_limb_max`),
## and the sphere center lifted `BodyChunks.CUT_LIFT` of it out of the skin against the
## shot, stored in the bone's pose space. `{}` when the bone is missing.
func cut_on_bone(bone: int, world_point: Vector3, shot: Vector3, region: StringName) -> Dictionary:
	if _skeleton == null or bone < 0:
		return {}
	var dir := shot.normalized() if shot.length_squared() > 0.000001 else -front_dir()
	var radius := randf_range(_tune("cut_min", 0.05), _tune("cut_max", 0.10))
	if region == CombatRules.REGION_ARM or region == CombatRules.REGION_LEG:
		radius = minf(radius, _tune("cut_limb_max", 0.06))
	var center := skin_entry(bone, world_point, dir) - dir * BodyChunks.CUT_LIFT * radius
	return {"bone": bone, "local": bone_pose_world(bone).affine_inverse() * center, "radius": radius}


## Where a shot along `dir` through `world_point` enters the posed skin of `bone` or its
## parent: the rest triangles each bind dominates, cast in that bind's space. The nearest
## entry from `SNAP_BACK` before the point to `SNAP_REACH` past it, else `world_point`.
## A cast down a shared edge (the mirror seam) can slip between both triangles, so a miss
## is cast again `SNAP_NUDGE` to the side.
func skin_entry(bone: int, world_point: Vector3, dir: Vector3) -> Vector3:
	var bind_tris: Dictionary = _split.get("bind_tris", {})
	if bind_tris.is_empty() or _mesh == null or _mesh.skin == null:
		return world_point
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	for nudge: Vector3 in [Vector3.ZERO, side * SNAP_NUDGE]:
		var entry: Variant = _cast_skin(bone, world_point + nudge, dir, bind_tris)
		if entry != null:
			return (entry as Vector3) - nudge
	return world_point


## `skin_entry` for one cast, or null.
func _cast_skin(bone: int, world_point: Vector3, dir: Vector3, bind_tris: Dictionary) -> Variant:
	var from := world_point - dir * SNAP_BACK
	var best := SNAP_BACK + SNAP_REACH
	var entry: Variant = null
	for b: int in [bone, _skeleton.get_bone_parent(bone)]:
		if b < 0:
			continue
		var bind := _skin_bind(_mesh.skin, _skeleton, _skeleton.get_bone_name(b))
		if bind < 0 or not bind_tris.has(bind):
			continue
		var tris: PackedVector3Array = bind_tris[bind]
		var m := bone_pose_world(b) * _mesh.skin.get_bind_pose(bind)
		var inv := m.affine_inverse()
		var o := inv * from
		var d := inv.basis * dir
		for i in range(0, tris.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(o, d, tris[i], tris[i + 1], tris[i + 2])
			if hit == null:
				continue
			var world: Vector3 = m * (hit as Vector3)
			var t := (world - from).dot(dir)
			if t < best:
				best = t
				entry = world
	return entry


## The body's solid skin material, for a gib's outer surface.
func skin_material() -> StandardMaterial3D:
	return _solid_material()


## Horizontal travel of `source` drives the in-place step. The local rig origin,
## the duelist, the remote head, or the mesh-lab puppet.
func follow_travel(source: Node3D) -> void:
	_travel = source
	_travel_ready = false


## View-only. Hides the head part (triangles weighted only to `Head`) on this
## instance, and the head holes with it.
func set_head_hidden(hidden: bool) -> void:
	_head_hidden = hidden
	_apply_part_visibility()


## Local VR hides the torso, arms, and legs until the body fit is picked back up.
## The hand meshes stay. Death clears this so the corpse orbit still has a body.
func set_body_shelved(shelved: bool) -> void:
	_body_shelved = shelved
	_apply_part_visibility()


## Visual layer for body and head. Hands stay on the default layer.
func set_body_render_layers(layers: int) -> void:
	if _body_mesh != null:
		_body_mesh.layers = layers
	if _head_mesh != null:
		_head_mesh.layers = layers


func set_hand_scale(scale: float) -> void:
	for suffix in _ik:
		(_ik[suffix] as Node).set("hand_scale", scale)


func _apply_part_visibility() -> void:
	if _body_mesh != null:
		_body_mesh.visible = not _body_shelved
	if _head_mesh != null:
		_head_mesh.visible = not _body_shelved and not _head_hidden
	for hand in _hand_meshes:
		hand.visible = true


## Feet stay on the parent origin. `yaw` is this node's local Y, including the 180° face turn.
func place_on_floor(head_global: Vector3, yaw: float) -> void:
	if not _pose_driven:
		return
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var local_head := parent.to_local(head_global)
	# `yaw` already includes the 180° face turn, so basis.z is the look.
	var look := Basis(Vector3.UP, yaw).z
	position = Vector3(local_head.x, 0.0, local_head.z) - look * EYE_SETBACK
	rotation.y = yaw


## `pitch` is `pitch_from_basis`. Clamped. Spine, chest, hips, and legs stay at rest.
func drive_look(pitch: float) -> void:
	if not _pose_driven:
		return
	_look_pitch = clampf(pitch, -NOD_LIMIT, NOD_LIMIT)


## Upright stance under the head. Yaw follows the headset. Spine and chest stay
## in the rest pose; only the neck nods. `stance_global` and `look_roll` are
## unused until torso lean comes back.
func place_toward_head(head_global: Vector3, yaw: float, look_pitch: float, _stance_global: Vector3, _look_roll: float = 0.0) -> void:
	place_on_floor(head_global, yaw)
	drive_look(look_pitch)


## `positive_x` is the side the arm occupies in this node's parent (+X / -X).
func drive_arm(positive_x: bool, target: Node3D, match_twist := false, wrist_inset := 0.0) -> void:
	if _skeleton == null or target == null:
		return
	var suffix := "R" if positive_x else "L"
	if _skeleton.find_bone("UpperArm." + suffix) < 0:
		push_error("DummyBody missing bone UpperArm.%s" % suffix)
		return
	var ik: Node = load("res://characters/dummy_arm_ik.gd").new()
	ik.name = "ArmIK" + suffix
	ik.set("bone_suffix", suffix)
	ik.set("match_twist", match_twist)
	ik.set("wrist_inset", wrist_inset)
	ik.process_priority = IK_PRIORITY
	_skeleton.add_child(ik)
	ik.set("target_path", ik.get_path_to(target))
	_ik[suffix] = ik


## `positive_x` is the arm on +X after this node's 180° yaw.
func set_hand_curl(positive_x: bool, pose: int, trigger: float) -> void:
	if _fingers != null:
		_fingers.set_curl(positive_x, pose, trigger)


## Retarget after the camera and the gun have moved. IK reads this on a later priority.
func set_arm_target(positive_x: bool, target: Node3D, match_twist: bool, wrist_inset: float, grip_local := Vector3.ZERO) -> void:
	var suffix := "R" if positive_x else "L"
	if target == null or not _ik.has(suffix):
		return
	var ik: Node = _ik[suffix]
	ik.set("match_twist", match_twist)
	ik.set("wrist_inset", wrist_inset)
	ik.set("grip_local", grip_local)
	ik.set("target_path", ik.get_path_to(target))


## World transform of a skeleton bone. Joint origin plus its posed basis.
func bone_global(bone_name: StringName) -> Transform3D:
	if _skeleton == null:
		return global_transform
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		return global_transform
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(idx)


## World-space axis that swings this bone's +Y toward the face. A positive hinge angle
## about it bends the elbow; the knee folds the other way (see `_swing_axis`).
func hinge_axis(bone_name: StringName) -> Vector3:
	var idx := _skeleton.find_bone(bone_name)
	if idx < 0:
		return Vector3.RIGHT
	return (bone_global(bone_name).basis * _swing_axis(idx, _face)).normalized()


func has_bone(bone_name: StringName) -> bool:
	return _skeleton != null and _skeleton.find_bone(bone_name) >= 0


## Skeleton index of `bone_name`, or -1.
func bone_index(bone_name: StringName) -> int:
	return _skeleton.find_bone(bone_name) if _skeleton != null else -1


## Put the combatant's six hit volumes on the posed bones. `arm_l` / `arm_r` are the
## sides of the mannequin (`.L` / `.R` bones); the leg pair is the same.
func attach_hitboxes(head: Hitbox, torso: Hitbox, arm_l: Hitbox, arm_r: Hitbox,
		leg_l: Hitbox, leg_r: Hitbox) -> BodyHitboxes:
	if _hitboxes != null:
		_hitboxes.queue_free()
	_hitboxes = BodyHitboxes.new()
	_hitboxes.name = "BodyHitboxes"
	_hitboxes.process_priority = HITBOX_PRIORITY
	add_child(_hitboxes)
	_hitboxes.setup(self, head, torso, {&"L": arm_l, &"R": arm_r}, {&"L": leg_l, &"R": leg_r})
	return _hitboxes


## `&"L"`, `&"R"`, or `&""`. The gun arm's forearm is thinner and stops short of the grip.
func set_gun_arm(side: StringName) -> void:
	if _hitboxes != null:
		_hitboxes.set_gun_arm(side)


func _process(delta: float) -> void:
	_apply_look()
	_apply_walk(delta)


## Body and head wear the shared skin (holes, first-person clip); hands stay solid.
func _apply_material() -> void:
	if _skin_material == null:
		_skin_material = BodyChunks.skin_material_new()
		_cavity_material = BodyChunks.cavity_material_new()
	var clip := FP_CLIP_RADIUS if _fp_clip else 0.0
	_skin_material.set_shader_parameter("albedo", _albedo)
	_skin_material.set_shader_parameter("roughness_amount", SKIN_ROUGHNESS)
	_skin_material.set_shader_parameter("clip_radius", clip)
	_cavity_material.set_shader_parameter("clip_radius", clip)
	var targets: Array[MeshInstance3D] = _parts
	if targets.is_empty() and _mesh != null:
		targets = [_mesh]
	for mesh in targets:
		if _hand_meshes.has(mesh):
			mesh.material_override = _solid_material()
		elif mesh.material_override != _skin_material:
			mesh.material_override = _skin_material


func _solid_material() -> StandardMaterial3D:
	return solid_material(_albedo)


static func solid_material(albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = SKIN_ROUGHNESS
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))


func _apply_look() -> void:
	if _skeleton == null:
		return
	# Torso lean is off. Clear any pose so the spine and chest stay on the rest bind.
	if _spine >= 0:
		_skeleton.reset_bone_pose(_spine)
	if _chest >= 0:
		_skeleton.reset_bone_pose(_chest)
	if _neck < 0 or _head < 0:
		return
	# Rest +X is the nod axis. Positive pose X looks up (the face is bone -Z).
	var neck_angle := _look_pitch * NECK_SHARE
	var head_angle := _look_pitch * (1.0 - NECK_SHARE)
	_skeleton.set_bone_pose_rotation(_neck, Quaternion(Vector3.RIGHT, neck_angle))
	_skeleton.set_bone_pose_rotation(_head, Quaternion(Vector3.RIGHT, head_angle))


func _clear_walk() -> void:
	_walk_phase = 0.0
	_walk_weight = 0.0
	_travel_ready = false
	_apply_legs(0.0)


func _apply_walk(delta: float) -> void:
	if _skeleton == null:
		return
	var moving := false
	if _travel != null and is_instance_valid(_travel):
		var here := _travel.global_position
		if not _travel_ready:
			_travel_prev = here
			_travel_ready = true
		else:
			var offset := here - _travel_prev
			_travel_prev = here
			var dist := Vector2(offset.x, offset.z).length()
			if dist <= WALK_TELEPORT and delta > 0.0:
				var speed := dist / delta
				if speed >= WALK_SPEED_MIN:
					moving = true
					_walk_phase = fposmod(_walk_phase + dist / WALK_STRIDE * TAU, TAU)
	var target := 1.0 if moving else 0.0
	_walk_weight = move_toward(_walk_weight, target, delta / WALK_EASE)
	_apply_legs(_walk_weight)


func _apply_legs(weight: float) -> void:
	if _skeleton == null:
		return
	var resting := weight <= 0.0001
	for leg in _legs:
		var upper: int = leg["upper"]
		var lower: int = leg["lower"]
		var foot: int = leg["foot"]
		if resting:
			_skeleton.reset_bone_pose(upper)
			_skeleton.reset_bone_pose(lower)
			_skeleton.reset_bone_pose(foot)
			continue
		var swing := sin(_walk_phase + float(leg["phase"]))
		var thigh := swing * THIGH_SWING * weight
		# Positive swing steps a bone toward the face. The knee flexes the other
		# way, so the shin folds back while this leg is behind the hips.
		var knee := -maxf(0.0, -swing) * KNEE_BEND * weight
		# Godot 4 pose rotation includes the rest. A bare swing replaces the
		# 127° thigh rest and kicks both legs out in front.
		_set_swing(upper, leg["upper_axis"] as Vector3, thigh)
		_set_swing(lower, leg["lower_axis"] as Vector3, knee)
		_set_swing(foot, leg["foot_axis"] as Vector3, -(thigh + knee))


func _set_swing(bone: int, axis: Vector3, angle: float) -> void:
	var rest_q := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone, rest_q * Quaternion(axis, angle))


## Local axis that swings this bone's +Y (down the bone, or along the foot)
## toward the mesh face. Positive pose rotation steps forward.
func _swing_axis(bone: int, face: Vector3) -> Vector3:
	var rest := _skeleton.get_bone_global_rest(bone)
	var along := rest.basis.y
	var axis_skel := along.cross(face)
	if axis_skel.length_squared() < 0.0001:
		axis_skel = along.cross(Vector3.UP)
	axis_skel = axis_skel.normalized()
	var axis_local: Vector3 = rest.basis.inverse() * axis_skel
	if axis_local.length_squared() < 0.0001:
		return Vector3.RIGHT
	return axis_local.normalized()


func _bind_legs(visual: Node3D) -> void:
	if visual == null:
		return
	var face := _skeleton.global_transform.basis.inverse() * visual.global_transform.basis.z
	if face.length_squared() < 0.0001:
		face = Vector3(0.0, 0.0, 1.0)
	else:
		face = face.normalized()
	_face = face
	_bind_leg("L", 0.0, face)
	_bind_leg("R", PI, face)


func _bind_leg(suffix: String, phase: float, face: Vector3) -> void:
	var upper := _skeleton.find_bone("UpperLeg." + suffix)
	var lower := _skeleton.find_bone("LowerLeg." + suffix)
	var foot := _skeleton.find_bone("Foot." + suffix)
	if upper < 0 or lower < 0 or foot < 0:
		push_error("DummyBody missing leg bones .%s" % suffix)
		return
	_legs.append({
		"upper": upper,
		"lower": lower,
		"foot": foot,
		"upper_axis": _swing_axis(upper, face),
		"lower_axis": _swing_axis(lower, face),
		"foot_axis": _swing_axis(foot, face),
		"phase": phase,
	})


func _bind(visual: Node) -> void:
	_skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	_mesh = visual.find_child("Reto", true, false) as MeshInstance3D
	if _skeleton == null:
		return
	_spine = _skeleton.find_bone("Spine")
	_chest = _skeleton.find_bone("Chest")
	_neck = _skeleton.find_bone("Neck")
	_head = _skeleton.find_bone("Head")
	_bind_legs(visual as Node3D)
	_fingers = HandFingers.new()
	_fingers.name = "HandFingers"
	_fingers.setup(_skeleton, visual)
	_skeleton.add_child(_fingers)
	_ragdoll = BodyRagdoll.new()
	_ragdoll.name = "BodyRagdoll"
	_ragdoll.process_priority = RAGDOLL_PRIORITY
	add_child(_ragdoll)
	_ragdoll.setup(self, _skeleton)
	_split_parts()


## Split `Reto` into body, head, and hand parts over all of its surfaces. Every body that
## wears the mesh shares the part meshes; holes are the skin shader's (`BodyChunks`).
func _split_parts() -> void:
	if _mesh == null or _mesh.mesh == null or _mesh.skin == null:
		return
	_split = _split_of(_mesh, _skeleton)
	if not _split.is_empty():
		var intact: Dictionary = _split["intact"]
		_body_mesh = _make_part("BodyMesh", intact[PART_BODY])
		_head_mesh = _make_part("HeadMesh", intact[PART_HEAD])
		if intact.has(PART_HAND):
			_hand_meshes.append(_make_part("HandMesh", intact[PART_HAND]))
		_mesh.visible = false
	_apply_material()
	_chunks = BodyChunks.new()
	_chunks.name = "BodyChunks"
	add_child(_chunks)
	_chunks.setup(self, _skin_material, _cavity_material)
	_apply_part_visibility()


func _make_part(part_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.skin = _mesh.skin
	var host := _mesh.get_parent()
	host.add_child(part)
	part.transform = _mesh.transform
	part.cast_shadow = _mesh.cast_shadow
	part.layers = _mesh.layers
	part.skeleton = part.get_path_to(_skeleton)
	_parts.append(part)
	return part


## The parse of `source`'s mesh, shared by every body that wears it. Empty when it
## cannot be split (no Head bind, no skin weights, or no head or body triangles).
static func _split_of(source: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var mesh := source.mesh as ArrayMesh
	if mesh == null:
		return {}
	if not _split_cache.has(mesh):
		_split_cache[mesh] = _parse_split(mesh, source.skin, skeleton)
	return _split_cache[mesh]


static func _parse_split(mesh: ArrayMesh, skin: Skin, skeleton: Skeleton3D) -> Dictionary:
	var head_bind := _skin_bind(skin, skeleton, "Head")
	if head_bind < 0:
		return {}
	var hand_binds := _collect_hand_binds(skin, skeleton)
	var merged := _merge_surfaces(mesh)
	if merged.is_empty():
		return {}
	var arrays: Array = merged["arrays"]
	var stride: int = merged["stride"]
	var flags: int = merged["flags"]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var dominant := _dominant_binds(arrays, stride)
	var lists := {PART_BODY: [], PART_HEAD: [], PART_HAND: []}
	var corners := {}
	for t in indices.size() / 3:
		var tri: Array[int] = [indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2]]
		var a := dominant[tri[0]]
		var b := dominant[tri[1]]
		var c := dominant[tri[2]]
		var part := PART_BODY
		if a == head_bind and b == head_bind and c == head_bind:
			part = PART_HEAD
		elif hand_binds.has(a) and hand_binds.has(b) and hand_binds.has(c):
			part = PART_HAND
		(lists[part] as Array).append_array(tri)
		if part == PART_HAND:
			continue
		# Each bind its corners lean on casts this triangle in the skin snap.
		for bind: int in {a: true, b: true, c: true}:
			if bind < 0:
				continue
			if not corners.has(bind):
				corners[bind] = []
			(corners[bind] as Array).append_array([verts[tri[0]], verts[tri[1]], verts[tri[2]]])
	if (lists[PART_HEAD] as Array).is_empty() or (lists[PART_BODY] as Array).is_empty():
		return {}
	var bind_tris := {}
	for bind: int in corners:
		bind_tris[bind] = PackedVector3Array(corners[bind])
	var intact := {}
	for part: StringName in lists:
		var all := PackedInt32Array(lists[part])
		if all.is_empty():
			continue
		var part_arrays := arrays.duplicate()
		part_arrays[Mesh.ARRAY_INDEX] = all
		var part_mesh := ArrayMesh.new()
		part_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part_arrays, [], {}, flags)
		intact[part] = part_mesh
	return {"intact": intact, "bind_tris": bind_tris}


## Every surface's arrays end to end, indices offset.
static func _merge_surfaces(mesh: ArrayMesh) -> Dictionary:
	var merged: Array = []
	var stride := 4
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var eight := mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS != 0
		if merged.is_empty():
			if indices.is_empty() or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
				return {}
			if (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty():
				return {}
			merged = arrays.duplicate()
			stride = 8 if eight else 4
		else:
			if indices.is_empty() or eight != (stride == 8) or not _same_layout(merged, arrays):
				push_warning("DummyBody: Reto surface %d does not match surface 0 and is dropped" % s)
				continue
			var base := (merged[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for slot in Mesh.ARRAY_MAX:
				if slot == Mesh.ARRAY_INDEX or merged[slot] == null:
					continue
				var joined: Variant = merged[slot]
				joined.append_array(arrays[slot])
				merged[slot] = joined
			for i in indices.size():
				indices[i] += base
			var all: PackedInt32Array = merged[Mesh.ARRAY_INDEX]
			all.append_array(indices)
			merged[Mesh.ARRAY_INDEX] = all
	return {
		"arrays": merged,
		"stride": stride,
		"flags": Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0,
	}


static func _same_layout(a: Array, b: Array) -> bool:
	for slot in Mesh.ARRAY_MAX:
		if (a[slot] == null) != (b[slot] == null):
			return false
	return true


## The heaviest bind of each vertex, or -1 when it has no weight.
static func _dominant_binds(arrays: Array, stride: int) -> PackedInt32Array:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var out := PackedInt32Array()
	out.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	for v in out.size():
		var base := v * stride
		var best := -1
		var best_w := 0.0
		if base + stride <= bones.size() and base + stride <= weights.size():
			for slot in stride:
				if weights[base + slot] > best_w:
					best_w = weights[base + slot]
					best = bones[base + slot]
		out[v] = best
	return out


static func _skin_bind(skin: Skin, skeleton: Skeleton3D, bone_name: String) -> int:
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == bone_name:
			return i
		var bone := skin.get_bind_bone(i)
		if bone >= 0 and skeleton.get_bone_name(bone) == bone_name:
			return i
	return -1


## Hand.L / Hand.R and every finger bone under them. A fingertip weighted only
## to Index1 would otherwise fall into the shelved body and vanish in VR.
static func _collect_hand_binds(skin: Skin, skeleton: Skeleton3D) -> Dictionary:
	var binds := {}
	for i in skeleton.get_bone_count():
		if not _bone_is_hand(skeleton, i):
			continue
		var bind := _skin_bind(skin, skeleton, skeleton.get_bone_name(i))
		if bind >= 0:
			binds[bind] = true
	return binds


static func _bone_is_hand(skeleton: Skeleton3D, bone: int) -> bool:
	var guard := 0
	while bone >= 0 and guard < 12:
		var bone_name := skeleton.get_bone_name(bone)
		if bone_name == "Hand.L" or bone_name == "Hand.R":
			return true
		bone = skeleton.get_bone_parent(bone)
		guard += 1
	return false
