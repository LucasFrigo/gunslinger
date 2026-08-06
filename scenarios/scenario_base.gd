class_name ScenarioBase
extends Node3D
## Contract for every scenario scene: must contain PlayerSpawn and EnemySpawn
## Marker3D children (facing each other), plus its own lighting/environment.
## Greybox geometry is built from CSG nodes named after the asset that will
## eventually replace it (e.g. "BLD_Saloon" -> saloon building model).

var scenario_resource: ScenarioResource

var _ambience_player: AudioStreamPlayer


func _ready() -> void:
	assert(has_node("PlayerSpawn"), "%s is missing a PlayerSpawn Marker3D" % name)
	assert(has_node("EnemySpawn"), "%s is missing an EnemySpawn Marker3D" % name)
	if scenario_resource != null and scenario_resource.ambience != null:
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.stream = scenario_resource.ambience
		_ambience_player.autoplay = true
		add_child(_ambience_player)


func get_player_spawn() -> Transform3D:
	return ($PlayerSpawn as Marker3D).global_transform


func get_enemy_spawn() -> Transform3D:
	return ($EnemySpawn as Marker3D).global_transform
