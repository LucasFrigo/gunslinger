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
		"THE PRACTICE RANGE",
		"",
		"DRAW — %s to draw or holster" % draw,
		"FIRE — %s" % fire,
		"COCK — %s" % cock,
		"RELOAD — %s" % reload,
		"JAM — look down, hold %s" % cock,
		"PROPS — %s for the wheel; hold %s to throw" % [wheel, throw],
		"BOTTLES — %s to grab, %s again to throw" % [use, use],
		"SLOTS — %s while looking at the lever" % use,
	])


func _vr_copy() -> String:
	var fire := _vr(&"fire")
	var grip := _vr(&"grip")
	var cock := _vr(&"cock")
	var gate := _vr(&"gate")
	var wheel := _vr(&"prop_radial")
	return "\n".join([
		"THE PRACTICE RANGE",
		"",
		"DRAW — %s, hold" % grip,
		"FIRE — %s" % fire,
		"COCK — %s" % cock,
		"RELOAD — %s opens the gate; shake to dump, off hand seats, bump or swing closes" % gate,
		"PROPS — off-hand %s for the wheel; off-hand %s throws" % [wheel, fire],
		"BOTTLES — off-hand %s, release to throw" % grip,
		"SLOTS — %s with a hand on the knob" % fire,
	])
