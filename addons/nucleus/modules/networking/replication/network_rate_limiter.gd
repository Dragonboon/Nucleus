class_name NucleusNetworkRateLimiter
extends RefCounted
## Fixed-window per-peer rate limiter for server-side RPC admission.

var _windows: Dictionary = {}


func allow(
	peer_id: int,
	now_msec: int,
	limit: int,
	window_msec: int = 1000,
) -> bool:
	if peer_id <= 0 or now_msec < 0 or window_msec <= 0:
		return false

	if limit <= 0:
		return true

	var entry: Dictionary = _windows.get(
		peer_id,
		{},
	)
	var started: int = int(
		entry.get(
			"started",
			now_msec,
		)
	)
	var count: int = int(
		entry.get(
			"count",
			0,
		)
	)

	if (
		entry.is_empty()
		or now_msec < started
		or now_msec - started >= window_msec
	):
		_windows[peer_id] = {
			"started": now_msec,
			"count": 1,
		}
		return true

	if count >= limit:
		return false

	entry["count"] = count + 1
	_windows[peer_id] = entry
	return true


func reset_peer(peer_id: int) -> void:
	_windows.erase(peer_id)


func clear() -> void:
	_windows.clear()
