class_name CombatRules
extends RefCounted
## Shared hit resolution: head is always lethal; torso/limbs subtract HP;
## surviving arm/leg hits apply status flags for the caller to enact.

const REGION_HEAD := &"head"
const REGION_TORSO := &"torso"
const REGION_ARM := &"arm"
const REGION_LEG := &"leg"

const DEFAULT_HEALTH := 2.0


static func player_max_health() -> float:
	if GameManager == null:
		return DEFAULT_HEALTH
	return float(GameManager.tuning.get("player_health", DEFAULT_HEALTH))


static func resolve(region: StringName, health: float, damage: float) -> Dictionary:
	if region == REGION_HEAD:
		return {"health": 0.0, "died": true, "disarm": false, "slow": false}
	var new_health := health - damage
	var died := new_health <= 0.0
	return {
		"health": new_health,
		"died": died,
		"disarm": (not died) and region == REGION_ARM,
		"slow": (not died) and region == REGION_LEG,
	}
