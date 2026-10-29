@tool
class_name NucleusTerrainGenerator3D
extends Node3D
## Scene-owned editor/runtime terrain generation with cheap 3D previews.

signal generation_started
signal patch_generated(index: int, patch: Node3D)
signal generation_completed(patch_count: int)
signal generation_failed(error: Error, message: String)

const PatchBuilder := preload(
	"res://addons/nucleus/modules/terrain/terrain_patch_builder.gd"
)
const WIREFRAME_SHADER := preload(
	"res://addons/nucleus/modules/terrain/shaders/terrain_wireframe.gdshader"
)

const GENERATED_ROOT: StringName = &"GeneratedTerrain"
const PREVIEW_ROOT: StringName = &"__TerrainPreview"

@export var profile: NucleusTerrainProfile:
	set(value):
		_disconnect_resource(profile)
		profile = value
		_connect_resource(profile)
		update_configuration_warnings()
		_request_auto_preview()

@export var layout: NucleusTerrainLayout:
	set(value):
		_disconnect_resource(layout)
		layout = value
		_connect_resource(layout)
		update_configuration_warnings()
		_request_auto_preview()

@export var material_profile: NucleusTerrainMaterialProfile:
	set(value):
		_disconnect_resource(material_profile)
		material_profile = value
		_connect_resource(material_profile)
		update_configuration_warnings()
		_request_auto_preview()

@export_group("Editor preview")
@export var auto_preview_on_change: bool = false
@export_range(4, 128, 1)
var preview_resolution: int = 24
@export var preview_uses_material: bool = true

@export_group("Runtime generation")
@export_range(1, 32, 1)
var patches_per_frame: int = 1

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
		_request_debug_refresh()
@export var debug_wireframe: bool = false:
	set(value):
		debug_wireframe = value
		_request_debug_refresh()
@export_range(2, 16, 1)
var debug_height_bands: int = 6:
	set(value):
		debug_height_bands = maxi(2, value)
		_request_debug_refresh()
@export_range(0.1, 1000.0, 0.1, "or_greater")
var debug_grid_scale: float = 10.0:
	set(value):
		debug_grid_scale = maxf(0.1, value)
		_request_debug_refresh()
@export var debug_wireframe_color: Color = Color(0.04, 0.04, 0.04, 1.0):
	set(value):
		debug_wireframe_color = value
		_request_debug_refresh()

@export_tool_button("Refresh Preview")
var refresh_preview_action: Callable = refresh_preview
@export_tool_button("Generate Terrain")
var generate_terrain_action: Callable = generate_terrain
@export_tool_button("Clear Generated Terrain")
var clear_generated_action: Callable = clear_generated

var _is_generating: bool = false
var _auto_preview_queued: bool = false
var _debug_refresh_queued: bool = false


func _ready() -> void:
	_connect_resource(profile)
	_connect_resource(layout)
	_connect_resource(material_profile)
	_request_debug_refresh()


func _exit_tree() -> void:
	_disconnect_resource(profile)
	_disconnect_resource(layout)
	_disconnect_resource(material_profile)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if profile == null:
		warnings.append("Assign a NucleusTerrainProfile before generating terrain.")
	elif not profile.get_validation_errors().is_empty():
		warnings.append("Terrain profile contains validation errors.")

	if layout != null and not layout.get_validation_errors().is_empty():
		warnings.append("Terrain layout contains validation errors.")

	if material_profile != null:
		if material_profile.custom_material == null:
			if material_profile.get_active_layer_count() == 0:
				warnings.append(
					"Terrain material has no active layers; only base_color will render."
				)
		elif debug_view == NucleusTerrainMaterialProfile.DebugView.LAYER_WEIGHTS:
			warnings.append(
				"Layer Weights debug uses the built-in terrain shader, not custom_material."
			)

	return warnings


func is_generating() -> bool:
	return _is_generating


func set_debug_view(value: int) -> void:
	debug_view = value


func set_debug_wireframe(enabled: bool) -> void:
	debug_wireframe = enabled


