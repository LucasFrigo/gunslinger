class_name ScenarioBase
extends Node3D
## Contract for every scenario scene: must contain a PlayerSpawn Marker3D plus
## its own lighting/environment. Duel scenes also need an EnemySpawn facing the
## player; the practice hub has none. For 2 or 3 NPCs a duel scene holds
## `EnemySpawns2` / `EnemySpawns3` with that many Marker3D children (positions only;
## yaw is derived).
## Placeholder CSG in each scenario is throwaway; art passes start from a new
## detailed greybox, then Blender meshes. Keep PlayerSpawn and EnemySpawn.

## Strafers clamp to +-this world X around the lane. 0 means no clamp.
@export var strafe_half_width := 0.0

var scenario_resource: ScenarioResource

## Set before add_child. Negative leaves the authored sun and sky.
var time_of_day := -1.0

var _ambience_player: AudioStreamPlayer
var _sun_yaw := NAN
var _environment_detached := false


func _ready() -> void:
	assert(has_node("PlayerSpawn"), "%s is missing a PlayerSpawn Marker3D" % name)
	if scenario_resource != null and scenario_resource.ambience != null:
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.stream = scenario_resource.ambience
		_ambience_player.autoplay = true
		add_child(_ambience_player)
	# Invisible guard walls stop walkers, but a corpse limb must not rest on them in mid-air.
	for wall in find_children("Guard*", "StaticBody3D", true, false):
		wall.add_to_group(BodyRagdoll.IGNORE_GROUP)
	if time_of_day >= 0.0:
		apply_time(time_of_day)


## Recolor the outdoor sun and sky. Saloon has no Sun, so this is a no-op there.
## Fog distances and shadow fade stay on the scene.
func apply_time(t: float) -> void:
	time_of_day = clampf(t, 0.0, 1.0)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	if is_nan(_sun_yaw):
		var toward_sun := sun.global_transform.basis.z
		_sun_yaw = atan2(toward_sun.x, toward_sun.z)
	_detach_environment()
	TimeOfDay.apply(self, time_of_day, _sun_yaw)


func _detach_environment() -> void:
	if _environment_detached:
		return
	_environment_detached = true
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	world.environment = world.environment.duplicate(true)


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
