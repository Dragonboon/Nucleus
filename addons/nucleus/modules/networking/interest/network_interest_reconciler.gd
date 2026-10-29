class_name NucleusNetworkInterestReconciler
extends RefCounted
## Bounded, deterministic desired-versus-admitted entity set for one peer.
## Emits decisions only; actual replication remains game/Godot-owned.

signal entity_entered(entity_id: StringName)
signal entity_exited(entity_id: StringName)

var max_enters_per_pump: int = 8
var max_exits_per_pump: int = 16

var _desired: Array[StringName] = []
var _desired_lookup: Dictionary = {}
var _admitted: Array[StringName] = []
var _admitted_lookup: Dictionary = {}


func set_desired_entities(entity_ids: Array[StringName]) -> void:
	_desired.clear()
	_desired_lookup.clear()

	for entity_id: StringName in entity_ids:
		if entity_id == &"" or _desired_lookup.has(entity_id):
			continue

		_desired_lookup[entity_id] = true
		_desired.append(entity_id)


func get_desired_entities() -> Array[StringName]:
	return _desired.duplicate()


func get_admitted_entities() -> Array[StringName]:
	return _admitted.duplicate()


func is_admitted(entity_id: StringName) -> bool:
	return _admitted_lookup.has(entity_id)


func is_settled() -> bool:
	if _desired.size() != _admitted.size():
		return false

	for entity_id: StringName in _desired:
		if not _admitted_lookup.has(entity_id):
			return false

	return true


func pump() -> void:
	var entered: int = 0
	for entity_id: StringName in _desired.duplicate():
		if entered >= maxi(max_enters_per_pump, 0):
			break
		if _admitted_lookup.has(entity_id):
			continue
		if not _desired_lookup.has(entity_id):
			continue

		_admitted_lookup[entity_id] = true
		_admitted.append(entity_id)
		entity_entered.emit(entity_id)
		entered += 1

	var exited: int = 0
	for entity_id: StringName in _admitted.duplicate():
		if exited >= maxi(max_exits_per_pump, 0):
			break
		if _desired_lookup.has(entity_id):
			continue
		if not _admitted_lookup.has(entity_id):
			continue

		_forget_admitted(entity_id)
		entity_exited.emit(entity_id)
		exited += 1


func forget_entity(entity_id: StringName) -> void:
	_desired_lookup.erase(entity_id)
	_desired.erase(entity_id)
	if _admitted_lookup.has(entity_id):
		_forget_admitted(entity_id)
		entity_exited.emit(entity_id)


func clear_immediately() -> void:
	_desired.clear()
	_desired_lookup.clear()
	var previous: Array[StringName] = _admitted.duplicate()
	_admitted.clear()
	_admitted_lookup.clear()
	for entity_id: StringName in previous:
		entity_exited.emit(entity_id)


func get_pending_count() -> int:
	var count: int = 0
	for entity_id: StringName in _desired:
		if not _admitted_lookup.has(entity_id):
			count += 1
	for entity_id: StringName in _admitted:
		if not _desired_lookup.has(entity_id):
			count += 1
	return count


func _forget_admitted(entity_id: StringName) -> void:
	_admitted_lookup.erase(entity_id)
	_admitted.erase(entity_id)
