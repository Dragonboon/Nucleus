@tool
class_name NucleusPlacementVariant3D
extends Resource
## One selectable scene in an optional placement variant set.
## The ID is game-owned and may be persisted after placement.

@export var variant_id: StringName = &""
@export var scene: PackedScene


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if variant_id == &"":
		errors.append("variant_id must not be empty.")
	if scene == null:
		errors.append("Assign a PackedScene to the variant.")
	return errors
