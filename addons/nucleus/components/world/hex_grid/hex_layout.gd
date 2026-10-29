class_name NucleusHexLayout
extends RefCounted
## Shared 2D/3D axial topology. Pixel Y and 3D Z use the same positive direction.
## No renderer, scene, physics, persistence, or gameplay rules.

const SQRT_3: float = 1.7320508075688772
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const DIAGONALS: Array[Vector2i] = [
	Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -1),
	Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 1),
]
const CORNER_X: Array[int] = [0, 1, 1, 0, -1, -1]
const CORNER_Y: Array[int] = [-2, -1, 1, 2, 1, -1]
const EDGE_NEIGHBOR_DIR: Array[int] = [1, 0, 5, 4, 3, 2]


static func axial_to_pixel(cell: Vector2i, radius: float, flat_top: bool = false) -> Vector2:
	if not is_finite(radius) or radius <= 0.0:
		return Vector2.ZERO
	var point := Vector2(
		SQRT_3 * radius * (float(cell.x) + float(cell.y) * 0.5),
		1.5 * radius * float(cell.y),
	)
	return point.rotated(PI / 6.0) if flat_top else point


static func pixel_to_axial(point: Vector2, radius: float, flat_top: bool = false) -> Vector2i:
	if not point.is_finite() or not is_finite(radius) or radius <= 0.0:
		return Vector2i.ZERO
	var p: Vector2 = point.rotated(-PI / 6.0) if flat_top else point
	var q: float = (SQRT_3 / 3.0 * p.x - p.y / 3.0) / radius
	var r: float = (2.0 / 3.0 * p.y) / radius
	return round_axial(q, r)


static func round_axial(q: float, r: float) -> Vector2i:
	if not is_finite(q) or not is_finite(r):
		return Vector2i.ZERO
	var s: float = -q - r
	var iq: int = roundi(q)
	var ir: int = roundi(r)
	var iz: int = roundi(s)
	var dq: float = absf(float(iq) - q)
	var dr: float = absf(float(ir) - r)
	var dz: float = absf(float(iz) - s)
	if dq > dr and dq > dz:
		iq = -ir - iz
	elif dr > dz:
		ir = -iq - iz
	return Vector2i(iq, ir)


static func corner_offset(index: int, radius: float, flat_top: bool = false) -> Vector2:
	var angle: float = -PI * 0.5 + float(posmod(index, 6)) * PI / 3.0
	if flat_top:
		angle += PI / 6.0
	return Vector2(cos(angle), sin(angle)) * radius


static func corner_key(cell: Vector3i, corner: int) -> Vector3i:
	var index: int = posmod(corner, 6)
	return Vector3i(
		2 * cell.x + cell.y + CORNER_X[index],
		3 * cell.y + CORNER_Y[index], cell.z,
	)


static func neighbor(cell: Vector2i, direction: int) -> Vector2i:
	return cell + DIRECTIONS[posmod(direction, 6)]


static func edge_neighbor(cell: Vector2i, side: int) -> Vector2i:
	return neighbor(cell, EDGE_NEIGHBOR_DIR[posmod(side, 6)])


static func diagonal_neighbor(cell: Vector2i, direction: int) -> Vector2i:
	return cell + DIAGONALS[posmod(direction, 6)]


static func rotate_axial(cell: Vector2i, steps: int) -> Vector2i:
	var result: Vector2i = cell
	for index: int in range(posmod(steps, 6)):
		result = Vector2i(-result.y, result.x + result.y)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))


static func in_radius(cell: Vector2i, radius: int) -> bool:
	return radius >= 0 and distance(Vector2i.ZERO, cell) <= radius


static func cells_in_radius(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0 or radius > 24:
		return result
	for q: int in range(-radius, radius + 1):
		var low: int = maxi(-radius, -q - radius)
		var high: int = mini(radius, -q + radius)
		for r: int in range(low, high + 1):
			result.append(Vector2i(q, r))
	return result


static func line(a: Vector2i, b: Vector2i, maximum: int = 64) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps: int = distance(a, b)
	if maximum < 1 or steps + 1 > maximum:
		return result
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps) if steps > 0 else 0.0
		var q: float = lerpf(float(a.x), float(b.x), t)
		var r: float = lerpf(float(a.y), float(b.y), t)
		var cell: Vector2i = round_axial(q, r)
		if result.is_empty() or result[result.size() - 1] != cell:
			result.append(cell)
	return result


## Uniform-cost bounded BFS. The consumer owns movement permissions and costs.
## can_enter receives the candidate Vector2i and returns a bool.
static func shortest_path(
	start: Vector2i, goal: Vector2i, can_enter: Callable, maximum: int = 2048,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_enter.is_valid() or maximum < 1:
		return result
	if start == goal:
		result.append(start)
		return result
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor: int = 0
	while cursor < queue.size() and queue.size() <= maximum:
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction: int in range(6):
			var next: Vector2i = neighbor(current, direction)
			if parents.has(next) or not bool(can_enter.call(next)):
				continue
			if queue.size() >= maximum:
				return []
			parents[next] = current
			if next == goal:
				var step: Vector2i = goal
				while step != start:
					result.push_front(step)
					step = parents[step]
				result.push_front(start)
				return result
			queue.append(next)
	return result
