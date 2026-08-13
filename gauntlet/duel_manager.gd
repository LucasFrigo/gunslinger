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
var _ai: DuelistAI
var _peer_holstered := false
var _bell_player: AudioStreamPlayer


func _ready() -> void:
	_bell_player = AudioStreamPlayer.new()
	_bell_player.bus = "Master"
	add_child(_bell_player)


# -- Public API ---------------------------------------------------------------

func start_ai_duel(ai: DuelistAI) -> void:
	stop()
	is_mp = false
	_ai = ai
	if not _ai.died.is_connected(_on_enemy_died):
		_ai.died.connect(_on_enemy_died)
	_bind_player()
	_enter(State.STANDOFF)


func host_start_mp_duel(scenario_index: int, _new_peer: int) -> void:
	stop()
	_mp_begin.rpc(scenario_index)


func stop() -> void:
	state = State.IDLE
	_ai = null
	_peer_holstered = false


## Host-side bullets report authoritative hits here during MP duels.
## `victim_is_local` is true when the HOST player was hit.
func mp_report_hit(victim_is_local: bool, trail_points: PackedVector3Array) -> void:
	if not is_mp or state == State.RESOLUTION or not NetworkManager.is_host():
		return
	var winner_is_host := not victim_is_local
	_mp_finish.rpc(winner_is_host, "Clean kill", trail_points)


func notify_kill_shot(trail_points: PackedVector3Array) -> void:
	kill_cam_requested.emit(trail_points)


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
			GameManager.show_message("Holster your weapon", 2.0)
		State.WAIT_SIGNAL:
			GameManager.show_message("Wait for the bell...", 2.0)
		State.DRAW:
			_ring_bell()
			GameManager.show_message("DRAW!", 1.5)
			if not is_mp and is_instance_valid(_ai):
				_ai.begin_draw()


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
			_finish_sp(false, "Foul: you drew early")


func _host_saw_foul() -> bool:
	if not is_mp or not NetworkManager.is_host():
		return false
	var player := GameManager.local_player
	if is_instance_valid(player) and player.is_gun_drawn():
		_mp_finish.rpc(false, "Foul: host drew early", PackedVector3Array())
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


func _on_enemy_died(trail_points: PackedVector3Array) -> void:
	if state == State.IDLE or is_mp:
		return
	notify_kill_shot(trail_points)
	_finish_sp(true, "Clean kill")


func _on_player_died(trail_points: PackedVector3Array) -> void:
	if state == State.IDLE:
		return
	if is_mp:
		return  # host bullet code reports MP hits via mp_report_hit
	var reason := "Shot down"
	if state == State.WAIT_SIGNAL:
		reason = "Shot down before the bell"
	notify_kill_shot(trail_points)
	_finish_sp(false, reason)


func _finish_sp(local_won: bool, reason: String) -> void:
	state = State.RESOLUTION
	if is_instance_valid(_ai):
		_ai.on_duel_over(local_won)
	duel_finished.emit(local_won, reason)


# -- Multiplayer RPCs -----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _mp_begin(scenario_index: int) -> void:
	is_mp = true
	_peer_holstered = false
	# Bind before setup: reset_for_duel emits holstered_changed, which the
	# client must relay to the host.
	_bind_player()
	GameManager.setup_mp_duel(scenario_index)
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
		_mp_finish.rpc(true, "Foul: opponent drew early", PackedVector3Array())


@rpc("any_peer", "call_remote", "reliable")
func _mp_holstered_state(holstered: bool) -> void:
	_peer_holstered = holstered


func _on_local_holster_changed(holstered: bool) -> void:
	if is_mp and not NetworkManager.is_host():
		_mp_holstered_state.rpc_id(1, holstered)


@rpc("authority", "call_local", "reliable")
func _mp_finish(winner_is_host: bool, reason: String, trail_points: PackedVector3Array) -> void:
	if state == State.RESOLUTION:
		return
	state = State.RESOLUTION
	var local_won := winner_is_host == NetworkManager.is_host()
	if not trail_points.is_empty():
		notify_kill_shot(trail_points)
	if not local_won and is_instance_valid(GameManager.local_player):
		GameManager.local_player.play_death_feedback()
	duel_finished.emit(local_won, reason)
