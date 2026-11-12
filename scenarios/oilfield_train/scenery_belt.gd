extends Node3D
## The oil field sliding past the stopped train. Each [constant ROWS] entry places one piece
## kind on a band (near, mid, far) with that band's speed and loop; a later batch adds a piece
## by adding a row. Copies move along z on wall-clock time, are never turned (the track's yaw
## is its kit fix), and lose their collision; nothing sways. One beam clock rocks every
## `WalkingBeam`. Local cosmetic, nothing on the wire. Design: docs/design/scenarios/oilfield_train.md B.

const TRACK_SCENE := preload("res://assets/models/scenarios/main_street/env_rail_track_8m.glb")
const PUMPJACK_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_pumpjack.glb")
const HORIZON_SCENE := preload("res://assets/models/scenarios/oilfield_train/oilfield_horizon.glb")
const WELL_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_burning_well.glb")
const DERRICK_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_derrick.glb")
const TANK_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_tank.glb")
const PYLON_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_pylon.glb")
const PIPE_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_pipe_run.glb")
const WELLHEAD_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_wellhead.glb")
const SUMP_SCENE := preload("res://assets/models/scenarios/oilfield_train/oil_sump.glb")

enum Band { NEAR, MID, FAR }

## The mid and far slot pitch (Train Rooftop's `HORIZON_SPAN`).
const SLOT := 48.0
const SLOTS_PER_SIDE := 16
const TRACK_LEN := 8.0
## Every loop wraps 360 m or more out, at about 88% fog under density 0.006 (the wrap grow, `GROW_M`, hides the pop).
const LOOPS := {
	Band.NEAR: 90 * TRACK_LEN,
	Band.MID: SLOT * SLOTS_PER_SIDE,
	Band.FAR: SLOT * SLOTS_PER_SIDE,
}
const LEFT := -1.0
const RIGHT := 1.0

## One row per piece kind. Keys:
## - `scene`: the GLB. `band`: a [enum Band].
## - `count`: copies spread evenly over the loop (pitch = loop / count), placed by `sides`:
##   &"centre" (x 0), &"alternate" (left first), &"left", &"right", or &"both" (one each side
##   per step). Or `slots` instead: {LEFT: [...], RIGHT: [...]}, 48 m slot indices (0 to 15).
## - `x`: Vector2(min, max) distance from the track's axis, rolled per copy (min == max is
##   fixed, as the pylon line's 22 m will be). `seed`: that roll's seed. `x_left`: the same for the
##   left side only, when it must stay clear of the pylon line at -22 (B, The belt).
## - Optional `phase` (the first copy's offset along its pitch, 0 to 1, default 0.5) and `yaw`.
## - Optional `grow`: false exempts a row from the wrap grow (`GROW_M`): only the tracks, which lie flat
##   at about 88% fog, take it.
## - Optional `lit`: {LEFT: n, RIGHT: n}: every nth slot of that side burns one anchor of its tile,
##   cycling `Flame_1` to `Flame_3` (F9): a flame column on that anchor (a smouldering mound only
##   glows). Left slots 0, 2, 4, ...; right slots 1, 5, 9, 13 (`LIT_PHASE`).
## - A piece with a `Flame_Near` anchor (the burning well) always burns it and drives the lane
##   glow's swell (`_update_swell`).
## - Optional `homes`: {LEFT: [...], RIGHT: [...]}, the copies' z in metres (a near row's loop is 720 m), in
##   place of `count`.
## The flame cue is `_light_flames` below.
## Mid slots (16 a side): the left's 0 and 8 hold the burning wells, 2, 5, 7, 10, 13, 15 pumpjacks and
## 1, 3, 4, 6, 9, 11, 12, 14 the derricks and tanks; the right's 1, 3, 6, 9, 11, 14 hold pumpjacks and
## 0, 2, 4, 5, 7, 8, 10, 12, 13, 15 the rest. One piece a slot: footprints stay apart.

