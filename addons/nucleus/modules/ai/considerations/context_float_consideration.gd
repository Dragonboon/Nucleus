class_name NucleusAIContextFloatConsideration
extends NucleusAIConsideration
## Normalizes one numeric context value and optionally remaps it with a Curve.

@export var context_key: StringName
@export var minimum_value: float = 0.0
@export var maximum_value: float = 1.0
@export_range(0.0, 1.0, 0.001)
var missing_score: float = 0.0
@export var response_curve: Curve


func score(context: Dictionary) -> float:
	if context_key == &"" or not context.has(context_key):
		return missing_score

	var value: Variant = context[context_key]

	if (
		typeof(value) != TYPE_INT
		and typeof(value) != TYPE_FLOAT
	):
		return missing_score

	if is_equal_approx(
		minimum_value,
		maximum_value,
	):
		return 1.0 if float(value) >= maximum_value else 0.0

	var normalized: float = clampf(
		inverse_lerp(
			minimum_value,
			maximum_value,
			float(value),
		),
		0.0,
		1.0,
	)

	if response_curve != null:
		normalized = clampf(
			response_curve.sample_baked(normalized),
			0.0,
			1.0,
		)

	return normalized
