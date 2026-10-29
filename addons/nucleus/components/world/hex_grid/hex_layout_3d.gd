class_name NucleusHexLayout3D
extends RefCounted
## Backwards-compatible XZ adapter. NucleusHexLayout owns shared hex maths.

const SQRT_3: float = 1.7320508075688772
const CORNER_X: Array[int] = [0, 1, 1, 0, -1, -1]
const CORNER_Z: Array[int] = [-2, -1, 1, 2, 1, -1]
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func axial_to_local(
	cell: Vector2i, radius: float, flat_top: bool = false,
) -> Vector3:
	var p: Vector2 = NucleusHexLayout.axial_to_pixel(cell, radius, flat_top)
	return Vector3(p.x, 0.0, p.y)


static func local_to_axial(
	point: Vector3, radius: float, flat_top: bool = false,
) -> Vector2i:
	return NucleusHexLayout.pixel_to_axial(Vector2(point.x, point.z), radius, flat_top)


static func corner_local(
	cell: Vector2i, corner: int, radius: float, flat_top: bool = false,
) -> Vector3:
	var position: Vector2 = NucleusHexLayout.axial_to_pixel(cell, radius, flat_top)
	var p: Vector2 = position + NucleusHexLayout.corner_offset(corner, radius, flat_top)
	return Vector3(p.x, 0.0, p.y)


static func corner_key(cell: Vector3i, corner: int) -> Vector3i:
	return NucleusHexLayout.corner_key(cell, corner)


static func distance(a: Vector2i, b: Vector2i) -> int:
	return NucleusHexLayout.distance(a, b)


static func in_ring(cell: Vector2i, ring_count: int) -> bool:
	return NucleusHexLayout.in_radius(cell, ring_count)


static func cells_in_radius(ring_count: int) -> Array[Vector2i]:
	return NucleusHexLayout.cells_in_radius(ring_count)


static func stroke_cells(a: Vector2i, b: Vector2i, maximum: int = 64) -> Array[Vector2i]:
	return NucleusHexLayout.line(a, b, maximum)
