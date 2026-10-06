class_name MeshLabMotionMenu
extends CanvasLayer
## Flat overlay for the mesh lab. Three independent switches, all on at
## entry. In VR this layer is parented to the spectator window, not the headset.

var _head: CheckBox
var _walk: CheckBox
var _hands: CheckBox


func _ready() -> void:
	# Under the HUD (layer 5) and the debug panel (layer 10), so Esc and F3 cover it.
	layer = 4
	MeshLabMotion.reset()
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.text = "MESH LAB"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Tab releases the mouse. Click the view to look."
	box.add_child(hint)
	_head = _add_check(box, "Head (1)")
	_walk = _add_check(box, "Walk (2)")
	_hands = _add_check(box, "Hands (3)")
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.in_mesh_lab():
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# The flat player is parked, so the rig that normally catches F3 is not running.
	if key.is_action_pressed("toggle_debug"):
		DebugMenu.toggle()
		get_viewport().set_input_as_handled()
		return
	match key.physical_keycode:
		KEY_TAB:
			if not GameManager.is_vr and DebugMenu.panel != null and DebugMenu.panel.visible:
				return
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		KEY_1:
			_flip(_head)
		KEY_2:
			_flip(_walk)
		KEY_3:
			_flip(_hands)


func _flip(box: CheckBox) -> void:
	if box == null:
		return
	box.button_pressed = not box.button_pressed
	get_viewport().set_input_as_handled()


func _add_check(parent: Node, text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = true
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(func(_on: bool) -> void:
		_sync())
	parent.add_child(box)
	return box


func _sync() -> void:
	if _head == null:
		return
	MeshLabMotion.head = _head.button_pressed
	MeshLabMotion.walk = _walk.button_pressed
	MeshLabMotion.hands = _hands.button_pressed
