@tool
class_name NucleusScatterProfile3D
extends Resource
## Data-only, deterministic world-XZ scatter recipe.
## No game-specific biome rules, colliders, autoloads or runtime managers.

@export var seed: int = 1337
@export_range(0.05, 1000.0, 0.05, "or_greater") var grid_spacing: float = 2.0
@export_range(0.0, 1.0, 0.01) var density: float = 0.5
@export_range(0.0, 1.0, 0.01) var jitter: float = 0.8
@export_range(0.0, 2000.0, 0.05) var minimum_separation: float = 0.0
@export_range(0.0, 90.0, 0.5, "radians_as_degrees") var maximum_slope: float = PI * 0.25
@export var minimum_height: float = -INF
@export var maximum_height: float = INF
@export var align_to_normal: bool = false
@export var vertical_offset: float = 0.0
@export_range(0.001, 100.0, 0.01, "or_greater") var scale_min: float = 0.8
@export_range(0.001, 100.0, 0.01, "or_greater") var scale_max: float = 1.2
@export var variants: Array[NucleusScatterVariant3D] = []


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not is_finite(grid_spacing) or grid_spacing <= 0.0:
		errors.append("grid_spacing must be positive and finite.")
	if not is_finite(density) or density < 0.0 or density > 1.0:
		errors.append("density must be between 0 and 1.")
	if not is_finite(jitter) or jitter < 0.0 or jitter > 1.0:
		errors.append("jitter must be between 0 and 1.")
	if not is_finite(minimum_separation) or minimum_separation < 0.0:
		errors.append("minimum_separation must be nonnegative and finite.")
	if minimum_separation > grid_spacing * 2.0:
		errors.append("minimum_separation must not exceed twice grid_spacing.")
	if not is_finite(maximum_slope) or maximum_slope < 0.0 or maximum_slope > PI * 0.5:
		errors.append("maximum_slope must be between 0 and 90 degrees.")
	if minimum_height > maximum_height or is_nan(minimum_height) or is_nan(maximum_height):
		errors.append("Height interval is invalid.")
	if not is_finite(scale_min) or scale_min <= 0.0 or scale_max < scale_min:
		errors.append("Scale interval is invalid.")
	if not is_finite(scale_max) or not is_finite(vertical_offset):
		errors.append("Scale and vertical offset must be finite.")
	var valid_variants: int = 0
	for variant: NucleusScatterVariant3D in variants:
		if variant != null and variant.is_usable():
			valid_variants += 1
	if valid_variants == 0:
		errors.append("At least one variant needs a mesh and positive weight.")
	return errors


func choose_variant(unit_random: float) -> int:
	var weight_total: float = 0.0
	for variant: NucleusScatterVariant3D in variants:
		if variant != null and variant.is_usable():
			weight_total += variant.weight
	if weight_total <= 0.0:
		return -1
	var threshold: float = clampf(unit_random, 0.0, 0.9999999) * weight_total
	for index: int in range(variants.size()):
		var variant: NucleusScatterVariant3D = variants[index]
		if variant == null or not variant.is_usable():
			continue
		threshold -= variant.weight
		if threshold < 0.0:
			return index
	return -1
