class_name PropRadial
extends Node3D
## VR equip wheel: `Label3D` wedges on a ring floating in front of the off hand,
## kept facing the HMD. The flat harness draws its own 2D wheel on the Hud
## (`ui/prop_radial_overlay.gd`) instead of using this node.

const RADIUS := 0.085
const COLOR_IDLE := Color(0.85, 0.82, 0.75, 0.75)
const COLOR_HIGHLIGHT := Color(1.0, 0.78, 0.3)

var _wedges: Array[Label3D] = []
var _hint: Label3D


func setup(labels: PackedStringArray) -> void:
	_hint = _make_label("", Vector3.ZERO, 20)
	for i in labels.size():
		var angle := TAU * float(i) / float(labels.size())
		var offset := Vector3(sin(angle) * RADIUS, cos(angle) * RADIUS, 0.0)
		_wedges.append(_make_label(labels[i], offset, 26))
	set_highlight(-1)


func set_highlight(index: int) -> void:
	for i in _wedges.size():
		var active := i == index
		_wedges[i].modulate = COLOR_HIGHLIGHT if active else COLOR_IDLE
		_wedges[i].scale = Vector3.ONE * (1.25 if active else 1.0)
	if _hint != null:
		_hint.text = "release to cancel" if index < 0 else "release to equip"


## Ride the hand's position but keep the ring square to the headset, so tilting
## the stick (and the controller with it) does not roll the wheel.
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_camera := camera.global_position - global_position
	if to_camera.length_squared() < 0.0001:
		return
	if absf(to_camera.normalized().dot(Vector3.UP)) > 0.99:
		return
	global_basis = Basis.looking_at(to_camera, Vector3.UP)


func _make_label(text: String, offset: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0012
	label.outline_size = 10
	label.no_depth_test = true
	label.position = offset
	add_child(label)
	return label
