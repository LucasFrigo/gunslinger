class_name DuelManager
extends Node
## Duel state machine: Standoff -> WaitSignal -> Draw -> Resolution -> Reset.
## Lives as a child of the GameManager autoload so its node path is stable on
## every peer, which lets it own the multiplayer duel RPCs directly.
## Works both vs AI (single-player, host runs everything) and PvP (host
## authoritative, state broadcast to the client).

signal state_changed(state: int)
signal duel_finished(local_player_won: bool, reason: String)
## Kill-cam hook: world-space points of the winning bullet's trajectory.
signal kill_cam_requested(trail_points: PackedVector3Array)

enum State { IDLE, STANDOFF, WAIT_SIGNAL, DRAW, RESOLUTION }

const SIGNAL_DELAY_MIN := 1.5
const SIGNAL_DELAY_MAX := 5.0

var state: int = State.IDLE
var is_mp := false

var _timer := 0.0
var _wait_duration := 0.0
var _ais: Array[DuelistAI] = []
var _lineup_text := ""
## A loss with two or more NPCs left: they fight on after the replay.
var _survivors_fight := false
var _peer_holstered := false
var _bell_player: AudioStreamPlayer
var _end_player: AudioStreamPlayer
var _mp_health_host := CombatRules.DEFAULT_HEALTH
var _mp_health_peer := CombatRules.DEFAULT_HEALTH
## Horde wave clear: true plays the usual replay + DeathCam. False (a wave win) just
## fires the kill-cam fly-along and skips ReplayBuffer.mark_death, so DeathCam never starts.
var _replay_win := true


func _ready() -> void:
	_bell_player = AudioStreamPlayer.new()
	_bell_player.bus = "Master"
	add_child(_bell_player)
	_end_player = AudioStreamPlayer.new()
	_end_player.bus = "Master"
	add_child(_end_player)
	TimeManager.scale_changed.connect(_sync_end_pitch)


# -- Public API ---------------------------------------------------------------

func start_ai_duel(ais: Array[DuelistAI], lineup_text := "", replay_win := true) -> void:
	stop()
	is_mp = false
	_ais = ais.duplicate()
	_lineup_text = lineup_text
	_replay_win = replay_win
	for ai in _ais:
		ai.died.connect(_on_enemy_died.bind(ai))
	_bind_player()
	_enter(State.STANDOFF)


func host_start_mp_duel(scenario_index: int, _new_peer: int) -> void:
	stop()
	_mp_begin.rpc(scenario_index, randf())


func stop() -> void:
	state = State.IDLE
	_ais = []
	_survivors_fight = false
	_peer_holstered = false
	_replay_win = true
	ReplayBuffer.abort()
	DeathCam.stop()


## Hits only count during DRAW. Blocks post-foul / pre-bell damage (BUG-007).
func accepts_hits() -> bool:
	return state == State.DRAW


## Bullet gate for `Hitbox.receive_hit`: DRAW, or an NPC-on-NPC shot while the
## survivors fight on after a loss.
func accepts_hit(victim: Node, shooter: int) -> bool:
	return accepts_hits() or (victim is DuelistAI and shooter >= 1 and survivors_fighting())


## The survivors of a loss shoot at each other during the trailing orbit.
func survivors_fighting() -> bool:
	return _survivors_fight and state == State.RESOLUTION 			and DeathCam.phase == DeathCam.Phase.TRAILING


## NPCs may draw and shoot: the live round, or the survivors' fight.
func npcs_in_combat() -> bool:
	return state == State.DRAW or survivors_fighting()


## Host-side bullets report authoritative hits here during MP duels.
## `victim_is_local` is true when the HOST player was hit. `cut` is the hole the hit
## makes (`Hitbox.receive_hit`), sent ahead of the wound or the finish.
func mp_report_hit(victim_is_local: bool, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO, damage: float = 1.0,
		shooter_is_local := false, cut := {}) -> void:
	if not is_mp or not accepts_hits() or not NetworkManager.is_host():
		return
	var victim_is_host := victim_is_local
	if victim_is_host:
		var result := CombatRules.resolve(region, _mp_health_host, damage)
		_mp_health_host = result["health"]
		_send_chunk(true, cut, trail_points, result["died"])
		if result["died"]:
			_mp_finish.rpc(false, "MSG_REASON_CLEAN_KILL", trail_points, shooter_is_local, true)
			return
		_mp_wound.rpc(true, String(region), _mp_health_host)
	else:
		var peer_result := CombatRules.resolve(region, _mp_health_peer, damage)
		_mp_health_peer = peer_result["health"]
		_send_chunk(false, cut, trail_points, peer_result["died"])
		if peer_result["died"]:
			_mp_finish.rpc(true, "MSG_REASON_CLEAN_KILL", trail_points, shooter_is_local, false)
			return
		_mp_wound.rpc(false, String(region), _mp_health_peer)


