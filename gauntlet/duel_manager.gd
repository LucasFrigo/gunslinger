class_name DuelManager
extends Node
## Duel state machine: [Intro] -> Standoff -> WaitSignal -> Draw -> Resolution -> Reset.
## Intro plays the title cards (`DuelIntro`) on a new matchup; fire skips it.
## Lives as a child of the GameManager autoload so its node path is stable on
## every peer, which lets it own the multiplayer duel RPCs directly.
## Works both vs AI (single-player, host runs everything) and in a lobby (2-4
## slots of humans and NPCs, host authoritative, state broadcast to the clients;
## the host runs the NPC slots).

signal state_changed(state: int)
signal duel_finished(local_player_won: bool, reason: String)
## Kill-cam hook: world-space points of the winning bullet's trajectory.
signal kill_cam_requested(trail_points: PackedVector3Array)

enum State { IDLE, INTRO, STANDOFF, WAIT_SIGNAL, DRAW, RESOLUTION }
## Why a slot dropped out of an MP duel before it ended (`_mp_down`).
enum Cause { KILLED, FOUL, LEFT }

const SIGNAL_DELAY_MIN := 1.5
const SIGNAL_DELAY_MAX := 5.0
## Fouls by one slot in one duel that put it out when 3-4 duel. Each one before that
## voids the standoff.
const FOULS_OUT := 2
## Seconds the standoff line stays up when it carries lines the title cards held back.
const HELD_MESSAGE_SECONDS := 3.0

var state: int = State.IDLE
var is_mp := false
## Title cards before the standoff (INTRO).
var intro: DuelIntro
## Autotest: the older suites run with no intro. Never saved.
var skip_intros := false
## MP: the roster this duel runs on, taken at its start (`_mp_begin`). Slot index =
## ReplayBuffer actor id = shooter id. Null outside an MP duel. Edits to the live roster
## apply from the next duel.
var snapshot: LobbyRoster

var _timer := 0.0
var _wait_duration := 0.0
var _ais: Array[DuelistAI] = []
var _lineup_text := ""
## INTRO: the card on screen and how many there are. The host (or single player) runs the
## clock, whether or not this peer still watches (`on_intro_paused`).
var _intro_card := 0
var _intro_cards := 0
## Client: this intro's skip has gone to the host.
var _intro_skip_sent := false
## A loss with two or more NPCs left: they fight on after the replay.
var _survivors_fight := false
var _bell_player: AudioStreamPlayer
var _end_player: AudioStreamPlayer
## MP, one entry per snapshot slot. HP, holster state, and foul counts are the host's;
## every peer keeps `_alive`.
var _health: Array[float] = []
var _alive: Array[bool] = []
var _fouls: Array[int] = []
var _holstered: Array[bool] = []
## Client: this wait's foul has gone to the host.
var _foul_reported := false
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
	intro = DuelIntro.new()
	intro.name = "DuelIntro"
	add_child(intro)


# -- Public API ---------------------------------------------------------------

## `play_intro` shows the title cards first: each NPC in lineup order, then the player.
func start_ai_duel(ais: Array[DuelistAI], lineup_text := "", replay_win := true, play_intro := false) -> void:
	stop()
	is_mp = false
	_ais = ais.duplicate()
	_lineup_text = lineup_text
	_replay_win = replay_win
	for ai in _ais:
		ai.died.connect(_on_enemy_died.bind(ai))
	_bind_player()
	_enter(State.INTRO if play_intro and is_instance_valid(GameManager.local_player) else State.STANDOFF)


## This machine's Settings allow the title cards. In multiplayer only the host's counts.
func intro_enabled() -> bool:
	return PlayerSettings.duel_intro_enabled and not skip_intros


## Host: a start from the waiting room always plays the intro. A rematch or a restart skips
## it when every slot keeps its occupant (the same peer, or the same NPC archetype after the
## Mixed roll) on the same arena.
func host_start_mp_duel(scenario_index: int) -> void:
	var previous := snapshot if state != State.IDLE else null
	var previous_arena := GameManager.current_scenario_index
	stop()
	var rolled := _roll_snapshot()
	var play_intro := intro_enabled() and not (previous_arena == scenario_index
			and _same_occupants(previous, rolled))
	_mp_begin.rpc(scenario_index, GameManager.roll_time_of_day(scenario_index), rolled, play_intro)


