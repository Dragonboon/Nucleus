class_name NucleusWorldStreamLifecycle
extends Node
## Admission controller for game-owned world streaming decisions.
##
## The consuming game decides which stable region IDs are desired and in what
## load order. This component only bounds load/unload admission and tracks
## asynchronous lifecycle acknowledgements.

signal desired_regions_changed(region_ids: Array[StringName])
signal load_requested(
	region_id: StringName,
	request_token: int,
)
signal unload_requested(
	region_id: StringName,
	request_token: int,
)
signal request_cancelled(
	region_id: StringName,
	request_token: int,
	operation: int,
)
signal region_loaded(region_id: StringName)
signal region_unloaded(region_id: StringName)
signal request_failed(
	region_id: StringName,
	request_token: int,
	operation: int,
	error: Error,
)
signal region_state_changed(
	region_id: StringName,
	state: int,
)

enum Operation {
	LOAD,
	UNLOAD,
}

enum RegionState {
	UNLOADED,
	LOADING,
	LOADED,
	UNLOADING,
	LOAD_FAILED,
	UNLOAD_FAILED,
}

@export_group("Admission")
@export_range(1, 64, 1)
var max_load_requests_per_frame: int = 1
@export_range(1, 64, 1)
var max_unload_requests_per_frame: int = 2
@export var process_automatically: bool = true

var _desired_order: Array[StringName] = []
var _desired_lookup: Dictionary = {}
var _states: Dictionary = {}
var _resident_order: Array[StringName] = []
var _request_tokens: Dictionary = {}
var _next_request_token: int = 1


func _ready() -> void:
	set_process(process_automatically)


func _process(_delta: float) -> void:
	pump()


func set_automatic_processing(enabled: bool) -> void:
	process_automatically = enabled
	set_process(enabled)


func set_desired_regions(region_ids: Array) -> Error:
	var normalized: Array[StringName] = []
	var seen: Dictionary = {}

	for value: Variant in region_ids:
		if not value is String and not value is StringName:
			return ERR_INVALID_PARAMETER

		var region_id := StringName(str(value).strip_edges())

		if region_id == &"":
			return ERR_INVALID_PARAMETER

		if seen.has(region_id):
			continue

		seen[region_id] = true
		normalized.append(region_id)

	_desired_order = normalized
	_desired_lookup.clear()

	for region_id: StringName in _desired_order:
		_desired_lookup[region_id] = true

	desired_regions_changed.emit(_desired_order.duplicate())
	return OK


func get_desired_regions() -> Array[StringName]:
	return _desired_order.duplicate()


func get_region_state(region_id: StringName) -> int:
	return int(_states.get(region_id, RegionState.UNLOADED))


func get_resident_regions() -> Array[StringName]:
	var result: Array[StringName] = []

	for region_id: StringName in _resident_order:
		var state := get_region_state(region_id)

		if state in [
			RegionState.LOADED,
			RegionState.UNLOADING,
			RegionState.UNLOAD_FAILED,
		]:
			result.append(region_id)

	return result


func get_request_token(region_id: StringName) -> int:
	return int(_request_tokens.get(region_id, 0))


func is_desired(region_id: StringName) -> bool:
	return _desired_lookup.has(region_id)


func is_settled() -> bool:
	for region_id: StringName in _desired_order:
		if get_region_state(region_id) != RegionState.LOADED:
			return false

	for region_id: StringName in _resident_order:
		if not is_desired(region_id):
			return false

	for state_value: Variant in _states.values():
		var state := int(state_value)

		if state in [
			RegionState.LOADING,
			RegionState.UNLOADING,
			RegionState.LOAD_FAILED,
			RegionState.UNLOAD_FAILED,
		]:
			return false

	return true


func pump() -> void:
	_admit_unloads()
	_admit_loads()


func register_loaded_region(region_id: StringName) -> Error:
	if region_id == &"":
		return ERR_INVALID_PARAMETER

	if get_region_state(region_id) != RegionState.UNLOADED:
		return ERR_ALREADY_EXISTS

	_mark_resident(region_id)
	_set_state(region_id, RegionState.LOADED)
	region_loaded.emit(region_id)
	return OK


func mark_loaded(
	region_id: StringName,
	request_token: int,
) -> Error:
	if not _matches_request(
		region_id,
		request_token,
		RegionState.LOADING,
	):
		return ERR_UNAVAILABLE

	_clear_request_token(region_id)
	_mark_resident(region_id)
	_set_state(region_id, RegionState.LOADED)
	region_loaded.emit(region_id)
	return OK


