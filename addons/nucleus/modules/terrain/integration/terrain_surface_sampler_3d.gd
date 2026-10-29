@tool
class_name NucleusTerrainSurfaceSampler3D
extends NucleusSurfaceSampler3D
## Analytical SurfaceSampler3D adapter for NucleusTerrainGenerator3D.
##
## Sampling uses the same internal height source and static layout descriptors as
## generated terrain, so consumers do not need physics raycasts to query height.

const HeightSampler := preload(
	"res://addons/nucleus/modules/terrain/terrain_height_sampler.gd"
)

@export var terrain: NucleusTerrainGenerator3D:
	set(value):
		if terrain == value:
			return

		_disconnect_resources()
		terrain = value
		_mark_dirty()
		update_configuration_warnings()

@export_range(0.001, 100.0, 0.001, "or_greater")
var normal_sample_distance: float = 0.5

var _height_sampler: RefCounted
var _descriptors: Array[Dictionary] = []
var _cached_profile: NucleusTerrainProfile
var _cached_layout: NucleusTerrainLayout
var _dirty: bool = true


func _ready() -> void:
	_resolve_terrain()
	_sync_resource_connections()


func _exit_tree() -> void:
	_disconnect_resources()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var resolved_terrain := terrain

	if resolved_terrain == null:
		resolved_terrain = _find_terrain_ancestor()

	if resolved_terrain == null:
		warnings.append(
			"Assign terrain or place this sampler below a NucleusTerrainGenerator3D."
		)
		return warnings

	if resolved_terrain.profile == null:
		warnings.append("The terrain generator requires a NucleusTerrainProfile.")
	elif not resolved_terrain.profile.get_validation_errors().is_empty():
		warnings.append("The terrain profile contains validation errors.")

	if not _is_transform_world_vertical(resolved_terrain.global_transform.basis):
		warnings.append(
			"Terrain surface sampling requires local +Y to remain aligned with world +Y."
		)

	return warnings


func _sample_surface_into(
	world_position: Vector3,
	out_sample: NucleusSurfaceSample3D,
	at_time: float,
) -> bool:
	_resolve_terrain()

	if not _ensure_cache() or not _is_terrain_transform_supported():
		return false

	var local_query := terrain.to_local(world_position)
	var match := _find_descriptor(local_query)

	if match.is_empty():
		return false

	var descriptor: Dictionary = match["descriptor"]
	var patch_index: int = match["index"]
	var patch_position: Vector3 = descriptor["position"]
	var patch_scale: float = descriptor["scale"]
	var patch_size := _cached_profile.size * patch_scale
	var local_xz := Vector2(
		local_query.x - patch_position.x,
		local_query.z - patch_position.z,
	)
	var sampling_origin := Vector2(
		patch_position.x,
		patch_position.z,
	)
	var force_island: bool = descriptor["force_island"]
	var height := _sample_height(
		local_xz,
		patch_size,
		sampling_origin,
		force_island,
	)
	var local_surface := Vector3(
		local_query.x,
		patch_position.y + height,
		local_query.z,
	)
	var local_normal := _sample_normal(
		local_xz,
		patch_size,
		sampling_origin,
		force_island,
	)
	var normal_basis := terrain.global_transform.basis.inverse().transposed()
	var world_normal := (normal_basis * local_normal).normalized()

	out_sample.set_values(
		terrain.to_global(local_surface),
		world_normal,
		Vector3.ZERO,
		at_time,
		{
			"terrain_patch_index": patch_index,
			"terrain_patch_scale": patch_scale,
		},
	)
	return true


func _ensure_cache() -> bool:
	if terrain == null or terrain.profile == null:
		return false

	_sync_resource_connections()

	if not _dirty and _height_sampler != null:
		return true

	var sampler := HeightSampler.new()
	var error: Error = sampler.configure(terrain.profile)

	if error != OK:
		_height_sampler = null
		_descriptors.clear()
		return false

	_height_sampler = sampler
	_descriptors.clear()

	if terrain.layout != null:
		_descriptors.append_array(
			terrain.layout.build_descriptors(terrain.profile.size)
		)
	else:
		_descriptors.append({
			"position": Vector3.ZERO,
			"scale": 1.0,
			"force_island": false,
		})

	_dirty = false
	return true


