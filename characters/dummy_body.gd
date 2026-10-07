class_name DummyBody
extends Node3D
## Skinned mannequin (`assets/models/characters/dummy.glb`).
## The glTF faces +Z; this node yaws 180° so the mesh faces -Z like every combatant.
## `drive_arm(true, …)` is the arm that ends up on +X after that yaw.
## Pose writes live here. `set_pose_driven(false)` leaves the last bone poses so a
## later ragdoll can take the skeleton without this writer fighting it.
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
const WRIST_BLEND_SEC := 0.1
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

const FP_SHADER_CODE := """shader_type spatial;
render_mode cull_back;
uniform vec4 albedo : source_color = vec4(0.62, 0.60, 0.58, 1.0);
uniform float clip_radius = 0.18;
uniform float roughness_amount = 0.9;
void fragment() {
	if (length(VERTEX) < clip_radius) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness_amount;
}
"""

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
var _spine := -1
var _chest := -1
var _neck := -1
var _head := -1
var _look_pitch := 0.0
var _pose_driven := true
var _albedo := Color(0.62, 0.60, 0.58)
var _fp_clip := false
var _fp_shader: Shader
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
## Turning it back on clears the step so a respawn stands.
func set_pose_driven(enabled: bool) -> void:
	var resume := enabled and not _pose_driven
	_pose_driven = enabled
	set_process(enabled)
	for suffix in _ik:
		(_ik[suffix] as Node).set_process(enabled)
	if _fingers != null:
		_fingers.set_process(enabled)
	if resume:
		_clear_walk()


## Horizontal travel of `source` drives the in-place step. The local rig origin,
## the duelist, the remote head, or the mesh-lab puppet.
func follow_travel(source: Node3D) -> void:
	_travel = source
	_travel_ready = false


## View-only. Hides triangles weighted to `Head` on this instance. The source
## glTF stays one surface; this is not a dismemberment cut.
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


func _process(delta: float) -> void:
	_apply_look()
	_apply_walk(delta)


func _apply_material() -> void:
	var targets: Array[MeshInstance3D] = _parts
	if targets.is_empty() and _mesh != null:
		targets = [_mesh]
	var material: Material = _solid_material()
	if _fp_clip:
		material = _clip_material()
	for mesh in targets:
		if _hand_meshes.has(mesh):
			mesh.material_override = _solid_material()
		else:
			mesh.material_override = material


func _solid_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _albedo
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


func _clip_material() -> ShaderMaterial:
	if _fp_shader == null:
		_fp_shader = Shader.new()
		_fp_shader.code = FP_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _fp_shader
	material.set_shader_parameter("albedo", _albedo)
	material.set_shader_parameter("clip_radius", FP_CLIP_RADIUS)
	material.set_shader_parameter("roughness_amount", 0.9)
	return material


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
	_split_head()


func _split_head() -> void:
	if _mesh == null or _mesh.mesh == null or _mesh.skin == null:
		return
	if _mesh.mesh.get_surface_count() < 1:
		return
	var head_bind := _skin_bind("Head")
	var hand_binds := _collect_hand_binds()
	if head_bind < 0:
		return
	var arrays: Array = _mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if bones.is_empty() or weights.is_empty() or indices.is_empty():
		return
	var format: int = _mesh.mesh.surface_get_format(0)
	var stride := 4
	if format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
		stride = 8
	var head_idx := PackedInt32Array()
	var hand_idx := PackedInt32Array()
	var body_idx := PackedInt32Array()
	var i := 0
	while i + 2 < indices.size():
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		if _vertex_is_bone(bones, weights, a, head_bind, stride) \
				and _vertex_is_bone(bones, weights, b, head_bind, stride) \
				and _vertex_is_bone(bones, weights, c, head_bind, stride):
			head_idx.append(a)
			head_idx.append(b)
			head_idx.append(c)
		elif _vertex_in_binds(bones, weights, a, hand_binds, stride) \
				and _vertex_in_binds(bones, weights, b, hand_binds, stride) \
				and _vertex_in_binds(bones, weights, c, hand_binds, stride):
			hand_idx.append(a)
			hand_idx.append(b)
			hand_idx.append(c)
		else:
			body_idx.append(a)
			body_idx.append(b)
			body_idx.append(c)
		i += 3
	if head_idx.is_empty() or body_idx.is_empty():
		return
	var body_arrays := arrays.duplicate(true)
	body_arrays[Mesh.ARRAY_INDEX] = body_idx
	var head_arrays := arrays.duplicate(true)
	head_arrays[Mesh.ARRAY_INDEX] = head_idx
	_body_mesh = _make_part("BodyMesh", body_arrays)
	_head_mesh = _make_part("HeadMesh", head_arrays)
	if not hand_idx.is_empty():
		var hand_arrays := arrays.duplicate(true)
		hand_arrays[Mesh.ARRAY_INDEX] = hand_idx
		_hand_meshes.append(_make_part("HandMesh", hand_arrays))
	_mesh.visible = false
	_apply_part_visibility()


func _make_part(part_name: String, arrays: Array) -> MeshInstance3D:
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = array_mesh
	part.skin = _mesh.skin
	var host := _mesh.get_parent()
	host.add_child(part)
	part.transform = _mesh.transform
	part.cast_shadow = _mesh.cast_shadow
	part.layers = _mesh.layers
	part.skeleton = part.get_path_to(_skeleton)
	_parts.append(part)
	return part


func _skin_bind(bone_name: String) -> int:
	var skin := _mesh.skin
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == bone_name:
			return i
		var bone := skin.get_bind_bone(i)
		if bone >= 0 and _skeleton.get_bone_name(bone) == bone_name:
			return i
	return -1


func _vertex_is_bone(bones: PackedInt32Array, weights: PackedFloat32Array, vertex: int,
		bind: int, stride: int) -> bool:
	var base := vertex * stride
	if base + stride > bones.size() or base + stride > weights.size():
		return false
	var best_slot := 0
	var best_w := -1.0
	for slot in stride:
		var w := weights[base + slot]
		if w > best_w:
			best_w = w
			best_slot = slot
	return best_w > 0.0 and bones[base + best_slot] == bind


## Hand.L / Hand.R and every finger bone under them. A fingertip weighted only
## to Index1 would otherwise fall into the shelved body and vanish in VR.
func _collect_hand_binds() -> Dictionary:
	var binds := {}
	for i in _skeleton.get_bone_count():
		if not _bone_is_hand(i):
			continue
		var bind := _skin_bind(_skeleton.get_bone_name(i))
		if bind >= 0:
			binds[bind] = true
	return binds


func _bone_is_hand(bone: int) -> bool:
	var guard := 0
	while bone >= 0 and guard < 12:
		var bone_name := _skeleton.get_bone_name(bone)
		if bone_name == "Hand.L" or bone_name == "Hand.R":
			return true
		bone = _skeleton.get_bone_parent(bone)
		guard += 1
	return false


func _vertex_in_binds(bones: PackedInt32Array, weights: PackedFloat32Array, vertex: int,
		binds: Dictionary, stride: int) -> bool:
	var base := vertex * stride
	if base + stride > bones.size() or base + stride > weights.size():
		return false
	var best_slot := 0
	var best_w := -1.0
	for slot in stride:
		var w := weights[base + slot]
		if w > best_w:
			best_w = w
			best_slot = slot
	return best_w > 0.0 and binds.has(bones[base + best_slot])
