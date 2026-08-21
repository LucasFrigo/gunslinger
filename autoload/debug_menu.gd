extends CanvasLayer
## Autoload. Live-tuning panel: slow-mo, gunplay/AI, Flat+VR movement,
## named presets, and session controls (reset duel / main menu).
## Toggled with F3 in flat mode; in VR it lives on a wrist panel (left
## controller) and is toggled with the left menu/Y button.
## The same Control is shared: it reparents between this CanvasLayer and the
## wrist UIPanel3D.

const SLOWMO_SLIDERS := {
	"constant_factor": [0.05, 1.0, 0.01],
	"on_draw_factor": [0.05, 1.0, 0.01],
	"on_draw_duration": [0.2, 5.0, 0.1],
	"movement_min_factor": [0.05, 1.0, 0.01],
	"movement_full_speed": [0.5, 6.0, 0.1],
	"near_miss_factor": [0.05, 1.0, 0.01],
	"near_miss_duration": [0.1, 3.0, 0.05],
	"kill_cam_factor": [0.05, 1.0, 0.01],
	"kill_cam_duration": [0.5, 5.0, 0.1],
	"ramp_speed": [0.5, 20.0, 0.5],
}

const MOVEMENT_SLIDERS := {
	"walk_speed": [0.5, 6.0, 0.1],
	"mouse_sensitivity": [0.0005, 0.01, 0.0001],
	"lean_angle": [0.0, 30.0, 0.5],
	"lean_offset": [0.0, 0.8, 0.05],
	"vr_move_speed": [0.5, 6.0, 0.1],
	"stick_deadzone": [0.05, 0.5, 0.05],
	"smooth_turn_speed": [30.0, 180.0, 5.0],
	"snap_turn_angle": [15.0, 90.0, 5.0],
	"turn_deadzone": [0.2, 0.9, 0.05],
}

var use_vr := false
var panel: PanelContainer
var _status_label: Label
var _wrist_panel: UIPanel3D
var _open_in_vr := false
var _status_accum := 0.0
var _refreshing := false

var _mode_option: OptionButton
var _slowmo_sliders: Dictionary = {}
var _bullet_slider: HSlider
var _bullet_value: Label
var _ai_slider: HSlider
var _ai_value: Label
var _auto_cock: CheckButton
var _reload_sliders: Dictionary = {}
var _release_sliders: Dictionary = {}
var _holster_side_option: OptionButton
var _combat_sliders: Dictionary = {}
var _movement_sliders: Dictionary = {}
var _turn_mode_option: OptionButton
var _preset_option: OptionButton
var _preset_name_edit: LineEdit
var _reload_volume_toggle: CheckButton
## Session-only: translucent meshes on belt / chamber / bump / hand probe.
var show_reload_volumes := false


func _ready() -> void:
	layer = 10
	_build_panel()
	panel.visible = false


func setup(vr: bool) -> void:
	use_vr = vr


func toggle() -> void:
	if use_vr:
		_toggle_vr()
	else:
		panel.visible = not panel.visible
		if panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_from_systems()


func _toggle_vr() -> void:
	if _open_in_vr:
		_open_in_vr = false
		if is_instance_valid(_wrist_panel):
			var control := _wrist_panel.release_control()
			if control != null:
				if control.get_parent() != null:
					control.get_parent().remove_child(control)
				add_child(control)
				control.visible = false
			_wrist_panel.queue_free()
		_wrist_panel = null
		return
	var player := GameManager.local_player
	if not is_instance_valid(player):
		return
	var wrist: Node3D = player.rig.get_wrist_attach()
	if wrist == null:
		return
	_open_in_vr = true
	_wrist_panel = UIPanel3D.new()
	_wrist_panel.panel_size = Vector2(0.42, 0.56)
	wrist.add_child(_wrist_panel)
	if panel.get_parent() == self:
		remove_child(panel)
	_wrist_panel.set_control(panel)
	_refresh_from_systems()


func _process(delta: float) -> void:
	if _status_label == null:
		return
	_status_accum += delta / maxf(Engine.time_scale, 0.001)
	if _status_accum < 0.25:
		return
	_status_accum = 0.0
	_status_label.text = "time scale: %.2f\nfps: %d\nnet: %s (%s, %d peer(s))" % [
		Engine.time_scale,
		Engine.get_frames_per_second(),
		"ONLINE" if NetworkManager.is_active() else "offline",
		NetworkManager.transport_kind(),
		NetworkManager.peer_count(),
	]


