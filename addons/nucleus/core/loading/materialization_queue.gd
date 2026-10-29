class_name NucleusMaterializationQueue
extends Node
## Scene-owned queue for bounded incremental main-thread materialization.
##
## The queue can bound the number of job steps and elapsed CPU time per frame.
## A single job step must still be authored as bounded work.

signal job_enqueued(job_id: int, job: NucleusMaterializationJob)
signal job_started(job_id: int, job: NucleusMaterializationJob)
signal job_completed(
	job_id: int,
	job: NucleusMaterializationJob,
	result: Variant,
)
signal job_failed(
	job_id: int,
	job: NucleusMaterializationJob,
	error: Error,
)
signal job_cancelled(job_id: int, job: NucleusMaterializationJob)

@export_group("Budget")
@export_range(1, 1024, 1)
var max_steps_per_frame: int = 4
## Zero disables the elapsed-time bound.
@export_range(0, 1000000, 50, "or_greater")
var frame_budget_usec: int = 2000
@export var process_automatically: bool = true

var _entries: Array[Dictionary] = []
var _next_job_id: int = 1
var _last_pump_steps: int = 0
var _last_pump_usec: int = 0


func _ready() -> void:
	set_process(process_automatically)


func _process(_delta: float) -> void:
	pump()


func set_automatic_processing(enabled: bool) -> void:
	process_automatically = enabled
	set_process(enabled)


func enqueue(job: NucleusMaterializationJob) -> int:
	if job == null or job.is_terminal():
		return 0

	for entry: Dictionary in _entries:
		if entry["job"] == job:
			return 0

	var job_id := _next_job_id
	_next_job_id += 1

	if _next_job_id <= 0:
		_next_job_id = 1

	_entries.append({
		"id": job_id,
		"job": job,
	})
	job_enqueued.emit(job_id, job)
	return job_id


func cancel_job(job: NucleusMaterializationJob) -> Error:
	if job == null:
		return ERR_INVALID_PARAMETER

	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index]

		if entry["job"] != job:
			continue

		var job_id := int(entry["id"])
		_entries.remove_at(index)

		if job.is_terminal():
			_emit_terminal_job(job_id, job)
			return ERR_UNAVAILABLE

		var cancel_error: Error = job.cancel()

		if cancel_error != OK:
			return cancel_error

		job_cancelled.emit(job_id, job)
		return OK

	return ERR_DOES_NOT_EXIST


func cancel_all() -> void:
	while not _entries.is_empty():
		var entry: Dictionary = _entries.pop_front()
		var job_id := int(entry["id"])
		var job: NucleusMaterializationJob = entry["job"]

		if job.is_terminal():
			_emit_terminal_job(job_id, job)
			continue

		job.cancel()
		job_cancelled.emit(job_id, job)


func pump() -> void:
	_last_pump_steps = 0
	_last_pump_usec = 0

	if _entries.is_empty():
		return

	var started_usec := Time.get_ticks_usec()
	var step_limit := maxi(max_steps_per_frame, 1)

	while not _entries.is_empty():
		if _last_pump_steps >= step_limit:
			break

		if (
			frame_budget_usec > 0
			and _last_pump_steps > 0
			and Time.get_ticks_usec() - started_usec
			>= frame_budget_usec
		):
			break

		var entry: Dictionary = _entries.pop_front()
		var job_id := int(entry["id"])
		var job: NucleusMaterializationJob = entry["job"]

		if job == null:
			continue

		if job.is_terminal():
			_emit_terminal_job(job_id, job)
			continue

		var was_pending := (
			job.get_state()
			== NucleusMaterializationJob.State.PENDING
		)
		var step_error: Error = job.step()
		_last_pump_steps += 1

		if was_pending:
			job_started.emit(job_id, job)

		if job.is_terminal():
			_emit_terminal_job(job_id, job)
		elif step_error == OK:
			_entries.append(entry)

	_last_pump_usec = Time.get_ticks_usec() - started_usec


func get_pending_count() -> int:
	return _entries.size()


func has_job(job: NucleusMaterializationJob) -> bool:
	for entry: Dictionary in _entries:
		if entry["job"] == job:
			return true

	return false


func get_last_pump_steps() -> int:
	return _last_pump_steps


func get_last_pump_usec() -> int:
	return _last_pump_usec


func get_debug_snapshot() -> Dictionary:
	return {
		"pending_jobs": _entries.size(),
		"last_pump_steps": _last_pump_steps,
		"last_pump_usec": _last_pump_usec,
		"max_steps_per_frame": max_steps_per_frame,
		"frame_budget_usec": frame_budget_usec,
	}


func _emit_terminal_job(
	job_id: int,
	job: NucleusMaterializationJob,
) -> void:
	match job.get_state():
		NucleusMaterializationJob.State.COMPLETED:
			job_completed.emit(
				job_id,
				job,
				job.get_result(),
			)
		NucleusMaterializationJob.State.FAILED:
			job_failed.emit(
				job_id,
				job,
				job.get_error(),
			)
		NucleusMaterializationJob.State.CANCELLED:
			job_cancelled.emit(job_id, job)
