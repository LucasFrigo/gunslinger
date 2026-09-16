extends Node
## Central combat AV feedback: spatial SFX stubs, placeholder VFX, haptics.
## Call sites stay thin; swap assets via AudioCatalog / VfxCatalog OVERRIDES.
## Boot `warmup()` compiles first-shot particles / trail / slug / gunshot on
## the loading screen so the hitch is not the first trigger pull.

signal warmup_progress(amount: float, status: String)

const REGION_HEAD := &"head"
const REGION_TORSO := &"torso"
const REGION_ARM := &"arm"
const REGION_LEG := &"leg"
const DRAW_FRAMES := 4

var _did_warmup := false


func shot_fired(muzzle_global: Transform3D, shooting_hand: StringName = &"right_hand") -> void:
	var parent := _scene_root()
	if parent != null:
		VfxCatalog.spawn(&"muzzle_smoke", parent, muzzle_global.origin, -muzzle_global.basis.z)
	CombatHaptics.fire(shooting_hand)


func world_impact(origin: Vector3, normal: Vector3) -> void:
	var parent := _scene_root()
	if parent != null:
		VfxCatalog.spawn(&"world_dust", parent, origin, normal)
		VfxCatalog.spawn(&"wood_chip", parent, origin, normal)
	_play_spatial(AudioCatalog.get_stream(&"impact_world"), origin)
	# Occasional muted ricochet tick.
	if randf() < 0.35:
		_play_spatial(AudioCatalog.get_stream(&"ricochet"), origin, 0.7)


func body_impact(origin: Vector3, normal: Vector3, region: StringName = REGION_TORSO) -> void:
	var parent := _scene_root()
	if parent != null:
		var amount_scale := 1.4 if region == REGION_HEAD else 1.0
		var lifetime_scale := 1.15 if region == REGION_HEAD else 1.0
		VfxCatalog.spawn(&"blood_burst", parent, origin, normal, amount_scale, lifetime_scale)
	_play_spatial(AudioCatalog.get_stream(&"impact_flesh"), origin)


func player_hurt(is_fatal: bool) -> void:
	_play_local(AudioCatalog.get_stream(&"hurt"))
	CombatHaptics.hurt(is_fatal)


func near_miss(at: Vector3) -> void:
	var parent := _scene_root()
	if parent != null:
		VfxCatalog.spawn(&"near_miss_whoosh", parent, at, Vector3.UP)
	_play_spatial(AudioCatalog.get_stream(&"whizz"), at)
	# Soft air whoosh layered under the classic whizz.
	_play_spatial(AudioCatalog.get_stream(&"near_miss_whoosh"), at, -4.0)
	CombatHaptics.near_miss()


## Compile combat AV before the menu. GPU work must draw in the live camera
## (XR swapchain / flat viewport). Await this; it emits `warmup_progress`.
func warmup() -> void:
	if _did_warmup:
		warmup_progress.emit(1.0, "Ready")
		return
	warmup_progress.emit(0.08, "Loading sounds...")
	AudioCatalog.warmup()
	warmup_progress.emit(0.22, "Loading weapons...")
	Bullet.ensure_mesh()
	if OS.has_feature("headless"):
		_did_warmup = true
		warmup_progress.emit(1.0, "Ready")
		return
	warmup_progress.emit(0.35, "Preparing effects...")
	var tree := get_tree()
	if tree == null:
		_did_warmup = true
		warmup_progress.emit(1.0, "Ready")
		return
	var camera: Node3D = null
	for _try in 20:
		await tree.process_frame
		camera = _find_camera()
		if camera != null:
			break
	if camera == null:
		_did_warmup = true
		warmup_progress.emit(1.0, "Ready")
		return
	warmup_progress.emit(0.5, "Compiling shaders...")
	var host := _spawn_draw_warmup(camera)
	for i in DRAW_FRAMES:
		await tree.process_frame
		warmup_progress.emit(0.5 + 0.4 * float(i + 1) / float(DRAW_FRAMES), "Compiling shaders...")
	if is_instance_valid(host):
		host.queue_free()
	_did_warmup = true
	warmup_progress.emit(1.0, "Ready")


func _scene_root() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene


func _play_spatial(stream: AudioStream, origin: Vector3, volume_db: float = 0.0) -> void:
	var parent := _scene_root()
	if parent == null or stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = 60.0
	player.autoplay = true
	parent.add_child(player)
	player.global_position = origin
	player.finished.connect(player.queue_free)


func _play_local(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.autoplay = true
	add_child(player)
	player.finished.connect(player.queue_free)


func _spawn_draw_warmup(camera: Node3D) -> Node3D:
	var host := Node3D.new()
	host.name = "CombatWarmup"
	camera.add_child(host)
	# In front of the lens, scaled down so the compile draw is not visible.
	host.position = Vector3(0.0, 0.0, -0.4)
	host.scale = Vector3.ONE * 0.001

	VfxCatalog.spawn_for_compile(host)

	var slug := MeshInstance3D.new()
	slug.mesh = Bullet.ensure_mesh()
	slug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(slug)

	var ribbon := ImmediateMesh.new()
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	ribbon.surface_add_vertex(Vector3(-0.2, 0.0, 0.0))
	ribbon.surface_add_vertex(Vector3(-0.2, 0.04, 0.0))
	ribbon.surface_add_vertex(Vector3(0.2, 0.0, 0.0))
	ribbon.surface_add_vertex(Vector3(0.2, 0.04, 0.0))
	ribbon.surface_end()
	var trail_draw := MeshInstance3D.new()
	trail_draw.mesh = ribbon
	trail_draw.material_override = BulletTrail.make_material(Color(1.0, 0.85, 0.35, 1.0))
	trail_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(trail_draw)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 0.01
	light.omni_range = 0.02
	host.add_child(light)

	var gunshot := AudioStreamPlayer3D.new()
	gunshot.stream = AudioCatalog.get_stream(&"gunshot")
	gunshot.volume_db = -80.0
	gunshot.max_distance = 1.0
	gunshot.autoplay = true
	host.add_child(gunshot)
	return host


func _find_camera() -> Node3D:
	var player := GameManager.local_player if GameManager != null else null
	if is_instance_valid(player) and is_instance_valid(player.rig):
		var rig_cam: Variant = player.rig.get("camera")
		if rig_cam is Node3D:
			return rig_cam as Node3D
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_camera_3d()
	return null
