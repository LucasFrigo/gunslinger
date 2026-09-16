class_name SteamTransport
extends NetworkTransport
## Steam lobbies + SteamMultiplayerPeer via the GodotSteam GDExtension.
##
## The extension is NOT bundled with the repo: drop the GodotSteam GDExtension
## (4.20+) into addons/godotsteam/ on desktop. All access here is dynamic
## (Engine.get_singleton / ClassDB) so this script parses and the game runs
## fine without it -- including on the Quest Android build, which never ships
## Steam. Uses app ID 480 (Spacewar) until the game has its own.
##
## One instance lives for the whole process (NetworkManager._steam), so create
## and join are modelled as a single in-flight request. Steam answers them on
## callbacks that can land after the player already left the menu, so every
## callback is matched against the pending request and a lobby nobody asked
## for any more is left again instead of adopted.
##
## Leaving and re-hosting in one process only works because each session takes
## a fresh Steam P2P virtual port (see _spent_virtual_ports) and the host
## publishes it as lobby metadata. Do not go back to host_with_lobby /
## connect_to_lobby: they hardcode port 0, which BUG-009 was.

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
## Steam P2P virtual port the host's listen socket is on, so joiners can dial
## it. Absent (0) on builds that predate the rotation below.
const LOBBY_KEY_PORT := "gunslinger_port"

## Steam allows virtual ports 0..999 per process.
const MAX_VIRTUAL_PORT := 999
## `Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED`; anything else means leaving.
const CHAT_MEMBER_ENTERED := 1

## In-flight request kinds. Only one create-or-join is ever pending.
const REQUEST_NONE := 0
const REQUEST_HOST := 1
const REQUEST_JOIN := 2

## Steam never answers createLobby / joinLobby if the client dropped out from
## under us; give up instead of leaving the menu stuck on "Creating...".
const REQUEST_TIMEOUT_MS := 10000
## Leaving a lobby needs a callback pump before the next one is requested, so
## requests are issued from poll() this many polls after they are queued.
const REQUEST_DELAY_POLLS := 1

var _mp: MultiplayerAPI
var _steam: Object
## The SteamMultiplayerPeer we created, kept so teardown does not depend on
## MultiplayerAPI still pointing at it.
var _peer: Object
var lobby_id: int = 0
var is_lobby_host := false
var _init_ok := false

var _request := REQUEST_NONE
var _request_deadline_ms := 0
var _queued_request := REQUEST_NONE
var _queued_target := 0
var _queued_delay := 0
## True once this instance asked Steam for a lobby. Guards the orphan cleanup:
## a throwaway instance (dev/autotest.gd) shares the Steam singleton's signals
## and must never leave the lobby owned by the real NetworkManager transport.
var _used := false

static var _api_initialized := false
static var _api_ok := false
## Virtual ports this process has already opened a listen socket on. GodotSteam
## 4.22's SteamMultiplayerPeer.close() does not release its listen socket, so
## Steam keeps the port occupied until the process exits. Reusing one makes
## create_host / create_client fail with ERR_CANT_CREATE, which is why leaving a
## lobby used to break both HOST and JOIN for the rest of the session (BUG-009).
static var _spent_virtual_ports: PackedInt32Array = []


static func is_available() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")


## Reserve `port` for this process, or false if it is already spent.
static func _claim_virtual_port(port: int) -> bool:
	if port < 0 or port > MAX_VIRTUAL_PORT or _spent_virtual_ports.has(port):
		return false
	_spent_virtual_ports.append(port)
	return true


## A port no session in this process has used yet, or -1 if we ran out. The
## first one is 0 so a normal single-session run is on the wire exactly as
## before; later ones are random so a returning joiner is unlikely to have
## spent the port its host picked.
static func _take_virtual_port() -> int:
	if _spent_virtual_ports.is_empty():
		_spent_virtual_ports.append(0)
		return 0
	for _attempt in 128:
		var port := randi_range(1, MAX_VIRTUAL_PORT)
		if _claim_virtual_port(port):
			return port
	return -1


func _init(mp: MultiplayerAPI) -> void:
	_mp = mp
	if not is_available():
		return
	_steam = Engine.get_singleton("Steam")
	_ensure_init()
	_connect_signal("lobby_created", _on_lobby_created)
	_connect_signal("lobby_joined", _on_lobby_joined)
	_connect_signal("lobby_match_list", _on_lobby_match_list)
	_connect_signal("lobby_chat_update", _on_lobby_chat_update)


func kind() -> String:
	return "steam"


