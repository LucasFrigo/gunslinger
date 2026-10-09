class_name DuelistAI
extends Node3D
## AI opponent. Mirrors the duel FSM: waits for the bell, reacts after its
## archetype-defined reaction time, draws over draw_time, then fires with an
## accuracy cone. A spent cylinder opens a RELOADING window (reload_time).
## Aims at one live duelist (the player or another NPC) and retaliates against
## whoever wounds it. All behavior comes from an AIArchetype .tres file.

signal died(trail_points: PackedVector3Array)

enum AIState { IDLE, REACTING, DRAWING, SHOOTING, RELOADING, DISARMED, DEAD }

const RELOAD_ARM_BLEND := 0.3
const STRAFE_RANGE := 1.5

var archetype: AIArchetype
var health := CombatRules.DEFAULT_HEALTH
var state: int = AIState.IDLE
var move_speed_mult := 1.0
## ReplayBuffer actor id. SP: NPC slot i is actor i + 1.
var actor_id := ReplayBuffer.ACTOR_OTHER
## Actor id of the shooter whose bullet killed this NPC, or -1 while alive.
var killed_by := -1
## Hit region that killed this NPC, set alongside killed_by before _die.
var killed_region: StringName = &""
## Horde: always aims at the player and never retaliates against another NPC.
var focus_player := false
## Horde: per-wave speed multiplier (loop promotion), on top of ai_speed_mult. Set by setup().
var speed_mult := 1.0

var _target: Node3D
var _timer := 0.0
var _draw_progress := 0.0
var _rest_arm_basis: Basis
var _spawn_position := Vector3.ZERO
## Fixed at placement: the strafe line must not swing with the facing or a retarget teleports.
var _strafe_axis := Vector3.RIGHT
var _strafe_phase := 0.0
var _disarm_remaining := 0.0
var _leg_remaining := 0.0
var _death_tween: Tween

@onready var arm: Node3D = $Arm
@onready var revolver: Revolver = $Arm/Revolver
@onready var head_hitbox: Hitbox = $HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox
@onready var arm_hitbox_l: Hitbox = $ArmHitboxL
@onready var arm_hitbox_r: Hitbox = $ArmHitboxR
@onready var leg_hitbox_l: Hitbox = $LegHitboxL
@onready var leg_hitbox_r: Hitbox = $LegHitboxR

var _dummy: DummyBody
var _grip_target: Marker3D
var _index_pull := 0.0


func setup(new_archetype: AIArchetype, health_mult: float, shade := 0.0, speed := 1.0) -> void:
	archetype = new_archetype
	health = archetype.health * health_mult
	speed_mult = speed
	_tint(archetype.body_color.lightened(shade) if shade >= 0.0 else archetype.body_color.darkened(-shade))
	capture_spawn()


## Combined global tuning speed and this NPC's own (horde loop) multiplier.
func _speed() -> float:
	return maxf(float(GameManager.tuning["ai_speed_mult"]) * speed_mult, 0.05)


func _ready() -> void:
	for hitbox in _hitboxes():
		hitbox.owner_entity = self
	revolver.shooting_hand = &""  # BUG-017: an NPC shot must not buzz the player's controller
	revolver.fired.connect(_on_fired)
	revolver.drawn = false
	revolver.held = false
	_rest_arm_basis = arm.transform.basis
	_attach_dummy()


## Store current world position as the strafe origin. Call after placing on the marker.
func capture_spawn() -> void:
	_spawn_position = global_position
	_strafe_axis = global_transform.basis.x


func is_alive() -> bool:
	return state != AIState.DEAD


func get_head_position() -> Vector3:
	return ($Head as Node3D).global_position


func set_target(node: Node3D) -> void:
	_target = node


## Called by the DuelManager when the bell rings.
func begin_draw() -> void:
	if state != AIState.IDLE or archetype == null:
		return
	if not _is_live(_target):
		_pick_target()
	state = AIState.REACTING
	_timer = (archetype.reaction_time
			+ randf_range(-1.0, 1.0) * archetype.reaction_variance) / _speed()
	_timer = maxf(_timer, 0.05)


func on_duel_over(_player_won: bool) -> void:
	if state != AIState.DEAD:
		revolver.close_gate()
		state = AIState.IDLE
		_disarm_remaining = 0.0
		_leg_remaining = 0.0
		move_speed_mult = 1.0


func _process(delta: float) -> void:
	if state == AIState.DEAD:
		return
	if DeathCam.blocks_combat() and not GameManager.duel.survivors_fighting():
		return
	if state != AIState.IDLE and not _is_live(_target):
		_pick_target()
		if _target == null:
			on_duel_over(false)
			return
	# Several NPCs have no target before the bell: hold the marker yaw.
	if is_instance_valid(_target):
		_face_target()
		_strafe(delta)
	_tick_wounds(delta)
	match state:
		AIState.REACTING:
			_timer -= delta
			if _timer <= 0.0:
				_start_drawing()
		AIState.DRAWING:
			_draw_progress += delta * _speed() / maxf(archetype.draw_time, 0.05)
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
	if not _other_npc_drawn():
		TimeManager.notify_enemy_draw()


## One slow-mo burst per bell: only the first NPC to draw triggers it.
func _other_npc_drawn() -> bool:
	for ai in GameManager.current_ais:
		if ai != self and is_instance_valid(ai) and ai.is_alive() and ai.revolver.drawn:
			return true
	return false


