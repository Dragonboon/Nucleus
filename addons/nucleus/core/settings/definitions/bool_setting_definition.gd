class_name NucleusBoolSettingDefinition
extends NucleusSettingDefinition
## Boolean setting definition.

@export var default_value: bool = false


func get_default_value() -> Variant:
	return default_value


func accepts_value(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL


func normalize_value(value: Variant) -> Variant:
	return value if accepts_value(value) else default_value
