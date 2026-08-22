class_name Player
extends Node3D
## The local player: shared body (health, hitboxes, holster, revolver) with a
## swappable rig -- VR (XROrigin3D) or flat (mouse-look test harness).

signal died(trail_points: PackedVector3Array)
signal holstered_changed(holstered: bool)

const VR_RIG := "res://player/vr_rig.tscn"
const FLAT_RIG := "res://player/flat_rig.tscn"
const HOLSTER_GRAB_RADIUS := 0.45
const HOLSTER_HIP := Vector3(0.25, 0.0, 0.05)
const POSE_SEND_HZ := 30.0
const RELOAD_VIZ_NAME := "_ReloadVolumeViz"
const GUN_RECOVER_Y := -5.0
const GUN_RECOVER_DIST := 20.0
const HAND_LEFT := &"left_hand"
const HAND_RIGHT := &"right_hand"

enum GunHand { NONE, LEFT, RIGHT }

var use_vr := false
var rig: Node3D
var health := CombatRules.DEFAULT_HEALTH
var max_health := CombatRules.DEFAULT_HEALTH
var alive := true
var move_speed_mult := 1.0
var killed_by_self := false

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
var _holding_hand: int = GunHand.NONE
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
var _jam_clear_accum := 0.0


func _ready() -> void:
	rig = load(VR_RIG if use_vr else FLAT_RIG).instantiate()
	rig_holder.add_child(rig)
	rig.trigger_changed.connect(_on_trigger_changed)
	rig.grip_changed.connect(_on_grip_changed)
	rig.cock_pressed.connect(_on_cock_pressed)
	rig.menu_button_pressed.connect(DebugMenu.toggle)
	if rig.has_signal("reload_pressed"):
		rig.reload_pressed.connect(_on_reload_pressed)
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
	revolver.jam_enabled = not use_vr
	revolver.holster_to(holster)
	_holding_hand = GunHand.NONE
	_refresh_reload_status()
	set_reload_volume_debug(DebugMenu.show_reload_volumes)


func _physics_process(delta: float) -> void:
	_follow_body()
	_recover_free_gun()
	_update_vr_spin()
	_update_vr_reload(delta)
	_update_wound_status(delta)
	_update_jam_clear(delta)


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

	# Holster rides the chosen hip, following the head's yaw.
	var hip := HOLSTER_HIP
	if int(GameManager.tuning["holster_side"]) != 0:
		hip.x = -hip.x
	holster.global_transform = Transform3D(
		yaw,
		Vector3(head.origin.x, global_position.y + 1.0, head.origin.z) + yaw * hip)

	# Ammo belt around the waist / lower torso.
	ammo_belt.global_transform = Transform3D(yaw, torso_pos)


func get_head_position() -> Vector3:
	return rig.get_head_transform().origin


func is_gun_drawn() -> bool:
	return revolver.drawn


func held_gun_hand() -> StringName:
	if revolver != null and revolver.held and _holding_hand != GunHand.NONE:
		return _holding_hand_name()
	return &""


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
	killed_by_self = false
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
	_jam_clear_accum = 0.0
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
		region: StringName = CombatRules.REGION_TORSO, self_inflicted := false) -> void:
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
		killed_by_self = self_inflicted
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

func _on_grip_changed(hand: StringName, pressed: bool) -> void:
	if not use_vr:
		if pressed:
			_toggle_gun()
		return
	if pressed:
		_on_vr_grip_press(hand)
	else:
		_on_vr_grip_release(hand)


func _on_vr_grip_press(hand: StringName) -> void:
	if not alive:
		return
	if revolver.held and _holding_hand_name() == hand:
		return
	var near_gun := _hand_near_gun(hand)
	var near_holster := _hand_near_holster(hand)
	if revolver.drawn and near_gun:
		if _holding_cartridge() and rig is VRRig:
			var attach := (rig as VRRig).get_cartridge_attach(hand)
			if _held_cartridge.get_parent() == attach:
				_drop_held_cartridge()
		_attach_gun_to_hand(hand)
		return
	if not revolver.drawn:
		if near_holster:
			_attach_gun_to_hand(hand)
		return
	if revolver.held:
		_try_grab_from_belt()


