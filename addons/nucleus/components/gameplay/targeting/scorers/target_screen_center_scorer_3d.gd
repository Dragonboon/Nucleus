class_name NucleusTargetScreenCenterScorer3D
extends NucleusTargetScorer
## Favors 3D targets whose projected point is closest to viewport center.

@export var camera: Camera3D
@export_range(1.0, 100000.0, 1.0, "or_greater")
var pixel_scale: float = 100.0


func score(
	_agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> float:
	if (
		camera == null
		or target == null
		or not target.has_position_3d()
	):
		return 0.0

	var position: Vector3 = target.get_position_3d()

	if camera.is_position_behind(position):
		return -1000000.0

	var screen_position: Vector2 = camera.unproject_position(
		position
	)
	var center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5

	return -screen_position.distance_to(center) / pixel_scale
