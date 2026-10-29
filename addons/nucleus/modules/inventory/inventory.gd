@tool
class_name NucleusInventory
extends Node
## Scene-owned item container with optional slot and weight limits.
##
## Item definitions are immutable Resources. Runtime stacks own quantity/state.

signal changed
signal item_added(item_id: StringName, amount: int)
signal item_removed(item_id: StringName, amount: int)
signal stack_added(stack: NucleusItemStack)
signal stack_removed(stack_id: String)

@export var catalog: NucleusItemCatalog:
	set(value):
		catalog = value
		update_configuration_warnings()

## Zero means unlimited.
@export_range(0, 1000000, 1, "or_greater")
var max_slots: int = 0

## Zero means unlimited.
@export_range(0.0, 1.0e12, 0.001, "or_greater")
var max_weight: float = 0.0

var _stacks: Array[NucleusItemStack] = []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if catalog == null:
		warnings.append(
			"Assign a NucleusItemCatalog for ID lookup and persistence restore."
		)
		return warnings

	warnings.append_array(catalog.get_validation_errors())
	return warnings


func get_stacks() -> Array[NucleusItemStack]:
	var result: Array[NucleusItemStack] = []

	for stack: NucleusItemStack in _stacks:
		result.append(stack)

	return result


func get_stack_by_id(stack_id: String) -> NucleusItemStack:
	if stack_id.is_empty():
		return null

	for stack: NucleusItemStack in _stacks:
		if stack.stack_id == stack_id:
			return stack

	return null


func get_definition(item_id: StringName) -> NucleusItemDefinition:
	if catalog == null:
		return null

	return catalog.get_item(item_id)


func get_count(item_id: StringName) -> int:
	var result: int = 0

	for stack: NucleusItemStack in _stacks:
		if stack.get_item_id() == item_id:
			result += stack.amount

	return result


func has_item(
	item_id: StringName,
	amount: int = 1,
) -> bool:
	if amount <= 0:
		return true

	return get_count(item_id) >= amount


func get_used_slots() -> int:
	return _stacks.size()


## Returns -1 when slot count is unlimited.
func get_remaining_slots() -> int:
	if max_slots <= 0:
		return -1

	return maxi(
		0,
		max_slots - get_used_slots(),
	)


func get_total_weight() -> float:
	var result: float = 0.0

	for stack: NucleusItemStack in _stacks:
		result += stack.get_weight()

	return result


## Returns -1 when weight is unlimited.
func get_remaining_weight() -> float:
	if max_weight <= 0.0:
		return -1.0

	return maxf(
		0.0,
		max_weight - get_total_weight(),
	)


func can_add_item(
	definition: NucleusItemDefinition,
	amount: int = 1,
	state: Dictionary = {},
) -> bool:
	if amount <= 0:
		return false

	return _calculate_accepted_amount(
		definition,
		amount,
		state,
	) == maxi(0, amount)


## Adds as many units as capacity permits and returns the accepted amount.
func add_item(
	definition: NucleusItemDefinition,
	amount: int = 1,
	state: Dictionary = {},
) -> int:
	var accepted: int = _calculate_accepted_amount(
		definition,
		amount,
		state,
	)

	if accepted <= 0:
		return 0

	var remaining: int = accepted

	for stack: NucleusItemStack in _stacks:
		if not stack.can_merge(definition, state):
			continue

		var increase: int = mini(
			remaining,
			stack.get_remaining_capacity(),
		)
		stack.amount += increase
		remaining -= increase

		if remaining <= 0:
			break

	while remaining > 0:
		var stack_amount: int = mini(
			remaining,
			definition.get_stack_limit(),
		)
		var stack := NucleusItemStack.new(
			definition,
			stack_amount,
			state,
		)
		_stacks.append(stack)
		stack_added.emit(stack)
		remaining -= stack_amount

	item_added.emit(
		definition.item_id,
		accepted,
	)
	changed.emit()

	return accepted


func add_item_by_id(
	item_id: StringName,
	amount: int = 1,
	state: Dictionary = {},
) -> int:
	var definition: NucleusItemDefinition = get_definition(item_id)

	if definition == null:
		return 0

	return add_item(
		definition,
		amount,
		state,
	)


## Removes up to [param amount] matching units and returns the removed amount.
func remove_item(
	item_id: StringName,
	amount: int = 1,
) -> int:
	if item_id == &"" or amount <= 0:
		return 0

	var remaining: int = amount
	var removed: int = 0
	var index: int = 0

	while index < _stacks.size() and remaining > 0:
		var stack: NucleusItemStack = _stacks[index]

		if stack.get_item_id() != item_id:
			index += 1
			continue

		var decrease: int = mini(
			remaining,
			stack.amount,
		)
		stack.amount -= decrease
		remaining -= decrease
		removed += decrease

		if stack.amount <= 0:
			var removed_id: String = stack.stack_id
			_stacks.remove_at(index)
			stack_removed.emit(removed_id)
			continue

		index += 1

	if removed > 0:
		item_removed.emit(
			item_id,
			removed,
		)
		changed.emit()

	return removed


