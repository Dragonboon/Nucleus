class_name NucleusProgressionDefinition
extends Resource
## Increasing cumulative thresholds; index 0 is XP required for level 2.
@export var track_id: StringName
@export var thresholds: PackedInt64Array = PackedInt64Array()


func is_valid() -> bool:
	if track_id == &"":
		return false
	var previous: int = 0
	for threshold: int in thresholds:
		if threshold <= previous:
			return false
		previous = threshold
	return true


func level_for_experience(experience: int) -> int:
	var result: int = 1
	for threshold: int in thresholds:
		if experience < threshold:
			break
		result += 1
	return result
