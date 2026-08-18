@tool
extends EditorExportPlugin
## Gradle export hook. Godot's Export dialog rewrites export_presets.cfg from
## its checkboxes, which has dropped INTERNET on re-export and left Quest
## unable to open UDP sockets ("Can't create"). These uses-permission tags
## are merged into AndroidManifest.xml regardless of those checkboxes.

func _get_name() -> String:
	return "gunslinger_lan_permissions"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform.get_os_name() == "Android"


func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return """
	<uses-permission android:name="android.permission.INTERNET" />
	<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
	<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
	<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
	"""