## `previous` held the same duelists, slot for slot, as the packed roster `rolled`.
static func _same_occupants(previous: LobbyRoster, rolled: Dictionary) -> bool:
	if previous == null:
		return false
	var next := LobbyRoster.new()
	if not next.unpack(rolled) or next.slots.size() != previous.slots.size():
		return false
	for slot in next.slots.size():
		var was := previous.slots[slot]
		var now := next.slots[slot]
		if was["kind"] != now["kind"]:
			return false
		if now["kind"] == LobbyRoster.Kind.HUMAN and was["peer_id"] != now["peer_id"]:
			return false
		if now["kind"] == LobbyRoster.Kind.NPC and was["archetype"] != now["archetype"]:
			return false
	return true


## Host: the live roster packed for this duel, with every NPC slot settled so each peer
## builds the same one: a Mixed slot rolls its archetype, and the slot takes the
## archetype's name. The live roster keeps Mixed, to roll again next duel.
func _roll_snapshot() -> Dictionary:
	var rolled := LobbyRoster.new()
	rolled.unpack(NetworkManager.roster.pack())
	for slot in rolled.slots:
		if slot["kind"] != LobbyRoster.Kind.NPC:
			continue
		var archetype: int = slot["archetype"]
		if archetype < 0 or archetype >= GameManager.ARCHETYPES.size():
			archetype = randi() % GameManager.ARCHETYPES.size()
		slot["archetype"] = archetype
		slot["name"] = GameManager.archetype_at(archetype).display_name
	return rolled.pack()


## Host: put `peer_id` in the waiting room on the arena the host stands in. 0 moves
## everyone, this peer included, to the roster's arena under a fresh sky.
func host_open_lobby(peer_id := 0) -> void:
	if peer_id == 0:
		var arena := NetworkManager.roster.scenario_index
		_mp_lobby.rpc(arena, GameManager.roll_time_of_day(arena))
	else:
		_mp_lobby.rpc_id(peer_id, GameManager.current_scenario_index,
				GameManager.current_scenario.time_of_day)


func stop() -> void:
	state = State.IDLE
	intro.finish()
	_ais = []
	_survivors_fight = false
	_replay_win = true
	ReplayBuffer.abort()
	# Before the snapshot goes: the death cam releases one actor per slot.
	DeathCam.stop()
	snapshot = null


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


## MP: `slot` is still in the duel (not killed, fouled out, or gone).
func slot_alive(slot: int) -> bool:
	return slot >= 0 and slot < _alive.size() and _alive[slot]


## MP: the slots still in the duel.
func live_slots() -> Array[int]:
	var live: Array[int] = []
	for slot in _alive.size():
		if _alive[slot]:
			live.append(slot)
	return live


## MP: the name messages use for `slot`.
func slot_name(slot: int) -> String:
	var slot_label := ""
	if snapshot != null and slot >= 0 and slot < snapshot.slots.size():
		slot_label = str(snapshot.slots[slot]["name"])
	return slot_label if not slot_label.is_empty() else tr("NET_PLAYER_N") % (slot + 1)


## MP: the local duelist is out of the running duel (killed, or fouled out).
func local_down() -> bool:
	return snapshot != null and not slot_alive(snapshot.local_slot())


## Host-side bullets report authoritative hits here during MP duels. `victim_slot` and
## `shooter_slot` are lobby slots (-1: shooter unknown); a self-kill is the same slot in
## both and still that duelist's death. `cut` is the hole the hit makes
## (`Hitbox.receive_hit`), sent ahead of the wound, the down, or the finish. `side` is the
## arm hit (`Hitbox.side`); the victim's peer decides gun arm or off arm.
func mp_report_hit(victim_slot: int, trail_points: PackedVector3Array,
		region: StringName = CombatRules.REGION_TORSO, damage: float = 1.0,
		shooter_slot := -1, cut := {}, side := &"") -> void:
	if not is_mp or not accepts_hits() or not NetworkManager.is_host() or not slot_alive(victim_slot):
		return
	var result := CombatRules.resolve(region, _health[victim_slot], damage)
	_health[victim_slot] = result["health"]
	_send_chunk(victim_slot, cut, trail_points, result["died"])
	if result["died"]:
		_host_eliminate(victim_slot, shooter_slot, trail_points, Cause.KILLED)
	else:
		_mp_wound.rpc(victim_slot, String(region), _health[victim_slot], String(side))


