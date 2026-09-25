class_name SlotMachine
extends StaticBody3D
## Practice-hub flavour set piece, front along local +Z. Pull the lever (flat
## `interact` while looking at the cabinet, VR trigger with a hand on the
## lever knob) to spin three reels that stop left to right. No credits and
## nothing saved: a match flashes the topper and spits coins from the tray.

signal spin_finished(won: bool)

const SYMBOLS: Array[String] = ["7", "$", "BAR", "*", "@"]
const WIN_CHANCE := 0.12
const REEL_STOPS: Array[float] = [0.9, 1.3, 1.7]
const TICK := 0.06
## VR: hand within this of the lever arm counts as on the lever.
const LEVER_REACH := 0.16
const LEVER_PULL := 1.1
const FLASH_TIME := 2.5
const TOPPER_IDLE := "LUCKY 7"
const TOPPER_WIN := "WINNER!"
const TOPPER_COLOR := Color(1.0, 0.82, 0.35)
const TOPPER_FLASH := Color(1.0, 0.35, 0.2)

var spinning := false

var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _tick_left := 0.0
var _result: Array[int] = []
var _stopped: Array[bool] = [false, false, false]
var _flash_left := 0.0

@onready var _reels: Array[Label3D] = [$Reel0, $Reel1, $Reel2]
@onready var _lever: Node3D = $LeverPivot
@onready var _knob: Node3D = $LeverPivot/Knob
@onready var _topper: Label3D = $Topper
@onready var _tray: Node3D = $Tray


func _ready() -> void:
	_rng.randomize()
	for i in _reels.size():
		_reels[i].text = SYMBOLS[i % SYMBOLS.size()]
	_topper.text = TOPPER_IDLE
	_topper.modulate = TOPPER_COLOR


## Weighted flavour roll: `WIN_CHANCE` for three of a kind, otherwise a miss.
static func roll(rng: RandomNumberGenerator) -> Array[int]:
	var count := SYMBOLS.size()
	if rng.randf() < WIN_CHANCE:
		var symbol := rng.randi_range(0, count - 1)
		return [symbol, symbol, symbol]
	var result: Array[int] = [
		rng.randi_range(0, count - 1),
		rng.randi_range(0, count - 1),
		rng.randi_range(0, count - 1),
	]
	if result[0] == result[1] and result[1] == result[2]:
		result[2] = (result[2] + 1) % count
	return result


static func is_win(result: Array[int]) -> bool:
	return result.size() == 3 and result[0] == result[1] and result[1] == result[2]


func is_hand_on_lever(point: Vector3) -> bool:
	var closest := Geometry3D.get_closest_point_to_segment(
			point, _lever.global_position, _knob.global_position)
	return point.distance_to(closest) <= LEVER_REACH


## Flat: true when the camera ray reaches the cabinet before anything else.
func is_looked_at(origin: Vector3, direction: Vector3, reach: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, 1)
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == self


## False while the reels are still turning.
func pull() -> bool:
	if spinning:
		return false
	spinning = true
	_elapsed = 0.0
	_tick_left = 0.0
	_result = roll(_rng)
	_stopped = [false, false, false]
	_flash_left = 0.0
	_topper.text = TOPPER_IDLE
	_topper.modulate = TOPPER_COLOR
	var tween := create_tween()
	tween.tween_property(_lever, "rotation:x", LEVER_PULL, 0.12)
	tween.tween_property(_lever, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK)
	ImpactFeedback.slot_sound(&"slot_pull", _knob.global_position)
	return true


func _process(delta: float) -> void:
	_update_flash(delta)
	if not spinning:
		return
	_elapsed += delta
	_tick_left -= delta
	var tick := _tick_left <= 0.0
	if tick:
		_tick_left = TICK
	var all_stopped := true
	for i in _reels.size():
		if _stopped[i]:
			continue
		if _elapsed >= REEL_STOPS[i]:
			_stopped[i] = true
			_reels[i].text = SYMBOLS[_result[i]]
			ImpactFeedback.slot_sound(&"slot_stop", _reels[i].global_position, -4.0)
			continue
		all_stopped = false
		if tick:
			_reels[i].text = SYMBOLS[_rng.randi_range(0, SYMBOLS.size() - 1)]
	if all_stopped:
		spinning = false
		_finish()


func _finish() -> void:
	var won := is_win(_result)
	if won:
		_flash_left = FLASH_TIME
		_topper.text = TOPPER_WIN
		ImpactFeedback.slot_win(_tray.global_position, global_basis.z)
	spin_finished.emit(won)


func _update_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_topper.text = TOPPER_IDLE
		_topper.modulate = TOPPER_COLOR
		return
	_topper.modulate = TOPPER_FLASH if int(_flash_left * 6.0) % 2 == 0 else TOPPER_COLOR
