class_name BulletTrail
extends MeshInstance3D
## Superhot-style visible trajectory: a glowing camera-facing ribbon that
## follows the bullet and lingers/fades after the bullet dies.

const GROUP := "bullet_trails"
const WIDTH := 0.02
const FADE_TIME := 1.6

var points := PackedVector3Array()
var _immediate := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _finished := false
var _fade_left := FADE_TIME
var _base_color := Color(1.0, 0.85, 0.35)


func _init() -> void:
	mesh = _immediate
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = _base_color
	material_override = _material
	top_level = true


func _ready() -> void:
	add_to_group(GROUP)
	global_transform = Transform3D.IDENTITY


func add_point(point: Vector3) -> void:
	points.append(point)


func finish() -> void:
	_finished = true


## Keep the ribbon alive longer (e.g. during kill-cam). Real-time seconds.
func extend_fade(seconds: float) -> void:
	_fade_left = maxf(_fade_left, seconds)


static func extend_all_fades(seconds: float) -> void:
	if Engine.get_main_loop() is SceneTree:
		for trail in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
			if trail.has_method("extend_fade"):
				trail.extend_fade(seconds)


func _process(delta: float) -> void:
	if _finished:
		# Fade in real time so the trail lingers correctly during slow-mo.
		_fade_left -= delta / maxf(Engine.time_scale, 0.001)
		if _fade_left <= 0.0:
			queue_free()
			return
		_material.albedo_color = Color(_base_color, clampf(_fade_left / FADE_TIME, 0.0, 1.0))
	_rebuild_ribbon()


func _rebuild_ribbon() -> void:
	_immediate.clear_surfaces()
	if points.size() < 2:
		return
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3.UP * 1.7
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var point := points[i]
		var forward: Vector3
		if i < points.size() - 1:
			forward = points[i + 1] - point
		else:
			forward = point - points[i - 1]
		var to_eye := (eye - point).normalized()
		var side := forward.cross(to_eye).normalized()
		if not side.is_finite() or side.is_zero_approx():
			side = Vector3.UP
		var half := side * WIDTH * 0.5
		_immediate.surface_add_vertex(point - half)
		_immediate.surface_add_vertex(point + half)
	_immediate.surface_end()


static func clear_all() -> void:
	if Engine.get_main_loop() is SceneTree:
		for trail in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
			trail.queue_free()
