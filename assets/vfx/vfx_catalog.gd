class_name VfxCatalog
extends RefCounted
## Spawns combat VFX. Assign PackedScenes in OVERRIDES to swap placeholders
## for real art without changing call sites.
##
## Cue names: muzzle_smoke, world_dust, wood_chip, blood_burst, near_miss_whoosh,
## glass_shatter, coin_burst, barrel_smoke, wind_gust, engine_smoke (a looping plume the
## Train Rooftop instances itself, listed here so the boot warmup compiles it)

const _SCENES := {
	&"muzzle_smoke": preload("res://assets/vfx/muzzle_smoke.tscn"),
	&"barrel_smoke": preload("res://assets/vfx/barrel_smoke.tscn"),
	&"world_dust": preload("res://assets/vfx/world_dust.tscn"),
	&"wood_chip": preload("res://assets/vfx/wood_chip.tscn"),
	&"blood_burst": preload("res://assets/vfx/blood_burst.tscn"),
	&"near_miss_whoosh": preload("res://assets/vfx/near_miss_whoosh.tscn"),
	&"glass_shatter": preload("res://assets/vfx/glass_shatter.tscn"),
	&"coin_burst": preload("res://assets/vfx/coin_burst.tscn"),
	&"wind_gust": preload("res://assets/vfx/wind_gust.tscn"),
	&"engine_smoke": preload("res://assets/vfx/engine_smoke.tscn"),
}

## Cues fired on every shot. A finished burst parks under `_pool_root` and the next
## shot reuses it, so no scene is instanced and no particle buffer allocated mid-duel.
const _POOLED: Array[StringName] = [&"muzzle_smoke", &"barrel_smoke"]
const _POOL_MAX := 8

## Optional cue → PackedScene overrides.
static var OVERRIDES: Dictionary = {}

static var _idle: Dictionary = {}
static var _pool_root: Node3D


static func cues() -> Array[StringName]:
	var names: Array[StringName] = []
	for key in _SCENES.keys():
		names.append(key as StringName)
	return names


static func spawn(
		cue: StringName,
		parent: Node,
		origin: Vector3,
		normal: Vector3 = Vector3.UP,
		amount_scale: float = 1.0,
		lifetime_scale: float = 1.0
	) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		return null
	var packed: PackedScene = null
	if OVERRIDES.has(cue):
		packed = OVERRIDES[cue] as PackedScene
	elif _SCENES.has(cue):
		packed = _SCENES[cue] as PackedScene
	else:
		push_warning("VfxCatalog: unknown cue '%s'" % cue)
		return null
	var pooled := cue in _POOLED and amount_scale == 1.0
	var reused: OneShotParticles = _take_idle(cue) if pooled else null
	var node: Node3D = reused
	if reused == null:
		node = packed.instantiate() as Node3D
		if node is GPUParticles3D:
			var particles := node as GPUParticles3D
			particles.set_meta(&"base_lifetime", particles.lifetime)
			if amount_scale != 1.0:
				particles.amount = maxi(1, int(round(float(particles.amount) * amount_scale)))
			if lifetime_scale != 1.0:
				particles.lifetime *= lifetime_scale
		if pooled and node is OneShotParticles:
			(node as OneShotParticles).park = _park.bind(cue)
	else:
		reused.lifetime = float(reused.get_meta(&"base_lifetime")) * lifetime_scale
	parent.add_child(node)
	node.global_position = origin
	if normal.length_squared() > 0.0001:
		var n := normal.normalized()
		# Aim burst outward along hit normal.
		if absf(n.dot(Vector3.UP)) < 0.99:
			node.look_at(origin + n, Vector3.UP)
		else:
			node.look_at(origin + n, Vector3.FORWARD)
	if reused != null:
		reused.play()
	return node


static func _take_idle(cue: StringName) -> OneShotParticles:
	var stack: Array = _idle.get(cue, [])
	while not stack.is_empty():
		var candidate: Variant = stack.pop_back()
		if is_instance_valid(candidate):
			var node := candidate as OneShotParticles
			node.get_parent().remove_child(node)
			return node
	return null


## `OneShotParticles.park` target: move a finished burst out of the scene into the pool.
static func _park(node: OneShotParticles, cue: StringName) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var stack: Array = _idle.get(cue, [])
	stack = stack.filter(func(entry: Variant) -> bool: return is_instance_valid(entry))
	_idle[cue] = stack
	if stack.size() >= _POOL_MAX:
		node.queue_free()
		return
	if _pool_root == null or not is_instance_valid(_pool_root):
		_pool_root = Node3D.new()
		_pool_root.name = "VfxPool"
		(Engine.get_main_loop() as SceneTree).root.add_child(_pool_root)
	node.emitting = false
	node.get_parent().remove_child(node)
	_pool_root.add_child(node)
	stack.append(node)


## Tiny local-space bursts for shader compile. Does not auto-play on add_child.
static func spawn_for_compile(parent: Node) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for cue in cues():
		var packed: PackedScene = null
		if OVERRIDES.has(cue):
			packed = OVERRIDES[cue] as PackedScene
		elif _SCENES.has(cue):
			packed = _SCENES[cue] as PackedScene
		if packed == null:
			continue
		var node := packed.instantiate() as Node3D
		if node is OneShotParticles:
			(node as OneShotParticles).auto_play = false
		if node is GPUParticles3D:
			var particles := node as GPUParticles3D
			particles.emitting = false
			particles.local_coords = true
		parent.add_child(node)
		node.position = Vector3.ZERO
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = true
