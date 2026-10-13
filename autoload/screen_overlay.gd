extends Node
## Autoload. One quad drawn over each eye (`ui/screen_overlay.gdshader`): the kill-cam
## iris wipe and the red hurt vignette, in flat and VR. Local and cosmetic, never on the wire.
## Idle, the quad is parked and hidden under this node. While an effect runs it rides the
## current camera, so a kill's red carries onto the kill-cam camera.

const SHADER := preload("res://ui/screen_overlay.gdshader")
## Iris radius (tangent off the eye axis) that clears every corner of a headset view.
const IRIS_OPEN := 4.0
## Drawn after world transparents (smoke, trails, flashes sit at 0; a remote avatar at 1),
## so a shut iris covers them. The quad has no depth test, so it also covers the opaque
## 3D UI panels; it is only ever up for the kill cam and a hurt fade.
const RENDER_PRIORITY := 100
const WOUND_FADE := 0.35
const KILL_FADE := 0.6

var _quad: MeshInstance3D
var _material: ShaderMaterial
var _hurt := 0.0
var _iris := IRIS_OPEN
var _hurt_tween: Tween
var _iris_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the camera swaps of the same frame (KillCam, DeathCam), so the quad follows them.
	process_priority = 100
	set_process(false)
	PlayerSettings.screen_effects_changed.connect(_on_screen_effects_changed)
	_ensure_quad()


## Peak is the higher of the running vignette and `strength`, then it fades to 0.
func hurt(strength: float, fade: float) -> void:
	if not PlayerSettings.screen_effects_enabled:
		return
	_kill_tween(_hurt_tween)
	_set_hurt(maxf(_hurt, clampf(strength, 0.0, 1.0)))
	_hurt_tween = _new_tween()
	_hurt_tween.tween_method(_set_hurt, _hurt, 0.0, maxf(fade, 0.01))


## Snap shut, in the same frame as the camera swap it hides.
func iris_shut() -> void:
	if not PlayerSettings.screen_effects_enabled:
		return
	_kill_tween(_iris_tween)
	_set_iris(0.0)


func iris_close(time: float) -> void:
	if not PlayerSettings.screen_effects_enabled:
		return
	_tween_iris(0.0, time, Tween.EASE_OUT)


## Always runs, so an iris left shut when the setting went off still ends open.
func iris_open(time: float) -> void:
	_tween_iris(IRIS_OPEN, time, Tween.EASE_IN)


## Abort paths: iris open, vignette clear, quad parked.
func reset() -> void:
	_kill_tween(_hurt_tween)
	_kill_tween(_iris_tween)
	_set_hurt(0.0)
	_set_iris(IRIS_OPEN)


func hurt_level() -> float:
	return _hurt


func iris_level() -> float:
	return _iris


func is_active() -> bool:
	return _hurt > 0.0 or _iris < IRIS_OPEN


## A fresh overlay quad with its own material, for `ImpactFeedback` to draw once at boot.
func make_quad() -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = RENDER_PRIORITY
	var quad := MeshInstance3D.new()
	quad.name = "ScreenOverlayQuad"
	quad.mesh = mesh
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the quad, so it would be culled by where it really sits.
	quad.extra_cull_margin = 16384.0
	quad.ignore_occlusion_culling = true
	return quad


func _process(_delta: float) -> void:
	_sync()


func _tween_iris(target: float, time: float, easing: Tween.EaseType) -> void:
	_kill_tween(_iris_tween)
	if is_equal_approx(_iris, target):
		_set_iris(target)
		return
	# Quadratic so the radius spends its time inside the visible field, not out at 4.
	_iris_tween = _new_tween().set_trans(Tween.TRANS_QUAD).set_ease(easing)
	_iris_tween.tween_method(_set_iris, _iris, target, maxf(time, 0.01))


func _new_tween() -> Tween:
	var tween := create_tween()
	# Kill-cam slow-mo must not stretch the wipe.
	tween.set_ignore_time_scale(true)
	return tween


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _set_hurt(value: float) -> void:
	_hurt = value
	_ensure_quad()
	_material.set_shader_parameter(&"hurt", value)
	_sync()


func _set_iris(value: float) -> void:
	_iris = value
	_ensure_quad()
	_material.set_shader_parameter(&"iris", value)
	_sync()


## Show on the current camera while an effect runs, park and hide otherwise.
func _sync() -> void:
	_ensure_quad()
	if not is_active():
		_quad.visible = false
		if _quad.get_parent() != self:
			_quad.reparent(self, false)
		set_process(false)
		return
	set_process(true)
	var camera := _find_camera()
	if camera == null:
		_quad.visible = false
		return
	if _quad.get_parent() != camera:
		_quad.reparent(camera, false)
	_quad.visible = true


## The quad dies with a camera that is freed under it; the material outlives it, so the
## state carries over and the next `_sync` puts a new quad on the live camera.
func _ensure_quad() -> void:
	if is_instance_valid(_quad):
		return
	_quad = make_quad()
	if _material == null:
		_material = _quad.material_override as ShaderMaterial
		_material.set_shader_parameter(&"hurt", _hurt)
		_material.set_shader_parameter(&"iris", _iris)
	else:
		_quad.material_override = _material
	_quad.visible = false
	add_child(_quad)


## The camera that is current now, which is not the player's during the kill cam.
func _find_camera() -> Camera3D:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		return camera
	var player := GameManager.local_player
	if is_instance_valid(player) and is_instance_valid(player.rig):
		var rig_cam: Variant = player.rig.get("camera")
		if rig_cam is Camera3D:
			return rig_cam as Camera3D
	return null


func _on_screen_effects_changed() -> void:
	if not PlayerSettings.screen_effects_enabled:
		reset()
