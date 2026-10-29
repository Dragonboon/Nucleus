@tool
class_name NucleusPropertyStateAdapter
extends NucleusWorldStateAdapter
## Captures an explicit list of simple Node properties.
##
## Property values must be compatible with the save codec selected by the game.

@export var target: Node:
	set(value):
		target = value
		update_configuration_warnings()

@export var properties: Array[StringName] = []:
	set(value):
		properties = value
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	var resolved: Node = _resolve_target()

	if resolved == null:
		warnings.append("Assign target or parent this adapter under its target.")
		return warnings

	if properties.is_empty():
		warnings.append("Add at least one property to persist.")
		return warnings

	for property_name: StringName in properties:
		if property_name == &"":
			warnings.append("Property names must not be empty.")
			continue

		if not _has_property(
			resolved,
			property_name,
		):
			warnings.append(
				"Target does not expose property '%s'." % property_name
			)

	return warnings


func capture_state() -> Variant:
	var resolved: Node = _resolve_target()
	var state: Dictionary = {}

	if resolved == null:
		return state

	for property_name: StringName in properties:
		if not _has_property(
			resolved,
			property_name,
		):
			continue

		state[String(property_name)] = resolved.get(property_name)

	return state


func restore_state(state: Variant) -> void:
	var resolved: Node = _resolve_target()

	if resolved == null or not state is Dictionary:
		return

	var values: Dictionary = state

	for key: Variant in values:
		var property_name := StringName(str(key))

		if _has_property(
			resolved,
			property_name,
		):
			resolved.set(
				property_name,
				values[key],
			)


func _resolve_target() -> Node:
	if target != null:
		return target

	return get_parent()


func _has_property(
	object: Object,
	property_name: StringName,
) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(str(property.get("name", ""))) == property_name:
			return true

	return false
