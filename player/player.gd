class_name Player
extends Node3D
## The local player: shared body (health, hitboxes, holster, revolver) with a
## swappable rig -- VR (XROrigin3D) or flat (mouse-look test harness).

signal died(trail_points: PackedVector3Array)
signal holstered_changed(holstered: bool)

const VR_RIG := "res://player/vr_rig.tscn"
const FLAT_RIG := "res://player/flat_rig.tscn"
const HOLSTER_GRAB_RADIUS := 0.45
const POSE_SEND_HZ := 30.0
const CHAMBER_PROXIMITY := 0.14

var use_vr := false
var rig: Node3D
var health := CombatRules.DEFAULT_HEALTH
var max_health := CombatRules.DEFAULT_HEALTH
var alive := true
var move_speed_mult := 1.0

@onready var rig_holder: Node3D = $RigHolder
@onready var holster: Node3D = $Holster
@onready var revolver: Revolver = $Holster/Revolver
@onready var head_hitbox: Hitbox = $HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox
@onready var arm_hitbox_l: Hitbox = $ArmHitboxL
@onready var arm_hitbox_r: Hitbox = $ArmHitboxR
@onready var leg_hitbox: Hitbox = $LegHitbox
@onready var ammo_belt: Area3D = $AmmoBelt

var _pose_accum := 0.0
var _menu_panel: UIPanel3D
var _vr_message: Label3D
var _vr_message_timer := 0.0
var _left_grip_held := false
var _held_cartridge: CartridgePhysical = null
var _reload_event := ""
var _reload_event_timer := 0.0
var _vr_reload_label: Label3D
var _prev_gate_open := false
var _dump_armed := true
var _close_armed := true
var _dump_hold_accum := 0.0
var _disarm_remaining := 0.0
var _leg_remaining := 0.0


func _ready() -> void:
	rig = load(VR_RIG if use_vr else FLAT_RIG).instantiate()
	rig_holder.add_child(rig)
	rig.trigger_changed.connect(_on_trigger_changed)
	rig.grip_pressed.connect(_on_grip_pressed)
	rig.cock_pressed.connect(_on_cock_pressed)
	rig.menu_button_pressed.connect(DebugMenu.toggle)
	if rig.has_signal("reload_pressed"):
		rig.reload_pressed.connect(_on_reload_pressed)
	if rig.has_signal("left_grip_changed"):
		rig.left_grip_changed.connect(_on_left_grip_changed)
	if rig.has_signal("gate_pressed"):
		rig.gate_pressed.connect(_on_gate_pressed)

	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	arm_hitbox_l.owner_entity = self
	arm_hitbox_r.owner_entity = self
	leg_hitbox.owner_entity = self
	revolver.fired.connect(_on_revolver_fired)
	revolver.shells_ejected.connect(_on_shells_ejected)
	revolver.state_changed.connect(_on_revolver_state_changed)
	revolver.dry_fired.connect(_on_revolver_dry_fired)
	_prev_gate_open = revolver.gate_open
	ammo_belt.visible = use_vr
	_refresh_reload_status()


func _physics_process(delta: float) -> void:
	_follow_body()
	_update_vr_reload(delta)
	_update_wound_status(delta)


func _process(delta: float) -> void:
	_broadcast_pose(delta)
	_update_vr_message(delta)
	_update_reload_event(delta)


# -- Body / hitboxes ------------------------------------------------------------

