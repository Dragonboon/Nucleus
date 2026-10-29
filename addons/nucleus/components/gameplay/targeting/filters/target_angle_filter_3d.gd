class_name NucleusTargetAngleFilter3D
extends NucleusTargetFilter
## Restricts selection to a 3D cone around Godot's conventional -Z forward.

@export_range(0.0, 180.0, 0.1)
var maximum_angle_degrees: float = 90.0


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

	var direction: Vector3 = (
		target.get_position_3d()
		- origin.global_position
	)

	if direction.is_zero_approx():
		return true

	var forward: Vector3 = NucleusTargetingSpace.forward_3d(agent)
	var minimum_dot: float = cos(
		deg_to_rad(maximum_angle_degrees)
	)

	return forward.dot(direction.normalized()) >= minimum_dot
