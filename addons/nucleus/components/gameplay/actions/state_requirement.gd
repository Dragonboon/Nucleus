class_name NucleusStateRequirement
extends NucleusActionRequirement
## Allows or blocks an action according to a NucleusStateMachine state.

@export var state_machine: NucleusStateMachine
@export var allowed_states: Array[StringName] = []
@export var blocked_states: Array[StringName] = []


func _ready() -> void:
	if state_machine == null:
		state_machine = _find_state_machine()

	if state_machine == null:
		NucleusLog.error(
			"%s requires a NucleusStateMachine." % get_path(),
			&"StateRequirement",
		)
		return

	state_machine.state_changed.connect(
		_on_state_changed
	)


func _exit_tree() -> void:
	if (
		state_machine
		and state_machine.state_changed.is_connected(
			_on_state_changed
		)
	):
		state_machine.state_changed.disconnect(
			_on_state_changed
		)


func check(_context: Dictionary) -> Error:
	if state_machine == null or state_machine.current_state == null:
		return ERR_UNCONFIGURED

	var current_id: StringName = (
		state_machine.current_state.get_state_id()
	)

	if (
		not allowed_states.is_empty()
		and current_id not in allowed_states
	):
		return ERR_UNAVAILABLE

	if current_id in blocked_states:
		return ERR_UNAVAILABLE

	return OK


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


func _on_state_changed(
	_from_state: NucleusState,
	_to_state: NucleusState,
	_context: Dictionary,
) -> void:
	notify_availability_changed()