## Near wellhead and sump homes (z, m). A wellhead's footprint is 4.0 m along z, a sump's 10.3 m (its spill
## tongue reaches 6.6 m toward +z), a pipe run's 15.9 m, a pumpjack's 1.5 m. Each home keeps 3 m from every
## other near footprint on its side, the tongue and the pad included, whatever x it rolls.
const WELLHEAD_HOMES_LEFT: Array[float] = [-298.0, -204.0, -118.0, -22.5, 62.0, 156.0, 242.0, 337.5]
const WELLHEAD_HOMES_RIGHT: Array[float] = [-242.0, -156.0, -62.0, 22.5, 118.0, 204.0, 298.0, -337.5]
const SUMP_HOMES_LEFT: Array[float] = [-330.5, -247.5, -150.5, -67.5, 29.5, 112.5, 209.5, 292.5]
const SUMP_HOMES_RIGHT: Array[float] = [-292.5, -213.0, -112.5, -33.0, 67.5, 147.0, 247.5, 327.0]

const ROWS: Array[Dictionary] = [
	# The kit track runs along X: yaw it so the rails follow the cars (z).
	{"scene": TRACK_SCENE, "band": Band.NEAR, "count": 90, "sides": &"centre", "yaw": PI * 0.5, "grow": false},
	# 10 a side, one per 72 m a side.
	{"scene": PUMPJACK_SCENE, "band": Band.NEAR, "count": 20, "sides": &"alternate",
			"x": Vector2(10.0, 15.0), "seed": 1925},
	{"scene": PUMPJACK_SCENE, "band": Band.MID, "x": Vector2(28.0, 40.0), "seed": 1926,
			"slots": {LEFT: [2, 5, 7, 10, 13, 15], RIGHT: [1, 3, 6, 9, 11, 14]}},
	# 16 slots x 2 sides = 32 tiles at the slot pitch (48 m). Unlit mounds still glow (F13).
	{"scene": HORIZON_SCENE, "band": Band.FAR, "count": 16, "sides": &"both",
			"x": Vector2(85.0, 110.0), "seed": 1884, "lit": {LEFT: 2, RIGHT: 4}},
	# 10 derricks and 8 tanks in the mid slots the pumpjacks and wells leave free. The left stays at x 28 or
	# beyond (the pylon line stands at 22); a left derrick's feet reach 3 m in from its origin, a left tank's
	# 5 m, so those rows start at 30 and 32.
	{"scene": DERRICK_SCENE, "band": Band.MID, "x": Vector2(26.0, 45.0), "x_left": Vector2(30.0, 45.0),
			"seed": 1888, "slots": {LEFT: [3, 6, 11, 14], RIGHT: [0, 4, 7, 10, 13, 15]}},
	{"scene": TANK_SCENE, "band": Band.MID, "x": Vector2(30.0, 45.0), "x_left": Vector2(32.0, 45.0),
			"seed": 1889, "slots": {LEFT: [1, 4, 9, 12], RIGHT: [2, 5, 8, 12]}},
	# Two burning wells, 384 m apart on the left: the anchor stands 42 to 45 m out (F10).
	{"scene": WELL_SCENE, "band": Band.MID, "x": Vector2(42.0, 45.0), "seed": 1887, "slots": {LEFT: [0, 8]}},
	# The pylon line: 8 towers at x -22 exactly, never rolled, on a 96 m pitch (768 / 8) so each tower's wires
	# end on the next one's arm tips; the 768 m mid loop closes on it.
	{"scene": PYLON_SCENE, "band": Band.MID, "count": 8, "sides": &"left", "x": Vector2(22.0, 22.0), "seed": 1890},
	# 24 pipe runs, 12 a side (one per 60 m a side), 16 m long: nothing on the near belt inside x 6 stands over 1.5 m.
	{"scene": PIPE_SCENE, "band": Band.NEAR, "count": 24, "sides": &"alternate", "x": Vector2(3.6, 5.0),
			"seed": 1891},
	# 8 wellheads and 8 sumps a side at fixed z homes (`NEAR_HOMES` below): even pitches could not keep every
	# footprint 3 m from the pipe runs, the pumpjacks, and each other, so each home was placed against them.
	{"scene": WELLHEAD_SCENE, "band": Band.NEAR, "x": Vector2(6.0, 12.0), "seed": 1892,
			"homes": {LEFT: WELLHEAD_HOMES_LEFT, RIGHT: WELLHEAD_HOMES_RIGHT}},
	{"scene": SUMP_SCENE, "band": Band.NEAR, "x": Vector2(7.0, 16.0), "seed": 1893,
			"homes": {LEFT: SUMP_HOMES_LEFT, RIGHT: SUMP_HOMES_RIGHT}},
]

