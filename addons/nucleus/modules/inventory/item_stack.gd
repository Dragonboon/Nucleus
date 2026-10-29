class_name NucleusItemStack
extends RefCounted
## Mutable runtime stack/instance referencing an immutable item definition.
##
## [member state] is game-owned per-stack state such as durability, quality,
## generated affixes, or ammo subtype. Stacks merge only when this state matches.

var stack_id: String
var definition: NucleusItemDefinition
var amount: int
var state: Dictionary


func _init(
	item_definition: NucleusItemDefinition = null,
	initial_amount: int = 0,
	initial_state: Dictionary = {},
	initial_stack_id: String = "",
) -> void:
	definition = item_definition
	state = initial_state.duplicate(true)
	stack_id = (
		initial_stack_id
		if not initial_stack_id.is_empty()
		else NucleusUuid.v4()
	)

	var limit: int = (
		definition.get_stack_limit()
		if definition != null
		else 1
	)
	amount = clampi(
		initial_amount,
		0,
		limit,
	)


func get_item_id() -> StringName:
	return (
		definition.item_id
		if definition != null
		else &""
	)


func get_remaining_capacity() -> int:
	if definition == null:
		return 0

	return maxi(
		0,
		definition.get_stack_limit() - amount,
	)


func get_weight() -> float:
	if definition == null:
		return 0.0

	return maxf(
		0.0,
		definition.unit_weight * amount,
	)


func can_merge(
	item_definition: NucleusItemDefinition,
	incoming_state: Dictionary = {},
) -> bool:
	return (
		definition != null
		and item_definition != null
		and definition.item_id == item_definition.item_id
		and definition.get_stack_limit() > 1
		and state == incoming_state
		and amount < definition.get_stack_limit()
	)


func capture_state() -> Dictionary:
	return {
		"stack_id": stack_id,
		"item_id": String(get_item_id()),
		"amount": amount,
		"state": state.duplicate(true),
	}