func get_debug_snapshot() -> Dictionary:
	if profile == null:
		return {}

	var patch_count := _count_meshes(GENERATED_ROOT)
	if patch_count == 0:
		patch_count = _count_meshes(PREVIEW_ROOT)

	var active_layers := 0
	var projection := "Default"

	if material_profile != null:
		active_layers = material_profile.get_active_layer_count()
		projection = "Triplanar" if material_profile.projection_mode == 1 else "Top"

	return {
		"debug_view": debug_view,
		"wireframe": debug_wireframe,
		"patch_count": patch_count,
		"resolution": profile.resolution,
		"triangles_per_patch": profile.resolution * profile.resolution * 2,
		"estimated_base_triangles": (
			patch_count * profile.resolution * profile.resolution * 2
		),
		"collision_resolution": profile.collision_resolution,
		"collision_samples_per_patch": (
			(profile.collision_resolution + 1)
			* (profile.collision_resolution + 1)
		),
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
	else:
		var layer_count := material_profile.get_active_layer_count()
		if layer_count == 0 and material_profile.custom_material == null:
			messages.append("Built-in material has no active texture/color layers.")
		if material_profile.projection_mode == 1 and layer_count >= 3:
			messages.append(
				"Triplanar with 3+ active layers is expensive on weak integrated GPUs."
			)

	if debug_view == NucleusTerrainMaterialProfile.DebugView.LAYER_WEIGHTS:
		if material_profile == null or material_profile.get_active_layer_count() == 0:
			messages.append("Layer Weights has no active layers to visualize.")

	if profile.collision_resolution > profile.resolution:
		messages.append("Collision resolution is higher than visual resolution.")

	if profile.resolution > 128:
		messages.append("Visual resolution above 128 cells is expensive per patch.")

	if profile.cast_shadows:
		messages.append("Terrain shadow casting is enabled.")

	if messages.is_empty():
		messages.append("No obvious terrain configuration issue detected.")

	return messages


func refresh_preview() -> Error:
	if profile == null:
		return ERR_UNCONFIGURED

	var validation_error := _first_validation_error()
	if validation_error != "":
		return _emit_failure(ERR_INVALID_DATA, validation_error)

	_clear_named_child(PREVIEW_ROOT)
	var root := Node3D.new()
	root.name = PREVIEW_ROOT
	add_child(root)
	var descriptors := _get_descriptors()
	var material := _build_preview_material()
	var overlay := _build_wireframe_overlay()

	for index: int in range(descriptors.size()):
		var descriptor: Dictionary = descriptors[index]
		var result := PatchBuilder.build_patch(
			profile,
			material,
			descriptor["position"],
			descriptor["scale"],
			descriptor["force_island"],
			mini(preview_resolution, profile.resolution),
			false,
			false,
			overlay,
		)

		if result.get("error", FAILED) != OK:
			_clear_named_child(PREVIEW_ROOT)
			return _emit_failure(
				result.get("error", FAILED),
				"Terrain preview patch %d could not be built." % index,
			)

		var patch: Node3D = result["node"]
		patch.name = "PreviewPatch_%03d" % index
		root.add_child(patch)

	return OK


func generate_terrain() -> Error:
	if _is_generating:
		return ERR_BUSY

	if profile == null:
		return ERR_UNCONFIGURED

	var validation_error := _first_validation_error()
	if validation_error != "":
		return _emit_failure(ERR_INVALID_DATA, validation_error)

	_is_generating = true
	generation_started.emit()
	clear_generated()
	var root := Node3D.new()
	root.name = GENERATED_ROOT
	add_child(root)
	var descriptors := _get_descriptors()
	var material := _build_material()

	if descriptors.is_empty():
		_is_generating = false
		_clear_named_child(GENERATED_ROOT)
		return _emit_failure(
			ERR_CANT_CREATE,
			"Terrain layout produced no patches. Check island separation/spread.",
		)

	for index: int in range(descriptors.size()):
		var result := _build_descriptor_patch(descriptors[index], material, index)
		if result != OK:
			_is_generating = false
			_clear_named_child(GENERATED_ROOT)
			return result

	_set_generated_owners(root)
	_is_generating = false
	generation_completed.emit(descriptors.size())
	return OK


func generate_terrain_async() -> void:
	if _is_generating or profile == null:
		return

	var validation_error := _first_validation_error()
	if validation_error != "":
		_emit_failure(ERR_INVALID_DATA, validation_error)
		return

	_is_generating = true
	generation_started.emit()
	clear_generated()
	var root := Node3D.new()
	root.name = GENERATED_ROOT
	add_child(root)
	var descriptors := _get_descriptors()
	var material := _build_material()

	if descriptors.is_empty():
		_is_generating = false
		_clear_named_child(GENERATED_ROOT)
		_emit_failure(
			ERR_CANT_CREATE,
			"Terrain layout produced no patches. Check island separation/spread.",
		)
		return

	var built_this_frame := 0

	for index: int in range(descriptors.size()):
		var result := _build_descriptor_patch(descriptors[index], material, index)
		if result != OK:
			_is_generating = false
			_clear_named_child(GENERATED_ROOT)
			return

		built_this_frame += 1
		if built_this_frame >= patches_per_frame and index < descriptors.size() - 1:
			built_this_frame = 0
			await get_tree().process_frame

	_set_generated_owners(root)
	_is_generating = false
	generation_completed.emit(descriptors.size())


func clear_preview() -> void:
	_clear_named_child(PREVIEW_ROOT)


func clear_generated() -> void:
	_clear_named_child(GENERATED_ROOT)


func _build_descriptor_patch(
	descriptor: Dictionary,
	material: Material,
	index: int,
) -> Error:
	var root := get_node_or_null(NodePath(String(GENERATED_ROOT))) as Node3D
	if root == null:
		return _emit_failure(ERR_UNCONFIGURED, "Generated terrain root disappeared.")

	var result := PatchBuilder.build_patch(
		profile,
		material,
		descriptor["position"],
		descriptor["scale"],
		descriptor["force_island"],
		0,
		true,
		true,
		_build_wireframe_overlay(),
	)

	if result.get("error", FAILED) != OK:
		return _emit_failure(
			result.get("error", FAILED),
			"Terrain patch %d could not be built." % index,
		)

	var patch: Node3D = result["node"]
	patch.name = "TerrainPatch_%03d" % index
	patch.set_meta(&"terrain_patch_index", index)
	root.add_child(patch)
	patch_generated.emit(index, patch)
	return OK


func _get_descriptors() -> Array[Dictionary]:
	if layout == null:
		return [
			{
				"position": Vector3.ZERO,
				"scale": 1.0,
				"force_island": false,
			}
		]

	return layout.build_descriptors(profile.size)


func _build_material() -> Material:
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


func _build_preview_material() -> Material:
	if preview_uses_material or debug_view != NucleusTerrainMaterialProfile.DebugView.MATERIAL:
		return _build_material()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.52, 0.24)
	material.roughness = 1.0
	return material