func _follow_body() -> void:
	var head: Transform3D = rig.get_head_transform()
	var yaw := Basis(Vector3.UP, head.basis.get_euler().y)

	head_hitbox.global_transform = Transform3D(yaw, head.origin)
	var torso_pos := Vector3(head.origin.x, global_position.y + 1.1, head.origin.z)
	torso_hitbox.global_transform = Transform3D(yaw, torso_pos)

	var left_arm := torso_pos + yaw * Vector3(-0.32, 0.22, 0.0)
	var right_arm := torso_pos + yaw * Vector3(0.32, 0.22, 0.0)
	if use_vr:
		left_arm = left_arm.lerp(rig.get_left_hand_transform().origin, 0.65)
		right_arm = right_arm.lerp(rig.get_right_hand_transform().origin, 0.65)
	arm_hitbox_l.global_transform = Transform3D(yaw, left_arm)
	arm_hitbox_r.global_transform = Transform3D(yaw, right_arm)
	leg_hitbox.global_transform = Transform3D(
		yaw, Vector3(head.origin.x, global_position.y + 0.4, head.origin.z))

	# Holster rides the right hip, following the head's yaw.
	holster.global_transform = Transform3D(
		yaw,
		Vector3(head.origin.x, global_position.y + 0.9, head.origin.z) + yaw * Vector3(0.25, 0.0, 0.05))

	# Ammo belt around the waist / lower torso.
	ammo_belt.global_transform = Transform3D(yaw, torso_pos)


func get_head_position() -> Vector3:
	return rig.get_head_transform().origin


func is_gun_drawn() -> bool:
	return revolver.drawn


func hitbox_rids() -> Array[RID]:
	return [
		head_hitbox.get_rid(),
		torso_hitbox.get_rid(),
		arm_hitbox_l.get_rid(),
		arm_hitbox_r.get_rid(),
		leg_hitbox.get_rid(),
	]


# -- Duel lifecycle ---------------------------------------------------------------

func reset_for_duel(spawn: Transform3D) -> void:
	global_transform = spawn
	max_health = CombatRules.player_max_health()
	health = max_health
	alive = true
	move_speed_mult = 1.0
	_disarm_remaining = 0.0
	_leg_remaining = 0.0
	_clear_held_cartridge(true)
	_holster_gun()
	revolver.reset()
	_refresh_health_hud()
	_dump_armed = true
	_close_armed = true
	_dump_hold_accum = 0.0
	_reload_event = ""
	_reload_event_timer = 0.0
	_prev_gate_open = revolver.gate_open
	_refresh_reload_status()
	if rig is FlatRig:
		# World yaw: FlatRig subtracts the Player root's spawn rotation so the
		# joiner is not spun 180° twice (BUG-004).
		(rig as FlatRig).face_yaw(spawn.basis.get_euler().y)
		rig.position = Vector3.ZERO
	elif rig is VRRig:
		(rig as VRRig).reset_locomotion()


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO) -> void:
	if not alive:
		return
	if NetworkManager.is_active():
		# MP: host resolves HP/status; application arrives via _mp_wound / _mp_finish.
		if NetworkManager.is_host():
			GameManager.duel.mp_report_hit(true, trail_points, region, damage_mult)
		return
	var result := CombatRules.resolve(region, health, damage_mult)
	health = result["health"]
	_refresh_health_hud()
	if result["died"]:
		play_death_feedback()
		died.emit(trail_points)
		return
	_apply_nonfatal(region)


## Host/client wound RPC: set HP and apply arm/leg status without re-resolving.
func apply_wound(region: StringName, new_health: float) -> void:
	if not alive:
		return
	health = new_health
	_refresh_health_hud()
	_apply_nonfatal(region)


func force_holster() -> void:
	_holster_gun()


func is_disarmed() -> bool:
	return _disarm_remaining > 0.0


func play_death_feedback() -> void:
	alive = false
	move_speed_mult = 1.0
	_disarm_remaining = 0.0
	_leg_remaining = 0.0
	ImpactFeedback.player_hurt(true)
	GameManager.hud.flash_red()
	_refresh_health_hud()


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


func _apply_nonfatal(region: StringName) -> void:
	ImpactFeedback.player_hurt(false)
	if region == CombatRules.REGION_ARM:
		force_holster()
		_disarm_remaining = float(GameManager.tuning["arm_disarm_duration"])
		GameManager.show_message("Disarmed!", 1.5)
	elif region == CombatRules.REGION_LEG:
		_leg_remaining = float(GameManager.tuning["leg_slow_duration"])
		move_speed_mult = float(GameManager.tuning["leg_speed_mult"])
		GameManager.show_message("Limp!", 1.5)


