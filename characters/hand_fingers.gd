class_name HandFingers
extends Node
## Blends the mannequin's finger bones after arm IK. Poses are sampled from the
## glTF actions on `dummy.glb` (Open, Pistol, PistolTrigger, Bottle, Pinch, Fist).
## The index bones slide from Pistol toward PistolTrigger with the trigger pull.

enum Pose { OPEN, PISTOL, BOTTLE, PINCH, FIST }

const POSE_NAMES: PackedStringArray = [
	"Open", "Pistol", "Bottle", "Pinch", "Fist",
]
const TRIGGER_POSE := "PistolTrigger"
const PREFIXES: PackedStringArray = ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const BLEND_SEC := 0.1
const TRIGGER_STEPS := 15

var _skeleton: Skeleton3D
var _bones: Array[String] = []
var _bone_idx: Dictionary = {}
var _library: Dictionary = {}
var _current: Dictionary = {}
var _pose := {&"L": Pose.OPEN, &"R": Pose.OPEN}
var _trigger := {&"L": 0.0, &"R": 0.0}


static func pack(left_pose: int, right_pose: int, left_trigger: float, right_trigger: float) -> int:
	var lt := _quantize(left_trigger)
	var rt := _quantize(right_trigger)
	return (left_pose & 7) | ((right_pose & 7) << 3) | (lt << 6) | (rt << 10)


static func unpack_pose(packed: int, right: bool) -> int:
	return (packed >> (3 if right else 0)) & 7


static func unpack_trigger(packed: int, right: bool) -> float:
	var bits := (packed >> (10 if right else 6)) & 15
	return float(bits) / float(TRIGGER_STEPS)


static func _quantize(value: float) -> int:
	return clampi(int(round(clampf(value, 0.0, 1.0) * float(TRIGGER_STEPS))), 0, TRIGGER_STEPS)


func setup(skeleton: Skeleton3D, visual: Node) -> void:
	_skeleton = skeleton
	process_priority = 30
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		if not _is_finger(bone_name):
			continue
		_bones.append(bone_name)
		_bone_idx[bone_name] = i
		_current[bone_name] = Quaternion.IDENTITY
	_library[TRIGGER_POSE] = {}
	for pose_name in POSE_NAMES:
		_library[pose_name] = {}
	var player := _find_player(visual)
	if player != null:
		_read_library(player)
		player.active = false
	for bone_name in _bones:
		_current[bone_name] = _rotation(Pose.OPEN, bone_name)


func set_curl(positive_x: bool, pose: int, trigger: float) -> void:
	var suffix: StringName = &"R" if positive_x else &"L"
	_pose[suffix] = clampi(pose, Pose.OPEN, Pose.FIST)
	_trigger[suffix] = clampf(trigger, 0.0, 1.0)


func _process(delta: float) -> void:
	if _skeleton == null or _bones.is_empty():
		return
	var t := 1.0 - exp(-delta / BLEND_SEC)
	for bone_name in _bones:
		var suffix: StringName = &"R" if bone_name.ends_with(".R") else &"L"
		var goal := _goal(bone_name, int(_pose[suffix]), float(_trigger[suffix]))
		var current: Quaternion = _current[bone_name]
		current = current.slerp(goal, clampf(t, 0.0, 1.0))
		_current[bone_name] = current
		_skeleton.set_bone_pose_rotation(int(_bone_idx[bone_name]), current)


func _goal(bone_name: String, pose: int, trigger: float) -> Quaternion:
	var goal := _rotation(pose, bone_name)
	if pose == Pose.PISTOL and bone_name.begins_with("Index"):
		goal = goal.slerp(_rotation_named(TRIGGER_POSE, bone_name), trigger)
	return goal


func _rotation(pose: int, bone_name: String) -> Quaternion:
	var pose_name := "Open"
	if pose >= 0 and pose < POSE_NAMES.size():
		pose_name = POSE_NAMES[pose]
	return _rotation_named(pose_name, bone_name)


func _rotation_named(pose_name: String, bone_name: String) -> Quaternion:
	var book: Dictionary = _library.get(pose_name, {})
	if book.has(bone_name):
		return book[bone_name]
	return Quaternion.IDENTITY


func _read_library(player: AnimationPlayer) -> void:
	var names: Array[String] = []
	names.append_array(POSE_NAMES)
	names.append(TRIGGER_POSE)
	for pose_name in names:
		if not player.has_animation(pose_name):
			continue
		var anim := player.get_animation(pose_name)
		var book: Dictionary = _library[pose_name]
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			if anim.track_get_key_count(i) < 1:
				continue
			var bone_name := _bone_from_path(str(anim.track_get_path(i)))
			if not _bone_idx.has(bone_name):
				continue
			var value: Variant = anim.track_get_key_value(i, 0)
			if value is Quaternion:
				book[bone_name] = value


func _find_player(visual: Node) -> AnimationPlayer:
	if visual is AnimationPlayer:
		return visual
	return visual.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _bone_from_path(path: String) -> String:
	var colon := path.rfind(":")
	if colon >= 0:
		return path.substr(colon + 1)
	return path


func _is_finger(bone_name: String) -> bool:
	for prefix in PREFIXES:
		if bone_name.begins_with(prefix):
			return true
	return false