func _on_vr_grip_release(hand: StringName) -> void:
	if revolver.held and _holding_hand_name() == hand:
		var speed := 0.0
		if rig is VRRig:
			speed = (rig as VRRig).hand_speed(hand)
		var max_speed := float(GameManager.tuning["gun_holster_max_speed"])
		var near_holster := _hand_near_holster(hand)
		if near_holster and speed < max_speed:
			_holster_gun()
		else:
			_toss_gun(hand)
		return
	_release_held_cartridge()


func _toggle_gun() -> void:
	if revolver.drawn:
		_holster_gun()
	else:
		_attach_gun_to_hand(HAND_RIGHT)


func _attach_gun_to_hand(hand: StringName) -> void:
	var was_holstered := not revolver.drawn
	if was_holstered and _disarm_remaining > 0.0:
		return
	revolver.attach_to(_gun_attach_node(hand), hand)
	_holding_hand = GunHand.LEFT if hand == HAND_LEFT else GunHand.RIGHT
	_dump_armed = true
	_close_armed = true
	_dump_hold_accum = 0.0
	if was_holstered:
		holstered_changed.emit(false)
	else:
		CombatHaptics.catch_gun(hand)
	_refresh_reload_status()


func _toss_gun(hand: StringName) -> void:
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	if rig is VRRig:
		var vr := rig as VRRig
		vel = vr.hand_velocity(hand) * float(GameManager.tuning["gun_throw_scale"])
		spin = vr.hand_angular_velocity(hand) * float(GameManager.tuning["gun_throw_spin_scale"])
	revolver.release_into_world(get_tree().current_scene, vel, spin)
	_holding_hand = GunHand.NONE
	_refresh_reload_status()


func _gun_attach_node(hand: StringName) -> Node3D:
	if rig is VRRig:
		return (rig as VRRig).get_gun_attach(hand)
	return rig.get_gun_attach()


func _holding_hand_name() -> StringName:
	return HAND_LEFT if _holding_hand == GunHand.LEFT else HAND_RIGHT


func _update_vr_spin() -> void:
	if not use_vr or not (rig is VRRig):
		return
	if not revolver.held or _holding_hand == GunHand.NONE:
		if revolver.is_spin_active():
			revolver.end_spin(true)
		return
	var stick: Vector2 = (rig as VRRig).get_stick(_holding_hand_name())
	var thresh := float(GameManager.tuning.get("spin_stick_threshold", 0.55))
	if stick.y <= -thresh:
		revolver.begin_spin()
	elif stick.y >= thresh:
		revolver.end_spin(false)


func _off_hand_name() -> StringName:
	return HAND_RIGHT if _holding_hand == GunHand.LEFT else HAND_LEFT


func _hand_position(hand: StringName) -> Vector3:
	if rig is VRRig:
		return (rig as VRRig).get_hand_transform(hand).origin
	return rig.get_right_hand_transform().origin


func _hand_near_holster(hand: StringName) -> bool:
	return _hand_position(hand).distance_to(holster.global_position) <= HOLSTER_GRAB_RADIUS


func _hand_near_gun(hand: StringName) -> bool:
	var radius := float(GameManager.tuning["gun_catch_radius"])
	return _hand_position(hand).distance_to(revolver.global_position) <= radius


func _recover_free_gun() -> void:
	if not revolver.drawn or revolver.held:
		return
	if revolver.global_position.y < GUN_RECOVER_Y:
		_holster_gun()
		return
	if revolver.global_position.distance_to(global_position) > GUN_RECOVER_DIST:
		_holster_gun()


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


func _update_jam_clear(delta: float) -> void:
	if use_vr or not revolver.jammed:
		_jam_clear_accum = 0.0
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var pitch := 0.0
	if rig is FlatRig:
		pitch = (rig as FlatRig).get_look_pitch()
	var looking_down := pitch <= -float(GameManager.tuning["jam_clear_pitch"])
	var holding := alive and revolver.held and Input.is_action_pressed("cock_hammer")
	if looking_down and holding:
		_jam_clear_accum += real_delta
		_refresh_reload_status()
		if _jam_clear_accum >= float(GameManager.tuning["jam_clear_hold"]):
			revolver.clear_jam()
			_jam_clear_accum = 0.0
			_flash_reload_event("CLEARED — ready")
	elif _jam_clear_accum > 0.0:
		_jam_clear_accum = 0.0
		_refresh_reload_status()


