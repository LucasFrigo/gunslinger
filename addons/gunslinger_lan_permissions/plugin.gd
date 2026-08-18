@tool
extends EditorPlugin
## Registers the export hook that stamps LAN permissions into the Quest APK.

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = preload("res://addons/gunslinger_lan_permissions/export_plugin.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
