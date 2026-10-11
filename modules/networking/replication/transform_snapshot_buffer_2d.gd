class_name NucleusTransformSnapshotBuffer2D
extends RefCounted
## Bounded transform history ordered by sequence and local arrival time.
## Example: push(sequence, now, position, angle), then sample(now - delay).
## Invalid data is rejected without consuming a sequence. clear() starts a new
## stream; call it for an intentional session reset, not to bypass admission.

var capacity: int = 32
var _latest_sequence: int = 0
var _snapshots: Array[Dictionary] = []


func push(
	sequence: int,
	received_time: float,
	position: Vector2,
	rotation: float,
) -> bool:
	if (
		sequence <= _latest_sequence or not is_finite(received_time) or received_time < 0.0
		or not position.is_finite() or not is_finite(rotation)
	):
		return false
	if not _snapshots.is_empty() and received_time < float(_snapshots.back()["time"]):
		return false

	_latest_sequence = sequence
	_snapshots.append(
		{
			"sequence": sequence,
			"time": received_time,
			"position": position,
			"rotation": rotation,
		}
	)

	while _snapshots.size() > maxi(
		2,
		capacity,
	):
		_snapshots.pop_front()

	return true


func sample(sample_time: float) -> Dictionary:
	if not is_finite(sample_time) or _snapshots.is_empty():
		return {}

	while (
		_snapshots.size() > 2
		and float(_snapshots[1]["time"]) <= sample_time
	):
		_snapshots.pop_front()

	if _snapshots.size() == 1:
		return _snapshots[0].duplicate()

	var first: Dictionary = _snapshots[0]
	var second: Dictionary = _snapshots[1]
	var first_time: float = float(first["time"])
	var second_time: float = float(second["time"])

	if sample_time <= first_time:
		return first.duplicate()

	if sample_time >= second_time:
		return second.duplicate()

	var duration: float = second_time - first_time

	if duration <= 0.000001:
		return second.duplicate()

	var weight: float = clampf(
		(sample_time - first_time) / duration,
		0.0,
		1.0,
	)

	var first_position: Vector2 = first["position"]
	var second_position: Vector2 = second["position"]

	return {
		"sequence": int(second["sequence"]),
		"time": sample_time,
		"position": first_position.lerp(
			second_position,
			weight,
		),
		"rotation": lerp_angle(
			float(first["rotation"]),
			float(second["rotation"]),
			weight,
		),
	}


func clear() -> void:
	_snapshots.clear()
	_latest_sequence = 0


func get_count() -> int:
	return _snapshots.size()


func get_latest_sequence() -> int:
	return _latest_sequence