## Host: the hole a hit made on the NPC in `slot`. The NPC resolves its own HP
## (`DuelistAI.take_bullet_hit`) and does not cut itself here: `_mp_chunk` cuts it once on
## every peer, this one included.
func mp_report_npc_cut(slot: int, cut: Dictionary, trail_points: PackedVector3Array, lethal: bool) -> void:
	if is_mp and NetworkManager.is_host() and slot_alive(slot):
		_send_chunk(slot, cut, trail_points, lethal)


## Host: every peer cuts the same hole at the host's clip time. Reliable channel 0, so
## it lands before the `_mp_wound` / `_mp_down` / `_mp_finish` sent after it. `cut` is
## empty for no hole: it still goes out (bone -1) so every peer flashes the body.
func _send_chunk(victim_slot: int, cut: Dictionary, trail_points: PackedVector3Array,
		lethal: bool) -> void:
	var bone := int(cut["bone"]) if not cut.is_empty() else -1
	var local: Vector3 = cut["local"] if bone >= 0 else Vector3.ZERO
	var radius := float(cut["radius"]) if bone >= 0 else 0.0
	_mp_chunk.rpc(victim_slot, bone, local, radius,
			DummyBody.shot_dir(trail_points), ReplayBuffer.clip_time(), lethal)


## Host: `slot` is out of the duel. The last side standing wins it, and every slot of that
## side is tallied, dead or alive; with two or more sides left the rest carry on.
func _host_eliminate(slot: int, killer_slot: int, trail_points: PackedVector3Array, cause: int) -> void:
	_alive[slot] = false
	var sides := _live_sides()
	# A leaver's avatar has to go on every peer even when the duel ends with it.
	if sides.size() > 1 or cause == Cause.LEFT:
		_mp_down.rpc(slot, killer_slot, trail_points, cause)
	if sides.size() > 1:
		return
	var winning_side: int = sides[0] if not sides.is_empty() else -1
	var winners: Array[int] = []
	for winner in snapshot.slots.size():
		if snapshot.side_of(winner) == winning_side and _occupant_stays(winner):
			winners.append(winner)
	NetworkManager.host_add_wins(winners)
	_mp_finish.rpc(winning_side, _finish_reason(slot, cause), trail_points, killer_slot, slot)


## Host: the live roster's `slot` still holds whoever began this duel in it. A leaver's
## slot is an NPC's by now, and a new occupant starts its own tally.
func _occupant_stays(slot: int) -> bool:
	var live := NetworkManager.roster.slots
	return slot < live.size() and live[slot]["kind"] == snapshot.slots[slot]["kind"] \
			and live[slot]["peer_id"] == snapshot.slots[slot]["peer_id"]


## Sides with a duelist still in. Free-for-all: every slot is its own side.
func _live_sides() -> Array[int]:
	var sides: Array[int] = []
	for slot in _alive.size():
		var side := snapshot.side_of(slot)
		if _alive[slot] and not sides.has(side):
			sides.append(side)
	return sides


## MP: the running duel is Teams with 3-4 duelists. Two duelists read as a 1v1 in either
## mode: YOU WIN / YOU LOSE and the 1v1 reasons.
func is_team_duel() -> bool:
	return snapshot != null and snapshot.mode == LobbyRoster.Mode.TEAMS and snapshot.slots.size() > 2


func _finish_reason(slot: int, cause: int) -> String:
	# One wording for a kill, a foul-out, and a leaver: whoever went may be the
	# reader's teammate, so "opponent" would be wrong for half the lobby.
	if is_team_duel():
		return "MSG_REASON_LAST_SIDE"
	match cause:
		Cause.FOUL:
			return "MSG_REASON_FOUL_HOST" if slot == 0 else "MSG_REASON_FOUL_OPPONENT"
		Cause.LEFT:
			return "MSG_OPPONENT_LEFT"
	return "MSG_REASON_CLEAN_KILL" if snapshot.slots.size() == 2 else "MSG_REASON_LAST_STANDING"


