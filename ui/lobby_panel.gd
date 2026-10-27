class_name LobbyPanel
extends VBoxContainer
## The lobby roster as a form, one control for two uses. SETUP (main menu, Multiplayer
## page) edits the saved host setup and needs no session. LIVE (pause overlay, Lobby page)
## shows `NetworkManager.roster`: the host's pickers call the host API, and every human
## gets a button for its own side. Rows are rebuilt on every change.

enum Use { SETUP, LIVE }

## START went through: the pause overlay can close.
signal started

const SIDE_NAMES: Array[String] = ["LOBBY_SIDE_RED", "LOBBY_SIDE_BLUE"]
const CHIP_SIZE := Vector2(18, 18)
const KIND_ORDER: Array[int] = [LobbyRoster.Kind.OPEN, LobbyRoster.Kind.NPC]
const NAME_WIDTH := 150.0

@export var use: Use = Use.SETUP

## One entry per slot row: { slot, chip, name, kind, side, wins, kick, kind_option,
## archetype_option, side_option }. Controls a row lacks are null.
var rows: Array[Dictionary] = []

var _setup := LobbyRoster.new()
var _stale := true
var _archetype_names: Array[String] = []

@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton
@onready var back_to_lobby_button: Button = %BackToLobbyButton
@onready var my_side_button: Button = %MySideButton
@onready var slot_count_option: OptionButton = %SlotCountOption
@onready var mode_option: OptionButton = %ModeOption
@onready var arena_option: OptionButton = %ArenaOption
@onready var slot_rows: VBoxContainer = %SlotRows
@onready var team_wins_label: Label = %TeamWinsLabel


func _ready() -> void:
	for path in GameManager.ARCHETYPES:
		_archetype_names.append((load(path) as AIArchetype).display_name)
	for count in range(LobbyRoster.MIN_SLOTS, LobbyRoster.max_slots() + 1):
		slot_count_option.add_item(str(count))
	mode_option.add_item(tr("LOBBY_MODE_FFA"))
	mode_option.add_item(tr("LOBBY_MODE_TEAMS"))
	for path in GameManager.SCENARIOS:
		arena_option.add_item((load(path) as ScenarioResource).display_name)
	slot_count_option.item_selected.connect(_on_slot_count_selected)
	mode_option.item_selected.connect(_on_mode_selected)
	arena_option.item_selected.connect(_on_arena_selected)
	start_button.pressed.connect(_on_start)
	back_to_lobby_button.pressed.connect(_on_back_to_lobby)
	my_side_button.pressed.connect(_on_my_side)
	visibility_changed.connect(_on_visibility_changed)
	if use == Use.LIVE:
		NetworkManager.roster_changed.connect(_on_roster_changed)
		GameManager.duel.state_changed.connect(_on_duel_state_changed)
	_on_visibility_changed()


## The Mixed NPC archetype as the single-player picker numbers it: one past the last
## archetype. The roster uses `LobbyRoster.ARCHETYPE_MIXED`.
static func archetype_to_index(archetype: int) -> int:
	return GameManager.ARCHETYPES.size() if archetype == LobbyRoster.ARCHETYPE_MIXED else archetype


static func index_to_archetype(index: int) -> int:
	return LobbyRoster.ARCHETYPE_MIXED if index >= GameManager.ARCHETYPES.size() else index


## Wins shown for one side of a Teams lobby. Wins are kept per slot (a Teams win adds one
## to every slot on the winning side), so the side's figure is its best tally: a newcomer's
## own count restarts, and a slot that switched sides keeps what it had.
static func side_wins(roster: LobbyRoster, side: int) -> int:
	var best := 0
	for slot in roster.slots:
		if int(slot["side"]) == side:
			best = maxi(best, int(slot["wins"]))
	return best


## Host: puts the saved setup on the live roster through the host API. Right after
## `host_lan()`, or once a Steam lobby is ready.
static func apply_saved_setup() -> bool:
	var want := LobbyRoster.new()
	PlayerSettings.fill_lobby_setup(want)
	var net := NetworkManager
	var ok := net.host_set_slot_count(want.slots.size())
	ok = net.host_set_mode(want.mode) and ok
	for slot in range(1, want.slots.size()):
		if want.slots[slot]["kind"] != LobbyRoster.Kind.NPC:
			continue
		ok = net.host_set_slot_kind(slot, LobbyRoster.Kind.NPC) and ok
		ok = net.host_set_archetype(slot, want.slots[slot]["archetype"]) and ok
		ok = net.host_set_npc_side(slot, want.slots[slot]["side"]) and ok
	if want.scenario_index != net.roster.scenario_index:
		ok = net.host_set_scenario(want.scenario_index) and ok
	return ok


## Rebuilds from the roster (LIVE) or the saved setup (SETUP) now.
func refresh() -> void:
	if use == Use.SETUP:
		PlayerSettings.fill_lobby_setup(_setup)
	_stale = false
	_rebuild()


