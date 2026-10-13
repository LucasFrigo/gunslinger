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