## Host: `peer_id` dropped. In a running duel its slot counts as dead and its avatar goes
## on every peer; after the finish only the avatar goes. False when it held no slot in
## this duel (the waiting room).
func host_peer_left(peer_id: int) -> bool:
	if snapshot == null or state == State.IDLE:
		return false
	var slot := snapshot.slot_of_peer(peer_id)
	if slot < 0:
		return false
	if state != State.RESOLUTION and slot_alive(slot):
		_host_eliminate(slot, -1, PackedVector3Array(), Cause.LEFT)
	else:
		_mp_down.rpc(slot, -1, PackedVector3Array(), Cause.LEFT)
	return true


## `killer_id` / `victim_id` are ReplayBuffer actor ids: lobby slots in MP; the player
## (0) and NPC i (i + 1) in single player.
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
		State.INTRO:
			var card := int(_timer / TitleCard.DURATION)
			if card >= _intro_cards:
				_enter(State.STANDOFF)
			elif card != _intro_card:
				_intro_card = card
				if is_mp:
					_mp_intro_card.rpc(card)
				else:
					intro.show_card(card)
		State.STANDOFF:
			if _everyone_holstered():
				if _timer >= 1.5:
					_wait_duration = randf_range(SIGNAL_DELAY_MIN, SIGNAL_DELAY_MAX)
					_enter(State.WAIT_SIGNAL)
			else:
				_timer = 0.0
		State.WAIT_SIGNAL:
			_watch_local_foul()
			# A foul may have ended the duel or voided the standoff.
			if state == State.WAIT_SIGNAL and _timer >= _wait_duration:
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
	_foul_reported = false
	if state != State.INTRO:
		intro.finish()
	state_changed.emit(state)
	match state:
		State.INTRO:
			_intro_card = 0
			_intro_skip_sent = false
			var entries := _intro_entries()
			_intro_cards = entries.size()
			intro.begin(entries)
			intro.show_card(0)
		State.STANDOFF:
			ReplayBuffer.begin()
			_show_standoff_message()
		State.WAIT_SIGNAL:
			GameManager.show_message(tr("MSG_WAIT_BELL"), 2.0)
		State.DRAW:
			_ring_bell()
			GameManager.show_message(tr("MSG_DRAW"), 1.5)
			for ai in _ais:
				if is_instance_valid(ai):
					ai.begin_draw()


## The lineup and HOLSTER line, after whatever the title cards held back (a gauntlet's
## progress, a leaver), each once.
func _show_standoff_message() -> void:
	var lines := PackedStringArray()
	for text in GameManager.take_held_messages():
		if text != _lineup_text and not lines.has(text):
			lines.append(text)
	var held := lines.size()
	if not _lineup_text.is_empty():
		lines.append(_lineup_text)
	lines.append(tr("MSG_HOLSTER"))
	GameManager.show_message("\n".join(lines), HELD_MESSAGE_SECONDS if held > 0 else 2.0)


# -- Title cards ----------------------------------------------------------------

func intro_playing() -> bool:
	return state == State.INTRO


## Fire during the cards: straight to the standoff. A client asks the host, which skips
## for everyone.
func request_intro_skip() -> void:
	if state != State.INTRO:
		return
	if not is_mp or NetworkManager.is_host():
		_enter(State.STANDOFF)
	elif not _intro_skip_sent and _in_mp_duel():
		_intro_skip_sent = true
		_mp_request_intro_skip.rpc_id(1)


## The pause menu opened over the cards. Single player skips to the standoff (the paused
## tree holds it there); multiplayer gives this peer its own view back while the host's
## clock runs on.
func on_intro_paused() -> void:
	if not is_mp:
		request_intro_skip()
	else:
		intro.finish()


## One entry per card: SP, each NPC in lineup order, then the player; MP, slot order with
## the NPC slots, each on its spawn.
func _intro_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if is_mp:
		var spawns := GameManager.slot_spawns(snapshot)
		for slot in snapshot.slots.size():
			var baked: Texture2D = null
			if snapshot.slots[slot]["kind"] == LobbyRoster.Kind.NPC:
				baked = GameManager.archetype_at(snapshot.slots[slot]["archetype"]).title_card_name
			entries.append(_intro_entry(slot_name(slot), baked,
					spawns.get(slot, GameManager.current_scenario.get_player_spawn())))
		return entries
	for ai in _ais:
		if is_instance_valid(ai) and ai.archetype != null:
			entries.append(_intro_entry(ai.archetype.display_name, ai.archetype.title_card_name,
					ai.global_transform))
	var player := GameManager.local_player
	if is_instance_valid(player):
		entries.append(_intro_entry(NetworkManager.local_player_name(), null, player.global_transform))
	return entries


