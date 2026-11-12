extends Node
## Autoload. Kill-cam consumer for DuelManager.kill_cam_requested.
## Flat: temporary Camera3D flies along the killing bullet trail.
## VR: spectator XROrigin3D ride (player rig stays put); TimeManager slow-mo.
## Both: `ScreenOverlay` iris wipes the cut in and out (kill cam only, not the replay).
## Plays locally in SP and 1v1 MP from synced trail points.

signal finished

const SIDE_OFFSET := 0.55
const HEIGHT_BIAS := 0.35
const LOOK_AHEAD := 0.08

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
var _iris_closing := false


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
	_iris_closing = false

	TimeManager.notify_kill_cam()
	BulletTrail.extend_all_fades(_duration + 0.4)

	if GameManager.is_vr:
		_start_vr_camera()
	else:
		_start_flat_camera()

	# Shut in the frame the camera swaps, so the cut never shows.
	ScreenOverlay.iris_shut()
	ScreenOverlay.iris_open(_iris_time())
	set_process(true)


func _process(delta: float) -> void:
	if not is_playing or get_tree().paused:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_elapsed += real_delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)

	if is_instance_valid(_camera):
		_update_flat_camera(t)
	if is_instance_valid(_spectator):
		_place_vr_origin(t)

	var iris_time := _iris_time()
	if not _iris_closing and t >= 1.0 - iris_time / _duration:
		_iris_closing = true
		ScreenOverlay.iris_close(iris_time)

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
	_scene_parent().add_child(_spectator)
	_place_vr_origin(0.0)

	rig.current = false
	rig.camera.current = false
	_spectator.current = true
	_spectator_cam.current = true


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


## Kept to half the clip, so a long wipe cannot close before it has opened.
func _iris_time() -> float:
	return minf(float(GameManager.tuning["iris_time"]), _duration * 0.5)


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
	if DeathCam.wants_camera():
		DeathCam.take_camera(_camera, _restore_camera, _spectator, _spectator_cam,
				_restore_origin, _restore_xr_camera, _hmd_ref, _hmd_ref_valid)
		_camera = null
		_restore_camera = null
		_spectator = null
		_spectator_cam = null
		_restore_origin = null
		_restore_xr_camera = null
		_hmd_ref_valid = false
		set_process(false)
		_trail = PackedVector3Array()
		is_playing = false
	else:
		_teardown()
	# The overlay is on whichever camera is current now, so this opens on the next view.
	ScreenOverlay.iris_open(_iris_time())
	finished.emit()


## Abort mid-sequence (menu / mode change). Does not emit finished.
func cancel() -> void:
	if not is_playing:
		return
	_teardown()
	ScreenOverlay.reset()
	for connection in finished.get_connections():
		finished.disconnect(connection["callable"])


func _teardown() -> void:
	set_process(false)
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
