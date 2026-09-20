class_name SettingsMenu
extends VBoxContainer
## Player-facing knobs: volume, holster, VR turn, mouse sensitivity, flat video,
## and combat button remapping. Not the F3 debug panel.
## Persist immediately via PlayerSettings / MovementConfig / tuning.

signal back_pressed

const MOUSE_MIN := 0.0005
const MOUSE_MAX := 0.01

var _refreshing := false
## action StringName → { label: Label, button: Button, is_vr: bool }
var _bind_rows: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if %HolsterOption.item_count == 0:
		%HolsterOption.add_item("Right")
		%HolsterOption.add_item("Left")
	if %TurnModeOption.item_count == 0:
		%TurnModeOption.add_item("Off")
		%TurnModeOption.add_item("Smooth")
		%TurnModeOption.add_item("Snap")
	if %WindowModeOption.item_count == 0:
		%WindowModeOption.add_item("Windowed")
		%WindowModeOption.add_item("Borderless Fullscreen")
		%WindowModeOption.add_item("Exclusive Fullscreen")
	%BackButton.pressed.connect(_on_back)
	%VolumeSlider.value_changed.connect(_on_volume_changed)
	%HolsterOption.item_selected.connect(_on_holster_selected)
	%TurnModeOption.item_selected.connect(_on_turn_mode_selected)
	%SmoothTurnSlider.value_changed.connect(_on_smooth_turn_changed)
	%SnapTurnSlider.value_changed.connect(_on_snap_turn_changed)
	%MouseSlider.value_changed.connect(_on_mouse_changed)
	%WindowModeOption.item_selected.connect(_on_video_choice_changed)
	%ResolutionOption.item_selected.connect(_on_video_choice_changed)
	%ApplyVideoButton.pressed.connect(_on_apply_video)
	%ResetBindsButton.pressed.connect(_on_reset_binds)
	PlayerSettings.binds_changed.connect(_refresh_bind_labels)
	PlayerSettings.listen_cancelled.connect(_refresh_bind_labels)
	_build_bind_rows()
	refresh()


func _exit_tree() -> void:
	PlayerSettings.cancel_listen()


func _input(event: InputEvent) -> void:
	if not PlayerSettings.is_listening():
		return
	if event.is_action_pressed("ui_cancel"):
		PlayerSettings.cancel_listen()
		_refresh_bind_labels()
		get_viewport().set_input_as_handled()
		return
	if PlayerSettings.listen_is_vr:
		return
	if event is InputEventMouseMotion:
		return
	if event.is_pressed() and not event.is_echo():
		if PlayerSettings.try_capture_flat_event(event):
			_refresh_bind_labels()
			get_viewport().set_input_as_handled()


func refresh() -> void:
	_refreshing = true
	%VolumeSlider.value = PlayerSettings.master_volume * 100.0
	%VolumeValue.text = "%d%%" % int(round(%VolumeSlider.value))
	%HolsterOption.selected = int(GameManager.tuning.get("holster_side", 0))
	%TurnModeOption.selected = MovementConfig.turn_mode
	%SmoothTurnSlider.value = MovementConfig.smooth_turn_speed
	%SmoothTurnValue.text = "%d°/s" % int(round(MovementConfig.smooth_turn_speed))
	%SnapTurnSlider.value = MovementConfig.snap_turn_angle
	%SnapTurnValue.text = "%d°" % int(round(MovementConfig.snap_turn_angle))
	var mouse_t := inverse_lerp(MOUSE_MIN, MOUSE_MAX, MovementConfig.mouse_sensitivity)
	%MouseSlider.value = clampf(mouse_t, 0.0, 1.0) * 100.0
	%MouseValue.text = "%d" % int(round(%MouseSlider.value))
	%WindowModeOption.selected = PlayerSettings.window_mode
	_fill_resolution_options()
	_apply_platform_rows()
	_refresh_bind_labels()
	_refreshing = false


func _build_bind_rows() -> void:
	for child in %BindRows.get_children():
		child.queue_free()
	_bind_rows.clear()
	for action in PlayerSettings.VR_ACTIONS:
		_add_bind_row(action, true)
	for action in PlayerSettings.FLAT_ACTIONS:
		_add_bind_row(action, false)


