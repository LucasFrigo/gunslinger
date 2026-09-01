class_name Hud
extends CanvasLayer
## Screen-space HUD (flat mode) and owner of the main menu / pause Controls,
## which the VR player borrows into a 3D panel via UIPanel3D.

@onready var message_label: Label = $Message
@onready var reload_status: Label = $ReloadStatus
@onready var health_status: Label = $HealthStatus
@onready var version_tag: Label = $VersionTag
@onready var red_flash: ColorRect = $RedFlash
@onready var menu_holder: Control = $MenuHolder
@onready var pause_holder: Control = $PauseHolder

var _menu: MainMenu
var pause_menu: PauseMenu
var _message_timer: SceneTreeTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = $MenuHolder/MainMenu
	pause_menu = $PauseHolder/PauseMenu
	message_label.visible = false
	reload_status.visible = false
	health_status.visible = false
	red_flash.modulate.a = 0.0
	menu_holder.visible = false
	pause_holder.visible = false
	version_tag.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func get_menu_control() -> Control:
	return _menu


func get_pause_control() -> Control:
	return pause_menu


func is_pause_open() -> bool:
	return pause_menu != null and pause_menu.is_open


func close_pause() -> void:
	if pause_menu != null:
		pause_menu.close()


func show_menu(is_vr: bool) -> void:
	close_pause()
	if _menu.has_method("show_mode_select"):
		_menu.show_mode_select()
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
	var home := pause_holder if control == pause_menu else menu_holder
	home.add_child(control)
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	if control != pause_menu:
		home.visible = false


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


## Persistent reload / ammo readout. Empty string hides it.
func set_reload_status(text: String) -> void:
	if text.is_empty():
		reload_status.visible = false
		return
	reload_status.text = text
	reload_status.visible = true


## One-line HP. Hidden when max_hp <= 0 (menu / boot).
func set_health(current: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		health_status.visible = false
		return
	health_status.text = "HP %d / %d" % [ceili(current), ceili(max_hp)]
	health_status.visible = true


func flash_red() -> void:
	red_flash.modulate.a = 0.55
	var tween := create_tween()
	tween.tween_property(red_flash, "modulate:a", 0.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if pause_menu != null and pause_menu.is_open:
		if pause_menu.is_settings_open():
			pause_menu.show_pause_root()
		else:
			pause_menu.close()
		get_viewport().set_input_as_handled()
		return
	if _menu != null and _menu.is_visible_in_tree() and _menu.is_settings_open():
		_menu.show_mode_select()
		get_viewport().set_input_as_handled()
		return
	if pause_menu != null:
		pause_menu.open()
		if pause_menu.is_open:
			get_viewport().set_input_as_handled()
