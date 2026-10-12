class_name LobbyRoster
extends RefCounted
## A lobby's setup: mode, arena, and 2-4 slots. Data only; NetworkManager owns the live copy.
## Slot index = ReplayBuffer actor id = shooter id. Slot 0 is always the host.

enum Mode { FFA, TEAMS }
enum Kind { OPEN, HUMAN, NPC }

const MIN_SLOTS := 2
const MAX_SLOTS := 4
## Most slots a lobby hosted on Android may hold. Lower it if the Quest frame-time gate fails.
const QUEST_MAX_SLOTS := 4
const SIDES := 2
const HOST_PEER := 1
const NAME_MAX := 24
## NPC slot that rolls its archetype at every duel start. Any other value is an index
## into `GameManager.ARCHETYPES`.
const ARCHETYPE_MIXED := -1
## Body tint per slot in free-for-all.
const SLOT_TINTS: Array[Color] = [
	Color(0.72, 0.26, 0.18),
	Color(0.22, 0.42, 0.66),
	Color(0.85, 0.66, 0.2),
	Color(0.3, 0.55, 0.3),
]
## Body tint per side in Teams.
const SIDE_TINTS: Array[Color] = [
	Color(0.72, 0.26, 0.18),
	Color(0.22, 0.42, 0.66),
]

var mode: int = Mode.FFA
var scenario_index := 0
## One per slot: { kind, peer_id, name, side, archetype, wins }.
var slots: Array[Dictionary] = []


func _init(host_name := "") -> void:
	reset(host_name)


## First-run setup: two slots, free-for-all, no NPCs, the host in slot 0.
func reset(host_name := "") -> void:
	mode = Mode.FFA
	scenario_index = 0
	slots = [_empty_slot(0), _empty_slot(1)]
	slots[0]["kind"] = Kind.HUMAN
	slots[0]["peer_id"] = HOST_PEER
	slots[0]["name"] = host_name


static func max_slots() -> int:
	return QUEST_MAX_SLOTS if OS.has_feature("android") else MAX_SLOTS


static func _empty_slot(index: int) -> Dictionary:
	return {
		"kind": Kind.OPEN,
		"peer_id": 0,
		"name": "",
		"side": index % SIDES,
		"archetype": ARCHETYPE_MIXED,
		"wins": 0,
	}


# -- Wire --------------------------------------------------------------------

func pack() -> Dictionary:
	var rows: Array = []
	for slot in slots:
		rows.append([slot["kind"], slot["peer_id"], slot["name"], slot["side"],
				slot["archetype"], slot["wins"]])
	return {"mode": mode, "scenario": scenario_index, "slots": rows}


## Replaces this roster with a `pack()` result. False, and nothing changes, if it is malformed.
func unpack(data: Dictionary) -> bool:
	var rows: Variant = data.get("slots")
	if not (rows is Array) or rows.size() < MIN_SLOTS or rows.size() > MAX_SLOTS:
		return false
	var parsed: Array[Dictionary] = []
	for row: Variant in rows:
		if not (row is Array) or row.size() != 6:
			return false
		parsed.append({
			"kind": clampi(int(row[0]), Kind.OPEN, Kind.NPC),
			"peer_id": int(row[1]),
			"name": str(row[2]),
			"side": clampi(int(row[3]), 0, SIDES - 1),
			"archetype": maxi(int(row[4]), ARCHETYPE_MIXED),
			"wins": maxi(int(row[5]), 0),
		})
	mode = Mode.TEAMS if int(data.get("mode", Mode.FFA)) == Mode.TEAMS else Mode.FFA
	scenario_index = maxi(int(data.get("scenario", 0)), 0)
	slots = parsed
	return true


## The `open/total` field lobby lists show, e.g. "1/2".
static func format_slots(open: int, total: int) -> String:
	return "%d/%d" % [open, total]


## (open, total) from an `open/total` field. Zero when `text` is not one.
static func parse_slots(text: String) -> Vector2i:
	var parts := text.split("/")
	if parts.size() != 2:
		return Vector2i.ZERO
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


# -- Queries -----------------------------------------------------------------

func count_kind(kind: int) -> int:
	var count := 0
	for slot in slots:
		if slot["kind"] == kind:
			count += 1
	return count


## Slots no human has taken yet.
func open_human_slots() -> int:
	return count_kind(Kind.OPEN)


## Slots meant for humans, taken or not (every slot that is not an NPC).
func human_slots() -> int:
	return slots.size() - count_kind(Kind.NPC)


## -1 when the peer holds no slot.
func slot_of_peer(peer_id: int) -> int:
	for slot in slots.size():
		if slots[slot]["kind"] == Kind.HUMAN and slots[slot]["peer_id"] == peer_id:
			return slot
	return -1


