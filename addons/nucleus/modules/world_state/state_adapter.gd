@tool
class_name NucleusWorldStateAdapter
extends Node
## Base adapter that contributes one explicit state slice to a world entity.

@export var adapter_id: StringName:
	set(value):
		adapter_id = value
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if adapter_id == &"":
		warnings.append("Assign a unique adapter_id inside this persistent entity.")

	return warnings


func capture_state() -> Variant:
	return {}


func restore_state(_state: Variant) -> void:
	pass
