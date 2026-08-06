extends Node
## Autoload. Live player locomotion tunables for Flat and VR, editable from the
## debug menu and persisted to user://movement.cfg. Named debug presets also
## snapshot these values via DebugPresets.

signal changed(key: String, value: Variant)

enum TurnMode { OFF, SMOOTH, SNAP }

const CONFIG_PATH := "user://movement.cfg"

const KEYS := [
	"walk_speed", "mouse_sensitivity", "lean_angle", "lean_offset",
	"vr_move_speed", "stick_deadzone", "turn_mode",
	"smooth_turn_speed", "snap_turn_angle", "turn_deadzone",
]

var walk_speed := 2.2
var mouse_sensitivity := 0.0025
var lean_angle := 12.0
var lean_offset := 0.35
var vr_move_speed := 2.2
var stick_deadzone := 0.15
var turn_mode: int = TurnMode.SMOOTH
var smooth_turn_speed := 90.0
var snap_turn_angle := 45.0
var turn_deadzone := 0.5


func _ready() -> void:
	_load_config()


func set_value(key: String, value: Variant) -> void:
	if key not in KEYS:
		return
	set(key, value)
	changed.emit(key, value)
	_save_config()


func get_value(key: String) -> Variant:
	return get(key)


func to_dict() -> Dictionary:
	var out := {}
	for key in KEYS:
		out[key] = get(key)
	return out


func apply_dict(data: Dictionary) -> void:
	for key in KEYS:
		if data.has(key):
			set(key, data[key])
			changed.emit(key, data[key])
	_save_config()


func _save_config() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("movement", key, get(key))
	cfg.save(CONFIG_PATH)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for key in KEYS:
		set(key, cfg.get_value("movement", key, get(key)))
