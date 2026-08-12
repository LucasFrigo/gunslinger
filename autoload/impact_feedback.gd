extends Node
## Central combat AV feedback: spatial SFX stubs, placeholder VFX, haptics.
## Call sites stay thin; swap assets via AudioCatalog / VfxCatalog OVERRIDES.

const REGION_HEAD := &"head"
const REGION_TORSO := &"torso"


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
