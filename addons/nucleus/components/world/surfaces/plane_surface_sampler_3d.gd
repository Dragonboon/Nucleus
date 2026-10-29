@tool
class_name NucleusPlaneSurfaceSampler3D
extends NucleusSurfaceSampler3D
## Analytical infinite plane sampler using this node's world transform.
##
## The local +Y axis is the surface normal. Nearly vertical planes are rejected
## because SurfaceSampler3D models a single-valued surface over world X/Z.

@export var surface_velocity: Vector3 = Vector3.ZERO
@export var metadata: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var plane_normal := global_transform.basis.y.normalized()

	if absf(plane_normal.y) <= 0.000001:
		warnings.append(
			"SurfaceSampler3D requires a plane that can be sampled over world X/Z."
		)

	return warnings


func _sample_surface_into(
	world_position: Vector3,
	out_sample: NucleusSurfaceSample3D,
	at_time: float,
) -> bool:
	var plane_normal := global_transform.basis.y.normalized()

	if absf(plane_normal.y) <= 0.000001:
		return false

	var plane_point := global_position
	var offset_x := world_position.x - plane_point.x
	var offset_z := world_position.z - plane_point.z
	var surface_y := plane_point.y - (
		plane_normal.x * offset_x
		+ plane_normal.z * offset_z
	) / plane_normal.y

	out_sample.set_values(
		Vector3(
			world_position.x,
			surface_y,
			world_position.z,
		),
		plane_normal,
		surface_velocity,
		at_time,
		metadata,
	)
	return true
