class_name PropFlight
extends Object
## Kinematic query for a thrown off-hand prop. Held meshes stay shapeless so
## they never sit on a physics layer; only the step they are about to travel
## is tested. Mask is world + glass (rail bottles and the off-hand longneck),
## the same pair bullets use minus the hitbox bit.

const HIT_MASK := 0b1000001


static func cast(world: World3D, from: Vector3, to: Vector3) -> Dictionary:
	if world == null or from.distance_squared_to(to) < 0.00000001:
		return {}
	var space := world.direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


static func is_bottle(hit: Dictionary) -> bool:
	return is_glass(hit.get("collider"))


## If `body` has fallen through a world surface, lift it back onto the hit.
static func snap_out_of_ground(body: RigidBody3D, half_height: float) -> void:
	if body == null or body.freeze:
		return
	var world := body.get_world_3d()
	if world == null:
		return
	var from := body.global_position + Vector3.UP * 4.0
	var to := body.global_position + Vector3.DOWN * 4.0
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [body.get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or is_bottle(hit):
		return
	var at: Vector3 = hit.get("position", body.global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var seat := at + normal * half_height
	if body.global_position.y >= seat.y - 0.002:
		return
	body.global_position = seat
	if body.linear_velocity.y < 0.0:
		body.linear_velocity.y = 0.0
	body.sleeping = false


static func shatter_if_bottle(hit: Dictionary) -> bool:
	var at: Vector3 = hit.get("position", Vector3.INF)
	return shatter_body(hit.get("collider"), at)


## Rail bottles and the off-hand longneck both expose shatter + center.
static func is_glass(body: Variant) -> bool:
	return body != null and body is Node \
			and body.has_method("shatter") and body.has_method("center")


## Shatter a rail bottle or an off-hand longneck. False if `body` is not glass.
static func shatter_body(body: Node, at := Vector3.INF) -> bool:
	if not is_glass(body):
		return false
	body.call("shatter", at)
	return true
