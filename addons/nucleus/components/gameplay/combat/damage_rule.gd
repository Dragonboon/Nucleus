class_name NucleusDamageRule
extends Resource
## Side-effect-free damage transformation; lower priority runs first.
## Override transform_amount() in game-owned rules (armor, resistance, crits).

@export var priority: int = 0


func transform_amount(_payload: NucleusHitPayload, amount: float) -> float:
	return amount
