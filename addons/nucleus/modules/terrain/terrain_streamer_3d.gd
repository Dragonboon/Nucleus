class_name NucleusTerrainStreamer3D
extends Node3D
## Lightweight linear runtime chunk streaming for long traversal games.

signal chunk_loaded(index: int, chunk: Node3D)
signal chunk_unloaded(index: int)

const PatchBuilder := preload(
	"res://addons/nucleus/modules/terrain/terrain_patch_builder.gd"
)
const WIREFRAME_SHADER: Shader = preload(
	"res://addons/nucleus/modules/terrain/shaders/terrain_wireframe.gdshader"
)

@export var profile: NucleusTerrainProfile
@export var material_profile: NucleusTerrainMaterialProfile
@export var tracked_node: Node3D
@export_enum("X", "Z")
var axis: int = NucleusTerrainLayout.Axis.Z
@export_range(0, 32, 1)
var chunks_behind: int = 2
@export_range(0, 32, 1)
var chunks_ahead: int = 4
@export_range(0.0, 10000.0, 0.1)
var patch_gap: float = 0.0
@export_range(0.02, 10.0, 0.01, "or_greater")
var update_interval: float = 0.25
@export_range(1, 8, 1)
var max_new_chunks_per_update: int = 1

@export_group("Prototype / debug")
@export_enum(
	"Material",
	"Height bands",
	"Slope",
	"Normals",
	"Layer weights",
	"World grid",
)
var debug_view: int = NucleusTerrainMaterialProfile.DebugView.MATERIAL:
	set(value):
		debug_view = clampi(value, 0, 5)
		_refresh_existing_materials()
@export var debug_wireframe: bool = false:
	set(value):
		debug_wireframe = value
		_refresh_existing_materials()
@export_range(2, 16, 1)
var debug_height_bands: int = 6:
	set(value):
		debug_height_bands = maxi(2, value)
		_refresh_existing_materials()
@export_range(0.1, 1000.0, 0.1, "or_greater")
var debug_grid_scale: float = 10.0:
	set(value):
		debug_grid_scale = maxf(0.1, value)
		_refresh_existing_materials()
@export var debug_wireframe_color: Color = Color(0.04, 0.04, 0.04, 1.0):
	set(value):
		debug_wireframe_color = value
		_refresh_existing_materials()

var _chunks: Dictionary[int, Node3D] = {}
var _pending: Array[int] = []
var _elapsed: float = 0.0
var _last_center_index: int = 2147483647
var _material: Material


func _ready() -> void:
	set_process(false)
	call_deferred("_initialize_streamer")


func _initialize_streamer() -> void:
	var missing := PackedStringArray()

	if profile == null:
		missing.append("profile")

	if tracked_node == null or not is_instance_valid(tracked_node):
		missing.append("tracked_node")

	if not missing.is_empty():
		NucleusLog.error(
			"Terrain streamer cannot start; missing: %s."
			% ", ".join(missing),
			&"Terrain",
		)
		return

	_material = _create_material()
	_update_stream(true)
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	_update_stream(false)


func set_debug_view(value: int) -> void:
	debug_view = value


func set_debug_wireframe(enabled: bool) -> void:
	debug_wireframe = enabled


func clear_chunks() -> void:
	_pending.clear()

	for index: int in _chunks.keys():
		var chunk: Node3D = _chunks[index]
		_chunks.erase(index)
		if is_instance_valid(chunk):
			chunk.queue_free()
		chunk_unloaded.emit(index)


func get_loaded_chunk_count() -> int:
	return _chunks.size()


func get_pending_chunk_count() -> int:
	return _pending.size()


func get_loaded_chunk_indices() -> Array[int]:
	var indices: Array[int] = []

	for index: int in _chunks.keys():
		indices.append(index)

	indices.sort()
	return indices


func get_center_chunk_index() -> int:
	if profile == null or tracked_node == null:
		return 0

	return _get_chunk_index(tracked_node.global_position)


func get_debug_snapshot() -> Dictionary:
	if profile == null:
		return {}

	var active_layers := 0
	var projection := "Default"

	if material_profile != null:
		active_layers = material_profile.get_active_layer_count()
		projection = "Triplanar" if material_profile.projection_mode == 1 else "Top"

	return {
		"debug_view": debug_view,
		"wireframe": debug_wireframe,
		"loaded_chunks": _chunks.size(),
		"pending_chunks": _pending.size(),
		"center_chunk": get_center_chunk_index(),
		"resolution": profile.resolution,
		"triangles_per_chunk": profile.resolution * profile.resolution * 2,
		"lod_levels": profile.lod_levels,
		"active_material_layers": active_layers,
		"projection": projection,
	}


