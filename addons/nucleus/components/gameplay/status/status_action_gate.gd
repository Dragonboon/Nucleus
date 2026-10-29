class_name NucleusStatusActionGate
extends Node
## Blocks ActionSet actions by action tags while one status tag is active.
##
## Example:
## status_tag = "silenced", blocked_action_tags = ["spell"].

@export var status_container: NucleusStatusEffectContainer
@export var action_set: NucleusActionSet
@export var status_tag: StringName
@export var blocked_action_tags: Array[StringName] = []

var _blocker_id: StringName


func _ready() -> void:
	_resolve_dependencies()

	if status_container == null or action_set == null:
		NucleusLog.error(
			"%s requires StatusEffectContainer and ActionSet." % get_path(),
			&"StatusActionGate",
		)
		return

	if status_tag == &"":
		NucleusLog.error(
			"%s requires a status_tag." % get_path(),
			&"StatusActionGate",
		)
		return

	_blocker_id = StringName(
		"status_gate:%s" % get_instance_id()
	)

	status_container.effects_changed.connect(_refresh)
	action_set.action_registered.connect(
		_on_action_registered
	)
	action_set.actions_ready.connect(
		_on_actions_ready
	)

	_refresh()


func _exit_tree() -> void:
	_remove_blocker_from_all()

	if (
		status_container
		and status_container.effects_changed.is_connected(_refresh)
	):
		status_container.effects_changed.disconnect(_refresh)

	if (
		action_set
		and action_set.action_registered.is_connected(
			_on_action_registered
		)
	):
		action_set.action_registered.disconnect(
			_on_action_registered
		)

	if (
		action_set
		and action_set.actions_ready.is_connected(
			_on_actions_ready
		)
	):
		action_set.actions_ready.disconnect(
			_on_actions_ready
		)


func _refresh(
	_argument: Variant = null,
) -> void:
	if status_container == null or action_set == null:
		return

	var should_block: bool = status_container.has_tag(
		status_tag
	)

	for action: NucleusGameplayAction in (
		action_set.get_actions().values()
	):
		_apply_to_action(
			action,
			should_block,
		)


func _apply_to_action(
	action: NucleusGameplayAction,
	should_block: bool,
) -> void:
	if action == null:
		return

	var matches: bool = blocked_action_tags.is_empty()

	if not matches:
		matches = NucleusArrayUtils.intersects(
			action.tags,
			blocked_action_tags,
		)

	if matches and should_block:
		action.add_blocker(_blocker_id)
	else:
		action.remove_blocker(_blocker_id)


func _remove_blocker_from_all() -> void:
	if action_set == null or _blocker_id == &"":
		return

	for action: NucleusGameplayAction in (
		action_set.get_actions().values()
	):
		action.remove_blocker(_blocker_id)


func _on_action_registered(
	action: NucleusGameplayAction,
) -> void:
	_apply_to_action(
		action,
		status_container.has_tag(status_tag),
	)


func _on_actions_ready(_actions: Dictionary) -> void:
	_refresh()


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and (
		status_container == null
		or action_set == null
	):
		if status_container == null and root is NucleusStatusEffectContainer:
			status_container = root as NucleusStatusEffectContainer

		if action_set == null and root is NucleusActionSet:
			action_set = root as NucleusActionSet

		for node: Node in NucleusNodeUtils.descendants(root):
			if (
				status_container == null
				and node is NucleusStatusEffectContainer
			):
				status_container = node as NucleusStatusEffectContainer

			if action_set == null and node is NucleusActionSet:
				action_set = node as NucleusActionSet

		root = root.get_parent()
