extends Node
## Autoload. After a lethal hit the dead player orbits the corpse. The winner
## keeps control. Both then watch the replay: killer's eyes until the death,
## then the same corpse orbit. Fire / trigger skips the clip onto that orbit.
## In 1v1 either peer's skip applies to both.

signal trailing_started
signal skipped

enum Phase { IDLE, FLYING, ORBIT, PLAYBACK, TRAILING }

const ORBIT_RADIUS := 3.2
const ORBIT_PITCH := 0.28
const CLIP_WAIT := 8.0
const WORLD_MASK := 0b1000101

var phase: int = Phase.IDLE

var _hold := 0.0
var _yaw := 0.4
var _pitch := ORBIT_PITCH
var _radius := ORBIT_RADIUS
var _saved_yaw := 0.4
var _saved_pitch := ORBIT_PITCH
var _saved_radius := ORBIT_RADIUS
var _orbit_saved := false
var _trailing_emitted := false
var _play_t := 0.0
var _slow_start := 0.0
var _clip_end := 0.0

var _camera: Camera3D
var _restore_camera: Camera3D
var _spectator: XROrigin3D
var _spectator_cam: XRCamera3D
var _restore_origin: XROrigin3D
var _restore_xr_camera: XRCamera3D
var _hmd_ref := Transform3D.IDENTITY
var _hmd_ref_valid := false
var _replay_fx: Array[Node] = []
var _stashed: Array = []
var _sting: AudioStreamPlayer
var _sting_played := false
var _replay_label: Label3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func is_active() -> bool:
	return phase != Phase.IDLE


## The dead player is on the corpse orbit. The winner keeps their own camera
## except during the fly-along and the replay, which both watch.
func blocks_combat() -> bool:
	if phase == Phase.IDLE:
		return false
	if phase == Phase.FLYING or phase == Phase.PLAYBACK:
		return true
	return _local_is_victim()


## Drop remote pose packets while that body is being driven by the clip,
## and while the remote player is the corpse (their headset must not turn it).
func blocks_remote_pose() -> bool:
	if phase == Phase.IDLE:
		return false
	if phase == Phase.PLAYBACK:
		return true
	return not _local_is_victim()


## Freeze the local body into the recording. The winner stays live once the
## fly-along is over so their orbit-time movement can be sampled.
func locks_recorded_body() -> bool:
	if phase == Phase.IDLE:
		return false
	if phase == Phase.FLYING or phase == Phase.PLAYBACK:
		return true
	return _local_is_victim()


func blocks_look() -> bool:
	if phase == Phase.FLYING:
		return true
	return phase == Phase.PLAYBACK and not _in_replay_trail()


func consumes_look() -> bool:
	if get_tree().paused or GameManager.is_pause_open():
		return false
	if _in_replay_trail():
		return true
	if phase == Phase.ORBIT or phase == Phase.TRAILING:
		return _local_is_victim()
	return false


func can_skip() -> bool:
	if GameManager.is_pause_open():
		return false
	if phase == Phase.FLYING or phase == Phase.PLAYBACK:
		return true
	if phase == Phase.ORBIT:
		return _local_is_victim()
	return false


func wants_camera() -> bool:
	return phase == Phase.FLYING


func start_sequence() -> void:
	if phase != Phase.IDLE:
		return
	_trailing_emitted = false
	_orbit_saved = false
	_hold = 0.0
	set_process(true)
	if KillCam.is_playing:
		phase = Phase.FLYING
	else:
		_enter_orbit()