func _add_bind_row(action: StringName, is_vr: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(160, 0)
	name_label.text = PlayerSettings.vr_action_label(action) if is_vr \
			else PlayerSettings.flat_action_label(action)
	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rebind_btn := Button.new()
	rebind_btn.text = "Rebind"
	rebind_btn.custom_minimum_size = Vector2(96, 0)
	var captured_action := action
	var captured_vr := is_vr
	rebind_btn.pressed.connect(func() -> void:
		_start_rebind(captured_action, captured_vr))
	row.add_child(name_label)
	row.add_child(value_label)
	row.add_child(rebind_btn)
	%BindRows.add_child(row)
	_bind_rows[_row_key(action, is_vr)] = {
		"row": row,
		"label": value_label,
		"button": rebind_btn,
		"action": action,
		"is_vr": is_vr,
	}


func _row_key(action: StringName, is_vr: bool) -> String:
	return ("%s:%s" % ["vr" if is_vr else "flat", String(action)])


func _refresh_bind_labels() -> void:
	var listening := PlayerSettings.is_listening()
	for key in _bind_rows:
		var info: Dictionary = _bind_rows[key]
		var action: StringName = info["action"]
		var is_vr: bool = info["is_vr"]
		var label: Label = info["label"]
		var button: Button = info["button"]
		if listening and PlayerSettings.listen_action == action \
				and PlayerSettings.listen_is_vr == is_vr:
			label.text = "Press a button…"
			button.text = "…"
		elif is_vr:
			label.text = PlayerSettings.vr_source_label(PlayerSettings.get_vr_bind(action))
			button.text = "Rebind"
		else:
			label.text = PlayerSettings.flat_event_label(
					PlayerSettings.get_flat_bind_event(action))
			button.text = "Rebind"


func _start_rebind(action: StringName, is_vr: bool) -> void:
	if PlayerSettings.is_listening() and PlayerSettings.listen_action == action \
			and PlayerSettings.listen_is_vr == is_vr:
		PlayerSettings.cancel_listen()
		_refresh_bind_labels()
		return
	PlayerSettings.begin_listen(action, is_vr)
	_refresh_bind_labels()


func _on_reset_binds() -> void:
	PlayerSettings.reset_binds()
	_refresh_bind_labels()


func _on_back() -> void:
	PlayerSettings.cancel_listen()
	back_pressed.emit()


func _fill_resolution_options() -> void:
	var option: OptionButton = %ResolutionOption
	option.clear()
	var current := Vector2i(PlayerSettings.window_width, PlayerSettings.window_height)
	var selected := 0
	var choices := PlayerSettings.resolution_choices()
	if choices.is_empty():
		choices = [current]
	for i in choices.size():
		var size: Vector2i = choices[i]
		option.add_item("%d × %d" % [size.x, size.y])
		option.set_item_metadata(i, size)
		if size == current:
			selected = i
	option.selected = selected


func _apply_platform_rows() -> void:
	var vr := GameManager.is_vr
	%TurnRow.visible = vr
	%SmoothTurnRow.visible = vr and MovementConfig.turn_mode == MovementConfig.TurnMode.SMOOTH
	%SnapTurnRow.visible = vr and MovementConfig.turn_mode == MovementConfig.TurnMode.SNAP
	%MouseRow.visible = not vr
	%WindowModeRow.visible = not vr
	%ResolutionRow.visible = not vr
	%ApplyVideoButton.visible = not vr
	%ResolutionOption.disabled = %WindowModeOption.selected == PlayerSettings.WindowModeSetting.BORDERLESS
	for key in _bind_rows:
		var info: Dictionary = _bind_rows[key]
		(info["row"] as Control).visible = info["is_vr"] == vr


func _on_volume_changed(value: float) -> void:
	%VolumeValue.text = "%d%%" % int(round(value))
	if _refreshing:
		return
	PlayerSettings.set_master_volume(value / 100.0)


func _on_holster_selected(index: int) -> void:
	if _refreshing:
		return
	GameManager.set_tuning("holster_side", index)


func _on_turn_mode_selected(index: int) -> void:
	if _refreshing:
		return
	MovementConfig.set_value("turn_mode", index)
	_apply_platform_rows()


func _on_smooth_turn_changed(value: float) -> void:
	%SmoothTurnValue.text = "%d°/s" % int(round(value))
	if _refreshing:
		return
	MovementConfig.set_value("smooth_turn_speed", value)


func _on_snap_turn_changed(value: float) -> void:
	%SnapTurnValue.text = "%d°" % int(round(value))
	if _refreshing:
		return
	MovementConfig.set_value("snap_turn_angle", value)


func _on_mouse_changed(value: float) -> void:
	%MouseValue.text = "%d" % int(round(value))
	if _refreshing:
		return
	MovementConfig.set_value("mouse_sensitivity", lerpf(MOUSE_MIN, MOUSE_MAX, value / 100.0))


func _on_video_choice_changed(_index: int) -> void:
	if _refreshing:
		return
	_apply_platform_rows()


func _pending_resolution() -> Vector2i:
	var option: OptionButton = %ResolutionOption
	var index: int = option.selected
	if index < 0:
		return Vector2i(PlayerSettings.window_width, PlayerSettings.window_height)
	var size: Variant = option.get_item_metadata(index)
	if size is Vector2i:
		return size as Vector2i
	return Vector2i(PlayerSettings.window_width, PlayerSettings.window_height)


func _on_apply_video() -> void:
	var mode_option: OptionButton = %WindowModeOption
	PlayerSettings.apply_display(mode_option.selected, _pending_resolution())
	_apply_platform_rows()
