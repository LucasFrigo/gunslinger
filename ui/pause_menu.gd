class_name PauseMenu
extends Control
## In-duel overlay. Freezes the tree in single-player; MP stays live.
## Settings is the same player-facing page as the main menu.

var is_open := false

@onready var pause_root: VBoxContainer = %PauseRoot
@onready var settings_menu: SettingsMenu = $Center/Panel/Margin/SettingsMenu
@onready var title_label: Label = %TitleLabel
@onready var restart_button: Button = %RestartButton
@onready var host_note: Label = %HostNote


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	settings_menu.visible = false
	%ResumeButton.pressed.connect(close)
	%SettingsButton.pressed.connect(_show_settings)
	settings_menu.back_pressed.connect(show_pause_root)
	restart_button.pressed.connect(_on_restart)
	%QuitButton.pressed.connect(_on_quit)


func is_settings_open() -> bool:
	return settings_menu.visible


func show_pause_root() -> void:
	pause_root.visible = true
	settings_menu.visible = false


func _show_settings() -> void:
	pause_root.visible = false
	settings_menu.visible = true
	settings_menu.refresh()


func open() -> void:
	if is_open or not _in_match():
		return
	DebugMenu.close()
	is_open = true
	show_pause_root()
	_refresh_buttons()
	if not NetworkManager.is_active():
		get_tree().paused = true
	if GameManager.is_vr and is_instance_valid(GameManager.local_player):
		visible = true
		GameManager.local_player.show_menu_panel(self)
	else:
		visible = true
		if get_parent() is Control:
			get_parent().visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not is_open:
		return
	is_open = false
	show_pause_root()
	get_tree().paused = false
	if GameManager.is_vr and is_instance_valid(GameManager.local_player):
		GameManager.local_player.hide_menu_panel()
	visible = false
	if get_parent() is Control:
		get_parent().visible = false
	if _in_match() and not GameManager.is_vr:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _refresh_buttons() -> void:
	var networked := NetworkManager.is_active()
	title_label.text = "MENU" if networked else "PAUSED"
	match GameManager.mode:
		GameManager.GameMode.GAUNTLET:
			restart_button.text = "RESTART GAUNTLET"
			restart_button.disabled = false
			host_note.visible = false
		GameManager.GameMode.MULTIPLAYER:
			restart_button.text = "RESTART DUEL"
			restart_button.disabled = not NetworkManager.is_host()
			host_note.visible = restart_button.disabled
		_:
			restart_button.text = "RESTART DUEL"
			restart_button.disabled = false
			host_note.visible = false


func _on_restart() -> void:
	if GameManager.mode == GameManager.GameMode.MULTIPLAYER and not NetworkManager.is_host():
		GameManager.show_message("Only the host can reset the duel.", 2.0)
		return
	var gauntlet := GameManager.mode == GameManager.GameMode.GAUNTLET
	close()
	if gauntlet:
		GameManager.start_gauntlet()
	else:
		GameManager.reset_current_duel()


func _on_quit() -> void:
	close()
	GameManager.go_to_menu()


func _in_match() -> bool:
	return GameManager.mode in [
		GameManager.GameMode.FREE_DUEL,
		GameManager.GameMode.GAUNTLET,
		GameManager.GameMode.MULTIPLAYER,
	]
