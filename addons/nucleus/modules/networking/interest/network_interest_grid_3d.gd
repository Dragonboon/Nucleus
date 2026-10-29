class_name NucleusNetworkInterestGrid3D
extends RefCounted
## Server-fed XZ spatial index for network relevance queries.
## Coordinates are world-space meters; vertical distance is intentionally ignored.

const MAX_QUERY_RADIUS_CELLS: int = 16
const MAX_QUERY_RESULTS: int = 1024

var cell_size: float = 32.0

var _positions: Dictionary = {}
var _entity_cells: Dictionary = {}
var _buckets: Dictionary = {}


func set_cell_size(value: float) -> Error:
	if not is_finite(value) or value <= 0.0:
		return ERR_INVALID_PARAMETER

	if value == cell_size:
		return OK

	cell_size = value
	_buckets.clear()
	_entity_cells.clear()

	for entity_id: StringName in _positions.keys():
		var position: Vector3 = _positions[entity_id]
		_insert_in_cell(entity_id, cell_for_position(position, cell_size))

	return OK


static func cell_for_position(position: Vector3, size: float) -> Vector2i:
	return Vector2i(
		floori(position.x / size),
		floori(position.z / size),
	)


static func is_valid_position(position: Vector3) -> bool:
	return (
		is_finite(position.x)
		and is_finite(position.y)
		and is_finite(position.z)
	)


func is_supported_radius(radius: float) -> bool:
	return (
		is_finite(radius)
		and radius >= 0.0
		and radius <= cell_size * float(MAX_QUERY_RADIUS_CELLS)
	)


func upsert_entity(entity_id: StringName, position: Vector3) -> Error:
	if entity_id == &"" or not is_valid_position(position):
		return ERR_INVALID_PARAMETER

	var new_cell: Vector2i = cell_for_position(position, cell_size)
	if _entity_cells.has(entity_id):
		var old_cell: Vector2i = _entity_cells[entity_id]
		if old_cell != new_cell:
			_remove_from_cell(entity_id, old_cell)
			_insert_in_cell(entity_id, new_cell)
	else:
		_insert_in_cell(entity_id, new_cell)

	_positions[entity_id] = position
	return OK


func remove_entity(entity_id: StringName) -> bool:
	if not _entity_cells.has(entity_id):
		return false

	var old_cell: Vector2i = _entity_cells[entity_id]
	_remove_from_cell(entity_id, old_cell)
	_positions.erase(entity_id)
	return true


func has_entity(entity_id: StringName) -> bool:
	return _positions.has(entity_id)


func get_entity_count() -> int:
	return _positions.size()


func clear() -> void:
	_positions.clear()
	_entity_cells.clear()
	_buckets.clear()


## Returns overlapping XZ cells in deterministic nearest-center-first order.
## These are bounding-box cells, not an authorization or exact circle test.
func get_covered_cells(
	world_position: Vector3,
	radius: float,
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not is_valid_position(world_position) or not is_supported_radius(radius):
		return cells

	var minimum: Vector2i = cell_for_position(
		world_position - Vector3(radius, 0.0, radius),
		cell_size,
	)
	var maximum: Vector2i = cell_for_position(
		world_position + Vector3(radius, 0.0, radius),
		cell_size,
	)
	for x: int in range(minimum.x, maximum.x + 1):
		for z: int in range(minimum.y, maximum.y + 1):
			cells.append(Vector2i(x, z))

	var center := Vector2(world_position.x, world_position.z) / cell_size
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_offset := Vector2(a) + Vector2(0.5, 0.5) - center
		var b_offset := Vector2(b) + Vector2(0.5, 0.5) - center
		var a_distance: float = a_offset.length_squared()
		var b_distance: float = b_offset.length_squared()
		if a_distance != b_distance:
			return a_distance < b_distance
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	return cells


func get_entities_in_cell(cell: Vector2i) -> Array[StringName]:
	var result: Array[StringName] = []
	var bucket: Dictionary = _buckets.get(cell, {})
	for entity_id: StringName in bucket.keys():
		result.append(entity_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	return result


func query_radius(
	world_position: Vector3,
	radius: float,
	max_results: int = 128,
) -> Array[StringName]:
	var result: Array[StringName] = []
	if (
		not is_valid_position(world_position)
		or not is_supported_radius(radius)
		or max_results <= 0
	):
		return result

	var radius_squared: float = radius * radius
	var matches: Array[Dictionary] = []

	for cell: Vector2i in get_covered_cells(world_position, radius):
		if not _buckets.has(cell):
			continue

		var bucket: Dictionary = _buckets[cell]
		for entity_id: StringName in bucket.keys():
			var position: Vector3 = _positions[entity_id]
			var delta := Vector2(
				position.x - world_position.x,
				position.z - world_position.z,
			)
			var distance_squared: float = delta.length_squared()
			if distance_squared <= radius_squared:
				matches.append({
					"id": entity_id,
					"distance_squared": distance_squared,
				})

	matches.sort_custom(_closer_first)
	var count: int = mini(
		max_results,
		mini(matches.size(), MAX_QUERY_RESULTS),
	)
	for index: int in range(count):
		var entity_id: StringName = matches[index]["id"]
		result.append(entity_id)

	return result


func _insert_in_cell(entity_id: StringName, cell: Vector2i) -> void:
	var bucket: Dictionary = _buckets.get(cell, {})
	bucket[entity_id] = true
	_buckets[cell] = bucket
	_entity_cells[entity_id] = cell


func _remove_from_cell(entity_id: StringName, cell: Vector2i) -> void:
	var bucket: Dictionary = _buckets.get(cell, {})
	bucket.erase(entity_id)
	if bucket.is_empty():
		_buckets.erase(cell)
	else:
		_buckets[cell] = bucket
	_entity_cells.erase(entity_id)


static func _closer_first(a: Dictionary, b: Dictionary) -> bool:
	var a_distance: float = a["distance_squared"]
	var b_distance: float = b["distance_squared"]
	if a_distance != b_distance:
		return a_distance < b_distance

	return String(a["id"]) < String(b["id"])
