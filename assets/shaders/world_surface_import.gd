@tool
extends EditorScenePostImport
## Scenario GLBs: swaps every flat-color StandardMaterial3D for a `world_surface.gdshader`
## ShaderMaterial at import, so the editor shows the real look. Set as `import_script/path`
## in each scenario `.glb.import`; reimport after changing this file. The GLBs reuse
## material names with different colors, so the color and roughness are read from each
## GLB's own material and only grain and sway come from the name. Each GLB owns copies of its
## materials named `<base>__<glb>` (`M_Wood__bld_bank`); the suffix is dropped before every name
## lookup. A material with a glTF albedo image (the hand-painted texture of that GLB) becomes a
## `use_albedo_tex` surface. The shared trim sheet is paused behind `USE_TRIM_SHEET`.

const SHADER := "res://assets/shaders/world_surface.gdshader"
const GRAIN_TEX := "res://assets/shaders/world_grain.tres"
const SHEET := "res://assets/textures/trim_sheet.png"
## Trim sheet switch. Off: the per-GLB textures replaced the strip UVs the sheet needs, so
## turning it on shows garbage until the UVs are rebuilt (`docs/TEXTURING.md`).
const USE_TRIM_SHEET := false
## Separates a material's base name from the GLB that owns the copy.
const GLB_SEP := "__"
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
## Ground and rock carry UVs for a later tiling texture, not the sheet. Keep in step with
## `TILING_MATERIALS` in `dev/scenery_uv.py`.
const TILING: Array[StringName] = [
	&"M_Sand", &"M_SandFar", &"M_Dirt", &"M_DirtFar", &"M_Rock", &"M_RockDark", &"M_Cap",
	&"M_CapDark",
]
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
		var material_name := StringName(source.resource_name.get_slice(GLB_SEP, 0))
		var sway := SWAY.has(material_name)
		var height := 1.0
		if sway:
			height = maxf(snappedf(mesh.get_aabb().end.y, HEIGHT_STEP), HEIGHT_STEP)
		var has_uv := mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV != 0
		var sheet := USE_TRIM_SHEET and has_uv and not TILING.has(material_name)
		var painted := source.albedo_texture
		var key := "%s|%s|%.2f|%.2f|%s|%s" % [
				source.albedo_color.to_html(), material_name, source.roughness, height, sheet,
				painted.get_instance_id() if painted != null else 0]
		var material: ShaderMaterial = _cache.get(key)
		if hinged:
			# Its own material, set on the node: the hinge line is this slab's box.
			material = _make(source, material_name, sway, height, sheet, painted)
			_hinge(material, mesh.get_aabb(), HINGES[StringName(instance.name)])
			instance.set_surface_override_material(surface, material)
			continue
		if material == null:
			material = _make(source, material_name, sway, height, sheet, painted)
			_cache[key] = material
		mesh.surface_set_material(surface, material)


func _make(source: StandardMaterial3D, material_name: StringName, sway: bool,
		height: float, sheet: bool, painted: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = source.resource_name
	material.shader = load(SHADER)
	material.set_shader_parameter("albedo", source.albedo_color)
	material.set_shader_parameter("roughness_amount", source.roughness)
	material.set_shader_parameter("grain_tex", load(GRAIN_TEX))
	material.set_shader_parameter("grain_strength", GRAIN.get(material_name, 0.0))
	material.set_shader_parameter("grain_local", true)
	if painted != null:
		material.set_shader_parameter("use_albedo_tex", true)
		material.set_shader_parameter("albedo_tex", _with_mipmaps(painted))
	elif sheet:
		material.set_shader_parameter("use_sheet", true)
		material.set_shader_parameter("sheet_tex", load(SHEET))
	if sway:
		material.set_shader_parameter("sway_amount", SWAY_AMOUNT)
		material.set_shader_parameter("sway_height", height)
	return material


## The GLB's embedded image, with a mip chain so far surfaces do not shimmer.
func _with_mipmaps(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	if not image.has_mipmaps():
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


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
	return source.vertex_color_use_as_albedo or source.normal_enabled \
			or source.emission_enabled \
			or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
