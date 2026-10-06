class_name UIPanel3D
extends Node3D
## A Control rendered onto a quad in 3D, with pointer input driven either by
## the VR laser pointer or (unused in flat mode, where Controls render
## directly on screen). Used for the VR main menu and the wrist debug panel.

const PX_PER_METER := 1200.0
const GROUP := "ui_panels"
## Full-stick scroll, in pages per second (uses the bar's visible page).
const STICK_SCROLL_PAGES_PER_SEC := 1.6
## Extra pixels around a doubled scrollbar so the laser can grab it.
const SCROLLBAR_HIT_PAD := 8.0

@export var panel_size := Vector2(0.8, 0.55)

var viewport: SubViewport
var _quad: MeshInstance3D
var _area: Area3D
var _control: Control
var _pointer_down := false
var _has_pointer := false
var _pointer_pos := Vector2.ZERO
var _drag_bar: ScrollBar
var _drag_grab_delta := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_thicken_scrollbars(control)


## Remove and return the adopted Control (so it can go back to a CanvasLayer).
func release_control() -> Control:
	_end_pointer()
	var control := _control
	_control = null
	if control != null:
		_restore_scrollbars(control)
		if control.get_parent() == viewport:
			viewport.remove_child(control)
	return control


func owns_area(area: Area3D) -> bool:
	return area == _area


# -- Pointer input -------------------------------------------------------------

func pointer_move(world_point: Vector3) -> void:
	var pos := _to_viewport(world_point)
	var relative := Vector2.ZERO
	if _has_pointer:
		relative = pos - _pointer_pos
	_pointer_pos = pos
	_has_pointer = true
	if _pointer_down and _drag_bar != null:
		_drag_scrollbar_to(pos)
		return
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = relative
	if _pointer_down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event)


func pointer_click(world_point: Vector3, pressed: bool) -> void:
	var pos := _to_viewport(world_point)
	_pointer_pos = pos
	_has_pointer = true
	if pressed:
		_pointer_down = true
		_drag_bar = _scrollbar_at(_control, pos)
		if _drag_bar != null:
			_begin_scrollbar_drag(_drag_bar, pos)
			return
	else:
		var was_drag := _drag_bar != null
		_pointer_down = false
		_drag_bar = null
		if was_drag:
			return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	viewport.push_input(event)


## Ray left this panel while the trigger was still down.
func pointer_cancel() -> void:
	if _pointer_down and _drag_bar == null and viewport != null:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = false
		event.position = _pointer_pos
		event.global_position = _pointer_pos
		viewport.push_input(event)
	_end_pointer()


## True when the pointer is on a scrollable page (or this panel has one scroll view).
func has_scroll_target() -> bool:
	return _scroll_target() != null


## Right-stick Y. Positive scrolls toward the top. `delta` is the process delta.
func apply_stick_scroll(stick_y: float, delta: float) -> void:
	if is_zero_approx(stick_y):
		return
	var host := _scroll_target()
	if host == null:
		return
	var bar: ScrollBar = host.call("get_v_scroll_bar")
	if bar == null:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var page := maxf(bar.page, 240.0)
	bar.value = clampf(
		bar.value - stick_y * page * STICK_SCROLL_PAGES_PER_SEC * real_delta,
		bar.min_value,
		bar.max_value)


func _end_pointer() -> void:
	_pointer_down = false
	_drag_bar = null
	_has_pointer = false


func _to_viewport(world_point: Vector3) -> Vector2:
	var local := _quad.to_local(world_point)
	var uv := Vector2(
		local.x / panel_size.x + 0.5,
		0.5 - local.y / panel_size.y)
	return uv * Vector2(viewport.size)


# -- Scrollbars ----------------------------------------------------------------

func _is_scroll_host(node: Node) -> bool:
	return node is Control and node.has_method("get_v_scroll_bar")


func _thicken_scrollbars(node: Node) -> void:
	if _is_scroll_host(node):
		_thicken_bar(node.call("get_v_scroll_bar"))
		if node.has_method("get_h_scroll_bar"):
			_thicken_bar(node.call("get_h_scroll_bar"))
	for child in node.get_children():
		_thicken_scrollbars(child)


func _restore_scrollbars(node: Node) -> void:
	if node is ScrollBar and node.has_meta(&"vr_bar_base_min"):
		(node as ScrollBar).custom_minimum_size = node.get_meta(&"vr_bar_base_min")
		node.remove_meta(&"vr_bar_base_min")
	for child in node.get_children():
		_restore_scrollbars(child)


