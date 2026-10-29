class_name NucleusUnlockGraph
extends Node
## Rank graph with points budget; the UI and rewards remain game-owned.

signal unlock_changed(unlock_id: StringName, rank: int)
signal points_changed(available: int)

@export var definitions: Array[NucleusUnlockDefinition] = []
@export var progression: NucleusProgressionTrack
@export var initial_points: int = 0

var available_points: int = 0
var _ranks: Dictionary[StringName, int] = {}
var _index: Dictionary[StringName, NucleusUnlockDefinition] = {}


func _ready() -> void:
	available_points = maxi(0, initial_points)
	for definition: NucleusUnlockDefinition in definitions:
		if definition != null and definition.unlock_id != &"" and not _index.has(definition.unlock_id):
			_index[definition.unlock_id] = definition


func get_rank(id: StringName) -> int:
	return _ranks.get(id, 0)


func add_points(amount: int) -> Error:
	if amount < 0 or amount > 2147483647 - available_points:
		return ERR_INVALID_PARAMETER
	available_points += amount
	points_changed.emit(available_points)
	return OK


func validate_graph() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in _index:
		var definition: NucleusUnlockDefinition = _index[id]
		for key: Variant in definition.required_ranks:
			var dependency := StringName(str(key))
			if not _index.has(dependency) or dependency == id:
				errors.append("Invalid prerequisite %s for %s" % [dependency, id])
			elif (
				int(definition.required_ranks[key]) < 1
				or int(definition.required_ranks[key]) > _index[dependency].max_rank
			):
				errors.append("Invalid prerequisite rank %s for %s" % [dependency, id])
	# Detect any prerequisite cycle, not just self-edges.
	for id: StringName in _index:
		if _reaches(id, id, {}):
			errors.append("Cyclic prerequisite: %s" % id)
	return errors


func _reaches(start: StringName, target: StringName, visited: Dictionary) -> bool:
	if visited.has(start):
		return false
	visited[start] = true
	var definition: NucleusUnlockDefinition = _index.get(start)
	if definition == null:
		return false
	for key: Variant in definition.required_ranks:
		var dependency := StringName(str(key))
		if dependency == target or _reaches(dependency, target, visited):
			return true
	return false


func can_unlock(id: StringName) -> Error:
	if not validate_graph().is_empty():
		return ERR_INVALID_DATA
	var definition: NucleusUnlockDefinition = _index.get(id)
	if definition == null:
		return ERR_DOES_NOT_EXIST
	if get_rank(id) >= definition.max_rank:
		return ERR_ALREADY_EXISTS
	if available_points < definition.cost_per_rank:
		return ERR_UNAVAILABLE
	if progression != null and progression.level < definition.minimum_level:
		return ERR_UNAVAILABLE
	if definition.exclusive_group != &"":
		for other_id: StringName in _index:
			if (
				other_id != id
				and _index[other_id].exclusive_group == definition.exclusive_group
				and get_rank(other_id) > 0
			):
				return ERR_UNAVAILABLE
	for key: Variant in definition.required_ranks:
		if get_rank(StringName(str(key))) < int(definition.required_ranks[key]):
			return ERR_UNAVAILABLE
	return OK


func unlock(id: StringName) -> Error:
	var error: Error = can_unlock(id)
	if error != OK:
		return error
	var definition: NucleusUnlockDefinition = _index[id]
	available_points -= definition.cost_per_rank
	_ranks[id] = get_rank(id) + 1
	points_changed.emit(available_points)
	unlock_changed.emit(id, _ranks[id])
	return OK


func reset_unlocks(refund: bool = true) -> void:
	if refund:
		for id: StringName in _ranks:
			available_points += _ranks[id] * _index[id].cost_per_rank
	for id: StringName in _ranks.keys():
		unlock_changed.emit(id, 0)
	_ranks.clear()
	points_changed.emit(available_points)


func capture_state() -> Dictionary:
	var ranks: Dictionary = {}
	for id: StringName in _ranks:
		ranks[String(id)] = _ranks[id]
	return {"ranks": ranks, "available_points": available_points}


func restore_state(data: Dictionary) -> Error:
	if not validate_graph().is_empty():
		return ERR_INVALID_DATA
	var ranks: Variant = data.get("ranks", {})
	var points: Variant = data.get("available_points", -1)
	if not (ranks is Dictionary) or not (points is int) or points < 0:
		return ERR_INVALID_DATA
	var restored: Dictionary[StringName, int] = {}
	for key: Variant in ranks:
		var id := StringName(str(key))
		var rank: Variant = ranks[key]
		if not _index.has(id) or not (rank is int) or rank < 0 or rank > _index[id].max_rank:
			return ERR_INVALID_DATA
		if rank > 0:
			restored[id] = rank
	# Check requirements and exclusivity on the restored snapshot.
	for id: StringName in restored:
		var definition: NucleusUnlockDefinition = _index[id]
		for prerequisite: Variant in definition.required_ranks:
			if restored.get(StringName(str(prerequisite)), 0) < int(definition.required_ranks[prerequisite]):
				return ERR_INVALID_DATA
		if definition.exclusive_group != &"":
			for other: StringName in restored:
				if other != id and _index[other].exclusive_group == definition.exclusive_group:
					return ERR_INVALID_DATA
	_ranks = restored
	available_points = points
	points_changed.emit(available_points)
	for id: StringName in _ranks:
		unlock_changed.emit(id, _ranks[id])
	return OK