func remove_from_stack(
	stack_id: String,
	amount: int = 1,
) -> int:
	if stack_id.is_empty() or amount <= 0:
		return 0

	for index: int in range(_stacks.size()):
		var stack: NucleusItemStack = _stacks[index]

		if stack.stack_id != stack_id:
			continue

		var removed: int = mini(
			amount,
			stack.amount,
		)
		stack.amount -= removed

		if stack.amount <= 0:
			_stacks.remove_at(index)
			stack_removed.emit(stack_id)

		if removed > 0:
			item_removed.emit(
				stack.get_item_id(),
				removed,
			)
			changed.emit()

		return removed

	return 0


func clear() -> void:
	if _stacks.is_empty():
		return

	var removed_ids: PackedStringArray = []

	for stack: NucleusItemStack in _stacks:
		removed_ids.append(stack.stack_id)

	_stacks.clear()

	for stack_id: String in removed_ids:
		stack_removed.emit(stack_id)

	changed.emit()


func capture_state() -> Dictionary:
	var stack_states: Array[Dictionary] = []

	for stack: NucleusItemStack in _stacks:
		stack_states.append(stack.capture_state())

	return {
		"stacks": stack_states,
	}


## Restores saved stacks by item ID.
##
## Slot/weight limits are intentionally not applied while loading so a balance
## change cannot silently delete already-owned items. Unknown item IDs are
## skipped and returned for migration/diagnostics.
func restore_state(data: Dictionary) -> PackedStringArray:
	var missing_ids := PackedStringArray()
	var stored_stacks: Variant = data.get(
		"stacks",
		[],
	)

	_stacks.clear()

	if not stored_stacks is Array:
		changed.emit()
		return missing_ids

	for entry: Variant in stored_stacks:
		if not entry is Dictionary:
			continue

		var stack_data: Dictionary = entry
		var item_id := StringName(
			str(stack_data.get("item_id", ""))
		)
		var definition: NucleusItemDefinition = get_definition(item_id)

		if definition == null:
			var missing_id: String = String(item_id)

			if not missing_id.is_empty() and missing_id not in missing_ids:
				missing_ids.append(missing_id)

			continue

		var state_value: Variant = stack_data.get(
			"state",
			{},
		)
		var state: Dictionary = (
			(state_value as Dictionary).duplicate(true)
			if state_value is Dictionary
			else {}
		)
		var remaining: int = maxi(
			0,
			int(stack_data.get("amount", 0)),
		)
		var source_stack_id: String = str(
			stack_data.get("stack_id", "")
		)
		var split_index: int = 0

		while remaining > 0:
			var stack_amount: int = mini(
				remaining,
				definition.get_stack_limit(),
			)
			var restored_id: String = source_stack_id

			if split_index > 0 and not source_stack_id.is_empty():
				restored_id = "%s:%d" % [
					source_stack_id,
					split_index,
				]

			restored_id = _resolve_unique_stack_id(restored_id)

			_stacks.append(
				NucleusItemStack.new(
					definition,
					stack_amount,
					state,
					restored_id,
				)
			)
			remaining -= stack_amount
			split_index += 1

	changed.emit()
	return missing_ids


func _calculate_accepted_amount(
	definition: NucleusItemDefinition,
	amount: int,
	state: Dictionary,
) -> int:
	if (
		definition == null
		or definition.item_id == &""
		or amount <= 0
	):
		return 0

	var accepted: int = amount

	if max_weight > 0.0 and definition.unit_weight > 0.0:
		var remaining_weight: float = maxf(
			0.0,
			max_weight - get_total_weight(),
		)
		var weight_capacity: int = int(
			floor(
				remaining_weight / definition.unit_weight
				+ 0.000001
			)
		)
		accepted = mini(
			accepted,
			maxi(0, weight_capacity),
		)

	if accepted <= 0 or max_slots <= 0:
		return maxi(0, accepted)

	var existing_capacity: int = 0

	for stack: NucleusItemStack in _stacks:
		if stack.can_merge(definition, state):
			existing_capacity += stack.get_remaining_capacity()

	var free_slots: int = maxi(
		0,
		max_slots - _stacks.size(),
	)
	var new_stack_capacity: int = (
		free_slots * definition.get_stack_limit()
	)

	return mini(
		accepted,
		existing_capacity + new_stack_capacity,
	)


func _resolve_unique_stack_id(candidate: String) -> String:
	if candidate.is_empty():
		candidate = NucleusUuid.v4()

	while get_stack_by_id(candidate) != null:
		candidate = NucleusUuid.v4()

	return candidate
