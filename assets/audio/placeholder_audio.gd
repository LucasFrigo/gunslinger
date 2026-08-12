class_name PlaceholderAudio
extends RefCounted
## Procedurally generated placeholder sounds so the game is audible before any
## real audio assets are dropped into assets/audio/. Replace usages with
## AudioStream files as assets arrive.

const SAMPLE_RATE := 22050

static var _cache: Dictionary = {}


static func gunshot() -> AudioStreamWAV:
	return _cached("gunshot", func() -> AudioStreamWAV:
		return _noise_burst(0.25, 1.0, 18.0))


static func whizz() -> AudioStreamWAV:
	return _cached("whizz", func() -> AudioStreamWAV:
		return _noise_burst(0.18, 0.35, 9.0, 2200.0))


static func bell() -> AudioStreamWAV:
	return _cached("bell", func() -> AudioStreamWAV:
		return _tone(880.0, 1.2, 0.5, 4.0))


static func click() -> AudioStreamWAV:
	return _cached("click", func() -> AudioStreamWAV:
		return _noise_burst(0.03, 0.4, 60.0))


static func dry_fire() -> AudioStreamWAV:
	return _cached("dry_fire", func() -> AudioStreamWAV:
		return _tone(320.0, 0.06, 0.3, 40.0))


static func impact_flesh() -> AudioStreamWAV:
	return _cached("impact_flesh", func() -> AudioStreamWAV:
		return _noise_burst(0.14, 0.75, 22.0, 180.0))


static func impact_world() -> AudioStreamWAV:
	return _cached("impact_world", func() -> AudioStreamWAV:
		return _noise_burst(0.12, 0.55, 28.0, 90.0))


static func ricochet() -> AudioStreamWAV:
	return _cached("ricochet", func() -> AudioStreamWAV:
		return _noise_burst(0.08, 0.4, 35.0, 2400.0))


static func hurt() -> AudioStreamWAV:
	return _cached("hurt", func() -> AudioStreamWAV:
		return _noise_burst(0.2, 0.65, 14.0, 140.0))


static func near_miss_whoosh() -> AudioStreamWAV:
	return _cached("near_miss_whoosh", func() -> AudioStreamWAV:
		return _noise_burst(0.22, 0.3, 8.0, 1600.0))


static func _cached(key: String, generator: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = generator.call()
	return _cache[key]


static func _noise_burst(duration: float, volume: float, decay: float, tone_hz := 0.0) -> AudioStreamWAV:
	var frames := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-decay * t)
		var sample := rng.randf_range(-1.0, 1.0)
		if tone_hz > 0.0:
			sample = 0.5 * sample + 0.5 * sin(TAU * tone_hz * t * (1.0 - 0.3 * t))
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	return _wav(data)


static func _tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var frames := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-decay * t)
		var sample := sin(TAU * freq * t) + 0.4 * sin(TAU * freq * 2.7 * t)
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
