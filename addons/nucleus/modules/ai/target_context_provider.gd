@tool
class_name NucleusAITargetContextProvider
extends NucleusAIContextProvider
## Exposes the existing TargetingAgent selection to UtilityBrain context.

@export var targeting_agent: NucleusTargetingAgent:
	set(value):
		_disconnect_targeting_agent()
		targeting_agent = value
		_connect_targeting_agent()
		update_configuration_warnings()

@export var source: Node:
	set(value):
		source = value
		update_configuration_warnings()

@export_group("Context keys")
@export var has_target_key: StringName = &"has_target"
@export var targetable_key: StringName = &"targetable"
@export var target_key: StringName = &"target"
@export var target_point_key: StringName = &"target_point"
@export var target_position_key: StringName = &"target_position"
@export var target_distance_key: StringName = &"target_distance"


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_connect_targeting_agent()


func _exit_tree() -> void:
	_disconnect_targeting_agent()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if targeting_agent == null:
		warnings.append("Assign a NucleusTargetingAgent.")

	return warnings


func contribute(context: Dictionary) -> void:
	var targetable: NucleusTargetable = (
		targeting_agent.current
		if targeting_agent != null
		else null
	)
	var has_target: bool = (
		targetable != null
		and is_instance_valid(targetable)
	)

	context[has_target_key] = has_target

	if not has_target:
		context[targetable_key] = null
		context[target_key] = null
		context[target_point_key] = null
		return

	var target_node: Node = targetable.get_target_node()
	var target_point: Node = targetable.get_target_point_node()

	context[targetable_key] = targetable
	context[target_key] = target_node
	context[target_point_key] = target_point

	var resolved_source: Node = source

	if resolved_source == null and targeting_agent != null:
		resolved_source = targeting_agent.source

	if (
		resolved_source is Node2D
		and targetable.has_position_2d()
	):
		var position_2d: Vector2 = targetable.get_position_2d()
		context[target_position_key] = position_2d
		context[target_distance_key] = (
			(resolved_source as Node2D)
			.global_position
			.distance_to(position_2d)
		)
	elif (
		resolved_source is Node3D
		and targetable.has_position_3d()
	):
		var position_3d: Vector3 = targetable.get_position_3d()
		context[target_position_key] = position_3d
		context[target_distance_key] = (
			(resolved_source as Node3D)
			.global_position
			.distance_to(position_3d)
		)


func _on_target_changed(
	_current: NucleusTargetable,
	_previous: NucleusTargetable,
) -> void:
	notify_context_changed()


func _connect_targeting_agent() -> void:
	if (
		Engine.is_editor_hint()
		or targeting_agent == null
		or not is_inside_tree()
	):
		return

	if not targeting_agent.current_changed.is_connected(
		_on_target_changed
	):
		targeting_agent.current_changed.connect(
			_on_target_changed
		)


func _disconnect_targeting_agent() -> void:
	if targeting_agent == null or not is_instance_valid(targeting_agent):
		return

	if targeting_agent.current_changed.is_connected(
		_on_target_changed
	):
		targeting_agent.current_changed.disconnect(
			_on_target_changed
		)
