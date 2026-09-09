extends Node
## Autoload. Owns the active NetworkTransport (ENet LAN or Steam) and relays
## fast-path gameplay traffic (poses, shots). Gameplay code is
## transport-agnostic: everything goes through Godot's MultiplayerAPI.

signal session_started(as_host: bool)
signal session_ended(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal lan_hosts_updated(hosts: Array)
signal steam_lobbies_updated(lobbies: Array)
signal network_error(message: String)
signal pose_received(peer_id: int, head: Transform3D, left: Transform3D, right: Transform3D, flags: int, gun: Transform3D)
signal shot_received(peer_id: int, origin: Vector3, direction: Vector3)

const POSE_FLAG_GUN_DRAWN := 1
const POSE_FLAG_GUN_COCKED := 2
const POSE_FLAG_GUN_FREE := 4
const POSE_FLAG_HOLSTER_LEFT := 8
const POSE_FLAG_GUN_HELD_LEFT := 16
const POSE_FLAG_GUN_SPINNING := 32
const STEAM_REFRESH_SEC := 4.0
const VERSION_HANDSHAKE_TIMEOUT := 3.0

var transport: NetworkTransport
var discovery: LanDiscovery
var session_active := false

var _steam: SteamTransport
var _steam_browse := false
var _steam_refresh_accum := 0.0
var _last_steam_lobbies: Array = []

## Host: peer that connected but has not finished the version hello yet.
var _pending_hello_peer_id := 0
## Host: peer that passed the version check (1v1 — ignore further hellos).
var _verified_peer_id := 0
## Joiner: waiting for _version_ok / _version_reject after sending hello.
var _awaiting_version_ok := false
var _handshake_timer := 0.0
var _kick_peer_id := 0


func _ready() -> void:
	discovery = LanDiscovery.new()
	discovery.name = "LanDiscovery"
	add_child(discovery)
	discovery.hosts_updated.connect(func(hosts: Array) -> void: lan_hosts_updated.emit(hosts))

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	if steam_available():
		_steam = SteamTransport.new(multiplayer)
		_steam.lobbies_updated.connect(_on_steam_lobbies)
		_steam.transport_failed.connect(_on_steam_failed)
		_steam.lobby_ready.connect(_on_steam_lobby_ready)


func _process(delta: float) -> void:
	if _steam != null:
		_steam.poll()
	if transport != null and transport != _steam:
		transport.poll()
	_try_begin_steam_join()
	if _steam_browse and not session_active and _steam != null:
		_steam_refresh_accum += delta
		if _steam_refresh_accum >= STEAM_REFRESH_SEC:
			_steam_refresh_accum = 0.0
			refresh_steam_lobbies()
	_tick_handshake(delta)
	if _kick_peer_id != 0:
		var kick_id := _kick_peer_id
		_kick_peer_id = 0
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(kick_id)


# -- Version helpers ---------------------------------------------------------

func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func versions_match(host_version: String, local_version: String) -> bool:
	return not host_version.is_empty() and not local_version.is_empty() and host_version == local_version


func version_mismatch_message(host_version: String, local_version: String) -> String:
	var host_label := host_version if not host_version.is_empty() else "unknown (older build)"
	var local_label := local_version if not local_version.is_empty() else "unknown"
	return "Cannot join: host is v%s, you are v%s." % [host_label, local_label]


# -- Session queries ---------------------------------------------------------

func is_active() -> bool:
	return session_active


func is_host() -> bool:
	return not session_active or multiplayer.is_server()


func peer_count() -> int:
	if not session_active:
		return 0
	return multiplayer.get_peers().size()


func transport_kind() -> String:
	return transport.kind() if transport != null else "none"


func steam_available() -> bool:
	# Meta Store / Quest APK is LAN-only; Steam lobbies stay on desktop.
	if OS.has_feature("android"):
		return false
	return SteamTransport.is_available()


func steam_lobby_label() -> String:
	return _steam.lobby_label() if _steam != null else "Steam lobby"


# -- LAN ---------------------------------------------------------------------

func host_lan() -> Error:
	leave("switching session")
	transport = ENetTransport.new(multiplayer)
	var err := transport.host()
	if err != OK:
		var hint := error_string(err)
		if OS.get_name() == "Android" and err == ERR_CANT_CREATE:
			hint += " — APK missing INTERNET (re-export Quest 3 after enabling LAN permissions)"
		network_error.emit("Could not host LAN game: %s" % hint)
		transport = null
		return err
	discovery.start_beacon(_local_host_name(), game_version())
	_begin_session(true)
	return OK


func join_lan(ip: String) -> Error:
	var address := ip.strip_edges()
	for host in discovery.get_hosts():
		if str(host.get("ip", "")) != address:
			continue
		var host_v := str(host.get("version", ""))
		if not versions_match(host_v, game_version()):
			network_error.emit(version_mismatch_message(host_v, game_version()))
			return ERR_INVALID_PARAMETER
		break
	leave("switching session")
	transport = ENetTransport.new(multiplayer)
	var err := transport.join(address)
	if err != OK:
		network_error.emit("Could not join %s: %s" % [address, error_string(err)])
		transport = null
	return err  # session starts after version handshake


func browse_lan(enable: bool) -> void:
	if enable:
		if session_active:
			return
		discovery.start_browse()
	elif not session_active:
		discovery.stop()


func lan_addresses() -> PackedStringArray:
	return LanDiscovery.lan_ipv4_addresses()


# -- Steam -------------------------------------------------------------------

func host_steam() -> Error:
	if _steam == null:
		network_error.emit("GodotSteam extension not found. See README.")
		return ERR_UNAVAILABLE
	leave("switching session")
	transport = _steam
	var err := _steam.host()
	if err != OK:
		transport = null
	return err


func join_steam(lobby_id: int) -> Error:
	if _steam == null:
		network_error.emit("GodotSteam extension not found. See README.")
		return ERR_UNAVAILABLE
	for lobby in _last_steam_lobbies:
		if int(lobby.get("id", 0)) != lobby_id:
			continue
		var host_v := str(lobby.get("version", ""))
		if not versions_match(host_v, game_version()):
			network_error.emit(version_mismatch_message(host_v, game_version()))
			return ERR_INVALID_PARAMETER
		break
	leave("switching session")
	transport = _steam
	var err := _steam.join(lobby_id)
	if err != OK:
		transport = null
	return err


func refresh_steam_lobbies() -> void:
	if _steam == null:
		steam_lobbies_updated.emit([])
		return
	_steam.request_lobby_list()


func browse_steam(enable: bool) -> void:
	_steam_browse = enable and _steam != null
	_steam_refresh_accum = 0.0
	if _steam_browse and not session_active:
		refresh_steam_lobbies()


func _on_steam_lobbies(lobbies: Array) -> void:
	_last_steam_lobbies = lobbies
	steam_lobbies_updated.emit(lobbies)


func _on_steam_failed(reason: String) -> void:
	network_error.emit(reason)
	leave(reason)


func _on_steam_lobby_ready(_lobby: int) -> void:
	if _steam != null and _steam.is_lobby_host:
		_begin_session(true)
		_steam.open_invite_overlay()
	else:
		_try_begin_steam_join()


func _try_begin_steam_join() -> void:
	if session_active or _awaiting_version_ok or _steam == null or transport != _steam:
		return
	if _steam.is_lobby_host or _steam.lobby_id == 0:
		return
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_start_joiner_handshake()


# -- Common ------------------------------------------------------------------

func leave(reason := "left session") -> void:
	_clear_handshake_state()
	if transport != null:
		transport.close()
		transport = null
	discovery.stop()
	if session_active:
		session_active = false
		session_ended.emit(reason)


func _begin_session(as_host: bool) -> void:
	if session_active:
		return
	session_active = true
	session_started.emit(as_host)


func _local_host_name() -> String:
	var name := OS.get_environment("COMPUTERNAME")
	if name.is_empty():
		name = OS.get_model_name()
	return name if not name.is_empty() else "Gunslinger Host"


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _steam != null and transport == _steam:
		_steam.set_joinable(false)
	if _verified_peer_id != 0:
		return
	_pending_hello_peer_id = peer_id
	_handshake_timer = VERSION_HANDSHAKE_TIMEOUT


func _on_peer_disconnected(peer_id: int) -> void:
	var was_verified := peer_id == _verified_peer_id
	if peer_id == _pending_hello_peer_id:
		_pending_hello_peer_id = 0
		_handshake_timer = 0.0
	if peer_id == _verified_peer_id:
		_verified_peer_id = 0
	if _steam != null and transport == _steam and session_active:
		_steam.set_joinable(true)
	if was_verified:
		peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	discovery.stop()
	_start_joiner_handshake()


func _on_connection_failed() -> void:
	network_error.emit("Connection failed.")
	leave("connection failed")


func _on_server_disconnected() -> void:
	if _awaiting_version_ok:
		# Kicked before reject RPC arrived (old host / timeout path).
		_awaiting_version_ok = false
		network_error.emit(version_mismatch_message("", game_version()))
		leave("host disconnected")
		return
	if not session_active and transport == null:
		return  # already cleaned up (e.g. version reject)
	network_error.emit("Host disconnected.")
	leave("host disconnected")


# -- Version handshake -------------------------------------------------------

func _clear_handshake_state() -> void:
	_pending_hello_peer_id = 0
	_verified_peer_id = 0
	_awaiting_version_ok = false
	_handshake_timer = 0.0
	_kick_peer_id = 0


func _start_joiner_handshake() -> void:
	if session_active or _awaiting_version_ok:
		return
	_awaiting_version_ok = true
	_handshake_timer = VERSION_HANDSHAKE_TIMEOUT
	_version_hello.rpc_id(1, game_version())


func _tick_handshake(delta: float) -> void:
	if _handshake_timer <= 0.0:
		return
	_handshake_timer -= delta
	if _handshake_timer > 0.0:
		return
	_handshake_timer = 0.0
	if multiplayer.is_server() and _pending_hello_peer_id != 0:
		var peer_id := _pending_hello_peer_id
		_pending_hello_peer_id = 0
		_version_reject.rpc_id(peer_id, game_version())
		_kick_peer_id = peer_id
		GameManager.show_message(
				"Rejected challenger: version mismatch (host v%s, peer unknown / older build)."
				% game_version(), 6.0)
	elif _awaiting_version_ok:
		_awaiting_version_ok = false
		network_error.emit(version_mismatch_message("", game_version()))
		leave("version handshake timeout")


@rpc("any_peer", "call_remote", "reliable")
func _version_hello(client_version: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _verified_peer_id != 0:
		return
	if _pending_hello_peer_id != 0 and peer_id != _pending_hello_peer_id:
		return
	_pending_hello_peer_id = 0
	_handshake_timer = 0.0
	if versions_match(game_version(), client_version):
		_verified_peer_id = peer_id
		_version_ok.rpc_id(peer_id)
		peer_joined.emit(peer_id)
		return
	_version_reject.rpc_id(peer_id, game_version())
	_kick_peer_id = peer_id
	var peer_label := client_version if not client_version.is_empty() else "unknown (older build)"
	GameManager.show_message(
			"Rejected challenger: version mismatch (host v%s, peer v%s)."
			% [game_version(), peer_label], 6.0)


@rpc("authority", "call_remote", "reliable")
func _version_ok() -> void:
	_awaiting_version_ok = false
	_handshake_timer = 0.0
	_begin_session(false)


@rpc("authority", "call_remote", "reliable")
func _version_reject(host_version: String) -> void:
	_awaiting_version_ok = false
	_handshake_timer = 0.0
	network_error.emit(version_mismatch_message(host_version, game_version()))
	leave("version mismatch")


# -- Fast-path relays --------------------------------------------------------

func send_pose(head: Transform3D, left: Transform3D, right: Transform3D, flags: int,
		gun := Transform3D.IDENTITY) -> void:
	if session_active and peer_count() > 0:
		_pose.rpc(head, left, right, flags, gun)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pose(head: Transform3D, left: Transform3D, right: Transform3D, flags: int,
		gun: Transform3D) -> void:
	pose_received.emit(multiplayer.get_remote_sender_id(), head, left, right, flags, gun)


func send_shot(origin: Vector3, direction: Vector3) -> void:
	if session_active and peer_count() > 0:
		_shot.rpc(origin, direction)


@rpc("any_peer", "call_remote", "reliable")
func _shot(origin: Vector3, direction: Vector3) -> void:
	shot_received.emit(multiplayer.get_remote_sender_id(), origin, direction)
