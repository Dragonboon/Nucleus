@tool
class_name NucleusScatterDensityVolume3D
extends Node3D
## Scene-owned planar box mask evaluated only during region generation.
## Volume rotation and scale are honored. No global registry or per-frame work.

@export var size: Vector2 = Vector2(10.0, 10.0)
@export_range(0.0, 1.0, 0.01) var density_multiplier: float = 0.0


func contains_world_xz(world_position: Vector3) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var local_point: Vector3 = global_transform.affine_inverse() * world_position
	return (
		absf(local_point.x) <= size.x * 0.5
		and absf(local_point.z) <= size.y * 0.5
	)


func get_density_multiplier(world_position: Vector3) -> float:
	if contains_world_xz(world_position):
		return clampf(density_multiplier, 0.0, 1.0)
	return 1.0
