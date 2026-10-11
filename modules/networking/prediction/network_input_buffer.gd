class_name NucleusNetworkInputBuffer
extends RefCounted
## Bounded per-actor input history. Caller owns the actor and simulation.

var capacity: int = 64
var _entries: Array[Dictionary] = []
var _last_sequence: int = 0
var _acknowledged: int = 0

func push(sequence: int, command: Dictionary, state: Dictionary) -> bool:
	if sequence <= _last_sequence or sequence <= 0 or _entries.size() >= maxi(1, capacity):
		return false
	if state.is_empty():
		return false
	_entries.append({
		"sequence": sequence,
		"command": command.duplicate(true),
		"state": state.duplicate(true),
	})
	_last_sequence = sequence
	return true

func has_sequence(sequence: int) -> bool:
	for entry in _entries:
		if int(entry["sequence"]) == sequence:
			return true
	return false

func predicted_at(sequence: int) -> Dictionary:
	for entry in _entries:
		if int(entry["sequence"]) == sequence:
			return (entry["state"] as Dictionary).duplicate(true)
	return {}

func pending_after(sequence: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		if int(entry["sequence"]) > sequence:
			result.append(entry.duplicate(true))
	return result

func pending_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		result.append({
			"sequence": entry["sequence"],
			"command": (entry["command"] as Dictionary).duplicate(true),
		})
	return result

## Commit only if the whole replay succeeded.
func commit(ack_sequence: int, replayed: Array[Dictionary]) -> bool:
	if ack_sequence <= _acknowledged or not has_sequence(ack_sequence):
		return false
	var remaining: Array[Dictionary] = pending_after(ack_sequence)
	if remaining.size() != replayed.size():
		return false
	for state in replayed:
		if state.is_empty():
			return false
	for i in range(remaining.size()):
		remaining[i]["state"] = replayed[i].duplicate(true)
	_entries = remaining
	_acknowledged = ack_sequence
	return true

func size() -> int:
	return _entries.size()

func last_acknowledged() -> int:
	return _acknowledged

func reset() -> void:
	_entries.clear()
	_last_sequence = 0
	_acknowledged = 0
