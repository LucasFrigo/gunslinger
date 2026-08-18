extends Node
## Autoload. Customizable slow motion for A/B testing which speed feels best.
## Drives Engine.time_scale and AudioServer.playback_speed_scale. XR head
## tracking is unaffected by time_scale, which produces the Superhot feel.
## Gameplay modes are SP-only; kill-cam burst is allowed in MP after RESOLUTION.

signal mode_changed(mode: int)
signal scale_changed(scale: float)

enum Mode {
	OFF,        ## Normal time.
	CONSTANT,   ## Always slowed.
	ON_DRAW,    ## Slows when the enemy starts drawing.
	MOVEMENT,   ## Superhot: time speed follows your head/hand speed.
	NEAR_MISS,  ## Bullet-time burst when a bullet passes near your head.
}

const CONFIG_PATH := "user://slowmo.cfg"
const MIN_SCALE := 0.05

var mode: int = Mode.ON_DRAW:
	set(value):
		mode = value
		mode_changed.emit(mode)
		_save_config()

## Tunables -- all live-editable from the debug menu.
var constant_factor := 0.35
var on_draw_factor := 0.25
var on_draw_duration := 2.0
var movement_min_factor := 0.12
var movement_full_speed := 2.5   ## m/s of combined head+hand motion for 100% time
var near_miss_factor := 0.2
var near_miss_duration := 0.7
var kill_cam_factor := 0.15
var kill_cam_duration := 2.2
var ramp_speed := 6.0            ## how fast time scale eases toward its target

var current_scale := 1.0
var _burst_time_left := 0.0
var _burst_factor := 1.0
var _kill_cam_burst := false
var _reported_motion := 0.0
var _save_timer := 0.0
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()


func _process(delta: float) -> void:
	# Timers must run in real time, not scaled time.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)

	if _burst_time_left > 0.0:
		_burst_time_left -= real_delta
		if _burst_time_left <= 0.0:
			_kill_cam_burst = false

	var target := _target_scale()
	current_scale = lerpf(current_scale, target, clampf(ramp_speed * real_delta, 0.0, 1.0))
	if absf(current_scale - target) < 0.005:
		current_scale = target
	current_scale = clampf(current_scale, MIN_SCALE, 1.0)

	if not is_equal_approx(Engine.time_scale, current_scale):
		Engine.time_scale = current_scale
		AudioServer.playback_speed_scale = current_scale
		scale_changed.emit(current_scale)

	_reported_motion = 0.0

	if _dirty:
		_save_timer += real_delta
		if _save_timer > 1.0:
			_flush_config()


func _target_scale() -> float:
	# Kill-cam burst is presentation-only (SP + MP). Other slow-mo is SP only.
	if _burst_time_left > 0.0 and (_kill_cam_burst or not NetworkManager.is_active()):
		return _burst_factor
	if NetworkManager.is_active():
		return 1.0
	match mode:
		Mode.CONSTANT:
			return constant_factor
		Mode.MOVEMENT:
			var t := clampf(_reported_motion / maxf(movement_full_speed, 0.01), 0.0, 1.0)
			return lerpf(movement_min_factor, 1.0, t)
	return 1.0


# -- Gameplay hooks ----------------------------------------------------------

## Called every frame by the local player rig with combined head+hand speed (m/s).
func report_player_motion(speed: float) -> void:
	_reported_motion = maxf(_reported_motion, speed)


## Called when an AI/remote enemy begins its draw.
func notify_enemy_draw() -> void:
	if mode == Mode.ON_DRAW:
		_burst_factor = on_draw_factor
		_burst_time_left = on_draw_duration


## Called by bullets that pass close to the local player's head.
func notify_near_miss() -> void:
	if mode == Mode.NEAR_MISS:
		_burst_factor = near_miss_factor
		_burst_time_left = near_miss_duration


## Forced slow-mo burst for kill-cam presentation (any Mode; allowed in MP).
func notify_kill_cam() -> void:
	_kill_cam_burst = true
	_burst_factor = kill_cam_factor
	_burst_time_left = kill_cam_duration


func reset() -> void:
	_kill_cam_burst = false
	_burst_time_left = 0.0
	current_scale = 1.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0


# -- Tunable access for the debug menu ---------------------------------------

const TUNABLES := [
	"constant_factor", "on_draw_factor", "on_draw_duration",
	"movement_min_factor", "movement_full_speed",
	"near_miss_factor", "near_miss_duration",
	"kill_cam_factor", "kill_cam_duration", "ramp_speed",
]


func set_tunable(property: String, value: float) -> void:
	if property in TUNABLES:
		set(property, value)
		_dirty = true


# -- Persistence --------------------------------------------------------------

func _save_config() -> void:
	_dirty = true


func _flush_config() -> void:
	_dirty = false
	_save_timer = 0.0
	var cfg := ConfigFile.new()
	cfg.set_value("slowmo", "mode", mode)
	for property in TUNABLES:
		cfg.set_value("slowmo", property, get(property))
	cfg.save(CONFIG_PATH)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	mode = cfg.get_value("slowmo", "mode", mode)
	for property in TUNABLES:
		set(property, cfg.get_value("slowmo", property, get(property)))
	_dirty = false