## This peer's slot, or -1 before the host has assigned one.
func local_slot() -> int:
	return slot_of_peer(NetworkManager.multiplayer.get_unique_id())


## Free-for-all: every slot is its own side. Teams: 0 or 1.
func side_of(slot: int) -> int:
	return int(slots[slot]["side"]) if mode == Mode.TEAMS else slot


## The body colour `slot` wears in a lobby, the same on every peer: its side's in Teams,
## its own in free-for-all.
func tint_of(slot: int) -> Color:
	return SIDE_TINTS[side_of(slot)] if mode == Mode.TEAMS else SLOT_TINTS[slot]


## No slot is waiting for a human, and in Teams both sides have someone.
func can_start() -> bool:
	if open_human_slots() > 0:
		return false
	if mode != Mode.TEAMS:
		return true
	var filled := [false, false]
	for slot in slots:
		filled[slot["side"]] = true
	return filled[0] and filled[1]


## The slot for each spawn point, in ring order (`PlayerSpawn` first). Teams puts the
## smaller side first and a tie keeps side 0 first, so the solo of a 1v3 takes
## `PlayerSpawn` and teammates stand on neighbouring points. Free-for-all is slot order.
func spawn_order() -> Array[int]:
	var order: Array[int] = []
	if mode != Mode.TEAMS:
		for slot in slots.size():
			order.append(slot)
		return order
	var by_side: Array[Array] = [[], []]
	for slot in slots.size():
		by_side[slots[slot]["side"]].append(slot)
	var first := 1 if by_side[1].size() < by_side[0].size() else 0
	for side: int in [first, 1 - first]:
		for slot: int in by_side[side]:
			order.append(slot)
	return order


# -- Edits (host) --------------------------------------------------------------

## A joining peer takes the first OPEN slot. Returns it, or -1 when none is open.
func assign_peer(peer_id: int, player_name: String) -> int:
	for slot in slots.size():
		if slots[slot]["kind"] != Kind.OPEN:
			continue
		slots[slot]["kind"] = Kind.HUMAN
		slots[slot]["peer_id"] = peer_id
		slots[slot]["name"] = player_name
		slots[slot]["wins"] = 0
		return slot
	return -1


## Leaver rule. A human gone during a duel or the rematch loop leaves a Mixed NPC in the
## slot from the next duel; one gone in the waiting room reopens it. Returns the slot,
## or -1 if the peer held none.
func vacate_peer(peer_id: int, in_duel: bool) -> int:
	var slot := slot_of_peer(peer_id)
	if slot <= 0:
		return -1
	_clear_slot(slot, Kind.NPC if in_duel else Kind.OPEN)
	if in_duel:
		slots[slot]["archetype"] = ARCHETYPE_MIXED
	return slot


## Refused while a slot the new count would remove holds a human.
func set_slot_count(count: int) -> bool:
	if count < MIN_SLOTS or count > max_slots():
		return false
	for slot in range(count, slots.size()):
		if slots[slot]["kind"] == Kind.HUMAN:
			return false
	while slots.size() > count:
		slots.pop_back()
	while slots.size() < count:
		slots.append(_empty_slot(slots.size()))
	return true


## Host switches an empty slot between OPEN and NPC. A human's slot is refused
## (kick first), and so is slot 0.
func set_slot_kind(slot: int, kind: int) -> bool:
	if slot <= 0 or slot >= slots.size() or kind == Kind.HUMAN or kind < Kind.OPEN or kind > Kind.NPC:
		return false
	if slots[slot]["kind"] == Kind.HUMAN:
		return false
	_clear_slot(slot, kind)
	return true


## Empties a human's slot back to OPEN (kick). Slot 0 is refused.
func open_slot(slot: int) -> bool:
	if slot <= 0 or slot >= slots.size():
		return false
	_clear_slot(slot, Kind.OPEN)
	return true


func set_archetype(slot: int, archetype: int) -> bool:
	if slot < 0 or slot >= slots.size():
		return false
	slots[slot]["archetype"] = maxi(archetype, ARCHETYPE_MIXED)
	return true


func set_side(slot: int, side: int) -> bool:
	if slot < 0 or slot >= slots.size() or side < 0 or side >= SIDES:
		return false
	slots[slot]["side"] = side
	return true


## A new occupant starts its own win tally; the slot keeps its side and archetype.
func _clear_slot(slot: int, kind: int) -> void:
	slots[slot]["kind"] = kind
	slots[slot]["peer_id"] = 0
	slots[slot]["name"] = ""
	slots[slot]["wins"] = 0
