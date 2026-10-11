class_name NucleusScatterBuildJob3D
extends NucleusMaterializationJob
## Bounded main-thread scatter candidate generation. World-aligned XZ cells.
## Independent seeded cell decisions make neighbouring region borders stable.
## No RenderingServer or PhysicsServer operations are performed by this job.

const HASH_MODULUS: int = 2147483647
const MAX_CELLS: int = 262144

@warning_ignore("shadowed_global_identifier")
var region_id: StringName = &""
var cells_per_step: int = 128

var _profile: NucleusScatterProfile3D
var _surface: NucleusSurfaceSampler3D
var _modulators: Array[NucleusScatterDensityVolume3D] = []
## Optional deterministic main-thread density filter (world XZ -> [0, 1]).
var _density_filter: Callable
var _region_min: Vector2 = Vector2.ZERO
var _region_end: Vector2 = Vector2.ZERO
var _start_cell: Vector2i = Vector2i.ZERO
var _grid_width: int = 0
var _grid_height: int = 0
var _cursor: int = 0
var _groups: Dictionary = {}
var _scratch: NucleusSurfaceSample3D = NucleusSurfaceSample3D.new()
var _accepted_count: int = 0


func configure(
	profile: NucleusScatterProfile3D,
	surface: NucleusSurfaceSampler3D,
	world_minimum_xz: Vector2,
	region_size: Vector2,
	stable_region_id: StringName,
	modulators: Array[NucleusScatterDensityVolume3D] = [],
	density_filter: Callable = Callable(),
) -> Error:
	if get_state() != State.PENDING:
		return ERR_UNAVAILABLE
	if profile == null or surface == null or stable_region_id == &"":
		return ERR_INVALID_PARAMETER
	if not profile.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER
	if (
		not world_minimum_xz.is_finite()
		or not region_size.is_finite()
		or region_size.x <= 0.0
		or region_size.y <= 0.0
	):
		return ERR_INVALID_PARAMETER
	var grid_step: float = profile.grid_spacing
	var cell_min: Vector2i = Vector2i(
		floori(world_minimum_xz.x / grid_step),
		floori(world_minimum_xz.y / grid_step),
	)
	var cell_end: Vector2i = Vector2i(
		ceili((world_minimum_xz.x + region_size.x) / grid_step),
		ceili((world_minimum_xz.y + region_size.y) / grid_step),
	)
	var width: int = cell_end.x - cell_min.x
	var height: int = cell_end.y - cell_min.y
	if (
		width <= 0 or height <= 0
		or width > MAX_CELLS or height > MAX_CELLS
		or width * height > MAX_CELLS
	):
		return ERR_OUT_OF_MEMORY
	_profile = profile
	_surface = surface
	_region_min = world_minimum_xz
	_region_end = world_minimum_xz + region_size
	_start_cell = cell_min
	_grid_width = width
	_grid_height = height
	_cursor = 0
	_accepted_count = 0
	_groups.clear()
	_modulators.assign(modulators)
	_density_filter = density_filter
	region_id = stable_region_id
	set_progress(0, width * height)
	return OK


func _step_job() -> Error:
	if _profile == null or _surface == null:
		return ERR_UNCONFIGURED
	var total: int = _grid_width * _grid_height
	var last: int = mini(total, _cursor + maxi(cells_per_step, 1))
	while _cursor < last:
		var cell: Vector2i = Vector2i(
			_start_cell.x + _cursor % _grid_width,
			_start_cell.y + _cursor / _grid_width,
		)
		_process_cell(cell)
		_cursor += 1
	set_progress(_cursor, total)
	if _cursor == total:
		return complete({
			"region_id": region_id,
			"groups": _groups,
			"accepted_count": _accepted_count,
			"candidate_count": total,
		})
	return OK


