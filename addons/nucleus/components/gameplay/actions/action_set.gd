class_name NucleusActionSet
extends Node
## Scene-owned registry for an actor's NucleusGameplayAction nodes.
##
## Direct references remain valid; this registry is useful for AI, UI, save
## integration, and code that executes actions by stable StringName id.

signal action_registered(action: NucleusGameplayAction)
signal actions_ready(actions: Dictionary)

@export var actions_root: Node

var _actions: Dictionary[StringName, NucleusGameplayAction] = {}


func _ready() -> void:
	if actions_root == null:
		actions_root = self

	_rebuild_registry()
	actions_ready.emit(get_actions())


func get_action(
	action_id: StringName,
) -> NucleusGameplayAction:
	return _actions.get(action_id)


func has_action(action_id: StringName) -> bool:
	return _actions.has(action_id)


func get_actions() -> Dictionary:
	return _actions.duplicate()


func get_actions_with_tag(
	tag: StringName,
) -> Array[NucleusGameplayAction]:
	var result: Array[NucleusGameplayAction] = []

	for action: NucleusGameplayAction in _actions.values():
		if action.has_tag(tag):
			result.append(action)

	return result


func execute(
	action_id: StringName,
	context: Dictionary = {},
) -> Error:
	var action: NucleusGameplayAction = get_action(
		action_id
	)

	if action == null:
		return ERR_DOES_NOT_EXIST

	return action.try_execute(context)


func capture_state() -> Dictionary:
	var state: Dictionary = {}

	for action_id: StringName in _actions:
		state[String(action_id)] = (
			_actions[action_id].capture_state()
		)

	return state


func restore_state(data: Dictionary) -> void:
	for key: Variant in data:
		var action_id := StringName(str(key))
		var action: NucleusGameplayAction = get_action(
			action_id
		)

		if action == null:
			continue

		var action_state: Variant = data[key]

		if action_state is Dictionary:
			action.restore_state(action_state)


func rebuild_registry() -> void:
	_rebuild_registry()
	actions_ready.emit(get_actions())


func _rebuild_registry() -> void:
	_actions.clear()

	for node: Node in NucleusNodeUtils.descendants(
		actions_root,
		true,
	):
		if not (node is NucleusGameplayAction):
			continue

		if _belongs_to_nested_action_set(node):
			continue

		var action := node as NucleusGameplayAction
		var action_id: StringName = action.get_action_id()

		if action_id == &"":
			NucleusLog.error(
				"Action %s has an empty id." % action.get_path(),
				&"ActionSet",
			)
			continue

		if _actions.has(action_id):
			NucleusLog.error(
				"Duplicate action id '%s' in %s."
				% [action_id, get_path()],
				&"ActionSet",
			)
			continue

		_actions[action_id] = action
		action_registered.emit(action)


func _belongs_to_nested_action_set(node: Node) -> bool:
	var current: Node = node.get_parent()

	while current and current != actions_root:
		if (
			current is NucleusActionSet
			and current != self
		):
			return true

		current = current.get_parent()

	return false
