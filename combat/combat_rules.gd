class_name CombatRules
extends RefCounted
## Shared hit resolution: head is always lethal; torso/limbs subtract HP;
## surviving arm/leg hits apply status flags for the caller to enact. Only the gun arm
## disarms; the off arm takes damage only.

const REGION_HEAD := &"head"
const REGION_TORSO := &"torso"
const REGION_ARM := &"arm"
const REGION_LEG := &"leg"

const DEFAULT_HEALTH := 2.0


static func player_max_health() -> float:
	if GameManager == null:
		return DEFAULT_HEALTH
	return float(GameManager.tuning.get("player_health", DEFAULT_HEALTH))


## `side` is the arm hit (`Hitbox.side`), `gun_side` the arm on the gun or the draw.
## Either one empty reads as the gun arm.
static func is_gun_arm(side: StringName, gun_side: StringName) -> bool:
	return side == &"" or gun_side == &"" or side == gun_side


static func resolve(region: StringName, health: float, damage: float, gun_arm := true) -> Dictionary:
	if region == REGION_HEAD:
		return {"health": 0.0, "died": true, "disarm": false, "slow": false}
	var new_health := health - damage
	var died := new_health <= 0.0
	return {
		"health": new_health,
		"died": died,
		"disarm": (not died) and region == REGION_ARM and gun_arm,
		"slow": (not died) and region == REGION_LEG,
	}
