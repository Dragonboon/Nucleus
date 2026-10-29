class_name NucleusIntSettingDefinition
extends NucleusSettingDefinition
## Integer setting definition with optional clamping metadata.

@export var default_value: int = 0

@export_group("Range")
@export var has_range: bool = false
@export var minimum_value: int = 0
@export var maximum_value: int = 100
@export_range(1, 100000, 1, "or_greater") var step: int = 1


func get_default_value() -> Variant:
	return normalize_value(default_value)


func accepts_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT


func normalize_value(value: Variant) -> Variant:
	if not accepts_value(value):
		return get_default_value()

	var normalized_value: int = value

	if has_range:
		normalized_value = clampi(
			normalized_value,
			minimum_value,
			maximum_value,
		)

	return normalized_value


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.get_validation_errors()

	if has_range and minimum_value > maximum_value:
		errors.append("minimum_value cannot be greater than maximum_value")

	if step <= 0:
		errors.append("step must be greater than zero")

	return errors
