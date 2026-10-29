class_name NucleusStringSettingDefinition
extends NucleusSettingDefinition
## String setting definition.

@export var default_value: String = ""


func get_default_value() -> Variant:
	return default_value


func accepts_value(value: Variant) -> bool:
	return typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]


func normalize_value(value: Variant) -> Variant:
	return str(value) if accepts_value(value) else default_value
