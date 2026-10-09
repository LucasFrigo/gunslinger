class_name HordeWaves
extends Resource
## Horde mode's wave table. Reuses the gauntlet rung type (`DuelEncounter`) for each
## wave's lineup; `scenario_index` and `score_reward` on those rungs are ignored — the
## arena comes from the Horde menu row, and Horde scores its own way (see below).
## After the last authored wave the table loops: every slot promotes one archetype
## tier (weakest -> strongest along `GameManager.ARCHETYPES`, capped at the last tier)
## and every NPC gets faster by `loop_speed_step` per loop.

## Ordered weakest -> strongest. A wave's archetypes are promoted along this same order.
@export var waves: Array[DuelEncounter] = []

@export var kill_points := 100
@export var headshot_bonus := 50
@export var wave_bonus := 100
## Extra speed multiplier per loop through the table (loop 1 = +this, loop 2 = +2x, ...).
@export var loop_speed_step := 0.1
## Real-time break between a wave clear and the next standoff.
@export var break_seconds := 3.0
## Flat distance (m) a horde spawn marker must clear from the player.
@export var spawn_min_distance := 4.0


## The lineup for `wave` (1-based): the matching authored rung, with every slot
## promoted one archetype tier per loop through the table. Anything not found in
## `GameManager.ARCHETYPES` (a custom/boss archetype) is left alone.
func lineup_for(wave: int) -> Array[AIArchetype]:
	if waves.is_empty():
		return []
	var entry := waves[(wave - 1) % waves.size()]
	var loop := _loop_for(wave)
	var lineup := entry.lineup()
	if loop <= 0:
		return lineup
	var promoted: Array[AIArchetype] = []
	for archetype in lineup:
		promoted.append(_promote(archetype, loop))
	return promoted


## Speed multiplier for `wave`: 1.0 on the first pass through the table, then
## `+loop_speed_step` per full loop.
func speed_for(wave: int) -> float:
	return 1.0 + float(_loop_for(wave)) * loop_speed_step


func _loop_for(wave: int) -> int:
	if waves.is_empty():
		return 0
	return (wave - 1) / waves.size()


func _promote(archetype: AIArchetype, loop: int) -> AIArchetype:
	var tiers := GameManager.ARCHETYPES
	var index := -1
	for i in tiers.size():
		if load(tiers[i]) == archetype:
			index = i
			break
	if index < 0:
		return archetype
	return load(tiers[clampi(index + loop, 0, tiers.size() - 1)])
