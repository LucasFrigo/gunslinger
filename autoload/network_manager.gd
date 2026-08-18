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
signal pose_received(peer_id: int, head: Transform3D, left: Transform3D, right: Transform3D, flags: int)
signal shot_received(peer_id: int, origin: Vector3, direction: Vector3)

const POSE_FLAG_GUN_DRAWN := 1
const POSE_FLAG_GUN_COCKED := 2

var transport: NetworkTransport
var discovery: LanDiscovery
var session_active := false


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


func _process(_delta: float) -> void:
	if transport != null:
		transport.poll()


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
	return SteamTransport.is_available()


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
	discovery.start_beacon(_local_host_name())
	_begin_session(true)
	return OK


func join_lan(ip: String) -> Error:
	leave("switching session")
	transport = ENetTransport.new(multiplayer)
	var err := transport.join(ip)
	if err != OK:
		network_error.emit("Could not join %s: %s" % [ip, error_string(err)])
		transport = null
	return err  # session starts on connected_to_server


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
	if not steam_available():
		network_error.emit("GodotSteam extension not found. See README.")
		return ERR_UNAVAILABLE
	leave("switching session")
	var steam := SteamTransport.new(multiplayer)
	transport = steam
	steam.transport_failed.connect(func(reason: String) -> void: network_error.emit(reason))
	steam.lobby_ready.connect(func(_lobby: int) -> void: _begin_session(true))
	return steam.host()


func join_steam(lobby_id: int) -> Error:
	if not steam_available():
		network_error.emit("GodotSteam extension not found. See README.")
		return ERR_UNAVAILABLE
	leave("switching session")
	var steam := SteamTransport.new(multiplayer)
	transport = steam
	steam.transport_failed.connect(func(reason: String) -> void: network_error.emit(reason))
	return steam.join(lobby_id)


func refresh_steam_lobbies() -> void:
	if not steam_available():
		steam_lobbies_updated.emit([])
		return
	var browser := transport as SteamTransport
	if browser == null:
		browser = SteamTransport.new(multiplayer)
		transport = browser
	if not browser.lobbies_updated.is_connected(_on_steam_lobbies):
		browser.lobbies_updated.connect(_on_steam_lobbies)
	browser.request_lobby_list()


func _on_steam_lobbies(lobbies: Array) -> void:
	steam_lobbies_updated.emit(lobbies)


# -- Common ------------------------------------------------------------------

func leave(reason := "left session") -> void:
	if transport != null:
		transport.close()
		transport = null
	discovery.stop()
	if session_active:
		session_active = false
		session_ended.emit(reason)


func _begin_session(as_host: bool) -> void:
	session_active = true
	session_started.emit(as_host)


func _local_host_name() -> String:
	var name := OS.get_environment("COMPUTERNAME")
	if name.is_empty():
		name = OS.get_model_name()
	return name if not name.is_empty() else "Gunslinger Host"


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	discovery.stop()
	_begin_session(false)


func _on_connection_failed() -> void:
	network_error.emit("Connection failed.")
	leave("connection failed")


func _on_server_disconnected() -> void:
	network_error.emit("Host disconnected.")
	leave("host disconnected")


# -- Fast-path relays --------------------------------------------------------

func send_pose(head: Transform3D, left: Transform3D, right: Transform3D, flags: int) -> void:
	if session_active and peer_count() > 0:
		_pose.rpc(head, left, right, flags)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pose(head: Transform3D, left: Transform3D, right: Transform3D, flags: int) -> void:
	pose_received.emit(multiplayer.get_remote_sender_id(), head, left, right, flags)


func send_shot(origin: Vector3, direction: Vector3) -> void:
	if session_active and peer_count() > 0:
		_shot.rpc(origin, direction)


@rpc("any_peer", "call_remote", "reliable")
func _shot(origin: Vector3, direction: Vector3) -> void:
	shot_received.emit(multiplayer.get_remote_sender_id(), origin, direction)
