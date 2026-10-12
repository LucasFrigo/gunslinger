extends Node
## Autoload. Rolling 30 Hz record of the live duel (poses + shots).
## Single-player and the lobby host record. On the final lethal hit the buffer keeps
## `replay_post_death` seconds, seals, and the host sends that clip to every
## client so all peers play the same frames.
## An actor id is a lobby slot in MP (0 is the host) and, in SP, the player (0) or
## NPC i (i + 1). A clip holds one actor per lobby slot, or per SP duelist.

const HZ := 30.0
const ACTOR_HOST := 0
const ACTOR_OTHER := 1
const ACTORS := 2
const PRESENT := 1 << 16
const XFORM_FLOATS := 7
## flags + five body transforms, then an object word and the prop and round poses.
const OBJECT_FLOATS := 1 + XFORM_FLOATS * 2
const ACTOR_FLOATS := 1 + XFORM_FLOATS * 5 + OBJECT_FLOATS
## Floats in one `_replay_samples` RPC: eight samples of a two-actor clip. A wider clip
## sends fewer samples per chunk, never a bigger one.
const CHUNK_FLOATS := 8 * (1 + ACTOR_FLOATS * ACTORS)
const _XFORM_KEYS: PackedStringArray = ["root", "head", "left", "right", "gun"]
## Off-hand prop packed into the object word. 0 is an empty hand.
const PROP_ID_MASK := 7
const PROP_PLACE_SHIFT := 3
const PROP_PLACE_MASK := 3
const PROP_PLACE_NONE := 0
const PROP_PLACE_HAND := 1
const PROP_PLACE_WORLD := 2
const ROUND_HELD := 1 << 5
const PROP_NONE := 0
const PROP_CIGARETTE := 1
const PROP_COIN := 2
const PROP_ACE := 3
const PROP_BOTTLE := 4

var is_sealed := false
var death_time := -1.0
var killer_id := ACTOR_HOST
var victim_id := ACTOR_OTHER
## Actor id -> clip time of its death: the victim, and every duelist that fell before it.
## A client gets these with the clip.
var death_times := {}

var _recording := false
var _serial := 0
var _accept_serial := -1
var _elapsed := 0.0
var _accum := 0.0
var _post_left := -1.0
var _samples: Array = []
var _shots: Array = []
## Client: actors per sample in the clip being received.
var _clip_actors := ACTORS


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


## Clip clock now, for stamping events the replay re-plays. -1 when not recording
## (an MP client, or after the clip sealed).
func clip_time() -> float:
	return _elapsed if _recording else -1.0


func ready_to_play() -> bool:
	return is_sealed and not _samples.is_empty()


func mark_death(killer: int, victim: int) -> void:
	killer_id = killer
	victim_id = victim
	note_death(victim)
	# Start the sequence first so the death-frame sample latches a frozen pose.
	DeathCam.start_sequence()
	if _recording and death_time < 0.0:
		death_time = _elapsed
		_capture_sample()
		_trim()
		_post_left = maxf(_tune("replay_post_death", 2.0), 0.0)
		if _post_left <= 0.0:
			_seal()


## Clip time `actor_id` died at; the first call wins. Only while recording.
func note_death(actor_id: int) -> void:
	if _recording and not death_times.has(actor_id):
		death_times[actor_id] = _elapsed


## -1 when `actor_id` did not die inside the recording.
func death_time_of(actor_id: int) -> float:
	return float(death_times.get(actor_id, -1.0))


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


## Recorded actors: every slot of the running MP duel, else the player plus every SP NPC.
func actor_count() -> int:
	var snapshot := GameManager.duel.snapshot
	if snapshot != null:
		return snapshot.slots.size()
	return maxi(ACTORS, 1 + GameManager.current_ais.size())


## Floats one packed sample of `count` actors takes.
func sample_floats(count: int) -> int:
	return 1 + ACTOR_FLOATS * count


## Samples of `count` actors that fit one chunk RPC.
func samples_per_chunk(count: int) -> int:
	return maxi(CHUNK_FLOATS / sample_floats(count), 1)


