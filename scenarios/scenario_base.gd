class_name ScenarioBase
extends Node3D
## Contract for every scenario scene: must contain a PlayerSpawn Marker3D plus
## its own lighting/environment. Duel scenes also need an EnemySpawn facing the
## player; the practice hub has none. For 2 or 3 NPCs a duel scene holds
## `EnemySpawns2` / `EnemySpawns3` with that many Marker3D children (positions only;
## yaw is derived).
## Placeholder CSG in each scenario is throwaway; art passes start from a new
## detailed greybox, then Blender meshes. Keep PlayerSpawn and EnemySpawn.

const CLOUD_COVER_MIN := 0.25
const CLOUD_COVER_MAX := 0.5
const DEFAULT_CLOUD_SPEED := 0.01
const WIND_OFF_DB := -60.0
const WIND_DUCK_DB := 8.0
const WIND_TICK := 0.25
const GUST_SIDE_MIN := 4.0
const GUST_SIDE_MAX := 8.0
const GUST_HEIGHT_MIN := 0.3
const GUST_HEIGHT_MAX := 1.4
## Gust swish sits this far under the strength-scaled level, so the bed stays the main wind.
const GUST_VOLUME_TRIM_DB := -6.0
## Sway (`world_surface.gdshader`): the always-on share of `gust_strength`, and one gust's
## pulse. The pulse lasts the dust sweep (`lifetime` in assets/vfx/wind_gust.tscn).
const WIND_AMBIENT_SHARE := 0.3
const GUST_PULSE_TIME := 1.8
const GUST_PULSE_RISE := 0.5

## The scenario that last wrote the wind globals. A swapped-out one is freed after its
## replacement is ready and must not zero what the new arena just set.
static var _wind_owner: ScenarioBase

## Strafers clamp to +-this world X around the lane. 0 means no clamp.
@export var strafe_half_width := 0.0
## False pins the clouds: the sky material's authored `cloud_cover` and `cloud_offset` stay,
## and the deck drifts along +x, instead of a roll per load.
@export var roll_clouds := true
## Cloud drift in deck-uv per second. Local only; 0 stops `_process`.
@export var cloud_speed := DEFAULT_CLOUD_SPEED

var scenario_resource: ScenarioResource

## Set before add_child. Negative leaves the authored sun and sky.
var time_of_day := -1.0

var _ambience_player: AudioStreamPlayer
var _sun_yaw := NAN
var _environment_detached := false
var _sky_material: ShaderMaterial
var _cloud_offset := Vector2.ZERO
var _cloud_dir := Vector2.RIGHT
var _wind_player: AudioStreamPlayer
var _wind_timer: Timer
var _wind_db := -80.0
var _wind_ducked := false
var _gusts_enabled := true
var _gust_interval_scale := 1.0
var _gust_left := 0.0
var _wind_ambient := 0.0
var _wind_gust := 0.0
var _gust_tween: Tween


func _ready() -> void:
	assert(has_node("PlayerSpawn"), "%s is missing a PlayerSpawn Marker3D" % name)
	set_process(false)
	if scenario_resource != null and scenario_resource.ambience != null:
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.stream = scenario_resource.ambience
		_ambience_player.autoplay = true
		add_child(_ambience_player)
	_start_wind()
	_wind_owner = self
	GameManager.tuning_changed.connect(_on_sway_tuning_changed)
	tree_exiting.connect(_release_wind)
	_push_wind()
	# Invisible guard walls stop walkers, but a corpse limb must not rest on them in mid-air.
	for wall in find_children("Guard*", "StaticBody3D", true, false):
		wall.add_to_group(BodyRagdoll.IGNORE_GROUP)
	# Body rim light: the authored sun's color, the warm default where there is no Sun.
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	TimeOfDay.set_edge(sun.light_color if sun != null else TimeOfDay.EDGE_DEFAULT)
	BulletTrail.solid = BulletTrail.DEFAULT_SOLID
	if time_of_day >= 0.0:
		apply_time(time_of_day)