func take_camera(camera: Camera3D, restore_camera: Camera3D, spectator: XROrigin3D,
		spectator_cam: XRCamera3D, restore_origin: XROrigin3D, restore_xr_camera: XRCamera3D,
		hmd_ref: Transform3D, hmd_ref_valid: bool) -> void:
	_camera = camera
	_restore_camera = restore_camera
	_spectator = spectator
	_spectator_cam = spectator_cam
	_restore_origin = restore_origin
	_restore_xr_camera = restore_xr_camera
	_hmd_ref = hmd_ref
	_hmd_ref_valid = hmd_ref_valid
	if _local_is_victim():
		_enter_orbit()
		return
	# Winner keeps first person. Drop the fly-along camera.
	if is_instance_valid(camera):
		camera.current = false
		camera.queue_free()
	if is_instance_valid(restore_camera):
		restore_camera.current = true
	if is_instance_valid(spectator):
		spectator.current = false
		if is_instance_valid(spectator_cam):
			spectator_cam.current = false
		spectator.queue_free()
	if is_instance_valid(restore_origin):
		restore_origin.current = true
	if is_instance_valid(restore_xr_camera):
		restore_xr_camera.current = true
	_camera = null
	_restore_camera = null
	_spectator = null
	_spectator_cam = null
	_restore_origin = null
	_restore_xr_camera = null
	_hmd_ref_valid = false
	phase = Phase.ORBIT
	_hold = 0.0


func request_skip() -> void:
	if not can_skip():
		return
	ReplayBuffer.request_skip()


func skip_to_trailing() -> void:
	if phase != Phase.FLYING and phase != Phase.ORBIT and phase != Phase.PLAYBACK:
		return
	var show_banner := phase == Phase.FLYING and KillCam.is_playing
	if KillCam.is_playing:
		KillCam.cancel()
	_clear_replay_fx()
	if show_banner:
		skipped.emit()
	_enter_trailing()


func add_look(relative: Vector2) -> void:
	var sens: float = MovementConfig.mouse_sensitivity
	_yaw -= relative.x * sens
	# Same vertical sense as flat look: mouse up raises the view.
	_pitch = clampf(_pitch + relative.y * sens, -0.35, 1.15)


