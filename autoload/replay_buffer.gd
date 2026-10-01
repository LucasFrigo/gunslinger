extends Node
## Autoload. Rolling 30 Hz record of the live duel (poses + shots).
## Single-player and the 1v1 host record. On a lethal hit the buffer keeps
## `replay_post_death` seconds, seals, and the host sends that clip to the
## joiner so both peers play the same frames.
## Actor 0 is the host (or the local player in SP). Actor 1 is the AI or the joiner.

const HZ := 30.0
const ACTOR_HOST := 0
const ACTOR_OTHER := 1
const ACTORS := 2
const PRESENT := 1 << 16
const XFORM_FLOATS := 7
const ACTOR_FLOATS := 1 + XFORM_FLOATS * 5
const SAMPLE_FLOATS := 1 + ACTOR_FLOATS * ACTORS
const SAMPLES_PER_CHUNK := 8
const _XFORM_KEYS: PackedStringArray = ["root", "head", "left", "right", "gun"]

var is_sealed := false
var death_time := -1.0
var killer_id := ACTOR_HOST
var victim_id := ACTOR_OTHER

var _recording := false
var _serial := 0
var _accept_serial := -1
var _elapsed := 0.0
var _accum := 0.0
var _post_left := -1.0
var _samples: Array = []
var _shots: Array = []


func _ready() -> void:
	set_process(false)


func begin() -> void:
	_serial += 1
	_accept_serial = -1
	_reset_clip()
	if NetworkManager.is_active() and not NetworkManager.is_host():
		return
	_recording = true
	set_process(true)


func abort() -> void:
	_serial += 1
	_accept_serial = -1
	_recording = false
	set_process(false)
	_reset_clip()


func is_recording() -> bool:
	return _recording


func ready_to_play() -> bool:
	return is_sealed and not _samples.is_empty()


func mark_death(killer: int, victim: int) -> void:
	killer_id = killer
	victim_id = victim
	# Start the sequence first so the death-frame sample latches a frozen pose.
	DeathCam.start_sequence()
	if _recording and death_time < 0.0:
		death_time = _elapsed
		_capture_sample()
		_trim()
		_post_left = maxf(_tune("replay_post_death", 2.0), 0.0)
		if _post_left <= 0.0:
			_seal()


func record_shot(origin: Vector3, direction: Vector3, shooter: int) -> void:
	if not _recording or direction.length_squared() < 0.0001:
		return
	_shots.append({
		"t": _elapsed,
		"origin": origin,
		"direction": direction.normalized(),
		"shooter": shooter,
	})


func request_skip() -> void:
	if not NetworkManager.is_active():
		DeathCam.skip_to_trailing()
		return
	if NetworkManager.is_host():
		_apply_skip.rpc()
	else:
		_request_skip.rpc_id(1)


func clip_begin() -> float:
	if _samples.is_empty():
		return 0.0
	return float(_samples[0]["t"])


func clip_end() -> float:
	if _samples.is_empty():
		return 0.0
	return float(_samples[_samples.size() - 1]["t"])


func sample_at(t: float) -> Array:
	if _samples.is_empty():
		return []
	if t <= float(_samples[0]["t"]):
		return _samples[0]["actors"]
	var last := _samples.size() - 1
	if t >= float(_samples[last]["t"]):
		return _samples[last]["actors"]
	for i in last:
		var a: Dictionary = _samples[i]
		var b: Dictionary = _samples[i + 1]
		if t <= float(b["t"]):
			var span := maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var u := clampf((t - float(a["t"])) / span, 0.0, 1.0)
			return _blend_actors(a["actors"], b["actors"], u)
	return _samples[last]["actors"]


func shots_between(t0: float, t1: float) -> Array:
	var out: Array = []
	for shot in _shots:
		var t := float(shot["t"])
		if t > t0 and t <= t1:
			out.append(shot)
	return out