## Recolor the outdoor sun and sky. Saloon has no Sun, so this is a no-op there.
## Fog distances and shadow fade stay on the scene.
func apply_time(t: float) -> void:
	time_of_day = clampf(t, 0.0, TimeOfDay.T_MAX)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	_detach_environment()
	if is_nan(_sun_yaw):
		var toward_sun := sun.global_transform.basis.z
		_sun_yaw = atan2(toward_sun.x, toward_sun.z)
		_roll_sky()
	TimeOfDay.apply(self, time_of_day, _sun_yaw)


## Drift the cloud deck. Enabled only while a sky shader exists and `cloud_speed > 0`.
func _process(delta: float) -> void:
	_cloud_offset = (_cloud_offset + _cloud_dir * cloud_speed * delta).posmod(1.0)
	_sky_material.set_shader_parameter(&"cloud_offset", _cloud_offset)


## F3 Sky group. The three setters do nothing where there is no sky shader (Saloon).
func set_cloud_cover(value: float) -> void:
	if _sky_material != null:
		_sky_material.set_shader_parameter(&"cloud_cover", value)


func set_cloud_speed(value: float) -> void:
	cloud_speed = maxf(value, 0.0)
	set_process(_sky_material != null and cloud_speed > 0.0)


func set_sun_radius(value: float) -> void:
	if _sky_material != null:
		_sky_material.set_shader_parameter(&"sun_radius", value)


func get_sky_float(param: StringName, fallback: float) -> float:
	if _sky_material == null:
		return fallback
	return float(_sky_material.get_shader_parameter(param))


## One roll per load: cover, offset, and drift direction, unless `roll_clouds` pins them.
## F3 time scrubs do not re-roll.
func _roll_sky() -> void:
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null or world.environment.sky == null:
		return
	_sky_material = world.environment.sky.sky_material as ShaderMaterial
	if _sky_material == null:
		return
	if roll_clouds:
		_cloud_offset = Vector2(randf(), randf())
		_cloud_dir = Vector2.from_angle(randf() * TAU)
		set_cloud_cover(randf_range(CLOUD_COVER_MIN, CLOUD_COVER_MAX))
	else:
		var authored: Variant = _sky_material.get_shader_parameter(&"cloud_offset")
		_cloud_offset = authored if authored is Vector2 else Vector2.ZERO
	_sky_material.set_shader_parameter(&"cloud_offset", _cloud_offset)
	set_cloud_speed(cloud_speed)


func _detach_environment() -> void:
	if _environment_detached:
		return
	_environment_detached = true
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	world.environment = world.environment.duplicate(true)


## F3 Wind group. All three do nothing where the arena has no wind (Saloon, menu backdrop).
func set_wind_volume(db: float) -> void:
	_wind_db = db
	if _wind_player != null:
		_wind_player.volume_db = _wind_bed_db()


func set_gust_interval(interval_scale: float) -> void:
	_gust_interval_scale = maxf(interval_scale, 0.1)


func set_gusts_enabled(on: bool) -> void:
	_gusts_enabled = on


## True once a bed or gusts were authored for this arena.
func has_wind() -> bool:
	return _wind_timer != null


func get_wind_volume() -> float:
	return _wind_db


## The sway the wind globals hold for this arena (0 where it has no wind).
func get_wind_ambient() -> float:
	return _wind_ambient


func get_wind_gust() -> float:
	return _wind_gust


## One gust now: dust crosses the lane from a side, with a panned swish at its origin.
func fire_gust() -> void:
	var strength := scenario_resource.gust_strength if scenario_resource != null else 1.0
	var spawn := get_player_spawn()
	var forward := -spawn.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var reach := scenario_resource.duel_distance * 0.5 if scenario_resource != null else 8.0
	var center := spawn.origin + forward * reach
	var side := forward.cross(Vector3.UP).normalized()
	var lateral := 1.0 if randf() < 0.5 else -1.0
	var origin := center + side * lateral * randf_range(GUST_SIDE_MIN, GUST_SIDE_MAX)
	origin.y = spawn.origin.y + randf_range(GUST_HEIGHT_MIN, GUST_HEIGHT_MAX)
	VfxCatalog.spawn(&"wind_gust", self, origin, -side * lateral, strength)
	_pulse_wind(strength)
	var player := AudioStreamPlayer3D.new()
	player.stream = AudioCatalog.get_stream(&"wind_gust")
	player.volume_db = linear_to_db(strength) + GUST_VOLUME_TRIM_DB
	player.max_distance = 60.0
	player.autoplay = true
	add_child(player)
	player.global_position = origin
	player.finished.connect(player.queue_free)


