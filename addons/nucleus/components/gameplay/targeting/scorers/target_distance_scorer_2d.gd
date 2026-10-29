class_name NucleusTargetDistanceScorer2D
extends NucleusTargetScorer
## Gives nearer 2D targets a higher score by returning negative distance.

@export_range(0.000001, 1000000.0, 0.001, "or_greater")
var distance_scale: float = 1.0


func score(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> float:
	if target == null or not target.has_position_2d():
		return 0.0

	var origin: Node2D = NucleusTargetingSpace.origin_2d(agent)

	if origin == null:
		return 0.0

	return -origin.global_position.distance_to(
		target.get_position_2d()
	) / distance_scale