func _build_wireframe_overlay() -> Material:
	if not debug_wireframe:
		return null

	var material := ShaderMaterial.new()
	material.shader = WIREFRAME_SHADER
	material.set_shader_parameter("wire_color", debug_wireframe_color)
	return material


func _first_validation_error() -> String:
	for error: String in profile.get_validation_errors():
		return "Terrain profile: %s" % error

	if layout != null:
		for error: String in layout.get_validation_errors():
			return "Terrain layout: %s" % error

	if material_profile != null:
		for error: String in material_profile.get_validation_errors():
			return "Terrain material: %s" % error

	return ""


func _emit_failure(error: Error, message: String) -> Error:
	generation_failed.emit(error, message)
	NucleusLog.error(
		"%s (%s)" % [message, error_string(error)],
		&"Terrain",
	)
	return error


func _clear_named_child(child_name: StringName) -> void:
	var child := get_node_or_null(NodePath(String(child_name)))
	if child == null:
		return
	remove_child(child)
	child.queue_free()


func _set_generated_owners(root: Node) -> void:
	if not Engine.is_editor_hint() or get_tree().edited_scene_root == null:
		return

	_set_owner_recursive(root, get_tree().edited_scene_root)


func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child: Node in node.get_children():
		_set_owner_recursive(child, owner)


func _connect_resource(resource: Resource) -> void:
	if resource == null or resource.changed.is_connected(_on_resource_changed):
		return
	resource.changed.connect(_on_resource_changed)


func _disconnect_resource(resource: Resource) -> void:
	if resource == null or not resource.changed.is_connected(_on_resource_changed):
		return
	resource.changed.disconnect(_on_resource_changed)


func _on_resource_changed() -> void:
	update_configuration_warnings()
	_request_auto_preview()
	_request_debug_refresh()


func _request_auto_preview() -> void:
	if not Engine.is_editor_hint() or not auto_preview_on_change:
		return
	if _auto_preview_queued or not is_inside_tree():
		return
	_auto_preview_queued = true
	call_deferred("_run_auto_preview")


func _run_auto_preview() -> void:
	_auto_preview_queued = false
	refresh_preview()


func _request_debug_refresh() -> void:
	if _debug_refresh_queued or not is_inside_tree():
		return
	_debug_refresh_queued = true
	call_deferred("_apply_debug_to_existing")


func _apply_debug_to_existing() -> void:
	_debug_refresh_queued = false

	_apply_material_to_root(
		PREVIEW_ROOT,
		_build_preview_material(),
		_build_wireframe_overlay(),
	)
	_apply_material_to_root(
		GENERATED_ROOT,
		_build_material(),
		_build_wireframe_overlay(),
	)
	update_configuration_warnings()


func _apply_material_to_root(
	root_name: StringName,
	material: Material,
	overlay: Material,
) -> void:
	var root := get_node_or_null(NodePath(String(root_name)))
	if root == null:
		return

	_apply_material_recursive(root, material, overlay)


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


func _count_meshes(root_name: StringName) -> int:
	var root := get_node_or_null(NodePath(String(root_name)))
	if root == null:
		return 0

	return _count_meshes_recursive(root)


func _count_meshes_recursive(node: Node) -> int:
	var count := 0

	if node is MeshInstance3D and node.name == &"TerrainMesh":
		count += 1

	for child: Node in node.get_children():
		count += _count_meshes_recursive(child)

	return count
