class_name DuelEncounter
extends Resource
## One rung of the gauntlet ladder: which enemy, where, and with what modifiers.

@export var label := "Duel"
@export var archetype: AIArchetype
## Further NPCs that share the standoff with `archetype` (rung 7 and up).
@export var extra_archetypes: Array[AIArchetype] = []
## Index into GameManager.SCENARIOS.
@export_range(0, 16) var scenario_index := 0
## Multiplier on the archetype's health (tanky bosses etc.).
@export_range(0.25, 5.0, 0.05) var health_mult := 1.0
@export var score_reward := 100


## Every NPC of the rung, `archetype` first.
func lineup() -> Array[AIArchetype]:
	var all: Array[AIArchetype] = [archetype]
	all.append_array(extra_archetypes)
	return all
