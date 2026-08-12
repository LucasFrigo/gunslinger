class_name VfxCatalog
extends RefCounted
## Spawns combat VFX. Assign PackedScenes in OVERRIDES to swap placeholders
## for real art without changing call sites.
##
## Cue names: muzzle_smoke, world_dust, wood_chip, blood_burst, near_miss_whoosh

const _SCENES := {
	&"muzzle_smoke": preload("res://assets/vfx/muzzle_smoke.tscn"),
	&"world_dust": preload("res://assets/vfx/world_dust.tscn"),
	&"wood_chip": preload("res://assets/vfx/wood_chip.tscn"),
	&"blood_burst": preload("res://assets/vfx/blood_burst.tscn"),
	&"near_miss_whoosh": preload("res://assets/vfx/near_miss_whoosh.tscn"),
}

## Optional cue → PackedScene overrides.
static var OVERRIDES: Dictionary = {}


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
	var node := packed.instantiate() as Node3D
	if node is GPUParticles3D:
		var particles := node as GPUParticles3D
		if amount_scale != 1.0:
			particles.amount = maxi(1, int(round(float(particles.amount) * amount_scale)))
		if lifetime_scale != 1.0:
			particles.lifetime *= lifetime_scale
	parent.add_child(node)
	node.global_position = origin
	if normal.length_squared() > 0.0001:
		var n := normal.normalized()
		# Aim burst outward along hit normal.
		if absf(n.dot(Vector3.UP)) < 0.99:
			node.look_at(origin + n, Vector3.UP)
		else:
			node.look_at(origin + n, Vector3.FORWARD)
	return node
