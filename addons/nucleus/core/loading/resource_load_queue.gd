class_name NucleusResourceLoadQueue
extends Node
## Scene-owned asynchronous resource batch loader.
##
## ResourceLoader remains authoritative for import, threading, dependency
## loading, and its native cache. This Node adds explicit plans, bounded
## concurrency, progress aggregation, retention, and observable lifecycle.

signal state_changed(state: int)
signal batch_started(plan: NucleusLoadPlan, total_items: int)
signal progress_changed(
	progress: float,
	processed_items: int,
	total_items: int,
)
signal item_started(entry: NucleusLoadEntry)
signal item_progress(entry: NucleusLoadEntry, progress: float)
signal item_completed(entry: NucleusLoadEntry, resource: Resource)
signal item_failed(entry: NucleusLoadEntry, error: Error)
signal batch_completed(plan: NucleusLoadPlan)
signal batch_failed(plan: NucleusLoadPlan, failures: Array[Dictionary])
signal batch_cancelled(plan: NucleusLoadPlan)

enum State {
	IDLE,
	RUNNING,
	CANCELLING,
	COMPLETED,
	FAILED,
	CANCELLED,
}

@export_range(1, 16, 1) var max_concurrent_requests: int = 2

var state: State = State.IDLE

var _plan: NucleusLoadPlan
var _pending: Array[Dictionary] = []
var _active: Dictionary = {}
var _retained: Dictionary = {}
var _failures: Array[Dictionary] = []
var _processed_items: int = 0
var _total_items: int = 0
var _settled_weight: float = 0.0
var _total_weight: float = 0.0
var _progress: float = 0.0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(_delta: float) -> void:
	match state:
		State.RUNNING:
			_poll_active_requests()
			_schedule_available_requests()
			_finish_if_settled()
		State.CANCELLING:
			_drain_cancelled_requests()
			_finish_if_settled()
		_:
			set_process(false)


func start(plan: NucleusLoadPlan) -> Error:
	if is_busy():
		return ERR_BUSY

	if not is_inside_tree():
		return ERR_UNCONFIGURED

	if plan == null:
		return ERR_INVALID_PARAMETER

	if not plan.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER

	_reset_batch_state()
	_plan = plan
	_total_items = plan.get_item_count()
	_total_weight = plan.get_total_weight()

	for index: int in range(plan.entries.size()):
		_pending.append({
			"entry": plan.entries[index],
			"index": index,
		})

	_pending.sort_custom(_request_precedes)
	_set_state(State.RUNNING)
	set_process(true)
	batch_started.emit(_plan, _total_items)
	_emit_progress(true)
	_schedule_available_requests()
	_finish_if_settled()
	return OK


func cancel() -> Error:
	if state != State.RUNNING:
		return ERR_UNAVAILABLE

	_pending.clear()
	_set_state(State.CANCELLING)
	set_process(true)
	_finish_if_settled()
	return OK


func is_busy() -> bool:
	return state in [State.RUNNING, State.CANCELLING]


func get_progress() -> float:
	return _progress


func get_processed_count() -> int:
	return _processed_items


func get_total_count() -> int:
	return _total_items


func get_pending_count() -> int:
	return _pending.size()


func get_active_count() -> int:
	return _active.size()


func get_failures() -> Array[Dictionary]:
	return _failures.duplicate(true)


func has_retained(path: String) -> bool:
	return _retained.has(path.strip_edges())


func get_retained(path: String) -> Resource:
	var normalized := path.strip_edges()
	return _retained.get(normalized) as Resource


func release_retained(path: String) -> bool:
	return _retained.erase(path.strip_edges())


func release_all_retained() -> void:
	_retained.clear()


func get_retained_count() -> int:
	return _retained.size()


func _schedule_available_requests() -> void:
	if not NucleusPlatform.supports_threads():
		if state == State.RUNNING and not _pending.is_empty():
			var request: Dictionary = _pending.pop_front()
			_start_request(request)
		return

	var capacity := maxi(max_concurrent_requests, 1)

	while (
		state == State.RUNNING
		and _active.size() < capacity
		and not _pending.is_empty()
	):
		var request: Dictionary = _pending.pop_front()
		_start_request(request)


func _start_request(request: Dictionary) -> void:
	var entry := request["entry"] as NucleusLoadEntry
	var normalized := entry.path.strip_edges()

	item_started.emit(entry)

	if _retained.has(normalized):
		_complete_request(request, _retained[normalized] as Resource)
		return

	if ResourceLoader.has_cached(normalized):
		var cached := ResourceLoader.get_cached_ref(normalized)

		if cached != null:
			_complete_request(request, cached)
			return

	if not ResourceLoader.exists(normalized, entry.type_hint):
		_fail_request(request, ERR_FILE_NOT_FOUND)
		return

	if not NucleusPlatform.supports_threads():
		var resource := ResourceLoader.load(
			normalized,
			entry.type_hint,
			ResourceLoader.CACHE_MODE_REUSE,
		)

		if resource == null:
			_fail_request(request, ERR_FILE_CANT_OPEN)
		else:
			_complete_request(request, resource)
		return

	var request_error := ResourceLoader.load_threaded_request(
		normalized,
		entry.type_hint,
		entry.use_sub_threads,
		ResourceLoader.CACHE_MODE_REUSE,
	)

	if request_error != OK:
		var existing_status := ResourceLoader.load_threaded_get_status(
			normalized
		)

		if existing_status not in [
			ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			ResourceLoader.THREAD_LOAD_LOADED,
		]:
			_fail_request(request, request_error)
			return

	request["progress"] = 0.0
	_active[normalized] = request


