class_name SettingsMenu
extends VBoxContainer
## Player-facing knobs: volume, holster, VR turn, mouse sensitivity, flat video.
## Not the F3 debug panel. Persist immediately via PlayerSettings / MovementConfig / tuning.

signal back_pressed

const MOUSE_MIN := 0.0005
const MOUSE_MAX := 0.01

var _refreshing := false


func _ready() -> void:
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
	%BackButton.pressed.connect(func() -> void: back_pressed.emit())
	%VolumeSlider.value_changed.connect(_on_volume_changed)
	%HolsterOption.item_selected.connect(_on_holster_selected)
	%TurnModeOption.item_selected.connect(_on_turn_mode_selected)
	%SmoothTurnSlider.value_changed.connect(_on_smooth_turn_changed)
	%SnapTurnSlider.value_changed.connect(_on_snap_turn_changed)
	%MouseSlider.value_changed.connect(_on_mouse_changed)
	%WindowModeOption.item_selected.connect(_on_video_choice_changed)
	%ResolutionOption.item_selected.connect(_on_video_choice_changed)
	%ApplyVideoButton.pressed.connect(_on_apply_video)
	refresh()


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
	_refreshing = false


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