## The local player, an NPC, or a peer's avatar: whichever this machine shows for `actor_id`.
func actor_node(actor_id: int) -> Node:
	return GameManager.actor_node(actor_id)


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
	for actor_id in actor_count():
		actors.append(_capture_node(actor_node(actor_id)))
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
		"objects": 0,
		"prop": Transform3D.IDENTITY,
		"round": Transform3D.IDENTITY,
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
	var actors := actor_count()
	_replay_header.rpc(_serial, death_time, killer_id, victim_id, actors, _pack_death_times(actors))
	var per_chunk := samples_per_chunk(actors)
	var buf := PackedFloat32Array()
	var count := 0
	for sample in _samples:
		_pack_sample(buf, sample, actors)
		count += 1
		if count >= per_chunk:
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


## One clip time per actor id, -1 for an actor that did not die in the recording.
func _pack_death_times(count: int) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	for actor_id in count:
		times.append(death_time_of(actor_id))
	return times


func _unpack_death_times(times: PackedFloat32Array, count: int) -> void:
	death_times.clear()
	for actor_id in mini(times.size(), count):
		if times[actor_id] >= 0.0:
			death_times[actor_id] = times[actor_id]


func _reset_clip() -> void:
	is_sealed = false
	death_time = -1.0
	killer_id = ACTOR_HOST
	victim_id = ACTOR_OTHER
	death_times.clear()
	_elapsed = 0.0
	_accum = 0.0
	_post_left = -1.0
	_samples.clear()
	_shots.clear()


func _tune(key: String, fallback: float) -> float:
	return float(GameManager.tuning.get(key, fallback))


func _blend_actors(a_actors: Array, b_actors: Array, u: float) -> Array:
	var blended: Array = []
	for i in mini(a_actors.size(), b_actors.size()):
		var a: Dictionary = a_actors[i]
		var b: Dictionary = b_actors[i]
		var flags_a := int(a.get("flags", 0))
		var flags_b := int(b.get("flags", 0))
		var obj_a := int(a.get("objects", 0))
		var obj_b := int(b.get("objects", 0))
		var pose := {}
		for key in _XFORM_KEYS:
			pose[key] = _lerp_xform(a[key], b[key], u)
		pose["flags"] = flags_b if u >= 0.5 else flags_a
		pose["objects"] = obj_b if u >= 0.5 else obj_a
		pose["prop"] = _lerp_object_xform(a, b, "prop", obj_a, obj_b, u, false)
		pose["round"] = _lerp_object_xform(a, b, "round", obj_a, obj_b, u, true)
		blended.append(pose)
	return blended


func _lerp_xform(a: Transform3D, b: Transform3D, u: float) -> Transform3D:
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb, u)), a.origin.lerp(b.origin, u))


## A prop or round that is absent on one sample must not slide in from the origin.
func _lerp_object_xform(a: Dictionary, b: Dictionary, key: String, obj_a: int, obj_b: int, u: float, round_bit: bool) -> Transform3D:
	var on_a := _object_present(obj_a, round_bit)
	var on_b := _object_present(obj_b, round_bit)
	var xf_a := _xform_of(a, key)
	var xf_b := _xform_of(b, key)
	if on_a and on_b:
		return _lerp_xform(xf_a, xf_b, u)
	if on_b and u >= 0.5:
		return xf_b
	if on_a and u < 0.5:
		return xf_a
	if on_a:
		return xf_a
	if on_b:
		return xf_b
	return Transform3D.IDENTITY


func _object_present(objects: int, round_bit: bool) -> bool:
	if round_bit:
		return objects & ROUND_HELD != 0
	var place := (objects >> PROP_PLACE_SHIFT) & PROP_PLACE_MASK
	return place != PROP_PLACE_NONE


func _xform_of(pose: Dictionary, key: String) -> Transform3D:
	return pose[key] if pose.has(key) else Transform3D.IDENTITY


