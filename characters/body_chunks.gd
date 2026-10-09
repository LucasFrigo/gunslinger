class_name BodyChunks
extends Node
## Hit holes on one `DummyBody`. Cosmetic only: an accepted hit cuts a sphere out of the
## skin where the bullet landed (`DummyBody.cut_at`) and throws a `BodyGib` along the shot.
## The skin shader discards inside each sphere and stains a rim; its cavity `next_pass`
## draws the bowl through the cut. The mesh is never rebuilt.
## A cut is `{bone, local, radius}`: the center in its bone's pose space, so it rides the
## pose, the ragdoll, and the replay. The newest `HOLE_CAP` cuts that are out show; an
## older one heals. Event times are `ReplayBuffer.clip_time()`. A cut at -1 is before the
## clip and stays.

const HOLE_CAP := 8
## The sphere center sits this share of its radius out of the skin, against the shot, so
## the bowl is the rest of the radius deep and does not tunnel a limb.
const CUT_LIFT := 0.3
const CRATER_RIM := Color(0.62, 0.16, 0.13)
const CRATER_CORE := Color(0.24, 0.02, 0.02)
const SKIN_SHADER := preload("res://characters/body_skin.gdshader")
const CAVITY_SHADER := preload("res://characters/body_cavity.gdshader")
## After the hit volumes (`DummyBody.HITBOX_PRIORITY`): the bones are final for the frame.
const PRIORITY := 45
## Thinnest side of a gib's collision box.
const GIB_MIN_SIZE := 0.02
## rad/s of random tumble on a thrown gib.
const GIB_SPIN := 9.0
## A unit gib is scaled by the cut radius times this.
const GIB_SCALE := 0.7
const GIB_VARIANTS := 3
const GIB_SEED := 7919
const GIB_SEGMENTS := 8
const GIB_ROWS := 3
## Skin dome height and flesh underside depth of a unit gib, and how rough each is.
const GIB_DOME := 0.45
const GIB_DEPTH := 0.6
const GIB_DOME_JITTER := 0.06
const GIB_FLESH_JITTER := 0.3
## Warmup gib skin when no body tint is known.
const COMPILE_ALBEDO := Color(0.62, 0.60, 0.58)
## Warmup hole: far off, so the probe compiles both passes without showing one.
const COMPILE_HOLE := Vector4(0.0, -1000.0, 0.0, 0.01)

static var _crater_material: StandardMaterial3D
static var _gib_meshes: Array[ArrayMesh] = []

var _body: DummyBody
var _skin: ShaderMaterial
var _cavity: ShaderMaterial
var _events: Array[Dictionary] = []
var _replaying := false


static func roll() -> bool:
	return randf() < float(GameManager.tuning.get("chunk_chance", 1.0))


## Untinted vertex color: dark red core, lighter rim. The flesh side of every gib.
static func crater_material() -> StandardMaterial3D:
	if _crater_material == null:
		_crater_material = StandardMaterial3D.new()
		_crater_material.vertex_color_use_as_albedo = true
		_crater_material.vertex_color_is_srgb = true
		_crater_material.roughness = 0.6
		_crater_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _crater_material


## A body's skin: albedo, first-person clip, and hole uniforms (`body_skin.gdshader`).
static func skin_material_new() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKIN_SHADER
	material.set_shader_parameter("rim_color", CRATER_RIM)
	return material


## The skin's bowl pass (`body_cavity.gdshader`), its `next_pass` while there are holes.
static func cavity_material_new() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CAVITY_SHADER
	material.set_shader_parameter("rim_color", CRATER_RIM)
	material.set_shader_parameter("core_color", CRATER_CORE)
	material.set_shader_parameter("cut_lift", CUT_LIFT)
	return material


## The shared lump variants, built once per process.
static func gib_meshes() -> Array[ArrayMesh]:
	if _gib_meshes.is_empty():
		for variant in GIB_VARIANTS:
			_gib_meshes.append(_lump(variant))
	return _gib_meshes


## Boot warmup under `host`: a probe with both hole passes and one frozen gib (not counted
## toward `gib_cap`).
static func spawn_for_compile(host: Node3D) -> void:
	var skin := skin_material_new()
	var cavity := cavity_material_new()
	var holes := PackedVector4Array()
	holes.resize(HOLE_CAP)
	holes[0] = COMPILE_HOLE
	for material: ShaderMaterial in [skin, cavity]:
		material.set_shader_parameter("holes", holes)
		material.set_shader_parameter("hole_count", 1)
	cavity.set_shader_parameter("hole_lifts", holes)
	var probe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	probe.mesh = sphere
	probe.material_override = skin
	skin.next_pass = cavity
	host.add_child(probe)
	var gib := BodyGib.make(gib_meshes()[0], DummyBody.solid_material(COMPILE_ALBEDO), BoxShape3D.new(),
			Vector3.ZERO)
	gib.freeze = true
	gib.set_physics_process(false)
	host.add_child(gib)


