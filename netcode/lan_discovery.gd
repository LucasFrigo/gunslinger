class_name LanDiscovery
extends Node
## UDP broadcast discovery so the Quest finds the notebook host without
## typing an IP. The host runs a beacon responder; browsing clients broadcast
## a magic ping and collect replies.

signal hosts_updated(hosts: Array)

const DISCOVERY_PORT := 9100
const PING := "GUNSLINGER_DISCOVER"
const PONG := "GUNSLINGER_HOST:"
const BROWSE_INTERVAL := 1.0
const HOST_TIMEOUT := 4.0

enum Role { IDLE, BEACON, BROWSE }

var _role: int = Role.IDLE
var _socket: PacketPeerUDP
var _host_name := ""
var _browse_timer := 0.0
## ip -> { "ip": String, "name": String, "seen": float }
var _found := {}


func start_beacon(host_name: String) -> void:
	stop()
	_host_name = host_name
	_socket = PacketPeerUDP.new()
	var err := _socket.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("LanDiscovery: could not bind beacon port %d (%s)" % [DISCOVERY_PORT, error_string(err)])
		_socket = null
		return
	_role = Role.BEACON


func start_browse() -> void:
	stop()
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	var err := _socket.bind(0)
	if err != OK:
		push_warning("LanDiscovery: could not bind browse socket (%s)" % error_string(err))
		_socket = null
		return
	_role = Role.BROWSE
	_found.clear()
	_browse_timer = BROWSE_INTERVAL  # ping immediately


func stop() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_role = Role.IDLE
	_found.clear()


func _process(delta: float) -> void:
	match _role:
		Role.BEACON:
			_process_beacon()
		Role.BROWSE:
			_process_browse(delta)


func _process_beacon() -> void:
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		if packet == PING:
			_socket.set_dest_address(_socket.get_packet_ip(), _socket.get_packet_port())
			_socket.put_packet((PONG + _host_name).to_utf8_buffer())


func _process_browse(delta: float) -> void:
	_browse_timer += delta / maxf(Engine.time_scale, 0.01)
	if _browse_timer >= BROWSE_INTERVAL:
		_browse_timer = 0.0
		_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_socket.put_packet(PING.to_utf8_buffer())
		_prune_stale()
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		if packet.begins_with(PONG):
			var ip := _socket.get_packet_ip()
			_found[ip] = {
				"ip": ip,
				"name": packet.trim_prefix(PONG),
				"seen": Time.get_ticks_msec() / 1000.0,
			}
			hosts_updated.emit(get_hosts())


func _prune_stale() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	for ip in _found.keys():
		if now - _found[ip]["seen"] > HOST_TIMEOUT:
			_found.erase(ip)
			changed = true
	if changed:
		hosts_updated.emit(get_hosts())


func get_hosts() -> Array:
	return _found.values()
