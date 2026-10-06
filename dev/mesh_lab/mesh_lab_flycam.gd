class_name MeshLabFlycam
extends Node
## WASD + mouse spectator. W moves along the look direction. In flat this
## camera is current on the main view. In VR it lives in a second window that
## shares the lab world, so the headset keeps its own camera.

const FLY_SPEED := 4.0
const START_POS := Vector3(0.0, 1.6, 3.5)

var _camera: Camera3D
var _window: Window
var _subviewport: SubViewport
var _yaw := 0.0
var _pitch := 0.0


func attach_flat(world: Node3D) -> void:
	_camera = _make_camera(world)
	_camera.current = true
	_place_start()


func attach_vr(host: Node, world: World3D, environment: Environment) -> void:
	_window = Window.new()
	_window.name = "MeshLabWindow"
	_window.title = "Mesh lab"
	_window.size = Vector2i(1280, 720)
	_window.min_size = Vector2i(640, 360)
	host.add_child(_window)
	var container := SubViewportContainer.new()
	container.name = "View"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(container)
	_subviewport = SubViewport.new()
	_subviewport.name = "LabView"
	_subviewport.size = _window.size
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.handle_input_locally = false
	container.add_child(_subviewport)
	_subviewport.own_world_3d = false
	_subviewport.world_3d = world
	_camera = _make_camera(_subviewport)
	_camera.environment = environment
	_place_start()
	_window.size_changed.connect(_on_window_resized)
	_window.position = Vector2i(64, 64)
	_window.grab_focus()
	if get_parent() != null:
		get_parent().remove_child(self)
	_window.add_child(self)


func mount_menu(menu: CanvasLayer) -> void:
	if _window != null:
		_window.add_child(menu)


func shutdown() -> void:
	if is_instance_valid(_camera):
		_camera.current = false
	if is_instance_valid(_window):
		_window.queue_free()
		_window = null
		_camera = null
		_subviewport = null
		return
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	queue_free()


func _process(delta: float) -> void:
	if not is_instance_valid(_camera) or not _accepts_fly():
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := _camera.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	var pos := _camera.global_position + wish * FLY_SPEED * delta
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), pos)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_camera) or not _accepts_look():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := MovementConfig.mouse_sensitivity
		_yaw -= motion.relative.x * sens
		_pitch = clampf(_pitch - motion.relative.y * sens, deg_to_rad(-89.0), deg_to_rad(89.0))
		_camera.global_transform = Transform3D(
				Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), _camera.global_position)
		get_viewport().set_input_as_handled()


func _accepts_fly() -> bool:
	if not _window_focused():
		return false
	return not _debug_panel_open()


func _accepts_look() -> bool:
	if not _window_focused():
		return false
	return not _debug_panel_open()


func _window_focused() -> bool:
	if _window == null:
		return true
	return is_instance_valid(_window) and _window.has_focus()


func _debug_panel_open() -> bool:
	return not GameManager.is_vr and DebugMenu.panel != null and DebugMenu.panel.visible


func _on_window_resized() -> void:
	if is_instance_valid(_window) and is_instance_valid(_subviewport):
		_subviewport.size = _window.size


func _place_start() -> void:
	_yaw = 0.0
	_pitch = 0.0
	_camera.global_transform = Transform3D(Basis.IDENTITY, START_POS)


func _make_camera(parent: Node) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "MeshLabCamera"
	camera.fov = 70.0
	camera.cull_mask = 0xfffff
	parent.add_child(camera)
	camera.current = true
	return camera
