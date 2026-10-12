extends Node
## Autoload. Proximity voice chat for lobbies of 2-4. Captures the local mic off
## the muted `Mic` bus, gates it on mute / push-to-talk / voice activity, and
## streams 16 kHz mono PCM16 frames to the other humans over the same
## MultiplayerAPI that carries poses. Each sender plays out of its own avatar's
## mouth, so distance falloff is just an AudioStreamPlayer3D on the `Voice` bus.
##
## Between STANDOFF and DRAW of a duel the lobby splits in two channels, the dead
## and the living: a packet goes only to peers in the speaker's life state, and a
## receiver drops one from the other (`voice_recipients`, `accepts_voice_from`).
## A dead speaker plays without distance falloff for the other dead.
##
## Transport-agnostic: works the same over LAN ENet (all SKUs, including the
## Quest APK) and Steam Datagram Relay, because no transport-specific voice API
## is involved.

const MIC_BUS := &"Mic"
const VOICE_BUS := &"Voice"
## Wire format is mono PCM16 at this rate, fixed so two machines whose audio
## drivers run different mix rates still understand each other.
const SEND_RATE := 16000
## 20 ms per packet: 320 samples / 640 bytes, 50 packets a second while someone
## is actually talking (silence is never sent).
const FRAME_SAMPLES := 320
## Tight jitter buffer. A quarter-second here is already a noticeable lag, and
## WASAPI can dump a multi-second capture backlog in one frame if we let it.
const PLAYBACK_BUFFER_SEC := 0.08
## Do not let queued playback grow past this; extra packets are dropped.
const PLAYBACK_TARGET_SEC := 0.04
## After a hitch, keep at most this many 20 ms capture packets (the newest).
const MAX_CAPTURE_PACKETS := 2
## Same bound on the receive side so a burst of RPCs cannot queue stale speech.
const MAX_RX_QUEUE := 2
## One-pole high-pass on the 16 kHz stream. Drops rumble / fan thump before
## the gate sees it; one multiply per sample.
const HP_CUTOFF_HZ := 180.0
## Keep transmitting this long after the level drops so word tails survive.
const VAD_HANG_SEC := 0.18
## Own ENet / Steam channels so a reliable shot or duel RPC cannot stall voice
## for seconds (Godot's default channel 0 is shared with gameplay).
const VOICE_CHANNEL := 2
const VOICE_STATE_CHANNEL := 1
## A packet this far behind the newest one is a straggler; a bigger gap than
## this means the peer restarted its counter, so resync instead of dropping.
const SEQ_REORDER_WINDOW := 100
const ANDROID_MIC_PERMISSION := "android.permission.RECORD_AUDIO"
## How often to retry capture while a session wants it (mic permission granted
## late on Quest, device plugged in mid-match).
const RETRY_INTERVAL := 1.0

## Smoothed local capture RMS (0-1). Settings draws this so the noise-gate
## slider can sit just above the idle bar.
var mic_level := 0.0
## Last packet RMS, pre-expander. Autotest and the debug readout use this.
var last_rms := 0.0
## True while the local mic is passing the gate and packets are going out.
var transmitting := false

var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
## One remote speaker: the avatar mouth their voice plays from and the jitter state
## for it. `player` is null while there is no avatar (only the mute flag is kept).
class Sender:
	var player: AudioStreamPlayer3D
	var playback: AudioStreamGeneratorPlayback
	var last_seq := 0
	## Newest incoming packets, oldest at front. Overflow drops the front.
	var rx: Array[PackedByteArray] = []
	var muted := false
	## The player's attenuation as the avatar scene has it, for when `flat` ends.
	var model: AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	## Playing without distance falloff: a dead speaker among the dead.
	var flat := false

