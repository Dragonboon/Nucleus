class_name NucleusTerrainBuildJob
extends NucleusMaterializationJob
## Incrementally builds one terrain patch on the main thread.
##
## Height sampling, surface arrays, indices, LODs, and heightmap collision are
## processed in bounded row batches. Native ArrayMesh/Shape creation remains a
## single finalization step and should still be profiled on target hardware.

const HeightSampler := preload(
	"res://addons/nucleus/modules/terrain/terrain_height_sampler.gd"
)

enum Stage {
	PREPARE,
	SAMPLE_VISUAL,
	BUILD_SURFACE,
	BUILD_BASE_INDICES,
	BUILD_LODS,
	CREATE_MESH,
	SAMPLE_COLLISION,
	PROCESS_COLLISION,
	CREATE_COLLISION,
	FINALIZE,
}

var rows_per_step: int = 8

var profile: NucleusTerrainProfile
var material: Material
var patch_position: Vector3 = Vector3.ZERO
var patch_scale: float = 1.0
var force_island: bool = false
var resolution_override: int = 0
var with_collision: bool = true
var include_lods: bool = true
var material_overlay: Material

var _stage: int = Stage.PREPARE
var _sampler: RefCounted
var _cells: int = 0
var _size: Vector2 = Vector2.ZERO
var _heights := PackedFloat32Array()
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _base_indices := PackedInt32Array()
var _visual_row: int = 0
var _surface_row: int = 0
var _base_index_z: int = 0

var _lod_steps: Array[int] = []
var _lod_level_index: int = 0
var _lod_z: int = 0
var _lod_indices := PackedInt32Array()
var _lods: Dictionary = {}

var _mesh: ArrayMesh

var _collision_cells_x: int = 0
var _collision_cells_z: int = 0
var _collision_size: Vector2 = Vector2.ZERO
var _collision_uniform_scale: float = 1.0
var _collision_heights := PackedFloat32Array()
var _collision_sample_row: int = 0
var _collision_process_row: int = 0
var _collision_shape: Shape3D


func configure(
	terrain_profile: NucleusTerrainProfile,
	surface_material: Material,
	position: Vector3,
	scale: float = 1.0,
	island: bool = false,
	override_resolution: int = 0,
	build_collision: bool = true,
	build_lods: bool = true,
	overlay_material: Material = null,
) -> Error:
	if get_state() != State.PENDING:
		return ERR_BUSY

	if terrain_profile == null or scale <= 0.0:
		return ERR_INVALID_PARAMETER

	profile = terrain_profile
	material = surface_material
	patch_position = position
	patch_scale = scale
	force_island = island
	resolution_override = override_resolution
	with_collision = build_collision
	include_lods = build_lods
	material_overlay = overlay_material
	return OK


func _step_job() -> Error:
	match _stage:
		Stage.PREPARE:
			return _prepare()
		Stage.SAMPLE_VISUAL:
			return _sample_visual()
		Stage.BUILD_SURFACE:
			return _build_surface()
		Stage.BUILD_BASE_INDICES:
			return _build_base_indices()
		Stage.BUILD_LODS:
			return _build_lods()
		Stage.CREATE_MESH:
			return _create_mesh()
		Stage.SAMPLE_COLLISION:
			return _sample_collision()
		Stage.PROCESS_COLLISION:
			return _process_collision()
		Stage.CREATE_COLLISION:
			return _create_collision()
		Stage.FINALIZE:
			return _finalize_patch()
		_:
			return ERR_BUG


func _prepare() -> Error:
	if profile == null:
		return ERR_UNCONFIGURED

	if not profile.get_validation_errors().is_empty():
		return ERR_INVALID_DATA

	_cells = (
		profile.resolution
		if resolution_override <= 0
		else resolution_override
	)
	_cells = maxi(_cells, 2)
	_size = profile.size * patch_scale

	_sampler = HeightSampler.new()
	var sampler_error: Error = _sampler.configure(profile)

	if sampler_error != OK:
		return sampler_error

	_heights.resize((_cells + 1) * (_cells + 1))
	_vertices.resize((_cells + 1) * (_cells + 1))
	_normals.resize((_cells + 1) * (_cells + 1))
	_uvs.resize((_cells + 1) * (_cells + 1))

	_prepare_lod_steps()
	_prepare_collision_grid()
	set_progress(0, _calculate_total_work_units())
	advance_progress()
	_stage = Stage.SAMPLE_VISUAL
	return OK


func _sample_visual() -> Error:
	var end_row := mini(
		_visual_row + maxi(rows_per_step, 1),
		_cells + 1,
	)

	for z: int in range(_visual_row, end_row):
		for x: int in range(_cells + 1):
			var local_position := Vector2(
				lerpf(
					-_size.x * 0.5,
					_size.x * 0.5,
					float(x) / float(_cells),
				),
				lerpf(
					-_size.y * 0.5,
					_size.y * 0.5,
					float(z) / float(_cells),
				),
			)
			_heights[z * (_cells + 1) + x] = _sampler.sample_height(
				local_position,
				_size,
				Vector2(
					patch_position.x,
					patch_position.z,
				),
				force_island,
			)

	var processed := end_row - _visual_row
	_visual_row = end_row
	advance_progress(processed)

	if _visual_row >= _cells + 1:
		_stage = Stage.BUILD_SURFACE

	return OK


