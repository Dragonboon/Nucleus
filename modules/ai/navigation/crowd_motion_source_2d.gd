@tool
class_name NucleusCrowdMotionSource2D
extends NucleusMotionSource2D
## Adds bounded neighbor steering to an existing motion source without moving actors.

@export var primary_source: NucleusMotionSource2D
@export_range(0.0, 512.0, 0.5) var separation_radius: float = 32.0
@export_range(0.0, 5.0, 0.05) var separation_weight: float = 0.6
@export_range(1, 128, 1) var maximum_neighbors: int = 24

var spatial_index: NucleusSpatialPointIndex2D
var actor_id: int = -1


func get_desired_velocity(
	body: CharacterBody2D,
	max_speed: float,
) -> Vector2:
	if not enabled or body == null:
		return Vector2.ZERO
	var desired := Vector2.ZERO
	if primary_source != null and primary_source != self and primary_source.enabled:
		desired = primary_source.get_desired_velocity(body, max_speed)
	var avoidance := NucleusCrowdSeparation2D.calculate(
		actor_id, body.global_position, spatial_index,
		separation_radius, maximum_neighbors,
	)
	var combined := desired / maxf(max_speed, 0.001) + avoidance * separation_weight
	if combined.is_zero_approx():
		return Vector2.ZERO
	return combined.limit_length(1.0) * maxf(max_speed, 0.0)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if primary_source == null:
		warnings.append("Assign an existing NucleusMotionSource2D.")
	return warnings
