class_name NucleusEquipmentSlotDefinition
extends Resource
## Data-driven equipment slot filter.
##
## Empty accepted_tags means no positive tag requirement. blocked_tags always
## reject matching equipment.

@export var slot_id: StringName
@export var accepted_tags: Array[StringName] = []
@export var blocked_tags: Array[StringName] = []


func accepts(
	item: NucleusEquipmentItemDefinition,
) -> bool:
	if (
		item == null
		or slot_id == &""
		or not item.can_equip_to(slot_id)
	):
		return false

	for tag: StringName in blocked_tags:
		if item.has_tag(tag):
			return false

	if accepted_tags.is_empty():
		return true

	for tag: StringName in accepted_tags:
		if item.has_tag(tag):
			return true

	return false
