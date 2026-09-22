extends Node3D
## Cosmetic desert sliding past a stopped train. Tracks and cacti move at
## [member speed_mps]; canyon walls and buttes move slower so the horizon
## parallaxes. Local only — no net sync. Pieces wrap on a loop.

const TRACK_SCENE := preload("res://assets/models/scenarios/main_street/env_rail_track_8m.glb")
const SCATTER_SCENE := preload("res://assets/models/scenarios/main_street/env_desert_scatter.glb")
const HORIZON_SCENE := preload("res://assets/models/scenarios/train_rooftop/horizon_ridge.glb")

## Matches dev/build_train_rooftop_blender.py HORIZON_SPAN.
const HORIZON_SPAN := 48.0
const TRACK_LEN := 8.0
# Long loops so the wrap sits past the fog. A short belt pops tracks,
# cacti, and cliffs into view at the far end of the cars.
const TRACK_COUNT := 90
const NEAR_LOOP := TRACK_LEN * TRACK_COUNT
const MID_COUNT := 20
const FAR_COUNT := 22
const MID_LOOP := HORIZON_SPAN * MID_COUNT
const FAR_LOOP := HORIZON_SPAN * FAR_COUNT
const CACTUS_COUNT := 180

@export var speed_mps := 10.0
@export var mid_speed_scale := 0.35
@export var far_speed_scale := 0.12

var _nodes: Array[Node3D] = []
var _home_z := PackedFloat32Array()
var _loops := PackedFloat32Array()
var _scales := PackedFloat32Array()


func _ready() -> void:
	_spawn_tracks()
	_spawn_cacti()
	_spawn_horizon()


func _process(_delta: float) -> void:
	var near := Time.get_ticks_msec() * 0.001 * speed_mps
	for i in _nodes.size():
		var loop: float = _loops[i]
		var z := wrapf(_home_z[i] + near * _scales[i], -loop * 0.5, loop * 0.5)
		_nodes[i].position.z = z


func _spawn_tracks() -> void:
	for i in TRACK_COUNT:
		var track := TRACK_SCENE.instantiate() as Node3D
		# The kit piece runs along X. Yaw it so the rails follow the cars (Z).
		track.rotation.y = PI * 0.5
		var home := -NEAR_LOOP * 0.5 + (float(i) + 0.5) * TRACK_LEN
		_add_piece(track, home, NEAR_LOOP, 1.0)


func _spawn_cacti() -> void:
	var scatter := SCATTER_SCENE.instantiate()
	var plants: Array[Node3D] = []
	_collect_plants(scatter, plants)
	var templates: Array[Node3D] = []
	for plant in plants:
		if _is_cactus(plant):
			templates.append(plant)
	if templates.is_empty():
		push_error("Train rooftop: desert scatter has no cactus plants to borrow")
		scatter.free()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1882
	var step := NEAR_LOOP / float(CACTUS_COUNT)
	for i in CACTUS_COUNT:
		var copy := (templates[rng.randi() % templates.size()] as Node3D).duplicate() as Node3D
		var side := 1.0 if rng.randi() % 2 == 0 else -1.0
		copy.position = Vector3(side * rng.randf_range(4.5, 16.0), 0.0, 0.0)
		var home := -NEAR_LOOP * 0.5 + (float(i) + 0.5) * step
		_add_piece(copy, home, NEAR_LOOP, 1.0)
	scatter.free()


func _spawn_horizon() -> void:
	var horizon := HORIZON_SCENE.instantiate()
	var canyon := _find_named(horizon, "Canyon")
	var mesa := _find_named(horizon, "Mesa")
	var butte := _find_named(horizon, "Butte")
	if canyon == null or mesa == null or butte == null:
		push_error("Train rooftop: horizon_ridge.glb is missing Canyon / Mesa / Butte")
		horizon.free()
		return
	var mid_rng := RandomNumberGenerator.new()
	mid_rng.seed = 1904
	for i in MID_COUNT:
		var template := canyon if i % 2 == 0 else mesa
		_place_span(template, i, MID_COUNT, MID_LOOP, 28.0, 40.0, mid_speed_scale, mid_rng)
	var far_rng := RandomNumberGenerator.new()
	far_rng.seed = 1911
	for i in FAR_COUNT:
		_place_span(butte, i, FAR_COUNT, FAR_LOOP, 70.0, 100.0, far_speed_scale, far_rng)
	horizon.free()


func _place_span(template: Node3D, index: int, count: int, loop: float, x_min: float, x_max: float, speed_scale: float, rng: RandomNumberGenerator) -> void:
	var home := -loop * 0.5 + (float(index) + 0.5) * (loop / float(count))
	for side in [-1.0, 1.0]:
		var copy := template.duplicate() as Node3D
		copy.position = Vector3(side * rng.randf_range(x_min, x_max), 0.0, 0.0)
		_add_piece(copy, home, loop, speed_scale)


func _add_piece(node: Node3D, home_z: float, loop_length: float, speed_scale: float) -> void:
	add_child(node)
	_strip_collision(node)
	node.position.z = home_z
	_nodes.append(node)
	_home_z.append(home_z)
	_loops.append(loop_length)
	_scales.append(speed_scale)


func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_strip_collision(child)


func _collect_plants(node: Node, into: Array[Node3D]) -> void:
	if String(node.name).begins_with("Plant_") and node is Node3D:
		into.append(node)
		return
	for child in node.get_children():
		_collect_plants(child, into)


func _is_cactus(plant: Node) -> bool:
	var cactus := false
	var skip := false
	var stack: Array[Node] = [plant]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nname := String(n.name)
		if nname.contains("Blade") or nname.contains("Clump") or nname.contains("Stick"):
			skip = true
		elif nname.contains("Arm") or nname.contains("Tip") or nname.contains("Pad") or nname.contains("Body") or nname.contains("Col") or nname.contains("Trunk"):
			cactus = true
		for child in n.get_children():
			stack.append(child)
	return cactus and not skip


func _find_named(root: Node, wanted: String) -> Node3D:
	if String(root.name) == wanted and root is Node3D:
		return root as Node3D
	for child in root.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null
