class_name NucleusTargetAngleFilter2D
extends NucleusTargetFilter
## Restricts selection to a 2D cone around the agent's local +X forward.

@export_range(0.0, 180.0, 0.1)
var maximum_angle_degrees: float = 90.0


func accepts(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	if target == null or not target.has_position_2d():
		return false

	var origin: Node2D = NucleusTargetingSpace.origin_2d(agent)

	if origin == null:
		return false

	var direction: Vector2 = (
		target.get_position_2d()
		- origin.global_position
	)

	if direction.is_zero_approx():
		return true

	var forward: Vector2 = NucleusTargetingSpace.forward_2d(agent)
	var minimum_dot: float = cos(
		deg_to_rad(maximum_angle_degrees)
	)

	return forward.dot(direction.normalized()) >= minimum_dot
