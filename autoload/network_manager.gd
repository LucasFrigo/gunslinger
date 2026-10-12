extends Node
## Autoload. Owns the active NetworkTransport (ENet LAN or Steam), the lobby
## roster, and relays fast-path gameplay traffic (poses, shots). Gameplay code is
## transport-agnostic: everything goes through Godot's MultiplayerAPI.

signal session_started(as_host: bool)
signal session_ended(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
## The roster was edited (host) or a sync arrived (client).
signal roster_changed
signal lan_hosts_updated(hosts: Array)
signal steam_lobbies_updated(lobbies: Array)
signal network_error(message: String)
signal pose_received(peer_id: int, head: Transform3D, left: Transform3D, right: Transform3D, flags: int, gun: Transform3D, hands: int, objects: int, prop: Transform3D, round_xf: Transform3D)
signal shot_received(peer_id: int, origin: Vector3, direction: Vector3)
## Client: the host's NPC in lobby slot `slot` moved or fired.
signal npc_pose_received(slot: int, head: Transform3D, flags: int, gun: Transform3D)
signal npc_shot_received(slot: int, origin: Vector3, direction: Vector3)

const POSE_FLAG_GUN_DRAWN := 1
const POSE_FLAG_GUN_COCKED := 2
const POSE_FLAG_GUN_FREE := 4
const POSE_FLAG_HOLSTER_LEFT := 8
const POSE_FLAG_GUN_HELD_LEFT := 16
const POSE_FLAG_GUN_SPINNING := 32
const POSE_FLAG_VOICE_MUTED := 64
const POSE_FLAG_GUN_STEADIED := 128
const POSE_FLAG_GATE_OPEN := 256
## Chamber 0–5 lives in the next three bits. Bit 16 is the replay present flag.
const POSE_FLAG_CHAMBER_SHIFT := 9
const STEAM_REFRESH_SEC := 4.0
const VERSION_HANDSHAKE_TIMEOUT := 3.0
## A refused peer is dropped this long after the RPC that says why, and never in the
## same frame: disconnecting clears the send queue, so the peer would only see the
## link close and report a version mismatch.
const KICK_GRACE_MSEC := 250

var transport: NetworkTransport
var discovery: LanDiscovery
var session_active := false
## The live lobby. The host edits it through the host_* calls; clients get `_roster_sync`.
var roster := LobbyRoster.new()

var _steam: SteamTransport
var _steam_browse := false
var _steam_refresh_accum := 0.0
var _last_steam_lobbies: Array = []

## Host: peer id -> seconds left to send the version hello.
var _pending_peers := {}
## Host: peer id -> player name, for peers that passed the hello and hold a slot.
var _verified_peers := {}
## Joiner: waiting for _version_ok / _version_reject / _join_refused after sending hello.
var _awaiting_version_ok := false
var _handshake_timer := 0.0
## Host: peer id -> [frame it was queued on, tick (msec) it may be dropped at].
var _kick_peers := {}
## Host: the `open/total` field last pushed to the LAN beacon and the Steam lobby.
var _advertised_slots := ""


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
	_flush_kicks()
	_refresh_advert()


# -- Version helpers ---------------------------------------------------------

func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func versions_match(host_version: String, local_version: String) -> bool:
	return not host_version.is_empty() and not local_version.is_empty() and host_version == local_version


func version_mismatch_message(host_version: String, local_version: String) -> String:
	var host_label := host_version if not host_version.is_empty() else tr("NET_UNKNOWN_OLD")
	var local_label := local_version if not local_version.is_empty() else tr("NET_UNKNOWN")
	return tr("NET_VERSION_MISMATCH") % [host_label, local_label]


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


## Steam persona on the Steam transport, the device name on LAN.
func local_player_name() -> String:
	var player_name := ""
	if _steam != null and transport == _steam:
		player_name = _steam.persona_name()
	if player_name.is_empty():
		player_name = _local_host_name()
	return _clean_name(player_name)


## Human slots a new player could take right now. None while a duel runs: the
## lobby is joinable only between duels.
func joinable_slots() -> int:
	if not _is_lobby_host() or GameManager.duel.state != DuelManager.State.IDLE:
		return 0
	return roster.open_human_slots()


func steam_available() -> bool:
	# Meta Store / Quest APK is LAN-only; Steam lobbies stay on desktop.
	if OS.has_feature("android"):
		return false
	return SteamTransport.is_available()


func steam_lobby_label() -> String:
	return _steam.lobby_label() if _steam != null else "Steam lobby"


## Lobby we currently hold, or 0. Should always be 0 outside a session.
func steam_lobby_id() -> int:
	return _steam.lobby_id if _steam != null else 0


# -- LAN ---------------------------------------------------------------------

func host_lan() -> Error:
	leave("switching session")
	transport = ENetTransport.new(multiplayer)
	var err := transport.host()
	if err != OK:
		var hint := error_string(err)
		if OS.get_name() == "Android" and err == ERR_CANT_CREATE:
			hint += " — APK missing INTERNET (re-export Quest 3 after enabling LAN permissions)"
		network_error.emit(tr("NET_HOST_FAILED") % hint)
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
		network_error.emit(tr("NET_JOIN_FAILED") % [address, error_string(err)])
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
		network_error.emit(tr("NET_NO_STEAM"))
		return ERR_UNAVAILABLE
	leave("switching session")
	transport = _steam
	var err := _steam.host()
	if err != OK:
		transport = null
	return err


func join_steam(lobby_id: int) -> Error:
	if _steam == null:
		network_error.emit(tr("NET_NO_STEAM"))
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


func invite_steam_friends() -> void:
	if _steam == null or not session_active or transport != _steam or not _steam.is_lobby_host:
		network_error.emit(tr("NET_HOST_FIRST"))
		return
	_steam.open_invite_overlay()


func _on_steam_lobby_ready(_lobby: int) -> void:
	if _steam != null and _steam.is_lobby_host:
		_begin_session(true)
		# Do not auto-open the Steam invite overlay. Creating the lobby used to
		# call it on the same click as HOST (STEAM), which opened the dialog
		# under the cursor and made it unclosable in the Godot window.
	else:
		_try_begin_steam_join()


func _try_begin_steam_join() -> void:
	if session_active or _awaiting_version_ok or _steam == null or transport != _steam:
		return
	if _steam.is_lobby_host or _steam.lobby_id == 0:
		return
	if _steam.peer_connected():
		_start_joiner_handshake()


# -- Common ------------------------------------------------------------------

func leave(reason := "left session") -> void:
	_clear_handshake_state()
	if transport != null:
		transport.close()
		transport = null
	if _steam != null:
		# SteamTransport outlives `transport`, so a lobby or peer it picked up
		# from a late Steam callback would never be released otherwise, and
		# every later create / join failed until restart (BUG-009).
		_steam.close()
	_reset_multiplayer_peer()
	discovery.stop()
	if session_active:
		session_active = false
		session_ended.emit(reason)


## Leave the MultiplayerAPI in the offline state no transport owns, so the next
## host / join starts from a known peer instead of a half-closed one.
func _reset_multiplayer_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is OfflineMultiplayerPeer:
		return
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _begin_session(as_host: bool) -> void:
	if session_active:
		return
	session_active = true
	# A joiner holds this placeholder until the host's first _roster_sync.
	roster.reset(local_player_name() if as_host else "")
	if as_host:
		roster.scenario_index = GameManager.current_scenario_index
	_advertised_slots = ""
	_refresh_advert()
	roster_changed.emit()
	session_started.emit(as_host)


func _local_host_name() -> String:
	var name := OS.get_environment("COMPUTERNAME")
	if name.is_empty():
		name = OS.get_model_name()
	return name if not name.is_empty() else "Gunslinger Host"


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_pending_peers[peer_id] = VERSION_HANDSHAKE_TIMEOUT


func _on_peer_disconnected(peer_id: int) -> void:
	_pending_peers.erase(peer_id)
	_kick_peers.erase(peer_id)
	if not _verified_peers.has(peer_id):
		return
	_verified_peers.erase(peer_id)
	# Read the duel state before peer_left: GameManager stops the duel on it.
	roster.vacate_peer(peer_id, GameManager.duel.state != DuelManager.State.IDLE)
	peer_left.emit(peer_id)
	_sync_roster()


func _on_connected_to_server() -> void:
	discovery.stop()
	_start_joiner_handshake()


func _on_connection_failed() -> void:
	network_error.emit(tr("NET_CONN_FAILED"))
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
	network_error.emit(tr("NET_HOST_DISCONNECTED"))
	leave("host disconnected")


# -- Version handshake -------------------------------------------------------

func _clear_handshake_state() -> void:
	_pending_peers.clear()
	_verified_peers.clear()
	_awaiting_version_ok = false
	_handshake_timer = 0.0
	_kick_peers.clear()
	_advertised_slots = ""


func _start_joiner_handshake() -> void:
	if session_active or _awaiting_version_ok:
		return
	_awaiting_version_ok = true
	_handshake_timer = VERSION_HANDSHAKE_TIMEOUT
	_version_hello.rpc_id(1, game_version(), local_player_name())


func _tick_handshake(delta: float) -> void:
	for peer_id: int in _pending_peers.keys():
		_pending_peers[peer_id] -= delta
		if _pending_peers[peer_id] > 0.0:
			continue
		_pending_peers.erase(peer_id)
		_version_reject.rpc_id(peer_id, game_version())
		_queue_kick(peer_id)
		GameManager.show_message(
				tr("NET_REJECT_UNKNOWN") % game_version(), 6.0)
	if _handshake_timer <= 0.0:
		return
	_handshake_timer -= delta
	if _handshake_timer > 0.0:
		return
	_handshake_timer = 0.0
	if _awaiting_version_ok:
		_awaiting_version_ok = false
		network_error.emit(version_mismatch_message("", game_version()))
		leave("version handshake timeout")


func _queue_kick(peer_id: int) -> void:
	_kick_peers[peer_id] = [Engine.get_process_frames(), Time.get_ticks_msec() + KICK_GRACE_MSEC]


func _flush_kicks() -> void:
	for peer_id: int in _kick_peers.keys():
		var due: Array = _kick_peers[peer_id]
		if Engine.get_process_frames() <= due[0] or Time.get_ticks_msec() < due[1]:
			continue
		_kick_peers.erase(peer_id)
		var peer := multiplayer.multiplayer_peer
		if peer != null and multiplayer.get_peers().has(peer_id):
			peer.disconnect_peer(peer_id)


## Host: tell `peer_id` why it cannot stay, then drop it.
func _refuse(peer_id: int, reason_key: String) -> void:
	_pending_peers.erase(peer_id)
	_join_refused.rpc_id(peer_id, reason_key)
	_queue_kick(peer_id)


func _clean_name(player_name: String) -> String:
	return player_name.strip_escapes().strip_edges().left(LobbyRoster.NAME_MAX)


@rpc("any_peer", "call_remote", "reliable")
func _version_hello(client_version: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _verified_peers.has(peer_id) or _kick_peers.has(peer_id):
		return
	_pending_peers.erase(peer_id)
	if not versions_match(game_version(), client_version):
		_version_reject.rpc_id(peer_id, game_version())
		_queue_kick(peer_id)
		var peer_label := client_version if not client_version.is_empty() else tr("NET_UNKNOWN_OLD")
		GameManager.show_message(
				tr("NET_REJECT_VERSION") % [game_version(), peer_label], 6.0)
		return
	if GameManager.duel.state != DuelManager.State.IDLE:
		_refuse(peer_id, "NET_REFUSED_DUEL")
		return
	var slot := roster.assign_peer(peer_id, _clean_name(player_name))
	if slot < 0:
		_refuse(peer_id, "NET_REFUSED_FULL")
		return
	if str(roster.slots[slot]["name"]).is_empty():
		roster.slots[slot]["name"] = tr("NET_PLAYER_N") % (slot + 1)
	_verified_peers[peer_id] = roster.slots[slot]["name"]
	_version_ok.rpc_id(peer_id)
	# The roster goes out before peer_joined, so the joiner knows its slot when
	# GameManager sends it to the waiting room.
	_sync_roster()
	peer_joined.emit(peer_id)


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


## Host -> one peer: the lobby is full, a duel is running, or the host kicked it.
## `reason_key` is a translation key. The host drops the peer after KICK_GRACE_MSEC.
@rpc("authority", "call_remote", "reliable")
func _join_refused(reason_key: String) -> void:
	_awaiting_version_ok = false
	_handshake_timer = 0.0
	var reason := tr(reason_key)
	network_error.emit(reason)
	leave(reason)


# -- Lobby roster --------------------------------------------------------------

func _is_lobby_host() -> bool:
	return session_active and multiplayer.is_server()


## Host: push the roster to every verified peer and tell local listeners.
func _sync_roster() -> void:
	var data := roster.pack()
	for peer_id: int in _verified_peers:
		_roster_sync.rpc_id(peer_id, data)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _roster_sync(data: Dictionary) -> void:
	if roster.unpack(data):
		roster_changed.emit()


## Pick a side in Teams. A client asks the host; the host applies its own. Ignored in
## free-for-all. A pick may leave a side empty: START then refuses until one is filled.
## During a duel it applies from the next one (the duel runs on its snapshot).
func request_side(side: int) -> void:
	if not session_active:
		return
	if multiplayer.is_server():
		_apply_side(roster.local_slot(), side)
	else:
		_request_side.rpc_id(1, side)


@rpc("any_peer", "call_remote", "reliable")
func _request_side(side: int) -> void:
	if multiplayer.is_server():
		_apply_side(roster.slot_of_peer(multiplayer.get_remote_sender_id()), side)


func _apply_side(slot: int, side: int) -> void:
	if roster.mode == LobbyRoster.Mode.TEAMS and roster.set_side(slot, side):
		_sync_roster()


## Host: keep the LAN beacon and the Steam lobby in step with the roster and the duel.
func _refresh_advert() -> void:
	if not _is_lobby_host():
		return
	var open := joinable_slots()
	var slots_text := LobbyRoster.format_slots(open, roster.human_slots())
	if slots_text == _advertised_slots:
		return
	_advertised_slots = slots_text
	discovery.set_beacon_slots(slots_text)
	if _steam != null and transport == _steam:
		_steam.set_slots(slots_text)
		_steam.set_joinable(open > 0)


# Host API. The lobby UI and the autotests edit the roster only through these; each
# returns false when refused and ends in a sync when applied.

func host_set_slot_count(count: int) -> bool:
	if not _is_lobby_host() or not roster.set_slot_count(count):
		return false
	_sync_roster()
	return true


func host_set_mode(mode: int) -> bool:
	if not _is_lobby_host() or (mode != LobbyRoster.Mode.FFA and mode != LobbyRoster.Mode.TEAMS):
		return false
	roster.mode = mode
	_sync_roster()
	return true


func host_set_scenario(scenario_index: int) -> bool:
	if not _is_lobby_host() or scenario_index < 0 or scenario_index >= GameManager.SCENARIOS.size():
		return false
	roster.scenario_index = scenario_index
	# The waiting room is the arena, so a pick made there moves everyone now. A
	# pick made during a duel applies from the next one.
	if GameManager.duel.state == DuelManager.State.IDLE:
		GameManager.duel.host_open_lobby()
	_sync_roster()
	return true


## `kind` is OPEN or NPC. A slot a human holds is refused: kick first.
func host_set_slot_kind(slot: int, kind: int) -> bool:
	if not _is_lobby_host() or not roster.set_slot_kind(slot, kind):
		return false
	_sync_roster()
	return true


## `archetype` is an index into GameManager.ARCHETYPES, or LobbyRoster.ARCHETYPE_MIXED.
func host_set_archetype(slot: int, archetype: int) -> bool:
	if not _is_lobby_host() or archetype >= GameManager.ARCHETYPES.size() \
			or not roster.set_archetype(slot, archetype):
		return false
	_sync_roster()
	return true


func host_set_npc_side(slot: int, side: int) -> bool:
	if not _is_lobby_host() or slot < 0 or slot >= roster.slots.size() \
			or roster.slots[slot]["kind"] != LobbyRoster.Kind.NPC or not roster.set_side(slot, side):
		return false
	_sync_roster()
	return true


## Between duels only (the waiting room or the rematch gap). The slot reopens.
func host_kick(slot: int) -> bool:
	if not _is_lobby_host() or slot <= 0 or slot >= roster.slots.size() \
			or roster.slots[slot]["kind"] != LobbyRoster.Kind.HUMAN:
		return false
	var duel_state := GameManager.duel.state
	if duel_state != DuelManager.State.IDLE and duel_state != DuelManager.State.RESOLUTION:
		return false
	var peer_id: int = roster.slots[slot]["peer_id"]
	roster.open_slot(slot)
	_verified_peers.erase(peer_id)
	_refuse(peer_id, "NET_REFUSED_KICKED")
	peer_left.emit(peer_id)
	_sync_roster()
	return true


## A duel ended: one more win for each of `slots` (the winning side's).
func host_add_wins(slots: Array[int]) -> bool:
	if not _is_lobby_host():
		return false
	for slot in slots:
		if slot >= 0 and slot < roster.slots.size():
			roster.slots[slot]["wins"] += 1
	_sync_roster()
	return true


## Translation key for why the host cannot start a duel now, or "" when it can.
func start_refusal() -> String:
	if not _is_lobby_host():
		return "MSG_HOST_ONLY_RESET"
	return roster_refusal()


## Translation key for why the live roster cannot start a duel, or "" when it can. Any
## peer can ask: a client knows the reason a rematch fell back to the waiting room.
func roster_refusal() -> String:
	if roster.open_human_slots() > 0:
		return "MSG_LOBBY_NOT_FULL"
	if not roster.can_start():
		return "MSG_LOBBY_EMPTY_SIDE"
	return ""


## Start (or restart) the duel for everyone. Shows the reason and returns false when
## the roster cannot start.
func host_start() -> bool:
	var refusal := start_refusal()
	if not refusal.is_empty():
		GameManager.show_message(tr(refusal), 3.0)
		return false
	# A peer still mid-handshake must not see the duel RPCs. Refuse it first: the
	# reliable channel delivers this ahead of _mp_begin.
	for peer_id: int in _pending_peers.keys():
		_refuse(peer_id, "NET_REFUSED_DUEL")
	GameManager.begin_mp_duel()
	_sync_roster()
	return true


## Stop any duel and put everyone in the waiting room on the roster's arena.
func host_back_to_lobby() -> bool:
	if not _is_lobby_host():
		return false
	GameManager.duel.host_open_lobby()
	_sync_roster()
	return true


# -- Fast-path relays --------------------------------------------------------

func send_pose(head: Transform3D, left: Transform3D, right: Transform3D, flags: int,
		gun := Transform3D.IDENTITY, hands := 0, objects := 0,
		prop := Transform3D.IDENTITY, round_xf := Transform3D.IDENTITY) -> void:
	if session_active and peer_count() > 0:
		_pose.rpc(head, left, right, flags, gun, hands, objects, prop, round_xf)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pose(head: Transform3D, left: Transform3D, right: Transform3D, flags: int,
		gun: Transform3D, hands: int, objects: int, prop: Transform3D, round_xf: Transform3D) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if _accepts_sender(peer_id):
		pose_received.emit(peer_id, head, left, right, flags, gun, hands, objects, prop, round_xf)


func send_shot(origin: Vector3, direction: Vector3) -> void:
	if session_active and peer_count() > 0:
		_shot.rpc(origin, direction)


@rpc("any_peer", "call_remote", "reliable")
func _shot(origin: Vector3, direction: Vector3) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if _accepts_sender(peer_id):
		shot_received.emit(peer_id, origin, direction)


## Host: the pose of the NPC it runs in `slot`, for the clients' proxy. `flags` are the
## POSE_FLAG_* bits `DuelistAI.capture_replay_pose` sets.
func send_npc_pose(slot: int, head: Transform3D, flags: int, gun: Transform3D) -> void:
	if _is_lobby_host() and peer_count() > 0:
		_npc_pose.rpc(slot, head, flags, gun)


## Receivers drop a slot that is not an NPC in the running duel's snapshot.
@rpc("authority", "call_remote", "unreliable_ordered")
func _npc_pose(slot: int, head: Transform3D, flags: int, gun: Transform3D) -> void:
	if session_active:
		npc_pose_received.emit(slot, head, flags, gun)


## Host: the NPC in `slot` fired. Clients draw the tracer; the hit is the host's.
func send_npc_shot(slot: int, origin: Vector3, direction: Vector3) -> void:
	if _is_lobby_host() and peer_count() > 0:
		_npc_shot.rpc(slot, origin, direction)


@rpc("authority", "call_remote", "reliable")
func _npc_shot(slot: int, origin: Vector3, direction: Vector3) -> void:
	if session_active:
		npc_shot_received.emit(slot, origin, direction)


## Poses and shots count only inside a session, and on the host only from a peer that
## passed the handshake. Receivers then map the sender to its slot and drop the unknown.
func _accepts_sender(peer_id: int) -> bool:
	if not session_active:
		return false
	return not multiplayer.is_server() or _verified_peers.has(peer_id)
