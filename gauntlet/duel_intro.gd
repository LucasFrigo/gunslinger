class_name DuelIntro
extends Node
## What the player sees while `DuelManager` is in INTRO: one title card per duelist, each on
## a fixed camera a few metres ahead of that duelist's spawn, framed on the card's open side.
## Flat swaps in a Camera3D; VR swaps in a spectator XROrigin3D (as `KillCam` does) with the
## card on a head-locked quad. The duelists stay live: the local body shows whole while the
## cards play, and the HUD and head-locked labels hide. Local only; the clock and the skip
## are `DuelManager`'s.

## Metres ahead of the spawn, eye height, and the chest height the camera looks at.
const CAM_DISTANCE := 2.6
const CAM_HEIGHT := 1.5
const LOOK_HEIGHT := 1.3
## Metres the aim point moves off the duelist, so they stand on the card's open side.
const FRAME_OFFSET := 0.55
const FLAT_FOV := 50.0
## Below the HUD (layer 5), so the pause menu draws over a card.
const FLAT_LAYER := 4
## The fractional scale wins when the best whole-number factor would leave the card smaller
## than this share of the screen.
const INTEGER_SCALE_MIN := 0.85
## VR quad: metres ahead of the spectator camera, and its width.
const VR_CARD_DISTANCE := 1.6
const VR_CARD_WIDTH := 1.9
const STING_DB := -3.0
const WHOOSH_DB := -2.0

## Names in the order their cards were shown since `begin` (tests read it).
var shown_names: PackedStringArray = []

var _entries: Array[Dictionary] = []
var _active := false
var _card: TitleCard
var _canvas: CanvasLayer
var _rect: TextureRect
var _camera: Camera3D
var _restore_camera: Camera3D
var _spectator: XROrigin3D
var _spectator_cam: XRCamera3D
var _restore_origin: XROrigin3D
var _restore_xr_camera: XRCamera3D
var _hmd_ref := Transform3D.IDENTITY
var _quad: MeshInstance3D
var _whoosh: AudioStreamPlayer
var _sting: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = TitleCard.new()
	_card.name = "TitleCard"
	add_child(_card)
	_card.landed.connect(_on_card_landed)
	_canvas = CanvasLayer.new()
	_canvas.layer = FLAT_LAYER
	_canvas.visible = false
	add_child(_canvas)
	_rect = TextureRect.new()
	_rect.texture = _card.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_rect)
	_whoosh = _audio_player(&"title_whoosh", WHOOSH_DB)
	_sting = _audio_player(&"title_sting", STING_DB)
	set_process(false)


func is_active() -> bool:
	return _active


func card_count() -> int:
	return _entries.size()


func card() -> TitleCard:
	return _card


## Every card's name, in card order.
func card_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry in _entries:
		names.append(str(entry["name"]))
	return names


## Takes the camera. `entries` are { name, texture (a baked name or null), spawn }, in
## card order. Card 0 waits for `show_card`.
func begin(entries: Array[Dictionary]) -> void:
	finish()
	if entries.is_empty():
		return
	_entries = entries
	_active = true
	shown_names = []
	if GameManager.is_vr:
		_start_vr_camera()
	else:
		_start_flat_camera()
	var player := GameManager.local_player
	if is_instance_valid(player):
		player.set_intro_view(true)
	if is_instance_valid(GameManager.hud):
		GameManager.hud.set_intro_hidden(true)
	set_process(true)


## Cuts to card `index`: the camera on that duelist, and the card from its side (odd
## cards are mirrored).
func show_card(index: int) -> void:
	if not _active or index < 0 or index >= _entries.size():
		return
	var entry := _entries[index]
	var mirrored := index % 2 == 1
	_place_camera(_card_eye(entry["spawn"], mirrored))
	_card.play(str(entry["name"]), entry["texture"], mirrored)
	shown_names.append(str(entry["name"]))
	_whoosh.play()


## Gives the camera back and puts the HUD and the first-person body back. Safe to repeat.
func finish() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_card.stop()
	_canvas.visible = false
	_whoosh.stop()
	_teardown_camera()
	var player := GameManager.local_player
	if is_instance_valid(player):
		player.set_intro_view(false)
	if is_instance_valid(GameManager.hud):
		GameManager.hud.set_intro_hidden(false)
	_entries = []


