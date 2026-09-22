extends Node
## Autoload. Proximity voice chat for 1v1 sessions. Captures the local mic off
## the muted `Mic` bus, gates it on mute / push-to-talk / voice activity, and
## streams 16 kHz mono PCM16 frames to the peer over the same MultiplayerAPI
## that carries poses. Incoming frames play out of the remote avatar's mouth,
## so distance falloff is just an AudioStreamPlayer3D on the `Voice` bus.
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
var _voice_player: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _capturing := false
var _session_wants_capture := false
## Settings holds a monitor open while it is on screen so the level bar works
## outside a session.
var _monitors := 0
var _retry_accum := 0.0
var _seq := 0
var _last_seq := 0
var _vad_hang := 0.0
var _peer_muted := false
## Last local mute value acted on, so a volume tweak does not re-broadcast.
var _local_muted := false
var _permission_requested := false
## High-pass delay line (previous input / output) on the 16 kHz stream.
var _hp_x := 0.0
var _hp_y := 0.0
var _hp_coeff := 0.0
## Newest incoming packets, oldest at front. Overflow drops the front.
var _rx_queue: Array[PackedByteArray] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicCapture"
	_mic_player.bus = MIC_BUS
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_mic_player)
	_hp_coeff = exp(-TAU * HP_CUTOFF_HZ / float(SEND_RATE))
	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended)
	NetworkManager.peer_joined.connect(_on_peer_joined)
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


## GameManager hands over the spawned avatar's player (or null on despawn).
func bind_voice_player(player: AudioStreamPlayer3D) -> void:
	_playback = null
	_voice_player = player
	_last_seq = 0
	_rx_queue.clear()
	if player == null:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = float(SEND_RATE)
	generator.buffer_length = PLAYBACK_BUFFER_SEC
	player.bus = VOICE_BUS
	player.stream = generator
	_apply_voice_tuning()
	player.play()
	_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		call_deferred("_grab_playback")
	_apply_peer_mute()


func _grab_playback() -> void:
	if _voice_player == null:
		return
	_playback = _voice_player.get_stream_playback() as AudioStreamGeneratorPlayback


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
	_last_seq = 0
	_vad_hang = 0.0
	_local_muted = PlayerSettings.voice_muted
	_session_wants_capture = true
	_update_capture_state()


func _on_peer_joined(_peer_id: int) -> void:
	_send_mute_state()


func _on_session_ended(_reason: String) -> void:
	_session_wants_capture = false
	_peer_muted = false
	bind_voice_player(null)
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
		GameManager.show_message("Mic muted" if _local_muted else "Mic live", 1.2)


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
		if _gate_open(last_rms, packet_sec):
			_voice.rpc(_seq, pcm)
			_seq += 1
			sent_any = true
	mic_level = maxf(rms, mic_level - delta * 3.0)
	if drained_any:
		transmitting = sent_any


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


func _push_playback(pcm: PackedByteArray) -> void:
	if _playback == null:
		return
	var count := pcm.size() / 2
	if count <= 0 or _playback.get_frames_available() < count:
		return
	var frames := PackedVector2Array()
	frames.resize(count)
	for i in count:
		var value := float(pcm.decode_s16(i * 2)) / 32767.0
		frames[i] = Vector2(value, value)
	_playback.push_buffer(frames)


func _queued_frames() -> int:
	if _playback == null:
		return 0
	var capacity := int(float(SEND_RATE) * PLAYBACK_BUFFER_SEC)
	return maxi(capacity - _playback.get_frames_available(), 0)


func _flush_rx_queue() -> void:
	if _playback == null or _rx_queue.is_empty():
		return
	var target := int(float(SEND_RATE) * PLAYBACK_TARGET_SEC)
	while not _rx_queue.is_empty() and _queued_frames() <= target:
		if _playback.get_frames_available() < FRAME_SAMPLES:
			break
		_push_playback(_rx_queue.pop_front())


# -- Net ----------------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable", VOICE_CHANNEL)
func _voice(seq: int, pcm: PackedByteArray) -> void:
	if not NetworkManager.is_active():
		return
	# Deliberately unordered: a late packet is already stale, and waiting for it
	# would add latency to every packet behind it.
	if seq <= _last_seq and _last_seq - seq < SEQ_REORDER_WINDOW:
		return
	_last_seq = seq
	_rx_queue.append(pcm)
	while _rx_queue.size() > MAX_RX_QUEUE:
		_rx_queue.pop_front()


@rpc("any_peer", "call_remote", "reliable", VOICE_STATE_CHANNEL)
func _voice_state(muted: bool) -> void:
	_peer_muted = muted
	_apply_peer_mute()


## The pose stream carries the same bit 30 times a second; this just covers the
## gap where the peer has joined but poses have not started flowing yet.
func _send_mute_state() -> void:
	if NetworkManager.is_active() and NetworkManager.peer_count() > 0:
		_voice_state.rpc(PlayerSettings.voice_muted)


# -- Playback ------------------------------------------------------------------

func _apply_peer_mute() -> void:
	if is_instance_valid(GameManager.remote_avatar):
		GameManager.remote_avatar.set_voice_muted(_peer_muted)


func _apply_voice_tuning() -> void:
	if _voice_player == null:
		return
	_voice_player.max_distance = float(GameManager.tuning.get("voice_max_distance", 26.0))
	_voice_player.unit_size = float(GameManager.tuning.get("voice_unit_size", 6.0))


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