## The one stream every bound voice player plays. A generator playback keeps a raw
## pointer to its stream, and the audio thread reads it for one more mix after the
## player is freed, so the stream must never be freed first (BUG-021): it holds a
## reference that is never released.
var _generator: AudioStreamGenerator
var _capturing := false
var _session_wants_capture := false
## Settings holds a monitor open while it is on screen so the level bar works
## outside a session.
var _monitors := 0
var _retry_accum := 0.0
var _seq := 0
var _vad_hang := 0.0
## Last local mute value acted on, so a volume tweak does not re-broadcast.
var _local_muted := false
var _permission_requested := false
## High-pass delay line (previous input / output) on the 16 kHz stream.
var _hp_x := 0.0
var _hp_y := 0.0
var _hp_coeff := 0.0
## Sender peer id -> Sender.
var _senders := {}
## Sender peer id -> packets taken into the jitter queue this session (autotest and
## the debug readout).
var packets_accepted := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicCapture"
	_mic_player.bus = MIC_BUS
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_mic_player)
	_hp_coeff = exp(-TAU * HP_CUTOFF_HZ / float(SEND_RATE))
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = float(SEND_RATE)
	_generator.buffer_length = PLAYBACK_BUFFER_SEC
	_generator.reference()
	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.roster_changed.connect(_prune_senders)
	PlayerSettings.audio_devices_changed.connect(_on_devices_changed)
	PlayerSettings.voice_changed.connect(_on_voice_settings_changed)
	GameManager.tuning_changed.connect(_on_tuning_changed)


func _process(delta: float) -> void:
	_poll_local_input()
	if _capturing:
		_pump_capture(delta)
	else:
		mic_level = maxf(mic_level - delta * 3.0, 0.0)
		transmitting = false
		_retry_accum += delta
		if _retry_accum >= RETRY_INTERVAL:
			_retry_accum = 0.0
			_update_capture_state()
	_refresh_falloff()
	_flush_rx_queue()


# -- Public API ----------------------------------------------------------------

func is_muted() -> bool:
	return PlayerSettings.voice_muted


func toggle_mute() -> void:
	PlayerSettings.set_voice_muted(not PlayerSettings.voice_muted)


## True while the mic stream is actually running (a session or a monitor).
func is_capturing() -> bool:
	return _capturing


## Settings keeps a monitor open while visible so the mic level bar reads even
## with no session running. Balance every add with a remove.
func add_monitor() -> void:
	_monitors += 1
	_update_capture_state()


func remove_monitor() -> void:
	_monitors = maxi(_monitors - 1, 0)
	_update_capture_state()


## GameManager hands over the player of the avatar standing for human `peer_id`
## (null when it despawns). Binding again replaces the old player, its playback,
## and its queue.
func bind_voice_player(peer_id: int, player: AudioStreamPlayer3D) -> void:
	var sender: Sender = _senders.get(peer_id)
	if player == null:
		if sender == null:
			return
		sender.player = null
		sender.playback = null
		sender.last_seq = 0
		sender.rx.clear()
		sender.flat = false
		if not sender.muted:
			_senders.erase(peer_id)
		return
	if sender == null:
		sender = Sender.new()
		_senders[peer_id] = sender
	sender.player = player
	sender.last_seq = 0
	sender.rx.clear()
	sender.model = player.attenuation_model
	sender.flat = _speaker_flat(peer_id)
	player.bus = VOICE_BUS
	player.stream = _generator
	_apply_player_tuning(sender)
	player.play()
	sender.playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if sender.playback == null:
		call_deferred("_grab_playback", peer_id, player)
	_apply_peer_mute(peer_id)


## The player bound for `peer_id`, or null.
func bound_player(peer_id: int) -> AudioStreamPlayer3D:
	var sender: Sender = _senders.get(peer_id)
	return sender.player if sender != null and is_instance_valid(sender.player) else null


func bound_peers() -> Array[int]:
	var peers: Array[int] = []
	for peer_id: int in _senders:
		if (_senders[peer_id] as Sender).player != null:
			peers.append(peer_id)
	return peers