func _refresh_health_hud() -> void:
	if GameManager.hud == null:
		return
	if GameManager.mode == GameManager.GameMode.MENU or GameManager.mode == GameManager.GameMode.BOOT:
		GameManager.hud.set_health(0.0, 0.0)
		return
	GameManager.hud.set_health(health, max_health)


func _draw_gun() -> void:
	_attach_gun_to_hand(HAND_RIGHT)


func _holster_gun() -> void:
	_clear_held_cartridge(true)
	if revolver.gate_open:
		revolver.close_gate()
	revolver.holster_to(holster)
	_holding_hand = GunHand.NONE
	holstered_changed.emit(true)
	_refresh_reload_status()


func _on_trigger_changed(hand: StringName, pressed: bool) -> void:
	if not pressed or not alive:
		return
	if use_vr and (not revolver.held or hand != _holding_hand_name()):
		return
	revolver.try_fire(GameManager.tuning["auto_cock"], rig.get_aim_override())


func _on_cock_pressed(hand: StringName) -> void:
	if use_vr and (not revolver.held or hand != _holding_hand_name()):
		return
	if revolver.gate_open:
		_close_gate_from_player("closed")
	elif not revolver.jammed:
		revolver.cock()


func _on_gate_pressed(hand: StringName) -> void:
	if not use_vr:
		return
	if revolver.held and hand == _holding_hand_name():
		if not alive:
			return
		if revolver.gate_open:
			return
		if revolver.open_gate():
			_dump_armed = true
			_close_armed = true
			_dump_hold_accum = 0.0
			_flash_reload_event("GATE OPEN — shake to dump, belt to load")
		return
	if hand == HAND_LEFT:
		DebugMenu.toggle()


func _on_reload_pressed() -> void:
	# Flat: R opens + dumps, or chambers one while open.
	if not alive or not revolver.held:
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
		&"jammed":
			_flash_reload_event("JAMMED — look down, hold Space")
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
			GameManager.tuning["bullet_speed"], authoritative, hitbox_rids(), true,
			float(GameManager.tuning.get("self_hit_grace", 0.28)))
	NetworkManager.send_shot(origin, direction)
	_refresh_reload_status()


# -- VR reload gestures -----------------------------------------------------------

func _try_grab_from_belt() -> void:
	if not revolver.held or not revolver.gate_open:
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
	if revolver.gate_open and revolver.held and _probe_overlaps(revolver.chamber_area):
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
	if not revolver.held:
		if not revolver.drawn:
			if _holding_cartridge():
				_clear_held_cartridge(true)
				_refresh_reload_status()
			_dump_hold_accum = 0.0
		else:
			_dump_hold_accum = 0.0
		return
	if not revolver.gate_open:
		_dump_hold_accum = 0.0
		return
	if not (rig is VRRig):
		return
	var vr := rig as VRRig
	var gun_speed: float = vr.hand_speed(_holding_hand_name())
	var off_speed: float = vr.hand_speed(_off_hand_name())
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

	# Close: swing gun-hand or bump off-hand into the bump volume.
	var bump := _probe_overlaps(revolver.bump_area) and off_speed >= bump_close
	var swing := gun_speed >= swing_close
	if (bump or swing) and _close_armed:
		var how := "bumped shut" if bump else "swung shut"
		_close_gate_from_player(how)
		_close_armed = false
	elif gun_speed < swing_close * 0.35 and off_speed < bump_close * 0.35:
		_close_armed = true


func _close_gate_from_player(how: String) -> void:
	if not revolver.gate_open:
		return
	_clear_held_cartridge(false)
	revolver.close_gate()
	_flash_reload_event("GATE CLOSED — %s (%d/%d)" % [
		how, revolver.rounds, revolver.max_rounds])


func _hand_in_ammo_belt() -> bool:
	return _probe_overlaps(ammo_belt)


func _reload_probe() -> Area3D:
	if not (rig is VRRig):
		return null
	var vr := rig as VRRig
	if revolver.held:
		return vr.get_reload_probe(_off_hand_name())
	return vr.get_reload_probe(HAND_LEFT)


func _probe_overlaps(area: Area3D) -> bool:
	var probe := _reload_probe()
	if probe == null or area == null:
		return false
	return probe.overlaps_area(area)


