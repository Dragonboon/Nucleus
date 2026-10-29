class_name NucleusTargetDistanceScorer3D
extends NucleusTargetScorer
## Gives nearer 3D targets a higher score by returning negative distance.

@export_range(0.000001, 1000000.0, 0.001, "or_greater")
var distance_scale: float = 1.0


func score(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> float:
	if target == null or not target.has_position_3d():
		return 0.0

	var origin: Node3D = NucleusTargetingSpace.origin_3d(agent)

	if origin == null:
		return 0.0

	return -origin.global_position.distance_to(
		target.get_position_3d()
	) / distance_scale
