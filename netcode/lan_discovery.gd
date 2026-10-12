class_name LanDiscovery
extends Node
## UDP broadcast discovery so the Quest finds the notebook host without
## typing an IP. The host runs a beacon (answers pings + periodically
## announces); browsing clients ping and collect replies.

signal hosts_updated(hosts: Array)

const DISCOVERY_PORT := 9100
const BIND_IPV4 := "0.0.0.0"
const PING := "GUNSLINGER_DISCOVER"
const PONG := "GUNSLINGER_HOST:"
const BROWSE_INTERVAL := 1.0
const HOST_TIMEOUT := 4.0

enum Role { IDLE, BEACON, BROWSE }

var _role: int = Role.IDLE
var _socket: PacketPeerUDP
var _host_name := ""
var _host_version := ""
var _host_slots := ""
var _browse_timer := 0.0
## ip -> { "ip": String, "name": String, "version": String, "open": int, "total": int, "seen": float }
var _found := {}


func start_beacon(host_name: String, host_version := "") -> void:
	stop()
	_host_name = host_name
	_host_version = host_version
	_socket = PacketPeerUDP.new()
	# Android drops inbound broadcasts unless the socket has this on
	# (Godot then takes a Wi-Fi multicast lock).
	_socket.set_broadcast_enabled(true)
	var err := _socket.bind(DISCOVERY_PORT, BIND_IPV4)
	if err != OK:
		push_warning("LanDiscovery: could not bind beacon port %d (%s)" % [DISCOVERY_PORT, error_string(err)])
		_socket = null
		return
	_role = Role.BEACON
	_browse_timer = BROWSE_INTERVAL  # announce immediately


## Host: the `open/total` human-slot field (`LobbyRoster.format_slots`) the beacon carries.
func set_beacon_slots(slots: String) -> void:
	_host_slots = slots


func start_browse() -> void:
	stop()
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	# Prefer the well-known port so we receive host announcements. Fall
	# back to an ephemeral port when 9100 is taken (second local instance).
	var err := _socket.bind(DISCOVERY_PORT, BIND_IPV4)
	if err != OK:
		err = _socket.bind(0, BIND_IPV4)
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
	_host_version = ""
	_host_slots = ""


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
		var parsed := parse_pong_packet(packet, _socket.get_packet_ip())
		if parsed.is_empty():
			continue
		_found[parsed["ip"]] = parsed
		hosts_updated.emit(get_hosts())


func _send_to_broadcasts(payload: PackedByteArray) -> void:
	for addr in _broadcast_targets():
		_socket.set_dest_address(addr, DISCOVERY_PORT)
		_socket.put_packet(payload)


## PONG rest is `ip|name|version|open/total` (preferred). Older builds send
## `ip|name|version`, `ip|name`, or a bare display name.
func _pong_payloads() -> Array[PackedByteArray]:
	var payloads: Array[PackedByteArray] = []
	var tail := "%s|%s" % [_host_name, _host_version]
	if not _host_slots.is_empty():
		tail += "|" + _host_slots
	var ips := lan_ipv4_addresses()
	if ips.is_empty():
		# No usable NIC IP: name|version|slots so parsers still pick up the build string.
		payloads.append((PONG + tail).to_utf8_buffer())
		return payloads
	for ip in ips:
		payloads.append((PONG + "%s|%s" % [ip, tail]).to_utf8_buffer())
	return payloads


## Public for autotests. Returns {} when the packet has no usable LAN IPv4.
## `total` is 0 when the host sent no slot field (an older build).
static func parse_pong_packet(packet: String, packet_ip: String) -> Dictionary:
	if not packet.begins_with(PONG):
		return {}
	var rest := packet.trim_prefix(PONG)
	var ip := packet_ip
	var version := ""
	var parts := rest.split("|")
	# A trailing `open/total` is the slot field; the version is the part before it.
	var slots := Vector2i.ZERO
	if parts.size() >= 2:
		slots = LobbyRoster.parse_slots(parts[parts.size() - 1])
		if slots.y > 0:
			parts.remove_at(parts.size() - 1)
		else:
			slots = Vector2i.ZERO
	var host_name := "|".join(parts)
	if parts.size() >= 3:
		var claimed := parts[0]
		version = parts[parts.size() - 1]
		host_name = "|".join(parts.slice(1, parts.size() - 1))
		if is_usable_lan_ipv4(claimed):
			ip = claimed
	elif parts.size() == 2:
		var claimed2 := parts[0]
		host_name = parts[1]
		if is_usable_lan_ipv4(claimed2):
			ip = claimed2
		else:
			# Bare `name|version` (no NIC IP in the beacon).
			host_name = parts[0]
			version = parts[1]
	if not is_usable_lan_ipv4(ip):
		return {}
	return {
		"ip": ip,
		"name": host_name if not host_name.is_empty() else ip,
		"version": version,
		"open": slots.x,
		"total": slots.y,
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
