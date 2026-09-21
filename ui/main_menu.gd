class_name MainMenu
extends Control
## Landing (SP / MP / Settings / Quit) plus page-switch sub-UIs. Rendered
## fullscreen in flat mode and inside a UIPanel3D quad in VR (same Control,
## reparented).

@onready var scenario_option: OptionButton = %ScenarioOption
@onready var enemy_option: OptionButton = %EnemyOption
@onready var ip_edit: LineEdit = %IpEdit
@onready var lan_list: ItemList = %LanList
@onready var steam_list: ItemList = %SteamList
@onready var status_label: Label = %StatusLabel
@onready var settings_menu: SettingsMenu = $Center/Panel/Margin/SettingsMenu

var _lan_hosts: Array = []
var _steam_lobbies: Array = []


func _ready() -> void:
	%VersionLabel.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	for path in GameManager.SCENARIOS:
		scenario_option.add_item((load(path) as ScenarioResource).display_name)
	for path in GameManager.ARCHETYPES:
		enemy_option.add_item((load(path) as AIArchetype).display_name)

	%SingleplayerButton.pressed.connect(_show_singleplayer)
	%MultiplayerButton.pressed.connect(_show_multiplayer)
	%SpBackButton.pressed.connect(show_mode_select)
	%MpBackButton.pressed.connect(show_mode_select)
	%GauntletButton.pressed.connect(GameManager.start_gauntlet)
	%FreeDuelButton.pressed.connect(func() -> void:
		GameManager.start_free_duel(scenario_option.selected, enemy_option.selected))
	%HostLanButton.pressed.connect(_host_lan)
	%JoinIpButton.pressed.connect(func() -> void: NetworkManager.join_lan(ip_edit.text))
	%JoinLanButton.pressed.connect(_join_selected_lan)
	lan_list.item_activated.connect(_join_lan_at)
	%HostSteamButton.pressed.connect(_host_steam)
	%RefreshSteamButton.pressed.connect(NetworkManager.refresh_steam_lobbies)
	%JoinSteamButton.pressed.connect(_join_selected_steam)
	steam_list.item_activated.connect(_join_steam_at)
	%SettingsButton.pressed.connect(_show_settings)
	settings_menu.back_pressed.connect(show_mode_select)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())

	NetworkManager.lan_hosts_updated.connect(_on_lan_hosts)
	NetworkManager.steam_lobbies_updated.connect(_on_steam_lobbies)
	NetworkManager.network_error.connect(_set_status)

	if OS.has_feature("android"):
		# Meta Store SKU: LAN only — no Steam lobby chrome on the headset.
		%SteamRow.visible = false
		steam_list.visible = false
		%JoinSteamButton.visible = false
		%SteamNote.visible = false
	elif not NetworkManager.steam_available():
		for button in [%HostSteamButton, %RefreshSteamButton, %JoinSteamButton]:
			(button as Button).disabled = true
		%SteamNote.text = "Steam: GodotSteam extension not installed (LAN still works)."
	else:
		%SteamNote.text = "Steam lobbies refresh automatically. After hosting, Esc → Invite friends (or Shift+Tab) if you want the Steam overlay."

	visibility_changed.connect(_on_visibility_changed)
	_on_lan_hosts([])
	if not OS.has_feature("android") and NetworkManager.steam_available():
		steam_list.clear()
		steam_list.add_item("Searching for Steam lobbies...")
		steam_list.set_item_disabled(0, true)
	_on_visibility_changed()


func show_mode_select() -> void:
	_show_page(%Landing)


## True when a sub-page (SP, MP, or Settings) was closed. Landing is a no-op.
func go_back() -> bool:
	if settings_menu.visible or %SingleplayerPage.visible or %MultiplayerPage.visible:
		show_mode_select()
		return true
	return false


func is_settings_open() -> bool:
	return settings_menu.visible


func _show_singleplayer() -> void:
	_show_page(%SingleplayerPage)


func _show_multiplayer() -> void:
	_show_page(%MultiplayerPage)


func _show_settings() -> void:
	_show_page(settings_menu)
	settings_menu.refresh()


func _show_page(page: Control) -> void:
	%Landing.visible = page == %Landing
	%SingleplayerPage.visible = page == %SingleplayerPage
	%MultiplayerPage.visible = page == %MultiplayerPage
	settings_menu.visible = page == settings_menu
	_sync_browse()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		show_mode_select()
	else:
		_sync_browse()


func _sync_browse() -> void:
	var mp_open: bool = is_visible_in_tree() and %MultiplayerPage.visible
	NetworkManager.browse_lan(mp_open)
	NetworkManager.browse_steam(mp_open and not OS.has_feature("android"))


func _host_lan() -> void:
	_set_status("Hosting LAN game...")
	NetworkManager.host_lan()


func _host_steam() -> void:
	_set_status("Creating Steam lobby...")
	NetworkManager.host_steam()


func _join_selected_lan() -> void:
	var selected := lan_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a LAN host first.")
		return
	_join_lan_at(selected[0])


func _join_lan_at(index: int) -> void:
	if index < 0 or index >= _lan_hosts.size():
		return
	var host: Dictionary = _lan_hosts[index]
	var host_v := str(host.get("version", ""))
	if not NetworkManager.versions_match(host_v, NetworkManager.game_version()):
		_set_status(NetworkManager.version_mismatch_message(host_v, NetworkManager.game_version()))
		return
	_set_status("Joining %s..." % host["ip"])
	NetworkManager.join_lan(host["ip"])


func _join_selected_steam() -> void:
	var selected := steam_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a Steam lobby first.")
		return
	_join_steam_at(selected[0])


func _join_steam_at(index: int) -> void:
	if index < 0 or index >= _steam_lobbies.size():
		return
	var lobby: Dictionary = _steam_lobbies[index]
	var host_v := str(lobby.get("version", ""))
	if not NetworkManager.versions_match(host_v, NetworkManager.game_version()):
		_set_status(NetworkManager.version_mismatch_message(host_v, NetworkManager.game_version()))
		return
	_set_status("Joining lobby %s..." % lobby["name"])
	NetworkManager.join_steam(lobby["id"])


func _on_lan_hosts(hosts: Array) -> void:
	_lan_hosts = hosts
	lan_list.clear()
	var local_v := NetworkManager.game_version()
	for host in hosts:
		var host_v := str(host.get("version", ""))
		var compatible := NetworkManager.versions_match(host_v, local_v)
		var version_label := host_v if not host_v.is_empty() else "?"
		var idx := lan_list.add_item("%s  (%s)  v%s" % [host["name"], host["ip"], version_label])
		if not compatible:
			lan_list.set_item_disabled(idx, true)
	if hosts.is_empty():
		lan_list.add_item("Searching for LAN hosts...")
		lan_list.set_item_disabled(0, true)
		_lan_hosts = []


func _on_steam_lobbies(lobbies: Array) -> void:
	_steam_lobbies = lobbies
	steam_list.clear()
	for lobby in lobbies:
		var host_v := str(lobby.get("version", ""))
		var version_label := host_v if not host_v.is_empty() else "?"
		var compatible: bool = bool(lobby.get("compatible",
				NetworkManager.versions_match(host_v, NetworkManager.game_version())))
		var idx := steam_list.add_item(
				"%s  (%d/2)  v%s" % [lobby["name"], lobby["players"], version_label])
		if not compatible:
			steam_list.set_item_disabled(idx, true)
	if lobbies.is_empty():
		steam_list.add_item("No lobbies found. Refresh to retry.")
		steam_list.set_item_disabled(0, true)


func _set_status(text: String) -> void:
	status_label.text = text
