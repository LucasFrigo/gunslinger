extends Node
## Two-bone reach so the mannequin's wrist meets a target. Bone +Y runs along the limb.
## Runs in _process because a SkeletonModifier3D child is not ticked by this imported skeleton.
## `match_twist` rolls the hand and bends it off the forearm so it follows the target.
## `wrist_inset` places the wrist behind the target along its local +Z, so the fingers run through the grip.
## Rest size matches the glTF mesh (arm about 46 cm, hand about 4 cm wide).
## Past that reach the upper arm and forearm grow along +Y so the wrist still meets the target.
## Shoulders stay on the chest joint.

const ARM_SCALE := 1.0
const HAND_SCALE := 1.0

var target_path: NodePath
var bone_suffix := "R"
var match_twist := false
var wrist_inset := 0.0
var hand_scale := HAND_SCALE
## Extra offset in the target's local space. The revolver grip hangs below its origin.
var grip_local := Vector3.ZERO


func _process(_delta: float) -> void:
	var skeleton: Skeleton3D = get_parent() as Skeleton3D
	var target: Node3D = get_node_or_null(target_path) as Node3D
	if skeleton == null or target == null:
		return
	var upper := skeleton.find_bone("UpperArm." + bone_suffix)
	var forearm := skeleton.find_bone("Forearm." + bone_suffix)
	var hand := skeleton.find_bone("Hand." + bone_suffix)
	if upper < 0 or forearm < 0 or hand < 0:
		return
	var elbow_rest: Vector3 = skeleton.get_bone_global_rest(forearm).origin
	var wrist_rest: Vector3 = skeleton.get_bone_global_rest(hand).origin
	var shoulder_rest: Vector3 = skeleton.get_bone_global_rest(upper).origin
	# Posed chest, not the bind shoulder, so a leaned torso keeps the arm attached.
	var shoulder := _joint_origin(skeleton, upper)
	var upper_len := shoulder_rest.distance_to(elbow_rest) * ARM_SCALE
	var fore_len := elbow_rest.distance_to(wrist_rest) * ARM_SCALE
	var anchor := target.global_position
	if grip_local != Vector3.ZERO:
		anchor = target.to_global(grip_local)
	var goal: Vector3 = skeleton.global_transform.affine_inverse() * anchor
	# Sit the wrist behind the target along its grip, so the fingers run through
	# the controller or the gun. Pulling toward the shoulder leaves the hand
	# beside the barrel whenever the arm is not in line with it.
	if wrist_inset > 0.0:
		var back: Vector3 = skeleton.global_transform.basis.inverse() * target.global_transform.basis.z
		if back.length_squared() > 0.000001:
			goal += back.normalized() * wrist_inset * hand_scale
	var reach := goal - shoulder
	var dist := reach.length()
	var rest_reach := upper_len + fore_len
	# Past the scaled length the bones grow further along the limb so the wrist stays on the controller.
	var extra := 1.0
	if dist > rest_reach and rest_reach > 0.001:
		extra = dist / rest_reach
		upper_len *= extra
		fore_len *= extra
	var limit := upper_len + fore_len
	if extra <= 1.0:
		limit -= 0.01
	var span := clampf(dist, 0.05, limit)
	if dist > 0.001:
		goal = shoulder + reach / dist * span
	else:
		goal = shoulder
	# Elbow stays behind the chest (-Z). A short pole flips when the hand rises to the gun.
	var pole := shoulder + Vector3(0.0, -0.5, -1.0)
	var elbow := _joint(shoulder, goal, pole, upper_len, fore_len)
	var length_scale := ARM_SCALE * extra
	_aim(skeleton, upper, shoulder, elbow, length_scale, ARM_SCALE)
	_aim(skeleton, forearm, elbow, goal, length_scale, ARM_SCALE)
	if match_twist:
		_aim_twisted(skeleton, hand, goal, elbow, target)
		return
	var fingers := wrist_rest - elbow_rest
	if fingers.length_squared() < 0.0001:
		fingers = (goal - elbow).normalized() * 0.08
	_aim(skeleton, hand, goal, goal + fingers.normalized() * fingers.length(), hand_scale, hand_scale)


func _joint(root: Vector3, tip: Vector3, pole: Vector3, root_len: float, tip_len: float) -> Vector3:
	var axis := tip - root
	var dist := maxf(axis.length(), 0.001)
	axis /= dist
	var cos_angle := clampf(
		(root_len * root_len + dist * dist - tip_len * tip_len) / (2.0 * root_len * dist),
		-1.0, 1.0)
	var along := axis * (root_len * cos_angle)
	var bend := (pole - root).slide(axis)
	if bend.length_squared() < 0.000001:
		bend = Vector3.DOWN.slide(axis)
	bend = bend.normalized() * (root_len * sqrt(maxf(1.0 - cos_angle * cos_angle, 0.0)))
	return root + along + bend


func _joint_origin(skeleton: Skeleton3D, bone: int) -> Vector3:
	var rest := skeleton.get_bone_rest(bone)
	var parent := skeleton.get_bone_parent(bone)
	if parent < 0:
		return rest.origin
	return (skeleton.get_bone_global_pose(parent) * rest).origin


func _aim(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3, length_scale := 1.0, thickness := 1.0) -> void:
	var y := to - from
	if y.length_squared() < 0.000001:
		return
	y = y.normalized()
	var rest := skeleton.get_bone_global_rest(bone)
	var x := rest.basis.x.slide(y)
	if x.length_squared() < 0.000001:
		x = rest.basis.z.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	var girth := maxf(thickness, 0.001)
	x *= girth
	z *= girth
	y *= maxf(length_scale, 0.001)
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(x, y, z), from))


## Fingers follow the controller point. A pistol grip is often near a right angle
## to the forearm, so the clamp stays wide enough for the hand to meet the gun.
const MAX_WRIST_BEND := deg_to_rad(110.0)


## Hand +Y follows the target's pointing axis (-Z), swung off the forearm for
## wrist flexion and radial/ulnar tilt. Roll follows the target's X, then flips
## 180° so the thumb points with the grip's up instead of down.
func _aim_twisted(skeleton: Skeleton3D, bone: int, wrist: Vector3, elbow: Vector3, target: Node3D) -> void:
	var forearm_y := wrist - elbow
	if forearm_y.length_squared() < 0.000001:
		return
	forearm_y = forearm_y.normalized()
	var rest := skeleton.get_bone_global_rest(bone)
	var ctrl := (skeleton.global_transform.basis.inverse() * target.global_transform.basis).orthonormalized()
	var y := -ctrl.z
	if y.length_squared() < 0.000001:
		y = forearm_y
	else:
		y = y.normalized()
		var bend := forearm_y.angle_to(y)
		if bend > MAX_WRIST_BEND and bend > 0.0001:
			y = forearm_y.slerp(y, MAX_WRIST_BEND / bend)
	var x := (-ctrl.x).slide(y)
	if x.length_squared() < 0.000001:
		x = rest.basis.x.slide(y)
	if x.length_squared() < 0.000001:
		x = rest.basis.z.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	var girth := hand_scale
	x *= girth
	y *= girth
	z *= girth
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(x, y, z), wrist))