## A unit lump around the origin: a skin dome up +Y (surface 0) over a jagged flesh
## underside (surface 1, rim to core). Seeded per variant, so every process builds the same.
static func _lump(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = GIB_SEED + variant
	var rim := PackedFloat32Array()
	for s in GIB_SEGMENTS:
		rim.append(rng.randf_range(0.8, 1.1))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _lump_half(rng, rim, GIB_DOME, GIB_DOME_JITTER, false))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _lump_half(rng, rim, -GIB_DEPTH, GIB_FLESH_JITTER, true))
	mesh.surface_set_material(1, crater_material())
	return mesh


## Rings from the shared rim (row 0) to a pole at `height`, the inner rings roughened by
## `jitter`. Faces look away from the origin. `flesh` adds rim-to-core vertex colors.
static func _lump_half(rng: RandomNumberGenerator, rim: PackedFloat32Array, height: float,
		jitter: float, flesh: bool) -> Array:
	var pos := PackedVector3Array()
	var colors := PackedColorArray()
	for row in GIB_ROWS:
		var k := float(row) / GIB_ROWS
		var rough := 0.0 if row == 0 else jitter
		for s in GIB_SEGMENTS:
			var angle := TAU * s / GIB_SEGMENTS
			var radial := rim[s] * cos(k * PI * 0.5) * rng.randf_range(1.0 - rough, 1.0 + rough)
			var y := height * sin(k * PI * 0.5) * rng.randf_range(1.0 - rough, 1.0 + rough)
			pos.append(Vector3(cos(angle) * radial, y, sin(angle) * radial))
			colors.append(CRATER_RIM.lerp(CRATER_CORE, k))
	var pole := pos.size()
	pos.append(Vector3(0.0, height * rng.randf_range(1.0 - jitter, 1.0 + jitter), 0.0))
	colors.append(CRATER_CORE)
	var idx := PackedInt32Array()
	for row in GIB_ROWS:
		for s in GIB_SEGMENTS:
			var a := row * GIB_SEGMENTS + s
			var b := row * GIB_SEGMENTS + (s + 1) % GIB_SEGMENTS
			if row == GIB_ROWS - 1:
				_outward_tri(idx, pos, a, b, pole)
				continue
			var c := a + GIB_SEGMENTS
			var d := b + GIB_SEGMENTS
			_outward_tri(idx, pos, a, b, d)
			_outward_tri(idx, pos, a, d, c)
	var normals := PackedVector3Array()
	normals.resize(pos.size())
	for i in range(0, idx.size(), 3):
		var face := _front_normal(pos[idx[i]], pos[idx[i + 1]], pos[idx[i + 2]])
		for j in 3:
			normals[idx[i + j]] += face
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	if flesh:
		arrays[Mesh.ARRAY_COLOR] = colors
	return arrays


## Godot's front face is clockwise; this is the normal it shades.
static func _front_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c - a).cross(b - a)


static func _outward_tri(idx: PackedInt32Array, pos: PackedVector3Array, a: int, b: int, c: int) -> void:
	if _front_normal(pos[a], pos[b], pos[c]).dot(pos[a] + pos[b] + pos[c]) < 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


