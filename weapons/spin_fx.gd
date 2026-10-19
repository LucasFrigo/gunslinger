class_name SpinFx
extends MeshInstance3D
## Spin effect on a twirling revolver: one static quad in the plane the blaster turns in,
## centered on SpinPivot. The shader draws a smear wedge under tapering ink arcs; `spin_fx_mode`
## is 0 off, anything else on.

const SHADER := preload("res://weapons/spin_fx.gdshader")
const HALF_SIZE := 0.25
## Visual turn rate (rad/s) below which the effect is hidden, and where it is at full strength.
const MIN_SPEED := 4.0
const FULL_SPEED := 14.0

var _gun: WeaponBase
var _material: ShaderMaterial
var _rest_angle := 0.0


## Same material as the live quad so boot warmup compiles the shader.
static func make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"half_size", HALF_SIZE)
	return mat


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * HALF_SIZE * 2.0
	mesh = quad
	_material = make_material()
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Quad +X is the gun's forward (-Z), so its normal is the spin axis (gun X).
	rotation = Vector3(0.0, PI * 0.5, 0.0)
	visible = false


func _ready() -> void:
	_gun = get_parent() as WeaponBase
	var pivot := _gun.get_node_or_null("SpinPivot") as Node3D
	var muzzle := _gun.get_node_or_null("Muzzle") as Node3D
	if pivot != null:
		position = pivot.position
		if muzzle != null:
			var tip := muzzle.position - pivot.position
			_rest_angle = atan2(tip.y, -tip.z)
			_material.set_shader_parameter(&"tip_radius", Vector2(tip.y, tip.z).length())


func _process(_delta: float) -> void:
	var mode := int(GameManager.tuning.get("spin_fx_mode", 1))
	var speed := _gun.twirl_speed
	visible = mode != 0 and _gun.is_twirling() and absf(speed) >= MIN_SPEED
	if not visible:
		return
	_material.set_shader_parameter(&"head_angle", _rest_angle + _gun.twirl_angle)
	_material.set_shader_parameter(&"omega", speed)
	_material.set_shader_parameter(&"fade", clampf(inverse_lerp(MIN_SPEED, FULL_SPEED, absf(speed)), 0.0, 1.0))
