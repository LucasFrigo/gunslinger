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
const LOBBY_KEY_NAME := "gunslinger_name"

var _mp: MultiplayerAPI
var _steam: Object
var lobby_id: int = 0
var _joining_lobby := false


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
	_steam.call("createLobby", LOBBY_TYPE_PUBLIC, 2)
	return OK  # continues in _on_lobby_created


func join(target: Variant) -> Error:
	if _steam == null:
		return ERR_UNAVAILABLE
	_joining_lobby = true
	_steam.call("joinLobby", int(target))
	return OK  # continues in _on_lobby_joined


func request_lobby_list() -> void:
	if _steam == null:
		return
	# Worldwide distance filter so test lobbies always show up.
	_steam.call("addRequestLobbyListDistanceFilter", 3)
	_steam.call("addRequestLobbyListStringFilter", LOBBY_KEY_NAME, "", 0)
	_steam.call("requestLobbyList")


func poll() -> void:
	if _steam != null:
		_steam.call("run_callbacks")


func close() -> void:
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	if _mp.multiplayer_peer != null:
		_mp.multiplayer_peer.close()
	_mp.multiplayer_peer = OfflineMultiplayerPeer.new()


func _ensure_init() -> void:
	# GodotSteam 4.19+ can auto-init from project settings; call explicitly to
	# be safe. Signatures vary slightly across versions, hence the fallbacks.
	var result: Variant = _steam.call("steamInitEx", APP_ID)
	if result is Dictionary and result.get("status", 0) != 0:
		result = _steam.call("steamInitEx")
	var persona: Variant = _steam.call("getPersonaName")
	print("SteamTransport: initialized as '%s'" % persona)


func _connect_signal(sig: String, target: Callable) -> void:
	if _steam.has_signal(sig) and not _steam.is_connected(sig, target):
		_steam.connect(sig, target)


func _on_lobby_created(status: int, new_lobby_id: int) -> void:
	if status != 1:
		transport_failed.emit("Lobby creation failed (status %d)" % status)
		return
	lobby_id = new_lobby_id
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_NAME, str(_steam.call("getPersonaName")))
	_steam.call("setLobbyJoinable", lobby_id, true)
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
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
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer.call("connect_to_lobby", lobby_id) != OK:
		transport_failed.emit("SteamMultiplayerPeer failed to connect to lobby")
		return
	_mp.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)


func _on_lobby_match_list(lobbies: Array) -> void:
	var result: Array = []
	for id in lobbies:
		var name := str(_steam.call("getLobbyData", id, LOBBY_KEY_NAME))
		if name.is_empty():
			continue
		result.append({
			"id": id,
			"name": name,
			"players": int(_steam.call("getNumLobbyMembers", id)),
		})
	lobbies_updated.emit(result)
