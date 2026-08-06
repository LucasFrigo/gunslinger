class_name Hud
extends CanvasLayer
## Screen-space HUD (flat mode) and owner of the main menu Control, which the
## VR player borrows into a 3D panel via UIPanel3D.

@onready var message_label: Label = $Message
@onready var red_flash: ColorRect = $RedFlash
@onready var menu_holder: Control = $MenuHolder

var _menu: Control
var _message_timer: SceneTreeTimer


func _ready() -> void:
	_menu = $MenuHolder/MainMenu
	message_label.visible = false
	red_flash.modulate.a = 0.0
	menu_holder.visible = false


func get_menu_control() -> Control:
	return _menu


func show_menu(is_vr: bool) -> void:
	if is_vr:
		menu_holder.visible = false
		return
	if _menu.get_parent() != menu_holder:
		_reparent_menu_home()
	_menu.visible = true
	menu_holder.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	menu_holder.visible = false


## Called when a VR menu panel is torn down and gives the Control back.
func reclaim_menu(control: Control) -> void:
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	menu_holder.add_child(control)
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_holder.visible = false


func _reparent_menu_home() -> void:
	reclaim_menu(_menu)


func show_message(text: String, duration := 2.5) -> void:
	message_label.text = text
	message_label.visible = true
	# Real-time timer so messages don't linger forever during slow-mo.
	_message_timer = get_tree().create_timer(duration, true, false, true)
	var timer := _message_timer
	timer.timeout.connect(func() -> void:
		if _message_timer == timer:
			message_label.visible = false)


func flash_red() -> void:
	red_flash.modulate.a = 0.55
	var tween := create_tween()
	tween.tween_property(red_flash, "modulate:a", 0.0, 0.6)
