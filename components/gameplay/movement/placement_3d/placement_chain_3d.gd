class_name NucleusPlacementChain3D
extends RefCounted
## Pure bounded straight-line layout; no meshes, physics or game rules.
## Each point is revalidated against world geometry before any commit.


static func points(
	anchor: Vector3,
	end: Vector3,
	spacing: float,
	maximum_count: int,
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not _finite(anchor) or not _finite(end):
		return result
	if not is_finite(spacing) or spacing <= 0.0 or maximum_count < 1:
		return result

	var horizontal := Vector3(end.x - anchor.x, 0.0, end.z - anchor.z)
	var distance := horizontal.length()
	if not is_finite(distance) or distance / spacing >= float(maximum_count):
		return result
	var count := floori(distance / spacing) + 1
	if count > maximum_count:
		return result
	var direction := horizontal.normalized() if distance > 0.0 else Vector3.ZERO
	for index: int in range(count):
		result.append(anchor + direction * spacing * float(index))
	return result


static func heading(anchor: Vector3, end: Vector3, fallback: float = 0.0) -> float:
	var delta := Vector2(end.x - anchor.x, end.z - anchor.z)
	if delta.length_squared() <= 0.000001:
		return fallback
	return atan2(-delta.x, -delta.y)


static func _finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