func set_reload_volume_debug(show: bool) -> void:
	for shape in _reload_volume_shapes():
		_set_reload_shape_viz(shape, show)


func _reload_volume_shapes() -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	_collect_reload_shape(shapes, ammo_belt)
	if revolver != null:
		_collect_reload_shape(shapes, revolver.chamber_area)
		_collect_reload_shape(shapes, revolver.bump_area)
	if rig is VRRig:
		var vr := rig as VRRig
		_collect_reload_shape(shapes, vr.get_reload_probe(HAND_LEFT))
		_collect_reload_shape(shapes, vr.get_reload_probe(HAND_RIGHT))
	return shapes


func _collect_reload_shape(shapes: Array[CollisionShape3D], area: Area3D) -> void:
	if area == null:
		return
	var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		shapes.append(shape_node)


func _set_reload_shape_viz(shape_node: CollisionShape3D, show: bool) -> void:
	var existing := shape_node.get_node_or_null(RELOAD_VIZ_NAME)
	if not show:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		return
	var mesh := _mesh_for_reload_shape(shape_node.shape)
	if mesh == null:
		return
	var vis := MeshInstance3D.new()
	vis.name = RELOAD_VIZ_NAME
	vis.mesh = mesh
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _reload_viz_color(shape_node)
	mat.no_depth_test = true
	vis.material_override = mat
	shape_node.add_child(vis)


func _mesh_for_reload_shape(shape: Shape3D) -> Mesh:
	if shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = (shape as SphereShape3D).radius
		sphere.height = (shape as SphereShape3D).radius * 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		return sphere
	if shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		return box
	if shape is CapsuleShape3D:
		var capsule := CapsuleMesh.new()
		var cap := shape as CapsuleShape3D
		capsule.radius = cap.radius
		capsule.height = cap.height
		return capsule
	return null


func _reload_viz_color(shape_node: CollisionShape3D) -> Color:
	var area := shape_node.get_parent()
	if area == ammo_belt:
		return Color(0.85, 0.55, 0.2, 0.35)
	if revolver != null and area == revolver.chamber_area:
		return Color(0.2, 0.9, 0.35, 0.4)
	if revolver != null and area == revolver.bump_area:
		return Color(0.2, 0.7, 1.0, 0.35)
	return Color(0.95, 0.3, 0.85, 0.4)


func _cartridge_attach() -> Node3D:
	if rig is VRRig:
		var hand := _off_hand_name() if revolver.held else HAND_LEFT
		return (rig as VRRig).get_cartridge_attach(hand)
	if rig.has_method("get_wrist_attach"):
		return rig.get_wrist_attach()
	return null


func _drop_held_cartridge() -> void:
	if not _holding_cartridge():
		return
	var pos := _held_cartridge.global_position
	var vel := Vector3.ZERO
	if rig is VRRig:
		var vr := rig as VRRig
		var off := _off_hand_name() if revolver.held else HAND_LEFT
		vel = vr.hand_velocity(off) * 0.25
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
	if revolver.jammed:
		ready_line = "JAMMED — look down, hold Space"
		var hold := float(GameManager.tuning["jam_clear_hold"])
		if hold > 0.0 and _jam_clear_accum > 0.0:
			ready_line += " (%d%%)" % int(100.0 * _jam_clear_accum / hold)
	elif not revolver.drawn:
		ready_line = "HOLSTERED"
	elif not revolver.held:
		ready_line = "GUN IN AIR — catch to fire"
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
	if revolver.drawn and not revolver.held:
		flags |= NetworkManager.POSE_FLAG_GUN_FREE
	if revolver.is_spin_active():
		flags |= NetworkManager.POSE_FLAG_GUN_SPINNING
	if _holding_hand == GunHand.LEFT:
		flags |= NetworkManager.POSE_FLAG_GUN_HELD_LEFT
	if int(GameManager.tuning["holster_side"]) != 0:
		flags |= NetworkManager.POSE_FLAG_HOLSTER_LEFT
	var gun_xf := Transform3D.IDENTITY
	if revolver.drawn and (not revolver.held or revolver.is_spin_active()):
		gun_xf = revolver.global_transform
	NetworkManager.send_pose(
		rig.get_head_transform(),
		rig.get_left_hand_transform(),
		rig.get_right_hand_transform(),
		flags,
		gun_xf)


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
