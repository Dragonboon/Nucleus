class_name NucleusLootState
extends RefCounted
## Runtime state for one logical loot-table owner.
##
## This keeps unique-entry consumption out of shared Resource assets.

var _consumed_unique: Dictionary[StringName, bool] = {}


func has_consumed(entry_id: StringName) -> bool:
	return (
		entry_id != &""
		and _consumed_unique.has(entry_id)
	)


func mark_consumed(entry_id: StringName) -> Error:
	if entry_id == &"":
		return ERR_INVALID_PARAMETER

	_consumed_unique[entry_id] = true
	return OK


func clear() -> void:
	_consumed_unique.clear()


func capture_state() -> Dictionary:
	var consumed: Array[String] = []

	for entry_id: StringName in _consumed_unique:
		consumed.append(String(entry_id))

	consumed.sort()

	return {
		"consumed_unique": consumed,
	}


func restore_state(data: Dictionary) -> void:
	_consumed_unique.clear()

	var stored: Variant = data.get(
		"consumed_unique",
		[],
	)

	if not stored is Array:
		return

	for value: Variant in stored:
		var entry_id := StringName(str(value))

		if entry_id != &"":
			_consumed_unique[entry_id] = true
