class_name NucleusEncounterDirector
extends Node
## Groups and lifecycle only; encounter authority, actor factories, victory policy
## and rewards remain scene/game-owned. Actors are identified via stable IDs.

signal wave_requested(index: int, participants: Dictionary)
signal encounter_started(encounter_id: StringName)
signal encounter_completed(encounter_id: StringName)
signal encounter_canceled(encounter_id: StringName)

@export var definition: NucleusEncounterDefinition

var running: bool = false
var wave_index: int = -1
var _remaining: Dictionary[StringName, int] = {}


func start_encounter() -> Error:
	if running:
		return ERR_BUSY
	if definition == null or definition.encounter_id == &"" or definition.waves.is_empty():
		return ERR_INVALID_PARAMETER
	for wave: NucleusEncounterWave in definition.waves:
		if (
			wave == null
			or wave.participant_ids.is_empty()
			or wave.participant_ids.size() != wave.counts.size()
		):
			return ERR_INVALID_DATA
		for index: int in range(wave.counts.size()):
			if wave.participant_ids[index] == &"" or wave.counts[index] < 1:
				return ERR_INVALID_DATA
	running = true
	wave_index = -1
	encounter_started.emit(definition.encounter_id)
	_start_next_wave()
	return OK


func get_remaining() -> Dictionary:
	return _remaining.duplicate()


func mark_defeated(id: StringName, count: int = 1) -> Error:
	if not running or not _remaining.has(id) or count < 1 or count > _remaining[id]:
		return ERR_INVALID_PARAMETER
	_remaining[id] -= count
	if _remaining[id] == 0:
		_remaining.erase(id)
	if _remaining.is_empty():
		_start_next_wave()
	return OK


func cancel_encounter() -> bool:
	if not running:
		return false
	running = false
	_remaining.clear()
	encounter_canceled.emit(definition.encounter_id)
	return true


func _start_next_wave() -> void:
	wave_index += 1
	if wave_index >= definition.waves.size():
		running = false
		_remaining.clear()
		encounter_completed.emit(definition.encounter_id)
		return
	_remaining.clear()
	var wave: NucleusEncounterWave = definition.waves[wave_index]
	for index: int in range(wave.participant_ids.size()):
		var id: StringName = wave.participant_ids[index]
		_remaining[id] = _remaining.get(id, 0) + wave.counts[index]
	wave_requested.emit(wave_index, get_remaining())
