class_name NucleusAIUtilityOption
extends Resource
## One reusable AI intention scored from normalized considerations.

@export var option_id: StringName
@export_range(0.0, 1.0, 0.001)
var base_score: float = 1.0
@export var priority: int = 0
@export var considerations: Array[NucleusAIConsideration] = []
@export var tags: Array[StringName] = []


func evaluate(context: Dictionary) -> float:
	var result: float = clampf(
		base_score,
		0.0,
		1.0,
	)

	for consideration: NucleusAIConsideration in considerations:
		if consideration == null:
			continue

		result *= consideration.evaluate(context)

		if result <= 0.0:
			return 0.0

	return clampf(
		result,
		0.0,
		1.0,
	)


func has_tag(tag: StringName) -> bool:
	return tag != &"" and tag in tags