func _build_surface() -> Error:
	var end_row := mini(
		_surface_row + maxi(rows_per_step, 1),
		_cells + 1,
	)
	var cell_x := _size.x / float(_cells)
	var cell_z := _size.y / float(_cells)

	for z: int in range(_surface_row, end_row):
		for x: int in range(_cells + 1):
			var index := z * (_cells + 1) + x
			_vertices[index] = Vector3(
				-_size.x * 0.5 + float(x) * cell_x,
				_heights[index],
				-_size.y * 0.5 + float(z) * cell_z,
			)
			_uvs[index] = Vector2(
				float(x) / float(_cells),
				float(z) / float(_cells),
			)
			_normals[index] = _normal_from_grid(
				x,
				z,
				cell_x,
				cell_z,
			)

	var processed := end_row - _surface_row
	_surface_row = end_row
	advance_progress(processed)

	if _surface_row >= _cells + 1:
		_stage = Stage.BUILD_BASE_INDICES

	return OK


func _build_base_indices() -> Error:
	var result := _append_index_rows(
		_base_indices,
		1,
		_base_index_z,
		maxi(rows_per_step, 1),
	)
	var next_z := int(result["next_z"])
	var processed := int(result["processed_rows"])
	_base_index_z = next_z
	advance_progress(processed)

	if _base_index_z >= _cells:
		_stage = Stage.BUILD_LODS

	return OK


func _build_lods() -> Error:
	if _lod_level_index >= _lod_steps.size():
		_stage = Stage.CREATE_MESH
		return OK

	var step := _lod_steps[_lod_level_index]
	var result := _append_index_rows(
		_lod_indices,
		step,
		_lod_z,
		maxi(rows_per_step, 1),
	)
	var next_z := int(result["next_z"])
	var processed := int(result["processed_rows"])
	_lod_z = next_z
	advance_progress(processed)

	if _lod_z >= _cells:
		var distance := (
			profile.lod_distance_step
			* float(_lod_level_index + 1)
		)
		_lods[distance] = _lod_indices
		_lod_indices = PackedInt32Array()
		_lod_z = 0
		_lod_level_index += 1

	return OK


func _create_mesh() -> Error:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _base_indices

	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays,
		[],
		_lods,
	)
	advance_progress()

	if (
		not with_collision
		or profile.collision_mode
		== NucleusTerrainProfile.CollisionMode.DISABLED
	):
		_stage = Stage.FINALIZE
	elif (
		profile.collision_mode
		== NucleusTerrainProfile.CollisionMode.HEIGHTMAP
	):
		_stage = Stage.SAMPLE_COLLISION
	else:
		_stage = Stage.CREATE_COLLISION

	return OK


func _sample_collision() -> Error:
	var end_row := mini(
		_collision_sample_row + maxi(rows_per_step, 1),
		_collision_cells_z + 1,
	)

	for z: int in range(_collision_sample_row, end_row):
		for x: int in range(_collision_cells_x + 1):
			var local_position := Vector2(
				lerpf(
					-_collision_size.x * 0.5,
					_collision_size.x * 0.5,
					float(x) / float(_collision_cells_x),
				),
				lerpf(
					-_collision_size.y * 0.5,
					_collision_size.y * 0.5,
					float(z) / float(_collision_cells_z),
				),
			)
			var index := z * (_collision_cells_x + 1) + x
			_collision_heights[index] = _sampler.sample_height(
				local_position,
				_collision_size,
				Vector2(
					patch_position.x,
					patch_position.z,
				),
				force_island,
			)

	var processed := end_row - _collision_sample_row
	_collision_sample_row = end_row
	advance_progress(processed)

	if _collision_sample_row >= _collision_cells_z + 1:
		_stage = Stage.PROCESS_COLLISION

	return OK


func _process_collision() -> Error:
	var end_row := mini(
		_collision_process_row + maxi(rows_per_step, 1),
		_collision_cells_z + 1,
	)

	for z: int in range(_collision_process_row, end_row):
		for x: int in range(_collision_cells_x + 1):
			var index := z * (_collision_cells_x + 1) + x
			var world_height := _collision_heights[index]

			if (
				profile.collision_holes_below_height
				and world_height < profile.collision_hole_height
			):
				_collision_heights[index] = NAN
			else:
				_collision_heights[index] = (
					world_height / _collision_uniform_scale
				)

	var processed := end_row - _collision_process_row
	_collision_process_row = end_row
	advance_progress(processed)

	if _collision_process_row >= _collision_cells_z + 1:
		_stage = Stage.CREATE_COLLISION

	return OK


