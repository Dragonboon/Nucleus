@tool
class_name NucleusEquipment
extends Node
## Scene-owned equipment state with optional Inventory and Attributes binding.
##
## Equipment does not transfer/remove items from Inventory. When [member inventory]
## is assigned, equipped stack IDs reference stacks that remain in that inventory.

signal changed
signal equipped(
	slot_id: StringName,
	item_id: StringName,
	stack_id: String,
)
signal unequipped(
	slot_id: StringName,
	item_id: StringName,
	stack_id: String,
)

@export var catalog: NucleusItemCatalog:
	set(value):
		catalog = value
		update_configuration_warnings()

@export var inventory: NucleusInventory:
	set(value):
		if inventory == value:
			return

		if (
			not Engine.is_editor_hint()
			and inventory != null
			and inventory.stack_removed.is_connected(
				_on_inventory_stack_removed
			)
		):
			inventory.stack_removed.disconnect(
				_on_inventory_stack_removed
			)

		inventory = value

		if (
			not Engine.is_editor_hint()
			and is_inside_tree()
		):
			_connect_inventory()

@export var attribute_set: NucleusAttributeSet:
	set(value):
		if attribute_set == value:
			return

		if (
			not Engine.is_editor_hint()
			and attribute_set != null
		):
			_remove_all_modifier_sources(attribute_set)

		attribute_set = value

		if (
			not Engine.is_editor_hint()
			and is_inside_tree()
		):
			refresh_attribute_modifiers()

@export var slots: Array[NucleusEquipmentSlotDefinition] = []:
	set(value):
		slots = value
		update_configuration_warnings()

var _slot_definitions: Dictionary[StringName, NucleusEquipmentSlotDefinition] = {}

## slot_id -> {"item_id": StringName, "stack_id": String}
var _equipped: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	_rebuild_slots()

	if Engine.is_editor_hint():
		return

	_connect_inventory()
	refresh_attribute_modifiers()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	if (
		inventory != null
		and inventory.stack_removed.is_connected(
			_on_inventory_stack_removed
		)
	):
		inventory.stack_removed.disconnect(
			_on_inventory_stack_removed
		)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var known_slots: Dictionary[StringName, bool] = {}

	if catalog == null:
		warnings.append(
			"Assign a NucleusItemCatalog for equipment persistence restore."
		)

	for index: int in range(slots.size()):
		var slot: NucleusEquipmentSlotDefinition = slots[index]

		if slot == null:
			warnings.append("Equipment slot %d is null." % index)
			continue

		if slot.slot_id == &"":
			warnings.append("Equipment slot %d has an empty slot_id." % index)
			continue

		if known_slots.has(slot.slot_id):
			warnings.append(
				"Duplicate equipment slot_id '%s'." % slot.slot_id
			)
			continue

		known_slots[slot.slot_id] = true

	return warnings


func has_slot(slot_id: StringName) -> bool:
	return _slot_definitions.has(slot_id)


func get_equipped_item(
	slot_id: StringName,
) -> NucleusEquipmentItemDefinition:
	if not _equipped.has(slot_id) or catalog == null:
		return null

	var item_id: StringName = _equipped[slot_id]["item_id"]
	var item: NucleusItemDefinition = catalog.get_item(item_id)

	return item as NucleusEquipmentItemDefinition


func get_equipped_stack_id(slot_id: StringName) -> String:
	if not _equipped.has(slot_id):
		return ""

	return str(_equipped[slot_id].get("stack_id", ""))


func is_equipped(slot_id: StringName) -> bool:
	return _equipped.has(slot_id)


func equip_inventory_stack(
	slot_id: StringName,
	stack_id: String,
) -> Error:
	if inventory == null:
		return ERR_UNCONFIGURED

	var stack: NucleusItemStack = inventory.get_stack_by_id(stack_id)

	if stack == null:
		return ERR_DOES_NOT_EXIST

	if not stack.definition is NucleusEquipmentItemDefinition:
		return ERR_INVALID_DATA

	return equip_item(
		slot_id,
		stack.definition as NucleusEquipmentItemDefinition,
		stack.stack_id,
	)


func equip_item(
	slot_id: StringName,
	item: NucleusEquipmentItemDefinition,
	stack_id: String = "",
) -> Error:
	if not has_slot(slot_id):
		return ERR_DOES_NOT_EXIST

	if item == null or item.item_id == &"":
		return ERR_INVALID_PARAMETER

	var slot: NucleusEquipmentSlotDefinition = _slot_definitions[slot_id]

	if not slot.accepts(item):
		return ERR_UNAVAILABLE

	if inventory != null and not stack_id.is_empty():
		var stack: NucleusItemStack = inventory.get_stack_by_id(stack_id)

		if (
			stack == null
			or stack.get_item_id() != item.item_id
		):
			return ERR_DOES_NOT_EXIST

	var current: Dictionary = _equipped.get(
		slot_id,
		{},
	)

	if (
		not current.is_empty()
		and current.get("item_id", &"") == item.item_id
		and str(current.get("stack_id", "")) == stack_id
	):
		return OK

	if not current.is_empty():
		_emit_unequipped_entry(
			slot_id,
			current,
		)

	_remove_modifier_source(slot_id)

	_equipped[slot_id] = {
		"item_id": item.item_id,
		"stack_id": stack_id,
	}
	_apply_modifier_source(
		slot_id,
		item,
	)

	equipped.emit(
		slot_id,
		item.item_id,
		stack_id,
	)
	changed.emit()

	return OK


