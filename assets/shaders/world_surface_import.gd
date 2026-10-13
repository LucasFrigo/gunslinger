@tool
extends EditorScenePostImport
## Scenario GLBs: swaps every flat-color StandardMaterial3D for a `world_surface.gdshader`
## ShaderMaterial at import, so the editor shows the real look. Set as `import_script/path`
## in each scenario `.glb.import`; reimport after changing this file. The GLBs reuse
## material names with different colors, so the color and roughness are read from each
## GLB's own material and only grain and sway come from the name.

const SHADER := "res://assets/shaders/world_surface.gdshader"
const GRAIN_TEX := "res://assets/shaders/world_grain.tres"
const SWAY_AMOUNT := 0.03
## Radians at full wind (about 2 degrees).
const HINGE_AMOUNT := 0.035
const HEIGHT_STEP := 0.1

## Grain strength by material name. Metals, glass, cloth, hide, and plants get none.
const GRAIN := {
	&"M_Sand": 0.2, &"M_SandFar": 0.2, &"M_Dirt": 0.2, &"M_DirtFar": 0.2,
	&"M_Rock": 0.2, &"M_RockDark": 0.2, &"M_Cap": 0.2, &"M_CapDark": 0.2,
	&"M_Wood": 0.12, &"M_WoodDark": 0.12, &"M_Plank": 0.12, &"M_Roof": 0.12,
	&"M_Car": 0.12, &"M_CarDark": 0.12, &"M_Floor": 0.12, &"M_FloorAlt": 0.12,
	&"M_Bar": 0.12, &"M_BarTop": 0.12, &"M_Trim": 0.12, &"M_Masonry": 0.12,
	&"M_Whitewash": 0.12,
}
## Materials that bend in the wind (cacti stay rigid). Each is a mesh of its own, so the
## mesh height is the plant's.
const SWAY: Array[StringName] = [&"M_Yucca", &"M_Scrub", &"M_ScrubDry", &"M_Hay"]
## Rigid slabs that swing about one edge, by node name. The vector points at the hinge
## edge in model space: up for a sign hanging from its top, toward the wall for an awning.
const HINGES := {
	&"Sign": Vector3.UP,
	&"PorchSign": Vector3.UP,
	&"ShedAwning": Vector3.BACK,
	&"Canopy": Vector3.FORWARD,
}

var _cache := {}


## Godot 4.7 hands this script the scene with its MeshInstance3D nodes already built.
func _post_import(scene: Node) -> Object:
	_cache.clear()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		_swap(node as MeshInstance3D)
	return scene


func _swap(instance: MeshInstance3D) -> void:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return
	var hinged := HINGES.has(StringName(instance.name))
	for surface in mesh.get_surface_count():
		# Collision proxies (-convcolonly) are bodies by now; a swapped surface is no longer
		# a StandardMaterial3D, so a shared mesh is not swapped twice.
		var source := mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null:
			continue
		if _unsupported(source):
			push_warning("world_surface_import: %s on %s keeps its StandardMaterial3D" % [
					source.resource_name, instance.name])
			continue
		var material_name := StringName(source.resource_name)
		var sway := SWAY.has(material_name)
		var height := 1.0
		if sway:
			height = maxf(snappedf(mesh.get_aabb().end.y, HEIGHT_STEP), HEIGHT_STEP)
		var key := "%s|%s|%.2f|%.2f" % [
				source.albedo_color.to_html(), material_name, source.roughness, height]
		var material: ShaderMaterial = _cache.get(key)
		if hinged:
			# Its own material, set on the node: the hinge line is this slab's box.
			material = _make(source, material_name, sway, height)
			_hinge(material, mesh.get_aabb(), HINGES[StringName(instance.name)])
			instance.set_surface_override_material(surface, material)
			continue
		if material == null:
			material = _make(source, material_name, sway, height)
			_cache[key] = material
		mesh.surface_set_material(surface, material)


func _make(source: StandardMaterial3D, material_name: StringName, sway: bool,
		height: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = source.resource_name
	material.shader = load(SHADER)
	material.set_shader_parameter("albedo", source.albedo_color)
	material.set_shader_parameter("roughness_amount", source.roughness)
	material.set_shader_parameter("grain_tex", load(GRAIN_TEX))
	material.set_shader_parameter("grain_strength", GRAIN.get(material_name, 0.0))
	material.set_shader_parameter("grain_local", true)
	if sway:
		material.set_shader_parameter("sway_amount", SWAY_AMOUNT)
		material.set_shader_parameter("sway_height", height)
	return material


## Hinge line on the `side` edge of the slab's box: along the long horizontal axis for a
## sign, along the wall for an awning.
func _hinge(material: ShaderMaterial, box: AABB, side: Vector3) -> void:
	var axis := Vector3.UP.cross(side)
	if side.is_equal_approx(Vector3.UP):
		axis = Vector3.RIGHT if box.size.x >= box.size.z else Vector3.BACK
	var origin := box.get_center() + side * side.abs().dot(box.size) * 0.5
	material.set_shader_parameter("hinge_amount", HINGE_AMOUNT)
	material.set_shader_parameter("hinge_origin", origin)
	material.set_shader_parameter("hinge_axis", axis)


func _unsupported(source: StandardMaterial3D) -> bool:
	return source.albedo_texture != null or source.vertex_color_use_as_albedo \
			or source.normal_enabled or source.emission_enabled \
			or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
