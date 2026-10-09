extends Node
## Autoload, listed FIRST in project.godot so its script is the oldest GDScript
## in the process. Works around a Godot 4.7 use-after-free at exit (BUG-020):
## GDScriptLanguage::finish() walks its script list newest-first, reads the
## next entry, then drops its Ref to the current script. If that frees a script
## the current one owned (a preloaded scene's script, an inner class), the next
## read is freed memory and the process segfaults after a clean run.
##
## On exit this pins every loaded script in a static var. Nothing can then free
## mid-walk until finish() reaches this script last and clears its statics.
## Fixed upstream after 4.7 (finish() copies the list first); drop this then.

static var _pinned: Array[Script] = []


func _exit_tree() -> void:
	_pinned.append(get_script())
	_pin_dir("res://")


func _pin_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_pin_dir(dir_path.path_join(sub))
	for file in dir.get_files():
		# Exported builds list compiled scripts as `<name>.gd.remap`.
		var path := dir_path.path_join(file.trim_suffix(".remap"))
		if path.get_extension() == "gd" and ResourceLoader.has_cached(path):
			var script := load(path) as Script
			if script != null:
				_pinned.append(script)
