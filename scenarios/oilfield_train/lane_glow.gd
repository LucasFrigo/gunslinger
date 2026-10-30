class_name LaneGlow
extends OmniLight3D
## The oil field's firelight over mid-lane (docs/design/scenarios/oilfield_train.md A): its
## energy flickers ±15% on a 2 to 6 Hz noise and the fog colour flickers ±8% with it. One energy write
## a frame. It also keeps the `smoke_fog_color` global (what `M_Smoke` plumes and the flame columns
## fade to past their distance ramp) at the sky's colour, not the fog's. Local cosmetic, nothing on the wire.

const FLICKER := 0.15
const FOG_FLICKER := 0.08
## Three sines inside 2 to 6 Hz, not multiples of each other; their mean is the noise.
const FLICKER_HZ: Array[float] = [2.3, 3.7, 5.3]
## A passing burning well adds up to this share of `base_energy` at abeam (F10), falling by a squared
## cosine of its z offset from the light to nothing at `SWELL_RANGE` metres either side.
const SWELL_MAX := 0.6
const SWELL_RANGE := 60.0
## Elevation of the sky colour the plumes and columns fade to: where a far plume's top stands (110 m
## up at 400 m is 15 degrees, its foot near 3). Fogged to the haze colour they read as orange pillars
## against the plum sky (sheet H, `oilfield_horizon`); at the sky's own value they dissolve into it.
const SMOKE_SKY_DEG := 15.0

@export var base_energy := 1.2

## 0 to 1: how far abeam the nearer `Flame_Near` is. The belt writes it each frame (`update_swell`);
## 1 is +60%.
var swell := 0.0

var _phases := PackedFloat32Array()
var _world: WorldEnvironment
var _fog_base := Color.BLACK
var _fog_written := Color.BLACK
var _has_fog_base := false
var _smoke_written := Color.BLACK


func _ready() -> void:
	for i in FLICKER_HZ.size():
		_phases.append(randf() * TAU)
	# A sibling; `ScenarioBase` swaps in a copy of its environment, so read it each frame.
	_world = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	light_energy = base_energy


## The swell (0 to 1) for a burning well `dz` metres from the light along z: cos² of a quarter turn
## over `SWELL_RANGE`, so 1 abeam and 0 (flat, no kink) at the range and beyond.
static func swell_at(dz: float) -> float:
	var d := absf(dz)
	if d >= SWELL_RANGE:
		return 0.0
	return pow(cos(0.5 * PI * d / SWELL_RANGE), 2.0)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var noise := 0.0
	for i in FLICKER_HZ.size():
		noise += sin(TAU * FLICKER_HZ[i] * now + _phases[i])
	noise /= float(FLICKER_HZ.size())
	light_energy = base_energy * (1.0 + SWELL_MAX * clampf(swell, 0.0, 1.0)) * (1.0 + FLICKER * noise)
	var env := _world.environment if _world != null else null
	if env == null:
		return
	_write_smoke_color(env)
	# TimeOfDay (or an F3 scrub) wrote a new fog colour since the last flicker: that is the base.
	if not _has_fog_base or not env.fog_light_color.is_equal_approx(_fog_written):
		_fog_base = env.fog_light_color
		_has_fog_base = true
	var k := 1.0 + FOG_FLICKER * noise
	_fog_written = Color(_fog_base.r * k, _fog_base.g * k, _fog_base.b * k, _fog_base.a)
	env.fog_light_color = _fog_written


## `sky_western.gdshader`'s gradient at `SMOKE_SKY_DEG`, written when it changes (an F3 scrub).
func _write_smoke_color(env: Environment) -> void:
	var sky := env.sky.sky_material as ShaderMaterial if env.sky != null else null
	if sky == null:
		return
	var curve := float(sky.get_shader_parameter(&"sky_curve"))
	var up := deg_to_rad(SMOKE_SKY_DEG) / (PI * 0.5)
	var mix_t := clampf(1.0 - pow(1.0 - up, 1.0 / maxf(curve, 0.001)), 0.0, 1.0)
	var top: Color = sky.get_shader_parameter(&"sky_top")
	var horizon: Color = sky.get_shader_parameter(&"sky_horizon")
	# The sky shader mixes in linear light.
	var color := horizon.srgb_to_linear().lerp(top.srgb_to_linear(), mix_t).linear_to_srgb()
	if not color.is_equal_approx(_smoke_written):
		_smoke_written = color
		RenderingServer.global_shader_parameter_set(&"smoke_fog_color", color)
