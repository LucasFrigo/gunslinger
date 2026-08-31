class_name SteamTransport
extends NetworkTransport
## Steam lobbies + SteamMultiplayerPeer via the GodotSteam GDExtension.
##
## The extension is NOT bundled with the repo: drop the GodotSteam GDExtension
## (4.20+) into addons/godotsteam/ on desktop. All access here is dynamic
## (Engine.get_singleton / ClassDB) so this script parses and the game runs
## fine without it -- including on the Quest Android build, which never ships
## Steam. Uses app ID 480 (Spacewar) until the game has its own.

signal lobbies_updated(lobbies: Array)
signal lobby_ready(lobby_id: int)
signal transport_failed(reason: String)

const APP_ID := 480
const LOBBY_TYPE_PUBLIC := 2
const DISTANCE_WORLDWIDE := 3
const LOBBY_COMPARISON_EQUAL := 0
const MAX_PLAYERS := 2
const LOBBY_KEY_GAME := "gunslinger"
const LOBBY_VALUE_GAME := "1"
const LOBBY_KEY_NAME := "gunslinger_name"
const LOBBY_KEY_VERSION := "gunslinger_version"

var _mp: MultiplayerAPI
var _steam: Object
var lobby_id: int = 0
var is_lobby_host := false
var _joining_lobby := false
var _init_ok := false

static var _api_initialized := false
static var _api_ok := false


static func is_available() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")


func _init(mp: MultiplayerAPI) -> void:
	_mp = mp
	if not is_available():
		return
	_steam = Engine.get_singleton("Steam")
	_ensure_init()
	_connect_signal("lobby_created", _on_lobby_created)
	_connect_signal("lobby_joined", _on_lobby_joined)
	_connect_signal("lobby_match_list", _on_lobby_match_list)


func kind() -> String:
	return "steam"


func host() -> Error:
	if _steam == null:
		return ERR_UNAVAILABLE
	if not _init_ok:
		transport_failed.emit("Steam is not running or failed to initialize.")
		return ERR_UNAVAILABLE
	is_lobby_host = true
	_joining_lobby = false
	_steam.call("createLobby", LOBBY_TYPE_PUBLIC, MAX_PLAYERS)
	return OK  # continues in _on_lobby_created


func join(target: Variant) -> Error:
	if _steam == null:
		return ERR_UNAVAILABLE
	if not _init_ok:
		transport_failed.emit("Steam is not running or failed to initialize.")
		return ERR_UNAVAILABLE
	is_lobby_host = false
	_joining_lobby = true
	_steam.call("joinLobby", int(target))
	return OK  # continues in _on_lobby_joined


func request_lobby_list() -> void:
	if _steam == null or not _init_ok:
		lobbies_updated.emit([])
		return
	# Worldwide so two test machines on Spacewar 480 always see each other.
	_steam.call("addRequestLobbyListDistanceFilter", DISTANCE_WORLDWIDE)
	_steam.call("addRequestLobbyListStringFilter", LOBBY_KEY_GAME, LOBBY_VALUE_GAME, LOBBY_COMPARISON_EQUAL)
	_steam.call("requestLobbyList")


func poll() -> void:
	if _steam != null:
		_steam.call("run_callbacks")


func close() -> void:
	# Leave the lobby and drop the Godot peer; do not shut Steam down.
	_joining_lobby = false
	is_lobby_host = false
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	if _mp != null and _mp.multiplayer_peer != null:
		_mp.multiplayer_peer.close()
		_mp.multiplayer_peer = OfflineMultiplayerPeer.new()


func set_joinable(joinable: bool) -> void:
	if _steam != null and lobby_id != 0:
		_steam.call("setLobbyJoinable", lobby_id, joinable)


func persona_name() -> String:
	if _steam == null:
		return ""
	return str(_steam.call("getPersonaName"))


func lobby_label() -> String:
	var name := persona_name()
	return name if not name.is_empty() else "Steam lobby"


func open_invite_overlay() -> void:
	if _steam == null or lobby_id == 0:
		return
	if _steam.has_method("activateGameOverlayInviteDialog"):
		_steam.call("activateGameOverlayInviteDialog", lobby_id)
	elif _steam.has_method("activateGameOverlay"):
		_steam.call("activateGameOverlay", "LobbyInvite")


func _ensure_init() -> void:
	# GodotSteam 4.19+ can auto-init from project settings; call explicitly to
	# be safe. Signatures vary slightly across versions, hence the fallbacks.
	if _api_initialized:
		_init_ok = _api_ok
		return
	# Editor / exported test builds need an App ID before steamInitEx.
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	var result: Variant = _steam.call("steamInitEx", APP_ID)
	if result is Dictionary and int(result.get("status", 0)) != 0:
		result = _steam.call("steamInitEx")
	_init_ok = true
	if result is Dictionary:
		_init_ok = int(result.get("status", 0)) == 0
	_api_initialized = true
	_api_ok = _init_ok
	if _init_ok and _steam.has_method("initRelayNetworkAccess"):
		_steam.call("initRelayNetworkAccess")
	var persona: Variant = _steam.call("getPersonaName")
	print("SteamTransport: initialized as '%s' (ok=%s)" % [persona, _init_ok])


func _connect_signal(sig: String, target: Callable) -> void:
	if _steam.has_signal(sig) and not _steam.is_connected(sig, target):
		_steam.connect(sig, target)


func _make_peer() -> Object:
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer.has_method("set_server_relay"):
		peer.call("set_server_relay", true)
	return peer


func _game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _on_lobby_created(status: int, new_lobby_id: int) -> void:
	if status != 1:
		transport_failed.emit("Lobby creation failed (status %d)" % status)
		return
	lobby_id = new_lobby_id
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_GAME, LOBBY_VALUE_GAME)
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_NAME, persona_name())
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_VERSION, _game_version())
	_steam.call("setLobbyJoinable", lobby_id, true)
	var peer := _make_peer()
	if peer.call("host_with_lobby", lobby_id) != OK:
		transport_failed.emit("SteamMultiplayerPeer failed to host lobby")
		return
	_mp.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _perms: int, _locked: bool, response: int) -> void:
	if not _joining_lobby:
		return  # our own host-side join callback
	_joining_lobby = false
	if response != 1:
		transport_failed.emit("Could not join lobby (response %d)" % response)
		return
	lobby_id = joined_lobby_id
	var peer := _make_peer()
	if peer.call("connect_to_lobby", lobby_id) != OK:
		transport_failed.emit("SteamMultiplayerPeer failed to connect to lobby")
		return
	_mp.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)


func _on_lobby_match_list(lobbies: Array) -> void:
	var result: Array = []
	for id in lobbies:
		var game := str(_steam.call("getLobbyData", id, LOBBY_KEY_GAME))
		if game != LOBBY_VALUE_GAME:
			continue
		var lobby_name := str(_steam.call("getLobbyData", id, LOBBY_KEY_NAME))
		if lobby_name.is_empty():
			continue
		var players := int(_steam.call("getNumLobbyMembers", id))
		if players >= MAX_PLAYERS:
			continue
		result.append({
			"id": id,
			"name": lobby_name,
			"players": players,
			"version": str(_steam.call("getLobbyData", id, LOBBY_KEY_VERSION)),
		})
	lobbies_updated.emit(result)
