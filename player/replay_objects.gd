class_name ReplayObjects
extends Node3D
## Ghost meshes for one actor during a duel replay. The live prop and the
## held reload round keep their real state; this copy follows the clip.


var _prop: Node3D
var _prop_id := 0
var _round: Node3D


func show_snapshot(objects: int, prop_xf: Transform3D, round_xf: Transform3D) -> void:
	var id := objects & ReplayBuffer.PROP_ID_MASK
	var place := (objects >> ReplayBuffer.PROP_PLACE_SHIFT) & ReplayBuffer.PROP_PLACE_MASK
	if place == ReplayBuffer.PROP_PLACE_NONE:
		id = ReplayBuffer.PROP_NONE
	_show_prop(id, prop_xf)
	_show_round(objects & ReplayBuffer.ROUND_HELD != 0, round_xf)


func dismiss() -> void:
	_drop_prop()
	_drop_round()


func _show_prop(id: int, xf: Transform3D) -> void:
	if id != _prop_id:
		_drop_prop()
		_prop_id = id
		_prop = _spawn_prop(id)
	if _prop == null:
		return
	_prop.visible = true
	_prop.global_transform = xf


func _show_round(held: bool, xf: Transform3D) -> void:
	if not held:
		_drop_round()
		return
	if _round == null:
		_round = CartridgePhysical.spawn_held(self)
		_quiet(_round)
	_round.visible = true
	_round.global_transform = xf


func _spawn_prop(id: int) -> Node3D:
	var node: Node3D = null
	match id:
		ReplayBuffer.PROP_CIGARETTE:
			node = Cigarette.spawn_held(self)
		ReplayBuffer.PROP_COIN:
			node = Coin.spawn_held(self)
		ReplayBuffer.PROP_ACE:
			node = AceOfSpades.spawn_held(self)
		ReplayBuffer.PROP_BOTTLE:
			node = Longneck.spawn_held(self)
		_:
			return null
	_quiet(node)
	return node


func _quiet(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0


func _drop_prop() -> void:
	if is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null
	_prop_id = 0


func _drop_round() -> void:
	if is_instance_valid(_round):
		_round.queue_free()
	_round = null
