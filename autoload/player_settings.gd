extends Node
## Autoload. Player-facing settings persisted to user://settings.cfg.
## Movement knobs stay on MovementConfig; holster side stays in GameManager.tuning.

const CONFIG_PATH := "user://settings.cfg"

enum WindowModeSetting { WINDOWED, BORDERLESS, EXCLUSIVE }

signal binds_changed
signal listen_cancelled
signal vr_source_captured(source: String)

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

## Logical VR combat actions → OpenXR / synthetic source strings.
const VR_ACTIONS: Array[StringName] = [
	&"fire", &"grip", &"cock", &"trick_shot", &"gate",
]

## Flat InputMap actions that players may remap.
const FLAT_ACTIONS: Array[StringName] = [
	&"fire", &"draw_toggle", &"cock_hammer", &"reload",
]

const VR_SOURCES: Array[String] = [
	"trigger_click",
	"grip_click",
	"ax_button",
	"by_button",
	"primary_click",
	"stick_down",
]

const VR_HOLD_ACTIONS: Array[StringName] = [&"fire", &"grip", &"trick_shot"]
const VR_EDGE_ACTIONS: Array[StringName] = [&"cock", &"gate"]

const DEFAULT_VR_BINDS := {
	"fire": "trigger_click",
	"grip": "grip_click",
	"cock": "stick_down",
	"trick_shot": "ax_button",
	"gate": "by_button",
}

const VR_SOURCE_LABELS := {
	"trigger_click": "Trigger",
	"grip_click": "Grip",
	"ax_button": "A / X",
	"by_button": "B / Y",
	"primary_click": "Stick Click",
	"stick_down": "Stick Down",
}

const FLAT_ACTION_LABELS := {
	"fire": "Fire",
	"draw_toggle": "Draw / Holster",
	"cock_hammer": "Cock",
	"reload": "Reload",
}

const VR_ACTION_LABELS := {
	"fire": "Fire",
	"grip": "Grip",
	"cock": "Cock",
	"trick_shot": "Trick Shot",
	"gate": "Gate",
}

var master_volume := 1.0
var window_mode: int = WindowModeSetting.WINDOWED
var window_width := 1280
var window_height := 720

## action StringName → source string (VR) or encoded event string (flat).
var vr_binds: Dictionary = {}
var flat_binds: Dictionary = {}

## While non-empty, Settings is waiting for a new bind for this action.
var listen_action: StringName = &""
var listen_is_vr := false


func _ready() -> void:
	_reset_binds_to_defaults(false)
	_load_config()
	apply_audio()
	apply_binds()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	_save_config()


func set_window_mode(mode: int) -> void:
	window_mode = clampi(mode, 0, WindowModeSetting.EXCLUSIVE)
	apply_window()
	_save_config()


func set_resolution(size: Vector2i) -> void:
	window_width = maxi(size.x, 640)
	window_height = maxi(size.y, 360)
	apply_window()
	_save_config()


func apply_display(mode: int, size: Vector2i) -> void:
	window_mode = clampi(mode, 0, WindowModeSetting.EXCLUSIVE)
	window_width = maxi(size.x, 640)
	window_height = maxi(size.y, 360)
	apply_window()
	_save_config()


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if master_volume <= 0.0:
		AudioServer.set_bus_volume_db(bus, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))


func apply_window() -> void:
	if not _can_apply_window():
		return
	var win := get_window()
	if win == null:
		return
	match window_mode:
		WindowModeSetting.BORDERLESS:
			win.mode = Window.MODE_FULLSCREEN
		WindowModeSetting.EXCLUSIVE:
			win.mode = Window.MODE_WINDOWED
			win.size = Vector2i(window_width, window_height)
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			_apply_window_size()
			_apply_window_size.call_deferred()


