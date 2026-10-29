class_name NucleusTargetFacingScorer2D
extends NucleusTargetScorer
## Scores how closely a target aligns with the agent's local +X forward.

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

	var direction: Vector2 = (
		target.get_position_2d()
		- origin.global_position
	)

	if direction.is_zero_approx():
		return 1.0

	return NucleusTargetingSpace.forward_2d(agent).dot(
		direction.normalized()
	)
