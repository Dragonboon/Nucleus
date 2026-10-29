class_name NucleusAIContextBoolConsideration
extends NucleusAIConsideration
## Binary utility gate driven by a Boolean context key.

@export var context_key: StringName
@export var expected_value: bool = true
@export_range(0.0, 1.0, 0.001)
var missing_score: float = 0.0


func score(context: Dictionary) -> float:
	if context_key == &"" or not context.has(context_key):
		return missing_score

	var value: Variant = context[context_key]

	if typeof(value) != TYPE_BOOL:
		return missing_score

	return 1.0 if bool(value) == expected_value else 0.0