## Basis whose +Y is `axis`.
static func _up_basis(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## `skin` is the body's shared skin material, `cavity` its bowl pass.
func setup(body: DummyBody, skin: ShaderMaterial, cavity: ShaderMaterial) -> void:
	_body = body
	_skin = skin
	_cavity = cavity
	process_priority = PRIORITY
	set_process(false)
	PlayerSettings.gore_changed.connect(_on_gore_changed)


func knock(cut: Dictionary, dir: Vector3, clip_t: float, lethal: bool) -> void:
	if cut.is_empty() or not PlayerSettings.gore_enabled:
		return
	var center: Vector3 = _body.cut_world_center(cut)
	var pose: Transform3D = _body.bone_pose_world(int(cut["bone"]))
	# Outward lift in bone space: the cavity's skin plane rides the pose like the center.
	var lift: Vector3 = pose.basis.inverse() * -dir if dir.length_squared() > 0.000001 else Vector3.ZERO
	var gib: BodyGib = null
	if lethal or not _body.is_body_shelved():
		gib = _spawn_gib(cut, center, dir)
	ImpactFeedback.flesh_chunk(center)
	_events.append({"cut": cut, "lift": lift, "t": clip_t, "gib": gib, "out": true, "replayed": false})
	_refresh()


## Holes showing now: the newest `HOLE_CAP` cuts that are out.
func hole_count() -> int:
	return _active().size()


## The cut of each showing hole, newest first.
func active_cuts() -> Array[Dictionary]:
	var cuts: Array[Dictionary] = []
	for event in _active():
		cuts.append(event["cut"])
	return cuts


## Every hole heals. Gibs stay where they lie.
func reset() -> void:
	_replaying = false
	_events.clear()
	_refresh()


## Cuts inside the clip heal and their gibs hide until their time.
func replay_begin(clip_begin: float) -> void:
	_replaying = true
	for event in _events:
		var t: float = event["t"]
		event["replayed"] = t >= 0.0 and t >= clip_begin
		if not event["replayed"]:
			continue
		event["out"] = false
		var gib := _gib_of(event)
		if gib != null:
			gib.replay_hide()
	_refresh()


## Each cut opens at its clip time; its gib re-flies its track from there.
func replay_at(now: float) -> void:
	if not _replaying:
		return
	var changed := false
	for event in _events:
		if not event["replayed"] or now < float(event["t"]):
			continue
		if not event["out"]:
			event["out"] = true
			changed = true
		var gib := _gib_of(event)
		if gib != null:
			gib.replay_at(now - float(event["t"]))
	if changed:
		_refresh()


## The replay ended: every cut open, every gib where it settled. No-op outside a replay.
func hold_final() -> void:
	if not _replaying:
		return
	_replaying = false
	for event in _events:
		if not event["replayed"]:
			continue
		event["replayed"] = false
		event["out"] = true
		var gib := _gib_of(event)
		if gib != null:
			gib.hold_final()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _active() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(_events.size() - 1, -1, -1):
		if _events[i]["out"]:
			out.append(_events[i])
			if out.size() >= HOLE_CAP:
				break
	return out


## Push the showing holes onto the pose: world centers and lifts into both passes. The
## cavity pass rides the skin only while there is a hole.
func _refresh() -> void:
	var active := _active()
	var holes := PackedVector4Array()
	var lifts := PackedVector4Array()
	holes.resize(HOLE_CAP)
	lifts.resize(HOLE_CAP)
	for i in active.size():
		var cut: Dictionary = active[i]["cut"]
		var pose: Transform3D = _body.bone_pose_world(int(cut["bone"]))
		var center: Vector3 = pose * (cut["local"] as Vector3)
		holes[i] = Vector4(center.x, center.y, center.z, float(cut["radius"]))
		var lift: Vector3 = pose.basis * (active[i]["lift"] as Vector3)
		if lift.length_squared() > 0.000001:
			lift = lift.normalized()
			lifts[i] = Vector4(lift.x, lift.y, lift.z, 1.0)
	_skin.set_shader_parameter("holes", holes)
	_skin.set_shader_parameter("hole_count", active.size())
	_cavity.set_shader_parameter("holes", holes)
	_cavity.set_shader_parameter("hole_lifts", lifts)
	_cavity.set_shader_parameter("hole_count", active.size())
	var cavity: Material = _cavity if not active.is_empty() else null
	if _skin.next_pass != cavity:
		_skin.next_pass = cavity
	set_process(not active.is_empty())


## A random lump scaled to the cut, skin side facing back along the shot.
func _spawn_gib(cut: Dictionary, center: Vector3, dir: Vector3) -> BodyGib:
	var parent: Node = GameManager.current_scenario
	if not is_instance_valid(parent):
		parent = get_tree().current_scene
	var meshes := gib_meshes()
	var mesh: ArrayMesh = meshes[randi() % meshes.size()]
	var size := float(cut["radius"]) * GIB_SCALE
	var box := mesh.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = (box.size * size).max(Vector3.ONE * GIB_MIN_SIZE)
	var out := -dir if dir.length_squared() > 0.000001 else _body.front_dir()
	var velocity := dir * float(GameManager.tuning.get("gib_speed", 3.5)) + Vector3.UP * BodyGib.GIB_LIFT
	var spin := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	return BodyGib.spawn(parent, mesh, _body.skin_material(), shape, box.get_center() * size,
			Transform3D(_up_basis(out), center), velocity, spin.normalized() * GIB_SPIN, size)


func _gib_of(event: Dictionary) -> BodyGib:
	var gib: Variant = event["gib"]
	return gib as BodyGib if is_instance_valid(gib) else null


func _on_gore_changed() -> void:
	if PlayerSettings.gore_enabled:
		return
	reset()
	BodyGib.free_all()