func _roster() -> LobbyRoster:
	return NetworkManager.roster if use == Use.LIVE else _setup


## SETUP always edits. LIVE edits only as the host of a session.
func _can_edit() -> bool:
	return use == Use.SETUP or (NetworkManager.is_active() and NetworkManager.is_host())


func _duel_running() -> bool:
	return GameManager.duel.state != DuelManager.State.IDLE


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and (_stale or use == Use.SETUP):
		refresh()


func _on_roster_changed() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		_stale = true


func _on_duel_state_changed(_state: int) -> void:
	_on_roster_changed()


# -- Build -----------------------------------------------------------------------

func _rebuild() -> void:
	var roster := _roster()
	var live := use == Use.LIVE
	var editable := _can_edit()
	var host := editable and live
	var waiting := live and GameManager.in_mp_lobby()
	var teams := roster.mode == LobbyRoster.Mode.TEAMS
	var local := roster.local_slot() if live else -1

	slot_count_option.select(roster.slots.size() - LobbyRoster.MIN_SLOTS)
	slot_count_option.disabled = not editable
	for index in slot_count_option.item_count:
		# A count that would drop a slot a human holds is refused: show it that way.
		var count := index + LobbyRoster.MIN_SLOTS
		var holds_human := false
		for slot in range(count, roster.slots.size()):
			holds_human = holds_human or roster.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN
		slot_count_option.set_item_disabled(index, holds_human)
	mode_option.select(roster.mode)
	mode_option.disabled = not editable
	arena_option.select(clampi(roster.scenario_index, 0, arena_option.item_count - 1))
	arena_option.disabled = not editable

	start_button.visible = host and waiting
	back_to_lobby_button.visible = host and not waiting
	var refusal := NetworkManager.start_refusal() if host and waiting else ""
	start_button.disabled = not refusal.is_empty()
	var status := ""
	if live and waiting and not NetworkManager.is_host():
		status = tr("MSG_LOBBY_WAIT_HOST")
	elif not refusal.is_empty():
		status = tr(refusal)
	status_label.text = status
	status_label.visible = not status.is_empty()

	my_side_button.visible = live and teams and local >= 0
	if my_side_button.visible:
		my_side_button.text = tr("LOBBY_MY_SIDE") % tr(SIDE_NAMES[int(roster.slots[local]["side"])])
	team_wins_label.visible = live and teams
	if team_wins_label.visible:
		team_wins_label.text = tr("LOBBY_TEAM_WINS") % [side_wins(roster, 0), side_wins(roster, 1)]

	for row in rows:
		slot_rows.remove_child(row["box"])
		(row["box"] as Node).queue_free()
	rows.clear()
	for slot in range(0 if live else 1, roster.slots.size()):
		_build_row(roster, slot, host, local)


func _build_row(roster: LobbyRoster, slot: int, host: bool, local: int) -> void:
	var live := use == Use.LIVE
	var kind: int = roster.slots[slot]["kind"]
	var teams := roster.mode == LobbyRoster.Mode.TEAMS
	var row := {"slot": slot, "chip": null, "name": null, "kind": null, "side": null, "wins": null,
			"kick": null, "kind_option": null, "archetype_option": null, "side_option": null}
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	row["box"] = box
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	box.add_child(line)
	if live:
		var chip := ColorRect.new()
		chip.custom_minimum_size = CHIP_SIZE
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.color = roster.tint_of(slot)
		line.add_child(chip)
		row["chip"] = chip
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text = _slot_name(roster, slot, local)
	line.add_child(name_label)
	row["name"] = name_label
	if live:
		var kind_label := Label.new()
		kind_label.text = tr("LOBBY_KIND_NPC") if kind == LobbyRoster.Kind.NPC else tr("LOBBY_KIND_HUMAN")
		line.add_child(kind_label)
		row["kind"] = kind_label
		if teams:
			var side_label := Label.new()
			side_label.text = tr(SIDE_NAMES[int(roster.slots[slot]["side"])])
			line.add_child(side_label)
			row["side"] = side_label
		if kind != LobbyRoster.Kind.OPEN:
			var wins_label := Label.new()
			wins_label.text = tr("LOBBY_WINS") % int(roster.slots[slot]["wins"])
			line.add_child(wins_label)
			row["wins"] = wins_label
		if host and kind == LobbyRoster.Kind.HUMAN and slot > 0:
			var kick := Button.new()
			kick.text = tr("LOBBY_KICK")
			# Between duels only: the host refuses it from the title cards to the draw.
			kick.disabled = GameManager.duel.state in [DuelManager.State.INTRO, DuelManager.State.STANDOFF,
					DuelManager.State.WAIT_SIGNAL, DuelManager.State.DRAW]
			kick.pressed.connect(_on_kick.bind(slot))
			line.add_child(kick)
			row["kick"] = kick
	if slot > 0 and kind != LobbyRoster.Kind.HUMAN and (host or not live):
		_build_pickers(box, row, roster, slot)
	slot_rows.add_child(box)
	rows.append(row)


