class_name PauseMenu
extends Control
## In-duel overlay. Freezes the tree in single-player; MP stays live.
## Settings is the same player-facing page as the main menu.

var is_open := false
## Host: the Lobby page opens by itself when the session starts and when the lobby fills.
## Off in the autotests, whose processes drive the roster without a player at the menu.
var auto_open_lobby := true

var _lobby_full := false

@onready var pause_root: VBoxContainer = %PauseRoot
@onready var settings_menu: SettingsMenu = $Center/Panel/Margin/SettingsMenu
@onready var lobby_page: VBoxContainer = %LobbyPage
@onready var lobby_panel: LobbyPanel = %LobbyPanel
@onready var lobby_button: Button = %LobbyButton
@onready var title_label: Label = %TitleLabel
@onready var restart_button: Button = %RestartButton
@onready var host_note: Label = %HostNote


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	settings_menu.visible = false
	lobby_page.visible = false
	%ResumeButton.pressed.connect(close)
	%SettingsButton.pressed.connect(_show_settings)
	lobby_button.pressed.connect(show_lobby)
	%LobbyBackButton.pressed.connect(show_pause_root)
	lobby_panel.started.connect(close)
	%InviteButton.pressed.connect(_on_invite)
	settings_menu.back_pressed.connect(show_pause_root)
	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.roster_changed.connect(_on_roster_changed)
	restart_button.pressed.connect(_on_restart)
	%QuitButton.pressed.connect(_on_quit)


func is_settings_open() -> bool:
	return settings_menu.visible


func is_lobby_open() -> bool:
	return lobby_page.visible


## Settings or Lobby: Back / Esc returns to the root page.
func is_subpage_open() -> bool:
	return settings_menu.visible or lobby_page.visible


func show_pause_root() -> void:
	pause_root.visible = true
	settings_menu.visible = false
	lobby_page.visible = false


## Multiplayer: the lobby roster, its host controls, and the player's own side.
func show_lobby() -> void:
	pause_root.visible = false
	settings_menu.visible = false
	lobby_page.visible = true
	lobby_panel.refresh()


func _show_settings() -> void:
	pause_root.visible = false
	lobby_page.visible = false
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
	title_label.text = tr("PAUSE_TITLE_MP") if networked else tr("PAUSE_TITLE")
	var steam_host := (
			networked
			and NetworkManager.is_host()
			and NetworkManager.transport_kind() == "steam"
	)
	%InviteButton.visible = steam_host
	lobby_button.visible = networked and GameManager.mode == GameManager.GameMode.MULTIPLAYER
	restart_button.visible = true
	match GameManager.mode:
		GameManager.GameMode.GAUNTLET:
			restart_button.text = tr("PAUSE_RESTART_GAUNTLET")
			restart_button.disabled = false
			host_note.visible = false
		GameManager.GameMode.MULTIPLAYER:
			# The waiting room starts from the Lobby page; Restart is for a duel that is running.
			restart_button.text = tr("PAUSE_RESTART_DUEL")
			restart_button.visible = not GameManager.in_mp_lobby()
			restart_button.disabled = not NetworkManager.is_host()
			host_note.text = tr("PAUSE_HOST_NOTE")
			host_note.visible = restart_button.visible and restart_button.disabled
		GameManager.GameMode.PRACTICE:
			restart_button.text = tr("PAUSE_RESET_RANGE")
			restart_button.disabled = false
			host_note.visible = false
		GameManager.GameMode.MESH_LAB:
			restart_button.text = tr("PAUSE_RESTART_DUEL")
			restart_button.disabled = true
			host_note.visible = false
		GameManager.GameMode.HORDE:
			restart_button.text = tr("PAUSE_RESTART_HORDE")
			restart_button.disabled = false
			host_note.visible = false
		_:
			restart_button.text = tr("PAUSE_RESTART_DUEL")
			restart_button.disabled = false
			host_note.visible = false


func _on_session_started(as_host: bool) -> void:
	_lobby_full = false
	if as_host and auto_open_lobby:
		_auto_open_lobby.call_deferred()


func _on_session_ended(_reason: String) -> void:
	_lobby_full = false


## The host's lobby just filled: every human slot has someone (an all-NPC lobby is full
## from the start, and opens with the session).
func _on_roster_changed() -> void:
	var full := NetworkManager.is_active() and NetworkManager.is_host() \
			and NetworkManager.roster.open_human_slots() == 0
	if full and not _lobby_full and auto_open_lobby:
		_auto_open_lobby.call_deferred()
	_lobby_full = full


## Once per event, never during a duel, never over a page already open (a player who closed
## it is not reopened by anything but the next event).
func _auto_open_lobby() -> void:
	if not auto_open_lobby or is_open or not NetworkManager.is_host() or not GameManager.in_mp_lobby():
		return
	open()
	if is_open:
		show_lobby()


func _on_invite() -> void:
	NetworkManager.invite_steam_friends()


func _on_restart() -> void:
	if GameManager.mode == GameManager.GameMode.MULTIPLAYER and not NetworkManager.is_host():
		GameManager.show_message(tr("MSG_HOST_ONLY_RESET"), 2.0)
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
		GameManager.GameMode.PRACTICE,
		GameManager.GameMode.MESH_LAB,
		GameManager.GameMode.HORDE,
	]