static func _intro_entry(display_name: String, baked: Texture2D, spawn: Transform3D) -> Dictionary:
	return {"name": display_name, "texture": baked, "spawn": spawn}


## A duel that ends during the cards (a leaver in a 1v1): the view goes back, and the lines
## the cards held are dropped so the result shows.
func _cut_intro() -> void:
	if state == State.INTRO:
		intro.finish()
		GameManager.drop_held_messages()


func _ring_bell() -> void:
	_bell_player.stream = AudioCatalog.get_stream(&"bell")
	_bell_player.play()


# -- Foul & holster checks ------------------------------------------------------

## MP (host): every human still in the duel has holstered. A dead or fouled-out
## duelist cannot put its gun away, so it does not count.
func _everyone_holstered() -> bool:
	var player := GameManager.local_player
	var local_ok := is_instance_valid(player) and not player.is_gun_drawn()
	if not is_mp:
		return local_ok
	var local := snapshot.local_slot()
	for slot in snapshot.slots.size():
		if not _alive[slot]:
			continue
		if slot == local:
			if not local_ok:
				return false
		elif snapshot.slots[slot]["kind"] == LobbyRoster.Kind.HUMAN and not _holstered[slot]:
			return false
	return true


func _watch_local_foul() -> void:
	if state != State.WAIT_SIGNAL:
		return
	var player := GameManager.local_player
	if not is_instance_valid(player) or not player.is_gun_drawn():
		return
	if not is_mp:
		_finish_sp(false, "MSG_REASON_FOUL_YOU")
	elif NetworkManager.is_host():
		_host_foul(snapshot.local_slot())
	elif not _foul_reported and player.alive:
		_foul_reported = true
		_mp_report_foul.rpc_id(1)


## Host: `slot` drew before the bell. Two duelists: the fouler loses at once. Three or
## four: a slot's first foul voids the standoff and its second puts it out.
func _host_foul(slot: int) -> void:
	if state != State.WAIT_SIGNAL or not slot_alive(slot):
		return
	_fouls[slot] += 1
	if snapshot.slots.size() > 2 and _fouls[slot] < FOULS_OUT:
		_mp_void.rpc(slot)
	else:
		_host_eliminate(slot, -1, PackedVector3Array(), Cause.FOUL)


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
	if not accepts_hits():
		return  # a corpse falling while the survivors fight is just a corpse
	if is_mp:
		# Host: the NPC already fell here. `_mp_down` / `_mp_finish` drop its proxy on the
		# clients and find no avatar to drop on this peer.
		_host_eliminate(ai.actor_id, ai.killed_by, trail_points, Cause.KILLED)
		return
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
	_cut_intro()
	state = State.RESOLUTION
	if not _survivors_fight:
		for ai in _ais:
			if is_instance_valid(ai):
				ai.on_duel_over(local_won)
	duel_finished.emit(local_won, reason)


# -- Multiplayer RPCs -----------------------------------------------------------

## Waiting room: the arena is loaded and everyone stands on their slot's spawn and can
## walk. No duel runs (IDLE), so hits are off.
@rpc("authority", "call_local", "reliable")
func _mp_lobby(scenario_index: int, time_of_day: float) -> void:
	if not NetworkManager.is_active():
		return  # still mid-handshake: the host has not given this peer a slot
	stop()
	is_mp = true
	GameManager.setup_mp_lobby(scenario_index, time_of_day)


## True on a peer inside an MP duel: it holds a slot and took this duel's `_mp_begin`.
## A peer still in the handshake gets the broadcasts too and must ignore them.
func _in_mp_duel() -> bool:
	return is_mp and snapshot != null and NetworkManager.is_active()


