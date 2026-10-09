class_name MainMenu
extends Control
## Landing (SP / MP / Settings / Quit) plus page-switch sub-UIs. Rendered
## fullscreen in flat mode and inside a UIPanel3D quad in VR (same Control,
## reparented).

const BACKDROP_SOLID_ALPHA := 0.94
const BACKDROP_FLAT_ALPHA := 0.2
const BIG_BUTTON_HEIGHT_FLAT := 44.0
const BIG_BUTTON_HEIGHT_VR := 80.0
const BIG_BUTTON_FONT_VR := 28

@onready var scenario_option: OptionButton = %ScenarioOption
@onready var enemy_option: OptionButton = %EnemyOption
@onready var count_option: OptionButton = %CountOption
@onready var horde_scenario_option: OptionButton = %HordeScenarioOption
@onready var horde_best_label: Label = %HordeBestLabel
@onready var gauntlet_best_label: Label = %GauntletBestLabel
@onready var ip_edit: LineEdit = %IpEdit
@onready var lan_list: ItemList = %LanList
@onready var steam_list: ItemList = %SteamList
@onready var status_label: Label = %StatusLabel
@onready var settings_menu: SettingsMenu = $Center/Panel/Margin/SettingsMenu

var _lan_hosts: Array = []
var _steam_lobbies: Array = []
var _gauntlet_ladder: GauntletLadder


func _ready() -> void:
	%VersionLabel.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	for path in GameManager.SCENARIOS:
		scenario_option.add_item((load(path) as ScenarioResource).display_name)
	for path in GameManager.ARCHETYPES:
		enemy_option.add_item((load(path) as AIArchetype).display_name)
	enemy_option.add_item(tr("MENU_ENEMY_MIXED"))
	for count in range(1, GameManager.MAX_NPCS + 1):
		count_option.add_item(tr("MENU_OPPONENT_ONE") if count == 1 else tr("MENU_OPPONENT_MANY") % count)
	scenario_option.select(PlayerSettings.free_duel_scenario)
	enemy_option.select(PlayerSettings.free_duel_enemy)
	count_option.select(PlayerSettings.free_duel_count - 1)
	for path in GameManager.SCENARIOS:
		horde_scenario_option.add_item((load(path) as ScenarioResource).display_name)
	horde_scenario_option.select(PlayerSettings.horde_scenario)
	_refresh_horde_best()
	_gauntlet_ladder = load(GameManager.GAUNTLET_LADDER)
	%GauntletBlurb.text = tr("MENU_GAUNTLET_BLURB") % [
		_gauntlet_ladder.encounters.size(), _gauntlet_ladder.lives]
	%DuelBlurb.text = tr("MENU_DUEL_BLURB")
	%HordeBlurb.text = tr("MENU_HORDE_BLURB")
	_refresh_gauntlet_best()
	set_vr_layout(false)

	%SingleplayerButton.pressed.connect(_show_singleplayer)
	%MultiplayerButton.pressed.connect(_show_multiplayer)
	%PracticeButton.pressed.connect(GameManager.start_practice)
	%SpBackButton.pressed.connect(show_mode_select)
	%MpBackButton.pressed.connect(show_mode_select)
	%GauntletModeButton.pressed.connect(_show_page.bind(%GauntletPage))
	%DuelModeButton.pressed.connect(_show_page.bind(%DuelPage))
	%HordeModeButton.pressed.connect(_show_page.bind(%HordePage))
	for back in [%GauntletBackButton, %DuelBackButton, %HordeBackButton]:
		(back as Button).pressed.connect(_show_singleplayer)
	%GauntletButton.pressed.connect(GameManager.start_gauntlet)
	%FreeDuelButton.pressed.connect(_start_free_duel)
	%HordeButton.pressed.connect(_start_horde)
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
		%SteamNote.text = tr("MENU_STEAM_MISSING")
	else:
		%SteamNote.text = tr("MENU_STEAM_NOTE")

	visibility_changed.connect(_on_visibility_changed)
	_on_lan_hosts([])
	if not OS.has_feature("android") and NetworkManager.steam_available():
		steam_list.clear()
		steam_list.add_item(tr("MENU_STEAM_SEARCHING"))
		steam_list.set_item_disabled(0, true)
	_on_visibility_changed()


func _start_free_duel() -> void:
	var count := count_option.selected + 1
	PlayerSettings.set_free_duel_pick(scenario_option.selected, enemy_option.selected, count)
	GameManager.start_free_duel(scenario_option.selected, enemy_option.selected, count)


func _start_horde() -> void:
	PlayerSettings.set_horde_scenario(horde_scenario_option.selected)
	GameManager.start_horde(horde_scenario_option.selected)


