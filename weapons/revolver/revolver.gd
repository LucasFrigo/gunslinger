class_name Revolver
extends WeaponBase
## Six-shooter. Visuals are the PSX blaster instanced in revolver.tscn
## (`assets/models/weapons/wpn_psx_blaster.glb`); greybox meshes stay hidden.
## Cylinder mesh lives under `Model/.../CylinderPivot` and indexes 60° per shot.
## Reload: open gate (VR B / Flat R) rolls the drum out on a bore hinge — to the
## side and down, mirrored when the gun changes hands — then shake to dump,
## belt-feed physical cartridges, close via bump/swing (Flat Space). VR spatial
## checks are Area3D volumes (`ChamberArea`, `BumpArea`) on physics layer `reload`.

const CHAMBER_STEP := TAU / 6.0
const GATE_TWEEN := 0.12
const SPIN_TWEEN := 0.07
const KICK_BACK := 0.011
const KICK_OUT := 0.035
const KICK_IN := 0.07
## Drum axis after glTF (+Y up): Blender +Y → Godot −Z.
const CYLINDER_AXIS := Vector3(0.0, 0.0, -1.0)
## Gate rolls around the bore so the drum stays parallel to the barrel.
const GATE_AXIS := Vector3(0.0, 0.0, 1.0)
const GATE_ROLL := deg_to_rad(82.0)
## Hinge sits just off the drum, above the bore, on the frame side of the swing.
const GATE_HINGE := Vector3(0.030, 0.004, 0.0)

@onready var _model: Node3D = $Model
@onready var _cylinder_pivot: Node3D = $Model/WPN_PSX_Blaster/CylinderPivot
@onready var _cylinder: MeshInstance3D = $Model/WPN_PSX_Blaster/CylinderPivot/Cylinder
@onready var _chamber: Marker3D = $Chamber
@onready var chamber_area: Area3D = $Chamber/ChamberArea
@onready var bump_area: Area3D = $BumpArea

var _pivot_rest: Basis
var _pivot_origin: Vector3
var _cylinder_rest: Basis
var _model_rest: Transform3D
var _chamber_index := 0
var _gate_tween: Tween
var _spin_tween: Tween
var _kick_tween: Tween


func _ready() -> void:
	_pivot_rest = _cylinder_pivot.transform.basis
	_pivot_origin = _cylinder_pivot.transform.origin
	_cylinder_rest = _cylinder.transform.basis
	_model_rest = _model.transform
	fired.connect(_on_fired)
	_apply_cylinder_pose(true)


func get_chamber_point() -> Vector3:
	return _chamber.global_position


func reset() -> void:
	_chamber_index = 0
	if _kick_tween != null:
		_kick_tween.kill()
	if _model != null:
		_model.transform = _model_rest
	super.reset()
	_apply_cylinder_pose(true)


func fill_cylinder() -> bool:
	var ok := super.fill_cylinder()
	if ok:
		_chamber_index = 0
		_spin_cylinder(true)
	return ok


func attach_to(hand_attach: Node3D, rumble_hand: StringName = &"right_hand") -> void:
	var prev_hand := shooting_hand
	super.attach_to(hand_attach, rumble_hand)
	if gate_open and prev_hand != rumble_hand:
		_on_gate_changed()


func _on_gate_changed() -> void:
	if _cylinder_pivot == null:
		return
	var target := _gate_pivot_transform()
	if _gate_tween != null:
		_gate_tween.kill()
	if not is_inside_tree():
		_cylinder_pivot.transform = target
		return
	_gate_tween = create_tween()
	_gate_tween.tween_property(_cylinder_pivot, "transform", target, GATE_TWEEN).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)


func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	_chamber_index = (_chamber_index + 1) % max_rounds
	_spin_cylinder(false)
	_kick_barrel()


func _spin_cylinder(snap: bool) -> void:
	if _cylinder == null:
		return
	var target := _cylinder.transform
	target.basis = _cylinder_rest.rotated(CYLINDER_AXIS, _chamber_index * CHAMBER_STEP)
	if _spin_tween != null:
		_spin_tween.kill()
	if snap or not is_inside_tree():
		_cylinder.transform = target
		return
	_spin_tween = create_tween()
	_spin_tween.tween_property(_cylinder, "transform", target, SPIN_TWEEN).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)


func _kick_barrel() -> void:
	if _model == null:
		return
	if _kick_tween != null:
		_kick_tween.kill()
	_model.transform = _model_rest
	var kicked := _model_rest
	kicked.origin.z += KICK_BACK
	_kick_tween = create_tween()
	_kick_tween.tween_property(_model, "transform", kicked, KICK_OUT).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_model, "transform", _model_rest, KICK_IN).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)


func _apply_cylinder_pose(snap: bool) -> void:
	if _gate_tween != null:
		_gate_tween.kill()
	_spin_cylinder(snap)
	if _cylinder_pivot == null:
		return
	_cylinder_pivot.transform = _gate_pivot_transform()


## Right hand rolls the drum toward local -X (off hand) and down. Left hand mirrors.
func _gate_pivot_transform() -> Transform3D:
	var closed := Transform3D(_pivot_rest, _pivot_origin)
	if not gate_open:
		return closed
	var sign := -1.0 if shooting_hand == &"left_hand" else 1.0
	var hinge := _pivot_origin + Vector3(-sign * GATE_HINGE.x, GATE_HINGE.y, GATE_HINGE.z)
	var swing := Basis(GATE_AXIS, -sign * GATE_ROLL)
	var offset := _pivot_origin - hinge
	return Transform3D(swing * _pivot_rest, hinge + swing * offset)
