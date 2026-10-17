class_name NucleusTurnSession
extends Node
## Local deterministic scheduler; no combat rules, global singleton or Timer.
## Participant callbacks may end turns reentrantly; the pump stays nonrecursive.

signal session_started
signal session_ended(reason: StringName, completed_turns: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal turn_started(participant: NucleusTurnParticipant, round_number: int)
signal turn_ended(participant: NucleusTurnParticipant, reason: StringName)
signal turn_skipped(participant: NucleusTurnParticipant, reason: StringName)
signal remaining_time_changed(participant: NucleusTurnParticipant, seconds: float)

enum Mode { SERIAL, INITIATIVE, SIMULTANEOUS }

@export var mode: Mode = Mode.SERIAL
@export_range(0.0, 86400.0, 0.01, "or_greater") var default_turn_seconds: float = 0.0
@export_range(0, 1000000, 1, "or_greater") var maximum_turns: int = 0
@export var automatic_clock: bool = true

var running: bool = false
var paused: bool = false
var round_number: int = 0
var completed_turns: int = 0

var _roster: Array[NucleusTurnParticipant] = []
var _active: Array[NucleusTurnParticipant] = []
var _remaining: Dictionary[StringName, float] = {}
var _index: int = 0
var _round_open: bool = false
var _pumping: bool = false


func _ready() -> void:
	set_process(false)


func start_session(participants: Array[NucleusTurnParticipant]) -> Error:
	if running or _pumping:
		return ERR_BUSY
	if participants.is_empty():
		return ERR_INVALID_PARAMETER
	if not _valid_duration(default_turn_seconds):
		return ERR_INVALID_PARAMETER
	if maximum_turns < 0:
		return ERR_INVALID_PARAMETER
	var ids: Dictionary = {}
	for seat: NucleusTurnParticipant in participants:
		if seat == null or not is_instance_valid(seat):
			return ERR_INVALID_PARAMETER
		if seat.participant_id == &"" or ids.has(seat.participant_id):
			return ERR_INVALID_DATA
		if seat.get_session() != null:
			return ERR_BUSY
		if not _valid_duration(seat.turn_seconds, true):
			return ERR_INVALID_PARAMETER
		ids[seat.participant_id] = true
	_roster.assign(participants)
	if mode == Mode.INITIATIVE:
		var sorted: Array[NucleusTurnParticipant] = []
		for seat: NucleusTurnParticipant in _roster:
			var position: int = 0
			while position < sorted.size():
				if sorted[position].initiative < seat.initiative:
					break
				position += 1
			sorted.insert(position, seat)
		_roster = sorted
	for seat: NucleusTurnParticipant in _roster:
		seat._session = self
	_active.clear()
	_remaining.clear()
	_index = 0
	_round_open = false
	round_number = 0
	completed_turns = 0
	paused = false
	running = true
	set_process(automatic_clock)
	session_started.emit()
	_pump()
	return OK


func get_participants() -> Array[NucleusTurnParticipant]:
	return _roster.duplicate()


func get_active_participants() -> Array[NucleusTurnParticipant]:
	return _active.duplicate()


func get_current_participant() -> NucleusTurnParticipant:
	return _active[0] if _active.size() == 1 else null


func get_remaining_seconds(seat: NucleusTurnParticipant) -> float:
	if seat == null or not _active.has(seat):
		return -1.0
	return _remaining.get(seat.participant_id, -1.0)


func complete_turn(seat: NucleusTurnParticipant) -> Error:
	return _finish_turn(seat, &"completed")


func skip_turn(seat: NucleusTurnParticipant) -> Error:
	return _finish_turn(seat, &"skipped")


func set_paused(value: bool) -> void:
	paused = value
	set_process(running and automatic_clock and not paused)


func end_session(reason: StringName = &"manual") -> void:
	if not running:
		return
	running = false
	set_process(false)
	for seat: NucleusTurnParticipant in _active.duplicate():
		if is_instance_valid(seat):
			seat.turn_ended.emit(&"session_ended")
			turn_ended.emit(seat, &"session_ended")
	for seat: NucleusTurnParticipant in _roster:
		if is_instance_valid(seat) and seat._session == self:
			seat._session = null
	_active.clear()
	_remaining.clear()
	_roster.clear()
	_round_open = false
	_index = 0
	session_ended.emit(reason, completed_turns)


func advance(seconds: float) -> Error:
	if seconds < 0.0 or is_nan(seconds) or is_inf(seconds):
		return ERR_INVALID_PARAMETER
	if not running or paused:
		return ERR_UNAVAILABLE
	# Snapshot: any new turn opened by a timeout is not charged old elapsed time.
	for seat: NucleusTurnParticipant in _active.duplicate():
		if not running:
			break
		if not is_instance_valid(seat) or not _active.has(seat):
			continue
		var remaining: float = _remaining.get(seat.participant_id, -1.0)
		if remaining < 0.0:
			continue
		remaining = maxf(0.0, remaining - seconds)
		_remaining[seat.participant_id] = remaining
		remaining_time_changed.emit(seat, remaining)
		if remaining <= 0.0 and _active.has(seat):
			_finish_turn(seat, &"timeout")
	return OK


func _process(delta: float) -> void:
	advance(delta)


func _finish_turn(seat: NucleusTurnParticipant, reason: StringName) -> Error:
	if not running or seat == null or not _active.has(seat):
		return ERR_UNAVAILABLE
	_active.erase(seat)
	_remaining.erase(seat.participant_id)
	if reason == &"skipped":
		seat.turn_skipped.emit(reason)
		turn_skipped.emit(seat, reason)
	seat.turn_ended.emit(reason)
	turn_ended.emit(seat, reason)
	completed_turns += 1
	if maximum_turns > 0 and completed_turns >= maximum_turns:
		end_session(&"maximum_turns")
	elif _active.is_empty():
		_pump()
	return OK


func _pump() -> void:
	if _pumping or not running:
		return
	_pumping = true
	var steps: int = 0
	while running and _active.is_empty() and steps < 256:
		steps += 1
		if _index >= _roster.size():
			if _round_open:
				_round_open = false
				round_ended.emit(round_number)
			_index = 0
		if not running:
			break
		if _index == 0:
			if not _has_eligible():
				end_session(&"no_eligible_participants")
				break
			round_number += 1
			_round_open = true
			round_started.emit(round_number)
		if not running:
			break
		if mode == Mode.SIMULTANEOUS:
			_start_batch()
		else:
			var seat: NucleusTurnParticipant = _roster[_index]
			_index += 1
			if not _can_participate(seat):
				continue
			if seat.consume_blocked_opportunity():
				_skip_blocked(seat)
			else:
				_activate(seat)
	_pumping = false
	if running and _active.is_empty() and steps >= 256:
		call_deferred("_pump")


func _start_batch() -> void:
	var new_turns: Array[NucleusTurnParticipant] = []
	while _index < _roster.size() and running:
		var seat: NucleusTurnParticipant = _roster[_index]
		_index += 1
		if not _can_participate(seat):
			continue
		if seat.consume_blocked_opportunity():
			_skip_blocked(seat)
		else:
			_active.append(seat)
			_remaining[seat.participant_id] = _duration_for(seat)
			new_turns.append(seat)
	for seat: NucleusTurnParticipant in new_turns:
		if running and _active.has(seat):
			_emit_start(seat)


func _activate(seat: NucleusTurnParticipant) -> void:
	_active.append(seat)
	_remaining[seat.participant_id] = _duration_for(seat)
	_emit_start(seat)


func _emit_start(seat: NucleusTurnParticipant) -> void:
	seat.turn_started.emit(round_number)
	turn_started.emit(seat, round_number)


func _skip_blocked(seat: NucleusTurnParticipant) -> void:
	seat.turn_skipped.emit(&"blocked")
	turn_skipped.emit(seat, &"blocked")
	completed_turns += 1
	if maximum_turns > 0 and completed_turns >= maximum_turns:
		end_session(&"maximum_turns")


func _has_eligible() -> bool:
	for seat: NucleusTurnParticipant in _roster:
		if _can_participate(seat):
			return true
	return false


func _can_participate(seat: NucleusTurnParticipant) -> bool:
	return is_instance_valid(seat) and seat.enabled and seat.is_inside_tree()


func _duration_for(seat: NucleusTurnParticipant) -> float:
	var seconds: float = (
		seat.turn_seconds if seat.turn_seconds >= 0.0 else default_turn_seconds
	)
	return seconds if seconds > 0.0 else -1.0


func _valid_duration(seconds: float, allow_inherit: bool = false) -> bool:
	if is_nan(seconds) or is_inf(seconds):
		return false
	return seconds >= 0.0 or (allow_inherit and seconds == -1.0)


func _exit_tree() -> void:
	end_session(&"owner_exited")
