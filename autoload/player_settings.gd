extends Node
## Autoload. Player-facing settings persisted to user://settings.cfg.
## Movement knobs stay on MovementConfig; holster side stays in GameManager.tuning.

const CONFIG_PATH := "user://settings.cfg"

enum WindowModeSetting { WINDOWED, BORDERLESS, EXCLUSIVE }

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var master_volume := 1.0
var window_mode: int = WindowModeSetting.WINDOWED
var window_width := 1280
var window_height := 720


func _ready() -> void:
	_load_config()
	apply_audio()


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
	cfg.save(CONFIG_PATH)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	window_mode = clampi(int(cfg.get_value("video", "window_mode", window_mode)), 0, WindowModeSetting.EXCLUSIVE)
	window_width = maxi(int(cfg.get_value("video", "window_width", window_width)), 640)
	window_height = maxi(int(cfg.get_value("video", "window_height", window_height)), 360)
