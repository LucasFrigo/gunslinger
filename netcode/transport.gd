class_name NetworkTransport
extends RefCounted
## Base class for network transports. Both ENet (LAN dev) and Steam (shipping)
## feed the same Godot MultiplayerAPI, so gameplay code never knows which one
## is active.


func kind() -> String:
	return "none"


## Start hosting a session. Returns OK on success (or on async start).
func host() -> Error:
	return ERR_UNAVAILABLE


## Join a session. `target` is transport-specific: an IP string for ENet,
## a lobby id (int) for Steam.
func join(_target: Variant) -> Error:
	return ERR_UNAVAILABLE


## Called every frame by NetworkManager.
func poll() -> void:
	pass


func close() -> void:
	pass
