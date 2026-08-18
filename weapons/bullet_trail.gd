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
var _side_ref := Vector3.ZERO


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
	var count := points.size()
	if count < 2:
		return
	var camera := get_viewport().get_camera_3d()
	var eye := Vector3.UP * 1.7
	var cam_up := Vector3.UP
	if camera != null:
		eye = camera.global_position
		cam_up = camera.global_transform.basis.y

	# One side vector for the whole strip. Per-vertex `forward.cross(to_eye)`
	# flips along the shot (especially when looking down the barrel, where
	# far points make to_eye ≈ -forward) and folds the ribbon into a V.
	var chord := points[count - 1] - points[0]
	if chord.length_squared() < 0.0000001:
		return
	var forward := chord.normalized()
	# Un-normalized eye offset: |forward × (eye - p)| is the camera's
	# distance to the shot line, so far vertices stay well-defined.
	var side := forward.cross(eye - points[0])
	if side.length_squared() < 0.0001:
		side = forward.cross(cam_up)
	if side.length_squared() < 0.0001:
		side = forward.cross(Vector3.RIGHT)
	if not side.is_finite() or side.is_zero_approx():
		return
	side = side.normalized()
	if _side_ref.dot(side) < 0.0:
		side = -side
	_side_ref = side

	var half := side * (WIDTH * 0.5)
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in count:
		var point := points[i]
		_immediate.surface_add_vertex(point - half)
		_immediate.surface_add_vertex(point + half)
	_immediate.surface_end()


static func clear_all() -> void:
	if Engine.get_main_loop() is SceneTree:
		for trail in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
			trail.queue_free()
