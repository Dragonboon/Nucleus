extends Resource
class_name NucleusScreenCombination
## Explicit unordered inventory recipe, not a crafting subsystem.

@export var first_item: StringName
@export var second_item: StringName
@export var result_item: StringName
@export var consume_inputs := true
@export var set_flag: StringName


func matches(a: StringName, b: StringName) -> bool:
	return (a == first_item and b == second_item) or (
		a == second_item and b == first_item
	)


func is_valid_recipe() -> bool:
	return first_item != &"" and second_item != &"" and result_item != &""
