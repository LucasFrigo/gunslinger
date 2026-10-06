class_name DuelistAI
extends Node3D
## AI opponent. Mirrors the duel FSM: waits for the bell, reacts after its
## archetype-defined reaction time, draws over draw_time, then fires with an
## accuracy cone. A spent cylinder opens a RELOADING window (reload_time).
## All behavior comes from an AIArchetype .tres file.

signal died(trail_points: PackedVector3Array)

enum AIState { IDLE, REACTING, DRAWING, SHOOTING, RELOADING, DISARMED, DEAD }

const RELOAD_ARM_BLEND := 0.3

var archetype: AIArchetype
var health := CombatRules.DEFAULT_HEALTH
var state: int = AIState.IDLE
var move_speed_mult := 1.0

var _target: Player
var _timer := 0.0
var _draw_progress := 0.0
var _rest_arm_basis: Basis
var _spawn_position := Vector3.ZERO
var _strafe_phase := 0.0
var _disarm_remaining := 0.0
var _leg_remaining := 0.0
var _death_tween: Tween

@onready var arm: Node3D = $Arm
@onready var revolver: Revolver = $Arm/Revolver
@onready var head_hitbox: Hitbox = $Head/HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox
@onready var arm_hitbox: Hitbox = $Arm/ArmHitbox
@onready var leg_hitbox: Hitbox = $LegHitbox

var _dummy: DummyBody
var _grip_target: Marker3D
var _index_pull := 0.0


func setup(new_archetype: AIArchetype, health_mult: float, target: Player) -> void:
	archetype = new_archetype
	health = archetype.health * health_mult
	_target = target
	_tint(archetype.body_color)
	capture_spawn()
	GameManager.show_message(archetype.display_name, 2.0)


func _ready() -> void:
	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	arm_hitbox.owner_entity = self
	leg_hitbox.owner_entity = self
	revolver.fired.connect(_on_fired)
	revolver.drawn = false
	revolver.held = false
	_rest_arm_basis = arm.transform.basis
	_attach_dummy()


## Store current world position as the strafe origin. Call after placing on the marker.
func capture_spawn() -> void:
	_spawn_position = global_position


## Called by the DuelManager when the bell rings.
func begin_draw() -> void:
	if state != AIState.IDLE or archetype == null:
		return
	capture_spawn()
	state = AIState.REACTING
	var speed_mult: float = maxf(GameManager.tuning["ai_speed_mult"], 0.05)
	_timer = (archetype.reaction_time
			+ randf_range(-1.0, 1.0) * archetype.reaction_variance) / speed_mult
	_timer = maxf(_timer, 0.05)


func on_duel_over(_player_won: bool) -> void:
	if state != AIState.DEAD:
		revolver.close_gate()
		state = AIState.IDLE
		_disarm_remaining = 0.0
		_leg_remaining = 0.0
		move_speed_mult = 1.0


func _process(delta: float) -> void:
	if state == AIState.DEAD or _target == null:
		return
	if DeathCam.blocks_combat():
		return
	_face_target()
	_strafe(delta)
	_tick_wounds(delta)
	match state:
		AIState.REACTING:
			_timer -= delta
			if _timer <= 0.0:
				_start_drawing()
		AIState.DRAWING:
			var speed_mult: float = maxf(GameManager.tuning["ai_speed_mult"], 0.05)
			_draw_progress += delta * speed_mult / maxf(archetype.draw_time, 0.05)
			_animate_arm(clampf(_draw_progress, 0.0, 1.0))
			if _draw_progress >= 1.0:
				if revolver.rounds <= 0:
					_begin_reload()
				else:
					state = AIState.SHOOTING
					_fire()
					if state == AIState.SHOOTING:
						_timer = archetype.followup_interval
		AIState.SHOOTING:
			_animate_arm(1.0)
			_timer -= delta
			if _timer <= 0.0:
				_fire()
				if state == AIState.SHOOTING:
					_timer = archetype.followup_interval
		AIState.RELOADING:
			_animate_arm(RELOAD_ARM_BLEND)
			_timer -= delta
			if _timer <= 0.0:
				_finish_reload()
		AIState.DISARMED:
			pass
	_drive_gun_hand(delta)


