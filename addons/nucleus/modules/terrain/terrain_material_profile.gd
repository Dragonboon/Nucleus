@tool
class_name NucleusTerrainMaterialProfile
extends Resource
## Reusable material policy for generated terrain patches.

enum DebugView {
	MATERIAL,
	HEIGHT_BANDS,
	SLOPE,
	NORMALS,
	LAYER_WEIGHTS,
	WORLD_GRID,
}

enum Quality {
	MINIMAL,
	REDUCED,
	FULL,
}

const DEFAULT_SHADER := preload(
	"res://addons/nucleus/modules/terrain/shaders/layered_terrain.gdshader"
)

@export_group("Base")
@export_enum("Top projection", "Triplanar")
var projection_mode: int = 0
@export var base_color: Color = Color(0.24, 0.38, 0.18, 1.0)
@export var layers: Array[NucleusTerrainTextureLayer] = []
@export var custom_material: Material

@export_group("PBR detail distance")
@export var distance_detail_fade: bool = true
@export_range(0.0, 1000000.0, 0.1, "or_greater")
var detail_distance_start: float = 25.0
@export_range(0.0, 1000000.0, 0.1, "or_greater")
var detail_distance_end: float = 100.0

@export_group("Quality")
@export_enum("Minimal", "Reduced", "Full")
var quality: int = Quality.FULL
@export var reduced_uses_triplanar: bool = false
@export var reduced_uses_detail_textures: bool = true
@export var minimal_uses_triplanar: bool = false
@export var minimal_uses_detail_textures: bool = false

@export_group("Material reuse")
@export var reuse_generated_materials: bool = true
@export_range(1, 64, 1)
var material_cache_limit: int = 12

var _material_cache: Dictionary[String, Material] = {}


func create_material(
	minimum_height: float,
	maximum_height: float,
	debug_view: int = DebugView.MATERIAL,
	debug_height_bands: int = 6,
	debug_grid_scale: float = 10.0,
	quality_override: int = -1,
) -> Material:
	if custom_material != null and debug_view == DebugView.MATERIAL:
		return custom_material

	var resolved_quality := (
		clampi(quality, Quality.MINIMAL, Quality.FULL)
		if quality_override < 0
		else clampi(
			quality_override,
			Quality.MINIMAL,
			Quality.FULL,
		)
	)
	var cache_key := _material_cache_key(
		minimum_height,
		maximum_height,
		debug_view,
		debug_height_bands,
		debug_grid_scale,
		resolved_quality,
	)

	if reuse_generated_materials and _material_cache.has(cache_key):
		var cached: Material = _material_cache.get(cache_key) as Material

		if cached != null:
			return cached

	var material := ShaderMaterial.new()
	material.shader = DEFAULT_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("height_min", minimum_height)
	material.set_shader_parameter("height_max", maximum_height)
	material.set_shader_parameter(
		"use_triplanar",
		_quality_uses_triplanar(resolved_quality),
	)
	material.set_shader_parameter(
		"detail_enabled",
		_quality_uses_detail_textures(resolved_quality),
	)
	material.set_shader_parameter(
		"detail_fade_enabled",
		distance_detail_fade,
	)
	material.set_shader_parameter(
		"detail_distance_start",
		maxf(detail_distance_start, 0.0),
	)
	material.set_shader_parameter(
		"detail_distance_end",
		maxf(
			detail_distance_end,
			detail_distance_start + 0.01,
		),
	)
	material.set_shader_parameter("debug_view", debug_view)
	material.set_shader_parameter(
		"debug_height_bands",
		maxi(2, debug_height_bands),
	)
	material.set_shader_parameter(
		"debug_grid_scale",
		maxf(0.1, debug_grid_scale),
	)

	for index: int in range(4):
		_apply_layer(material, index)

	if reuse_generated_materials:
		_store_cached_material(cache_key, material)

	return material


func clear_material_cache() -> void:
	_material_cache.clear()


func get_cached_material_count() -> int:
	return _material_cache.size()


func get_active_layer_count() -> int:
	var count := 0

	for layer: NucleusTerrainTextureLayer in layers:
		if layer != null and layer.enabled:
			count += 1

	return count


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if layers.size() > 4:
		errors.append(
			"The built-in terrain material supports at most four layers."
		)

	if detail_distance_end < detail_distance_start:
		errors.append(
			"detail_distance_end must not be lower than detail_distance_start."
		)

	for index: int in range(layers.size()):
		var layer: NucleusTerrainTextureLayer = layers[index]

		if layer == null:
			errors.append("layers[%d] is null." % index)
			continue

		for error: String in layer.get_validation_errors():
			errors.append("layers[%d]: %s" % [index, error])

	return errors


