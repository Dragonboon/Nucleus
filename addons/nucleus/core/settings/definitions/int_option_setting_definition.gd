class_name NucleusIntOptionSettingDefinition
extends NucleusSettingDefinition
## Integer setting restricted to an explicit list of selectable options.

@export var default_value: int = 0
@export var options: Array[NucleusIntSettingOption] = []


func get_default_value() -> Variant:
	if _contains_value(default_value):
		return default_value

	if options.is_empty():
		return default_value

	return options.front().value


func accepts_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and _contains_value(value)


func normalize_value(value: Variant) -> Variant:
	return value if accepts_value(value) else get_default_value()


func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.get_validation_errors()
	var used_values: Dictionary[int, bool] = {}

	if options.is_empty():
		errors.append("options cannot be empty")
		return errors

	for option: NucleusIntSettingOption in options:
		if option == null:
			errors.append("options cannot contain null resources")
			continue

		if used_values.has(option.value):
			errors.append("option values must be unique")
			continue

		used_values[option.value] = true

	if not _contains_value(default_value):
		errors.append("default_value must match one option value")

	return errors


func find_option_index(value: int) -> int:
	for index: int in range(options.size()):
		var option: NucleusIntSettingOption = options[index]

		if option and option.value == value:
			return index

	return -1


func _contains_value(value: int) -> bool:
	return find_option_index(value) != -1