func _process(_delta: float) -> void:
	var duel := GameManager.duel
	if duel == null or duel.state != DuelManager.State.INTRO:
		finish()
		return
	if GameManager.is_pause_open():
		# The VR pause panel floats where the player stands, out of the card camera's view.
		duel.on_intro_paused()
		return
	if not GameManager.is_vr:
		_fit_flat_card()


## The camera for one card: ahead of the spawn, eye height, turned back on the chest.
## The aim point moves left of the duelist on a normal card (the name panel is on the
## left, so they stand centre-right) and right of them on a mirrored one.
static func _card_eye(spawn: Transform3D, mirrored: bool) -> Transform3D:
	var facing := -spawn.basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length_squared() > 0.0001 else Vector3.FORWARD
	var chest := spawn.origin + Vector3.UP * LOOK_HEIGHT
	var eye := spawn.origin + facing * CAM_DISTANCE + Vector3.UP * CAM_HEIGHT
	var camera_right := (chest - eye).cross(Vector3.UP).normalized()
	var target := chest + camera_right * (FRAME_OFFSET if mirrored else -FRAME_OFFSET)
	return Transform3D(Basis.IDENTITY, eye).looking_at(target, Vector3.UP)


func _on_card_landed() -> void:
	if _active:
		_sting.play()


func _fit_flat_card() -> void:
	var screen := get_viewport().get_visible_rect().size
	var card_size := Vector2(TitleCard.SIZE)
	var fit := minf(screen.x / card_size.x, screen.y / card_size.y)
	var whole := floorf(fit)
	var scale := whole if whole >= 1.0 and whole / fit >= INTEGER_SCALE_MIN else fit
	_rect.size = (card_size * scale).floor()
	# Hugs the panel's side, so a wider screen than 16:9 still runs the panel to its edge.
	var x := screen.x - _rect.size.x if _card.is_mirrored() else 0.0
	_rect.position = Vector2(x, (screen.y - _rect.size.y) * 0.5).floor()


func _start_flat_camera() -> void:
	_restore_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "DuelIntroCamera"
	_camera.fov = FLAT_FOV
	_scene_parent().add_child(_camera)
	_camera.current = true
	_canvas.visible = true
	_fit_flat_card()


func _start_vr_camera() -> void:
	var player := GameManager.local_player
	var rig := player.rig as VRRig if is_instance_valid(player) and player.use_vr else null
	if rig == null:
		return
	_restore_origin = rig
	_restore_xr_camera = rig.camera
	_hmd_ref = rig.camera.transform
	_spectator = XROrigin3D.new()
	_spectator.name = "DuelIntroOrigin"
	_spectator_cam = XRCamera3D.new()
	_spectator_cam.name = "XRCamera3D"
	_spectator.add_child(_spectator_cam)
	_scene_parent().add_child(_spectator)
	_quad = MeshInstance3D.new()
	_quad.name = "TitleCardQuad"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(VR_CARD_WIDTH, VR_CARD_WIDTH * TitleCard.SIZE.y / TitleCard.SIZE.x)
	_quad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.no_depth_test = true
	material.render_priority = ScreenOverlay.RENDER_PRIORITY - 1
	material.albedo_texture = _card.get_texture()
	_quad.material_override = material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.position = Vector3(0.0, 0.0, -VR_CARD_DISTANCE)
	_spectator_cam.add_child(_quad)
	rig.current = false
	rig.camera.current = false
	_spectator.current = true
	_spectator_cam.current = true


func _place_camera(eye: Transform3D) -> void:
	if is_instance_valid(_camera):
		_camera.global_transform = eye
	if is_instance_valid(_spectator):
		_spectator.global_transform = (eye * _hmd_ref.inverse()).orthonormalized()


func _teardown_camera() -> void:
	if is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
	_camera = null
	if is_instance_valid(_restore_camera):
		_restore_camera.current = true
	_restore_camera = null
	if is_instance_valid(_spectator):
		_spectator.current = false
		if is_instance_valid(_spectator_cam):
			_spectator_cam.current = false
		_spectator.queue_free()
	_spectator = null
	_spectator_cam = null
	_quad = null
	if is_instance_valid(_restore_origin):
		_restore_origin.current = true
	if is_instance_valid(_restore_xr_camera):
		_restore_xr_camera.current = true
	_restore_origin = null
	_restore_xr_camera = null


func _audio_player(cue: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = AudioCatalog.get_stream(cue)
	player.bus = "Master"
	player.volume_db = volume_db
	add_child(player)
	return player


func _scene_parent() -> Node:
	if is_instance_valid(GameManager.main_root):
		return GameManager.main_root
	return self
