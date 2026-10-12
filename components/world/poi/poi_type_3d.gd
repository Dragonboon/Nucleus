@tool
class_name NucleusPOIType3D
extends Resource
## Stable content identifier, not a scene path or authoritative spawn action.

@export var poi_id: StringName = &""
@export_range(0.01, 1000.0, 0.01, "or_greater") var weight: float = 1.0
@export var allowed_biomes: PackedStringArray = PackedStringArray()
@export var height_range: Vector2 = Vector2(-10000.0, 10000.0)
@export_range(0.0, 90.0, 0.5) var maximum_slope_degrees: float = 45.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if poi_id == &"":
		errors.append("poi_id cannot be empty.")
	if not is_finite(weight) or weight <= 0.0:
		errors.append("POI type weight must be finite and positive.")
	if not height_range.is_finite() or height_range.x > height_range.y:
		errors.append("POI height interval must be finite and ordered.")
	if (
		not is_finite(maximum_slope_degrees)
		or maximum_slope_degrees < 0.0 or maximum_slope_degrees > 90.0
	):
		errors.append("POI maximum slope must be finite and within [0, 90].")
	for name: String in allowed_biomes:
		if name.is_empty():
			errors.append("Allowed biome IDs must not contain empty values.")
	return errors


func accepts(biome_id: StringName, height: float, slope: float) -> bool:
	if not is_finite(height) or not is_finite(slope) or slope < 0.0 or slope > 90.0:
		return false
	if height < height_range.x or height > height_range.y:
		return false
	if slope > maximum_slope_degrees:
		return false
	return (
		allowed_biomes.is_empty()
		or allowed_biomes.has(str(biome_id))
	)