func resolution_choices() -> Array[Vector2i]:
	var screen := Vector2i(1920, 1080)
	if _can_query_display():
		screen = DisplayServer.screen_get_size()
		if screen.x < 640 or screen.y < 360:
			screen = Vector2i(1920, 1080)
	var seen := {}
	var out: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	candidates.append_array(RESOLUTION_PRESETS)
	candidates.append(screen)
	candidates.append(Vector2i(window_width, window_height))
	for size in candidates:
		if size.x < 640 or size.y < 360:
			continue
		if size.x > screen.x or size.y > screen.y:
			continue
		var key := "%dx%d" % [size.x, size.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(size)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


# -- Binds ---------------------------------------------------------------------

func get_vr_bind(action: StringName) -> String:
	return str(vr_binds.get(String(action), DEFAULT_VR_BINDS.get(String(action), "")))


func get_flat_bind_event(action: StringName) -> InputEvent:
	var encoded := str(flat_binds.get(String(action), ""))
	if encoded.is_empty():
		return _default_flat_event(action)
	return _decode_flat_event(encoded)


func vr_action_label(action: StringName) -> String:
	return str(VR_ACTION_LABELS.get(String(action), String(action)))


func flat_action_label(action: StringName) -> String:
	return str(FLAT_ACTION_LABELS.get(String(action), String(action)))


func vr_source_label(source: String) -> String:
	return str(VR_SOURCE_LABELS.get(source, source))


func flat_event_label(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	return event.as_text()


func is_vr_hold_action(action: StringName) -> bool:
	return action in VR_HOLD_ACTIONS


func is_vr_edge_action(action: StringName) -> bool:
	return action in VR_EDGE_ACTIONS


func vr_uses_stick_down() -> bool:
	for action in VR_ACTIONS:
		if get_vr_bind(action) == "stick_down":
			return true
	return false


func vr_action_for_source(source: String) -> StringName:
	for action in VR_ACTIONS:
		if get_vr_bind(action) == source:
			return action
	return &""


func begin_listen(action: StringName, is_vr: bool) -> void:
	listen_action = action
	listen_is_vr = is_vr


func cancel_listen() -> void:
	if listen_action == &"":
		return
	listen_action = &""
	listen_is_vr = false
	listen_cancelled.emit()


func is_listening() -> bool:
	return listen_action != &""


## Called by VRRig while Settings is capturing. Returns true if consumed.
func try_capture_vr_source(source: String) -> bool:
	if not is_listening() or not listen_is_vr:
		return false
	if source not in VR_SOURCES:
		return false
	var action := listen_action
	listen_action = &""
	listen_is_vr = false
	set_vr_bind(action, source)
	vr_source_captured.emit(source)
	return true


## Called while Settings is capturing a flat bind. Returns true if consumed.
func try_capture_flat_event(event: InputEvent) -> bool:
	if not is_listening() or listen_is_vr:
		return false
	if not _is_legal_flat_rebind(event):
		return false
	var action := listen_action
	listen_action = &""
	listen_is_vr = false
	set_flat_bind(action, event)
	return true


func set_vr_bind(action: StringName, source: String) -> void:
	if action not in VR_ACTIONS or source not in VR_SOURCES:
		return
	var key := String(action)
	var previous := get_vr_bind(action)
	if previous == source:
		_save_config()
		binds_changed.emit()
		return
	var conflict := vr_action_for_source(source)
	vr_binds[key] = source
	if conflict != &"" and conflict != action:
		vr_binds[String(conflict)] = previous
	apply_binds()
	_save_config()
	binds_changed.emit()


func set_flat_bind(action: StringName, event: InputEvent) -> void:
	if action not in FLAT_ACTIONS:
		return
	if not _is_legal_flat_rebind(event):
		return
	var key := String(action)
	var encoded := _encode_flat_event(event)
	var previous := str(flat_binds.get(key, ""))
	if previous == encoded:
		apply_binds()
		_save_config()
		binds_changed.emit()
		return
	var conflict := _flat_action_for_encoded(encoded)
	flat_binds[key] = encoded
	if conflict != &"" and conflict != action:
		flat_binds[String(conflict)] = previous
	apply_binds()
	_save_config()
	binds_changed.emit()


func reset_binds() -> void:
	cancel_listen()
	_reset_binds_to_defaults(true)
	apply_binds()
	_save_config()
	binds_changed.emit()


func apply_binds() -> void:
	for action in FLAT_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var event := get_flat_bind_event(action)
		if event != null:
			InputMap.action_add_event(action, event)


func _reset_binds_to_defaults(overwrite: bool) -> void:
	if overwrite or vr_binds.is_empty():
		vr_binds = DEFAULT_VR_BINDS.duplicate()
	if overwrite or flat_binds.is_empty():
		flat_binds = {}
		for action in FLAT_ACTIONS:
			flat_binds[String(action)] = _encode_flat_event(_default_flat_event(action))


func _default_flat_event(action: StringName) -> InputEvent:
	match action:
		&"fire":
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			return mb
		&"draw_toggle":
			var mb2 := InputEventMouseButton.new()
			mb2.button_index = MOUSE_BUTTON_RIGHT
			return mb2
		&"cock_hammer":
			var key := InputEventKey.new()
			key.physical_keycode = KEY_SPACE
			return key
		&"reload":
			var key2 := InputEventKey.new()
			key2.physical_keycode = KEY_R
			return key2
	return null


func _encode_flat_event(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % int(code)
	return ""


func _decode_flat_event(encoded: String) -> InputEvent:
	if encoded.begins_with("mouse:"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(encoded.get_slice(":", 1)) as MouseButton
		return mb
	if encoded.begins_with("key:"):
		var key := InputEventKey.new()
		key.physical_keycode = int(encoded.get_slice(":", 1)) as Key
		return key
	return null


func _flat_action_for_encoded(encoded: String) -> StringName:
	for action in FLAT_ACTIONS:
		if str(flat_binds.get(String(action), "")) == encoded:
			return action
	return &""


func _is_legal_flat_rebind(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var btn := (event as InputEventMouseButton).button_index
		return btn == MOUSE_BUTTON_LEFT or btn == MOUSE_BUTTON_RIGHT or btn == MOUSE_BUTTON_MIDDLE
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE or code == KEY_F3:
			return false
		# Reject WASD / lean defaults so locomotion stays intact.
		if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]:
			return false
		return true
	return false


func _apply_window_size() -> void:
	var win := get_window()
	if win == null or window_mode == WindowModeSetting.BORDERLESS:
		return
	var size := Vector2i(window_width, window_height)
	win.size = size
	var screen_id := win.current_screen
	var screen_pos := DisplayServer.screen_get_position(screen_id)
	var screen_size := DisplayServer.screen_get_size(screen_id)
	win.position = screen_pos + (screen_size - size) / 2


func _can_apply_window() -> bool:
	if GameManager.is_vr:
		return false
	return _can_query_display()


func _can_query_display() -> bool:
	if OS.has_feature("headless"):
		return false
	return DisplayServer.get_name() != "headless"


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "window_width", window_width)
	cfg.set_value("video", "window_height", window_height)
	for action in VR_ACTIONS:
		cfg.set_value("binds", "vr_%s" % String(action), get_vr_bind(action))
	for action in FLAT_ACTIONS:
		cfg.set_value("binds", "flat_%s" % String(action),
				str(flat_binds.get(String(action), _encode_flat_event(_default_flat_event(action)))))
	cfg.save(CONFIG_PATH)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	window_mode = clampi(int(cfg.get_value("video", "window_mode", window_mode)), 0, WindowModeSetting.EXCLUSIVE)
	window_width = maxi(int(cfg.get_value("video", "window_width", window_width)), 640)
	window_height = maxi(int(cfg.get_value("video", "window_height", window_height)), 360)
	for action in VR_ACTIONS:
		var loaded := str(cfg.get_value("binds", "vr_%s" % String(action), get_vr_bind(action)))
		if loaded in VR_SOURCES:
			vr_binds[String(action)] = loaded
	_ensure_unique_vr_binds()
	for action in FLAT_ACTIONS:
		var encoded := str(cfg.get_value("binds", "flat_%s" % String(action),
				str(flat_binds.get(String(action), ""))))
		var event := _decode_flat_event(encoded)
		if event != null and _is_legal_flat_rebind(event):
			flat_binds[String(action)] = encoded
	_ensure_unique_flat_binds()


func _ensure_unique_vr_binds() -> void:
	var used := {}
	for action in VR_ACTIONS:
		var source := get_vr_bind(action)
		if used.has(source) or source not in VR_SOURCES:
			source = str(DEFAULT_VR_BINDS[String(action)])
			# If default also taken, pick first free source.
			if used.has(source):
				for candidate in VR_SOURCES:
					if not used.has(candidate):
						source = candidate
						break
			vr_binds[String(action)] = source
		used[source] = true


func _ensure_unique_flat_binds() -> void:
	var used := {}
	for action in FLAT_ACTIONS:
		var encoded := str(flat_binds.get(String(action), ""))
		if encoded.is_empty() or used.has(encoded):
			encoded = _encode_flat_event(_default_flat_event(action))
			if used.has(encoded):
				# Fall back to unused mouse/key slot — should not happen with defaults.
				for candidate_action in FLAT_ACTIONS:
					var candidate := _encode_flat_event(_default_flat_event(candidate_action))
					if not used.has(candidate):
						encoded = candidate
						break
			flat_binds[String(action)] = encoded
		used[encoded] = true
