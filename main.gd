extends Node3D
## Boot scene. Decides between VR (OpenXR) and flat desktop mode, then hands
## everything over to the GameManager autoload.

@onready var world_root: Node3D = $WorldRoot


func _ready() -> void:
	var use_vr := _try_init_xr()
	print("Gunslinger: starting in %s mode" % ("VR" if use_vr else "FLAT"))
	GameManager.setup(self, use_vr)
	_maybe_start_autotest()


## Headless CI/dev smoke tests: `godot --headless -- --autotest=duel|gauntlet|host|join`
func _maybe_start_autotest() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest"):
			var autotest: Node = load("res://dev/autotest.gd").new()
			autotest.name = "Autotest"
			add_child(autotest)
			return


func _try_init_xr() -> bool:
	if _flat_forced():
		print("Gunslinger: flat mode forced (--flat or 'flat' export feature)")
		return false
	var xr := XRServer.find_interface("OpenXR")
	if xr == null:
		return false
	if not xr.is_initialized() and not xr.initialize():
		return false
	get_viewport().use_xr = true
	# The XR runtime paces frames; engine vsync would fight it.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	return true


func _flat_forced() -> bool:
	if OS.has_feature("flat"):
		return true
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return "--flat" in args
