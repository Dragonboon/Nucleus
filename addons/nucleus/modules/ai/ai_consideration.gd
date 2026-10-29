class_name NucleusAIConsideration
extends Resource
## One normalized utility factor.
##
## Subclasses implement score(). evaluate() clamps to [0, 1] and supports
## optional inversion without changing the original context.

@export var enabled: bool = true
@export var invert: bool = false


func score(_context: Dictionary) -> float:
	return 1.0


func evaluate(context: Dictionary) -> float:
	if not enabled:
		return 1.0

	var result: float = clampf(
		score(context),
		0.0,
		1.0,
	)

	return 1.0 - result if invert else result
