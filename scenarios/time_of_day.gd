class_name TimeOfDay
extends RefCounted
## Dawn-to-dusk samples for outdoor arenas. A load picks t in [0, 1] once.
## Only colors, sun elevation, and fog sun-scatter change. Fog distances,
## sky/ground curves, and shadow fade stay on the scene so a recolor cannot
## draw the canyon's 6 km edge or pop the train belt out of the fog.
## fog_light_color is always copied from ground_horizon_color after the lerp.

const DAWN_ELEVATION_DEG := 8.0
const NOON_ELEVATION_DEG := 70.0
const AFTERNOON_ELEVATION_DEG := 32.0
const DUSK_ELEVATION_DEG := 12.0

const KEYFRAMES: Array = [
	{
		"t": 0.0,
		"elevation_deg": DAWN_ELEVATION_DEG,
		"light_color": Color(1.0, 0.62, 0.42),
		"light_energy": 0.95,
		"sky_top": Color(0.22, 0.32, 0.55),
		"sky_horizon": Color(0.95, 0.62, 0.45),
		"ground_bottom": Color(0.32, 0.2, 0.14),
		"ground_horizon": Color(0.93, 0.6, 0.44),
		"fog_sun_scatter": 0.48,
	},
	{
		"t": 1.0 / 3.0,
		"elevation_deg": NOON_ELEVATION_DEG,
		"light_color": Color(1.0, 0.97, 0.9),
		"light_energy": 1.25,
		"sky_top": Color(0.28, 0.52, 0.92),
		"sky_horizon": Color(0.7, 0.8, 0.92),
		"ground_bottom": Color(0.42, 0.36, 0.26),
		"ground_horizon": Color(0.66, 0.74, 0.84),
		"fog_sun_scatter": 0.12,
	},
	{
		"t": 2.0 / 3.0,
		"elevation_deg": AFTERNOON_ELEVATION_DEG,
		"light_color": Color(1.0, 0.88, 0.68),
		"light_energy": 1.15,
		"sky_top": Color(0.32, 0.48, 0.82),
		"sky_horizon": Color(0.86, 0.74, 0.52),
		"ground_bottom": Color(0.4, 0.3, 0.18),
		"ground_horizon": Color(0.84, 0.7, 0.48),
		"fog_sun_scatter": 0.28,
	},
	{
		"t": 1.0,
		"elevation_deg": DUSK_ELEVATION_DEG,
		"light_color": Color(1.0, 0.58, 0.32),
		"light_energy": 0.9,
		"sky_top": Color(0.25, 0.15, 0.3),
		"sky_horizon": Color(0.95, 0.5, 0.25),
		"ground_bottom": Color(0.55, 0.28, 0.16),
		"ground_horizon": Color(0.95, 0.55, 0.28),
		"fog_sun_scatter": 0.4,
	},
]


## Recolor `root`'s Sun and procedural sky. No Sun means leave the scene
## alone (Saloon). `sun_yaw` is the authored azimuth, kept across samples.
static func apply(root: Node3D, t: float, sun_yaw: float) -> void:
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	var sample := _sample(t)
	_aim_sun(sun, float(sample["elevation_deg"]), sun_yaw)
	sun.light_color = sample["light_color"]
	sun.light_energy = float(sample["light_energy"])
	var world := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null or world.environment.sky == null:
		return
	var mat := world.environment.sky.sky_material as ProceduralSkyMaterial
	if mat == null:
		return
	mat.sky_top_color = sample["sky_top"]
	mat.sky_horizon_color = sample["sky_horizon"]
	mat.ground_bottom_color = sample["ground_bottom"]
	mat.ground_horizon_color = sample["ground_horizon"]
	# The opaque fog must be the sky ground, or the distant plain draws a line.
	world.environment.fog_light_color = mat.ground_horizon_color
	world.environment.fog_sun_scatter = float(sample["fog_sun_scatter"])


static func _sample(t: float) -> Dictionary:
	var time := clampf(t, 0.0, 1.0)
	var last: Dictionary = KEYFRAMES[KEYFRAMES.size() - 1]
	if time >= float(last["t"]):
		return last
	for i in KEYFRAMES.size() - 1:
		var a: Dictionary = KEYFRAMES[i]
		var b: Dictionary = KEYFRAMES[i + 1]
		var b_t := float(b["t"])
		if time > b_t:
			continue
		var span := b_t - float(a["t"])
		var u := 0.0 if span <= 0.0 else (time - float(a["t"])) / span
		return _lerp_frame(a, b, u)
	return last


static func _lerp_frame(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	return {
		"elevation_deg": lerpf(float(a["elevation_deg"]), float(b["elevation_deg"]), u),
		"light_color": (a["light_color"] as Color).lerp(b["light_color"], u),
		"light_energy": lerpf(float(a["light_energy"]), float(b["light_energy"]), u),
		"sky_top": (a["sky_top"] as Color).lerp(b["sky_top"], u),
		"sky_horizon": (a["sky_horizon"] as Color).lerp(b["sky_horizon"], u),
		"ground_bottom": (a["ground_bottom"] as Color).lerp(b["ground_bottom"], u),
		"ground_horizon": (a["ground_horizon"] as Color).lerp(b["ground_horizon"], u),
		"fog_sun_scatter": lerpf(float(a["fog_sun_scatter"]), float(b["fog_sun_scatter"]), u),
	}


## DirectionalLight3D shines along -Z, so +Z points at the sun.
static func _aim_sun(sun: DirectionalLight3D, elevation_deg: float, yaw: float) -> void:
	var elev := deg_to_rad(elevation_deg)
	var toward_sun := Vector3(sin(yaw) * cos(elev), sin(elev), cos(yaw) * cos(elev))
	sun.look_at(sun.global_position - toward_sun, Vector3.UP)