func _grab_playback(peer_id: int, player: AudioStreamPlayer3D) -> void:
	var sender: Sender = _senders.get(peer_id)
	if sender != null and sender.player == player and is_instance_valid(player):
		sender.playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


## True when voice could physically work here: a real audio driver, the Mic bus
## from the project bus layout, and the mic permission on Android. Pure query —
## it never prompts, because the UI and debug panel poll it.
func is_available() -> bool:
	if OS.has_feature("headless") or AudioServer.get_driver_name() == "Dummy":
		return false
	if AudioServer.get_bus_index(MIC_BUS) < 0:
		return false
	return _has_mic_permission()


# -- Session lifecycle ---------------------------------------------------------

func _on_session_started(_as_host: bool) -> void:
	_seq = 0
	_senders.clear()
	packets_accepted.clear()
	_vad_hang = 0.0
	_local_muted = PlayerSettings.voice_muted
	_session_wants_capture = true
	_update_capture_state()


func _on_peer_joined(_peer_id: int) -> void:
	_send_mute_state()


func _on_peer_left(peer_id: int) -> void:
	_senders.erase(peer_id)


## A sender that holds no slot any more (a client sees a leaver only here) loses its state.
func _prune_senders() -> void:
	var roster := _roster()
	for peer_id: int in _senders.keys():
		if roster.slot_of_peer(peer_id) < 0:
			_senders.erase(peer_id)


func _on_session_ended(_reason: String) -> void:
	_session_wants_capture = false
	_senders.clear()
	_update_capture_state()


func _on_devices_changed() -> void:
	if not _capturing:
		return
	# The mic stream has to be restarted for a new input device to take, and the
	# old device's tail in the capture buffer is stale.
	_mic_player.stop()
	_mic_player.play()
	if _capture != null:
		_capture.clear_buffer()


## Fires for volume too, so only react when mute itself flipped.
func _on_voice_settings_changed() -> void:
	if _local_muted == PlayerSettings.voice_muted:
		return
	_local_muted = PlayerSettings.voice_muted
	_send_mute_state()
	# The mute bind is a bare keypress, so confirm it somewhere the player is
	# already looking. The peer gets the X over the mouth instead.
	if NetworkManager.is_active():
		GameManager.show_message(tr("MSG_MIC_MUTED") if _local_muted else tr("MSG_MIC_LIVE"), 1.2)


func _on_tuning_changed(key: String, _value: Variant) -> void:
	if key.begins_with("voice_"):
		_apply_voice_tuning()


# -- Capture -------------------------------------------------------------------

func _update_capture_state() -> void:
	var want := _session_wants_capture or _monitors > 0
	if want == _capturing:
		return
	if want:
		_start_capture()
	else:
		_stop_capture()


func _start_capture() -> void:
	if not _has_mic_permission():
		_request_mic_permission()
		return  # retried from _process once the player answers the prompt
	if not is_available() or not _ensure_capture_effect():
		return
	_capture.clear_buffer()
	_hp_x = 0.0
	_hp_y = 0.0
	_mic_player.play()
	_capturing = true


func _stop_capture() -> void:
	_capturing = false
	transmitting = false
	mic_level = 0.0
	_vad_hang = 0.0
	_mic_player.stop()
	if _capture != null:
		_capture.clear_buffer()


func _ensure_capture_effect() -> bool:
	if _capture != null:
		return true
	var bus := AudioServer.get_bus_index(MIC_BUS)
	if bus < 0:
		return false
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectCapture:
			_capture = effect as AudioEffectCapture
			return true
	push_warning("VoiceChat: the Mic bus has no AudioEffectCapture; voice is off.")
	return false


