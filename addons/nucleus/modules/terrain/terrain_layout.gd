@tool
class_name NucleusTerrainLayout
extends Resource
## Deterministic placement policy for complete, linear, grid, or island terrains.

enum Mode {
	SINGLE,
	GRID,
	LINEAR,
	ISLANDS,
}

enum Axis {
	X,
	Z,
}

@export var mode: Mode = Mode.SINGLE

@export_group("Grid")
@export var grid_size: Vector2i = Vector2i(2, 2)
@export_range(0.0, 100000.0, 0.1)
var patch_gap: float = 0.0

@export_group("Linear")
@export_range(1, 1024, 1)
var linear_count: int = 6
@export var linear_axis: Axis = Axis.Z
@export var linear_centered: bool = true

@export_group("Islands")
@export_range(1, 256, 1)
var island_count: int = 6
@export var island_spread: Vector2 = Vector2(1800.0, 1800.0)
@export var island_scale_range: Vector2 = Vector2(0.55, 1.35)
@export_range(0.0, 100000.0, 1.0)
var island_min_separation: float = 80.0
@export_range(1, 512, 1)
var island_placement_attempts: int = 64
@warning_ignore("shadowed_global_identifier")
@export var seed: int = 1337


func build_descriptors(patch_size: Vector2) -> Array[Dictionary]:
	match mode:
		Mode.GRID:
			return _build_grid(patch_size)
		Mode.LINEAR:
			return _build_linear(patch_size)
		Mode.ISLANDS:
			return _build_islands(patch_size)
		_:
			return [_descriptor(Vector3.ZERO, 1.0, false)]


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if mode == Mode.GRID and (grid_size.x <= 0 or grid_size.y <= 0):
		errors.append("grid_size components must be positive.")

	if mode == Mode.ISLANDS:
		if island_spread.x <= 0.0 or island_spread.y <= 0.0:
			errors.append("island_spread components must be positive.")
		if island_scale_range.x <= 0.0:
			errors.append("island_scale_range minimum must be positive.")
		if island_scale_range.x > island_scale_range.y:
			errors.append("island_scale_range minimum must not exceed maximum.")

	return errors


func _build_grid(patch_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var step := patch_size + Vector2.ONE * patch_gap
	var offset := Vector2(
		float(grid_size.x - 1) * step.x * 0.5,
		float(grid_size.y - 1) * step.y * 0.5,
	)

	for z: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var position := Vector3(
				float(x) * step.x - offset.x,
				0.0,
				float(z) * step.y - offset.y,
			)
			result.append(_descriptor(position, 1.0, false))

	return result


func _build_linear(patch_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var length := patch_size.x if linear_axis == Axis.X else patch_size.y
	length += patch_gap
	var start := 0.0

	if linear_centered:
		start = -float(linear_count - 1) * length * 0.5

	for index: int in range(linear_count):
		var distance := start + float(index) * length
		var position := Vector3.ZERO

		if linear_axis == Axis.X:
			position.x = distance
		else:
			position.z = distance

		result.append(_descriptor(position, 1.0, false))

	return result


func _build_islands(patch_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for _index: int in range(island_count):
		var accepted := false
		var candidate := Vector2.ZERO
		var scale := 1.0

		for _attempt: int in range(island_placement_attempts):
			scale = rng.randf_range(
				island_scale_range.x,
				island_scale_range.y,
			)
			candidate = Vector2(
				rng.randf_range(-island_spread.x * 0.5, island_spread.x * 0.5),
				rng.randf_range(-island_spread.y * 0.5, island_spread.y * 0.5),
			)

			if _is_island_position_valid(result, candidate, patch_size, scale):
				accepted = true
				break

		if accepted:
			result.append(
				_descriptor(
					Vector3(candidate.x, 0.0, candidate.y),
					scale,
					true,
				)
			)

	return result


func _is_island_position_valid(
	existing: Array[Dictionary],
	candidate: Vector2,
	patch_size: Vector2,
	scale: float,
) -> bool:
	var candidate_radius := maxf(patch_size.x, patch_size.y) * scale * 0.5

	for descriptor: Dictionary in existing:
		var position: Vector3 = descriptor["position"]
		var other_scale: float = descriptor["scale"]
		var other_radius := maxf(patch_size.x, patch_size.y) * other_scale * 0.5
		var separation := candidate_radius + other_radius + island_min_separation

		if candidate.distance_to(Vector2(position.x, position.z)) < separation:
			return false

	return true


func _descriptor(
	position: Vector3,
	scale: float,
	force_island: bool,
) -> Dictionary:
	return {
		"position": position,
		"scale": scale,
		"force_island": force_island,
	}