## The host's controls for a slot no human holds: its kind, and for an NPC its archetype
## and, in Teams, its side.
func _build_pickers(box: VBoxContainer, row: Dictionary, roster: LobbyRoster, slot: int) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	box.add_child(line)
	var kind_option := OptionButton.new()
	kind_option.add_item(tr("LOBBY_KIND_HUMAN"))
	kind_option.add_item(tr("LOBBY_KIND_NPC"))
	kind_option.select(KIND_ORDER.find(roster.slots[slot]["kind"]))
	kind_option.item_selected.connect(_on_kind_selected.bind(slot))
	line.add_child(kind_option)
	row["kind_option"] = kind_option
	if roster.slots[slot]["kind"] != LobbyRoster.Kind.NPC:
		return
	var archetype_option := OptionButton.new()
	archetype_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for archetype_name in _archetype_names:
		archetype_option.add_item(archetype_name)
	archetype_option.add_item(tr("MENU_ENEMY_MIXED"))
	archetype_option.select(archetype_to_index(roster.slots[slot]["archetype"]))
	archetype_option.item_selected.connect(_on_archetype_selected.bind(slot))
	line.add_child(archetype_option)
	row["archetype_option"] = archetype_option
	if roster.mode == LobbyRoster.Mode.TEAMS:
		var side_option := OptionButton.new()
		for side_name in SIDE_NAMES:
			side_option.add_item(tr(side_name))
		side_option.select(int(roster.slots[slot]["side"]))
		side_option.item_selected.connect(_on_npc_side_selected.bind(slot))
		line.add_child(side_option)
		row["side_option"] = side_option


## What a slot is called: its human's name, the NPC's archetype or Mixed, or "(open)".
func _slot_name(roster: LobbyRoster, slot: int, local: int) -> String:
	if use == Use.SETUP:
		return tr("LOBBY_SLOT_N") % (slot + 1)
	match int(roster.slots[slot]["kind"]):
		LobbyRoster.Kind.NPC:
			var archetype: int = roster.slots[slot]["archetype"]
			return tr("MENU_ENEMY_MIXED") if archetype == LobbyRoster.ARCHETYPE_MIXED \
					else _archetype_names[mini(archetype, _archetype_names.size() - 1)]
		LobbyRoster.Kind.HUMAN:
			var player_name := str(roster.slots[slot]["name"])
			return tr("LOBBY_YOU") % player_name if slot == local else player_name
	return tr("LOBBY_OPEN")


# -- Edits -------------------------------------------------------------------------

func _on_slot_count_selected(index: int) -> void:
	var count := index + LobbyRoster.MIN_SLOTS
	_edited(NetworkManager.host_set_slot_count(count) if use == Use.LIVE else _setup.set_slot_count(count))


func _on_mode_selected(index: int) -> void:
	if use == Use.LIVE:
		_edited(NetworkManager.host_set_mode(index))
	else:
		_setup.mode = index
		_edited(true)


func _on_arena_selected(index: int) -> void:
	if use == Use.LIVE:
		_edited(NetworkManager.host_set_scenario(index))
	else:
		_setup.scenario_index = index
		_edited(true)


func _on_kind_selected(index: int, slot: int) -> void:
	var kind: int = KIND_ORDER[index]
	_edited(NetworkManager.host_set_slot_kind(slot, kind) if use == Use.LIVE else _setup.set_slot_kind(slot, kind))


func _on_archetype_selected(index: int, slot: int) -> void:
	var archetype := index_to_archetype(index)
	_edited(NetworkManager.host_set_archetype(slot, archetype) if use == Use.LIVE \
			else _setup.set_archetype(slot, archetype))


func _on_npc_side_selected(side: int, slot: int) -> void:
	_edited(NetworkManager.host_set_npc_side(slot, side) if use == Use.LIVE else _setup.set_side(slot, side))


func _on_kick(slot: int) -> void:
	var kicked := str(NetworkManager.roster.slots[slot]["name"])
	if NetworkManager.host_kick(slot):
		GameManager.show_message(tr("MSG_LOBBY_KICKED") % kicked, 3.0)
	refresh()


func _on_my_side() -> void:
	var local := NetworkManager.roster.local_slot()
	if local >= 0:
		NetworkManager.request_side(1 - int(NetworkManager.roster.slots[local]["side"]))


func _on_start() -> void:
	if NetworkManager.host_start():
		started.emit()
	else:
		refresh()


func _on_back_to_lobby() -> void:
	NetworkManager.host_back_to_lobby()
	refresh()


## An edit was applied or refused. Applied: remember the setup for the next host. Either
## way the pickers fall back to what the roster says.
func _edited(applied: bool) -> void:
	if applied:
		PlayerSettings.set_lobby_setup(_roster())
	refresh()