func _process_cell(cell: Vector2i) -> void:
	var candidate: Vector2 = _candidate_xz(cell)
	if (
		candidate.x < _region_min.x
		or candidate.y < _region_min.y
		or candidate.x >= _region_end.x
		or candidate.y >= _region_end.y
	):
		return
	if _random(cell, 3) >= _effective_density(candidate):
		return
	if not _wins_spacing(cell, candidate):
		return
	if not _surface.sample_into(
		Vector3(candidate.x, 0.0, candidate.y),
		_scratch,
	):
		return
	if (
		_scratch.position.y < _profile.minimum_height
		or _scratch.position.y > _profile.maximum_height
		or _scratch.normal.dot(Vector3.UP) < cos(_profile.maximum_slope)
	):
		return
	var variant_id: int = _profile.choose_variant(_random(cell, 4))
	if variant_id < 0:
		return
	var up: Vector3 = (
		_scratch.normal if _profile.align_to_normal else Vector3.UP
	)
	var x_axis: Vector3 = Vector3.FORWARD.cross(up).normalized()
	if x_axis.is_zero_approx():
		x_axis = Vector3.RIGHT
	var z_axis: Vector3 = x_axis.cross(up).normalized()
	var rotation_basis: Basis = Basis(x_axis, up, z_axis)
	var yaw: float = _random(cell, 5) * TAU
	rotation_basis = rotation_basis.rotated(up, yaw)
	var scale_value: float = lerpf(
		_profile.scale_min,
		_profile.scale_max,
		_random(cell, 6),
	)
	var transform: Transform3D = Transform3D(
		rotation_basis.scaled(Vector3.ONE * scale_value),
		_scratch.position + up * _profile.vertical_offset,
	)
	if not _groups.has(variant_id):
		_groups[variant_id] = []
	var group: Array = _groups[variant_id]
	group.append(transform)
	_accepted_count += 1


func _wins_spacing(cell: Vector2i, candidate: Vector2) -> bool:
	var minimum: float = _profile.minimum_separation
	if minimum <= 0.0:
		return true
	var radius: int = ceili(minimum / _profile.grid_spacing) + 1
	var own_priority: int = _hash_cell(cell, 7)
	for dz: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx == 0 and dz == 0:
				continue
			var neighbor: Vector2i = cell + Vector2i(dx, dz)
			var position: Vector2 = _candidate_xz(neighbor)
			if position.distance_squared_to(candidate) >= minimum * minimum:
				continue
			if _random(neighbor, 3) >= _effective_density(position):
				continue
			var competitor: int = _hash_cell(neighbor, 7)
			if competitor > own_priority:
				return false
			if competitor == own_priority and _comes_first(neighbor, cell):
				return false
	return true


func _effective_density(world_xz: Vector2) -> float:
	var probability: float = _profile.density
	var world_position: Vector3 = Vector3(world_xz.x, 0.0, world_xz.y)
	for volume: NucleusScatterDensityVolume3D in _modulators:
		if volume != null and is_instance_valid(volume):
			probability *= volume.get_density_multiplier(world_position)
	if _density_filter.is_valid():
		var value: Variant = _density_filter.call(world_xz)
		if not value is int and not value is float:
			return 0.0
		var multiplier: float = float(value)
		if not is_finite(multiplier):
			return 0.0
		probability *= clampf(multiplier, 0.0, 1.0)
	return clampf(probability, 0.0, 1.0)


func _candidate_xz(cell: Vector2i) -> Vector2:
	var spacing: float = _profile.grid_spacing
	return Vector2(
		(float(cell.x) + 0.5 + (_random(cell, 1) - 0.5) * _profile.jitter) * spacing,
		(float(cell.y) + 0.5 + (_random(cell, 2) - 0.5) * _profile.jitter) * spacing,
	)


func _random(cell: Vector2i, salt: int) -> float:
	return float(_hash_cell(cell, salt)) / float(HASH_MODULUS)


func _hash_cell(cell: Vector2i, salt: int) -> int:
	# Keep intermediates below signed 64-bit limits and never rely on hash() salts.
	var code: int = posmod(_profile.seed, HASH_MODULUS - 1) + 1
	code = posmod(code * 48271 + posmod(cell.x, HASH_MODULUS), HASH_MODULUS)
	code = posmod(code * 48271 + posmod(cell.y, HASH_MODULUS), HASH_MODULUS)
	return posmod(code * 48271 + salt * 1259, HASH_MODULUS)


func _comes_first(left: Vector2i, right: Vector2i) -> bool:
	return left.x < right.x or (left.x == right.x and left.y < right.y)