func add_stick(stick: Vector2, delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var speed := deg_to_rad(MovementConfig.smooth_turn_speed)
	_yaw -= stick.x * speed * real_delta
	_pitch = clampf(_pitch - stick.y * speed * real_delta, -0.35, 1.15)


func stop() -> void:
	_set_replay_tag(false)
	_stop_sting()
	if phase == Phase.IDLE and _camera == null and _spectator == null:
		_drop_listeners()
		return
	_clear_replay_fx()
	_release_actors()
	_teardown_camera()
	phase = Phase.IDLE
	_trailing_emitted = false
	_orbit_saved = false
	_stashed.clear()
	set_process(false)
	_drop_listeners()


func _drop_listeners() -> void:
	for connection in trailing_started.get_connections():
		trailing_started.disconnect(connection["callable"])
	for connection in skipped.get_connections():
		skipped.disconnect(connection["callable"])


func _process(delta: float) -> void:
	if phase == Phase.IDLE or get_tree().paused:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	match phase:
		Phase.FLYING:
			if not KillCam.is_playing:
				_enter_orbit()
		Phase.ORBIT:
			_hold += real_delta
			if _local_is_victim():
				_apply_orbit()
			var hold := _tune("death_cam_hold", 2.0)
			if _hold >= hold and ReplayBuffer.ready_to_play():
				_begin_playback()
			elif _hold >= hold and (ReplayBuffer.is_sealed or _hold >= hold + CLIP_WAIT):
				_enter_trailing()
		Phase.PLAYBACK:
			_advance_playback(real_delta)
		Phase.TRAILING:
			if _local_is_victim():
				_apply_orbit()


func _enter_orbit() -> void:
	phase = Phase.ORBIT
	_hold = 0.0
	if not _local_is_victim():
		_teardown_camera()
		return
	_ensure_camera()
	_seed_orbit_from_camera()
	_apply_orbit()


func _begin_playback() -> void:
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	_saved_radius = _radius
	_orbit_saved = true
	_stash_live()
	Bullet.clear_all()
	_sting_played = false
	phase = Phase.PLAYBACK
	_ensure_camera()
	_play_t = ReplayBuffer.clip_begin()
	_clip_end = ReplayBuffer.clip_end()
	var slow_seconds := _tune("replay_slow_seconds", 2.0)
	_slow_start = _clip_end - maxf(slow_seconds, 0.0)
	_apply_playback_frame(_play_t)
	_place_replay_view(_play_t)
	_set_replay_tag(true)
	if ReplayBuffer.death_time >= 0.0 and _play_t >= ReplayBuffer.death_time:
		_play_replay_sting()


func _advance_playback(real_delta: float) -> void:
	var rate := 1.0
	if _tune("replay_slow_seconds", 2.0) > 0.0 and _play_t >= _slow_start:
		rate = _tune("replay_slow_factor", 0.35)
	var prev := _play_t
	var next := _play_t + real_delta * rate
	if next > _clip_end:
		next = _clip_end
	for shot in ReplayBuffer.shots_between(_play_t, next):
		_spawn_replay_shot(shot, rate)
	_play_t = next
	_apply_playback_frame(_play_t)
	_place_replay_view(_play_t)
	if ReplayBuffer.death_time >= 0.0 and prev < ReplayBuffer.death_time and _play_t >= ReplayBuffer.death_time:
		_play_replay_sting()
	if _play_t >= _clip_end - 0.0001:
		_clear_replay_fx()
		_enter_trailing()


func _enter_trailing() -> void:
	_set_replay_tag(false)
	if not _stashed.is_empty():
		_restore_stash()
	elif phase == Phase.FLYING and _local_is_victim():
		_radius = ORBIT_RADIUS
		_pitch = ORBIT_PITCH
		_yaw = 0.6
	# After this frame's IK, so the stashed death pose is the one that sticks.
	_freeze_replay_bodies()
	phase = Phase.TRAILING
	if _local_is_victim():
		_ensure_camera()
		_apply_orbit()
	else:
		_teardown_camera()
		_unlock_winner()
	if not _trailing_emitted:
		_trailing_emitted = true
		trailing_started.emit()


func _apply_playback_frame(t: float) -> void:
	var actors := ReplayBuffer.sample_at(t)
	for i in actors.size():
		var pose: Dictionary = actors[i]
		if int(pose.get("flags", 0)) & ReplayBuffer.PRESENT == 0:
			continue
		var node := ReplayBuffer.actor_node(i)
		if is_instance_valid(node) and node.has_method("apply_replay_pose"):
			node.apply_replay_pose(pose)


## Killer's eyes through the shot, then the corpse orbit for the rest of the clip.
func _place_replay_view(t: float) -> void:
	if _in_replay_trail_at(t):
		_apply_orbit()
		return
	_place_killer_eye(t)


func _in_replay_trail() -> bool:
	return phase == Phase.PLAYBACK and _in_replay_trail_at(_play_t)


func _in_replay_trail_at(t: float) -> bool:
	return ReplayBuffer.death_time >= 0.0 and t >= ReplayBuffer.death_time


func _local_is_victim() -> bool:
	var host_side := not NetworkManager.is_active() or NetworkManager.is_host()
	if ReplayBuffer.victim_id == ReplayBuffer.ACTOR_HOST:
		return host_side
	return not host_side


func _stash_live() -> void:
	_stashed.clear()
	for actor_id in [ReplayBuffer.ACTOR_HOST, ReplayBuffer.ACTOR_OTHER]:
		var node := ReplayBuffer.actor_node(actor_id)
		if node is Player:
			_stashed.append((node as Player).capture_live_replay_pose())
		elif is_instance_valid(node) and node.has_method("capture_replay_pose"):
			_stashed.append(node.capture_replay_pose())
		else:
			_stashed.append({})


func _restore_stash() -> void:
	for i in _stashed.size():
		var pose: Dictionary = _stashed[i]
		if pose.is_empty():
			continue
		var node := ReplayBuffer.actor_node(i)
		if is_instance_valid(node) and node.has_method("apply_replay_pose"):
			node.apply_replay_pose(pose)
	_stashed.clear()
	_unlock_winner()


func _freeze_replay_bodies() -> void:
	for actor_id in [ReplayBuffer.ACTOR_HOST, ReplayBuffer.ACTOR_OTHER]:
		var node := ReplayBuffer.actor_node(actor_id)
		if is_instance_valid(node) and node is Player:
			(node as Player).freeze_replay_body.call_deferred()


func _unlock_winner() -> void:
	if ReplayBuffer.killer_id == ReplayBuffer.victim_id:
		return
	var winner_id := ReplayBuffer.ACTOR_OTHER if ReplayBuffer.victim_id == ReplayBuffer.ACTOR_HOST \
			else ReplayBuffer.ACTOR_HOST
	var winner := ReplayBuffer.actor_node(winner_id)
	if is_instance_valid(winner) and winner.has_method("clear_replay_pose"):
		winner.clear_replay_pose()


## Same full-speed sting as the live kill. Replay slow-mo does not drag it.
func _play_replay_sting() -> void:
	if _sting_played:
		return
	_sting_played = true
	if _sting == null or not is_instance_valid(_sting):
		_sting = AudioStreamPlayer.new()
		_sting.bus = "Master"
		add_child(_sting)
	_sting.stream = AudioCatalog.get_stream(&"duel_end")
	_sting.pitch_scale = 1.0 / maxf(AudioServer.playback_speed_scale, 0.001)
	_sting.play()


func _set_replay_tag(on: bool) -> void:
	if GameManager.hud != null:
		GameManager.hud.set_replay_tag(on and not GameManager.is_vr)
	if on and GameManager.is_vr:
		_show_vr_replay_tag()
	else:
		_hide_vr_replay_tag()


func _show_vr_replay_tag() -> void:
	var view := _spectator_cam if is_instance_valid(_spectator_cam) else null
	if view == null:
		return
	if _replay_label != null and is_instance_valid(_replay_label) and _replay_label.get_parent() == view:
		_replay_label.visible = true
		return
	_hide_vr_replay_tag()
	_replay_label = Label3D.new()
	_replay_label.text = "REPLAY"
	_replay_label.font_size = 48
	_replay_label.pixel_size = 0.0018
	_replay_label.outline_size = 12
	_replay_label.modulate = Color(0.95, 0.88, 0.72)
	_replay_label.no_depth_test = true
	_replay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_replay_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Upper right of the headset view, same idea as the flat HUD corner.
	_replay_label.position = Vector3(0.55, 0.28, -1.4)
	view.add_child(_replay_label)


func _hide_vr_replay_tag() -> void:
	if _replay_label != null and is_instance_valid(_replay_label):
		_replay_label.queue_free()
	_replay_label = null


func _stop_sting() -> void:
	_sting_played = false
	if _sting != null and is_instance_valid(_sting):
		_sting.stop()


func _place_killer_eye(t: float) -> void:
	var actors := ReplayBuffer.sample_at(t)
	var killer := ReplayBuffer.killer_id
	if killer < 0 or killer >= actors.size():
		_apply_orbit()
		return
	var pose: Dictionary = actors[killer]
	if int(pose.get("flags", 0)) & ReplayBuffer.PRESENT == 0:
		_apply_orbit()
		return
	var head: Transform3D = pose["head"]
	var nudge := 0.0 if ReplayBuffer.actor_node(killer) is Player else 0.18
	var eye := Transform3D(head.basis, head.origin + (-head.basis.z) * nudge)
	_place_locked(eye)


func _spawn_replay_shot(shot: Dictionary, rate: float) -> void:
	var origin: Vector3 = shot["origin"]
	var direction: Vector3 = shot["direction"]
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	var parent := _scene_parent()
	# Step past the muzzle so the ribbon does not die on the shooter.
	var from := origin + direction * 0.45
	var end := origin + direction * 80.0
	var normal := -direction
	var world: World3D = (parent as Node3D).get_world_3d() if parent is Node3D else null
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(from, end, WORLD_MASK)
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
			normal = hit["normal"]
			var collider: Object = hit.get("collider")
			if collider is Hitbox:
				ImpactFeedback.body_impact(end, normal, (collider as Hitbox).region)
			else:
				ImpactFeedback.world_impact(end, normal)
	var trail := BulletTrail.new()
	parent.add_child(trail)
	trail.add_point(origin)
	trail.add_point(end)
	trail.finish()
	trail.extend_fade(12.0)
	_replay_fx.append(trail)
	var gunshot := AudioStreamPlayer3D.new()
	gunshot.stream = AudioCatalog.get_stream(&"gunshot")
	gunshot.pitch_scale = clampf(rate, 0.2, 1.0)
	parent.add_child(gunshot)
	gunshot.global_position = origin
	gunshot.finished.connect(gunshot.queue_free)
	gunshot.play()
	_replay_fx.append(gunshot)


func _seed_orbit_from_camera() -> void:
	var eye := _current_eye_origin()
	var pivot := _chest()
	var offset := eye - pivot
	if offset.length_squared() < 0.04:
		_radius = ORBIT_RADIUS
		_pitch = ORBIT_PITCH
		_yaw = 0.6
		return
	_radius = clampf(offset.length(), 1.4, 7.0)
	var dir := offset / _radius
	_pitch = asin(clampf(dir.y, -1.0, 1.0))
	_yaw = atan2(dir.x, dir.z)


func _apply_orbit() -> void:
	_ensure_camera()
	var pivot := _chest()
	var cp := cos(_pitch)
	var offset := Vector3(sin(_yaw) * cp, sin(_pitch), cos(_yaw) * cp) * _radius
	var eye := pivot + offset
	var xf := Transform3D(Basis.IDENTITY, eye)
	if eye.distance_squared_to(pivot) > 0.0001:
		xf = xf.looking_at(pivot, Vector3.UP)
	_place_locked(xf)


func _chest() -> Vector3:
	var node := ReplayBuffer.actor_node(ReplayBuffer.victim_id)
	if node is Player:
		return (node as Player).get_head_position() + Vector3.DOWN * 0.45
	if node is RemoteAvatar:
		var avatar := node as RemoteAvatar
		if is_instance_valid(avatar.head):
			return avatar.head.global_position + Vector3.DOWN * 0.45
	if node is DuelistAI:
		return (node as Node3D).global_position + Vector3.UP * 1.05
	if GameManager.local_player != null:
		return GameManager.local_player.global_position + Vector3.UP * 1.1
	return Vector3.UP


func _current_eye_origin() -> Vector3:
	if is_instance_valid(_camera):
		return _camera.global_position
	if is_instance_valid(_spectator_cam):
		return _spectator_cam.global_position
	return _chest() + Vector3(1.6, 1.4, 2.4)


func _place_locked(desired: Transform3D) -> void:
	if is_instance_valid(_camera):
		_camera.global_transform = desired
	if is_instance_valid(_spectator) and _hmd_ref_valid:
		_spectator.global_transform = (desired * _hmd_ref.inverse()).orthonormalized()


func _ensure_camera() -> void:
	if GameManager.is_vr:
		if is_instance_valid(_spectator):
			return
		var rig := _player_vr_rig()
		if rig == null:
			return
		_restore_origin = rig
		_restore_xr_camera = rig.camera
		_hmd_ref = rig.camera.transform
		_hmd_ref_valid = true
		_spectator = XROrigin3D.new()
		_spectator.name = "DeathCamOrigin"
		_spectator_cam = XRCamera3D.new()
		_spectator_cam.name = "XRCamera3D"
		_spectator.add_child(_spectator_cam)
		_scene_parent().add_child(_spectator)
		rig.current = false
		rig.camera.current = false
		_spectator.current = true
		_spectator_cam.current = true
		return
	if is_instance_valid(_camera):
		return
	_restore_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "DeathCamCamera"
	_camera.fov = 55.0
	_scene_parent().add_child(_camera)
	_camera.current = true


func _teardown_camera() -> void:
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


func _release_actors() -> void:
	for actor_id in [ReplayBuffer.ACTOR_HOST, ReplayBuffer.ACTOR_OTHER]:
		var node := ReplayBuffer.actor_node(actor_id)
		if is_instance_valid(node) and node.has_method("clear_replay_pose"):
			node.clear_replay_pose()


func _clear_replay_fx() -> void:
	for node in _replay_fx:
		if is_instance_valid(node):
			node.queue_free()
	_replay_fx.clear()


func _scene_parent() -> Node:
	if is_instance_valid(GameManager.main_root):
		return GameManager.main_root
	return self


func _player_vr_rig() -> VRRig:
	var player := GameManager.local_player
	if player == null or not player.use_vr:
		return null
	return player.rig as VRRig


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))
