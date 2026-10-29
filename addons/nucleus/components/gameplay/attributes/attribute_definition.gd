class_name NucleusAttributeDefinition
extends Resource
## Immutable design-time metadata for one numeric gameplay attribute.

@export var attribute_id: StringName
@export var base_value: float = 0.0

@export_group("Clamping")
@export var use_minimum: bool = false
@export var minimum_value: float = 0.0
@export var use_maximum: bool = false
@export var maximum_value: float = 100.0


func clamp_value(value: float) -> float:
	var result: float = value

	if use_minimum:
		result = maxf(result, minimum_value)

	if use_maximum:
		result = minf(result, maximum_value)

	return result
