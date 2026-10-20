class_name NucleusSpatialPointIndex2D
extends RefCounted
## Scene-independent mutable point broad phase. Exact physics stays in Godot.

const MAX_QUERY_CELLS: int = 4096

var cell_size: float = 64.0
var _positions: Dictionary = {}
var _cells: Dictionary = {}
var _memberships: Dictionary = {}


func configure_cell_size(value: float) -> Error:
	if not is_finite(value) or value <= 0.0:
		return ERR_INVALID_PARAMETER
	if is_equal_approx(cell_size, value):
		return OK
	cell_size = value
	var positions := _positions.duplicate()
	clear()
	for id: Variant in positions:
		upsert(int(id), positions[id])
	return OK


func upsert(id: int, point: Vector2) -> Error:
	if id < 0 or not _valid_point(point):
		return ERR_INVALID_PARAMETER
	var new_cell := _cell(point)
	if _memberships.has(id):
		var previous: Vector2i = _memberships[id]
		if previous != new_cell:
			_erase_member(id, previous)
		else:
			_positions[id] = point
			return OK
	var bucket: Dictionary = _cells.get(new_cell, {})
	bucket[id] = true
	_cells[new_cell] = bucket
	_memberships[id] = new_cell
	_positions[id] = point
	return OK


func remove(id: int) -> bool:
	if not _memberships.has(id):
		return false
	_erase_member(id, _memberships[id])
	_memberships.erase(id)
	_positions.erase(id)
	return true


func clear() -> void:
	_positions.clear()
	_memberships.clear()
	_cells.clear()


func size() -> int:
	return _positions.size()


func query_radius(center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	if not _valid_point(center) or not is_finite(radius) or radius < 0.0:
		return result
	if radius > 100000000.0:
		return result
	var first := _cell(center - Vector2.ONE * radius)
	var last := _cell(center + Vector2.ONE * radius)
	var span_x := last.x - first.x + 1
	var span_y := last.y - first.y + 1
	var candidates: Dictionary = {}
	if span_x * span_y > MAX_QUERY_CELLS:
		candidates = _positions
	else:
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var bucket: Dictionary = _cells.get(Vector2i(x, y), {})
				for id: Variant in bucket:
					candidates[id] = true
	var squared := radius * radius
	for id: Variant in candidates:
		var point: Vector2 = _positions[id]
		if point.distance_squared_to(center) <= squared:
			result.append(int(id))
	result.sort()
	return result


func get_position(id: int) -> Vector2:
	return _positions.get(id, Vector2.ZERO)


func has_point(id: int) -> bool:
	return _positions.has(id)


func _erase_member(id: int, cell: Vector2i) -> void:
	var bucket: Dictionary = _cells.get(cell, {})
	bucket.erase(id)
	if bucket.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = bucket


func _valid_point(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	var scaled := point / cell_size
	return absf(scaled.x) <= 100000000.0 and absf(scaled.y) <= 100000000.0


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