func _poll_active_requests() -> void:
	for path: String in _active.keys().duplicate():
		var request: Dictionary = _active[path]
		var entry := request["entry"] as NucleusLoadEntry
		var progress_values: Array = []
		var status := ResourceLoader.load_threaded_get_status(
			path,
			progress_values,
		)

		if not progress_values.is_empty():
			var previous := float(request.get("progress", 0.0))
			var item_value := clampf(float(progress_values[0]), 0.0, 1.0)
			request["progress"] = item_value
			_active[path] = request

			if not is_equal_approx(previous, item_value):
				item_progress.emit(entry, item_value)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path)
				_active.erase(path)

				if resource == null:
					_fail_request(request, ERR_FILE_CANT_OPEN)
				else:
					_complete_request(request, resource)
			ResourceLoader.THREAD_LOAD_FAILED:
				_active.erase(path)
				_fail_request(request, ERR_FILE_CANT_OPEN)
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_active.erase(path)
				_fail_request(request, ERR_FILE_UNRECOGNIZED)

	_emit_progress()


func _complete_request(
	request: Dictionary,
	resource: Resource,
) -> void:
	var entry := request["entry"] as NucleusLoadEntry
	var normalized := entry.path.strip_edges()

	if entry.retain:
		_retained[normalized] = resource

	_processed_items += 1
	_settled_weight += entry.weight
	item_completed.emit(entry, resource)
	_emit_progress()


func _fail_request(
	request: Dictionary,
	error: Error,
) -> void:
	var entry := request["entry"] as NucleusLoadEntry

	_processed_items += 1
	_settled_weight += entry.weight
	_failures.append({
		"path": entry.path.strip_edges(),
		"display_name": entry.get_display_name(),
		"error": error,
		"error_name": error_string(error),
		"required": entry.required,
	})
	item_failed.emit(entry, error)
	_emit_progress()


func _drain_cancelled_requests() -> void:
	for path: String in _active.keys().duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
				_active.erase(path)
			_:
				_active.erase(path)


func _finish_if_settled() -> void:
	if not _pending.is_empty() or not _active.is_empty():
		return

	if state == State.CANCELLING:
		var cancelled_plan := _plan
		_set_state(State.CANCELLED)
		set_process(false)
		batch_cancelled.emit(cancelled_plan)
		return

	if state != State.RUNNING:
		return

	_progress = 1.0
	progress_changed.emit(
		_progress,
		_processed_items,
		_total_items,
	)

	var completed_plan := _plan
	var required_failures := _get_required_failures()

	if required_failures.is_empty():
		_set_state(State.COMPLETED)
		set_process(false)
		batch_completed.emit(completed_plan)
	else:
		_set_state(State.FAILED)
		set_process(false)
		batch_failed.emit(
			completed_plan,
			required_failures,
		)


func _emit_progress(force: bool = false) -> void:
	var weighted := _settled_weight

	for request_value: Variant in _active.values():
		var request := request_value as Dictionary
		var entry := request["entry"] as NucleusLoadEntry
		weighted += entry.weight * clampf(
			float(request.get("progress", 0.0)),
			0.0,
			1.0,
		)

	var next_progress := (
		clampf(weighted / _total_weight, 0.0, 1.0)
		if _total_weight > 0.0
		else 0.0
	)

	if not force and is_equal_approx(next_progress, _progress):
		return

	_progress = next_progress
	progress_changed.emit(
		_progress,
		_processed_items,
		_total_items,
	)


func _get_required_failures() -> Array[Dictionary]:
	var required: Array[Dictionary] = []

	for failure: Dictionary in _failures:
		if bool(failure.get("required", false)):
			required.append(failure.duplicate(true))

	return required


func _request_precedes(
	left: Dictionary,
	right: Dictionary,
) -> bool:
	var left_entry := left["entry"] as NucleusLoadEntry
	var right_entry := right["entry"] as NucleusLoadEntry

	if left_entry.priority == right_entry.priority:
		return int(left["index"]) < int(right["index"])

	return left_entry.priority > right_entry.priority


func _reset_batch_state() -> void:
	_pending.clear()
	_active.clear()
	_failures.clear()
	_processed_items = 0
	_total_items = 0
	_settled_weight = 0.0
	_total_weight = 0.0
	_progress = 0.0
	_plan = null


func _set_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state
	state_changed.emit(state)