# -- UI construction ------------------------------------------------------------

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 720)
	panel.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	scroll.add_child(root)

	_add_header(root, "DEBUG / TUNING")
	_status_label = Label.new()
	root.add_child(_status_label)

	_build_presets_section(root)
	_build_slowmo_section(root)
	_build_gunplay_section(root)
	_build_movement_section(root)
	_build_session_section(root)


func _build_presets_section(root: Control) -> void:
	_add_header(root, "Presets")
	_preset_option = OptionButton.new()
	root.add_child(_preset_option)

	_preset_name_edit = LineEdit.new()
	_preset_name_edit.placeholder_text = "Preset name"
	root.add_child(_preset_name_edit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_on_preset_save)
	row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(_on_preset_load)
	row.add_child(load_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.pressed.connect(_on_preset_delete)
	row.add_child(delete_btn)

	_refresh_preset_list()


func _build_slowmo_section(root: Control) -> void:
	_add_header(root, "Slow motion")
	_mode_option = OptionButton.new()
	for mode_name in TimeManager.Mode.keys():
		_mode_option.add_item(mode_name)
	_mode_option.selected = TimeManager.mode
	_mode_option.item_selected.connect(func(index: int) -> void:
		if _refreshing:
			return
		TimeManager.mode = index)
	TimeManager.mode_changed.connect(func(mode: int) -> void:
		if _mode_option.selected != mode:
			_mode_option.selected = mode)
	root.add_child(_mode_option)

	for property in SLOWMO_SLIDERS:
		var range_def: Array = SLOWMO_SLIDERS[property]
		var widgets := _add_slider(root, property, range_def[0], range_def[1], range_def[2],
				TimeManager.get(property),
				func(value: float) -> void:
					if _refreshing:
						return
					TimeManager.set_tunable(property, value))
		_slowmo_sliders[property] = widgets

	var reset_button := Button.new()
	reset_button.text = "Reset time to 1.0"
	reset_button.pressed.connect(TimeManager.reset)
	root.add_child(reset_button)


func _build_gunplay_section(root: Control) -> void:
	_add_header(root, "Gunplay / AI")
	var bullet := _add_slider(root, "bullet_speed", 20.0, 120.0, 1.0,
			GameManager.tuning["bullet_speed"],
			func(value: float) -> void:
				if _refreshing:
					return
				GameManager.set_tuning("bullet_speed", value))
	_bullet_slider = bullet["slider"]
	_bullet_value = bullet["label"]

	var ai := _add_slider(root, "ai_speed_mult", 0.3, 2.5, 0.05,
			GameManager.tuning["ai_speed_mult"],
			func(value: float) -> void:
				if _refreshing:
					return
				GameManager.set_tuning("ai_speed_mult", value))
	_ai_slider = ai["slider"]
	_ai_value = ai["label"]

	_auto_cock = CheckButton.new()
	_auto_cock.text = "Auto-cock (double action)"
	_auto_cock.button_pressed = GameManager.tuning["auto_cock"]
	_auto_cock.toggled.connect(func(pressed: bool) -> void:
		if _refreshing:
			return
		GameManager.set_tuning("auto_cock", pressed))
	root.add_child(_auto_cock)

	_add_header(root, "Regional Hits")
	const COMBAT_SLIDERS := {
		"player_health": [1.0, 6.0, 0.5],
		"arm_disarm_duration": [0.2, 4.0, 0.1],
		"leg_slow_duration": [0.2, 6.0, 0.1],
		"leg_speed_mult": [0.1, 1.0, 0.05],
	}
	for combat_key in COMBAT_SLIDERS:
		var combat_range: Array = COMBAT_SLIDERS[combat_key]
		var tune_combat: String = combat_key
		var combat_widgets := _add_slider(root, combat_key, combat_range[0], combat_range[1],
				combat_range[2], float(GameManager.tuning[tune_combat]),
				func(value: float) -> void:
					if _refreshing:
						return
					GameManager.set_tuning(tune_combat, value))
		_combat_sliders[tune_combat] = combat_widgets

	_add_header(root, "VR Reload (m/s)")
	const RELOAD_SLIDERS := {
		"reload_dump_speed": [1.0, 12.0, 0.1],
		"reload_dump_hold": [0.05, 1.0, 0.05],
		"reload_swing_close": [2.0, 14.0, 0.1],
		"reload_bump_close": [0.5, 8.0, 0.1],
	}
	for key in RELOAD_SLIDERS:
		var range_def: Array = RELOAD_SLIDERS[key]
		var tune_key: String = key
		var widgets := _add_slider(root, key, range_def[0], range_def[1], range_def[2],
				float(GameManager.tuning[tune_key]),
				func(value: float) -> void:
					if _refreshing:
						return
					GameManager.set_tuning(tune_key, value))
		_reload_sliders[tune_key] = widgets

	_reload_volume_toggle = CheckButton.new()
	_reload_volume_toggle.text = "Show reload volumes"
	_reload_volume_toggle.button_pressed = show_reload_volumes
	_reload_volume_toggle.toggled.connect(func(pressed: bool) -> void:
		if _refreshing:
			return
		show_reload_volumes = pressed
		if GameManager.local_player != null:
			GameManager.local_player.set_reload_volume_debug(pressed))
	root.add_child(_reload_volume_toggle)

	_add_header(root, "VR Gun Release")
	var holster_label := Label.new()
	holster_label.text = "holster_side"
	root.add_child(holster_label)
	_holster_side_option = OptionButton.new()
	_holster_side_option.add_item("Right")
	_holster_side_option.add_item("Left")
	_holster_side_option.selected = int(GameManager.tuning["holster_side"])
	_holster_side_option.item_selected.connect(func(index: int) -> void:
		if _refreshing:
			return
		GameManager.set_tuning("holster_side", index))
	root.add_child(_holster_side_option)
	const RELEASE_SLIDERS := {
		"gun_catch_radius": [0.08, 0.4, 0.01],
		"gun_holster_max_speed": [0.3, 3.0, 0.05],
		"gun_throw_scale": [0.5, 2.5, 0.05],
		"gun_throw_spin_scale": [0.5, 2.5, 0.05],
	}
	for release_key in RELEASE_SLIDERS:
		var release_range: Array = RELEASE_SLIDERS[release_key]
		var tune_release: String = release_key
		var release_widgets := _add_slider(root, release_key, release_range[0], release_range[1],
				release_range[2], float(GameManager.tuning[tune_release]),
				func(value: float) -> void:
					if _refreshing:
						return
					GameManager.set_tuning(tune_release, value))
		_release_sliders[tune_release] = release_widgets


func _build_movement_section(root: Control) -> void:
	_add_header(root, "Movement (Flat)")
	for key in ["walk_speed", "mouse_sensitivity", "lean_angle", "lean_offset"]:
		var range_def: Array = MOVEMENT_SLIDERS[key]
		var widgets := _add_slider(root, key, range_def[0], range_def[1], range_def[2],
				float(MovementConfig.get_value(key)),
				func(value: float) -> void:
					if _refreshing:
						return
					MovementConfig.set_value(key, value))
		_movement_sliders[key] = widgets

	_add_header(root, "Movement (VR)")
	var turn_label := Label.new()
	turn_label.text = "turn_mode"
	root.add_child(turn_label)
	_turn_mode_option = OptionButton.new()
	for mode_name in MovementConfig.TurnMode.keys():
		_turn_mode_option.add_item(mode_name)
	_turn_mode_option.selected = MovementConfig.turn_mode
	_turn_mode_option.item_selected.connect(func(index: int) -> void:
		if _refreshing:
			return
		MovementConfig.set_value("turn_mode", index))
	root.add_child(_turn_mode_option)

	for key in ["vr_move_speed", "stick_deadzone", "smooth_turn_speed",
			"snap_turn_angle", "turn_deadzone"]:
		var range_def2: Array = MOVEMENT_SLIDERS[key]
		var widgets2 := _add_slider(root, key, range_def2[0], range_def2[1], range_def2[2],
				float(MovementConfig.get_value(key)),
				func(value: float) -> void:
					if _refreshing:
						return
					MovementConfig.set_value(key, value))
		_movement_sliders[key] = widgets2


func _build_session_section(root: Control) -> void:
	_add_header(root, "Session")
	var reset_duel := Button.new()
	reset_duel.text = "Reset duel"
	reset_duel.pressed.connect(func() -> void:
		GameManager.reset_current_duel())
	root.add_child(reset_duel)

	var menu_button := Button.new()
	menu_button.text = "Back to main menu"
	menu_button.pressed.connect(func() -> void:
		if use_vr and _open_in_vr:
			_toggle_vr()
		elif panel.visible:
			panel.visible = false
		GameManager.go_to_menu())
	root.add_child(menu_button)


# -- Presets -------------------------------------------------------------------

func _on_preset_save() -> void:
	var name_text := _preset_name_edit.text.strip_edges()
	if name_text.is_empty() and _preset_option.selected >= 0:
		name_text = _preset_option.get_item_text(_preset_option.selected)
	if name_text.is_empty():
		return
	if DebugPresets.save_preset(name_text):
		_preset_name_edit.text = ""
		_refresh_preset_list()


func _on_preset_load() -> void:
	if _preset_option.selected < 0:
		return
	var name_text := _preset_option.get_item_text(_preset_option.selected)
	if DebugPresets.load_preset(name_text):
		_refresh_from_systems()


func _on_preset_delete() -> void:
	if _preset_option.selected < 0:
		return
	var name_text := _preset_option.get_item_text(_preset_option.selected)
	if DebugPresets.delete_preset(name_text):
		_refresh_preset_list()


func _refresh_preset_list() -> void:
	_preset_option.clear()
	var names := DebugPresets.list_presets()
	var select_idx := -1
	for i in names.size():
		_preset_option.add_item(names[i])
		if names[i] == DebugPresets.active:
			select_idx = i
	if select_idx >= 0:
		_preset_option.selected = select_idx
	elif names.size() > 0:
		_preset_option.selected = 0


func _refresh_from_systems() -> void:
	_refreshing = true
	if _mode_option != null:
		_mode_option.selected = TimeManager.mode
	for property in _slowmo_sliders:
		var widgets: Dictionary = _slowmo_sliders[property]
		var value: float = TimeManager.get(property)
		widgets["slider"].value = value
		widgets["label"].text = "%.2f" % value
	if _bullet_slider != null:
		_bullet_slider.value = GameManager.tuning["bullet_speed"]
		_bullet_value.text = "%.2f" % GameManager.tuning["bullet_speed"]
	if _ai_slider != null:
		_ai_slider.value = GameManager.tuning["ai_speed_mult"]
		_ai_value.text = "%.2f" % GameManager.tuning["ai_speed_mult"]
	if _auto_cock != null:
		_auto_cock.button_pressed = GameManager.tuning["auto_cock"]
	for key in _reload_sliders:
		var rwidgets: Dictionary = _reload_sliders[key]
		var rvalue: float = float(GameManager.tuning[key])
		rwidgets["slider"].value = rvalue
		rwidgets["label"].text = "%.2f" % rvalue
	if _reload_volume_toggle != null:
		_reload_volume_toggle.button_pressed = show_reload_volumes
	if _holster_side_option != null:
		_holster_side_option.selected = int(GameManager.tuning["holster_side"])
	for key in _release_sliders:
		var rel_widgets: Dictionary = _release_sliders[key]
		var rel_value: float = float(GameManager.tuning[key])
		rel_widgets["slider"].value = rel_value
		rel_widgets["label"].text = "%.2f" % rel_value
	for key in _combat_sliders:
		var cwidgets: Dictionary = _combat_sliders[key]
		var cvalue: float = float(GameManager.tuning[key])
		cwidgets["slider"].value = cvalue
		cwidgets["label"].text = "%.2f" % cvalue
	for key in _movement_sliders:
		var mwidgets: Dictionary = _movement_sliders[key]
		var mvalue: float = float(MovementConfig.get_value(key))
		mwidgets["slider"].value = mvalue
		var step: float = mwidgets["slider"].step
		if step < 0.001:
			mwidgets["label"].text = "%.4f" % mvalue
		else:
			mwidgets["label"].text = "%.2f" % mvalue
	if _turn_mode_option != null:
		_turn_mode_option.selected = MovementConfig.turn_mode
	_refresh_preset_list()
	_refreshing = false


# -- Helpers -------------------------------------------------------------------

func _add_header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)


func _add_slider(parent: Control, label_text: String, min_value: float,
		max_value: float, step: float, initial: float, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 0)
	row.add_child(slider)

	var value_label := Label.new()
	if step < 0.001:
		value_label.text = "%.4f" % initial
	else:
		value_label.text = "%.2f" % initial
	value_label.custom_minimum_size = Vector2(46, 0)
	row.add_child(value_label)

	slider.value_changed.connect(func(value: float) -> void:
		if step < 0.001:
			value_label.text = "%.4f" % value
		else:
			value_label.text = "%.2f" % value
		on_change.call(value))

	return {"slider": slider, "label": value_label}