## Host body, AI, or the peer avatar — whichever this machine is showing for `actor_id`.
func actor_node(actor_id: int) -> Node:
	var host_side := not NetworkManager.is_active() or NetworkManager.is_host()
	if actor_id == ACTOR_HOST:
		if host_side:
			return GameManager.local_player
		return GameManager.remote_avatar
	if is_instance_valid(GameManager.current_ai):
		return GameManager.current_ai
	if host_side:
		return GameManager.remote_avatar
	return GameManager.local_player


func _process(delta: float) -> void:
	if not _recording:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_elapsed += real_delta
	_accum += real_delta
	var step := 1.0 / HZ
	while _accum >= step:
		_accum -= step
		_capture_sample()
		_trim()
	if _post_left >= 0.0:
		_post_left -= real_delta
		if _post_left <= 0.0:
			_capture_sample()
			_seal()


func _capture_sample() -> void:
	var actors: Array = []
	actors.append(_capture_node(actor_node(ACTOR_HOST)))
	actors.append(_capture_node(actor_node(ACTOR_OTHER)))
	_samples.append({"t": _elapsed, "actors": actors})


func _capture_node(node: Node) -> Dictionary:
	if not is_instance_valid(node) or not node.has_method("capture_replay_pose"):
		return _blank_pose()
	var pose: Dictionary = node.capture_replay_pose()
	pose["flags"] = int(pose.get("flags", 0)) | PRESENT
	return pose


func _blank_pose() -> Dictionary:
	return {
		"root": Transform3D.IDENTITY,
		"head": Transform3D.IDENTITY,
		"left": Transform3D.IDENTITY,
		"right": Transform3D.IDENTITY,
		"gun": Transform3D.IDENTITY,
		"flags": 0,
	}


func _trim() -> void:
	var pre := _tune("replay_pre_death", 5.0)
	var keep_from := _elapsed - pre - 1.0
	if death_time >= 0.0:
		keep_from = death_time - pre
	while not _samples.is_empty() and float(_samples[0]["t"]) < keep_from - 0.001:
		_samples.pop_front()
	while not _shots.is_empty() and float(_shots[0]["t"]) < keep_from - 0.001:
		_shots.pop_front()


func _seal() -> void:
	if is_sealed:
		return
	_recording = false
	_post_left = -1.0
	set_process(false)
	_trim()
	is_sealed = true
	if NetworkManager.is_active() and NetworkManager.is_host() and NetworkManager.peer_count() > 0:
		_send_clip()


func _send_clip() -> void:
	_replay_header.rpc(_serial, death_time, killer_id, victim_id)
	var buf := PackedFloat32Array()
	var count := 0
	for sample in _samples:
		_pack_sample(buf, sample)
		count += 1
		if count >= SAMPLES_PER_CHUNK:
			_replay_samples.rpc(_serial, buf)
			buf = PackedFloat32Array()
			count = 0
	if buf.size() > 0:
		_replay_samples.rpc(_serial, buf)
	var packed := PackedFloat32Array()
	for shot in _shots:
		var origin: Vector3 = shot["origin"]
		var direction: Vector3 = shot["direction"]
		packed.append(float(shot["t"]))
		packed.append(origin.x)
		packed.append(origin.y)
		packed.append(origin.z)
		packed.append(direction.x)
		packed.append(direction.y)
		packed.append(direction.z)
		packed.append(float(shot["shooter"]))
	_replay_shots.rpc(_serial, packed)
	_replay_seal.rpc(_serial)


func _reset_clip() -> void:
	is_sealed = false
	death_time = -1.0
	killer_id = ACTOR_HOST
	victim_id = ACTOR_OTHER
	_elapsed = 0.0
	_accum = 0.0
	_post_left = -1.0
	_samples.clear()
	_shots.clear()


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))


