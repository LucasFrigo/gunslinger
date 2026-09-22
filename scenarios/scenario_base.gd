class_name ScenarioBase
extends Node3D
## Contract for every scenario scene: must contain PlayerSpawn and EnemySpawn
## Marker3D children (facing each other), plus its own lighting/environment.
## Placeholder CSG in each scenario is throwaway; art passes start from a new
## detailed greybox, then Blender meshes. Keep PlayerSpawn and EnemySpawn.

var scenario_resource: ScenarioResource

## Set before add_child. Negative leaves the authored sun and sky.
var time_of_day := -1.0

var _ambience_player: AudioStreamPlayer
var _sun_yaw := NAN
var _environment_detached := false


func _ready() -> void:
	assert(has_node("PlayerSpawn"), "%s is missing a PlayerSpawn Marker3D" % name)
	assert(has_node("EnemySpawn"), "%s is missing an EnemySpawn Marker3D" % name)
	if scenario_resource != null and scenario_resource.ambience != null:
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.stream = scenario_resource.ambience
		_ambience_player.autoplay = true
		add_child(_ambience_player)
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
	return ($EnemySpawn as Marker3D).global_transform