## "Best: wave N · S", hidden until a run has set one.
func _refresh_horde_best() -> void:
	if PlayerSettings.horde_best_wave <= 0 and PlayerSettings.horde_best_score <= 0:
		horde_best_label.visible = false
		return
	horde_best_label.text = tr("MENU_HORDE_BEST") % [
		PlayerSettings.horde_best_wave, PlayerSettings.horde_best_score]
	horde_best_label.visible = true


## "Best: duel N / M · S", or CLEARED once a run beat the ladder. Hidden until set.
func _refresh_gauntlet_best() -> void:
	if PlayerSettings.gauntlet_best_rung <= 0 and PlayerSettings.gauntlet_best_score <= 0:
		gauntlet_best_label.visible = false
		return
	if PlayerSettings.gauntlet_cleared:
		gauntlet_best_label.text = tr("MENU_GAUNTLET_BEST_CLEARED") % PlayerSettings.gauntlet_best_score
	else:
		gauntlet_best_label.text = tr("MENU_GAUNTLET_BEST") % [PlayerSettings.gauntlet_best_rung,
			_gauntlet_ladder.encounters.size(), PlayerSettings.gauntlet_best_score]
	gauntlet_best_label.visible = true


## Taller mode / START buttons for laser pointing on the VR quad.
func set_vr_layout(vr: bool) -> void:
	for button: Button in find_children("*", "Button"):
		if not button.is_in_group(&"menu_big_button"):
			continue
		button.custom_minimum_size.y = BIG_BUTTON_HEIGHT_VR if vr else BIG_BUTTON_HEIGHT_FLAT
		if vr:
			button.add_theme_font_size_override(&"font_size", BIG_BUTTON_FONT_VR)
		else:
			button.remove_theme_font_size_override(&"font_size")


func show_mode_select() -> void:
	_show_page(%Landing)


## Flat shows the frozen arena through a light tint; the VR quad keeps its
## solid backing so it reads against the hub.
func set_backdrop_dim(solid: bool) -> void:
	$Background.color.a = BACKDROP_SOLID_ALPHA if solid else BACKDROP_FLAT_ALPHA


## True when a sub-page was closed. A mode page steps back to the SP list;
## SP, MP, and Settings step back to landing. Landing is a no-op.
func go_back() -> bool:
	if %GauntletPage.visible or %DuelPage.visible or %HordePage.visible:
		_show_singleplayer()
		return true
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
	for p: Control in [%Landing, %SingleplayerPage, %GauntletPage, %DuelPage, %HordePage,
			%MultiplayerPage, settings_menu]:
		p.visible = p == page
	_sync_browse()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		show_mode_select()
		_refresh_horde_best()
		_refresh_gauntlet_best()
	else:
		_sync_browse()


func _sync_browse() -> void:
	var mp_open: bool = is_visible_in_tree() and %MultiplayerPage.visible
	NetworkManager.browse_lan(mp_open)
	NetworkManager.browse_steam(mp_open and not OS.has_feature("android"))


func _host_lan() -> void:
	_set_status(tr("MENU_HOSTING_LAN"))
	NetworkManager.host_lan()


func _host_steam() -> void:
	_set_status(tr("MENU_CREATING_LOBBY"))
	NetworkManager.host_steam()


func _join_selected_lan() -> void:
	var selected := lan_list.get_selected_items()
	if selected.is_empty():
		_set_status(tr("MENU_SELECT_LAN"))
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
	_set_status(tr("MENU_JOINING_HOST") % host["ip"])
	NetworkManager.join_lan(host["ip"])


func _join_selected_steam() -> void:
	var selected := steam_list.get_selected_items()
	if selected.is_empty():
		_set_status(tr("MENU_SELECT_LOBBY"))
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
	_set_status(tr("MENU_JOINING_LOBBY") % lobby["name"])
	NetworkManager.join_steam(lobby["id"])


func _on_lan_hosts(hosts: Array) -> void:
	_lan_hosts = hosts
	lan_list.clear()
	var local_v := NetworkManager.game_version()
	for host in hosts:
		var host_v := str(host.get("version", ""))
		var compatible := NetworkManager.versions_match(host_v, local_v)
		var version_label := host_v if not host_v.is_empty() else "?"
		var idx := lan_list.add_item(tr("MENU_LAN_ENTRY") % [host["name"], host["ip"], version_label])
		if not compatible:
			lan_list.set_item_disabled(idx, true)
	if hosts.is_empty():
		lan_list.add_item(tr("MENU_LAN_SEARCHING"))
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
				tr("MENU_STEAM_ENTRY") % [lobby["name"], lobby["players"], version_label])
		if not compatible:
			steam_list.set_item_disabled(idx, true)
	if lobbies.is_empty():
		steam_list.add_item(tr("MENU_STEAM_EMPTY"))
		steam_list.set_item_disabled(0, true)


func _set_status(text: String) -> void:
	status_label.text = text
