@tool
class_name NucleusNodeStateAdapter
extends NucleusWorldStateAdapter
## Bridges any Node that already exposes capture_state()/restore_state().
##
## This is useful for NucleusInventory, NucleusEquipment, NucleusLootRoller,
## custom doors, actors, containers, or other explicit state owners.

@export var target: Node:
	set(value):
		target = value
		update_configuration_warnings()

@export var capture_method: StringName = &"capture_state":
	set(value):
		capture_method = value
		update_configuration_warnings()

@export var restore_method: StringName = &"restore_state":
	set(value):
		restore_method = value
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	var resolved: Node = _resolve_target()

	if resolved == null:
		warnings.append("Assign target or parent this adapter under its target.")
		return warnings

	if capture_method == &"" or not resolved.has_method(capture_method):
		warnings.append(
			"Target does not expose capture method '%s'." % capture_method
		)

	if restore_method == &"" or not resolved.has_method(restore_method):
		warnings.append(
			"Target does not expose restore method '%s'." % restore_method
		)

	return warnings


func capture_state() -> Variant:
	var resolved: Node = _resolve_target()

	if (
		resolved == null
		or capture_method == &""
		or not resolved.has_method(capture_method)
	):
		return null

	return resolved.call(capture_method)


func restore_state(state: Variant) -> void:
	var resolved: Node = _resolve_target()

	if (
		resolved == null
		or restore_method == &""
		or not resolved.has_method(restore_method)
	):
		return

	resolved.call(
		restore_method,
		state,
	)


func _resolve_target() -> Node:
	if target != null:
		return target

	return get_parent()
