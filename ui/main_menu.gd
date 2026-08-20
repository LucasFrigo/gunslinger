class_name MainMenu
extends Control
## Mode select + multiplayer lobby UI. Rendered fullscreen in flat mode and
## inside a UIPanel3D quad in VR (same Control, reparented).

@onready var scenario_option: OptionButton = %ScenarioOption
@onready var enemy_option: OptionButton = %EnemyOption
@onready var ip_edit: LineEdit = %IpEdit
@onready var lan_list: ItemList = %LanList
@onready var steam_list: ItemList = %SteamList
@onready var status_label: Label = %StatusLabel

var _lan_hosts: Array = []
var _steam_lobbies: Array = []


func _ready() -> void:
	%VersionLabel.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	for path in GameManager.SCENARIOS:
		scenario_option.add_item((load(path) as ScenarioResource).display_name)
	for path in GameManager.ARCHETYPES:
		enemy_option.add_item((load(path) as AIArchetype).display_name)

	%GauntletButton.pressed.connect(GameManager.start_gauntlet)
	%FreeDuelButton.pressed.connect(func() -> void:
		GameManager.start_free_duel(scenario_option.selected, enemy_option.selected))
	%HostLanButton.pressed.connect(func() -> void: NetworkManager.host_lan())
	%JoinIpButton.pressed.connect(func() -> void: NetworkManager.join_lan(ip_edit.text))
	%JoinLanButton.pressed.connect(_join_selected_lan)
	lan_list.item_activated.connect(_join_lan_at)
	%HostSteamButton.pressed.connect(func() -> void: NetworkManager.host_steam())
	%RefreshSteamButton.pressed.connect(NetworkManager.refresh_steam_lobbies)
	%JoinSteamButton.pressed.connect(_join_selected_steam)
	steam_list.item_activated.connect(_join_steam_at)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())

	NetworkManager.lan_hosts_updated.connect(_on_lan_hosts)
	NetworkManager.steam_lobbies_updated.connect(_on_steam_lobbies)
	NetworkManager.network_error.connect(_set_status)

	if not NetworkManager.steam_available():
		for button in [%HostSteamButton, %RefreshSteamButton, %JoinSteamButton]:
			(button as Button).disabled = true
		%SteamNote.text = "Steam: GodotSteam extension not installed (LAN still works)."

	visibility_changed.connect(_on_visibility_changed)
	_on_lan_hosts([])
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	# Only scan the LAN while the menu is actually open.
	NetworkManager.browse_lan(is_visible_in_tree())


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
	_set_status("Joining lobby %s..." % lobby["name"])
	NetworkManager.join_steam(lobby["id"])


func _on_lan_hosts(hosts: Array) -> void:
	_lan_hosts = hosts
	lan_list.clear()
	for host in hosts:
		lan_list.add_item("%s  (%s)" % [host["name"], host["ip"]])
	if hosts.is_empty():
		lan_list.add_item("Searching for LAN hosts...")
		lan_list.set_item_disabled(0, true)
		_lan_hosts = []


func _on_steam_lobbies(lobbies: Array) -> void:
	_steam_lobbies = lobbies
	steam_list.clear()
	for lobby in lobbies:
		steam_list.add_item("%s  (%d/2)" % [lobby["name"], lobby["players"]])
	if lobbies.is_empty():
		steam_list.add_item("No lobbies found. Refresh to retry.")
		steam_list.set_item_disabled(0, true)


func _set_status(text: String) -> void:
	status_label.text = text