func _is_live(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is Player:
		return (node as Player).alive
	if node is DuelistAI:
		return (node as DuelistAI).is_alive()
	return false


## Horde: this NPC always aims at the player while the player is alive.
func _focused() -> bool:
	return focus_player and _is_live(GameManager.local_player)


## A random live duelist other than this NPC, or null when none is left.
## Horde NPCs always pick the player while focused; once the player is dead
## (or outside horde) they fall back to the shipped free-for-all pick.
func _pick_target() -> void:
	if _focused():
		_target = GameManager.local_player
		return
	var rivals := GameManager.live_duelists()
	rivals.erase(self)
	_target = rivals.pick_random() if not rivals.is_empty() else null


func _target_head() -> Vector3:
	if _target is DuelistAI:
		return (_target as DuelistAI).get_head_position()
	return (_target as Player).get_head_position()


func _face_target() -> void:
	var to_target := _target_head() - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		# Orient so the model's -Z (forward) points at the player.
		rotation.y = atan2(-to_target.x, -to_target.z)


func _strafe(delta: float) -> void:
	if archetype.move_style != AIArchetype.MoveStyle.STRAFE or state == AIState.IDLE:
		return
	_strafe_phase += delta * archetype.strafe_speed * move_speed_mult
	var pos := _spawn_position + _strafe_axis * sin(_strafe_phase) * STRAFE_RANGE
	var half_width := GameManager.current_scenario.strafe_half_width if GameManager.current_scenario != null else 0.0
	if half_width > 0.0:
		pos.x = clampf(pos.x, -half_width, half_width)
	global_position = pos


func _animate_arm(progress: float) -> void:
	# Blend the arm from resting (gun at the hip) to aiming at the player's chest.
	var aim_point := _target_head() + Vector3.DOWN * 0.25
	var aimed := arm.global_transform.looking_at(aim_point, Vector3.UP).basis
	var rest := global_transform.basis * _rest_arm_basis
	arm.global_transform.basis = rest.slerp(aimed, ease(progress, 0.4))


func _fire() -> void:
	if not _is_live(_target):
		_pick_target()
		if _target == null:
			return
	if revolver.rounds <= 0:
		_begin_reload()
		return
	var muzzle := revolver.get_muzzle().global_position
	var direction := (_target_head() + Vector3.DOWN * 0.2 - muzzle).normalized()
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
	_timer = maxf(archetype.reload_time / _speed(), 0.05)


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
	ReplayBuffer.record_shot(origin, direction, actor_id)
	Bullet.spawn(get_tree().current_scene, origin, direction,
			archetype.bullet_speed, true, hitbox_rids(), false, 0.0, [], actor_id)


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
	# A corpse stands for the clip before the death; its fall takes over from there.
	_dummy.set_pose_driven(true)
	revolver.hold_replay_pose(pose["gun"], int(pose.get("flags", 0)))


func clear_replay_pose() -> void:
	revolver.release_replay_hold()


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO, _self_inflicted := false,
		_shooter_is_local := false, shooter := -1, cut := {}) -> void:
	if state == AIState.DEAD:
		return
	var result := CombatRules.resolve(region, health, damage_mult)
	health = result["health"]
	# Before `_die`: the gib leaves from the live pose, not the one `collapse` rescales.
	_dummy.knock_chunk(cut, DummyBody.shot_dir(trail_points), ReplayBuffer.clip_time(), result["died"])
	if result["died"]:
		killed_by = shooter if shooter >= 0 else ReplayBuffer.ACTOR_HOST
		killed_region = region
		_die(trail_points)
		return
	if not _focused():
		var attacker := ReplayBuffer.actor_node(shooter) if shooter >= 0 else null
		if attacker != self and _is_live(attacker):
			_target = attacker as Node3D
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
	if GameManager.duel != null and GameManager.duel.npcs_in_combat():
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
	for hitbox in _hitboxes():
		hitbox.set_deferred("monitorable", false)
	if DummyBody.ragdoll_on():
		revolver.release_into_world(get_tree().current_scene, DummyBody.gun_fling(trail_points),
				DummyBody.gun_spin(trail_points), false)
		_dummy.collapse(trail_points)
	else:
		revolver.drawn = false
		revolver.held = false
		_death_tween = create_tween()
		_death_tween.set_ignore_time_scale(true)
		_death_tween.tween_property(self, "rotation:x", -PI / 2.0, 0.6) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	died.emit(trail_points)


## The mannequin that falls on death. `DeathCam` orbits its chest.
func corpse_body() -> DummyBody:
	return _dummy


func _hitboxes() -> Array[Hitbox]:
	return [head_hitbox, torso_hitbox, arm_hitbox_l, arm_hitbox_r, leg_hitbox_l, leg_hitbox_r]


func hitbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for hitbox in _hitboxes():
		rids.append(hitbox.get_rid())
	return rids


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
	_dummy.attach_hitboxes(head_hitbox, torso_hitbox, arm_hitbox_l, arm_hitbox_r,
			leg_hitbox_l, leg_hitbox_r)


func _drive_gun_hand(delta: float) -> void:
	if _dummy == null:
		return
	_index_pull = maxf(_index_pull - delta / 0.15, 0.0)
	_dummy.set_gun_arm(&"R" if revolver.held else &"")
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