func _blend_actors(a_actors: Array, b_actors: Array, u: float) -> Array:
	var blended: Array = []
	for i in ACTORS:
		if i >= a_actors.size() or i >= b_actors.size():
			break
		var a: Dictionary = a_actors[i]
		var b: Dictionary = b_actors[i]
		var flags_a := int(a.get("flags", 0))
		var flags_b := int(b.get("flags", 0))
		var pose := {}
		for key in _XFORM_KEYS:
			pose[key] = _lerp_xform(a[key], b[key], u)
		pose["flags"] = flags_b if u >= 0.5 else flags_a
		blended.append(pose)
	return blended


func _lerp_xform(a: Transform3D, b: Transform3D, u: float) -> Transform3D:
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb, u)), a.origin.lerp(b.origin, u))


func _pack_sample(buf: PackedFloat32Array, sample: Dictionary) -> void:
	buf.append(float(sample["t"]))
	var actors: Array = sample["actors"]
	for i in ACTORS:
		var pose: Dictionary = actors[i] if i < actors.size() else _blank_pose()
		buf.append(float(pose.get("flags", 0)))
		for key in _XFORM_KEYS:
			var xf: Transform3D = pose[key]
			var q := xf.basis.orthonormalized().get_rotation_quaternion()
			buf.append(q.x)
			buf.append(q.y)
			buf.append(q.z)
			buf.append(q.w)
			buf.append(xf.origin.x)
			buf.append(xf.origin.y)
			buf.append(xf.origin.z)


func _unpack_sample(buf: PackedFloat32Array, offset: int) -> Dictionary:
	var i := offset
	var t := buf[i]
	i += 1
	var actors: Array = []
	for _actor in ACTORS:
		var flags := int(buf[i])
		i += 1
		var pose := {"flags": flags}
		for key in _XFORM_KEYS:
			var q := Quaternion(buf[i], buf[i + 1], buf[i + 2], buf[i + 3])
			var origin := Vector3(buf[i + 4], buf[i + 5], buf[i + 6])
			pose[key] = Transform3D(Basis(q), origin)
			i += XFORM_FLOATS
		actors.append(pose)
	return {"t": t, "actors": actors, "next": i}


@rpc("authority", "call_remote", "reliable")
func _replay_header(serial: int, death_t: float, killer: int, victim: int) -> void:
	if NetworkManager.is_host() or not DeathCam.is_active():
		return
	_accept_serial = serial
	_samples.clear()
	_shots.clear()
	is_sealed = false
	death_time = death_t
	killer_id = killer
	victim_id = victim


@rpc("authority", "call_remote", "reliable")
func _replay_samples(serial: int, buf: PackedFloat32Array) -> void:
	if NetworkManager.is_host() or serial != _accept_serial or is_sealed:
		return
	var i := 0
	while i + SAMPLE_FLOATS <= buf.size():
		var parsed := _unpack_sample(buf, i)
		_samples.append({"t": parsed["t"], "actors": parsed["actors"]})
		i = int(parsed["next"])


@rpc("authority", "call_remote", "reliable")
func _replay_shots(serial: int, buf: PackedFloat32Array) -> void:
	if NetworkManager.is_host() or serial != _accept_serial or is_sealed:
		return
	_shots.clear()
	var i := 0
	while i + 8 <= buf.size():
		_shots.append({
			"t": buf[i],
			"origin": Vector3(buf[i + 1], buf[i + 2], buf[i + 3]),
			"direction": Vector3(buf[i + 4], buf[i + 5], buf[i + 6]),
			"shooter": int(buf[i + 7]),
		})
		i += 8


@rpc("authority", "call_remote", "reliable")
func _replay_seal(serial: int) -> void:
	if NetworkManager.is_host() or serial != _accept_serial:
		return
	is_sealed = true


@rpc("any_peer", "call_remote", "reliable")
func _request_skip() -> void:
	if NetworkManager.is_host():
		_apply_skip.rpc()


@rpc("authority", "call_local", "reliable")
func _apply_skip() -> void:
	DeathCam.skip_to_trailing()
