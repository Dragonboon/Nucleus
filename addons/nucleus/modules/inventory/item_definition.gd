class_name NucleusItemDefinition
extends Resource
## Immutable design-time identity and stacking metadata for one item kind.
##
## Runtime quantity and per-instance state belong to NucleusItemStack.

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(1, 1000000, 1, "or_greater")
var max_stack_size: int = 1
@export_range(0.0, 1.0e12, 0.001, "or_greater")
var unit_weight: float = 0.0
@export var tags: Array[StringName] = []


func is_stackable() -> bool:
	return max_stack_size > 1


func has_tag(tag: StringName) -> bool:
	return tag != &"" and tag in tags


func get_stack_limit() -> int:
	return maxi(1, max_stack_size)
