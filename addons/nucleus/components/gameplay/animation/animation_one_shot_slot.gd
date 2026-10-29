@tool
class_name NucleusAnimationOneShotSlot
extends Resource
## Semantic handle for one authored AnimationNodeOneShot parameter set.

@export var slot_id: StringName
@export var node_name: StringName

@export_group("Optional explicit paths")
@export var request_parameter: StringName
@export var active_parameter: StringName


func get_request_parameter() -> StringName:
	if request_parameter != &"":
		return request_parameter

	if node_name == &"":
		return &""

	return StringName(
		"parameters/%s/request" % String(node_name)
	)


func get_active_parameter() -> StringName:
	if active_parameter != &"":
		return active_parameter

	if node_name == &"":
		return &""

	return StringName(
		"parameters/%s/active" % String(node_name)
	)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if slot_id == &"":
		errors.append("slot_id is required")

	if get_request_parameter() == &"":
		errors.append(
			"node_name or request_parameter is required"
		)

	return errors
