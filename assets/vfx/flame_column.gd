class_name FlameColumn
extends MeshInstance3D
## One flame column of the oil field, a child of a lit `Flame_*` anchor (`scenery_belt.gd`
## spawns it through `VfxCatalog` and calls `configure`). A unit quad scaled to the column and
## drawn by `flame_column.gdshader`, which turns it about its vertical axis to face the camera.
## It leans toward -x with `ScenarioBase.get_wind_gust()` as the engine smoke does. F3 World
## `flame_columns` (0 hides it) is its only knob. Local cosmetic, nothing on the wire.

## Share of the height the top leans at rest, and the extra at a full gust.
const LEAN_REST := 0.05
const LEAN_GUST := 0.08
const TUNING_KEY := "flame_columns"
## `width_slack` in the shader: the quad is this much wider than the base across.
const WIDTH_SLACK := 1.5

var _material: ShaderMaterial
var _arena: ScenarioBase


func _ready() -> void:
	# The sub-resource is shared by every instance; each column rolls on its own phase.
	_material = (material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_material.set_shader_parameter(&"seed", randf() * 64.0)
	_material.set_shader_parameter(&"width_slack", WIDTH_SLACK)
	material_override = _material
	var node := get_parent()
	while node != null and not node is ScenarioBase:
		node = node.get_parent()
	_arena = node as ScenarioBase
	GameManager.tuning_changed.connect(_on_tuning_changed)
	_apply_tuning()


## The column's base width and height in metres (sheet B, F14).
func configure(base_width: float, height: float) -> void:
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3(base_width * WIDTH_SLACK, height, 1.0)


func _process(_delta: float) -> void:
	var gust := _arena.get_wind_gust() if _arena != null else 0.0
	_material.set_shader_parameter(&"lean", LEAN_REST + LEAN_GUST * gust)


func _apply_tuning() -> void:
	visible = float(GameManager.tuning.get(TUNING_KEY, 1.0)) > 0.5
	set_process(visible)


func _on_tuning_changed(key: String, _value: Variant) -> void:
	if key == TUNING_KEY:
		_apply_tuning()
