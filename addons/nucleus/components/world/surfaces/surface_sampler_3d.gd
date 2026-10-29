@tool
class_name NucleusSurfaceSampler3D
extends Node3D
## Scene-owned extension point for analytical 3D surface queries.
##
## A sampler represents a single-valued surface over world X/Z. Subclasses may
## implement static planes, procedural terrain, oceans, rivers, or other fields.

@export var enabled: bool = true


func sample(
	world_position: Vector3,
	at_time: float = -1.0,
) -> NucleusSurfaceSample3D:
	var result := NucleusSurfaceSample3D.new()

	if not sample_into(
		world_position,
		result,
		at_time,
	):
		return null

	return result


func sample_into(
	world_position: Vector3,
	out_sample: NucleusSurfaceSample3D,
	at_time: float = -1.0,
) -> bool:
	if out_sample == null:
		return false

	out_sample.clear()

	if not enabled:
		return false

	if not _sample_surface_into(
		world_position,
		out_sample,
		at_time,
	):
		out_sample.clear()
		return false

	if not out_sample.is_valid():
		out_sample.clear()
		return false

	return true


func _sample_surface_into(
	_world_position: Vector3,
	_out_sample: NucleusSurfaceSample3D,
	_at_time: float,
) -> bool:
	return false
