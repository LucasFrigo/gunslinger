class_name OutlineHull
extends RefCounted
## The ink line's hull, shared by duelists and held objects. `weld` makes the closed copy a
## `body_outline.gdshader` material pushes out along its normals; `attach` hangs it under a
## mesh as an "Outline" child. Local cosmetic only: each peer builds its own, nothing is sent.
## Gun and offhand props wear the "gun" material, brass the "ammo" one. Both are shared
## statics, so a width change is one `set_shader_parameter`. F3 `outline_enabled` hides every
## line; ammo lines also hide past `AMMO_LINE_RANGE` and beyond the newest `AMMO_LINE_CAP`.

## Positions closer than this share one averaged normal.
const WELD_EPSILON := 0.0001
## Metres of line per metre of view distance for gun and props (F3 `object_outline_width`).
const OBJECT_WIDTH := 0.0015
## Held objects: the line holds its screen size from `OBJECT_NEAR` to `OBJECT_FAR`.
const OBJECT_NEAR := 0.3
const OBJECT_FAR := 6.0
## Brass is cheap to skip: only the newest few pieces near the camera wear a line.
const AMMO_LINE_CAP := 12
const AMMO_LINE_RANGE := 6.0
const AMMO_TICK := 0.25
const OUTLINE_NAME := "Outline"
## Group of the gun and prop lines, so `outline_enabled` reaches them without a registry.
const GROUP := &"object_outline"

static var _cache := {}
static var _gun_material: ShaderMaterial
static var _ammo_material: ShaderMaterial
## Live ammo lines, oldest first. The registry owns the cap and the range check.
static var _ammo: Array[MeshInstance3D] = []
static var _ticking := false
static var _listening := false