## Host: every peer cuts the same hole at the host's clip time. Reliable channel 0, so
## it lands before the `_mp_wound` / `_mp_finish` sent after it. `cut` is empty for no hole.
func _send_chunk(victim_is_host: bool, cut: Dictionary, trail_points: PackedVector3Array,
		lethal: bool) -> void:
	if cut.is_empty():
		return
	_mp_chunk.rpc(victim_is_host, int(cut["bone"]), cut["local"] as Vector3, float(cut["radius"]),
			DummyBody.shot_dir(trail_points), ReplayBuffer.clip_time(), lethal)


## `killer_id` / `victim_id` are ReplayBuffer actor ids (0 host or SP player, 1 AI or joiner).
func notify_kill_shot(trail_points: PackedVector3Array, killer_id: int, victim_id: int) -> void:
	_play_duel_end()
	kill_cam_requested.emit(trail_points)
	ReplayBuffer.mark_death(killer_id, victim_id)


func _play_duel_end() -> void:
	_end_player.stream = AudioCatalog.get_stream(&"duel_end")
	_end_player.pitch_scale = 1.0 / maxf(AudioServer.playback_speed_scale, 0.001)
	_end_player.play()


func _sync_end_pitch(_scale: float) -> void:
	if _end_player == null or not _end_player.playing:
		return
	_end_player.pitch_scale = 1.0 / maxf(AudioServer.playback_speed_scale, 0.001)


# -- State machine ------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.IDLE or state == State.RESOLUTION:
		return
	# In MP only the host advances the clock.
	if is_mp and not NetworkManager.is_host():
		_watch_local_foul()
		return

	_timer += delta
	match state:
		State.STANDOFF:
			if _everyone_holstered():
				if _timer >= 1.5:
					_wait_duration = randf_range(SIGNAL_DELAY_MIN, SIGNAL_DELAY_MAX)
					_enter(State.WAIT_SIGNAL)
			else:
				_timer = 0.0
		State.WAIT_SIGNAL:
			_watch_local_foul()
			if _host_saw_foul():
				return
			if _timer >= _wait_duration:
				_enter(State.DRAW)
		State.DRAW:
			pass  # resolved by hit reports / death signals


func _enter(new_state: int) -> void:
	state = new_state
	_timer = 0.0
	if is_mp and NetworkManager.is_host():
		_mp_set_state.rpc(new_state)
	_apply_state()


