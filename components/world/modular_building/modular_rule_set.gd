@tool
class_name NucleusModularRuleSet
extends Resource
## Pure orthogonal neighbor resolver; connect it to SquareGrid/TileMapLayer/GridMap.
@export var fallback_variant: StringName = &""
@export var rules: Array[NucleusModularRule] = []

func resolve(mask: int) -> StringName:
	if mask < 0 or mask > 15:
		return &""
	var result: StringName = fallback_variant
	var best_priority: int = -2147483648
	for rule: NucleusModularRule in rules:
		if rule != null and rule.neighbor_mask == mask and rule.variant_id != &"":
			if rule.priority > best_priority:
				result = rule.variant_id
				best_priority = rule.priority
	return result

static func neighbor_mask(cell: Vector2i, occupied: Callable) -> int:
	if not occupied.is_valid():
		return 0
	var result: int = 0
	for direction in range(4):
		if bool(occupied.call(NucleusSquareLayout.neighbor(cell, direction))):
			result |= 1 << direction
	return result
