class_name NucleusCrowdSeparation2D
extends RefCounted
## Steering intent from an explicitly maintained NucleusSpatialPointIndex2D.
## Does not own entity position, physics, or AI decisions.


static func calculate(
	agent_id: int,
	agent_position: Vector2,
	index: NucleusSpatialPointIndex2D,
	radius: float,
	maximum_neighbors: int = 24,
	maximum_candidates: int = 0,
) -> Vector2:
	if index == null or not agent_position.is_finite():
		return Vector2.ZERO
	if not is_finite(radius) or radius <= 0.0 or maximum_neighbors <= 0:
		return Vector2.ZERO
	var nearby: Array[int]
	if maximum_candidates > 0:
		nearby = index.query_radius_bounded(
			agent_position, radius, maximum_neighbors, maximum_candidates, 64, agent_id,
		)
	else:
		nearby = index.query_radius(agent_position, radius)
	var repulsion := Vector2.ZERO
	var processed := 0
	for other_id: int in nearby:
		if other_id == agent_id:
			continue
		var displacement := agent_position - index.get_position(other_id)
		var squared := displacement.length_squared()
		if squared < 0.000001:
			continue
		var distance := sqrt(squared)
		repulsion += displacement / distance * (1.0 - distance / radius)
		processed += 1
		if processed >= maximum_neighbors:
			break
	return repulsion.normalized() if not repulsion.is_zero_approx() else Vector2.ZERO
