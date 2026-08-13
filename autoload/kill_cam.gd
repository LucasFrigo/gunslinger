extends Node
## Autoload. SP-only kill-cam consumer for DuelManager.kill_cam_requested.
## Flat: temporary Camera3D flies along the killing bullet trail.
## VR: keeps the HMD; TimeManager slow-mo burst only.

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
	if NetworkManager.is_active():
		return

	is_playing = true
	_trail = trail_points.duplicate()
	_elapsed = 0.0
	_duration = maxf(TimeManager.kill_cam_duration, 0.5)

	TimeManager.notify_kill_cam()
	BulletTrail.extend_all_fades(_duration + 0.4)

	if not GameManager.is_vr:
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

	if t >= 1.0:
		_end()


func _start_flat_camera() -> void:
	_restore_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "KillCamCamera"
	_camera.fov = 55.0
	var parent: Node = GameManager.main_root if is_instance_valid(GameManager.main_root) else self
	parent.add_child(_camera)
	_update_flat_camera(0.0)
	_camera.current = true


func _update_flat_camera(t: float) -> void:
	var sample := _sample_trail(t)
	var ahead := _sample_trail(minf(t + LOOK_AHEAD, 1.0))
	var tangent := ahead - sample
	if tangent.length_squared() < 0.0001:
		tangent = _trail[_trail.size() - 1] - _trail[0]
	tangent = tangent.normalized()
	var side := tangent.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var eye := sample + side * SIDE_OFFSET + Vector3.UP * HEIGHT_BIAS
	var target := ahead + Vector3.UP * 0.15
	_camera.global_position = eye
	if eye.distance_squared_to(target) > 0.0001:
		_camera.look_at(target, Vector3.UP)


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
	set_process(false)
	if is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
		_camera = null
	if is_instance_valid(_restore_camera):
		_restore_camera.current = true
	_restore_camera = null
	_trail = PackedVector3Array()
	is_playing = false
	finished.emit()


## Abort mid-sequence (menu / mode change). Does not emit finished.
func cancel() -> void:
	if not is_playing:
		return
	set_process(false)
	if is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
		_camera = null
	if is_instance_valid(_restore_camera):
		_restore_camera.current = true
	_restore_camera = null
	_trail = PackedVector3Array()
	is_playing = false
	for connection in finished.get_connections():
		finished.disconnect(connection["callable"])