func _start_wind() -> void:
	var res := scenario_resource
	if res == null:
		return
	var bed := res.ambience == null and res.wind_volume_db > WIND_OFF_DB
	var gusts := res.gust_interval_max > 0.0
	if not bed and not gusts:
		return
	if bed:
		_wind_db = res.wind_volume_db
		_wind_player = AudioStreamPlayer.new()
		_wind_player.stream = AudioCatalog.get_stream(&"wind_bed")
		_wind_player.volume_db = _wind_bed_db()
		_wind_player.autoplay = true
		add_child(_wind_player)
	_gusts_enabled = gusts
	_roll_gust()
	_wind_timer = Timer.new()
	_wind_timer.wait_time = WIND_TICK
	_wind_timer.autostart = true
	_wind_timer.timeout.connect(_on_wind_tick)
	add_child(_wind_timer)


## Writes `wind_ambient` and `wind_gust` for `world_surface.gdshader`. Ambient is 0 where
## the arena has no wind, which also holds the menu backdrop and the Saloon still.
func _push_wind() -> void:
	_wind_ambient = 0.0
	if has_wind():
		var strength := scenario_resource.gust_strength if scenario_resource != null else 1.0
		_wind_ambient = clampf(WIND_AMBIENT_SHARE * strength, 0.0, 1.0) * _sway_scale()
	RenderingServer.global_shader_parameter_set(&"wind_ambient", _wind_ambient)
	RenderingServer.global_shader_parameter_set(&"wind_gust", _wind_gust)


func _sway_scale() -> float:
	return maxf(float(GameManager.tuning.get("sway_scale", 1.0)), 0.0)


## One gust's pulse over the dust sweep: up fast, then back to 0 by the time the dust is gone.
func _pulse_wind(strength: float) -> void:
	if not has_wind():
		return
	if _gust_tween != null and _gust_tween.is_valid():
		_gust_tween.kill()
	var peak := strength * _sway_scale()
	_gust_tween = create_tween()
	_gust_tween.tween_method(_set_wind_gust, 0.0, peak, GUST_PULSE_RISE) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_gust_tween.tween_method(_set_wind_gust, peak, 0.0, GUST_PULSE_TIME - GUST_PULSE_RISE) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_wind_gust(value: float) -> void:
	_wind_gust = value
	RenderingServer.global_shader_parameter_set(&"wind_gust", value)


func _on_sway_tuning_changed(key: String, _value: Variant) -> void:
	if key == "sway_scale" and _wind_owner == self:
		_push_wind()


func _release_wind() -> void:
	if _wind_owner != self:
		return
	_wind_owner = null
	RenderingServer.global_shader_parameter_set(&"wind_ambient", 0.0)
	RenderingServer.global_shader_parameter_set(&"wind_gust", 0.0)


func _wind_bed_db() -> float:
	return _wind_db - (WIND_DUCK_DB if _wind_ducked else 0.0)


func _roll_gust() -> void:
	var res := scenario_resource
	var lo := minf(res.gust_interval_min, res.gust_interval_max)
	_gust_left = randf_range(lo, res.gust_interval_max) * _gust_interval_scale


## Polls the death cam: the bed ducks and gusts hold off through death cam and replay.
func _on_wind_tick() -> void:
	var ducked := DeathCam.phase != DeathCam.Phase.IDLE
	if ducked != _wind_ducked:
		_wind_ducked = ducked
		if _wind_player != null:
			create_tween().tween_property(_wind_player, "volume_db", _wind_bed_db(), 0.6)
	if ducked or not _gusts_enabled or scenario_resource.gust_interval_max <= 0.0:
		return
	_gust_left -= WIND_TICK
	if _gust_left <= 0.0:
		fire_gust()
		_roll_gust()