func _update_wound_status(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _disarm_remaining > 0.0:
		_disarm_remaining -= real_delta
		if _disarm_remaining < 0.0:
			_disarm_remaining = 0.0
	if _leg_remaining > 0.0:
		_leg_remaining -= real_delta
		if _leg_remaining <= 0.0:
			_leg_remaining = 0.0
			move_speed_mult = 1.0


func _refresh_health_hud() -> void:
	if GameManager.hud == null:
		return
	if GameManager.mode == GameManager.GameMode.MENU or GameManager.mode == GameManager.GameMode.BOOT:
		GameManager.hud.set_health(0.0, 0.0)
		return
	GameManager.hud.set_health(health, max_health)


func _draw_gun() -> void:
	if revolver.drawn or _disarm_remaining > 0.0:
		return
	revolver.drawn = true
	revolver.reparent(rig.get_gun_attach())
	revolver.transform = Transform3D.IDENTITY
	_dump_armed = true
	_close_armed = true
	_dump_hold_accum = 0.0
	holstered_changed.emit(false)
	_refresh_reload_status()


func _holster_gun() -> void:
	_clear_held_cartridge(true)
	if revolver.gate_open:
		revolver.close_gate()
	revolver.drawn = false
	if revolver.get_parent() != holster:
		revolver.reparent(holster)
	revolver.transform = Transform3D.IDENTITY
	holstered_changed.emit(true)
	_refresh_reload_status()


func _on_trigger_changed(pressed: bool) -> void:
	if pressed and alive:
		revolver.try_fire(GameManager.tuning["auto_cock"], rig.get_aim_override())


func _on_cock_pressed() -> void:
	if revolver.gate_open:
		_close_gate_from_player("closed")
	else:
		revolver.cock()


func _on_gate_pressed() -> void:
	if not alive or not use_vr or not revolver.drawn:
		return
	if revolver.gate_open:
		return
	if revolver.open_gate():
		_dump_armed = true
		_close_armed = true
		_dump_hold_accum = 0.0
		_flash_reload_event("GATE OPEN — shake to dump, belt to load")


func _on_reload_pressed() -> void:
	# Flat: R opens + dumps, or chambers one while open.
	if not alive or not revolver.drawn:
		return
	if revolver.gate_open:
		if revolver.try_chamber():
			_flash_reload_event("CHAMBERED — round seated (%d/%d)" % [
				revolver.rounds, revolver.max_rounds])
	else:
		if revolver.open_gate():
			var ejected := revolver.dump_rounds()
			if ejected <= 0:
				_flash_reload_event("GATE OPEN — empty, R to chamber")


func _on_shells_ejected(ejected: int) -> void:
	var origin := revolver.get_chamber_point()
	ShellCasingPlaceholder.spawn(get_tree().current_scene, origin, ejected)
	_flash_reload_event("DUMPED — %d shell(s)" % ejected)


func _on_revolver_dry_fired(reason: StringName) -> void:
	match reason:
		&"empty":
			_flash_reload_event("CLICK — EMPTY")
		&"gate_open":
			_flash_reload_event("CAN'T FIRE — gate open")
		&"uncocked":
			_flash_reload_event("CLICK — hammer not cocked")
		_:
			_flash_reload_event("CLICK — no shot")


func _on_revolver_state_changed() -> void:
	if _prev_gate_open and not revolver.gate_open:
		if _reload_event.is_empty() or not _reload_event.begins_with("GATE CLOSED"):
			_flash_reload_event("GATE CLOSED — ready (%d/%d)" % [
				revolver.rounds, revolver.max_rounds])
	elif (not _prev_gate_open) and revolver.gate_open and _reload_event.is_empty():
		_flash_reload_event("GATE OPEN")
	_prev_gate_open = revolver.gate_open
	_refresh_reload_status()


func _on_revolver_fired(origin: Vector3, direction: Vector3) -> void:
	var authoritative := not NetworkManager.is_active() or NetworkManager.is_host()
	Bullet.spawn(get_tree().current_scene, origin, direction,
			GameManager.tuning["bullet_speed"], authoritative, hitbox_rids(), true)
	NetworkManager.send_shot(origin, direction)
	_refresh_reload_status()


# -- VR reload gestures -----------------------------------------------------------

func _on_left_grip_changed(pressed: bool) -> void:
	_left_grip_held = pressed
	if not use_vr:
		return
	if pressed:
		_try_grab_from_belt()
		return
	_release_held_cartridge()


func _try_grab_from_belt() -> void:
	if not revolver.drawn or not revolver.gate_open:
		return
	if _holding_cartridge():
		return
	if revolver.rounds >= revolver.max_rounds:
		_flash_reload_event("CYLINDER FULL — bump/swing to close")
		return
	if not _hand_in_ammo_belt():
		_flash_reload_event("MISS BELT — hand must be near waist belt")
		return
	var attach := _cartridge_attach()
	if attach == null:
		return
	_held_cartridge = CartridgePhysical.spawn_held(attach)
	_flash_reload_event("ROUND IN HAND — release near cylinder")
	_refresh_reload_status()


func _release_held_cartridge() -> void:
	if not _holding_cartridge():
		return
	var chambered := false
	if revolver.gate_open and revolver.drawn:
		var hand_pos: Vector3 = rig.get_left_hand_transform().origin
		if hand_pos.distance_to(revolver.get_chamber_point()) <= CHAMBER_PROXIMITY:
			chambered = revolver.try_chamber()
	if chambered:
		_held_cartridge.queue_free()
		_held_cartridge = null
		_flash_reload_event("CHAMBERED — round seated (%d/%d)" % [
			revolver.rounds, revolver.max_rounds])
	else:
		_drop_held_cartridge()
		_flash_reload_event("DROPPED — release near cylinder to chamber")
	_refresh_reload_status()


func _update_vr_reload(delta: float) -> void:
	if not use_vr or not alive:
		return
	if not revolver.drawn:
		_clear_held_cartridge(true)
		_dump_hold_accum = 0.0
		_refresh_reload_status()
		return
	if not revolver.gate_open:
		_dump_hold_accum = 0.0
		return
	if not (rig is VRRig):
		return
	var vr := rig as VRRig
	var gun_speed: float = vr.right_hand_speed
	var left_speed: float = vr.left_hand_speed
	# Thresholds live in GameManager.tuning (debug panel → Gunplay / AI).
	var dump_speed: float = float(GameManager.tuning["reload_dump_speed"])
	var dump_hold: float = float(GameManager.tuning["reload_dump_hold"])
	var swing_close: float = float(GameManager.tuning["reload_swing_close"])
	var bump_close: float = float(GameManager.tuning["reload_bump_close"])
	var real_delta := delta / maxf(Engine.time_scale, 0.001)

	# Motion dump: sustain a deliberate shake — brief aim wobble should not eject.
	if revolver.rounds > 0 and _dump_armed:
		if gun_speed >= dump_speed:
			_dump_hold_accum += real_delta
			if _dump_hold_accum >= dump_hold:
				revolver.dump_rounds()
				_dump_armed = false
				_dump_hold_accum = 0.0
		else:
			_dump_hold_accum = 0.0
	elif gun_speed < dump_speed * 0.4:
		_dump_armed = true
		_dump_hold_accum = 0.0

	# Close: swing gun-hand or bump left hand into chamber.
	var hand_pos: Vector3 = vr.get_left_hand_transform().origin
	var near_chamber := hand_pos.distance_to(revolver.get_chamber_point()) <= CHAMBER_PROXIMITY
	var bump := near_chamber and left_speed >= bump_close
	var swing := gun_speed >= swing_close
	if (bump or swing) and _close_armed:
		var how := "bumped shut" if bump else "swung shut"
		_close_gate_from_player(how)
		_close_armed = false
	elif gun_speed < swing_close * 0.35 and left_speed < bump_close * 0.35:
		_close_armed = true


func _close_gate_from_player(how: String) -> void:
	if not revolver.gate_open:
		return
	_clear_held_cartridge(false)
	revolver.close_gate()
	_flash_reload_event("GATE CLOSED — %s (%d/%d)" % [
		how, revolver.rounds, revolver.max_rounds])


func _hand_in_ammo_belt() -> bool:
	var shape_node := ammo_belt.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return false
	var hand: Vector3 = rig.get_left_hand_transform().origin
	var local := ammo_belt.global_transform.affine_inverse() * hand
	var box := shape_node.shape as BoxShape3D
	if box == null:
		return false
	var half := box.size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


func _cartridge_attach() -> Node3D:
	if rig.has_method("get_cartridge_attach"):
		return rig.get_cartridge_attach()
	if rig.has_method("get_wrist_attach"):
		return rig.get_wrist_attach()
	return null


func _drop_held_cartridge() -> void:
	if not _holding_cartridge():
		return
	var pos := _held_cartridge.global_position
	var vel := Vector3.ZERO
	if rig is VRRig:
		# Impart a little left-hand motion so the drop feels physical.
		var left_basis: Basis = rig.get_left_hand_transform().basis
		vel = -left_basis.z * (rig as VRRig).left_hand_speed * 0.25
	_held_cartridge.drop_into_world(get_tree().current_scene, pos, vel)
	_held_cartridge = null


func _clear_held_cartridge(destroy: bool) -> void:
	if not _holding_cartridge():
		_held_cartridge = null
		return
	if destroy:
		_held_cartridge.queue_free()
	else:
		_drop_held_cartridge()
		return
	_held_cartridge = null


# -- Reload status HUD ------------------------------------------------------------

func _flash_reload_event(text: String) -> void:
	_reload_event = text
	_reload_event_timer = 2.0
	_refresh_reload_status()


func _update_reload_event(delta: float) -> void:
	if _reload_event_timer <= 0.0:
		return
	_reload_event_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _reload_event_timer <= 0.0:
		_reload_event = ""
		_refresh_reload_status()


func _holding_cartridge() -> bool:
	return _held_cartridge != null and is_instance_valid(_held_cartridge)


func _build_reload_status_text() -> String:
	var ammo_line := "AMMO %d / %d" % [revolver.rounds, revolver.max_rounds]
	if revolver.rounds <= 0:
		ammo_line += "  (EMPTY)"
	var gate_line := "GATE OPEN" if revolver.gate_open else "GATE CLOSED"
	var hand_line := "ROUND IN HAND" if _holding_cartridge() else "HAND EMPTY"
	var ready_line := "READY TO FIRE"
	if not revolver.drawn:
		ready_line = "HOLSTERED"
	elif revolver.gate_open:
		if use_vr:
			ready_line = "RELOADING — shake dump / belt grab / bump-swing close"
		else:
			ready_line = "RELOADING — R chamber / Space close"
	elif revolver.rounds <= 0:
		if use_vr:
			ready_line = "EMPTY — B open, shake dump, belt load"
		else:
			ready_line = "EMPTY — R open+dump, R load, Space close"
	var lines := [ammo_line, gate_line, hand_line, ready_line]
	if not _reload_event.is_empty():
		lines.append("> " + _reload_event)
	return "\n".join(lines)


func _refresh_reload_status() -> void:
	var text := _build_reload_status_text()
	if GameManager.hud != null:
		GameManager.hud.set_reload_status(text)
	_update_vr_reload_label(text)


func _update_vr_reload_label(text: String) -> void:
	if not use_vr:
		return
	if _vr_reload_label == null:
		var camera: Node3D = rig.get_node_or_null("XRCamera3D")
		if camera == null:
			return
		_vr_reload_label = Label3D.new()
		_vr_reload_label.font_size = 42
		_vr_reload_label.pixel_size = 0.0018
		_vr_reload_label.outline_size = 12
		_vr_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_vr_reload_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_vr_reload_label.no_depth_test = true
		_vr_reload_label.position = Vector3(-0.55, -0.25, -1.4)
		camera.add_child(_vr_reload_label)
	_vr_reload_label.text = text
	_vr_reload_label.visible = true


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
