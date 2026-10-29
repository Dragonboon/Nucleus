class_name NucleusStateTransitionEffect
extends NucleusActionEffect
## Transitions an existing NucleusStateMachine when an action commits.

@export var state_machine: NucleusStateMachine
@export var target_state: StringName
@export var merge_action_context: bool = true
@export var extra_context: Dictionary = {}


func _ready() -> void:
	if state_machine == null:
		state_machine = _find_state_machine()

	if state_machine == null:
		NucleusLog.error(
			"%s requires a NucleusStateMachine." % get_path(),
			&"StateTransitionEffect",
		)


func can_apply(context: Dictionary) -> Error:
	if state_machine == null or target_state == &"":
		return ERR_UNCONFIGURED

	if not state_machine.has_state(target_state):
		return ERR_DOES_NOT_EXIST

	if state_machine.is_transitioning():
		return ERR_BUSY

	var target: NucleusState = state_machine.get_state(
		target_state
	)
	var current: NucleusState = state_machine.current_state
	var transition_context: Dictionary = _build_context(context)

	if (
		current
		and not current.can_exit(
			target,
			transition_context,
		)
	):
		return ERR_UNAVAILABLE

	if not target.can_enter(
		current,
		transition_context,
	):
		return ERR_UNAVAILABLE

	return OK


func apply(context: Dictionary) -> Error:
	return state_machine.change_state(
		target_state,
		_build_context(context),
	)


func _build_context(
	action_context: Dictionary,
) -> Dictionary:
	var result: Dictionary = extra_context.duplicate(true)

	if merge_action_context:
		result.merge(
			action_context,
			true,
		)

	return result


func _find_state_machine() -> NucleusStateMachine:
	var root: Node = get_parent()

	while root:
		if root is NucleusStateMachine:
			return root as NucleusStateMachine

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusStateMachine:
				return node as NucleusStateMachine

		root = root.get_parent()

	return null
