@tool
class_name NucleusTerrainTextureLayer
extends Resource
## One procedural terrain material layer blended by height and surface slope.

@export var enabled: bool = true

@export_group("Albedo")
@export var albedo: Texture2D
@export var tint: Color = Color.WHITE
@export_range(0.001, 1000.0, 0.001, "or_greater")
var uv_scale: float = 0.08

@export_group("PBR detail")
@export var normal: Texture2D
@export_range(0.0, 2.0, 0.01, "or_greater")
var normal_strength: float = 1.0
@export var roughness_texture: Texture2D
@export_range(0.0, 1.0, 0.01)
var roughness_texture_strength: float = 1.0
@export_range(0.0, 1.0, 0.01)
var roughness: float = 0.9
@export_range(0.0, 1.0, 0.01)
var metallic: float = 0.0

@export_group("Blend")
@export var height_range: Vector2 = Vector2(0.0, 1.0)
@export var slope_range: Vector2 = Vector2(0.0, 1.0)
@export_range(0.001, 0.5, 0.001)
var blend_softness: float = 0.08


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if height_range.x > height_range.y:
		errors.append(
			"height_range minimum must not exceed its maximum."
		)

	if slope_range.x > slope_range.y:
		errors.append(
			"slope_range minimum must not exceed its maximum."
		)

	return errors
