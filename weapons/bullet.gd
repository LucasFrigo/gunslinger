class_name Bullet
extends Node3D
## A real slow projectile (not hitscan). Moves by manual integration so
## Engine.time_scale naturally slows it, raycasts its own path each physics
## step, feeds a BulletTrail, and triggers near-miss bullet-time when passing
## the local player's head.
##
## `authoritative` decides whether this instance can deal damage: true in
## single player, and true only on the HOST in multiplayer (remote clients
## see visual-only tracers).

const GROUP := "bullets"
const MAX_RANGE := 120.0
const NEAR_MISS_RADIUS := 0.45
const HIT_MASK := 0b101  # world + hitbox layers

static var _bullet_mesh: SphereMesh

var direction := Vector3.FORWARD
var speed := 55.0
var authoritative := true
var exclude: Array[RID] = []
var from_local_player := false
var self_hit_grace := 0.0

var _travelled := 0.0
var _trail: BulletTrail
var _near_miss_done := false
var _spawn_origin := Vector3.ZERO


static func spawn(parent: Node, origin: Vector3, dir: Vector3, bullet_speed: float,
		is_authoritative: bool, exclude_rids: Array[RID], local_shooter: bool,
		hit_grace := 0.0) -> Bullet:
	var bullet := Bullet.new()
	bullet.direction = dir.normalized()
	bullet.speed = bullet_speed
	bullet.authoritative = is_authoritative
	bullet.exclude = exclude_rids
	bullet.from_local_player = local_shooter
	bullet.self_hit_grace = hit_grace
	# Position must be known before `_ready`: that is when the trail records
	# its first point. `add_child` runs `_ready` immediately.
	bullet._spawn_origin = origin
	parent.add_child(bullet)
	return bullet


## Drop every in-flight bullet (e.g. on duel reset / return to menu).
## Finishes each trail first so `_clear_combatants` can then clear lingerers.
static func clear_all() -> void:
	if Engine.get_main_loop() is SceneTree:
		for node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(GROUP):
			(node as Bullet)._clear_for_reset()


func _ready() -> void:
	add_to_group(GROUP)
	global_position = _spawn_origin
	# Visible slug.
	if _bullet_mesh == null:
		_bullet_mesh = SphereMesh.new()
		_bullet_mesh.radius = 0.015
		_bullet_mesh.height = 0.03
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.9, 0.5)
		_bullet_mesh.material = mat
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _bullet_mesh
	add_child(mesh_instance)

	_trail = BulletTrail.new()
	get_tree().current_scene.add_child(_trail)
	_trail.add_point(global_position)


func _physics_process(delta: float) -> void:
	# Trail may have been freed by scene reset while this bullet still flies.
	if not is_instance_valid(_trail):
		queue_free()
		return

	var step := speed * delta
	var from := global_position
	var to := from + direction * step

	var space := get_world_3d().direct_space_state
	var remaining_from := from
	var hit: Dictionary = {}
	for _retry in 4:
		var query_exclude: Array[RID] = []
		if self_hit_grace <= 0.0:
			query_exclude = exclude
		var query := PhysicsRayQueryParameters3D.create(remaining_from, to, HIT_MASK, query_exclude)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		hit = space.intersect_ray(query)
		if hit.is_empty() or not _ignore_self_hit(hit):
			break
		remaining_from = hit["position"] + direction * 0.008
		if remaining_from.distance_squared_to(from) >= step * step:
			hit = {}
			break

	if not hit.is_empty():
		global_position = hit["position"]
		_trail.add_point(hit["position"])
		_on_impact(hit)
		return

	global_position = to
	_travelled += step
	_trail.add_point(to)
	_check_near_miss(from, to)

	if _travelled >= MAX_RANGE:
		_expire()


func _on_impact(hit: Dictionary) -> void:
	var collider: Object = hit.get("collider")
	var pos: Vector3 = hit.get("position", global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if collider is Hitbox:
		var hitbox := collider as Hitbox
		ImpactFeedback.body_impact(pos, normal, hitbox.region)
		if authoritative and is_instance_valid(_trail):
			var self_inflicted := from_local_player and hitbox.owner_entity == GameManager.local_player
			hitbox.receive_hit(_trail.points.duplicate(), self_inflicted)
	else:
		ImpactFeedback.world_impact(pos, normal)
	_expire()


func _expire() -> void:
	if is_instance_valid(_trail):
		_trail.finish()
	queue_free()


func _clear_for_reset() -> void:
	set_physics_process(false)
	if is_instance_valid(_trail):
		_trail.finish()
	_trail = null
	queue_free()


func _check_near_miss(from: Vector3, to: Vector3) -> void:
	if _near_miss_done or from_local_player:
		return
	var player := GameManager.local_player
	if not is_instance_valid(player):
		return
	var head: Vector3 = player.get_head_position()
	var closest := Geometry3D.get_closest_point_to_segment(head, from, to)
	if closest.distance_to(head) <= NEAR_MISS_RADIUS:
		_near_miss_done = true
		TimeManager.notify_near_miss()
		ImpactFeedback.near_miss(closest)


func _ignore_self_hit(hit: Dictionary) -> bool:
	if self_hit_grace <= 0.0 or exclude.is_empty():
		return false
	var pos: Vector3 = hit.get("position", global_position)
	if pos.distance_to(_spawn_origin) >= self_hit_grace:
		return false
	var collider: Object = hit.get("collider")
	if collider == null or not collider.has_method("get_rid"):
		return false
	return exclude.has(collider.get_rid())
