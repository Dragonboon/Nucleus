class_name NucleusFlowField2D
extends RefCounted
## Bounded shared grid distance field. The caller owns terrain and invalidation.

const BLOCKED: int = -1
const UNREACHABLE: int = 2147483647
const ORTHOGONAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const DIAGONAL: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var origin: Vector2i = Vector2i.ZERO
var dimensions: Vector2i = Vector2i.ZERO
var diagonal_movement: bool = false
var _distances := PackedInt32Array()
var _walkable := PackedByteArray()
var _destinations: Array[Vector2i] = []


func configure(grid_origin: Vector2i, size: Vector2i, passable: PackedByteArray) -> Error:
	if size.x <= 0 or size.y <= 0 or size.x > 1024 or size.y > 1024:
		return ERR_INVALID_PARAMETER
	if size.x * size.y > 262144 or passable.size() != size.x * size.y:
		return ERR_INVALID_PARAMETER
	origin = grid_origin
	dimensions = size
	_walkable = passable.duplicate()
	_distances.resize(passable.size())
	_reset_distances()
	_destinations.clear()
	return OK


func rebuild(goals: Array[Vector2i]) -> Error:
	if dimensions.x <= 0 or dimensions.y <= 0:
		return ERR_UNCONFIGURED
	_reset_distances()
	_destinations.clear()
	var queue := PackedInt32Array()
	queue.resize(_distances.size())
	var head := 0
	var tail := 0
	for goal: Vector2i in goals:
		var index := _index(goal)
		if index < 0 or _walkable[index] == 0 or _distances[index] == 0:
			continue
		_distances[index] = 0
		queue[tail] = index
		tail += 1
		_destinations.append(goal)
	while head < tail:
		var current := queue[head]
		head += 1
		var cell := origin + Vector2i(current % dimensions.x, current / dimensions.x)
		var distance := _distances[current] + 1
		for direction: Vector2i in ORTHOGONAL:
			var other := _index(cell + direction)
			if other < 0 or _walkable[other] == 0 or _distances[other] != UNREACHABLE:
				continue
			_distances[other] = distance
			queue[tail] = other
			tail += 1
		if not diagonal_movement:
			continue
		for direction: Vector2i in DIAGONAL:
			var destination := cell + direction
			var other := _index(destination)
			if other < 0 or _walkable[other] == 0 or _distances[other] != UNREACHABLE:
				continue
			var horizontal := _index(cell + Vector2i(direction.x, 0))
			var vertical := _index(cell + Vector2i(0, direction.y))
			if horizontal < 0 or vertical < 0:
				continue
			if _walkable[horizontal] == 0 or _walkable[vertical] == 0:
				continue
			_distances[other] = distance
			queue[tail] = other
			tail += 1
	return OK


func distance_at(cell: Vector2i) -> int:
	var index := _index(cell)
	if index < 0 or _walkable[index] == 0:
		return BLOCKED
	return _distances[index]


func direction_at(cell: Vector2i) -> Vector2:
	var current := distance_at(cell)
	if current <= 0 or current == UNREACHABLE:
		return Vector2.ZERO
	var best := current
	var direction := Vector2.ZERO
	for offset: Vector2i in ORTHOGONAL:
		var value := distance_at(cell + offset)
		if value >= 0 and value < best:
			best = value
			direction = Vector2(offset)
	if diagonal_movement:
		for offset: Vector2i in DIAGONAL:
			var adjacent_a := distance_at(cell + Vector2i(offset.x, 0))
			var adjacent_b := distance_at(cell + Vector2i(0, offset.y))
			if adjacent_a < 0 or adjacent_b < 0:
				continue
			var value := distance_at(cell + offset)
			if value >= 0 and value < best:
				best = value
				direction = Vector2(offset).normalized()
	return direction


func get_goals() -> Array[Vector2i]:
	return _destinations.duplicate()


func _reset_distances() -> void:
	_distances.fill(UNREACHABLE)


func _index(cell: Vector2i) -> int:
	var local := cell - origin
	if local.x < 0 or local.y < 0 or local.x >= dimensions.x or local.y >= dimensions.y:
		return -1
	return local.y * dimensions.x + local.x
