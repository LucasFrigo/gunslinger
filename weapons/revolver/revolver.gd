class_name Revolver
extends WeaponBase
## Six-shooter. Greybox visuals live in revolver.tscn; swap the placeholder
## meshes for a real model without touching this script.
## Reload: open gate (VR B / Flat R), shake to dump, belt-feed physical
## cartridges, close via bump/swing (Flat Space). VR spatial checks are
## Area3D volumes (`ChamberArea`, `BumpArea`) on physics layer `reload`.

const GATE_CYLINDER_YAW := deg_to_rad(18.0)

@onready var _cylinder: MeshInstance3D = $Cylinder
@onready var _chamber: Marker3D = $Chamber
@onready var chamber_area: Area3D = $Chamber/ChamberArea
@onready var bump_area: Area3D = $BumpArea

var _cylinder_closed_basis: Basis


func _ready() -> void:
	_cylinder_closed_basis = _cylinder.transform.basis
	_on_gate_changed()


func get_chamber_point() -> Vector3:
	return _chamber.global_position


func _on_gate_changed() -> void:
	if _cylinder == null:
		return
	if gate_open:
		_cylinder.transform.basis = _cylinder_closed_basis.rotated(Vector3.UP, GATE_CYLINDER_YAW)
	else:
		_cylinder.transform.basis = _cylinder_closed_basis
