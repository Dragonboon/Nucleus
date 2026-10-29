class_name NucleusVector2iSettingDefinition
extends NucleusSettingDefinition
## Vector2i setting definition, useful for values such as window resolution.

@export var default_value: Vector2i = Vector2i.ZERO


func get_default_value() -> Variant:
	return default_value


func accepts_value(value: Variant) -> bool:
	return typeof(value) == TYPE_VECTOR2I


func normalize_value(value: Variant) -> Variant:
	return value if accepts_value(value) else default_value