func _start_drawing() -> void:
	state = AIState.DRAWING
	_draw_progress = 0.0
	revolver.drawn = true
	revolver.held = true
	TimeManager.notify_enemy_draw()


func _face_target() -> void:
	var to_target := _target.get_head_position() - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		# Orient so the model's -Z (forward) points at the player.
		rotation.y = atan2(-to_target.x, -to_target.z)


func _strafe(delta: float) -> void:
	if archetype.move_style != AIArchetype.MoveStyle.STRAFE or state == AIState.IDLE:
		return
	_strafe_phase += delta * archetype.strafe_speed * move_speed_mult
	var right := global_transform.basis.x
	global_position = _spawn_position + right * sin(_strafe_phase) * 1.5


func _animate_arm(progress: float) -> void:
	# Blend the arm from resting (gun at the hip) to aiming at the player's chest.
	var aim_point := _target.get_head_position() + Vector3.DOWN * 0.25
	var aimed := arm.global_transform.looking_at(aim_point, Vector3.UP).basis
	var rest := global_transform.basis * _rest_arm_basis
	arm.global_transform.basis = rest.slerp(aimed, ease(progress, 0.4))


func _fire() -> void:
	if not is_instance_valid(_target) or not _target.alive:
		return
	if revolver.rounds <= 0:
		_begin_reload()
		return
	var muzzle := revolver.get_muzzle().global_position
	var direction := (_target.get_head_position() + Vector3.DOWN * 0.2 - muzzle).normalized()
	direction = _apply_accuracy_cone(direction)
	revolver.try_fire(true, direction)
	_index_pull = 1.0
	if revolver.rounds <= 0:
		_begin_reload()


func _begin_reload() -> void:
	if state == AIState.RELOADING or state == AIState.DEAD or archetype == null:
		return
	state = AIState.RELOADING
	revolver.open_gate()
	var speed_mult: float = maxf(GameManager.tuning["ai_speed_mult"], 0.05)
	_timer = maxf(archetype.reload_time / speed_mult, 0.05)


func _finish_reload() -> void:
	revolver.fill_cylinder()
	revolver.close_gate()
	state = AIState.SHOOTING
	_animate_arm(1.0)
	_fire()
	if state == AIState.SHOOTING:
		_timer = archetype.followup_interval


func _apply_accuracy_cone(direction: Vector3) -> Vector3:
	var max_angle := deg_to_rad(archetype.accuracy_angle_deg)
	if max_angle <= 0.0:
		return direction
	var axis := direction.cross(Vector3.UP).normalized()
	if not axis.is_finite() or axis.is_zero_approx():
		axis = Vector3.RIGHT
	axis = axis.rotated(direction, randf() * TAU)
	return direction.rotated(axis, randf() * max_angle)


func _on_fired(origin: Vector3, direction: Vector3) -> void:
	ReplayBuffer.record_shot(origin, direction, ReplayBuffer.ACTOR_OTHER)
	Bullet.spawn(get_tree().current_scene, origin, direction,
			archetype.bullet_speed, true, hitbox_rids(), false)


func capture_replay_pose() -> Dictionary:
	var flags := 0
	if revolver.drawn:
		flags |= NetworkManager.POSE_FLAG_GUN_DRAWN
	if revolver.drawn and not revolver.held:
		flags |= NetworkManager.POSE_FLAG_GUN_FREE
	if revolver.gate_open:
		flags |= NetworkManager.POSE_FLAG_GATE_OPEN
	flags |= revolver.chamber_index() << NetworkManager.POSE_FLAG_CHAMBER_SHIFT
	return {
		"root": global_transform,
		"head": ($Head as Node3D).global_transform,
		"left": global_transform,
		"right": arm.global_transform,
		"gun": revolver.global_transform,
		"flags": flags,
	}


func apply_replay_pose(pose: Dictionary) -> void:
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	global_transform = pose["root"]
	arm.global_transform = pose["right"]
	revolver.hold_replay_pose(pose["gun"], int(pose.get("flags", 0)))


