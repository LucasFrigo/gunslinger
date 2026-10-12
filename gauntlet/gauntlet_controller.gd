class_name GauntletController
extends Node
## Runs a GauntletLadder: sequences encounters, tracks lives and score,
## escalates by simply ordering harder archetypes/modifiers in the ladder
## resource. Data-driven: new towers are just new .tres files.

signal progress_changed(encounter_index: int, total: int, score: int, lives: int)

var ladder: GauntletLadder
var encounter_index := 0
var score := 0
var lives := 0
var running := false


func start(new_ladder: GauntletLadder) -> void:
	ladder = new_ladder
	encounter_index = 0
	score = 0
	lives = ladder.lives
	running = true
	_next_encounter()


func stop() -> void:
	running = false


func on_duel_finished(player_won: bool) -> void:
	if not running:
		return
	if player_won:
		score += ladder.encounters[encounter_index].score_reward
		encounter_index += 1
		if encounter_index >= ladder.encounters.size():
			_victory()
			return
	else:
		lives -= 1
		if lives <= 0:
			_defeat()
			return
		GameManager.show_message(tr("MSG_LIVES_LEFT") % lives, 2.0)
	_next_encounter()


func _next_encounter() -> void:
	var encounter := ladder.encounters[encounter_index]
	progress_changed.emit(encounter_index, ladder.encounters.size(), score, lives)
	GameManager.show_message(tr("MSG_DUEL_PROGRESS") % [
		encounter_index + 1, ladder.encounters.size(), encounter.label], 3.0)
	GameManager.begin_gauntlet_encounter(encounter)


func _victory() -> void:
	running = false
	PlayerSettings.record_gauntlet_run(encounter_index, score, true)
	GameManager.show_message(tr("MSG_GAUNTLET_CLEARED") + "\n" + tr("MSG_FINAL_SCORE") % score, 5.0)
	_back_to_menu()


func _defeat() -> void:
	running = false
	PlayerSettings.record_gauntlet_run(encounter_index, score, false)
	GameManager.show_message(tr("MSG_GAUNTLET_OVER") + "\n" + tr("MSG_SCORE") % score, 5.0)
	_back_to_menu()


func _back_to_menu() -> void:
	get_tree().create_timer(5.0, false, false, true).timeout.connect(
		GameManager.go_to_menu)
