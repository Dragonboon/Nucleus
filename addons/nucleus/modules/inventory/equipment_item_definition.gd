class_name NucleusEquipmentItemDefinition
extends NucleusItemDefinition
## Item definition that can occupy equipment slots and contribute Attributes.

@export var valid_slots: Array[StringName] = []
@export var attribute_modifiers: Array[NucleusAttributeModifier] = []


func can_equip_to(slot_id: StringName) -> bool:
	return (
		slot_id != &""
		and (
			valid_slots.is_empty()
			or slot_id in valid_slots
		)
	)