func _pump_capture(delta: float) -> void:
	if _capture == null:
		return
	var needed := _input_frames_per_packet()
	if needed <= 0:
		return
	var packet_sec := float(FRAME_SAMPLES) / float(SEND_RATE)
	# A stalled WASAPI input buffer can hold seconds. Throw away everything but
	# the latest couple of packets so we transmit *now*, not five seconds ago.
	var available := _capture.get_frames_available()
	var packets := available / needed
	if packets > MAX_CAPTURE_PACKETS:
		_capture.get_buffer((packets - MAX_CAPTURE_PACKETS) * needed)
		packets = MAX_CAPTURE_PACKETS
	var sent_any := false
	var drained_any := false
	var rms := 0.0
	for _i in packets:
		drained_any = true
		var pcm := _encode(_capture.get_buffer(needed))
		rms = maxf(rms, last_rms)
		if _gate_open(last_rms, packet_sec) and _send_packet(pcm):
			sent_any = true
	mic_level = maxf(rms, mic_level - delta * 3.0)
	if drained_any:
		transmitting = sent_any


## One packet to everyone `voice_recipients` names. False when nobody is eligible.
func _send_packet(pcm: PackedByteArray) -> bool:
	var peers := voice_recipients()
	if peers.is_empty():
		return false
	for peer_id in peers:
		_voice.rpc_id(peer_id, _seq, pcm)
	_seq += 1
	return true


## Autotest only: feeds one PCM packet into the send path the microphone uses, past
## the mute / push-to-talk / noise gate.
func send_test_packet(pcm: PackedByteArray) -> bool:
	return _send_packet(pcm)


## Frames of driver-rate audio that make up one SEND_RATE packet. Standard mix
## rates (44.1 / 48 kHz) divide evenly into 20 ms, so this does not drift.
func _input_frames_per_packet() -> int:
	var rate := AudioServer.get_mix_rate()
	return maxi(int(round(rate * float(FRAME_SAMPLES) / float(SEND_RATE))), 1)


## Mute always wins. With push-to-talk on, the button is the whole gate;
## otherwise RMS has to clear the Settings noise-gate cutoff. A short hang keeps
## the ends of words from being clipped.
func _gate_open(rms: float, delta: float) -> bool:
	if not NetworkManager.is_active() or NetworkManager.peer_count() <= 0:
		return false
	if PlayerSettings.voice_muted:
		return false
	if PlayerSettings.voice_ptt_enabled:
		return _ptt_pressed()
	var threshold := PlayerSettings.voice_gate_cutoff
	if threshold <= 0.0:
		return true
	if rms >= threshold:
		_vad_hang = VAD_HANG_SEC
		return true
	_vad_hang = maxf(_vad_hang - delta, 0.0)
	return _vad_hang > 0.0


func _ptt_pressed() -> bool:
	if not InputMap.has_action(&"voice_ptt"):
		return false
	return Input.is_action_pressed(&"voice_ptt")


func _poll_local_input() -> void:
	if PlayerSettings.is_listening() or not InputMap.has_action(&"voice_mute"):
		return
	if Input.is_action_just_pressed(&"voice_mute"):
		toggle_mute()


# -- Codec ---------------------------------------------------------------------

## Downmix to mono, box-average down to SEND_RATE, then a one-pole high-pass
## and a cheap expander below the noise-gate cutoff. RMS is measured *before*
## the expander so the gate sees the real speech energy.
func _encode(frames: PackedVector2Array) -> PackedByteArray:
	var count := frames.size()
	var pcm := PackedByteArray()
	if count <= 0:
		last_rms = 0.0
		return pcm
	var samples := PackedFloat32Array()
	samples.resize(FRAME_SAMPLES)
	var step := float(count) / float(FRAME_SAMPLES)
	var energy := 0.0
	for i in FRAME_SAMPLES:
		var from := mini(int(i * step), count - 1)
		var to := mini(maxi(int((i + 1) * step), from + 1), count)
		var sum := 0.0
		for j in range(from, to):
			var frame := frames[j]
			sum += (frame.x + frame.y) * 0.5
		var value := sum / float(to - from)
		# y[n] = a * (y[n-1] + x[n] - x[n-1])
		var hp := _hp_coeff * (_hp_y + value - _hp_x)
		_hp_x = value
		_hp_y = hp
		samples[i] = hp
		energy += hp * hp
	last_rms = sqrt(energy / float(FRAME_SAMPLES))
	var gain := 1.0
	var cutoff := PlayerSettings.voice_gate_cutoff
	if cutoff > 0.0 and last_rms < cutoff:
		# Square the ratio so room tone well below the cutoff almost vanishes,
		# while a word that just clears it is barely touched.
		var ratio := last_rms / cutoff
		gain = ratio * ratio
	pcm.resize(FRAME_SAMPLES * 2)
	for i in FRAME_SAMPLES:
		var value := clampf(samples[i] * gain, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(value * 32767.0))
	return pcm


