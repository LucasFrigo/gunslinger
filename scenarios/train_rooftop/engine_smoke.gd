extends GPUParticles3D
## The 3:10's stack plume. F3 `engine_smoke_density` thins or thickens it by particle count
## only. A wind gust leans the plume further off the left side. Local only, no net sync.

## Gravity push (m/s^2) toward -X at a full gust pulse (`ScenarioBase.get_wind_gust()`).
const GUST_SHOVE := 3.0
## `amount` holds this many times the default count, so the knob never restarts the system.
const DENSITY_MAX := 3.0

## Puff tint (unshaded). The default is `engine_smoke.tscn`'s silver; a night arena sets a dark one.
@export var puff_color := Color(0.561, 0.549, 0.525)

var _base_gravity := Vector3.ZERO
var _material: ParticleProcessMaterial
var _arena: ScenarioBase


func _ready() -> void:
	# The sub-resource is shared by every instance, and a swapped arena briefly outlives the new one.
	_material = (process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	process_material = _material
	_material.color = puff_color
	_base_gravity = _material.gravity
	_arena = get_parent() as ScenarioBase
	_apply_density()
	GameManager.tuning_changed.connect(_on_tuning_changed)


func _process(_delta: float) -> void:
	var gust := _arena.get_wind_gust() if _arena != null else 0.0
	_material.gravity = _base_gravity + Vector3(-GUST_SHOVE * gust, 0.0, 0.0)


func _apply_density() -> void:
	var density := float(GameManager.tuning["engine_smoke_density"])
	amount_ratio = clampf(density / DENSITY_MAX, 0.0, 1.0)
	emitting = density > 0.0


func _on_tuning_changed(key: String, _value: Variant) -> void:
	if key == "engine_smoke_density":
		_apply_density()