func mark_unloaded(
	region_id: StringName,
	request_token: int,
) -> Error:
	if not _matches_request(
		region_id,
		request_token,
		RegionState.UNLOADING,
	):
		return ERR_UNAVAILABLE

	_clear_request_token(region_id)
	_resident_order.erase(region_id)
	_set_state(region_id, RegionState.UNLOADED)
	region_unloaded.emit(region_id)
	return OK


func cancel_request(
	region_id: StringName,
	request_token: int,
) -> Error:
	var state := get_region_state(region_id)
	var operation: int

	match state:
		RegionState.LOADING:
			operation = Operation.LOAD
		RegionState.UNLOADING:
			operation = Operation.UNLOAD
		_:
			return ERR_UNAVAILABLE

	if not _matches_request(
		region_id,
		request_token,
		state,
	):
		return ERR_UNAVAILABLE

	_clear_request_token(region_id)

	if operation == Operation.LOAD:
		_set_state(region_id, RegionState.UNLOADED)
	else:
		_set_state(region_id, RegionState.LOADED)

	request_cancelled.emit(
		region_id,
		request_token,
		operation,
	)
	return OK


func mark_request_failed(
	region_id: StringName,
	request_token: int,
	operation: int,
	error: Error = FAILED,
) -> Error:
	var expected_state := (
		RegionState.LOADING
		if operation == Operation.LOAD
		else RegionState.UNLOADING
	)

	if operation not in [Operation.LOAD, Operation.UNLOAD]:
		return ERR_INVALID_PARAMETER

	if not _matches_request(
		region_id,
		request_token,
		expected_state,
	):
		return ERR_UNAVAILABLE

	var failed_state := (
		RegionState.LOAD_FAILED
		if operation == Operation.LOAD
		else RegionState.UNLOAD_FAILED
	)
	_clear_request_token(region_id)
	_set_state(region_id, failed_state)
	request_failed.emit(
		region_id,
		request_token,
		operation,
		error,
	)
	return OK


func retry_region(region_id: StringName) -> Error:
	var state := get_region_state(region_id)

	match state:
		RegionState.LOAD_FAILED:
			_set_state(region_id, RegionState.UNLOADED)
		RegionState.UNLOAD_FAILED:
			_set_state(region_id, RegionState.LOADED)
		_:
			return ERR_UNAVAILABLE

	return OK


func get_debug_snapshot() -> Dictionary:
	var loading := 0
	var unloading := 0
	var load_failures := 0
	var unload_failures := 0

	for state_value: Variant in _states.values():
		match int(state_value):
			RegionState.LOADING:
				loading += 1
			RegionState.UNLOADING:
				unloading += 1
			RegionState.LOAD_FAILED:
				load_failures += 1
			RegionState.UNLOAD_FAILED:
				unload_failures += 1

	return {
		"desired": _desired_order.size(),
		"resident": get_resident_regions().size(),
		"loading": loading,
		"unloading": unloading,
		"load_failures": load_failures,
		"unload_failures": unload_failures,
		"settled": is_settled(),
	}


func _admit_unloads() -> void:
	var admitted := 0

	for region_id: StringName in _resident_order.duplicate():
		if admitted >= max_unload_requests_per_frame:
			break

		if is_desired(region_id):
			continue

		if get_region_state(region_id) != RegionState.LOADED:
			continue

		var request_token := _begin_request(
			region_id,
			RegionState.UNLOADING,
		)
		unload_requested.emit(region_id, request_token)
		admitted += 1


func _admit_loads() -> void:
	var admitted := 0

	for region_id: StringName in _desired_order:
		if admitted >= max_load_requests_per_frame:
			break

		if get_region_state(region_id) != RegionState.UNLOADED:
			continue

		var request_token := _begin_request(
			region_id,
			RegionState.LOADING,
		)
		load_requested.emit(region_id, request_token)
		admitted += 1


func _begin_request(
	region_id: StringName,
	state: int,
) -> int:
	var request_token := _next_request_token
	_next_request_token += 1

	if _next_request_token <= 0:
		_next_request_token = 1

	_request_tokens[region_id] = request_token
	_set_state(region_id, state)
	return request_token


func _matches_request(
	region_id: StringName,
	request_token: int,
	expected_state: int,
) -> bool:
	return (
		request_token > 0
		and get_region_state(region_id) == expected_state
		and get_request_token(region_id) == request_token
	)


func _clear_request_token(region_id: StringName) -> void:
	_request_tokens.erase(region_id)


func _mark_resident(region_id: StringName) -> void:
	if not _resident_order.has(region_id):
		_resident_order.append(region_id)


func _set_state(
	region_id: StringName,
	state: int,
) -> void:
	var previous := get_region_state(region_id)

	if previous == state:
		return

	if state == RegionState.UNLOADED:
		_states.erase(region_id)
	else:
		_states[region_id] = state

	region_state_changed.emit(region_id, state)