func get_live_diagnostics() -> PackedStringArray:
	var messages := PackedStringArray()

	if profile == null:
		messages.append("No terrain profile is assigned.")
		return messages

	if material_profile == null:
		messages.append("No material profile: terrain uses the fallback base material.")
	elif material_profile.projection_mode == 1:
		if material_profile.get_active_layer_count() >= 3:
			messages.append(
				"Triplanar with 3+ active layers is expensive on weak integrated GPUs."
			)

	if profile.resolution > 128:
		messages.append("Visual resolution above 128 cells is expensive per chunk.")

	if max_new_chunks_per_update > 2:
		messages.append("Building more than two new chunks per update can spike CPU time.")

	if messages.is_empty():
		messages.append("No obvious terrain streaming issue detected.")

	return messages


func _update_stream(force: bool) -> void:
	var center: int = _get_chunk_index(tracked_node.global_position)

	if not force and center == _last_center_index and _pending.is_empty():
		return

	_last_center_index = center
	var minimum: int = center - chunks_behind
	var maximum: int = center + chunks_ahead
	var remove_indices: Array[int] = []

	for index: int in _chunks.keys():
		if index < minimum or index > maximum:
			remove_indices.append(index)

	for index: int in remove_indices:
		var chunk: Node3D = _chunks[index]
		_chunks.erase(index)
		if is_instance_valid(chunk):
			chunk.queue_free()
		chunk_unloaded.emit(index)

	for index: int in range(minimum, maximum + 1):
		if not _chunks.has(index) and not _pending.has(index):
			_pending.append(index)

	_pending.sort_custom(
		func(left: int, right: int) -> bool:
			return absi(left - center) < absi(right - center)
	)

	var build_count: int = mini(max_new_chunks_per_update, _pending.size())
	for _iteration: int in range(build_count):
		var index: int = _pending.pop_front()
		_build_chunk(index)


func _build_chunk(index: int) -> void:
	var chunk_position: Vector3 = _get_chunk_position(index)
	var result: Dictionary = PatchBuilder.build_patch(
		profile,
		_material,
		chunk_position,
		1.0,
		false,
		0,
		true,
		true,
		_build_wireframe_overlay(),
	)

	if result.get("error", FAILED) != OK:
		NucleusLog.error(
			"Terrain streamer could not build chunk %d: %s"
			% [index, error_string(result.get("error", FAILED))],
			&"Terrain",
		)
		return

	var chunk: Node3D = result["node"]
	chunk.name = "TerrainChunk_%d" % index
	chunk.set_meta(&"terrain_chunk_index", index)
	add_child(chunk)
	_chunks[index] = chunk
	chunk_loaded.emit(index, chunk)


func _get_chunk_index(world_position: Vector3) -> int:
	var length: float = (
		profile.size.x
		if axis == NucleusTerrainLayout.Axis.X
		else profile.size.y
	)
	length += patch_gap
	var coordinate: float = (
		world_position.x
		if axis == NucleusTerrainLayout.Axis.X
		else world_position.z
	)
	return int(floor(coordinate / maxf(length, 0.001)))


func _get_chunk_position(index: int) -> Vector3:
	var length: float = (
		profile.size.x
		if axis == NucleusTerrainLayout.Axis.X
		else profile.size.y
	)
	length += patch_gap
	var chunk_position: Vector3 = Vector3.ZERO

	if axis == NucleusTerrainLayout.Axis.X:
		chunk_position.x = float(index) * length
	else:
		chunk_position.z = float(index) * length

	return chunk_position


func _create_material() -> Material:
	if material_profile != null:
		return material_profile.create_material(
			profile.minimum_expected_height(),
			profile.maximum_expected_height(),
			debug_view,
			debug_height_bands,
			debug_grid_scale,
		)

	if debug_view != NucleusTerrainMaterialProfile.DebugView.MATERIAL:
		var debug_profile := NucleusTerrainMaterialProfile.new()
		return debug_profile.create_material(
			profile.minimum_expected_height(),
			profile.maximum_expected_height(),
			debug_view,
			debug_height_bands,
			debug_grid_scale,
		)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.38, 0.18)
	material.roughness = 1.0
	return material


func _build_wireframe_overlay() -> Material:
	if not debug_wireframe:
		return null

	var material := ShaderMaterial.new()
	material.shader = WIREFRAME_SHADER
	material.set_shader_parameter("wire_color", debug_wireframe_color)
	return material


func _refresh_existing_materials() -> void:
	if not is_inside_tree() or profile == null:
		return

	_material = _create_material()
	var overlay := _build_wireframe_overlay()

	for chunk: Node3D in _chunks.values():
		if is_instance_valid(chunk):
			_apply_material_recursive(chunk, _material, overlay)


func _apply_material_recursive(
	node: Node,
	material: Material,
	overlay: Material,
) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.name == &"TerrainMesh":
			mesh_instance.material_override = material
			mesh_instance.material_overlay = overlay

	for child: Node in node.get_children():
		_apply_material_recursive(child, material, overlay)
