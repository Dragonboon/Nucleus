@tool
class_name NucleusBiomeProfile3D
extends Resource
## Biome classification rules and optional references to existing generators.
## Never mutate referenced scatter/terrain materials during classification.

@export var biome_id: StringName = &""
@export var priority: int = 0
@export var temperature_range: Vector2 = Vector2(0.0, 1.0)
@export var moisture_range: Vector2 = Vector2(0.0, 1.0)
@export var height_range: Vector2 = Vector2(-10000.0, 10000.0)
@export_range(0.0, 90.0, 0.5) var maximum_slope_degrees: float = 90.0
@export var scatter_profile: NucleusScatterProfile3D
@export var terrain_material: NucleusTerrainMaterialProfile


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if biome_id == &"":
		errors.append("biome_id cannot be empty.")
	if not _valid_interval(temperature_range, 0.0, 1.0):
		errors.append("Temperature range must be finite and inside [0, 1].")
	if not _valid_interval(moisture_range, 0.0, 1.0):
		errors.append("Moisture range must be finite and inside [0, 1].")
	if not _valid_interval(height_range, -1000000.0, 1000000.0):
		errors.append("Height range must be finite and ordered.")
	if (
		not is_finite(maximum_slope_degrees)
		or maximum_slope_degrees < 0.0 or maximum_slope_degrees > 90.0
	):
		errors.append("Slope must be finite and within [0, 90].")
	return errors


func accepts(
	temperature: float,
	moisture: float,
	height: float,
	slope_degrees: float,
) -> bool:
	return (
		temperature >= temperature_range.x and temperature <= temperature_range.y
		and moisture >= moisture_range.x and moisture <= moisture_range.y
		and height >= height_range.x and height <= height_range.y
		and slope_degrees >= 0.0 and slope_degrees <= maximum_slope_degrees
	)


static func _valid_interval(interval: Vector2, low: float, high: float) -> bool:
	return (
		interval.is_finite() and interval.x >= low
		and interval.y <= high and interval.x <= interval.y
	)