## Flame column size by anchor name: (base across, height) in metres (sheet B, F14). `Flame_Near` is
## the burning well's: always lit.
const FLAME_SIZES := {
	&"Flame_1": Vector2(18.0, 60.0),
	&"Flame_2": Vector2(11.2, 35.0),
	&"Flame_3": Vector2(6.2, 15.0),
	&"Flame_Near": Vector2(11.2, 35.0),
}
const FLAME_CYCLE: Array[StringName] = [&"Flame_1", &"Flame_2", &"Flame_3"]
const WELL_ANCHOR := &"Flame_Near"
## The first lit slot of each side, so the two sides do not burn in step.
const LIT_PHASE := {LEFT: 0, RIGHT: 1}

## The walking beam's nod (F17, F18): ±12° about its local z (positive raises the head), a
## sine with a 10 s period, in three phase groups by copy index so neighbours never nod in step.
const BEAM_NAME := "WalkingBeam"
const BEAM_SWING_DEG := 12.0
const BEAM_PERIOD := 10.0
const BEAM_GROUPS := 3

## The wrap grow: a piece's scale ramps from 0 at the wrap to 1 over its first `GROW_M` metres, and back to 0 over
## its last, uniformly about its origin (the base stays on the ground; the pumpjack's beam and the flame anchors
## are children and go with it). A rig at the wrap is a faint dark silhouette against the band at about 88% fog, so
## it must grow in and out, not pop. The ramp is a smoothstep, floored at `GROW_MIN` (a zero scale is singular).
const GROW_M := 40.0
const GROW_MIN := 0.001
enum Grow { OFF, FULL, RAMP }

@export var speed_mps := 20.0
@export var mid_speed_scale := 0.35
@export var far_speed_scale := 0.12

var _nodes: Array[Node3D] = []
var _home_z := PackedFloat32Array()
var _loops := PackedFloat32Array()
var _scales := PackedFloat32Array()
var _grow := PackedByteArray()
var _beams: Array[Node3D] = []
var _beam_phase := PackedFloat32Array()
var _wells: Array[Node3D] = []
var _glow: LaneGlow


func _ready() -> void:
	_glow = get_parent().get_node_or_null("LaneGlow") as LaneGlow
	for row in ROWS:
		_spawn_row(row)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var near := now * speed_mps
	for i in _nodes.size():
		var loop: float = _loops[i]
		var z := wrapf(_home_z[i] + near * _scales[i], -loop * 0.5, loop * 0.5)
		var node := _nodes[i]
		node.position.z = z
		var state: int = _grow[i]
		if state == Grow.OFF:
			continue
		var edge := loop * 0.5 - absf(z)
		if edge < GROW_M:
			node.scale = Vector3.ONE * grow_at(edge)
			_grow[i] = Grow.RAMP
		elif state == Grow.RAMP:
			node.scale = Vector3.ONE
			_grow[i] = Grow.FULL
	set_beams(TAU * now / BEAM_PERIOD)
	update_swell()


## The scale of a piece `edge` metres inside the wrap (`loop / 2 - |z|`): 0 (floored) at the wrap, 1 from `GROW_M`.
static func grow_at(edge: float) -> float:
	return maxf(smoothstep(0.0, GROW_M, edge), GROW_MIN)


## Every beam at its group's angle for `stroke` radians into the 10 s cycle.
func set_beams(stroke: float) -> void:
	var swing := deg_to_rad(BEAM_SWING_DEG)
	for i in _beams.size():
		_beams[i].rotation.z = swing * sin(stroke + _beam_phase[i])


## Writes the lane glow's swell from the nearer burning well: one write a frame (F10). A well's
## anchor stands at its piece's z, so the offset from the light is read off the anchor itself.
func update_swell() -> void:
	if _wells.is_empty() or _glow == null:
		return
	var nearest := INF
	for well in _wells:
		nearest = minf(nearest, absf(well.global_position.z - _glow.global_position.z))
	_glow.swell = LaneGlow.swell_at(nearest)


