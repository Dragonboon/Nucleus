@tool
class_name NucleusTerrainResolutionPolicy
extends Resource
## Resolves visual/collision heightfield resolution from physical terrain size.
##
## The policy is pure. It does not mutate NucleusTerrainProfile automatically.

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

@export_group("Visual meters per cell")
@export_range(0.05, 1000.0, 0.05, "or_greater")
var minimal_meters_per_cell: float = 6.0
@export_range(0.05, 1000.0, 0.05, "or_greater")
var reduced_meters_per_cell: float = 4.0
@export_range(0.05, 1000.0, 0.05, "or_greater")
var full_meters_per_cell: float = 2.5

@export_group("Visual bounds")
@export_range(2, 4096, 1, "or_greater")
var minimum_visual_resolution: int = 32
@export_range(2, 4096, 1, "or_greater")
var maximum_visual_resolution: int = 256
@export_range(1, 256, 1, "or_greater")
var visual_resolution_step: int = 16

@export_group("Collision")
@export_range(0.05, 1.0, 0.05)
var collision_resolution_ratio: float = 0.5
@export_range(2, 2048, 1, "or_greater")
var minimum_collision_resolution: int = 16
@export_range(2, 2048, 1, "or_greater")
var maximum_collision_resolution: int = 128
@export_range(1, 256, 1, "or_greater")
var collision_resolution_step: int = 8


func resolve_visual_resolution(
	terrain_size: Vector2,
	quality: int = Quality.FULL,
) -> int:
	var meters_per_cell := _meters_per_cell(quality)
	var largest_axis := maxf(
		absf(terrain_size.x),
		absf(terrain_size.y),
	)
	var requested := int(ceil(largest_axis / meters_per_cell))
	requested = _round_up_to_step(
		requested,
		maxi(visual_resolution_step, 1),
	)

	return clampi(
		requested,
		maxi(minimum_visual_resolution, 2),
		maxi(maximum_visual_resolution, minimum_visual_resolution),
	)


func resolve_collision_resolution(
	terrain_size: Vector2,
	quality: int = Quality.FULL,
) -> int:
	var visual := resolve_visual_resolution(
		terrain_size,
		quality,
	)
	var requested := int(ceil(
		float(visual)
		* clampf(collision_resolution_ratio, 0.05, 1.0)
	))
	requested = _round_up_to_step(
		requested,
		maxi(collision_resolution_step, 1),
	)

	return mini(
		visual,
		clampi(
			requested,
			maxi(minimum_collision_resolution, 2),
			maxi(
				maximum_collision_resolution,
				minimum_collision_resolution,
			),
		),
	)


func resolve(
	terrain_size: Vector2,
	quality: int = Quality.FULL,
) -> Dictionary:
	return {
		"visual_resolution": resolve_visual_resolution(
			terrain_size,
			quality,
		),
		"collision_resolution": resolve_collision_resolution(
			terrain_size,
			quality,
		),
	}


func apply_to_profile(
	profile: NucleusTerrainProfile,
	quality: int = Quality.FULL,
) -> Error:
	if profile == null:
		return ERR_INVALID_PARAMETER

	profile.resolution = resolve_visual_resolution(
		profile.size,
		quality,
	)
	profile.collision_resolution = resolve_collision_resolution(
		profile.size,
		quality,
	)
	return OK


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if minimum_visual_resolution > maximum_visual_resolution:
		errors.append(
			"minimum_visual_resolution must not exceed the maximum."
		)

	if minimum_collision_resolution > maximum_collision_resolution:
		errors.append(
			"minimum_collision_resolution must not exceed the maximum."
		)

	if (
		minimal_meters_per_cell < reduced_meters_per_cell
		or reduced_meters_per_cell < full_meters_per_cell
	):
		errors.append(
			"Expected Minimal >= Reduced >= Full meters-per-cell values."
		)

	return errors


func _meters_per_cell(quality: int) -> float:
	match clampi(quality, Quality.MINIMAL, Quality.FULL):
		Quality.MINIMAL:
			return maxf(minimal_meters_per_cell, 0.05)
		Quality.REDUCED:
			return maxf(reduced_meters_per_cell, 0.05)
		_:
			return maxf(full_meters_per_cell, 0.05)


func _round_up_to_step(
	value: int,
	step: int,
) -> int:
	var safe_step := maxi(step, 1)
	var safe_value := maxi(value, 0)
	return int(ceil(float(safe_value) / float(safe_step))) * safe_step
