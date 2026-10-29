class_name NucleusPlacementBrush3D
extends RefCounted
## Pure cursor-stroke spacing and bounded jitter. Does NOT instantiate scenes,
## raycast, move nodes, decide validity, or persist changes.
## Consumers submit each candidate to NucleusPlacementSession3D.

var spacing: float = 1.5
var radius: float = 0.0
var max_candidates: int = 64

var _active: bool = false
var _last: Vector3 = Vector3.ZERO
var _distance_from_stamp: float = 0.0
var _produced: int = 0
var _random := RandomNumberGenerator.new()


func begin(step: float, spread: float = 0.0, limit: int = 64, seed_value: int = 1) -> Error:
	if not is_finite(step) or not is_finite(spread):
		return ERR_INVALID_PARAMETER
	if step < 0.1 or spread < 0.0 or spread > 20.0 or limit < 1 or limit > 256:
		return ERR_INVALID_PARAMETER
	spacing = step
	radius = spread
	max_candidates = limit
	_produced = 0
	_distance_from_stamp = 0.0
	_active = true
	_random.seed = seed_value
	return OK


func add_cursor(position: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not _active or not _finite(position) or _produced >= max_candidates:
		return result
	if _produced == 0:
		_last = position
		result.append(_jitter(position))
		_produced += 1
		return result
	var from_position: Vector3 = _last
	var delta: Vector2 = Vector2(position.x - from_position.x, position.z - from_position.z)
	var distance: float = delta.length()
	if distance <= 0.000001:
		return result
	var advanced: float = 0.0
	while _produced < max_candidates:
		var needed: float = spacing - _distance_from_stamp
		if advanced + needed > distance + 0.000001:
			break
		advanced += needed
		var point: Vector3 = from_position.lerp(position, minf(advanced / distance, 1.0))
		result.append(_jitter(point))
		_produced += 1
		_distance_from_stamp = 0.0
	_distance_from_stamp += distance - advanced
	_last = position
	return result


func get_count() -> int:
	return _produced


func is_full() -> bool:
	return _produced >= max_candidates


func end() -> void:
	_active = false


func _jitter(point: Vector3) -> Vector3:
	if radius <= 0.0:
		return point
	var angle: float = _random.randf() * TAU
	var magnitude: float = sqrt(_random.randf()) * radius
	return point + Vector3(cos(angle) * magnitude, 0.0, sin(angle) * magnitude)


static func _finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