func _append_xform(buf: PackedFloat32Array, xf: Transform3D) -> void:
	var q := xf.basis.orthonormalized().get_rotation_quaternion()
	buf.append(q.x)
	buf.append(q.y)
	buf.append(q.z)
	buf.append(q.w)
	buf.append(xf.origin.x)
	buf.append(xf.origin.y)
	buf.append(xf.origin.z)


func _read_xform(buf: PackedFloat32Array, i: int) -> Transform3D:
	var q := Quaternion(buf[i], buf[i + 1], buf[i + 2], buf[i + 3])
	var origin := Vector3(buf[i + 4], buf[i + 5], buf[i + 6])
	return Transform3D(Basis(q), origin)


## Appends `sample_floats(count)` floats. An actor the sample lacks packs blank.
func _pack_sample(buf: PackedFloat32Array, sample: Dictionary, count: int) -> void:
	buf.append(float(sample["t"]))
	var actors: Array = sample["actors"]
	for i in count:
		var pose: Dictionary = actors[i] if i < actors.size() else _blank_pose()
		buf.append(float(pose.get("flags", 0)))
		for key in _XFORM_KEYS:
			_append_xform(buf, pose[key])
		buf.append(float(pose.get("objects", 0)))
		_append_xform(buf, _xform_of(pose, "prop"))
		_append_xform(buf, _xform_of(pose, "round"))


func _unpack_sample(buf: PackedFloat32Array, offset: int, count: int) -> Dictionary:
	var i := offset
	var t := buf[i]
	i += 1
	var actors: Array = []
	for _actor in count:
		var flags := int(buf[i])
		i += 1
		var pose := {"flags": flags}
		for key in _XFORM_KEYS:
			pose[key] = _read_xform(buf, i)
			i += XFORM_FLOATS
		pose["objects"] = int(buf[i])
		i += 1
		pose["prop"] = _read_xform(buf, i)
		i += XFORM_FLOATS
		pose["round"] = _read_xform(buf, i)
		i += XFORM_FLOATS
		actors.append(pose)
	return {"t": t, "actors": actors, "next": i}


## True on a client inside the session. The host records its own clip, and a peer still
## in the handshake gets the broadcasts too and must ignore them.
func _takes_clip() -> bool:
	return NetworkManager.is_active() and not NetworkManager.is_host()


## `actors` is the sample stride. `times` holds one clip time per actor id, -1 for an
## actor that did not die in the recording.
@rpc("authority", "call_remote", "reliable")
func _replay_header(serial: int, death_t: float, killer: int, victim: int, actors: int,
		times: PackedFloat32Array) -> void:
	if not _takes_clip() or not DeathCam.is_active() or actors < 1 or actors > LobbyRoster.MAX_SLOTS:
		return
	_accept_serial = serial
	_clip_actors = actors
	_samples.clear()
	_shots.clear()
	is_sealed = false
	death_time = death_t
	killer_id = killer
	victim_id = victim
	_unpack_death_times(times, actors)


@rpc("authority", "call_remote", "reliable")
func _replay_samples(serial: int, buf: PackedFloat32Array) -> void:
	if not _takes_clip() or serial != _accept_serial or is_sealed:
		return
	var stride := sample_floats(_clip_actors)
	var i := 0
	while i + stride <= buf.size():
		var parsed := _unpack_sample(buf, i, _clip_actors)
		_samples.append({"t": parsed["t"], "actors": parsed["actors"]})
		i = int(parsed["next"])


@rpc("authority", "call_remote", "reliable")
func _replay_shots(serial: int, buf: PackedFloat32Array) -> void:
	if not _takes_clip() or serial != _accept_serial or is_sealed:
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
	if not _takes_clip() or serial != _accept_serial:
		return
	is_sealed = true


@rpc("any_peer", "call_remote", "reliable")
func _request_skip() -> void:
	var snapshot := GameManager.duel.snapshot
	if NetworkManager.is_active() and NetworkManager.is_host() and snapshot != null \
			and snapshot.slot_of_peer(multiplayer.get_remote_sender_id()) >= 0:
		_apply_skip.rpc()


@rpc("authority", "call_local", "reliable")
func _apply_skip() -> void:
	if NetworkManager.is_active():
		DeathCam.skip_to_trailing()
