class_name ENetTransport
extends NetworkTransport
## Plain ENet over UDP for LAN testing (Quest 3 standalone <-> notebook).

const DEFAULT_PORT := 9099
const MAX_PLAYERS := 2

var _mp: MultiplayerAPI


func _init(mp: MultiplayerAPI) -> void:
	_mp = mp


func kind() -> String:
	return "lan"


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS - 1)
	if err != OK:
		push_error("ENetTransport: failed to create server (%s)" % error_string(err))
		return err
	_mp.multiplayer_peer = peer
	return OK


func join(target: Variant) -> Error:
	var address := str(target).strip_edges()
	if address.is_empty():
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, DEFAULT_PORT)
	if err != OK:
		push_error("ENetTransport: failed to connect to %s (%s)" % [address, error_string(err)])
		return err
	_mp.multiplayer_peer = peer
	return OK


func close() -> void:
	if _mp.multiplayer_peer != null:
		_mp.multiplayer_peer.close()
	_mp.multiplayer_peer = OfflineMultiplayerPeer.new()