## A copy of `mesh` for the ink hull: the normal at every vertex is the sum over all
## vertices sharing its position, normalized, so the hull stays closed along flat-shaded
## facet edges. Every surface is merged into one. Indices are kept; bones and weights only
## when every surface has them; UVs, tangents, and vertex colours are dropped.
static func weld(mesh: Mesh, flags: int = 0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var skinned := true
	for s in mesh.get_surface_count():
		var source := mesh.surface_get_arrays(s)
		var part: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var part_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL] if source[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if part.is_empty() or part_normals.size() != part.size():
			continue
		var base := verts.size()
		var part_indices := PackedInt32Array()
		if source[Mesh.ARRAY_INDEX] != null:
			part_indices = source[Mesh.ARRAY_INDEX]
		if part_indices.is_empty():
			part_indices.resize(part.size())
			for i in part.size():
				part_indices[i] = i
		for i in part_indices.size():
			indices.append(part_indices[i] + base)
		verts.append_array(part)
		normals.append_array(part_normals)
		var part_bones: PackedInt32Array = source[Mesh.ARRAY_BONES] if source[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var part_weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS] if source[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if part_bones.is_empty() or part_weights.is_empty():
			skinned = false
		else:
			bones.append_array(part_bones)
			weights.append_array(part_weights)
	var out := ArrayMesh.new()
	if verts.is_empty():
		return out
	var cells: Array[Vector3i] = []
	var sums := {}
	for i in verts.size():
		var cell := Vector3i((verts[i] / WELD_EPSILON).round())
		cells.append(cell)
		sums[cell] = (sums[cell] as Vector3 if sums.has(cell) else Vector3.ZERO) + normals[i]
	var welded := PackedVector3Array()
	welded.resize(verts.size())
	for i in verts.size():
		var sum: Vector3 = sums[cells[i]]
		# Opposed normals at one point cancel; keep the vertex's own then.
		welded[i] = sum.normalized() if sum.length_squared() > 0.000001 else normals[i]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = welded
	if skinned:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags if skinned else 0)
	return out


## `weld` of an unskinned mesh, built once per source mesh. Primitive meshes are shared
## resources, so one hull serves every casing.
static func weld_cached(mesh: Mesh) -> ArrayMesh:
	if not _cache.has(mesh):
		_cache[mesh] = weld(mesh)
	return _cache[mesh]


## Hangs an "Outline" child under `host`: the hull on the host's layers, no shadow, visible
## with the host. `hull` is the host's welded copy (`weld_cached` of its mesh when null).
## Pass the skeleton for a skinned host; the child takes its skin.
static func attach(host: MeshInstance3D, material: Material, skeleton: Skeleton3D = null,
		hull: Mesh = null) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.name = OUTLINE_NAME
	line.mesh = hull if hull != null else weld_cached(host.mesh)
	if skeleton != null:
		line.skin = host.skin
	host.add_child(line)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.layers = host.layers
	if skeleton != null:
		line.skeleton = line.get_path_to(skeleton)
	if material != null:
		line.material_override = material
	return line


## The ink material at the given width and fade range.
static func material_new(width: float, near: float, far: float) -> ShaderMaterial:
	var material := BodyChunks.outline_material_new()
	material.set_shader_parameter("width", width)
	material.set_shader_parameter("near", near)
	material.set_shader_parameter("far", far)
	return material


## The one gun and prop material.
static func gun_material() -> ShaderMaterial:
	_listen()
	if _gun_material == null:
		_gun_material = material_new(_object_width(), OBJECT_NEAR, OBJECT_FAR)
	return _gun_material


## The one brass material.
static func ammo_material() -> ShaderMaterial:
	_listen()
	if _ammo_material == null:
		_ammo_material = material_new(_object_width(), OBJECT_NEAR, OBJECT_FAR)
	return _ammo_material


## Lines for every mesh under `root` (the root counts), on the shared gun material. Lines
## already there are skipped, so a call twice is harmless.
static func attach_model(root: Node, ammo := false) -> Array[MeshInstance3D]:
	var lines: Array[MeshInstance3D] = []
	var hosts: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		hosts.push_front(root)
	for node in hosts:
		var host := node as MeshInstance3D
		if host.mesh == null or host.name == OUTLINE_NAME or host.get_node_or_null(OUTLINE_NAME) != null:
			continue
		if ammo:
			lines.append(attach_ammo(host))
		else:
			lines.append(attach_gun(host))
	return lines


## A gun or prop line: shown whenever `outline_enabled` is.
static func attach_gun(host: MeshInstance3D) -> MeshInstance3D:
	var line := attach(host, gun_material())
	line.visible = _enabled()
	line.add_to_group(GROUP)
	return line


## A brass line: also capped to the newest `AMMO_LINE_CAP` and hidden past `AMMO_LINE_RANGE`.
static func attach_ammo(host: MeshInstance3D) -> MeshInstance3D:
	var line := attach(host, ammo_material())
	_prune_ammo()
	_ammo.append(line)
	while _ammo.size() > AMMO_LINE_CAP:
		_ammo.pop_front().visible = false
	line.visible = _enabled()
	_arm_tick()
	return line


## Live ammo lines that still count toward the cap, oldest first.
static func ammo_lines() -> Array[MeshInstance3D]:
	_prune_ammo()
	return _ammo.duplicate()


## Shows or hides every ammo line by `outline_enabled` and camera range.
static func refresh_ammo() -> void:
	_prune_ammo()
	for line in _ammo:
		_refresh_ammo(line)


## Forgets the registry and the shared materials (a test's clean slate).
static func reset() -> void:
	_cache.clear()
	_ammo.clear()
	_gun_material = null
	_ammo_material = null


static func _object_width() -> float:
	return float(GameManager.tuning.get("object_outline_width", OBJECT_WIDTH))


static func _enabled() -> bool:
	return float(GameManager.tuning.get("outline_enabled", 1.0)) > 0.5


static func _listen() -> void:
	if _listening:
		return
	_listening = true
	GameManager.tuning_changed.connect(_on_tuning_changed)


static func _on_tuning_changed(key: String, _value: Variant) -> void:
	if key == "object_outline_width":
		var width := _object_width()
		for material in [_gun_material, _ammo_material]:
			if material != null:
				(material as ShaderMaterial).set_shader_parameter("width", width)
	elif key == "outline_enabled":
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			for line in tree.get_nodes_in_group(GROUP):
				(line as MeshInstance3D).visible = _enabled()
		refresh_ammo()


static func _prune_ammo() -> void:
	var live: Array[MeshInstance3D] = []
	for line in _ammo:
		if is_instance_valid(line) and not line.is_queued_for_deletion():
			live.append(line)
	_ammo = live


static func _refresh_ammo(line: MeshInstance3D) -> void:
	var on := _enabled()
	if on and line.is_inside_tree():
		var camera := line.get_viewport().get_camera_3d() if line.get_viewport() != null else null
		if camera != null:
			on = line.global_position.distance_to(camera.global_position) <= AMMO_LINE_RANGE
	line.visible = on


## One shared timer for every piece of brass: re-arms while any line is live.
static func _arm_tick() -> void:
	if _ticking:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_ticking = true
	tree.create_timer(AMMO_TICK, true, false, true).timeout.connect(_on_ammo_tick)


static func _on_ammo_tick() -> void:
	_ticking = false
	refresh_ammo()
	if not _ammo.is_empty():
		_arm_tick()