func _push_playback(sender: Sender, pcm: PackedByteArray) -> void:
	var playback := sender.playback
	if playback == null:
		return
	var count := pcm.size() / 2
	if count <= 0 or playback.get_frames_available() < count:
		return
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in count:
		var value := float(pcm.decode_s16(i * 2)) / 32767.0
		frames[i] = Vector2(value, value)
	playback.push_buffer(frames)


func _queued_frames(sender: Sender) -> int:
	if sender.playback == null:
		return 0
	var capacity := int(float(SEND_RATE) * PLAYBACK_BUFFER_SEC)
	return maxi(capacity - sender.playback.get_frames_available(), 0)


func _flush_rx_queue() -> void:
	var target := int(float(SEND_RATE) * PLAYBACK_TARGET_SEC)
	for peer_id: int in _senders:
		var sender: Sender = _senders[peer_id]
		if sender.playback == null:
			continue
		while not sender.rx.is_empty() and _queued_frames(sender) <= target:
			if sender.playback.get_frames_available() < FRAME_SAMPLES:
				break
			_push_playback(sender, sender.rx.pop_front())


# -- Channels -------------------------------------------------------------------

func _roster() -> LobbyRoster:
	var snapshot := GameManager.duel.snapshot
	return snapshot if snapshot != null else NetworkManager.roster


## True from the standoff to the draw of an MP duel, the span where the lobby splits in the
## dead and the living. The waiting room, the finish, and the rematch gap hear everyone.
func _channels_split() -> bool:
	var duel := GameManager.duel
	return duel.snapshot != null and duel.state in [
			DuelManager.State.STANDOFF, DuelManager.State.WAIT_SIGNAL, DuelManager.State.DRAW]


func _same_channel(slot_a: int, slot_b: int) -> bool:
	return not _channels_split() or GameManager.duel.slot_alive(slot_a) == GameManager.duel.slot_alive(slot_b)


## A dead speaker among the dead plays without distance falloff: the listener is on a
## spectator camera, not near the corpse.
func _speaker_flat(peer_id: int) -> bool:
	return _channels_split() and not GameManager.duel.slot_alive(_roster().slot_of_peer(peer_id))


## The peers this machine's packet goes to right now: every other human in the same
## channel. An NPC slot has no peer, so it is never one. A human who left or was kicked
## is gone from the live roster even while the running duel's snapshot still names them.
func voice_recipients() -> Array[int]:
	var peers: Array[int] = []
	if not NetworkManager.is_active():
		return peers
	var roster := _roster()
	var local := roster.local_slot()
	if local < 0:
		return peers
	for slot in roster.slots.size():
		var peer_id := int(roster.slots[slot]["peer_id"])
		if slot != local and roster.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN \
				and NetworkManager.roster.slot_of_peer(peer_id) >= 0 and _same_channel(local, slot):
			peers.append(peer_id)
	return peers


