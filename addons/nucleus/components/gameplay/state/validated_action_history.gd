class_name NucleusValidatedActionHistory
extends RefCounted
## Bounded data-snapshot undo/redo with game-validated restoration.
## This does not apply states. The consumer validates/restores a preview before
## confirming its ticket. Prefer Godot UndoRedo for reversible commands.

var max_actions: int = 20
var max_snapshot_bytes: int = 2097152
var max_snapshot_items: int = 10000

var _entries: Array[Dictionary] = []
var _cursor: int = 0
var _next_ticket: int = 1
var _pending: Dictionary = {}


func clear() -> void:
	_entries.clear()
	_cursor = 0
	_invalidate_pending()


func record(before: Dictionary, after: Dictionary, label: StringName) -> Error:
	if label == &"" or max_actions < 1 or max_snapshot_bytes < 1:
		return ERR_INVALID_PARAMETER
	if max_snapshot_items < 1:
		return ERR_INVALID_PARAMETER
	if not _accepts_snapshot(before) or not _accepts_snapshot(after):
		return ERR_INVALID_DATA
	if before == after:
		return ERR_ALREADY_EXISTS

	_invalidate_pending()
	while _entries.size() > _cursor:
		_entries.pop_back()
	_entries.append({
		"before": before.duplicate(true),
		"after": after.duplicate(true),
		"label": label,
	})
	_cursor += 1
	while _entries.size() > max_actions:
		_entries.pop_front()
		_cursor -= 1
	return OK


func can_undo() -> bool:
	return _cursor > 0


func can_redo() -> bool:
	return _cursor < _entries.size()


func undo_count() -> int:
	return _cursor


func redo_count() -> int:
	return _entries.size() - _cursor


func peek_undo() -> Dictionary:
	if not can_undo():
		_invalidate_pending()
		return {}
	return _prepare(-1, _entries[_cursor - 1])


func peek_redo() -> Dictionary:
	if not can_redo():
		_invalidate_pending()
		return {}
	return _prepare(1, _entries[_cursor])


func confirm_undo(ticket: int) -> Error:
	return _confirm(ticket, -1)


func confirm_redo(ticket: int) -> Error:
	return _confirm(ticket, 1)


func cancel_preview() -> void:
	_invalidate_pending()


func _prepare(direction: int, entry: Dictionary) -> Dictionary:
	_invalidate_pending()
	var ticket := _next_ticket
	_next_ticket += 1
	_pending = {"ticket": ticket, "direction": direction, "cursor": _cursor}
	var snapshot: Dictionary = entry["before"] if direction < 0 else entry["after"]
	return {
		"ticket": ticket,
		"label": entry["label"],
		"snapshot": snapshot.duplicate(true),
	}


func _confirm(ticket: int, direction: int) -> Error:
	if ticket <= 0 or _pending.is_empty():
		return ERR_UNAVAILABLE
	if (
		int(_pending["ticket"]) != ticket
		or int(_pending["direction"]) != direction
		or int(_pending["cursor"]) != _cursor
	):
		return ERR_UNAVAILABLE
	if (direction < 0 and not can_undo()) or (direction > 0 and not can_redo()):
		return ERR_UNAVAILABLE
	_cursor += direction
	_invalidate_pending()
	return OK


func _invalidate_pending() -> void:
	_pending.clear()


func _accepts_snapshot(snapshot: Dictionary) -> bool:
	var remaining: Array[int] = [max_snapshot_items]
	if not _is_data_value(snapshot, 0, remaining):
		return false
	return var_to_bytes(snapshot).size() <= max_snapshot_bytes


func _is_data_value(value: Variant, depth: int, remaining: Array[int]) -> bool:
	remaining[0] -= 1
	if remaining[0] < 0 or depth > 16:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]:
				return false
			if not _is_data_value(value[key], depth + 1, remaining):
				return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _is_data_value(item, depth + 1, remaining):
				return false
		return true
	return typeof(value) in [
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
		TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I,
		TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I,
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D,
		TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS, TYPE_COLOR,
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY,
	]
