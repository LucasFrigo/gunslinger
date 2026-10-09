class_name Hitbox
extends Area3D
## Damage-receiving zone (head/torso/limb). Bullets raycast against these.
## The entity that owns this hitbox must implement
## take_bullet_hit(damage, trail_points, region, self_inflicted, shooter_is_local, shooter, cut).
## `region` drives AV feedback and CombatRules (head kill, arm disarm, leg slow).
## Damage is ignored unless `DuelManager.accepts_hit()` (DRAW, or NPCs fighting after a loss).
## `cut` is the hole the hit makes where the bullet landed (`DummyBody.cut_at`, rolled on
## `chunk_chance` here, on the authority), or `{}`. The owner applies it after its own gates.
##
## The shapes are built and moved by `BodyHitboxes` from the posed mannequin bones.
## The arm node holds an upper-arm and a forearm capsule; the gun-hand forearm is
## thinner and stops short of the grip so a forward muzzle shot does not clip it.

const GROUP := &"hitboxes"
const VIZ_NAME := "_HitboxViz"

@export_range(0.1, 4.0, 0.05) var damage_mult := 1.0
@export var region: StringName = &"torso"

var owner_entity: Node
## Skip the F3 view. The local head volume surrounds the camera.
var exclude_debug := false


func _init() -> void:
	collision_layer = 0b100  # hitbox layer (3)
	collision_mask = 0
	monitoring = false
	monitorable = true


func _ready() -> void:
	add_to_group(GROUP)
	set_debug_visible(DebugMenu.show_hitboxes)


## True for a dead NPC, or the local player after an SP death. Bullets fly through these.
func is_corpse() -> bool:
	if owner_entity is DuelistAI:
		return (owner_entity as DuelistAI).state == DuelistAI.AIState.DEAD
	if owner_entity is Player and not NetworkManager.is_active():
		return not (owner_entity as Player).alive
	return false


## `shape_index` is the ray hit's shape on this area; it picks the cut's bone. The impact
## is the trail's last point.
func receive_hit(trail_points: PackedVector3Array, self_inflicted := false,
		shooter_is_local := false, shooter := -1, shape_index := -1) -> void:
	if GameManager == null or GameManager.duel == null or not GameManager.duel.accepts_hit(owner_entity, shooter):
		return
	if owner_entity == null or not owner_entity.has_method("take_bullet_hit"):
		return
	var cut := {}
	if shape_index >= 0 and not trail_points.is_empty() and owner_entity.has_method("corpse_body") \
			and BodyChunks.roll():
		var body: DummyBody = owner_entity.corpse_body()
		if body != null:
			cut = body.cut_at(shape_owner_get_owner(shape_find_owner(shape_index)),
					trail_points[trail_points.size() - 1], DummyBody.shot_dir(trail_points), region)
	owner_entity.take_bullet_hit(damage_mult, trail_points, region, self_inflicted, shooter_is_local,
			shooter, cut)


# -- F3 "Show hitboxes" ---------------------------------------------------------

func set_debug_visible(enabled: bool) -> void:
	set_process(enabled)
	if enabled:
		_sync_debug()
	else:
		_clear_debug()


func _process(_delta: float) -> void:
	_sync_debug()


## One translucent mesh per shape node. Shapes are made after `_ready` and resize with
## the limb, so the mesh is rebuilt whenever its shape key changes.
func _sync_debug() -> void:
	if exclude_debug:
		_clear_debug()
		return
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		var key := _shape_key(shape_node.shape)
		var viz := shape_node.get_node_or_null(VIZ_NAME) as MeshInstance3D
		if viz != null and viz.get_meta(&"key") == key:
			continue
		if viz == null:
			viz = MeshInstance3D.new()
			viz.name = VIZ_NAME
			viz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			viz.material_override = _viz_material()
			shape_node.add_child(viz)
		viz.mesh = DebugMenu.mesh_for_shape(shape_node.shape)
		viz.set_meta(&"key", key)


func _clear_debug() -> void:
	for child in get_children():
		var viz := child.get_node_or_null(VIZ_NAME)
		if viz != null:
			viz.queue_free()


func _shape_key(shape: Shape3D) -> Vector2:
	if shape is CapsuleShape3D:
		return Vector2((shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height)
	if shape is SphereShape3D:
		return Vector2((shape as SphereShape3D).radius, 0.0)
	return Vector2.ZERO


func _viz_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = _region_color()
	return mat


func _region_color() -> Color:
	match region:
		CombatRules.REGION_HEAD:
			return Color(1.0, 0.2, 0.2, 0.3)
		CombatRules.REGION_ARM:
			return Color(0.25, 0.55, 1.0, 0.3)
		CombatRules.REGION_LEG:
			return Color(0.25, 0.9, 0.35, 0.3)
	return Color(1.0, 0.6, 0.2, 0.3)
