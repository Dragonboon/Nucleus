class_name NucleusAbilityLoadout
extends Node
## Stable skill IDs and optional unlock ranks mapped to scene-owned actions.

signal assignment_changed(slot_id: StringName, action_id: StringName)

@export var action_set: NucleusActionSet
@export var unlock_graph: NucleusUnlockGraph
@export var require_unlocked: bool = true

var _slots: Dictionary[StringName, StringName] = {}


func assign(slot_id: StringName, action_id: StringName) -> Error:
	if slot_id == &"" or action_id == &"":
		return ERR_INVALID_PARAMETER
	if action_set == null or not action_set.has_action(action_id):
		return ERR_DOES_NOT_EXIST
	if require_unlocked and (unlock_graph == null or unlock_graph.get_rank(action_id) < 1):
		return ERR_UNAVAILABLE
	_slots[slot_id] = action_id
	assignment_changed.emit(slot_id, action_id)
	return OK


func unassign(slot_id: StringName) -> bool:
	if not _slots.erase(slot_id):
		return false
	assignment_changed.emit(slot_id, &"")
	return true


func get_assigned(slot_id: StringName) -> StringName:
	return _slots.get(slot_id, &"")


func execute_slot(slot_id: StringName, context: Dictionary = {}) -> Error:
	var id: StringName = get_assigned(slot_id)
	if id == &"" or action_set == null:
		return ERR_DOES_NOT_EXIST
	if require_unlocked and (unlock_graph == null or unlock_graph.get_rank(id) < 1):
		return ERR_UNAVAILABLE
	return action_set.execute(id, context)


func capture_state() -> Dictionary:
	var slots: Dictionary = {}
	for id: StringName in _slots:
		slots[String(id)] = String(_slots[id])
	return {"slots": slots}


func restore_state(data: Dictionary) -> PackedStringArray:
	var rejected := PackedStringArray()
	var slots: Variant = data.get("slots", {})
	if not (slots is Dictionary):
		return PackedStringArray(["Invalid slots snapshot"])
	# Validate first: an invalid snapshot must never erase valid assignments.
	var candidate: Dictionary[StringName, StringName] = {}
	for key: Variant in slots:
		var slot_id := StringName(str(key))
		var action_id := StringName(str(slots[key]))
		if slot_id == &"" or action_id == &"":
			rejected.append(str(key))
			continue
		if action_set == null or not action_set.has_action(action_id):
			rejected.append(str(key))
			continue
		if require_unlocked and (
			unlock_graph == null or unlock_graph.get_rank(action_id) < 1
		):
			rejected.append(str(key))
			continue
		candidate[slot_id] = action_id
	if not rejected.is_empty():
		return rejected
	var previous: Dictionary[StringName, StringName] = _slots.duplicate()
	_slots = candidate
	for slot_id: StringName in previous:
		if not _slots.has(slot_id):
			assignment_changed.emit(slot_id, &"")
	for slot_id: StringName in _slots:
		if previous.get(slot_id, &"") != _slots[slot_id]:
			assignment_changed.emit(slot_id, _slots[slot_id])
	return rejected
