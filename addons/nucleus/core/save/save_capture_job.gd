class_name NucleusSaveCaptureJob
extends RefCounted
## Incremental main-thread capture over one stable SaveSession participant set.
##
## The job snapshots participant IDs/callbacks at creation time. step() captures
## only a bounded number of participants, allowing a game or SaveSession helper
## to distribute capture work across frames without moving Node access to a
## worker thread.

signal progress_changed(processed: int, total: int)
signal completed

var _entries: Array[Dictionary] = []
var _index: int = 0
var _snapshot: Dictionary = {}
var _completed_emitted: bool = false


func _init(participants: Dictionary) -> void:
	for raw_id: Variant in participants:
		var participant: Dictionary = participants[raw_id]
		var capture: Callable = participant["capture"]

		_entries.append({
			"id": StringName(str(raw_id)),
			"capture": capture,
		})


## Captures at most max_participants entries and returns the number attempted.
func step(max_participants: int = 1) -> int:
	if max_participants <= 0 or is_completed():
		return 0

	var captured: int = 0
	var limit: int = mini(
		_entries.size(),
		_index + max_participants,
	)

	while _index < limit:
		var entry: Dictionary = _entries[_index]
		var participant_id: StringName = entry["id"]
		var capture: Callable = entry["capture"]

		if capture.is_valid():
			_snapshot[String(participant_id)] = capture.call()

		_index += 1
		captured += 1

	progress_changed.emit(_index, _entries.size())

	if is_completed() and not _completed_emitted:
		_completed_emitted = true
		completed.emit()

	return captured


func get_processed_count() -> int:
	return _index


func get_total_count() -> int:
	return _entries.size()


func is_completed() -> bool:
	return _index >= _entries.size()


## Transfers the completed snapshot without deep-copying it. The job becomes
## empty after a successful take. Calling before completion returns an empty map.
func take_snapshot() -> Dictionary:
	if not is_completed():
		return {}

	var result: Dictionary = _snapshot
	_snapshot = {}
	return result
