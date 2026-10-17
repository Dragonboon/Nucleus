class_name NucleusEncounterDirector
extends Node
## Scene-owned wave state. Instance IDs prevent duplicate death accounting.

signal wave_requested(index: int, participants: Dictionary)
signal encounter_started(encounter_id: StringName)
signal encounter_completed(encounter_id: StringName)
signal encounter_canceled(encounter_id: StringName)
signal encounter_ended(encounter_id: StringName, outcome: StringName)
signal instance_registered(instance_id: StringName, participant_id: StringName)

@export var definition: NucleusEncounterDefinition

var running: bool = false
var wave_index: int = -1
var _remaining: Dictionary[StringName, int] = {}
var _instances: Dictionary[StringName, StringName] = {}
var _busy: bool = false
var _generation: int = 0


func start_encounter() -> Error:
	if running or _busy:
		return ERR_BUSY
	if not _valid_definition():
		return ERR_INVALID_DATA
	running = true
	wave_index = -1
	_generation += 1
	_instances.clear()
	_busy = true
	encounter_started.emit(definition.encounter_id)
	_busy = false
	if running:
		_start_next_wave()
	return OK


func get_remaining() -> Dictionary:
	return _remaining.duplicate()


func register_instance(instance_id: StringName, participant_id: StringName) -> Error:
	if not running or instance_id == &"" or not _remaining.has(participant_id):
		return ERR_INVALID_PARAMETER
	if _instances.has(instance_id):
		return ERR_ALREADY_EXISTS
	var registered: int = 0
	for value: StringName in _instances.values():
		if value == participant_id:
			registered += 1
	if registered >= int(_remaining[participant_id]):
		return ERR_UNAVAILABLE
	_instances[instance_id] = participant_id
	instance_registered.emit(instance_id, participant_id)
	return OK


func mark_instance_defeated(instance_id: StringName) -> Error:
	if not running or not _instances.has(instance_id):
		return ERR_DOES_NOT_EXIST
	var id: StringName = _instances[instance_id]
	_instances.erase(instance_id)
	return mark_defeated(id)


func mark_defeated(id: StringName, count: int = 1) -> Error:
	if not running or not _remaining.has(id) or count < 1 or count > _remaining[id]:
		return ERR_INVALID_PARAMETER
	_remaining[id] -= count
	if _remaining[id] == 0:
		_remaining.erase(id)
	if _remaining.is_empty():
		_start_next_wave()
	return OK


func finish_encounter(outcome: StringName) -> Error:
	if not running or outcome not in [&"victory", &"defeat", &"retreat"]:
		return ERR_INVALID_PARAMETER
	_finish(outcome)
	return OK


func cancel_encounter() -> bool:
	if not running:
		return false
	_finish(&"canceled")
	return true


func capture_state() -> Dictionary:
	var pending: Dictionary = {}
	for id: StringName in _remaining:
		pending[String(id)] = _remaining[id]
	var instances: Dictionary = {}
	for id: StringName in _instances:
		instances[String(id)] = String(_instances[id])
	return {
		"encounter_id": String(definition.encounter_id) if definition else "",
		"running": running,
		"wave_index": wave_index,
		"remaining": pending,
		"instances": instances,
	}


func restore_state(data: Dictionary) -> Error:
	if running or _busy or not _valid_definition():
		return ERR_BUSY
	if str(data.get("encounter_id", "")) != String(definition.encounter_id):
		return ERR_INVALID_DATA
	var requested: Variant = data.get("running", false)
	var index: Variant = data.get("wave_index", -1)
	var pending: Variant = data.get("remaining", {})
	var instances: Variant = data.get("instances", {})
	if not (requested is bool) or not (index is int):
		return ERR_INVALID_DATA
	if not (pending is Dictionary) or not (instances is Dictionary):
		return ERR_INVALID_DATA
	if requested and (index < 0 or index >= definition.waves.size()):
		return ERR_INVALID_DATA
	if not requested and (not pending.is_empty() or not instances.is_empty()):
		return ERR_INVALID_DATA
	var maximum: Dictionary = {}
	if requested:
		var wave: NucleusEncounterWave = definition.waves[index]
		for n: int in range(wave.counts.size()):
			var id: StringName = wave.participant_ids[n]
			maximum[id] = maximum.get(id, 0) + wave.counts[n]
	var restored: Dictionary[StringName, int] = {}
	for key: Variant in pending:
		var id := StringName(str(key))
		var value: Variant = pending[key]
		if not maximum.has(id) or not (value is int):
			return ERR_INVALID_DATA
		if value < 1 or value > int(maximum[id]):
			return ERR_INVALID_DATA
		restored[id] = value
	if requested and restored.is_empty():
		return ERR_INVALID_DATA
	var tracked: Dictionary[StringName, StringName] = {}
	var counts: Dictionary = {}
	for key: Variant in instances:
		var instance_id := StringName(str(key))
		var id := StringName(str(instances[key]))
		if instance_id == &"" or not restored.has(id):
			return ERR_INVALID_DATA
		tracked[instance_id] = id
		counts[id] = counts.get(id, 0) + 1
		if counts[id] > restored[id]:
			return ERR_INVALID_DATA
	_remaining = restored
	_instances = tracked
	wave_index = index
	running = requested
	_generation += 1
	return OK


func _valid_definition() -> bool:
	if definition == null or definition.encounter_id == &"":
		return false
	if definition.waves.is_empty():
		return false
	for wave: NucleusEncounterWave in definition.waves:
		if wave == null or wave.participant_ids.is_empty():
			return false
		if wave.participant_ids.size() != wave.counts.size():
			return false
		for n: int in range(wave.counts.size()):
			if wave.participant_ids[n] == &"" or wave.counts[n] <= 0:
				return false
	return true


func _start_next_wave() -> void:
	if not running or _busy:
		return
	_busy = true
	_instances.clear()
	wave_index += 1
	if wave_index >= definition.waves.size():
		_busy = false
		_finish(&"victory")
		return
	_remaining.clear()
	var wave: NucleusEncounterWave = definition.waves[wave_index]
	for n: int in range(wave.participant_ids.size()):
		var id: StringName = wave.participant_ids[n]
		_remaining[id] = _remaining.get(id, 0) + wave.counts[n]
	var serial: int = _generation
	wave_requested.emit(wave_index, get_remaining())
	_busy = false
	if serial != _generation:
		return


func _finish(outcome: StringName) -> void:
	if not running:
		return
	running = false
	_generation += 1
	_remaining.clear()
	_instances.clear()
	_busy = false
	if outcome == &"victory":
		encounter_completed.emit(definition.encounter_id)
	elif outcome == &"canceled":
		encounter_canceled.emit(definition.encounter_id)
	encounter_ended.emit(definition.encounter_id, outcome)
