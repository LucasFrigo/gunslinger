class_name DuelEncounter
extends Resource
## One rung of the gauntlet ladder: which enemy, where, and with what modifiers.

@export var label := "Duel"
@export var archetype: AIArchetype
## Index into GameManager.SCENARIOS.
@export_range(0, 16) var scenario_index := 0
## Multiplier on the archetype's health (tanky bosses etc.).
@export_range(0.25, 5.0, 0.05) var health_mult := 1.0
@export var score_reward := 100