func _spawn_row(row: Dictionary) -> void:
	var band: Band = row["band"]
	var loop: float = LOOPS[band]
	var speed_scale := _band_scale(band)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(row.get("seed", 0))
	var span: Vector2 = row.get("x", Vector2.ZERO)
	if row.has("homes"):
		var homes: Dictionary = row["homes"]
		for side: float in [LEFT, RIGHT]:
			for home: float in homes.get(side, []):
				_place(row, side * rng.randf_range(span.x, span.y), home, loop, speed_scale)
		return
	if row.has("slots"):
		var slots: Dictionary = row["slots"]
		for side: float in [LEFT, RIGHT]:
			var side_span: Vector2 = row.get("x_left", span) if side == LEFT else span
			for slot: int in slots.get(side, []):
				var home := -loop * 0.5 + (float(slot) + 0.5) * SLOT
				_place(row, side * rng.randf_range(side_span.x, side_span.y), home, loop, speed_scale, slot)
		return
	var count: int = row["count"]
	var pitch := loop / float(count)
	var phase: float = row.get("phase", 0.5)
	var sides: StringName = row.get("sides", &"centre")
	for i in count:
		var home := -loop * 0.5 + (float(i) + phase) * pitch
		match sides:
			&"centre":
				_place(row, 0.0, home, loop, speed_scale)
			&"alternate":
				var side := LEFT if i % 2 == 0 else RIGHT
				_place(row, side * rng.randf_range(span.x, span.y), home, loop, speed_scale)
			&"left", &"right":
				var side := LEFT if sides == &"left" else RIGHT
				_place(row, side * rng.randf_range(span.x, span.y), home, loop, speed_scale)
			&"both":
				for side: float in [LEFT, RIGHT]:
					_place(row, side * rng.randf_range(span.x, span.y), home, loop, speed_scale, i)


func _place(row: Dictionary, x: float, home_z: float, loop: float, speed_scale: float,
		slot: int = -1) -> void:
	var piece := (row["scene"] as PackedScene).instantiate() as Node3D
	piece.rotation.y = float(row.get("yaw", 0.0))
	piece.position.x = x
	add_child(piece)
	_strip_collision(piece)
	if row.has("lit"):
		_light_flames(piece, _lit_anchor(row["lit"], signf(x), slot))
	var well := piece.find_child(WELL_ANCHOR, true, false) as Node3D
	if well != null:
		_add_column(well)
		_wells.append(well)
	piece.position.z = home_z
	_nodes.append(piece)
	_home_z.append(home_z)
	_loops.append(loop)
	_scales.append(speed_scale)
	_grow.append(Grow.FULL if row.get("grow", true) else Grow.OFF)
	var beam := piece.find_child(BEAM_NAME, true, false) as Node3D
	if beam != null:
		_beam_phase.append(TAU * float(_beams.size() % BEAM_GROUPS) / float(BEAM_GROUPS))
		_beams.append(beam)


## The anchor a tile in `slot` of `side` burns, or &"" when the slot is unlit (F9): every nth slot
## from the side's `LIT_PHASE`, cycling `Flame_1` to `Flame_3`.
func _lit_anchor(lit: Dictionary, side: float, slot: int) -> StringName:
	var every: int = lit.get(side, 0)
	var start: int = LIT_PHASE[side]
	if every <= 0 or slot < 0 or posmod(slot - start, every) != 0:
		return &""
	return FLAME_CYCLE[((slot - start) / every + start) % FLAME_CYCLE.size()]


## Burns `lit_name` on a horizon tile: a flame column on that anchor.
func _light_flames(piece: Node3D, lit_name: StringName) -> void:
	var anchor := piece.find_child(String(lit_name), true, false) as Node3D if lit_name != &"" else null
	if anchor != null:
		_add_column(anchor)


func _add_column(anchor: Node3D) -> void:
	var size: Vector2 = FLAME_SIZES[anchor.name]
	var cue := VfxCatalog.spawn(&"flame_column", anchor, anchor.global_position) as FlameColumn
	if cue != null:
		cue.configure(size.x, size.y)


func _band_scale(band: Band) -> float:
	match band:
		Band.MID:
			return mid_speed_scale
		Band.FAR:
			return far_speed_scale
	return 1.0


func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_strip_collision(child)
