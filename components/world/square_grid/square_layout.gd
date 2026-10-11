class_name NucleusSquareLayout
extends RefCounted
## Shared orthogonal topology for 2D (including isometric projection) and 3D.
## Coordinates are data; Godot TileMapLayer/GridMap remain the rendering owners.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 0),
]


static func neighbor(cell: Vector2i, side: int) -> Vector2i:
	return cell + DIRECTIONS[posmod(side, 4)]


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func rotate_cell(cell: Vector2i, clockwise_steps: int) -> Vector2i:
	var result: Vector2i = cell
	for _step in range(posmod(clockwise_steps, 4)):
		result = Vector2i(-result.y, result.x)
	return result


## Keys are exact integer coordinates and include the elevation layer.
static func corner_key(cell: Vector3i, corner: int) -> Vector3i:
	var offsets: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(1, -1),
		Vector2i(1, 1), Vector2i(-1, 1),
	]
	var offset: Vector2i = offsets[posmod(corner, 4)]
	return Vector3i(2 * cell.x + offset.x, 2 * cell.y + offset.y, cell.z)


static func cell_to_local(
	cell: Vector2i, size: Vector2, isometric: bool = false,
) -> Vector2:
	if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	if isometric:
		return Vector2(
			float(cell.x - cell.y) * size.x * 0.5,
			float(cell.x + cell.y) * size.y * 0.5,
		)
	return Vector2(float(cell.x) * size.x, float(cell.y) * size.y)


static func local_to_cell(
	position: Vector2, size: Vector2, isometric: bool = false,
) -> Vector2i:
	if not position.is_finite() or not size.is_finite():
		return Vector2i.ZERO
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2i.ZERO
	if isometric:
		var u: float = position.x / size.x
		var v: float = position.y / size.y
		return Vector2i(roundi(u + v), roundi(v - u))
	return Vector2i(roundi(position.x / size.x), roundi(position.y / size.y))


static func corner_offset(corner: int, size: Vector2, isometric: bool = false) -> Vector2:
	var offsets: Array[Vector2] = [
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
		Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
	]
	var offset: Vector2 = offsets[posmod(corner, 4)]
	if isometric:
		return Vector2(
			(offset.x - offset.y) * size.x * 0.5,
			(offset.x + offset.y) * size.y * 0.5,
		)
	return offset * size


static func local_3d(cell: Vector3i, spacing: Vector2, layer_step: float) -> Vector3:
	return Vector3(
		float(cell.x) * spacing.x,
		float(cell.z) * layer_step,
		float(cell.y) * spacing.y,
	)


## Bounded Bresenham rasterization for continuous mouse strokes.
static func line(a: Vector2i, b: Vector2i, maximum: int = 128) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dx: int = absi(b.x - a.x)
	var dy: int = absi(b.y - a.y)
	if maximum < 1 or maxi(dx, dy) + 1 > maximum:
		return result
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var error: int = dx - dy
	var x: int = a.x
	var y: int = a.y
	while true:
		result.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			return result
		var twice: int = 2 * error
		if twice > -dy:
			error -= dy
			x += sx
		if twice < dx:
			error += dx
			y += sy
	return result


## Uniform-cost BFS; the consumer controls admissible cells and obstacles.
static func shortest_path(
	start: Vector2i, goal: Vector2i, can_enter: Callable, maximum: int = 2048,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_enter.is_valid() or maximum < 1:
		return result
	if start == goal:
		return [start]
	var frontier: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor: int = 0
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		for direction in range(4):
			var candidate: Vector2i = neighbor(cell, direction)
			if parents.has(candidate) or not bool(can_enter.call(candidate)):
				continue
			if frontier.size() >= maximum:
				return []
			parents[candidate] = cell
			if candidate == goal:
				var cursor_cell: Vector2i = goal
				while cursor_cell != start:
					result.push_front(cursor_cell)
					cursor_cell = parents[cursor_cell]
				result.push_front(start)
				return result
			frontier.append(candidate)
	return []
