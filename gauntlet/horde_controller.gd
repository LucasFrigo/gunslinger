class_name HordeController
extends Node
## Runs a HordeWaves table: an endless run of standoffs, one life, full heal and
## reload between waves. Modeled on GauntletController, but DuelManager stays the
## per-wave state machine -- this only tracks the score and advances the wave.

var waves: HordeWaves
var wave := 0
var score := 0
var kills := 0
var running := false


func start(table: HordeWaves) -> void:
	waves = table
	wave = 0
	score = 0
	kills = 0
	running = true
	_next_wave()


func stop() -> void:
	running = false
	if is_instance_valid(GameManager.hud):
		GameManager.hud.set_horde_status(-1, 0)


## Credits the player's kill (crossfire kills score 0, but still count toward the clear).
func note_kill(_trail_points: PackedVector3Array, ai: DuelistAI) -> void:
	if ai.killed_by != ReplayBuffer.ACTOR_HOST:
		return
	score += waves.kill_points
	if ai.killed_region == CombatRules.REGION_HEAD:
		score += waves.headshot_bonus
	kills += 1
	_refresh_hud()


## Called by GameManager when the wave's duel resolves as a win. Returns the banner text.
func clear_wave() -> String:
	score += waves.wave_bonus * wave
	_refresh_hud()
	return tr("MSG_WAVE_CLEARED") % wave + "\n" + tr("MSG_SCORE") % score


func on_duel_finished(won: bool) -> void:
	if not running:
		return
	if won:
		_next_wave()
	else:
		_game_over()


func break_seconds() -> float:
	return waves.break_seconds


func _next_wave() -> void:
	wave += 1
	GameManager.begin_horde_wave(waves.lineup_for(wave), waves.speed_for(wave), wave)
	_refresh_hud()


func _game_over() -> void:
	running = false
	var waves_cleared := wave - 1
	var new_best := PlayerSettings.record_horde_run(waves_cleared, score)
	var message := tr("MSG_HORDE_OVER") + "\n" + tr("MSG_HORDE_RESULT") % [waves_cleared, score]
	if new_best:
		message += "\n" + tr("MSG_NEW_BEST")
	GameManager.show_message(message, 5.0)
	_hide_hud()
	_back_to_menu()


func _back_to_menu() -> void:
	get_tree().create_timer(5.0, false, false, true).timeout.connect(
		GameManager.go_to_menu)


func _refresh_hud() -> void:
	if is_instance_valid(GameManager.hud):
		GameManager.hud.set_horde_status(wave, score)


func _hide_hud() -> void:
	if is_instance_valid(GameManager.hud):
		GameManager.hud.set_horde_status(-1, score)
