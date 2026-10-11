@tool
class_name NucleusModularRuleSet
extends Resource
## Pure, bounded cardinal rule resolver. No scene instantiation or game policy.

const MAX_RULES: int = 64

@export var fallback_variant: StringName = &""
@export var rules: Array[NucleusModularRule] = []


## Kept for existing consumers: returns only the stable variant ID.
func resolve(mask: int) -> StringName:
	return resolve_variant(mask).get("variant_id", &"")


## On ties, higher priority wins; then unrotated; then authored array order.
## Rotation steps are positive quarter turns about the 3D world's up axis.
func resolve_variant(mask: int) -> Dictionary:
	if mask < 0 or mask > 15:
		return {}
	var best_id: StringName = fallback_variant
	var best_steps: int = 0
	var best_priority: int = -2147483648
	var best_exact: bool = false
	var matched: bool = false
	for rule: NucleusModularRule in rules.slice(0, MAX_RULES):
		if rule == null or rule.variant_id == &"":
			continue
		if rule.neighbor_mask < 0 or rule.neighbor_mask > 15:
			continue
		var count: int = 4 if rule.allow_rotations else 1
		for steps in range(count):
			if rotate_mask(rule.neighbor_mask, steps) != mask:
				continue
			var exact: bool = steps == 0
			if (
				not matched or rule.priority > best_priority
				or (rule.priority == best_priority and exact and not best_exact)
			):
				best_id = rule.variant_id
				best_steps = steps
				best_priority = rule.priority
				best_exact = exact
				matched = true
			break
	return {
		"variant_id": best_id,
		"rotation_steps": best_steps,
		"matched": matched,
		"neighbor_mask": mask,
	}


## N=1, E=2, S=4, W=8. Clockwise quarter turns preserve bit count.
static func rotate_mask(mask: int, steps: int) -> int:
	if mask < 0 or mask > 15:
		return -1
	var result: int = 0
	for side in range(4):
		if mask & (1 << side):
			result |= 1 << posmod(side + steps, 4)
	return result


static func neighbor_mask(cell: Vector2i, occupied: Callable) -> int:
	if not occupied.is_valid():
		return 0
	var result: int = 0
	for direction in range(4):
		if bool(occupied.call(NucleusSquareLayout.neighbor(cell, direction))):
			result |= 1 << direction
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if rules.size() > MAX_RULES:
		errors.append("A modular rule set supports at most %d rules." % MAX_RULES)
	for i in range(rules.size()):
		var rule: NucleusModularRule = rules[i]
		if rule == null:
			errors.append("rules[%d] is null." % i)
			continue
		if rule.neighbor_mask < 0 or rule.neighbor_mask > 15:
			errors.append("rules[%d] has an invalid connection mask." % i)
		if rule.variant_id == &"":
			errors.append("rules[%d] requires a stable variant_id." % i)
	return errors
