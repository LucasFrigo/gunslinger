class_name LanDiscovery
extends Node
## UDP broadcast discovery so the Quest finds the notebook host without
## typing an IP. The host runs a beacon (answers pings + periodically
## announces); browsing clients ping and collect replies.

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
	# Android drops inbound broadcasts unless the socket has this on
	# (Godot then takes a Wi-Fi multicast lock).
	_socket.set_broadcast_enabled(true)
	var err := _socket.bind(DISCOVERY_PORT, "*")
	if err != OK:
		push_warning("LanDiscovery: could not bind beacon port %d (%s)" % [DISCOVERY_PORT, error_string(err)])
		_socket = null
		return
	_role = Role.BEACON
	_browse_timer = BROWSE_INTERVAL  # announce immediately


func start_browse() -> void:
	stop()
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	# Prefer the well-known port so we receive host announcements. Fall
	# back to an ephemeral port when 9100 is taken (second local instance).
	var err := _socket.bind(DISCOVERY_PORT, "*")
	if err != OK:
		err = _socket.bind(0, "*")
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
			_process_beacon(delta)
		Role.BROWSE:
			_process_browse(delta)


func _process_beacon(delta: float) -> void:
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		if packet == PING:
			var reply_ip := _socket.get_packet_ip()
			var reply_port := _socket.get_packet_port()
			if not reply_ip.is_empty() and reply_port > 0:
				for payload in _pong_payloads():
					_socket.set_dest_address(reply_ip, reply_port)
					_socket.put_packet(payload)
	_browse_timer += delta / maxf(Engine.time_scale, 0.01)
	if _browse_timer >= BROWSE_INTERVAL:
		_browse_timer = 0.0
		for payload in _pong_payloads():
			_send_to_broadcasts(payload)


func _process_browse(delta: float) -> void:
	_browse_timer += delta / maxf(Engine.time_scale, 0.01)
	if _browse_timer >= BROWSE_INTERVAL:
		_browse_timer = 0.0
		_send_to_broadcasts(PING.to_utf8_buffer())
		_prune_stale()
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		if not packet.begins_with(PONG):
			continue
		var parsed := _parse_pong(packet, _socket.get_packet_ip())
		if parsed.is_empty():
			continue
		_found[parsed["ip"]] = parsed
		hosts_updated.emit(get_hosts())


func _send_to_broadcasts(payload: PackedByteArray) -> void:
	for addr in _broadcast_targets():
		_socket.set_dest_address(addr, DISCOVERY_PORT)
		_socket.put_packet(payload)


## PONG rest is `ip|name` (preferred) or a bare display name.
func _pong_payloads() -> Array[PackedByteArray]:
	var payloads: Array[PackedByteArray] = []
	var ips := lan_ipv4_addresses()
	if ips.is_empty():
		payloads.append((PONG + _host_name).to_utf8_buffer())
		return payloads
	for ip in ips:
		payloads.append((PONG + "%s|%s" % [ip, _host_name]).to_utf8_buffer())
	return payloads


func _parse_pong(packet: String, packet_ip: String) -> Dictionary:
	var rest := packet.trim_prefix(PONG)
	var ip := packet_ip
	var host_name := rest
	var sep := rest.find("|")
	if sep >= 0:
		var claimed := rest.substr(0, sep)
		host_name = rest.substr(sep + 1)
		if is_usable_lan_ipv4(claimed):
			ip = claimed
	if not is_usable_lan_ipv4(ip):
		return {}
	return {
		"ip": ip,
		"name": host_name if not host_name.is_empty() else ip,
		"seen": Time.get_ticks_msec() / 1000.0,
	}


func _broadcast_targets() -> PackedStringArray:
	var targets: PackedStringArray = ["255.255.255.255"]
	for ip in lan_ipv4_addresses():
		var parts := ip.split(".")
		if parts.size() != 4:
			continue
		var bcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not targets.has(bcast):
			targets.append(bcast)
	return targets


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


static func lan_ipv4_addresses() -> PackedStringArray:
	var result: PackedStringArray = []
	for ip in IP.get_local_addresses():
		if is_usable_lan_ipv4(ip) and not result.has(ip):
			result.append(ip)
	return result


static func is_usable_lan_ipv4(ip: String) -> bool:
	if ip.is_empty() or ip.contains(":") or not ip.is_valid_ip_address():
		return false
	if ip.begins_with("127.") or ip.begins_with("0.") or ip.begins_with("169.254.") or ip.begins_with("255."):
		return false
	if ip.begins_with("10.") or ip.begins_with("192.168."):
		return true
	if ip.begins_with("172."):
		var second := int(ip.get_slice(".", 1))
		return second >= 16 and second <= 31
	return false
