extends Node
## Autoload. Named Save/Load/Delete snapshots of all debugger tunables:
## slow-mo (TimeManager), gunplay/AI (GameManager.tuning), and movement
## (MovementConfig). Live slider edits still write last-session cfg files;
## presets are explicit snapshots only.

const CONFIG_PATH := "user://debug_presets.cfg"

var _names: PackedStringArray = PackedStringArray()
var active := ""


func _ready() -> void:
	_load_meta()
	# Autoload order guarantees TimeManager / GameManager / MovementConfig
	# already ran _ready and loaded last-session configs.
	if not active.is_empty() and active in _names:
		load_preset(active)


func list_presets() -> PackedStringArray:
	return _names.duplicate()


func save_preset(preset_name: String) -> bool:
	var cleaned := _sanitize_name(preset_name)
	if cleaned.is_empty():
		return false
	var data := capture_dict()
	_write_preset_section(cleaned, data)
	if cleaned not in _names:
		_names.append(cleaned)
	active = cleaned
	_flush_meta()
	return true


func load_preset(preset_name: String) -> bool:
	var cleaned := _sanitize_name(preset_name)
	if cleaned.is_empty() or cleaned not in _names:
		return false
	var data := _read_preset_section(cleaned)
	if data.is_empty():
		return false
	apply_dict(data)
	active = cleaned
	_flush_meta()
	return true


func delete_preset(preset_name: String) -> bool:
	var cleaned := _sanitize_name(preset_name)
	if cleaned.is_empty() or cleaned not in _names:
		return false
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.erase_section("preset_%s" % cleaned)
	var idx := _names.find(cleaned)
	if idx >= 0:
		_names.remove_at(idx)
	if active == cleaned:
		active = ""
	_flush_meta_to(cfg)
	cfg.save(CONFIG_PATH)
	return true


func capture_dict() -> Dictionary:
	var slowmo := {"mode": TimeManager.mode}
	for property in TimeManager.TUNABLES:
		slowmo[property] = TimeManager.get(property)
	return {
		"slowmo": slowmo,
		"tuning": GameManager.tuning.duplicate(true),
		"movement": MovementConfig.to_dict(),
	}


func apply_dict(data: Dictionary) -> void:
	if data.has("slowmo") and data["slowmo"] is Dictionary:
		var slowmo: Dictionary = data["slowmo"]
		if slowmo.has("mode"):
			TimeManager.mode = int(slowmo["mode"])
		for property in TimeManager.TUNABLES:
			if slowmo.has(property):
				TimeManager.set_tunable(property, float(slowmo[property]))
	if data.has("tuning") and data["tuning"] is Dictionary:
		var tuning: Dictionary = data["tuning"]
		for key in GameManager.tuning:
			if tuning.has(key):
				GameManager.set_tuning(key, tuning[key])
	if data.has("movement") and data["movement"] is Dictionary:
		MovementConfig.apply_dict(data["movement"])


func _sanitize_name(preset_name: String) -> String:
	var cleaned := preset_name.strip_edges()
	# Keep filesystem / ConfigFile section-safe characters.
	var out := ""
	for i in cleaned.length():
		var ch := cleaned[i]
		var code := ch.unicode_at(0)
		var ok := (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
				or (code >= 48 and code <= 57) or ch == "_" or ch == "-" or ch == " "
		if ok:
			out += ch
	return out.strip_edges().replace(" ", "_")


func _write_preset_section(preset_name: String, data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	var section := "preset_%s" % preset_name
	if cfg.has_section(section):
		cfg.erase_section(section)
	var slowmo: Dictionary = data.get("slowmo", {})
	for key in slowmo:
		cfg.set_value(section, "slowmo/%s" % key, slowmo[key])
	var tuning: Dictionary = data.get("tuning", {})
	for key in tuning:
		cfg.set_value(section, "tuning/%s" % key, tuning[key])
	var movement: Dictionary = data.get("movement", {})
	for key in movement:
		cfg.set_value(section, "movement/%s" % key, movement[key])
	_flush_meta_to(cfg)
	cfg.save(CONFIG_PATH)


func _read_preset_section(preset_name: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return {}
	var section := "preset_%s" % preset_name
	if not cfg.has_section(section):
		return {}
	var slowmo := {}
	var tuning := {}
	var movement := {}
	for key in cfg.get_section_keys(section):
		var value = cfg.get_value(section, key)
		if key.begins_with("slowmo/"):
			slowmo[key.substr(7)] = value
		elif key.begins_with("tuning/"):
			tuning[key.substr(7)] = value
		elif key.begins_with("movement/"):
			movement[key.substr(9)] = value
	return {"slowmo": slowmo, "tuning": tuning, "movement": movement}


func _load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		_names = PackedStringArray()
		active = ""
		return
	_names = cfg.get_value("meta", "names", PackedStringArray())
	active = str(cfg.get_value("meta", "active", ""))


func _flush_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	_flush_meta_to(cfg)
	cfg.save(CONFIG_PATH)


func _flush_meta_to(cfg: ConfigFile) -> void:
	cfg.set_value("meta", "names", _names)
	cfg.set_value("meta", "active", active)