func _quality_uses_triplanar(resolved_quality: int) -> bool:
	if projection_mode != 1:
		return false

	match resolved_quality:
		Quality.MINIMAL:
			return minimal_uses_triplanar
		Quality.REDUCED:
			return reduced_uses_triplanar
		_:
			return true


func _quality_uses_detail_textures(resolved_quality: int) -> bool:
	match resolved_quality:
		Quality.MINIMAL:
			return minimal_uses_detail_textures
		Quality.REDUCED:
			return reduced_uses_detail_textures
		_:
			return true


func _apply_layer(
	material: ShaderMaterial,
	index: int,
) -> void:
	var prefix := "layer%d_" % index
	var layer: NucleusTerrainTextureLayer = (
		layers[index]
		if index < layers.size()
		else null
	)

	if layer == null or not layer.enabled:
		material.set_shader_parameter(prefix + "enabled", false)
		return

	material.set_shader_parameter(prefix + "enabled", true)
	material.set_shader_parameter(
		prefix + "use_texture",
		layer.albedo != null,
	)
	material.set_shader_parameter(prefix + "albedo", layer.albedo)
	material.set_shader_parameter(prefix + "tint", layer.tint)
	material.set_shader_parameter(prefix + "uv_scale", layer.uv_scale)
	material.set_shader_parameter(
		prefix + "use_normal",
		layer.normal != null,
	)
	material.set_shader_parameter(prefix + "normal", layer.normal)
	material.set_shader_parameter(
		prefix + "normal_strength",
		maxf(layer.normal_strength, 0.0),
	)
	material.set_shader_parameter(
		prefix + "use_roughness_texture",
		layer.roughness_texture != null,
	)
	material.set_shader_parameter(
		prefix + "roughness_texture",
		layer.roughness_texture,
	)
	material.set_shader_parameter(
		prefix + "roughness_texture_strength",
		clampf(layer.roughness_texture_strength, 0.0, 1.0),
	)
	material.set_shader_parameter(
		prefix + "height_range",
		layer.height_range,
	)
	material.set_shader_parameter(
		prefix + "slope_range",
		layer.slope_range,
	)
	material.set_shader_parameter(
		prefix + "softness",
		layer.blend_softness,
	)
	material.set_shader_parameter(
		prefix + "roughness",
		layer.roughness,
	)
	material.set_shader_parameter(
		prefix + "metallic",
		layer.metallic,
	)


func _material_cache_key(
	minimum_height: float,
	maximum_height: float,
	debug_view: int,
	debug_height_bands: int,
	debug_grid_scale: float,
	resolved_quality: int,
) -> String:
	var values := PackedStringArray([
		str(minimum_height),
		str(maximum_height),
		str(debug_view),
		str(debug_height_bands),
		str(debug_grid_scale),
		str(resolved_quality),
		str(projection_mode),
		str(base_color),
		str(distance_detail_fade),
		str(detail_distance_start),
		str(detail_distance_end),
		str(reduced_uses_triplanar),
		str(reduced_uses_detail_textures),
		str(minimal_uses_triplanar),
		str(minimal_uses_detail_textures),
	])

	for layer: NucleusTerrainTextureLayer in layers:
		if layer == null:
			values.append("null")
			continue

		values.append_array(PackedStringArray([
			str(layer.enabled),
			_resource_key(layer.albedo),
			str(layer.tint),
			str(layer.uv_scale),
			_resource_key(layer.normal),
			str(layer.normal_strength),
			_resource_key(layer.roughness_texture),
			str(layer.roughness_texture_strength),
			str(layer.roughness),
			str(layer.metallic),
			str(layer.height_range),
			str(layer.slope_range),
			str(layer.blend_softness),
		]))

	return "|".join(values)


func _store_cached_material(
	cache_key: String,
	material: Material,
) -> void:
	if _material_cache.size() >= maxi(material_cache_limit, 1):
		_material_cache.clear()

	_material_cache[cache_key] = material


func _resource_key(resource: Resource) -> String:
	if resource == null:
		return "none"

	if not resource.resource_path.is_empty():
		return resource.resource_path

	return "instance:%d" % resource.get_instance_id()