func _thicken_bar(bar: Variant) -> void:
	if not bar is ScrollBar:
		return
	var scroll_bar := bar as ScrollBar
	if scroll_bar.has_meta(&"vr_bar_base_min"):
		return
	var vertical := scroll_bar is VScrollBar
	var theme_min := scroll_bar.get_combined_minimum_size()
	var thickness := theme_min.x if vertical else theme_min.y
	if thickness < 4.0:
		thickness = 12.0
	scroll_bar.set_meta(&"vr_bar_base_min", scroll_bar.custom_minimum_size)
	var sized := scroll_bar.custom_minimum_size
	if vertical:
		sized.x = maxf(sized.x, thickness * 2.0)
	else:
		sized.y = maxf(sized.y, thickness * 2.0)
	scroll_bar.custom_minimum_size = sized


func _scrollbar_at(node: Node, pos: Vector2) -> ScrollBar:
	if node == null:
		return null
	if node is ScrollBar:
		var bar := node as ScrollBar
		if bar.visible and _bar_hit_rect(bar).has_point(pos):
			return bar
	for child in node.get_children():
		var found := _scrollbar_at(child, pos)
		if found != null:
			return found
	return null


func _bar_hit_rect(bar: ScrollBar) -> Rect2:
	return bar.get_global_rect().grow(SCROLLBAR_HIT_PAD)


func _begin_scrollbar_drag(bar: ScrollBar, pos: Vector2) -> void:
	var vertical := bar is VScrollBar
	var rect := bar.get_global_rect()
	var along := (pos.y - rect.position.y) if vertical else (pos.x - rect.position.x)
	var area := rect.size.y if vertical else rect.size.x
	var grabber := _grabber_size(bar, area)
	var center := _grabber_offset(bar, area, grabber) + grabber * 0.5
	if along >= center - grabber * 0.5 and along <= center + grabber * 0.5:
		_drag_grab_delta = along - center
	else:
		_drag_grab_delta = 0.0
	_drag_scrollbar_to(pos)


func _drag_scrollbar_to(pos: Vector2) -> void:
	if _drag_bar == null:
		return
	var vertical := _drag_bar is VScrollBar
	var rect := _drag_bar.get_global_rect()
	var along := (pos.y - rect.position.y) if vertical else (pos.x - rect.position.x)
	var area := rect.size.y if vertical else rect.size.x
	_set_bar_from_along(_drag_bar, along - _drag_grab_delta, area)


func _grabber_size(bar: ScrollBar, area: float) -> float:
	var span := bar.max_value - bar.min_value
	var denom := span + bar.page
	if denom <= 0.001 or area <= 0.001:
		return area
	return clampf(area * bar.page / denom, 0.0, area)


func _grabber_offset(bar: ScrollBar, area: float, grabber: float) -> float:
	var span := bar.max_value - bar.min_value
	if span <= 0.001:
		return 0.0
	var ratio := clampf((bar.value - bar.min_value) / span, 0.0, 1.0)
	return (area - grabber) * ratio


func _set_bar_from_along(bar: ScrollBar, along: float, area: float) -> void:
	var span := bar.max_value - bar.min_value
	if span <= 0.001 or area <= 0.001:
		return
	var grabber := _grabber_size(bar, area)
	var travel := maxf(area - grabber, 0.001)
	var t := clampf((along - grabber * 0.5) / travel, 0.0, 1.0)
	bar.value = bar.min_value + t * span


func _scroll_target() -> Control:
	if _control == null or not _has_pointer:
		return null
	var under := _scroll_host_at(_control, _pointer_pos)
	if under != null:
		return under
	var hosts := _visible_scroll_hosts(_control)
	if hosts.size() == 1:
		return hosts[0]
	return null


func _scroll_host_at(node: Node, pos: Vector2) -> Control:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return null
	var found: Control = null
	if _is_scroll_host(node) and (node as Control).get_global_rect().has_point(pos):
		found = node as Control
	for child in node.get_children():
		var deeper := _scroll_host_at(child, pos)
		if deeper != null:
			return deeper
	return found


func _visible_scroll_hosts(node: Node) -> Array[Control]:
	var hosts: Array[Control] = []
	_collect_scroll_hosts(node, hosts)
	return hosts


func _collect_scroll_hosts(node: Node, hosts: Array[Control]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if _is_scroll_host(node):
		hosts.append(node as Control)
	for child in node.get_children():
		_collect_scroll_hosts(child, hosts)
