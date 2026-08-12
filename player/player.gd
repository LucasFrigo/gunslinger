class_name Player
extends Node3D
## The local player: shared body (health, hitboxes, holster, revolver) with a
## swappable rig -- VR (XROrigin3D) or flat (mouse-look test harness).

signal died
signal holstered_changed(holstered: bool)

const VR_RIG := "res://player/vr_rig.tscn"
const FLAT_RIG := "res://player/flat_rig.tscn"
const HOLSTER_GRAB_RADIUS := 0.45
const POSE_SEND_HZ := 30.0

var use_vr := false
var rig: Node3D
var health := 1.0
var alive := true

@onready var rig_holder: Node3D = $RigHolder
@onready var holster: Node3D = $Holster
@onready var revolver: Revolver = $Holster/Revolver
@onready var head_hitbox: Hitbox = $HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox

var _pose_accum := 0.0
var _menu_panel: UIPanel3D
var _vr_message: Label3D
var _vr_message_timer := 0.0


func _ready() -> void:
	rig = load(VR_RIG if use_vr else FLAT_RIG).instantiate()
	rig_holder.add_child(rig)
	rig.trigger_changed.connect(_on_trigger_changed)
	rig.grip_pressed.connect(_on_grip_pressed)
	rig.cock_pressed.connect(_on_cock_pressed)
	rig.menu_button_pressed.connect(DebugMenu.toggle)

	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	revolver.fired.connect(_on_revolver_fired)


func _physics_process(_delta: float) -> void:
	_follow_body()


func _process(delta: float) -> void:
	_broadcast_pose(delta)
	_update_vr_message(delta)


# -- Body / hitboxes ------------------------------------------------------------

func _follow_body() -> void:
	var head: Transform3D = rig.get_head_transform()
	var yaw := Basis(Vector3.UP, head.basis.get_euler().y)

	head_hitbox.global_transform = Transform3D(yaw, head.origin)
	torso_hitbox.global_transform = Transform3D(
		yaw, Vector3(head.origin.x, global_position.y + 1.1, head.origin.z))

	# Holster rides the right hip, following the head's yaw.
	holster.global_transform = Transform3D(
		yaw,
		Vector3(head.origin.x, global_position.y + 0.9, head.origin.z) + yaw * Vector3(0.25, 0.0, 0.05))


func get_head_position() -> Vector3:
	return rig.get_head_transform().origin


func is_gun_drawn() -> bool:
	return revolver.drawn


func hitbox_rids() -> Array[RID]:
	return [head_hitbox.get_rid(), torso_hitbox.get_rid()]


# -- Duel lifecycle ---------------------------------------------------------------

func reset_for_duel(spawn: Transform3D) -> void:
	global_transform = spawn
	health = 1.0
	alive = true
	_holster_gun()
	revolver.reset()
	if rig is FlatRig:
		(rig as FlatRig).face_yaw(spawn.basis.get_euler().y)
		rig.position = Vector3.ZERO
	elif rig is VRRig:
		(rig as VRRig).reset_locomotion()


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array) -> void:
	if not alive:
		return
	if NetworkManager.is_active():
		# MP: the host's simulation is authoritative for hits on itself.
		if NetworkManager.is_host():
			GameManager.duel.mp_report_hit(true, trail_points)
		return
	health -= damage_mult
	if health <= 0.0:
		play_death_feedback()
		died.emit()
	else:
		ImpactFeedback.player_hurt(false)


func play_death_feedback() -> void:
	alive = false
	ImpactFeedback.player_hurt(true)
	GameManager.hud.flash_red()


# -- Gun handling -----------------------------------------------------------------

func _on_grip_pressed() -> void:
	if not use_vr:
		# Flat harness: RMB toggles draw/holster directly.
		_toggle_gun()
		return
	var hand: Vector3 = rig.get_right_hand_transform().origin
	if hand.distance_to(holster.global_position) <= HOLSTER_GRAB_RADIUS:
		_toggle_gun()


func _toggle_gun() -> void:
	if revolver.drawn:
		_holster_gun()
	else:
		_draw_gun()


func _draw_gun() -> void:
	if revolver.drawn:
		return
	revolver.drawn = true
	revolver.reparent(rig.get_gun_attach())
	revolver.transform = Transform3D.IDENTITY
	holstered_changed.emit(false)


func _holster_gun() -> void:
	revolver.drawn = false
	if revolver.get_parent() != holster:
		revolver.reparent(holster)
	revolver.transform = Transform3D.IDENTITY
	holstered_changed.emit(true)


func _on_trigger_changed(pressed: bool) -> void:
	if pressed and alive:
		revolver.try_fire(GameManager.tuning["auto_cock"], rig.get_aim_override())


func _on_cock_pressed() -> void:
	revolver.cock()


func _on_revolver_fired(origin: Vector3, direction: Vector3) -> void:
	var authoritative := not NetworkManager.is_active() or NetworkManager.is_host()
	Bullet.spawn(get_tree().current_scene, origin, direction,
			GameManager.tuning["bullet_speed"], authoritative, hitbox_rids(), true)
	NetworkManager.send_shot(origin, direction)


# -- Multiplayer pose broadcast ------------------------------------------------------

func _broadcast_pose(delta: float) -> void:
	if not NetworkManager.is_active():
		return
	_pose_accum += delta / maxf(Engine.time_scale, 0.001)
	if _pose_accum < 1.0 / POSE_SEND_HZ:
		return
	_pose_accum = 0.0
	var flags := 0
	if revolver.drawn:
		flags |= NetworkManager.POSE_FLAG_GUN_DRAWN
	if revolver.cocked:
		flags |= NetworkManager.POSE_FLAG_GUN_COCKED
	NetworkManager.send_pose(
		rig.get_head_transform(),
		rig.get_left_hand_transform(),
		rig.get_right_hand_transform(),
		flags)


# -- VR UI ------------------------------------------------------------------------

func show_menu_panel(menu_control: Control) -> void:
	hide_menu_panel()
	_menu_panel = UIPanel3D.new()
	_menu_panel.panel_size = Vector2(1.0, 0.7)
	add_child(_menu_panel)
	var head := get_head_position()
	var forward := -Basis(Vector3.UP, rig.get_head_transform().basis.get_euler().y).z
	_menu_panel.global_position = Vector3(head.x, global_position.y + 1.4, head.z) + forward * 1.8
	_menu_panel.look_at(head, Vector3.UP, true)
	_menu_panel.set_control(menu_control)


func hide_menu_panel() -> void:
	if is_instance_valid(_menu_panel):
		var control := _menu_panel.release_control()
		if control != null:
			GameManager.hud.reclaim_menu(control)
		_menu_panel.queue_free()
	_menu_panel = null


func show_vr_message(text: String, duration: float) -> void:
	if _vr_message == null:
		_vr_message = Label3D.new()
		_vr_message.font_size = 64
		_vr_message.pixel_size = 0.002
		_vr_message.outline_size = 16
		_vr_message.no_depth_test = true
		_vr_message.position = Vector3(0, -0.15, -1.6)
		var camera: Node3D = rig.get_node("XRCamera3D") if use_vr else null
		if camera != null:
			camera.add_child(_vr_message)
		else:
			return
	_vr_message.text = text
	_vr_message.visible = true
	_vr_message_timer = duration


func _update_vr_message(delta: float) -> void:
	if _vr_message == null or not _vr_message.visible:
		return
	_vr_message_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _vr_message_timer <= 0.0:
		_vr_message.visible = false
