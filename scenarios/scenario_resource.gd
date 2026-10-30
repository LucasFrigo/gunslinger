class_name ScenarioResource
extends Resource
## Template describing a duel scenario. The scene must have a ScenarioBase
## root (spawn markers, lighting rig). Add the .tres path to
## GameManager.SCENARIOS to register it in all menus.

@export var display_name := "Scenario"
@export_multiline var description := ""
@export var scene: PackedScene
## Nominal distance between duelists, meters (informational; actual distance
## comes from the spawn markers).
@export_range(5.0, 60.0, 0.5) var duel_distance := 15.0
## Optional ambience loop, played while the scenario is active.
@export var ambience: AudioStream
## Procedural wind bed level, dB. -80 or lower is off. Ignored when `ambience` is set.
@export_range(-80.0, 0.0, 0.5) var wind_volume_db := -80.0
## Seconds between visual gusts, rolled in this range. 0 max means no gusts.
@export_range(0.0, 120.0, 0.5) var gust_interval_min := 0.0
@export_range(0.0, 120.0, 0.5) var gust_interval_max := 0.0
## Scales the gust's dust amount and volume.
@export_range(0.25, 3.0, 0.05) var gust_strength := 1.0
## A fixed `TimeOfDay` t (up to `TimeOfDay.T_MAX`, past dusk) used on every load, the MP
## host's included. Negative rolls dawn to dusk per load.
@export_range(-1.0, 1.25, 0.01) var fixed_time_of_day := -1.0


## The t a fresh load of this arena takes: the fixed one, or a roll in [0, 1).
func roll_time_of_day() -> float:
	return fixed_time_of_day if fixed_time_of_day >= 0.0 else randf()
