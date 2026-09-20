class_name PropController
extends Node3D
## Miscellaneous off-hand props: the equip radial and the cigarette boomerang.
## Lives under `Player`. The rigs supply the attach points, the highlight vector
## and the launch direction, so VR and flat share one code path from here down.

const ITEM_NONE := &"none"
const ITEM_CIGARETTE := &"cigarette"

## Wheel order, clockwise from the top.
const ITEMS: Array[Dictionary] = [
	{"id": ITEM_NONE, "label": "Empty Hand"},
	{"id": ITEM_CIGARETTE, "label": "Cigarette"},
]

## Stick / mouse deflection before a wedge highlights. Inside it, release cancels.
const HIGHLIGHT_DEADZONE := 0.35

var _player: Player
var _prop: Cigarette
var _equipped: StringName = ITEM_NONE
var _radial_hand: StringName = &""
var _radial_index := -1
var _vr_wheel: PropRadial
var _fire_held := false


## Wedge under `vector` (x right, y up), or -1 for the cancel deadzone.
static func highlight_index(vector: Vector2, count: int) -> int:
	if count <= 0 or vector.length() < HIGHLIGHT_DEADZONE:
		return -1
	var angle := wrapf(atan2(vector.x, vector.y), 0.0, TAU)
	return int(roundf(angle / (TAU / float(count)))) % count


static func item_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for item in ITEMS:
		labels.append(str(item["label"]))
	return labels


func setup(player: Player) -> void:
	_player = player


func is_radial_open() -> bool:
	return _radial_hand != &""


func has_prop() -> bool:
	return is_instance_valid(_prop)


func is_prop_flying() -> bool:
	return has_prop() and _prop.is_flying()


## 0 → 1 windup on the equipped prop, for readouts and tests.
func charge_ratio() -> float:
	return _prop.charge_ratio() if has_prop() else 0.0


func equipped_item() -> StringName:
	return _equipped


## New duel: drop whatever is in the hand and close any open wheel.
func reset_for_duel() -> void:
	_close_radial(false)
	_fire_held = false
	_clear_prop()
	_equipped = ITEM_NONE


# -- Radial -------------------------------------------------------------------

func on_radial_changed(hand: StringName, pressed: bool) -> void:
	if pressed:
		_open_radial(hand)
	elif _radial_hand == hand:
		_close_radial(true)


func _open_radial(hand: StringName) -> void:
	if is_radial_open() or not _can_use_props():
		return
	# A live boomerang owns the hand: ignore the wheel until it is caught.
	if is_prop_flying() or _stowed():
		return
	_radial_hand = hand
	_radial_index = -1
	_player.rig.set_prop_radial_active(true, hand)
	if _player.use_vr:
		_show_vr_wheel(hand)
	elif is_instance_valid(GameManager.hud):
		GameManager.hud.show_prop_radial(item_labels())
	_refresh_highlight(true)


func _close_radial(equip: bool) -> void:
	if not is_radial_open():
		return
	var index := _radial_index
	_radial_hand = &""
	_radial_index = -1
	if is_instance_valid(_player) and _player.rig != null:
		_player.rig.set_prop_radial_active(false)
	if is_instance_valid(_vr_wheel):
		_vr_wheel.queue_free()
	_vr_wheel = null
	if not _player.use_vr and is_instance_valid(GameManager.hud):
		GameManager.hud.hide_prop_radial()
	if equip and index >= 0:
		equip_item(ITEMS[index]["id"])


func _refresh_highlight(force := false) -> void:
	var index := highlight_index(_player.rig.get_prop_radial_vector(), ITEMS.size())
	if index == _radial_index and not force:
		return
	_radial_index = index
	if is_instance_valid(_vr_wheel):
		_vr_wheel.set_highlight(index)
	elif not _player.use_vr and is_instance_valid(GameManager.hud):
		GameManager.hud.set_prop_radial_highlight(index)


func _show_vr_wheel(hand: StringName) -> void:
	var anchor: Node3D = _player.rig.get_hand_node(hand)
	if anchor == null:
		return
	_vr_wheel = PropRadial.new()
	anchor.add_child(_vr_wheel)
	_vr_wheel.position = Vector3(0.0, 0.10, -0.18)
	_vr_wheel.setup(item_labels())


func equip_item(id: StringName) -> void:
	if id == _equipped and (id == ITEM_NONE or has_prop()):
		return
	_clear_prop()
	_equipped = id
	if id == ITEM_CIGARETTE:
		var attach := _prop_attach()
		if attach == null:
			_equipped = ITEM_NONE
			return
		_prop = Cigarette.spawn_held(attach)
		GameManager.show_message("Cigarette in the off hand", 1.5)
	else:
		GameManager.show_message("Off hand empty", 1.2)


# -- Boomerang ----------------------------------------------------------------

## Off-hand trigger (VR) or `prop_fire` (flat): hold winds up and charges the
## range, release throws along the hand's forward at that moment.
func on_fire_changed(pressed: bool) -> void:
	if not pressed:
		if not _fire_held:
			return
		_fire_held = false
		if has_prop():
			_prop.release_charge(get_tree().current_scene, _launch_direction())
		return
	if _fire_held or is_radial_open() or not has_prop():
		return
	if _prop.is_flying() or _stowed() or not _can_use_props():
		return
	_fire_held = true
	_prop.begin_charge()


func _launch_direction() -> Vector3:
	if _player.use_vr:
		return -_player.rig.get_hand_transform(_hand()).basis.z
	return _player.rig.get_aim_override()


# -- Attach upkeep ------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _player == null or _player.rig == null:
		return
	if is_radial_open():
		if _can_use_props():
			_refresh_highlight()
		else:
			_close_radial(false)
	# Pause or death mid-windup drops the throw instead of firing it off.
	if _fire_held and not _can_use_props():
		_fire_held = false
		if has_prop():
			_prop.cancel_charge()
	_update_prop_attach()


## The off hand changes when the revolver swaps hands, and VR reload parks the
## cig at the mouth while a belt round is in that hand. A flying cig always
## homes to the hand, never the mouth.
func _update_prop_attach() -> void:
	if not has_prop():
		return
	if _prop.is_flying():
		_prop.set_attach(_hand_attach())
		return
	_prop.set_attach(_prop_attach())


func _prop_attach() -> Node3D:
	if _stowed():
		var mouth: Node3D = _player.rig.get_mouth_attach()
		if mouth != null:
			return mouth
	return _hand_attach()


func _hand_attach() -> Node3D:
	return _player.rig.get_prop_attach(_hand())


func _hand() -> StringName:
	return _player.off_hand_name()


## VR reload owns the off hand while a cartridge is in it.
func _stowed() -> bool:
	return _player.use_vr and _player.is_holding_cartridge()


func _clear_prop() -> void:
	if is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null


func _can_use_props() -> bool:
	if not is_instance_valid(_player) or not _player.alive:
		return false
	if GameManager.is_pause_open():
		return false
	return GameManager.mode in [
		GameManager.GameMode.FREE_DUEL,
		GameManager.GameMode.GAUNTLET,
		GameManager.GameMode.MULTIPLAYER,
	]