func clear_replay_pose() -> void:
	revolver.release_replay_hold()


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO, _self_inflicted := false,
		_shooter_is_local := false) -> void:
	if state == AIState.DEAD:
		return
	var result := CombatRules.resolve(region, health, damage_mult)
	health = result["health"]
	if result["died"]:
		_die(trail_points)
		return
	if result["disarm"]:
		_disarm()
	if result["slow"]:
		_leg_remaining = float(GameManager.tuning["leg_slow_duration"])
		move_speed_mult = float(GameManager.tuning["leg_speed_mult"])


func _disarm() -> void:
	revolver.close_gate()
	_draw_progress = 0.0
	arm.transform.basis = _rest_arm_basis
	state = AIState.DISARMED
	_disarm_remaining = float(GameManager.tuning["arm_disarm_duration"])
	if revolver.get_parent() == arm:
		revolver.pain_jerk_into_world(get_tree().current_scene)


func _snatch_gun() -> void:
	if not is_instance_valid(revolver):
		return
	revolver.holster_to(arm)


func _tick_wounds(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _leg_remaining > 0.0:
		_leg_remaining -= real_delta
		if _leg_remaining <= 0.0:
			_leg_remaining = 0.0
			move_speed_mult = 1.0
	if state != AIState.DISARMED:
		return
	_disarm_remaining -= real_delta
	if _disarm_remaining > 0.0:
		return
	_disarm_remaining = 0.0
	_snatch_gun()
	state = AIState.IDLE
	if GameManager.duel != null and GameManager.duel.state == DuelManager.State.DRAW:
		begin_draw()


func _exit_tree() -> void:
	if not is_instance_valid(revolver):
		return
	var parent := revolver.get_parent()
	if parent == arm or parent == self:
		return
	revolver.queue_free()


func _die(trail_points: PackedVector3Array) -> void:
	state = AIState.DEAD
	revolver.close_gate()
	revolver.drawn = false
	revolver.held = false
	head_hitbox.set_deferred("monitorable", false)
	torso_hitbox.set_deferred("monitorable", false)
	arm_hitbox.set_deferred("monitorable", false)
	leg_hitbox.set_deferred("monitorable", false)
	_death_tween = create_tween()
	_death_tween.set_ignore_time_scale(true)
	_death_tween.tween_property(self, "rotation:x", -PI / 2.0, 0.6) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	died.emit(trail_points)


func hitbox_rids() -> Array[RID]:
	return [
		head_hitbox.get_rid(),
		torso_hitbox.get_rid(),
		arm_hitbox.get_rid(),
		leg_hitbox.get_rid(),
	]


func _attach_dummy() -> void:
	_dummy = DummyBody.spawn(self)
	_dummy.follow_travel(self)
	($Body as MeshInstance3D).visible = false
	($Head/HeadMesh as MeshInstance3D).visible = false
	($Head/Hat as MeshInstance3D).visible = false
	var grip := Marker3D.new()
	grip.name = "GripTarget"
	# Wrist sits just behind the revolver, which lives on this arm's -Z.
	grip.position = Vector3(0.0, 0.0, -0.16)
	arm.add_child(grip)
	_grip_target = grip
	# The gun arm is on +X.
	_dummy.drive_arm(true, grip)


func _drive_gun_hand(delta: float) -> void:
	if _dummy == null:
		return
	_index_pull = maxf(_index_pull - delta / 0.15, 0.0)
	if revolver.held:
		var anchor := revolver.get_node_or_null("GripAnchor") as Node3D
		_dummy.set_arm_target(true, anchor if anchor != null else _grip_target, true, DummyBody.WRIST_INSET)
		_dummy.set_hand_curl(true, HandFingers.Pose.PISTOL, _index_pull)
		return
	if _grip_target != null:
		_dummy.set_arm_target(true, _grip_target, true, DummyBody.WRIST_INSET)
	_dummy.set_hand_curl(true, HandFingers.Pose.OPEN, 0.0)


func _tint(color: Color) -> void:
	if _dummy != null:
		_dummy.set_tint(color)
		return
	for mesh in [$Body, $Head/HeadMesh, $Head/Hat]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		(mesh as MeshInstance3D).material_override = material
