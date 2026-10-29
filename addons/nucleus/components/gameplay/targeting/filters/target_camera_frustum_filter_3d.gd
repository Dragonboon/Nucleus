class_name NucleusTargetCameraFrustumFilter3D
extends NucleusTargetFilter
## Uses Camera3D's native frustum query for screen-visible target selection.

@export var camera: Camera3D


func accepts(
	_agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	var resolved_camera: Camera3D = camera

	if resolved_camera == null and _agent.orientation_source is Camera3D:
		resolved_camera = _agent.orientation_source as Camera3D

	if resolved_camera == null or target == null:
		return false

	if not target.has_position_3d():
		return false

	return resolved_camera.is_position_in_frustum(
		target.get_position_3d()
	)
