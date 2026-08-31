@tool
extends EditorExportPlugin
## Steam looks for steam_appid.txt beside the executable during editor/dev
## launches. Valve does not want this file on a real Steam depot; for Spacewar
## 480 test zips it is required. Android exports are skipped.

func _get_name() -> String:
	return "gunslinger_steam_export"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	var os := platform.get_os_name()
	return os == "Windows" or os == "Linux" or os == "macOS"


func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	if path.is_empty():
		return
	var from := ProjectSettings.globalize_path("res://steam_appid.txt")
	if not FileAccess.file_exists(from):
		push_warning("gunslinger_steam_export: missing res://steam_appid.txt")
		return
	var dest_dir := path.get_base_dir()
	if dest_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var to := dest_dir.path_join("steam_appid.txt")
	var err := DirAccess.copy_absolute(from, to)
	if err != OK:
		push_warning("gunslinger_steam_export: could not copy steam_appid.txt (%s)" % error_string(err))
	else:
		print("gunslinger_steam_export: wrote %s" % to)