## `snapshot_data` is the roster this duel runs on (`LobbyRoster.pack()`): mode, and per
## slot kind / peer / name / side / archetype (an NPC's rolled one) / wins. `play_intro` is
## the host's call: the title cards first, in slot order.
@rpc("authority", "call_local", "reliable")
func _mp_begin(scenario_index: int, time_of_day: float, snapshot_data: Dictionary, play_intro: bool) -> void:
	if not NetworkManager.is_active():
		return  # still mid-handshake: the host has not given this peer a slot
	var roster := LobbyRoster.new()
	if not roster.unpack(snapshot_data) or roster.local_slot() < 0:
		return
	DeathCam.stop()
	ReplayBuffer.abort()
	is_mp = true
	snapshot = roster
	_lineup_text = ""
	var count := roster.slots.size()
	_health.resize(count)
	_health.fill(CombatRules.player_max_health())
	_alive.resize(count)
	_alive.fill(true)
	_fouls.resize(count)
	_fouls.fill(0)
	_holstered.resize(count)
	_holstered.fill(false)
	# Bind before setup: reset_for_duel emits holstered_changed, which the
	# client must relay to the host.
	_bind_player()
	if play_intro:
		GameManager.hold_messages()
	GameManager.setup_mp_duel(scenario_index, time_of_day)
	# The host runs the NPC slots; a client has none.
	_ais = GameManager.current_ais.duplicate()
	for ai in _ais:
		ai.died.connect(_on_enemy_died.bind(ai))
	state = State.INTRO if play_intro else State.STANDOFF
	_timer = 0.0
	_apply_state()


@rpc("authority", "call_remote", "reliable")
func _mp_set_state(new_state: int) -> void:
	if not _in_mp_duel():
		return
	state = new_state
	_apply_state()


## Host: card `card` of the running intro, on every peer at once.
@rpc("authority", "call_local", "reliable")
func _mp_intro_card(card: int) -> void:
	if _in_mp_duel() and state == State.INTRO:
		intro.show_card(card)


## A client fired during the cards. The host skips for everyone (`_mp_set_state`).
@rpc("any_peer", "call_remote", "reliable")
func _mp_request_intro_skip() -> void:
	if NetworkManager.is_host() and _in_mp_duel() and state == State.INTRO \
			and snapshot.slot_of_peer(multiplayer.get_remote_sender_id()) >= 0:
		_enter(State.STANDOFF)


@rpc("any_peer", "call_remote", "reliable")
func _mp_report_foul() -> void:
	if NetworkManager.is_host() and _in_mp_duel():
		_host_foul(snapshot.slot_of_peer(multiplayer.get_remote_sender_id()))


@rpc("any_peer", "call_remote", "reliable")
func _mp_holstered_state(holstered: bool) -> void:
	if not NetworkManager.is_host() or not _in_mp_duel():
		return
	var slot := snapshot.slot_of_peer(multiplayer.get_remote_sender_id())
	if slot >= 0:
		_holstered[slot] = holstered


func _on_local_holster_changed(holstered: bool) -> void:
	if is_mp and not NetworkManager.is_host():
		_mp_holstered_state.rpc_id(1, holstered)


@rpc("authority", "call_local", "reliable")
func _mp_wound(victim_slot: int, region_str: String, new_health: float, side_str: String) -> void:
	if not _in_mp_duel() or state == State.RESOLUTION:
		return
	if victim_slot == snapshot.local_slot() and is_instance_valid(GameManager.local_player):
		GameManager.local_player.apply_wound(StringName(region_str), new_health, StringName(side_str))


## Every peer flashes the victim's body and cuts it: `bone` / `local` / `radius` rebuild the
## cut (`DummyBody.cut_on_bone`; bone -1 is no hole), `dir` is the shot, `clip_t` the host's
## clip time.
@rpc("authority", "call_local", "reliable")
func _mp_chunk(victim_slot: int, bone: int, local: Vector3, radius: float, dir: Vector3,
		clip_t: float, lethal: bool) -> void:
	if not _in_mp_duel():
		return
	var victim := GameManager.actor_node(victim_slot)
	if is_instance_valid(victim) and victim.has_method("corpse_body"):
		var body: DummyBody = victim.corpse_body()
		if body != null:
			body.flash(clip_t)
			body.knock_chunk({"bone": bone, "local": local, "radius": radius}, dir, clip_t, lethal)