## Flat main-menu backdrop eye points, each framed on the lane center (the midpoint of
## PlayerSpawn and EnemySpawn, like `get_enemy_spawns`). Empty when the scenario has no
## `MenuCameras` group yet; the caller falls back to PlayerSpawn.
func get_menu_cameras() -> Array[Transform3D]:
	var group := get_node_or_null("MenuCameras")
	if group == null:
		return []
	var center := (get_player_spawn().origin + get_enemy_spawn().origin) * 0.5
	var cameras: Array[Transform3D] = []
	for marker in group.get_children():
		if marker is Marker3D:
			cameras.append(Transform3D(Basis.IDENTITY, (marker as Marker3D).global_position)
					.looking_at(center, Vector3.UP))
	return cameras


func get_player_spawn() -> Transform3D:
	return ($PlayerSpawn as Marker3D).global_transform


func get_enemy_spawn() -> Transform3D:
	assert(has_node("EnemySpawn"), "%s is missing an EnemySpawn Marker3D" % name)
	return ($EnemySpawn as Marker3D).global_transform


## One spawn per NPC. One NPC uses EnemySpawn; more read the markers under
## EnemySpawns<count> and face the lane center (midpoint of PlayerSpawn and EnemySpawn).
func get_enemy_spawns(count: int) -> Array[Transform3D]:
	var spawns: Array[Transform3D] = []
	if count <= 1:
		spawns.append(get_enemy_spawn())
		return spawns
	var group := get_node_or_null("EnemySpawns%d" % count)
	assert(group != null and group.get_child_count() == count,
			"%s needs EnemySpawns%d with %d Marker3D children" % [name, count, count])
	var center := (get_player_spawn().origin + get_enemy_spawn().origin) * 0.5
	for marker in group.get_children():
		var origin := (marker as Marker3D).global_position
		var to_center := center - origin
		spawns.append(Transform3D(Basis(Vector3.UP, atan2(-to_center.x, -to_center.z)), origin))
	return spawns


## One spawn per duelist of a lobby, in ring order: PlayerSpawn, then
## `get_enemy_spawns(count - 1)`. Two duelists stand exactly where 1v1 does.
func get_duel_spawns(count: int) -> Array[Transform3D]:
	var spawns: Array[Transform3D] = [get_player_spawn()]
	spawns.append_array(get_enemy_spawns(count - 1))
	return spawns


## Horde: up to `count` markers at least `min_distance` (flat) from `avoid`, each facing
## `avoid`. Pool is EnemySpawn(s) at every supported count, deduped within 0.5 m. Fewer
## spawn if not enough markers clear the distance, but never zero: falls back to the
## single farthest marker.
func get_horde_spawns(count: int, avoid: Vector3, min_distance: float) -> Array[Transform3D]:
	var origins: Array[Vector3] = []
	var pool: Array[Vector3] = [get_enemy_spawn().origin]
	for n in [2, 3]:
		var group := get_node_or_null("EnemySpawns%d" % n)
		if group == null:
			continue
		for marker in group.get_children():
			pool.append((marker as Marker3D).global_position)
	for origin in pool:
		var dup := false
		for seen in origins:
			if seen.distance_to(origin) < 0.5:
				dup = true
				break
		if not dup:
			origins.append(origin)

	var far_flat := func(origin: Vector3) -> float:
		return Vector2(origin.x - avoid.x, origin.z - avoid.z).length()

	var clear: Array[Vector3] = []
	for origin in origins:
		if far_flat.call(origin) >= min_distance:
			clear.append(origin)
	if clear.is_empty() and not origins.is_empty():
		var farthest := origins[0]
		for origin in origins:
			if far_flat.call(origin) > far_flat.call(farthest):
				farthest = origin
		clear.append(farthest)

	var spawns: Array[Transform3D] = []
	for origin: Vector3 in clear.slice(0, count):
		var to_avoid: Vector3 = avoid - origin
		spawns.append(Transform3D(Basis(Vector3.UP, atan2(-to_avoid.x, -to_avoid.z)), origin))
	return spawns
