class_name NucleusDictionarySettingDefinition
extends NucleusSettingDefinition
## Dictionary setting definition for structured Core preferences.

@export var default_value: Dictionary = {}


func get_default_value() -> Variant:
	return default_value.duplicate(true)


func accepts_value(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY


func normalize_value(value: Variant) -> Variant:
	if not accepts_value(value):
		return get_default_value()

	return value.duplicate(true)
