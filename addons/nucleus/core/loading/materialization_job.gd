class_name NucleusMaterializationJob
extends RefCounted
## One bounded, incremental main-thread materialization job.
##
## Subclasses implement _step_job() and should keep each step small enough for
## NucleusMaterializationQueue to enforce its budget between steps.

signal started
signal progress_changed(processed_units: int, total_units: int)
signal completed(result: Variant)
signal failed(error: Error)
signal cancelled

enum State {
	PENDING,
	RUNNING,
	COMPLETED,
	FAILED,
	CANCELLED,
}

var _state: int = State.PENDING
var _processed_units: int = 0
var _total_units: int = 0
var _result: Variant
var _error: Error = OK


func step() -> Error:
	if _state in [
		State.COMPLETED,
		State.FAILED,
		State.CANCELLED,
	]:
		return ERR_UNAVAILABLE

	if _state == State.PENDING:
		_state = State.RUNNING
		started.emit()

	var step_error: Error = _step_job()

	if step_error != OK and _state == State.RUNNING:
		fail(step_error)

	return step_error


func cancel() -> Error:
	if _state in [
		State.COMPLETED,
		State.FAILED,
		State.CANCELLED,
	]:
		return ERR_UNAVAILABLE

	_state = State.CANCELLED
	cancelled.emit()
	return OK


func complete(result: Variant = null) -> Error:
	if _state != State.RUNNING:
		return ERR_UNAVAILABLE

	_result = result
	_state = State.COMPLETED

	if _total_units > 0:
		_processed_units = _total_units
		progress_changed.emit(
			_processed_units,
			_total_units,
		)

	completed.emit(_result)
	return OK


func fail(error: Error = FAILED) -> Error:
	if _state not in [State.PENDING, State.RUNNING]:
		return ERR_UNAVAILABLE

	_error = error if error != OK else FAILED
	_state = State.FAILED
	failed.emit(_error)
	return OK


func set_progress(
	processed_units: int,
	total_units: int,
) -> void:
	var safe_total := maxi(total_units, 0)
	var safe_processed := maxi(processed_units, 0)

	if safe_total > 0:
		safe_processed = mini(safe_processed, safe_total)

	if (
		_processed_units == safe_processed
		and _total_units == safe_total
	):
		return

	_processed_units = safe_processed
	_total_units = safe_total
	progress_changed.emit(
		_processed_units,
		_total_units,
	)


func advance_progress(units: int = 1) -> void:
	set_progress(
		_processed_units + maxi(units, 0),
		_total_units,
	)


func get_state() -> int:
	return _state


func get_processed_units() -> int:
	return _processed_units


func get_total_units() -> int:
	return _total_units


func get_progress_ratio() -> float:
	if _total_units <= 0:
		return 0.0

	return clampf(
		float(_processed_units) / float(_total_units),
		0.0,
		1.0,
	)


func get_result() -> Variant:
	return _result


func get_error() -> Error:
	return _error


func is_terminal() -> bool:
	return _state in [
		State.COMPLETED,
		State.FAILED,
		State.CANCELLED,
	]


func _step_job() -> Error:
	complete()
	return OK
