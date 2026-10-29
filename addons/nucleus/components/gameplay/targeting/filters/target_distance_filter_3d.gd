class_name NucleusTargetDistanceFilter3D
extends NucleusTargetFilter
## Restricts 3D candidates by distance from the agent origin.

@export_range(0.0, 1000000.0, 0.1, "or_greater")
var maximum_distance: float = 30.0
@export_range(0.0, 1000000.0, 0.1, "or_greater")
var minimum_distance: float = 0.0


func accepts(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	if target == null or not target.has_position_3d():
		return false

	var origin: Node3D = NucleusTargetingSpace.origin_3d(agent)

	if origin == null:
		return false

	var distance: float = origin.global_position.distance_to(
		target.get_position_3d()
	)

	return (
		distance >= maxf(0.0, minimum_distance)
		and (
			maximum_distance <= 0.0
			or distance <= maximum_distance
		)
	)
