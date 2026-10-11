class_name NucleusHexLayout3D
extends RefCounted
## Pure pointy-top hexagon mathematics on XZ; Y is owned by the consuming grid.
## Axial (q, r); clockwise corners start at local -Z. No scene/physics state.

const SQRT_3: float = 1.7320508075688772
const CORNER_X: Array[int] = [0, 1, 1, 0, -1, -1]
const CORNER_Z: Array[int] = [-2, -1, 1, 2, 1, -1]
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func axial_to_local(cell: Vector2i, cell_radius: float) -> Vector3:
	if not is_finite(cell_radius) or cell_radius <= 0.0:
		return Vector3.ZERO
	return Vector3(
		SQRT_3 * cell_radius * (float(cell.x) + float(cell.y) * 0.5),
		0.0,
		1.5 * cell_radius * float(cell.y),
	)


static func local_to_axial(point: Vector3, cell_radius: float) -> Vector2i:
	if not _valid_vector(point) or not is_finite(cell_radius) or cell_radius <= 0.0:
		return Vector2i.ZERO
	var fractional_q: float = (SQRT_3 / 3.0 * point.x - point.z / 3.0) / cell_radius
	var fractional_r: float = (2.0 / 3.0 * point.z) / cell_radius
	var fractional_s: float = -fractional_q - fractional_r
	var q: int = roundi(fractional_q)
	var r: int = roundi(fractional_r)
	var s: int = roundi(fractional_s)
	var q_diff: float = absf(float(q) - fractional_q)
	var r_diff: float = absf(float(r) - fractional_r)
	var s_diff: float = absf(float(s) - fractional_s)
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	return Vector2i(q, r)


## Bounded, contiguous axial stroke between two cells (includes endpoints).
## Useful for rapid mouse painting without gaps between rendered frames.
static func stroke_cells(a: Vector2i, b: Vector2i, maximum: int = 64) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps: int = distance(a, b)
	if maximum < 1 or steps + 1 > maximum:
		return result
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps) if steps > 0 else 0.0
		var point := axial_to_local(a, 1.0).lerp(axial_to_local(b, 1.0), t)
		var cell: Vector2i = local_to_axial(point, 1.0)
		if result.is_empty() or result[result.size() - 1] != cell:
			result.append(cell)
	return result


static func corner_local(cell: Vector2i, corner: int, cell_radius: float) -> Vector3:
	var index: int = posmod(corner, 6)
	var angle: float = -PI * 0.5 + float(index) * PI / 3.0
	return axial_to_local(cell, cell_radius) + Vector3(
		cos(angle) * cell_radius, 0.0, sin(angle) * cell_radius,
	)


## Exact integer key: avoids floating point errors when comparing vertices.
## Three adjacent hexagons may share one vertex; only equal layers connect.
static func corner_key(cell: Vector3i, corner: int) -> Vector3i:
	var index: int = posmod(corner, 6)
	return Vector3i(
		2 * cell.x + cell.y + CORNER_X[index],
		3 * cell.y + CORNER_Z[index],
		cell.z,
	)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))


static func in_ring(cell: Vector2i, ring_count: int) -> bool:
	return ring_count >= 0 and distance(Vector2i.ZERO, cell) <= ring_count


static func cells_in_radius(ring_count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if ring_count < 0 or ring_count > 24:
		return cells
	for q: int in range(-ring_count, ring_count + 1):
		for r: int in range(maxi(-ring_count, -q - ring_count), mini(ring_count, -q + ring_count) + 1):
			cells.append(Vector2i(q, r))
	return cells


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
