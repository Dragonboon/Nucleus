class_name NucleusTargetFacingScorer3D
extends NucleusTargetScorer
## Scores how closely a target aligns with Godot's conventional -Z forward.

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

	var direction: Vector3 = (
		target.get_position_3d()
		- origin.global_position
	)

	if direction.is_zero_approx():
		return 1.0

	return NucleusTargetingSpace.forward_3d(agent).dot(
		direction.normalized()
	)