func _create_collision() -> Error:
	if (
		profile.collision_mode
		== NucleusTerrainProfile.CollisionMode.HEIGHTMAP
	):
		var shape := HeightMapShape3D.new()
		shape.map_width = _collision_cells_x + 1
		shape.map_depth = _collision_cells_z + 1
		shape.map_data = _collision_heights
		_collision_shape = shape
	else:
		_collision_shape = _mesh.create_trimesh_shape()

		if _collision_shape == null:
			return ERR_CANT_CREATE

	advance_progress()
	_stage = Stage.FINALIZE
	return OK


func _finalize_patch() -> Error:
	var patch := Node3D.new()
	patch.position = patch_position

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = _mesh
	mesh_instance.material_override = material
	mesh_instance.material_overlay = material_overlay
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if profile.cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	patch.add_child(mesh_instance)

	if _collision_shape != null:
		var body := StaticBody3D.new()
		body.name = "TerrainCollision"
		body.collision_layer = profile.collision_layer
		body.collision_mask = profile.collision_mask

		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = _collision_shape

		if (
			profile.collision_mode
			== NucleusTerrainProfile.CollisionMode.HEIGHTMAP
		):
			collision.scale = (
				Vector3.ONE * _collision_uniform_scale
			)

		body.add_child(collision)
		patch.add_child(body)

	advance_progress()
	return complete({
		"error": OK,
		"node": patch,
		"mesh": _mesh,
	})


func _prepare_lod_steps() -> void:
	_lod_steps.clear()

	if not include_lods or profile.lod_levels <= 0:
		return

	var step := 1

	for _level: int in range(1, profile.lod_levels + 1):
		step *= profile.lod_reduction_factor

		if step >= _cells:
			break

		_lod_steps.append(step)


func _prepare_collision_grid() -> void:
	if (
		not with_collision
		or profile.collision_mode
		!= NucleusTerrainProfile.CollisionMode.HEIGHTMAP
	):
		return

	var target_cells := maxi(2, profile.collision_resolution)
	var largest_axis := maxf(_size.x, _size.y)
	_collision_uniform_scale = (
		largest_axis / float(target_cells)
	)
	_collision_cells_x = maxi(
		2,
		int(round(_size.x / _collision_uniform_scale)),
	)
	_collision_cells_z = maxi(
		2,
		int(round(_size.y / _collision_uniform_scale)),
	)
	_collision_size = Vector2(
		float(_collision_cells_x) * _collision_uniform_scale,
		float(_collision_cells_z) * _collision_uniform_scale,
	)
	_collision_heights.resize(
		(_collision_cells_x + 1)
		* (_collision_cells_z + 1)
	)


func _calculate_total_work_units() -> int:
	var total := 1
	total += _cells + 1
	total += _cells + 1
	total += _cells

	for step: int in _lod_steps:
		total += int(ceil(float(_cells) / float(step)))

	total += 1

	if (
		with_collision
		and profile.collision_mode
		== NucleusTerrainProfile.CollisionMode.HEIGHTMAP
	):
		total += _collision_cells_z + 1
		total += _collision_cells_z + 1
		total += 1
	elif (
		with_collision
		and profile.collision_mode
		== NucleusTerrainProfile.CollisionMode.TRIMESH
	):
		total += 1

	total += 1
	return total


func _append_index_rows(
	indices: PackedInt32Array,
	step: int,
	start_z: int,
	maximum_rows: int,
) -> Dictionary:
	var row := _cells + 1
	var z := start_z
	var processed_rows := 0

	while z < _cells and processed_rows < maximum_rows:
		var next_z := mini(z + step, _cells)
		var x := 0

		while x < _cells:
			var next_x := mini(x + step, _cells)
			var a := z * row + x
			var b := z * row + next_x
			var c := next_z * row + x
			var d := next_z * row + next_x
			indices.append_array(
				PackedInt32Array([a, b, c, b, d, c])
			)
			x = next_x

		z = next_z
		processed_rows += 1

	return {
		"next_z": z,
		"processed_rows": processed_rows,
	}


func _normal_from_grid(
	x: int,
	z: int,
	cell_x: float,
	cell_z: float,
) -> Vector3:
	var row := _cells + 1
	var left_x := maxi(0, x - 1)
	var right_x := mini(_cells, x + 1)
	var up_z := maxi(0, z - 1)
	var down_z := mini(_cells, z + 1)
	var left := _heights[z * row + left_x]
	var right := _heights[z * row + right_x]
	var up := _heights[up_z * row + x]
	var down := _heights[down_z * row + x]
	var dx_distance := maxf(
		cell_x * float(right_x - left_x),
		0.000001,
	)
	var dz_distance := maxf(
		cell_z * float(down_z - up_z),
		0.000001,
	)
	var dx := (right - left) / dx_distance
	var dz := (down - up) / dz_distance
	return Vector3(-dx, 1.0, -dz).normalized()
