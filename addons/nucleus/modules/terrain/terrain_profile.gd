@tool
class_name NucleusTerrainProfile
extends Resource
## Height source, geometry, collision, and shoreline policy for one terrain patch.

enum HeightSource {
	FAST_NOISE,
	HEIGHTMAP,
	IMAGE,
}

enum ImageMapping {
	STRETCH_TO_PATCH,
	WORLD_REPEAT,
}

enum ShapeMode {
	RECTANGLE,
	ISLAND,
}

enum CollisionMode {
	DISABLED,
	HEIGHTMAP,
	TRIMESH,
}

@export_group("Dimensions")
@export var size: Vector2 = Vector2(256.0, 256.0)
@export_range(2, 1024, 1, "or_greater")
var resolution: int = 96
@export var base_height: float = 0.0
@export_range(0.001, 100000.0, 0.01, "or_greater")
var height_scale: float = 50.0
@export var sampling_offset: Vector2 = Vector2.ZERO

@export_group("Height source")
@export var height_source: HeightSource = HeightSource.FAST_NOISE
@export var noise: FastNoiseLite
@export var image: Texture2D
@export var image_mapping: ImageMapping = ImageMapping.STRETCH_TO_PATCH
@export var image_world_size: Vector2 = Vector2(256.0, 256.0)
@export var normalize_heightmap: bool = true
@export var elevation_curve: Curve

@export_group("Shape")
@export var shape_mode: ShapeMode = ShapeMode.RECTANGLE
@export_range(0.0, 0.95, 0.01)
var island_inner_radius: float = 0.55
@export_range(0.01, 1.0, 0.01)
var island_falloff: float = 0.35
@export_range(0.1, 8.0, 0.05)
var island_power: float = 1.5
@export var edge_floor_height: float = -12.0
@export var shoreline_noise: FastNoiseLite
@export_range(0.0, 0.45, 0.01)
var shoreline_noise_strength: float = 0.12
@export var edge_floor_noise: FastNoiseLite
@export_range(0.0, 10000.0, 0.1, "or_greater")
var edge_floor_noise_strength: float = 0.0
@export var falloff_texture: Texture2D

@export_group("Rendering")
@export_range(0, 6, 1)
var lod_levels: int = 2
@export_range(10.0, 100000.0, 1.0, "or_greater")
var lod_distance_step: float = 120.0
@export_range(2, 8, 1)
var lod_reduction_factor: int = 2
@export var cast_shadows: bool = true

@export_group("Collision")
@export var collision_mode: CollisionMode = CollisionMode.HEIGHTMAP
@export_range(2, 512, 1, "or_greater")
var collision_resolution: int = 48
@export var collision_holes_below_height: bool = false
@export var collision_hole_height: float = -1.0
@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if size.x <= 0.0 or size.y <= 0.0:
		errors.append("size components must be greater than zero.")

	if height_source == HeightSource.FAST_NOISE and noise == null:
		errors.append("FAST_NOISE requires a FastNoiseLite resource.")

	if height_source != HeightSource.FAST_NOISE and image == null:
		errors.append("HEIGHTMAP and IMAGE sources require an image texture.")

	if image_mapping == ImageMapping.WORLD_REPEAT:
		if image_world_size.x <= 0.0 or image_world_size.y <= 0.0:
			errors.append("image_world_size must be positive for WORLD_REPEAT.")

	if collision_resolution > resolution * 2:
		errors.append(
			"collision_resolution is unusually higher than visual resolution."
		)

	return errors


func minimum_expected_height() -> float:
	return minf(
		base_height,
		edge_floor_height - edge_floor_noise_strength,
	)


func maximum_expected_height() -> float:
	return maxf(
		base_height + height_scale,
		edge_floor_height + edge_floor_noise_strength,
	)
