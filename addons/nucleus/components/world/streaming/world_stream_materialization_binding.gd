class_name NucleusWorldStreamMaterializationBinding
extends Node
## Optional bridge between world-stream request tokens and materialization jobs.
##
## The game still decides what a region means and constructs the actual jobs.

signal stale_completion_ignored(
	region_id: StringName,
	request_token: int,
	operation: int,
)

@export var lifecycle: NucleusWorldStreamLifecycle
@export var queue: NucleusMaterializationQueue
@export var cancel_stale_requests: bool = true

var _tracked_jobs: Dictionary = {}


func _ready() -> void:
	_connect_dependencies()


func _exit_tree() -> void:
	_disconnect_dependencies()


func submit_job(
	region_id: StringName,
	request_token: int,
	operation: int,
	job: NucleusMaterializationJob,
) -> Error:
	if lifecycle == null or queue == null:
		return ERR_UNCONFIGURED

	if region_id == &"" or request_token <= 0 or job == null:
		return ERR_INVALID_PARAMETER

	if operation not in [
		NucleusWorldStreamLifecycle.Operation.LOAD,
		NucleusWorldStreamLifecycle.Operation.UNLOAD,
	]:
		return ERR_INVALID_PARAMETER

	var expected_state := (
		NucleusWorldStreamLifecycle.RegionState.LOADING
		if operation == NucleusWorldStreamLifecycle.Operation.LOAD
		else NucleusWorldStreamLifecycle.RegionState.UNLOADING
	)

	if (
		lifecycle.get_region_state(region_id) != expected_state
		or lifecycle.get_request_token(region_id) != request_token
	):
		return ERR_UNAVAILABLE

	for entry_value: Variant in _tracked_jobs.values():
		var entry: Dictionary = entry_value

		if (
			StringName(entry["region_id"]) == region_id
			and int(entry["request_token"]) == request_token
		):
			return ERR_ALREADY_EXISTS

	var job_id := queue.enqueue(job)

	if job_id <= 0:
		return ERR_CANT_CREATE

	_tracked_jobs[job_id] = {
		"job": job,
		"region_id": region_id,
		"request_token": request_token,
		"operation": operation,
	}
	return OK


func get_tracked_job_count() -> int:
	return _tracked_jobs.size()


func cancel_region_request(
	region_id: StringName,
	request_token: int,
) -> Error:
	for job_id_value: Variant in _tracked_jobs.keys():
		var job_id := int(job_id_value)
		var entry: Dictionary = _tracked_jobs[job_id]

		if (
			StringName(entry["region_id"]) != region_id
			or int(entry["request_token"]) != request_token
		):
			continue

		var job: NucleusMaterializationJob = entry["job"]
		return queue.cancel_job(job)

	return ERR_DOES_NOT_EXIST


func _connect_dependencies() -> void:
	if lifecycle != null:
		if (
			not lifecycle.desired_regions_changed.is_connected(
				_on_desired_regions_changed
			)
		):
			lifecycle.desired_regions_changed.connect(
				_on_desired_regions_changed
			)

	if queue != null:
		if not queue.job_completed.is_connected(_on_job_completed):
			queue.job_completed.connect(_on_job_completed)

		if not queue.job_failed.is_connected(_on_job_failed):
			queue.job_failed.connect(_on_job_failed)

		if not queue.job_cancelled.is_connected(_on_job_cancelled):
			queue.job_cancelled.connect(_on_job_cancelled)


func _disconnect_dependencies() -> void:
	if lifecycle != null:
		if lifecycle.desired_regions_changed.is_connected(
			_on_desired_regions_changed
		):
			lifecycle.desired_regions_changed.disconnect(
				_on_desired_regions_changed
			)

	if queue != null:
		if queue.job_completed.is_connected(_on_job_completed):
			queue.job_completed.disconnect(_on_job_completed)

		if queue.job_failed.is_connected(_on_job_failed):
			queue.job_failed.disconnect(_on_job_failed)

		if queue.job_cancelled.is_connected(_on_job_cancelled):
			queue.job_cancelled.disconnect(_on_job_cancelled)


func _on_desired_regions_changed(
	_region_ids: Array[StringName],
) -> void:
	if not cancel_stale_requests or lifecycle == null or queue == null:
		return

	for job_id_value: Variant in _tracked_jobs.keys().duplicate():
		var job_id := int(job_id_value)
		var entry: Dictionary = _tracked_jobs.get(job_id, {})
		var region_id: StringName = StringName(entry.get("region_id", &""))
		var operation: int = int(entry.get("operation", -1))
		var is_stale := (
			operation == NucleusWorldStreamLifecycle.Operation.LOAD
			and not lifecycle.is_desired(region_id)
		) or (
			operation == NucleusWorldStreamLifecycle.Operation.UNLOAD
			and lifecycle.is_desired(region_id)
		)

		if not is_stale:
			continue

		var job: NucleusMaterializationJob = entry.get("job")

		if job != null:
			queue.cancel_job(job)


func _on_job_completed(
	job_id: int,
	_job: NucleusMaterializationJob,
	_result: Variant,
) -> void:
	var entry := _take_entry(job_id)

	if entry.is_empty() or lifecycle == null:
		return

	var region_id := StringName(entry["region_id"])
	var request_token := int(entry["request_token"])
	var operation := int(entry["operation"])
	var completion_error: Error

	if operation == NucleusWorldStreamLifecycle.Operation.LOAD:
		completion_error = lifecycle.mark_loaded(
			region_id,
			request_token,
		)
	else:
		completion_error = lifecycle.mark_unloaded(
			region_id,
			request_token,
		)

	if completion_error == ERR_UNAVAILABLE:
		stale_completion_ignored.emit(
			region_id,
			request_token,
			operation,
		)


func _on_job_failed(
	job_id: int,
	_job: NucleusMaterializationJob,
	error: Error,
) -> void:
	var entry := _take_entry(job_id)

	if entry.is_empty() or lifecycle == null:
		return

	var region_id := StringName(entry["region_id"])
	var request_token := int(entry["request_token"])
	var operation := int(entry["operation"])
	var mark_error: Error = lifecycle.mark_request_failed(
		region_id,
		request_token,
		operation,
		error,
	)

	if mark_error == ERR_UNAVAILABLE:
		stale_completion_ignored.emit(
			region_id,
			request_token,
			operation,
		)


func _on_job_cancelled(
	job_id: int,
	_job: NucleusMaterializationJob,
) -> void:
	var entry := _take_entry(job_id)

	if entry.is_empty() or lifecycle == null:
		return

	var region_id := StringName(entry["region_id"])
	var request_token := int(entry["request_token"])
	var operation := int(entry["operation"])
	var cancel_error: Error = lifecycle.cancel_request(
		region_id,
		request_token,
	)

	if cancel_error == ERR_UNAVAILABLE:
		stale_completion_ignored.emit(
			region_id,
			request_token,
			operation,
		)


func _take_entry(job_id: int) -> Dictionary:
	if not _tracked_jobs.has(job_id):
		return {}

	var entry: Dictionary = _tracked_jobs[job_id]
	_tracked_jobs.erase(job_id)
	return entry
