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