func _find_descriptor(local_query: Vector3) -> Dictionary:
	var best := {}
	var best_distance_squared := INF

	for index: int in range(_descriptors.size()):
		var descriptor: Dictionary = _descriptors[index]
		var patch_position: Vector3 = descriptor["position"]
		var patch_scale: float = descriptor["scale"]
		var patch_size := _cached_profile.size * patch_scale
		var half_size := patch_size * 0.5
		var relative := Vector2(
			local_query.x - patch_position.x,
			local_query.z - patch_position.z,
		)

		if (
			absf(relative.x) > half_size.x
			or absf(relative.y) > half_size.y
		):
			continue

		var distance_squared := relative.length_squared()

		if distance_squared >= best_distance_squared:
			continue

		best_distance_squared = distance_squared
		best = {
			"descriptor": descriptor,
			"index": index,
		}

	return best


func _sample_height(
	local_xz: Vector2,
	patch_size: Vector2,
	sampling_origin: Vector2,
	force_island: bool,
) -> float:
	return _height_sampler.sample_height(
		local_xz,
		patch_size,
		sampling_origin,
		force_island,
	)


func _sample_normal(
	local_xz: Vector2,
	patch_size: Vector2,
	sampling_origin: Vector2,
	force_island: bool,
) -> Vector3:
	var half_size := patch_size * 0.5
	var step := maxf(normal_sample_distance, 0.001)
	var left_x := maxf(-half_size.x, local_xz.x - step)
	var right_x := minf(half_size.x, local_xz.x + step)
	var near_z := maxf(-half_size.y, local_xz.y - step)
	var far_z := minf(half_size.y, local_xz.y + step)
	var left := _sample_height(
		Vector2(left_x, local_xz.y),
		patch_size,
		sampling_origin,
		force_island,
	)
	var right := _sample_height(
		Vector2(right_x, local_xz.y),
		patch_size,
		sampling_origin,
		force_island,
	)
	var near_height := _sample_height(
		Vector2(local_xz.x, near_z),
		patch_size,
		sampling_origin,
		force_island,
	)
	var far_height := _sample_height(
		Vector2(local_xz.x, far_z),
		patch_size,
		sampling_origin,
		force_island,
	)
	var dx_distance := maxf(right_x - left_x, 0.000001)
	var dz_distance := maxf(far_z - near_z, 0.000001)
	var dx := (right - left) / dx_distance
	var dz := (far_height - near_height) / dz_distance

	return Vector3(-dx, 1.0, -dz).normalized()


func _resolve_terrain() -> void:
	if terrain != null:
		return

	terrain = _find_terrain_ancestor()


func _find_terrain_ancestor() -> NucleusTerrainGenerator3D:
	var current := get_parent()

	while current != null:
		if current is NucleusTerrainGenerator3D:
			return current as NucleusTerrainGenerator3D

		current = current.get_parent()

	return null


func _is_terrain_transform_supported() -> bool:
	return (
		terrain != null
		and _is_transform_world_vertical(terrain.global_transform.basis)
		and absf(terrain.global_transform.basis.determinant()) > 0.000001
	)


static func _is_transform_world_vertical(basis: Basis) -> bool:
	var local_up := basis.y.normalized()
	return local_up.dot(Vector3.UP) > 0.9999


func _sync_resource_connections() -> void:
	if terrain == null:
		_disconnect_resources()
		return

	var profile_changed := terrain.profile != _cached_profile
	var layout_changed := terrain.layout != _cached_layout

	if not profile_changed and not layout_changed:
		return

	_disconnect_resources()
	_cached_profile = terrain.profile
	_cached_layout = terrain.layout

	if _cached_profile != null:
		_cached_profile.changed.connect(_on_resource_changed)

	if _cached_layout != null:
		_cached_layout.changed.connect(_on_resource_changed)

	_mark_dirty()


func _disconnect_resources() -> void:
	if (
		_cached_profile != null
		and _cached_profile.changed.is_connected(_on_resource_changed)
	):
		_cached_profile.changed.disconnect(_on_resource_changed)

	if (
		_cached_layout != null
		and _cached_layout.changed.is_connected(_on_resource_changed)
	):
		_cached_layout.changed.disconnect(_on_resource_changed)

	_cached_profile = null
	_cached_layout = null


func _mark_dirty() -> void:
	_dirty = true
	_height_sampler = null
	_descriptors.clear()


func _on_resource_changed() -> void:
	_mark_dirty()
	update_configuration_warnings()
