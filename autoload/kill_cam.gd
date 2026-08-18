extends Node
## Autoload. Kill-cam consumer for DuelManager.kill_cam_requested.
## Flat: temporary Camera3D flies along the killing bullet trail.
## VR: spectator XROrigin3D ride (player rig stays put); TimeManager slow-mo.
## Plays locally in SP and 1v1 MP from synced trail points.

signal finished

const SIDE_OFFSET := 0.55
const HEIGHT_BIAS := 0.35
const LOOK_AHEAD := 0.08
const FADE_TIME := 0.15
const FADE_SCENE := preload("res://addons/godot-xr-tools/effects/fade.tscn")

var is_playing := false

var _trail: PackedVector3Array = PackedVector3Array()
var _elapsed := 0.0
var _duration := 2.2
var _camera: Camera3D
var _restore_camera: Camera3D
var _spectator: XROrigin3D
var _spectator_cam: XRCamera3D
var _restore_origin: XROrigin3D
var _restore_xr_camera: XRCamera3D
var _hmd_ref := Transform3D.IDENTITY
var _hmd_ref_valid := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	call_deferred("_bind_duel")


func _bind_duel() -> void:
	var duel := GameManager.duel
	if duel == null:
		return
	if not duel.kill_cam_requested.is_connected(_on_kill_cam_requested):
		duel.kill_cam_requested.connect(_on_kill_cam_requested)


func _on_kill_cam_requested(trail_points: PackedVector3Array) -> void:
	if is_playing or trail_points.size() < 2:
		return

	is_playing = true
	_trail = trail_points.duplicate()
	_elapsed = 0.0
	_duration = maxf(TimeManager.kill_cam_duration, 0.5)

	TimeManager.notify_kill_cam()
	BulletTrail.extend_all_fades(_duration + 0.4)

	if GameManager.is_vr:
		_start_vr_camera()
	else:
		_start_flat_camera()

	set_process(true)


func _process(delta: float) -> void:
	if not is_playing:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_elapsed += real_delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)

	if is_instance_valid(_camera):
		_update_flat_camera(t)
	if is_instance_valid(_spectator):
		_place_vr_origin(t)
		_update_vr_fade(t)

	if t >= 1.0:
		_end()


func _start_flat_camera() -> void:
	_restore_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "KillCamCamera"
	_camera.fov = 55.0
	_scene_parent().add_child(_camera)
	_update_flat_camera(0.0)
	_camera.current = true


func _start_vr_camera() -> void:
	var rig := _player_vr_rig()
	if rig == null:
		return
	_restore_origin = rig
	_restore_xr_camera = rig.camera
	_hmd_ref = rig.camera.transform
	_hmd_ref_valid = true

	_spectator = XROrigin3D.new()
	_spectator.name = "KillCamOrigin"
	_spectator_cam = XRCamera3D.new()
	_spectator_cam.name = "XRCamera3D"
	_spectator.add_child(_spectator_cam)
	_spectator_cam.add_child(FADE_SCENE.instantiate())
	_scene_parent().add_child(_spectator)
	_place_vr_origin(0.0)

	rig.current = false
	rig.camera.current = false
	_spectator.current = true
	_spectator_cam.current = true
	_set_kill_cam_fade(1.0)


func _update_flat_camera(t: float) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.global_transform = _cinematic_eye(t)


func _place_vr_origin(t: float) -> void:
	if not is_instance_valid(_spectator) or not _hmd_ref_valid:
		return
	var desired := _cinematic_eye(t)
	_spectator.global_transform = (desired * _hmd_ref.inverse()).orthonormalized()


func _cinematic_eye(t: float) -> Transform3D:
	var sample := _sample_trail(t)
	var ahead := _sample_trail(minf(t + LOOK_AHEAD, 1.0))
	var tangent := ahead - sample
	if tangent.length_squared() < 0.0001:
		tangent = _trail[_trail.size() - 1] - _trail[0]
	if tangent.length_squared() < 0.0001:
		return Transform3D(Basis.IDENTITY, sample + Vector3.UP * HEIGHT_BIAS)
	tangent = tangent.normalized()
	var side := tangent.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var eye := sample + side * SIDE_OFFSET + Vector3.UP * HEIGHT_BIAS
	var target := ahead + Vector3.UP * 0.15
	var xform := Transform3D(Basis.IDENTITY, eye)
	if eye.distance_squared_to(target) > 0.0001:
		xform = xform.looking_at(target, Vector3.UP)
	return xform


func _update_vr_fade(t: float) -> void:
	var fade_span := FADE_TIME / maxf(_duration, 0.001)
	var alpha := 0.0
	if t < fade_span:
		alpha = 1.0 - t / fade_span
	elif t > 1.0 - fade_span:
		alpha = (t - (1.0 - fade_span)) / fade_span
	_set_kill_cam_fade(alpha)


func _set_kill_cam_fade(alpha: float) -> void:
	XRToolsFade.set_fade("kill_cam", Color(0.0, 0.0, 0.0, clampf(alpha, 0.0, 1.0)))


func _sample_trail(t: float) -> Vector3:
	if _trail.size() == 1:
		return _trail[0]
	var lengths: Array[float] = []
	var total := 0.0
	for i in range(1, _trail.size()):
		var seg := _trail[i].distance_to(_trail[i - 1])
		lengths.append(seg)
		total += seg
	if total <= 0.001:
		return _trail[_trail.size() - 1]
	var target := clampf(t, 0.0, 1.0) * total
	var walked := 0.0
	for i in lengths.size():
		var seg: float = lengths[i]
		if walked + seg >= target:
			var local_t := 0.0 if seg <= 0.0 else (target - walked) / seg
			return _trail[i].lerp(_trail[i + 1], local_t)
		walked += seg
	return _trail[_trail.size() - 1]


func _end() -> void:
	_teardown()
	finished.emit()


## Abort mid-sequence (menu / mode change). Does not emit finished.
func cancel() -> void:
	if not is_playing:
		return
	_teardown()
	for connection in finished.get_connections():
		finished.disconnect(connection["callable"])


func _teardown() -> void:
	set_process(false)
	_set_kill_cam_fade(0.0)
	if is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
	_camera = null
	if is_instance_valid(_restore_camera):
		_restore_camera.current = true
	_restore_camera = null
	if is_instance_valid(_spectator):
		_spectator.current = false
		if is_instance_valid(_spectator_cam):
			_spectator_cam.current = false
		_spectator.queue_free()
	_spectator = null
	_spectator_cam = null
	if is_instance_valid(_restore_origin):
		_restore_origin.current = true
	if is_instance_valid(_restore_xr_camera):
		_restore_xr_camera.current = true
	_restore_origin = null
	_restore_xr_camera = null
	_hmd_ref_valid = false
	_trail = PackedVector3Array()
	is_playing = false


func _scene_parent() -> Node:
	if is_instance_valid(GameManager.main_root):
		return GameManager.main_root
	return self


func _player_vr_rig() -> VRRig:
	var player := GameManager.local_player
	if player == null or not player.use_vr:
		return null
	return player.rig as VRRig
