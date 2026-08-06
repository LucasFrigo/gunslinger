class_name DuelistAI
extends Node3D
## AI opponent. Mirrors the duel FSM: waits for the bell, reacts after its
## archetype-defined reaction time, draws over draw_time, then fires with an
## accuracy cone. All behavior comes from an AIArchetype .tres file.

signal died(trail_points: PackedVector3Array)

enum AIState { IDLE, REACTING, DRAWING, SHOOTING, DEAD }

var archetype: AIArchetype
var health := 1.0
var state: int = AIState.IDLE

var _target: Player
var _timer := 0.0
var _draw_progress := 0.0
var _rest_arm_basis: Basis
var _spawn_position := Vector3.ZERO
var _strafe_phase := 0.0

@onready var arm: Node3D = $Arm
@onready var revolver: Revolver = $Arm/Revolver
@onready var head_hitbox: Hitbox = $Head/HeadHitbox
@onready var torso_hitbox: Hitbox = $TorsoHitbox


func setup(new_archetype: AIArchetype, health_mult: float, target: Player) -> void:
	archetype = new_archetype
	health = archetype.health * health_mult
	_target = target
	_tint(archetype.body_color)
	GameManager.show_message(archetype.display_name, 2.0)


func _ready() -> void:
	head_hitbox.owner_entity = self
	torso_hitbox.owner_entity = self
	revolver.fired.connect(_on_fired)
	revolver.drawn = false
	_rest_arm_basis = arm.transform.basis
	_spawn_position = position


## Called by the DuelManager when the bell rings.
func begin_draw() -> void:
	if state != AIState.IDLE or archetype == null:
		return
	state = AIState.REACTING
	var speed_mult: float = maxf(GameManager.tuning["ai_speed_mult"], 0.05)
	_timer = (archetype.reaction_time
			+ randf_range(-1.0, 1.0) * archetype.reaction_variance) / speed_mult
	_timer = maxf(_timer, 0.05)


func on_duel_over(_player_won: bool) -> void:
	if state != AIState.DEAD:
		state = AIState.IDLE


func _process(delta: float) -> void:
	if state == AIState.DEAD or _target == null:
		return
	_face_target()
	_strafe(delta)
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
				state = AIState.SHOOTING
				_fire()
				_timer = archetype.followup_interval
		AIState.SHOOTING:
			_animate_arm(1.0)
			_timer -= delta
			if _timer <= 0.0:
				_fire()
				_timer = archetype.followup_interval


func _start_drawing() -> void:
	state = AIState.DRAWING
	_draw_progress = 0.0
	revolver.drawn = true
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
	_strafe_phase += delta * archetype.strafe_speed
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
	var muzzle := revolver.get_muzzle().global_position
	var direction := (_target.get_head_position() + Vector3.DOWN * 0.2 - muzzle).normalized()
	direction = _apply_accuracy_cone(direction)
	if revolver.rounds <= 0:
		revolver.reset()
	revolver.try_fire(true, direction)


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
	Bullet.spawn(get_tree().current_scene, origin, direction,
			archetype.bullet_speed, true, hitbox_rids(), false)


func take_bullet_hit(damage_mult: float, trail_points: PackedVector3Array) -> void:
	if state == AIState.DEAD:
		return
	health -= damage_mult
	if health <= 0.0:
		_die(trail_points)


func _die(trail_points: PackedVector3Array) -> void:
	state = AIState.DEAD
	revolver.drawn = false
	head_hitbox.set_deferred("monitorable", false)
	torso_hitbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", -PI / 2.0, 0.6) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	died.emit(trail_points)


func hitbox_rids() -> Array[RID]:
	return [head_hitbox.get_rid(), torso_hitbox.get_rid()]


func _tint(color: Color) -> void:
	for mesh in [$Body, $Head/HeadMesh, $Head/Hat]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		(mesh as MeshInstance3D).material_override = material
