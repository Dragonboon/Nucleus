class_name NucleusNetworkClockSync
extends RefCounted
## Client-side four-timestamp clock estimator, independent of transport/RPC.
## Time.get_ticks_usec() defines BOTH local and remote clock domains.
## This class never establishes server identity or session authorization.

signal session_reset(session_id: int)
signal sample_accepted(offset_seconds: float, round_trip_seconds: float)
signal sample_rejected(reason: StringName)

const USEC_PER_SEC: float = 1000000.0
const USEC_PER_MSEC: float = 1000.0

var profile: NucleusNetworkClockSyncProfile

var _session_id: int = 0
var _next_request_id: int = 0
var _pending: Dictionary = {}
var _recent_rtts_usec: Array[int] = []
var _has_sample: bool = false
var _offset_usec: float = 0.0
var _last_rtt_usec: int = -1
var _last_sample_local_usec: int = -1
var _sample_count: int = 0


func _init(sync_profile: NucleusNetworkClockSyncProfile = null) -> void:
	if sync_profile == null:
		profile = NucleusNetworkClockSyncProfile.new()
	else:
		profile = sync_profile.duplicate(true) as NucleusNetworkClockSyncProfile


## Call on first connection, reconnection, explicit logout or server switch.
## An old response cannot update a new session, even with a reused request ID.
func begin_session() -> int:
	_session_id += 1
	_next_request_id = 0
	_pending.clear()
	_recent_rtts_usec.clear()
	_has_sample = false
	_offset_usec = 0.0
	_last_rtt_usec = -1
	_last_sample_local_usec = -1
	_sample_count = 0
	session_reset.emit(_session_id)
	return _session_id


## Builds a ticket for a game-owned RPC. The local timestamp stays local.
## An empty Dictionary means no active session, invalid profile or full queue.
func create_request(local_send_usec: int = -1) -> Dictionary:
	if _session_id <= 0 or not _profile_valid():
		return {}

	var now_usec: int = _resolve_now(local_send_usec)
	if now_usec < 0:
		return {}

	_prune_expired_requests(now_usec)
	if _pending.size() >= profile.max_pending_requests:
		return {}

	_next_request_id += 1
	_pending[_next_request_id] = now_usec
	return {
		"session_id": _session_id,
		"request_id": _next_request_id,
	}


## Complete an echoed ticket using server-owned receive/send timestamps.
## Calculation: offset = ((server_recv - client_send)
##                      + (server_send - client_recv)) / 2
## network RTT = (client_recv - client_send) - (server_send - server_recv)
func accept_response(
	session_id: int,
	request_id: int,
	server_receive_usec: int,
	server_send_usec: int,
	local_receive_usec: int = -1,
) -> bool:
	if session_id != _session_id or request_id <= 0 or not _pending.has(request_id):
		return _reject(&"unknown_or_stale_ticket")

	# Remove the ticket before checks: duplicates and malformed replies cannot retry.
	var local_send_usec: int = int(_pending[request_id])
	_pending.erase(request_id)

	if not _profile_valid():
		return _reject(&"invalid_profile")

	var local_now_usec: int = _resolve_now(local_receive_usec)
	if (
		local_now_usec < local_send_usec
		or server_receive_usec < 0
		or server_send_usec < server_receive_usec
	):
		return _reject(&"invalid_timestamps")

	var elapsed_local_usec: int = local_now_usec - local_send_usec
	var server_processing_usec: int = server_send_usec - server_receive_usec
	if elapsed_local_usec > _request_timeout_usec():
		return _reject(&"expired_ticket")
	if server_processing_usec > _milliseconds_to_usec(profile.max_server_processing_ms):
		return _reject(&"server_processing_limit")
	if server_processing_usec > elapsed_local_usec:
		return _reject(&"invalid_timestamps")

	var round_trip_usec: int = elapsed_local_usec - server_processing_usec
	if round_trip_usec > _milliseconds_to_usec(profile.max_rtt_ms):
		return _reject(&"rtt_limit")

	var had_fresh_sample: bool = is_synchronized(local_now_usec)
	if not had_fresh_sample:
		_recent_rtts_usec.clear()

	if not _recent_rtts_usec.is_empty():
		var best_rtt_usec: int = int(_recent_rtts_usec.min())
		var extra_usec: int = _milliseconds_to_usec(profile.outlier_tolerance_ms)
		if round_trip_usec > best_rtt_usec + extra_usec:
			return _reject(&"rtt_outlier")

	var offset_sample_usec: float = (
		float(server_receive_usec - local_send_usec)
		+ float(server_send_usec - local_now_usec)
	) * 0.5

	# Never smooth from an estimate already declared stale.
	if not had_fresh_sample:
		_offset_usec = offset_sample_usec
	else:
		_offset_usec = lerpf(
			_offset_usec,
			offset_sample_usec,
			profile.smoothing_factor,
		)

	_recent_rtts_usec.append(round_trip_usec)
	while _recent_rtts_usec.size() > profile.rtt_window_size:
		_recent_rtts_usec.remove_at(0)

	_last_rtt_usec = round_trip_usec
	_last_sample_local_usec = local_now_usec
	_has_sample = true
	_sample_count += 1
	sample_accepted.emit(_offset_usec / USEC_PER_SEC, float(round_trip_usec) / USEC_PER_SEC)
	return true


