class_name NucleusNetworkSequenceTracker
extends RefCounted
## Monotonic per-peer/per-stream sequence validation.
##
## Sequences start at 1. They intentionally do not wrap; signed 64-bit GDScript
## integers make practical session exhaustion irrelevant.

var _last_by_peer: Dictionary = {}


func accept(
	peer_id: int,
	stream_id: StringName,
	sequence: int,
) -> bool:
	if peer_id <= 0 or stream_id == &"" or sequence <= 0:
		return false

	var streams: Dictionary = _last_by_peer.get(
		peer_id,
		{},
	)
	var previous: int = int(
		streams.get(
			stream_id,
			0,
		)
	)

	if sequence <= previous:
		return false

	streams[stream_id] = sequence
	_last_by_peer[peer_id] = streams
	return true


func get_last(
	peer_id: int,
	stream_id: StringName,
) -> int:
	var streams: Dictionary = _last_by_peer.get(
		peer_id,
		{},
	)
	return int(
		streams.get(
			stream_id,
			0,
		)
	)


func reset_peer(peer_id: int) -> void:
	_last_by_peer.erase(peer_id)


func clear() -> void:
	_last_by_peer.clear()