## A duelist is out while the duel goes on. KILLED: the body falls and the gun drops, with
## no kill cam and no sting. FOUL (a second foul): no fall, the body stands frozen. LEFT:
## the avatar goes. The host also sends LEFT after the finish, to clear a leaver's avatar.
## A local duelist who is killed or fouled out goes on to spectate the living (`DeathCam`).
@rpc("authority", "call_local", "reliable")
func _mp_down(victim_slot: int, killer_slot: int, trail_points: PackedVector3Array, cause: int) -> void:
	if not _in_mp_duel() or victim_slot < 0 or victim_slot >= _alive.size():
		return
	_alive[victim_slot] = false
	if cause == Cause.KILLED:
		ReplayBuffer.note_death(victim_slot)
	var player := GameManager.local_player
	var is_local := victim_slot == snapshot.local_slot() and is_instance_valid(player)
	var avatar := GameManager.actor_node(victim_slot) as RemoteAvatar
	var lines: PackedStringArray = []
	match cause:
		Cause.LEFT:
			GameManager.free_avatar(victim_slot)
			lines.append(tr("MSG_DUELIST_LEFT") % slot_name(victim_slot))
		Cause.FOUL:
			if is_local:
				player.play_death_feedback()
			elif avatar != null:
				avatar.put_out()
			lines.append(tr("MSG_FOUL_OUT") % slot_name(victim_slot))
		_:
			if is_local:
				player.play_death_feedback()
				player.collapse(trail_points)
			elif avatar != null:
				avatar.collapse(trail_points)
			# Named for everyone, from the slot ids this RPC already carries.
			if killer_slot >= 0 and killer_slot != victim_slot:
				lines.append(tr("MSG_DUELIST_SHOT") % [slot_name(victim_slot), slot_name(killer_slot)])
			else:
				lines.append(tr("MSG_DUELIST_DOWN") % slot_name(victim_slot))
	if state != State.RESOLUTION:
		lines.append(tr("MSG_NPCS_LEFT") % live_slots().size())
	GameManager.show_message("\n".join(lines), 2.0)
	if is_local and cause != Cause.LEFT and state != State.RESOLUTION:
		DeathCam.start_spectate(killer_slot, cause == Cause.KILLED)


## A first foul with 3-4 duelists: back to the standoff where everyone stands. No arena
## reload and no teleport; everyone holsters again and the host rolls a new bell delay.
@rpc("authority", "call_local", "reliable")
func _mp_void(fouler_slot: int) -> void:
	if not _in_mp_duel() or state == State.RESOLUTION:
		return
	state = State.STANDOFF
	_timer = 0.0
	_foul_reported = false
	state_changed.emit(state)
	GameManager.show_message(tr("MSG_FOUL_VOID") % slot_name(fouler_slot), 3.0)


## `winning_side` is a `LobbyRoster.side_of` value. An empty trail is a foul or a leaver:
## nobody falls and `killer_slot` is -1.
@rpc("authority", "call_local", "reliable")
func _mp_finish(winning_side: int, reason: String, trail_points: PackedVector3Array,
		killer_slot: int, victim_slot: int) -> void:
	if not _in_mp_duel() or state == State.RESOLUTION:
		return
	_cut_intro()
	state = State.RESOLUTION
	var local := snapshot.local_slot()
	var local_won := snapshot.side_of(local) == winning_side
	var killed := not trail_points.is_empty()
	if victim_slot >= 0 and victim_slot < _alive.size():
		_alive[victim_slot] = false
	if killed:
		# Before the fly-along starts: it restores the camera it finds, which must be the
		# player's own and not a spectator's orbit.
		DeathCam.end_spectate()
		notify_kill_shot(trail_points, killer_slot, victim_slot)
	# Only a killing shot falls; a foul has no trail and the loser stays frozen.
	var player := GameManager.local_player
	if not local_won and is_instance_valid(player) and player.alive:
		player.play_death_feedback()
	if killed and victim_slot == local and is_instance_valid(player):
		player.collapse(trail_points)
	elif killed:
		var avatar := GameManager.actor_node(victim_slot) as RemoteAvatar
		if avatar != null:
			avatar.collapse(trail_points)
	for ai in _ais:
		if is_instance_valid(ai):
			ai.on_duel_over(local_won)
	duel_finished.emit(local_won, reason)