func host() -> Error:
	if _steam == null:
		return ERR_UNAVAILABLE
	if not _init_ok:
		transport_failed.emit("Steam is not running or failed to initialize.")
		return ERR_UNAVAILABLE
	# Self-heal: drop any lobby or peer still held from an earlier session.
	close()
	_used = true
	is_lobby_host = true
	_queue_request(REQUEST_HOST, 0)
	return OK  # continues in _on_lobby_created


func join(target: Variant) -> Error:
	if _steam == null:
		return ERR_UNAVAILABLE
	if not _init_ok:
		transport_failed.emit("Steam is not running or failed to initialize.")
		return ERR_UNAVAILABLE
	close()
	_used = true
	is_lobby_host = false
	_queue_request(REQUEST_JOIN, int(target))
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
	if _steam == null:
		return
	_steam.call("run_callbacks")
	_issue_queued_request()
	_check_request_timeout()


func close() -> void:
	# Clearing the request first matters: nothing may adopt a lobby Steam
	# answers with after this point. The peer goes before the lobby so it can
	# still disconnect its P2P sessions while we are a member.
	_queued_request = REQUEST_NONE
	_queued_target = 0
	_queued_delay = 0
	_request = REQUEST_NONE
	_request_deadline_ms = 0
	is_lobby_host = false
	_drop_peer()
	_leave_lobby()


## True once our own Godot peer for the current lobby reports a live link.
## Read instead of MultiplayerAPI's peer, which sits on an OfflineMultiplayerPeer
## (permanently "connected") between sessions.
func peer_connected() -> bool:
	if _peer == null:
		return false
	return int(_peer.call("get_connection_status")) == MultiplayerPeer.CONNECTION_CONNECTED


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
	# Call from a user click (pause Invite), never from lobby-created: opening
	# the overlay on the same mouse-down as HOST (STEAM) leaves it stuck.
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


# -- Request queue -----------------------------------------------------------

func _queue_request(kind: int, target: int) -> void:
	_queued_request = kind
	_queued_target = target
	_queued_delay = REQUEST_DELAY_POLLS


func _issue_queued_request() -> void:
	if _queued_request == REQUEST_NONE:
		return
	if _queued_delay > 0:
		_queued_delay -= 1
		return
	_request = _queued_request
	var target := _queued_target
	_queued_request = REQUEST_NONE
	_queued_target = 0
	_request_deadline_ms = Time.get_ticks_msec() + REQUEST_TIMEOUT_MS
	if _request == REQUEST_HOST:
		_steam.call("createLobby", LOBBY_TYPE_PUBLIC, MAX_PLAYERS)
	else:
		_steam.call("joinLobby", target)


func _check_request_timeout() -> void:
	if _request == REQUEST_NONE or Time.get_ticks_msec() < _request_deadline_ms:
		return
	var kind := _request
	close()
	if kind == REQUEST_HOST:
		transport_failed.emit("Steam never answered the lobby create request. Is Steam still running?")
	else:
		transport_failed.emit("Steam never answered the lobby join request. The lobby may be gone.")


# -- Teardown ----------------------------------------------------------------

func _drop_peer() -> void:
	var peer: Object = _peer
	_peer = null
	if peer == null:
		return
	peer.call("close")
	if _mp != null and _mp.multiplayer_peer == peer:
		_mp.multiplayer_peer = OfflineMultiplayerPeer.new()


func _leave_lobby() -> void:
	if _steam != null and lobby_id != 0:
		_steam.call("leaveLobby", lobby_id)
	lobby_id = 0


## A lobby Steam handed us after we stopped waiting for one. Leaving it is the
## whole point of BUG-009: an orphan lobby kept the process "already in a
## lobby" and every later create / join failed until restart.
func _discard_orphan_lobby(orphan_id: int) -> void:
	if not _used or _steam == null or orphan_id == 0 or orphan_id == lobby_id:
		return
	print("SteamTransport: discarding lobby %d (no longer wanted)" % orphan_id)
	_steam.call("leaveLobby", orphan_id)


# -- Steam callbacks ---------------------------------------------------------

func _make_peer() -> Object:
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer.has_method("set_server_relay"):
		peer.call("set_server_relay", true)
	return peer


