@tool
class_name NucleusTextureBudgetProfile
extends Resource
## Development-time texture budget thresholds.
##
## The profile produces diagnostics only. It never changes import settings.

@export_group("Dimensions")
@export_range(1, 32768, 1)
var warning_dimension: int = 2048:
	set(value):
		warning_dimension = maxi(value, 1)
		emit_changed()

@export_range(1, 32768, 1)
var critical_dimension: int = 4096:
	set(value):
		critical_dimension = maxi(value, 1)
		emit_changed()

@export_group("3D import policy")
@export var warn_missing_mipmaps: bool = true
@export var warn_non_vram_compression: bool = true
@export var warn_disabled_normal_map_detection: bool = true

@export_group("Normal-map filename hints")
@export var normal_map_tokens := PackedStringArray([
	"_normal",
	"_norm",
	"_nrm",
	" normal",
])


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if warning_dimension <= 0:
		errors.append("warning_dimension must be greater than zero")

	if critical_dimension < warning_dimension:
		errors.append(
			"critical_dimension must be greater than or equal to warning_dimension"
		)

	return errors
