class_name CombatHaptics
extends RefCounted
## Maps combat events to XRToolsRumbleManager and flat-mode joy vibration.
## Shooting / catch hand is the holding controller (`left_hand` / `right_hand`).

const FIRE_EVENT := preload("res://assets/haptics/fire_rumble.tres")
const NEAR_MISS_EVENT := preload("res://assets/haptics/near_miss_rumble.tres")
const HURT_EVENT := preload("res://assets/haptics/hurt_rumble.tres")
const DEATH_EVENT := preload("res://assets/haptics/death_rumble.tres")

const RIGHT := &"right_hand"
const LEFT := &"left_hand"


static func fire(shooting_hand: StringName = RIGHT) -> void:
	_pulse("combat_fire", FIRE_EVENT, [shooting_hand], 0.35, 0.7, 0.08)


static func catch_gun(hand: StringName) -> void:
	_pulse("gun_catch", NEAR_MISS_EVENT, [hand], 0.2, 0.4, 0.08)


static func near_miss() -> void:
	_pulse("combat_near_miss", NEAR_MISS_EVENT, [LEFT, RIGHT], 0.25, 0.45, 0.18)


static func hurt(is_fatal: bool) -> void:
	if is_fatal:
		_pulse("combat_death", DEATH_EVENT, [LEFT, RIGHT], 0.6, 1.0, 0.45)
	else:
		_pulse("combat_hurt", HURT_EVENT, [LEFT, RIGHT], 0.4, 0.85, 0.22)


static func _pulse(
		key: StringName,
		event: XRToolsRumbleEvent,
		trackers: Array,
		flat_weak: float,
		flat_strong: float,
		flat_duration: float
	) -> void:
	if XRToolsRumbleManager != null:
		XRToolsRumbleManager.add(key, event, trackers)
	# Flat / gamepad fallback (no-op if no pad connected).
	Input.start_joy_vibration(0, flat_weak, flat_strong, flat_duration)
