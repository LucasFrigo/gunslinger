class_name PracticeHub
extends ScenarioBase
## Practice lot (`dev/build_practice_hub_blender.py`). A scenario with no
## EnemySpawn and no duel: spawns a PracticeBottle on every `BottleSpot*` empty
## and the slot machine on `SlotSpot`, and counts every shatter for the HUD and
## the scoreboard on the berm. Not in `GameManager.SCENARIOS`.

signal broken_changed(count: int)

const BOTTLE_SCENE := preload("res://practice/practice_bottle.tscn")
const SLOT_SCENE := preload("res://practice/slot_machine.tscn")

var broken := 0
var slot_machine: SlotMachine

var _bottles: Array[PracticeBottle] = []

@onready var _model: Node3D = $Model
@onready var _scoreboard: Label3D = $Scoreboard


func _ready() -> void:
	super._ready()
	for spot in _model.find_children("BottleSpot*", "", true, false):
		var bottle: PracticeBottle = BOTTLE_SCENE.instantiate()
		add_child(bottle)
		bottle.set_home(Transform3D(Basis.IDENTITY, (spot as Node3D).global_position))
		bottle.shattered.connect(_on_bottle_shattered)
		_bottles.append(bottle)
	var slot_spot := _model.find_child("SlotSpot", true, false) as Node3D
	if slot_spot != null:
		slot_machine = SLOT_SCENE.instantiate()
		add_child(slot_machine)
		slot_machine.global_position = slot_spot.global_position
		# Front faces the porch centre.
		slot_machine.look_at(slot_machine.global_position + Vector3.RIGHT, Vector3.UP, true)
	_refresh()


func _exit_tree() -> void:
	# A fresh hub (VR menu reload) is already current and owns the readout.
	var replaced_by_hub := GameManager.in_practice() and GameManager.current_scenario != self
	if is_instance_valid(GameManager.hud) and not replaced_by_hub:
		GameManager.hud.set_practice_count(-1)


func bottles() -> Array[PracticeBottle]:
	return _bottles


## Every bottle back on its rail, including held, loose, and broken ones.
func reset_range() -> void:
	for bottle in _bottles:
		bottle.go_home()
	broken = 0
	_refresh()


## Closest grabbable bottle whose middle is within `radius` of `point`.
func nearest_bottle(point: Vector3, radius: float) -> PracticeBottle:
	var best: PracticeBottle = null
	var best_distance := radius
	for bottle in _bottles:
		if not bottle.is_grabbable():
			continue
		var distance := bottle.center().distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = bottle
	return best


## Flat pickup: nearest grabbable bottle within `radius` of the look ray and
## `reach` of the eye, unless world geometry is in the way.
func bottle_along_ray(origin: Vector3, direction: Vector3, reach: float, radius: float) -> PracticeBottle:
	var best: PracticeBottle = null
	var best_along := reach
	for bottle in _bottles:
		if not bottle.is_grabbable():
			continue
		var along := (bottle.center() - origin).dot(direction)
		if along < 0.0 or along > best_along:
			continue
		if bottle.center().distance_to(origin + direction * along) > radius:
			continue
		best_along = along
		best = bottle
	if best == null:
		return null
	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(origin, best.center(), PracticeBottle.LAYER_WORLD)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return null
	return best


func _on_bottle_shattered(_bottle: PracticeBottle) -> void:
	broken += 1
	_refresh()


func _refresh() -> void:
	if _scoreboard != null:
		_scoreboard.text = "BOTTLES %d" % broken
	if is_instance_valid(GameManager.hud):
		GameManager.hud.set_practice_count(broken)
	broken_changed.emit(broken)