## Whether a packet from `peer_id` is heard now: a human still in the lobby that holds a
## slot other than ours, in our channel. This covers a packet in flight when its sender died.
func accepts_voice_from(peer_id: int) -> bool:
	if not NetworkManager.is_active() or NetworkManager.roster.slot_of_peer(peer_id) < 0:
		return false
	var roster := _roster()
	var from := roster.slot_of_peer(peer_id)
	var local := roster.local_slot()
	return from >= 0 and local >= 0 and from != local and _same_channel(from, local)


func _refresh_falloff() -> void:
	for peer_id: int in _senders:
		var sender: Sender = _senders[peer_id]
		if not is_instance_valid(sender.player):
			continue
		var flat := _speaker_flat(peer_id)
		if flat != sender.flat:
			sender.flat = flat
			_apply_player_tuning(sender)


# -- Net ----------------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable", VOICE_CHANNEL)
func _voice(seq: int, pcm: PackedByteArray) -> void:
	_take_packet(multiplayer.get_remote_sender_id(), seq, pcm)


## The receive path. False when the packet is dropped: a sender we do not hear now or
## have no avatar for, or a straggler.
func _take_packet(peer_id: int, seq: int, pcm: PackedByteArray) -> bool:
	if not accepts_voice_from(peer_id):
		return false
	var sender: Sender = _senders.get(peer_id)
	if sender == null or not is_instance_valid(sender.player):
		return false
	# Deliberately unordered: a late packet is already stale, and waiting for it
	# would add latency to every packet behind it.
	if seq <= sender.last_seq and sender.last_seq - seq < SEQ_REORDER_WINDOW:
		return false
	sender.last_seq = seq
	sender.rx.append(pcm)
	while sender.rx.size() > MAX_RX_QUEUE:
		sender.rx.pop_front()
	packets_accepted[peer_id] = int(packets_accepted.get(peer_id, 0)) + 1
	return true


@rpc("any_peer", "call_remote", "reliable", VOICE_STATE_CHANNEL)
func _voice_state(muted: bool) -> void:
	_take_mute(multiplayer.get_remote_sender_id(), muted)


func _take_mute(peer_id: int, muted: bool) -> void:
	if not NetworkManager.is_active() or _roster().slot_of_peer(peer_id) < 0:
		return
	var sender: Sender = _senders.get(peer_id)
	if sender == null:
		sender = Sender.new()
		_senders[peer_id] = sender
	sender.muted = muted
	_apply_peer_mute(peer_id)


## The pose stream carries the same bit 30 times a second; this just covers the
## gap where the peer has joined but poses have not started flowing yet.
func _send_mute_state() -> void:
	if NetworkManager.is_active() and NetworkManager.peer_count() > 0:
		_voice_state.rpc(PlayerSettings.voice_muted)


# -- Playback ------------------------------------------------------------------

func _apply_peer_mute(peer_id: int) -> void:
	var sender: Sender = _senders.get(peer_id)
	var avatar := GameManager.avatar_of_peer(peer_id)
	if sender != null and avatar != null:
		avatar.set_voice_muted(sender.muted)


func _apply_voice_tuning() -> void:
	for peer_id: int in _senders:
		var sender: Sender = _senders[peer_id]
		if is_instance_valid(sender.player):
			_apply_player_tuning(sender)


func _apply_player_tuning(sender: Sender) -> void:
	if sender.flat:
		sender.player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		sender.player.max_distance = 0.0
		return
	sender.player.attenuation_model = sender.model
	sender.player.max_distance = float(GameManager.tuning.get("voice_max_distance", 26.0))
	sender.player.unit_size = float(GameManager.tuning.get("voice_unit_size", 6.0))


func _has_mic_permission() -> bool:
	if OS.get_name() != "Android":
		return true
	return ANDROID_MIC_PERMISSION in OS.get_granted_permissions()


## Quest shows the mic prompt once; capture keeps retrying from _process, so it
## picks up whenever the player grants it.
func _request_mic_permission() -> void:
	if _permission_requested or OS.get_name() != "Android":
		return
	_permission_requested = true
	OS.request_permissions()
