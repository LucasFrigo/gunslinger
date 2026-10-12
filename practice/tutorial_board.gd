class_name TutorialBoard
extends Node3D
## Old-town news board on the practice-hub porch. Lists the live binds so
## a remap in Settings shows up here too. Flat and VR share the same board.

@onready var _copy: Label3D = $Copy


func _ready() -> void:
	PlayerSettings.binds_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if PlayerSettings.binds_changed.is_connected(_refresh):
		PlayerSettings.binds_changed.disconnect(_refresh)


func copy_text() -> String:
	return _copy.text if _copy != null else ""


func _refresh() -> void:
	if _copy == null:
		return
	_copy.text = _vr_copy() if GameManager.is_vr else _flat_copy()


func _flat(action: StringName) -> String:
	return PlayerSettings.flat_event_label(PlayerSettings.get_flat_bind_event(action))


func _vr(action: StringName) -> String:
	return PlayerSettings.vr_source_label(PlayerSettings.get_vr_bind(action))


func _mapped(action: StringName) -> String:
	if not InputMap.has_action(action):
		return String(action)
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return String(action)
	return PlayerSettings.flat_event_label(events[0])


func _flat_copy() -> String:
	var fire := _flat(&"fire")
	var draw := _flat(&"draw_toggle")
	var cock := _flat(&"cock_hammer")
	var reload := _flat(&"reload")
	var wheel := _flat(&"prop_radial")
	var throw := _flat(&"prop_fire")
	var use := _mapped(&"interact")
	return "\n".join([
		tr("BOARD_TITLE"),
		"",
		tr("BOARD_FLAT_DRAW") % draw,
		tr("BOARD_FLAT_FIRE") % fire,
		tr("BOARD_FLAT_COCK") % cock,
		tr("BOARD_FLAT_RELOAD") % reload,
		tr("BOARD_FLAT_JAM") % cock,
		tr("BOARD_FLAT_PROPS") % [wheel, throw],
		tr("BOARD_FLAT_BOTTLES") % [use, use],
		tr("BOARD_FLAT_SLOTS") % use,
	])


func _vr_copy() -> String:
	var fire := _vr(&"fire")
	var grip := _vr(&"grip")
	var cock := _vr(&"cock")
	var gate := _vr(&"gate")
	var wheel := _vr(&"prop_radial")
	var pause := _vr(&"pause")
	return "\n".join([
		tr("BOARD_TITLE"),
		"",
		tr("BOARD_VR_MENU") % pause,
		tr("BOARD_VR_DRAW") % grip,
		tr("BOARD_VR_FIRE") % fire,
		tr("BOARD_VR_COCK") % cock,
		tr("BOARD_VR_RELOAD") % gate,
		tr("BOARD_VR_PROPS") % [wheel, fire],
		tr("BOARD_VR_BOTTLES") % grip,
		tr("BOARD_VR_SLOTS") % fire,
	])