func _on_lobby_created(status: int, new_lobby_id: int) -> void:
	if _request != REQUEST_HOST:
		if status == 1:
			_discard_orphan_lobby(new_lobby_id)
		return
	_request = REQUEST_NONE
	_request_deadline_ms = 0
	if status != 1:
		transport_failed.emit("Lobby creation failed (status %d)" % status)
		return
	lobby_id = new_lobby_id
	var port := _take_virtual_port()
	if port < 0:
		transport_failed.emit("Out of Steam P2P ports in this session. Restart the game to host again.")
		return
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_GAME, LOBBY_VALUE_GAME)
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_NAME, persona_name())
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_VERSION, NetworkManager.game_version())
	_steam.call("setLobbyData", lobby_id, LOBBY_KEY_PORT, str(port))
	_steam.call("setLobbyJoinable", lobby_id, true)
	# create_host instead of host_with_lobby: the helper hardcodes virtual
	# port 0, which only works once per process (see _spent_virtual_ports).
	var peer := _make_peer()
	if peer.call("create_host", port) != OK:
		peer.call("close")
		transport_failed.emit("SteamMultiplayerPeer failed to listen on Steam port %d" % port)
		return
	_peer = peer
	_mp.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _perms: int, _locked: bool, response: int) -> void:
	if _request != REQUEST_JOIN:
		# Our own host-side enter callback, or an answer to a join we abandoned.
		# Only the second case is an orphan, and only once nothing is pending.
		if _request == REQUEST_NONE and response == 1:
			_discard_orphan_lobby(joined_lobby_id)
		return
	_request = REQUEST_NONE
	_request_deadline_ms = 0
	if response != 1:
		transport_failed.emit("Could not join lobby (response %d)" % response)
		return
	var host_version := str(_steam.call("getLobbyData", joined_lobby_id, LOBBY_KEY_VERSION))
	if not NetworkManager.versions_match(host_version, NetworkManager.game_version()):
		_steam.call("leaveLobby", joined_lobby_id)
		lobby_id = 0
		transport_failed.emit(NetworkManager.version_mismatch_message(
				host_version, NetworkManager.game_version()))
		return
	lobby_id = joined_lobby_id
	var host_steam_id := int(_steam.call("getLobbyOwner", lobby_id))
	if host_steam_id == 0:
		_leave_lobby()
		transport_failed.emit("That lobby has no host any more.")
		return
	# The host listens on the port it advertised; an older host that published
	# nothing is on 0, which is what connect_to_lobby would have dialled.
	var port := int(str(_steam.call("getLobbyData", lobby_id, LOBBY_KEY_PORT)))
	if not _claim_virtual_port(port):
		_leave_lobby()
		transport_failed.emit(
				"This session already used that host's Steam port. Ask them to re-host, or restart the game.")
		return
	var peer := _make_peer()
	if peer.call("create_client", host_steam_id, port) != OK:
		peer.call("close")
		transport_failed.emit("SteamMultiplayerPeer failed to reach the host on Steam port %d" % port)
		return
	_peer = peer
	_mp.multiplayer_peer = peer
	lobby_ready.emit(lobby_id)


## create_host / create_client do not set the addon's `tracked_lobby`, so it no
## longer drops the Godot peer when someone leaves the lobby. Without this the
## other side is only noticed when the Steam connection itself times out.
func _on_lobby_chat_update(changed_lobby_id: int, changed_id: int, _by_id: int, chat_state: int) -> void:
	if _peer == null or lobby_id == 0 or changed_lobby_id != lobby_id:
		return
	if chat_state == CHAT_MEMBER_ENTERED:
		return  # the joiner dials us; our listen socket accepts it
	var peer_id := int(_peer.call("get_peer_id_for_steam_id", changed_id))
	if peer_id > 0:
		_peer.call("disconnect_peer", peer_id, true)


func _on_lobby_match_list(lobbies: Array) -> void:
	var result: Array = []
	var local_version := NetworkManager.game_version()
	for id in lobbies:
		if id == lobby_id:
			continue  # our own lobby
		var game := str(_steam.call("getLobbyData", id, LOBBY_KEY_GAME))
		if game != LOBBY_VALUE_GAME:
			continue
		var lobby_name := str(_steam.call("getLobbyData", id, LOBBY_KEY_NAME))
		if lobby_name.is_empty():
			continue
		var players := int(_steam.call("getNumLobbyMembers", id))
		if players >= MAX_PLAYERS:
			continue  # 2/2 duel in progress; the host also set it unjoinable
		var version := str(_steam.call("getLobbyData", id, LOBBY_KEY_VERSION))
		result.append({
			"id": id,
			"name": lobby_name,
			"players": players,
			"version": version,
			"compatible": NetworkManager.versions_match(version, local_version),
		})
	lobbies_updated.emit(result)
