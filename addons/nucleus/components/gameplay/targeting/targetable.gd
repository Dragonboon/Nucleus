class_name NucleusTargetable
extends Node
## Scene-owned endpoint that marks one gameplay object as targetable.
##
## The endpoint stores target metadata only. Sensors discover it, TargetingAgent
## selects it, and project systems decide what targeting means.

signal availability_changed(available: bool)
signal ranking_changed
signal metadata_changed

@export var target: Node
@export var target_point: Node

@export_group("Selection")
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return

		enabled = value

		if is_node_ready():
			availability_changed.emit(enabled)

@export var priority: float = 0.0:
	set(value):
		if is_equal_approx(priority, value):
			return

		priority = value

		if is_node_ready():
			ranking_changed.emit()

@export var tags: Array[StringName] = []


func _ready() -> void:
	if target == null:
		target = get_parent()


func can_be_targeted(
	_requester: Node,
	_context: Dictionary = {},
) -> bool:
	return (
		enabled
		and target != null
		and is_instance_valid(target)
		and target.is_inside_tree()
	)


func has_tag(tag: StringName) -> bool:
	return tag in tags


func has_any_tag(query_tags: Array[StringName]) -> bool:
	return NucleusArrayUtils.intersects(
		tags,
		query_tags,
	)


func has_all_tags(query_tags: Array[StringName]) -> bool:
	for tag: StringName in query_tags:
		if tag not in tags:
			return false

	return true


func get_target_node() -> Node:
	if target and is_instance_valid(target):
		return target

	return get_parent()


func get_target_point_node() -> Node:
	if target_point and is_instance_valid(target_point):
		return target_point

	return get_target_node()


func has_position_2d() -> bool:
	return get_target_point_node() is Node2D


func has_position_3d() -> bool:
	return get_target_point_node() is Node3D


func get_position_2d() -> Vector2:
	var point: Node = get_target_point_node()

	if point is Node2D:
		return (point as Node2D).global_position

	return Vector2.ZERO


func get_position_3d() -> Vector3:
	var point: Node = get_target_point_node()

	if point is Node3D:
		return (point as Node3D).global_position

	return Vector3.ZERO


func set_tags(new_tags: Array[StringName]) -> void:
	if tags == new_tags:
		return

	tags.clear()
	tags.append_array(new_tags)
	metadata_changed.emit()
	ranking_changed.emit()


func notify_metadata_changed() -> void:
	metadata_changed.emit()
	ranking_changed.emit()