## Returns false if no sample is available or the last estimate has expired.
func is_synchronized(local_now_usec: int = -1) -> bool:
	if not _has_valid_sample():
		return false
	var now_usec: int = _resolve_now(local_now_usec)
	if now_usec < _last_sample_local_usec:
		return false
	return now_usec - _last_sample_local_usec <= (
		_milliseconds_to_usec(profile.stale_after_seconds * 1000.0)
	)


## Returns server monotonic microseconds in the SERVER's boot-time domain.
## -1 indicates unavailable/stale; NEVER interpret this as Unix epoch time.
func get_server_ticks_usec(local_now_usec: int = -1) -> int:
	var now_usec: int = _resolve_now(local_now_usec)
	if not is_synchronized(now_usec):
		return -1
	return maxi(0, int(round(float(now_usec) + _offset_usec)))


func get_server_ticks_seconds(local_now_usec: int = -1) -> float:
	var estimated_usec: int = get_server_ticks_usec(local_now_usec)
	if estimated_usec < 0:
		return -1.0
	return float(estimated_usec) / USEC_PER_SEC


func get_offset_seconds() -> float:
	return _offset_usec / USEC_PER_SEC if _has_sample else 0.0


func get_round_trip_seconds() -> float:
	return float(_last_rtt_usec) / USEC_PER_SEC if _last_rtt_usec >= 0 else -1.0


func get_sample_count() -> int:
	return _sample_count


func get_session_id() -> int:
	return _session_id


func get_pending_request_count() -> int:
	return _pending.size()


func _has_valid_sample() -> bool:
	return _has_sample and _profile_valid()


func _resolve_now(explicit_usec: int) -> int:
	return Time.get_ticks_usec() if explicit_usec == -1 else explicit_usec


func _milliseconds_to_usec(milliseconds: float) -> int:
	return int(round(milliseconds * USEC_PER_MSEC))


func _request_timeout_usec() -> int:
	return _milliseconds_to_usec(profile.request_timeout_seconds * 1000.0)


func _prune_expired_requests(now_usec: int) -> void:
	var timeout_usec: int = _request_timeout_usec()
	for key: Variant in _pending.keys():
		var created_usec: int = int(_pending[key])
		if now_usec < created_usec or now_usec - created_usec > timeout_usec:
			_pending.erase(key)


func _profile_valid() -> bool:
	return profile != null and profile.get_validation_errors().is_empty()


func _reject(reason: StringName) -> bool:
	sample_rejected.emit(reason)
	return false
