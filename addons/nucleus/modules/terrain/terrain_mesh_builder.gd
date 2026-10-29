extends RefCounted
## Internal direct ArrayMesh builder for procedural heightfields.

const HeightSampler := preload(
	"res://addons/nucleus/modules/terrain/terrain_height_sampler.gd"
)


static func build_mesh(
	profile: NucleusTerrainProfile,
	patch_position: Vector3,
	patch_scale: float = 1.0,
	resolution_override: int = 0,
	force_island: bool = false,
	include_lods: bool = true,
) -> Dictionary:
	if profile == null:
		return {"error": ERR_INVALID_PARAMETER}

	var cells := profile.resolution if resolution_override <= 0 else resolution_override
	cells = maxi(2, cells)
	var size := profile.size * patch_scale
	var sampler := HeightSampler.new()
	var sampler_error: Error = sampler.configure(profile)

	if sampler_error != OK:
		return {"error": sampler_error}

	var grid := _build_height_grid(
		sampler,
		size,
		cells,
		Vector2(patch_position.x, patch_position.z),
		force_island,
	)
	var arrays := _build_surface_arrays(grid, size, cells)
	var lods: Dictionary = {}

	if include_lods and profile.lod_levels > 0:
		lods = _build_lods(profile, cells)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays,
		[],
		lods,
	)

	return {
		"error": OK,
		"mesh": mesh,
		"heights": grid,
		"cells": cells,
		"size": size,
	}


static func build_heightmap_shape(
	profile: NucleusTerrainProfile,
	patch_position: Vector3,
	patch_scale: float,
	force_island: bool,
) -> Dictionary:
	var target_cells := maxi(2, profile.collision_resolution)
	var size := profile.size * patch_scale
	var largest_axis := maxf(size.x, size.y)
	var uniform_scale := largest_axis / float(target_cells)
	var cells_x := maxi(2, int(round(size.x / uniform_scale)))
	var cells_z := maxi(2, int(round(size.y / uniform_scale)))
	var collision_size := Vector2(
		float(cells_x) * uniform_scale,
		float(cells_z) * uniform_scale,
	)
	var sampler := HeightSampler.new()
	var sampler_error: Error = sampler.configure(profile)

	if sampler_error != OK:
		return {"error": sampler_error}

	var heights := _build_height_grid_rect(
		sampler,
		collision_size,
		cells_x,
		cells_z,
		Vector2(patch_position.x, patch_position.z),
		force_island,
	)

	for index: int in range(heights.size()):
		var world_height := heights[index]

		if (
			profile.collision_holes_below_height
			and world_height < profile.collision_hole_height
		):
			heights[index] = NAN
		else:
			heights[index] = world_height / uniform_scale

	var shape := HeightMapShape3D.new()
	shape.map_width = cells_x + 1
	shape.map_depth = cells_z + 1
	shape.map_data = heights

	return {
		"error": OK,
		"shape": shape,
		"cells_x": cells_x,
		"cells_z": cells_z,
		"size": collision_size,
		"uniform_scale": uniform_scale,
	}


static func _build_height_grid(
	sampler: RefCounted,
	size: Vector2,
	cells: int,
	sampling_origin: Vector2,
	force_island: bool,
) -> PackedFloat32Array:
	return _build_height_grid_rect(
		sampler,
		size,
		cells,
		cells,
		sampling_origin,
		force_island,
	)


static func _build_height_grid_rect(
	sampler: RefCounted,
	size: Vector2,
	cells_x: int,
	cells_z: int,
	sampling_origin: Vector2,
	force_island: bool,
) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize((cells_x + 1) * (cells_z + 1))

	for z: int in range(cells_z + 1):
		for x: int in range(cells_x + 1):
			var local_position := Vector2(
				lerpf(-size.x * 0.5, size.x * 0.5, float(x) / float(cells_x)),
				lerpf(-size.y * 0.5, size.y * 0.5, float(z) / float(cells_z)),
			)
			heights[z * (cells_x + 1) + x] = sampler.sample_height(
				local_position,
				size,
				sampling_origin,
				force_island,
			)

	return heights


static func _build_surface_arrays(
	heights: PackedFloat32Array,
	size: Vector2,
	cells: int,
) -> Array:
	var vertex_count := (cells + 1) * (cells + 1)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	var cell_x := size.x / float(cells)
	var cell_z := size.y / float(cells)

	for z: int in range(cells + 1):
		for x: int in range(cells + 1):
			var index := z * (cells + 1) + x
			vertices[index] = Vector3(
				-size.x * 0.5 + float(x) * cell_x,
				heights[index],
				-size.y * 0.5 + float(z) * cell_z,
			)
			uvs[index] = Vector2(float(x) / float(cells), float(z) / float(cells))
			normals[index] = _normal_from_grid(
				heights,
				x,
				z,
				cells,
				cell_x,
				cell_z,
			)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _build_indices(cells, 1)
	return arrays


static func _build_lods(
	profile: NucleusTerrainProfile,
	cells: int,
) -> Dictionary:
	var lods: Dictionary = {}
	var step := 1

	for level: int in range(1, profile.lod_levels + 1):
		step *= profile.lod_reduction_factor
		if step >= cells:
			break
		var distance := profile.lod_distance_step * float(level)
		lods[distance] = _build_indices(cells, step)

	return lods


static func _build_indices(cells: int, step: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var row := cells + 1
	var z := 0

	while z < cells:
		var next_z := mini(z + step, cells)
		var x := 0

		while x < cells:
			var next_x := mini(x + step, cells)
			var a := z * row + x
			var b := z * row + next_x
			var c := next_z * row + x
			var d := next_z * row + next_x
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
			x = next_x

		z = next_z

	return indices


static func _normal_from_grid(
	heights: PackedFloat32Array,
	x: int,
	z: int,
	cells: int,
	cell_x: float,
	cell_z: float,
) -> Vector3:
	var row := cells + 1
	var left_x := maxi(0, x - 1)
	var right_x := mini(cells, x + 1)
	var up_z := maxi(0, z - 1)
	var down_z := mini(cells, z + 1)
	var left := heights[z * row + left_x]
	var right := heights[z * row + right_x]
	var up := heights[up_z * row + x]
	var down := heights[down_z * row + x]
	var dx_distance := maxf(cell_x * float(right_x - left_x), 0.000001)
	var dz_distance := maxf(cell_z * float(down_z - up_z), 0.000001)
	var dx := (right - left) / dx_distance
	var dz := (down - up) / dz_distance

	return Vector3(-dx, 1.0, -dz).normalized()
