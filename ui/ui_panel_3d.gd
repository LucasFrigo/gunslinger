class_name UIPanel3D
extends Node3D
## A Control rendered onto a quad in 3D, with pointer input driven either by
## the VR laser pointer or (unused in flat mode, where Controls render
## directly on screen). Used for the VR main menu and the wrist debug panel.

const PX_PER_METER := 1200.0
const GROUP := "ui_panels"

@export var panel_size := Vector2(0.8, 0.55)

var viewport: SubViewport
var _quad: MeshInstance3D
var _area: Area3D
var _control: Control


func _ready() -> void:
	add_to_group(GROUP)

	viewport = SubViewport.new()
	viewport.size = Vector2i(panel_size * PX_PER_METER)
	viewport.transparent_bg = false
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var mesh := QuadMesh.new()
	mesh.size = panel_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	_quad = MeshInstance3D.new()
	_quad.mesh = mesh
	add_child(_quad)

	_area = Area3D.new()
	_area.collision_layer = 0b1000  # interactable layer (4)
	_area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(panel_size.x, panel_size.y, 0.02)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


## Adopt a Control into this panel's viewport (reparents it).
func set_control(control: Control) -> void:
	release_control()
	_control = control
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	viewport.add_child(control)
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.visible = true


## Remove and return the adopted Control (so it can go back to a CanvasLayer).
func release_control() -> Control:
	var control := _control
	_control = null
	if control != null and control.get_parent() == viewport:
		viewport.remove_child(control)
	return control


func owns_area(area: Area3D) -> bool:
	return area == _area


# -- Pointer input -------------------------------------------------------------

func pointer_move(world_point: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _to_viewport(world_point)
	viewport.push_input(event)


func pointer_click(world_point: Vector3, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _to_viewport(world_point)
	viewport.push_input(event)


func _to_viewport(world_point: Vector3) -> Vector2:
	var local := _quad.to_local(world_point)
	var uv := Vector2(
		local.x / panel_size.x + 0.5,
		0.5 - local.y / panel_size.y)
	return uv * Vector2(viewport.size)
