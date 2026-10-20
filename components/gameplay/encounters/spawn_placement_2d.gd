class_name NucleusSpawnPlacement2D
extends RefCounted
## Bounded placement policy. Game code owns actor selection and spawning.

var minimum_radius: float = 180.0
var maximum_radius: float = 280.0
var clearance: float = 12.0
var separation_radius: float = 24.0
var maximum_attempts: int = 24


func find_position(
	center: Vector2,
	rng: RandomNumberGenerator,
	excluded: Array[Rect2] = [],
	walkable: Callable = Callable(),
	occupied: NucleusSpatialPointIndex2D = null,
) -> Dictionary:
	var result: Dictionary = {"found": false, "position": Vector2.ZERO, "attempts": 0}
	if rng == null or not center.is_finite() or not _is_valid():
		return result
	for attempt in range(maximum_attempts):
		var point := NucleusRandomGeometry.point_in_annulus(
			center, minimum_radius, maximum_radius, rng,
		)
		result["attempts"] = attempt + 1
		var rejected := false
		for rectangle: Rect2 in excluded:
			if rectangle.grow(clearance).has_point(point):
				rejected = true
				break
		if rejected:
			continue
		if occupied != null and not occupied.query_radius(
			point, separation_radius,
		).is_empty():
			continue
		if walkable.is_valid() and not bool(walkable.call(point)):
			continue
		result["found"] = true
		result["position"] = point
		return result
	return result


func _is_valid() -> bool:
	return (
		is_finite(minimum_radius)
		and is_finite(maximum_radius)
		and is_finite(clearance)
		and is_finite(separation_radius)
		and minimum_radius >= 0.0
		and maximum_radius >= minimum_radius
		and clearance >= 0.0
		and separation_radius >= 0.0
		and maximum_attempts > 0
		and maximum_attempts <= 256
	)