func unequip(slot_id: StringName) -> bool:
	if not _equipped.has(slot_id):
		return false

	var current: Dictionary = _equipped[slot_id]
	_equipped.erase(slot_id)
	_remove_modifier_source(slot_id)

	_emit_unequipped_entry(
		slot_id,
		current,
	)
	changed.emit()

	return true


func clear() -> void:
	if _equipped.is_empty():
		return

	var slot_ids: Array[StringName] = []

	for slot_id: StringName in _equipped:
		slot_ids.append(slot_id)

	for slot_id: StringName in slot_ids:
		unequip(slot_id)


func refresh_attribute_modifiers() -> void:
	if attribute_set == null:
		return

	_remove_all_modifier_sources(attribute_set)

	for slot_id: StringName in _equipped:
		var item: NucleusEquipmentItemDefinition = get_equipped_item(
			slot_id
		)

		if item != null:
			_apply_modifier_source(
				slot_id,
				item,
			)


func capture_state() -> Dictionary:
	var equipped_state: Dictionary = {}

	for slot_id: StringName in _equipped:
		var entry: Dictionary = _equipped[slot_id]
		equipped_state[String(slot_id)] = {
			"item_id": String(entry.get("item_id", &"")),
			"stack_id": str(entry.get("stack_id", "")),
		}

	return {
		"equipped": equipped_state,
	}


func restore_state(data: Dictionary) -> PackedStringArray:
	var missing_ids := PackedStringArray()
	clear()

	var stored_equipment: Variant = data.get(
		"equipped",
		{},
	)

	if not stored_equipment is Dictionary:
		return missing_ids

	var equipment_data: Dictionary = stored_equipment

	for key: Variant in equipment_data:
		if not equipment_data[key] is Dictionary:
			continue

		var slot_id := StringName(str(key))
		var entry: Dictionary = equipment_data[key]
		var item_id := StringName(
			str(entry.get("item_id", ""))
		)
		var item: NucleusItemDefinition = (
			catalog.get_item(item_id)
			if catalog != null
			else null
		)

		if not item is NucleusEquipmentItemDefinition:
			var missing_id: String = String(item_id)

			if not missing_id.is_empty() and missing_id not in missing_ids:
				missing_ids.append(missing_id)

			continue

		var stack_id: String = str(
			entry.get("stack_id", "")
		)
		var error: Error = equip_item(
			slot_id,
			item as NucleusEquipmentItemDefinition,
			stack_id,
		)

		if error != OK and not stack_id.is_empty():
			NucleusLog.warning(
				"Could not restore equipped stack '%s' in slot '%s'."
				% [stack_id, slot_id],
				&"Equipment",
			)

	return missing_ids


func _rebuild_slots() -> void:
	_slot_definitions.clear()

	for slot: NucleusEquipmentSlotDefinition in slots:
		if (
			slot == null
			or slot.slot_id == &""
			or _slot_definitions.has(slot.slot_id)
		):
			continue

		_slot_definitions[slot.slot_id] = slot


func _connect_inventory() -> void:
	if inventory == null:
		return

	if not inventory.stack_removed.is_connected(
		_on_inventory_stack_removed
	):
		inventory.stack_removed.connect(
			_on_inventory_stack_removed
		)


func _on_inventory_stack_removed(stack_id: String) -> void:
	var slots_to_clear: Array[StringName] = []

	for slot_id: StringName in _equipped:
		if get_equipped_stack_id(slot_id) == stack_id:
			slots_to_clear.append(slot_id)

	for slot_id: StringName in slots_to_clear:
		unequip(slot_id)


func _modifier_source_id(slot_id: StringName) -> StringName:
	return StringName(
		"equipment:%s" % slot_id
	)


func _apply_modifier_source(
	slot_id: StringName,
	item: NucleusEquipmentItemDefinition,
) -> void:
	if attribute_set == null:
		return

	attribute_set.set_modifier_source(
		_modifier_source_id(slot_id),
		item.attribute_modifiers,
	)


func _remove_modifier_source(slot_id: StringName) -> void:
	if attribute_set == null:
		return

	attribute_set.remove_modifier_source(
		_modifier_source_id(slot_id)
	)


func _remove_all_modifier_sources(
	target_attribute_set: NucleusAttributeSet,
) -> void:
	for slot: NucleusEquipmentSlotDefinition in slots:
		if slot == null or slot.slot_id == &"":
			continue

		target_attribute_set.remove_modifier_source(
			_modifier_source_id(slot.slot_id)
		)


func _emit_unequipped_entry(
	slot_id: StringName,
	entry: Dictionary,
) -> void:
	unequipped.emit(
		slot_id,
		StringName(
			str(entry.get("item_id", ""))
		),
		str(entry.get("stack_id", "")),
	)