func _apply_state() -> void:
	state_changed.emit(state)
	match state:
		State.STANDOFF:
			ReplayBuffer.begin()
			var holster := tr("MSG_HOLSTER")
			GameManager.show_message("%s
%s" % [_lineup_text, holster] if not _lineup_text.is_empty() else holster, 2.0)
		State.WAIT_SIGNAL:
			GameManager.show_message(tr("MSG_WAIT_BELL"), 2.0)
		State.DRAW:
			_ring_bell()
			GameManager.show_message(tr("MSG_DRAW"), 1.5)
			if not is_mp:
				for ai in _ais:
					if is_instance_valid(ai):
						ai.begin_draw()


func _ring_bell() -> void:
	_bell_player.stream = AudioCatalog.get_stream(&"bell")
	_bell_player.play()


# -- Foul & holster checks ------------------------------------------------------

func _everyone_holstered() -> bool:
	var player := GameManager.local_player
	var local_ok := is_instance_valid(player) and not player.is_gun_drawn()
	if not is_mp:
		return local_ok
	return local_ok and _peer_holstered


func _watch_local_foul() -> void:
	if state != State.WAIT_SIGNAL:
		return
	var player := GameManager.local_player
	if is_instance_valid(player) and player.is_gun_drawn():
		if is_mp and not NetworkManager.is_host():
			_mp_report_foul.rpc_id(1)
		elif not is_mp:
			_finish_sp(false, "MSG_REASON_FOUL_YOU")


func _host_saw_foul() -> bool:
	if not is_mp or not NetworkManager.is_host():
		return false
	var player := GameManager.local_player
	if is_instance_valid(player) and player.is_gun_drawn():
		_mp_finish.rpc(false, "MSG_REASON_FOUL_HOST", PackedVector3Array(), false, false)
		return true
	return false


# -- Single-player resolution ---------------------------------------------------

func _bind_player() -> void:
	var player := GameManager.local_player
	if not is_instance_valid(player):
		return
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if not player.holstered_changed.is_connected(_on_local_holster_changed):
		player.holstered_changed.connect(_on_local_holster_changed)


func _on_enemy_died(trail_points: PackedVector3Array, ai: DuelistAI) -> void:
	if not accepts_hits() or is_mp:
		return  # a corpse falling while the survivors fight is just a corpse
	ReplayBuffer.note_death(ai.actor_id)
	var left := _live_npc_count()
	if left > 0:
		GameManager.show_message(tr("MSG_NPCS_LEFT") % left, 1.5)
		return
	if _replay_win:
		notify_kill_shot(trail_points, ai.killed_by, ai.actor_id)
	else:
		# Horde wave clear: the fly-along and the sting, but no DeathCam / replay.
		_play_duel_end()
		kill_cam_requested.emit(trail_points)
	_finish_sp(true, "MSG_REASON_CLEAN_KILL" if _ais.size() == 1 else "MSG_REASON_LAST_STANDING")


func _live_npc_count() -> int:
	var count := 0
	for ai in _ais:
		if is_instance_valid(ai) and ai.is_alive():
			count += 1
	return count


func _on_player_died(trail_points: PackedVector3Array) -> void:
	if not accepts_hits() or is_mp:
		return  # host bullet code reports MP hits via mp_report_hit
	var killer := ReplayBuffer.ACTOR_OTHER
	var player := GameManager.local_player
	if is_instance_valid(player) and player.killed_by_self:
		killer = ReplayBuffer.ACTOR_HOST
	elif is_instance_valid(player) and player.killed_by >= ReplayBuffer.ACTOR_OTHER:
		killer = player.killed_by
	_survivors_fight = _live_npc_count() >= 2
	notify_kill_shot(trail_points, killer, ReplayBuffer.ACTOR_HOST)
	var reason := "MSG_REASON_SELF" if is_instance_valid(player) and player.killed_by_self else "MSG_REASON_SHOT_DOWN"
	_finish_sp(false, reason)


func _finish_sp(local_won: bool, reason: String) -> void:
	if state == State.RESOLUTION:
		return
	state = State.RESOLUTION
	if not _survivors_fight:
		for ai in _ais:
			if is_instance_valid(ai):
				ai.on_duel_over(local_won)
	duel_finished.emit(local_won, reason)


# -- Multiplayer RPCs -----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _mp_begin(scenario_index: int, time_of_day: float) -> void:
	DeathCam.stop()
	ReplayBuffer.abort()
	is_mp = true
	_peer_holstered = false
	_mp_health_host = CombatRules.player_max_health()
	_mp_health_peer = CombatRules.player_max_health()
	# Bind before setup: reset_for_duel emits holstered_changed, which the
	# client must relay to the host.
	_bind_player()
	GameManager.setup_mp_duel(scenario_index, time_of_day)
	state = State.STANDOFF
	_timer = 0.0
	_apply_state()


@rpc("authority", "call_remote", "reliable")
func _mp_set_state(new_state: int) -> void:
	state = new_state
	_apply_state()


@rpc("any_peer", "call_remote", "reliable")
func _mp_report_foul() -> void:
	if NetworkManager.is_host() and state == State.WAIT_SIGNAL:
		_mp_finish.rpc(true, "MSG_REASON_FOUL_OPPONENT", PackedVector3Array(), false, false)


@rpc("any_peer", "call_remote", "reliable")
func _mp_holstered_state(holstered: bool) -> void:
	_peer_holstered = holstered


func _on_local_holster_changed(holstered: bool) -> void:
	if is_mp and not NetworkManager.is_host():
		_mp_holstered_state.rpc_id(1, holstered)


@rpc("authority", "call_local", "reliable")
func _mp_wound(victim_is_host: bool, region_str: String, new_health: float) -> void:
	if state == State.RESOLUTION:
		return
	var i_am_victim := victim_is_host == NetworkManager.is_host()
	if i_am_victim and is_instance_valid(GameManager.local_player):
		GameManager.local_player.apply_wound(StringName(region_str), new_health)


## Every peer cuts the victim's body: `bone` / `local` / `radius` rebuild the cut
## (`DummyBody.cut_on_bone`), `dir` is the shot, `clip_t` the host's clip time.
@rpc("authority", "call_local", "reliable")
func _mp_chunk(victim_is_host: bool, bone: int, local: Vector3, radius: float, dir: Vector3,
		clip_t: float, lethal: bool) -> void:
	var body: DummyBody = null
	if victim_is_host == NetworkManager.is_host():
		if is_instance_valid(GameManager.local_player):
			body = GameManager.local_player.corpse_body()
	elif is_instance_valid(GameManager.remote_avatar):
		body = GameManager.remote_avatar.corpse_body()
	if body != null:
		body.knock_chunk({"bone": bone, "local": local, "radius": radius}, dir, clip_t, lethal)


@rpc("authority", "call_local", "reliable")
func _mp_finish(winner_is_host: bool, reason: String, trail_points: PackedVector3Array,
		killer_is_host: bool, victim_is_host: bool) -> void:
	if state == State.RESOLUTION:
		return
	state = State.RESOLUTION
	var local_won := winner_is_host == NetworkManager.is_host()
	if not trail_points.is_empty():
		var killer := ReplayBuffer.ACTOR_HOST if killer_is_host else ReplayBuffer.ACTOR_OTHER
		var victim := ReplayBuffer.ACTOR_HOST if victim_is_host else ReplayBuffer.ACTOR_OTHER
		notify_kill_shot(trail_points, killer, victim)
	# Only a killing shot falls; a foul has no trail and the loser stays frozen.
	if not local_won and is_instance_valid(GameManager.local_player):
		GameManager.local_player.play_death_feedback()
		if not trail_points.is_empty():
			GameManager.local_player.collapse(trail_points)
	elif local_won and not trail_points.is_empty() and is_instance_valid(GameManager.remote_avatar):
		GameManager.remote_avatar.collapse(trail_points)
	duel_finished.emit(local_won, reason)
