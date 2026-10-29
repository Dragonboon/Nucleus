@tool
class_name NucleusAIStateMachineBridge
extends Node
## Converts UtilityBrain decisions into existing StateMachine transitions.

signal transition_failed(
	option_id: StringName,
	state_id: StringName,
	error: Error,
)

@export var brain: NucleusAIUtilityBrain:
	set(value):
		brain = value
		update_configuration_warnings()

@export var state_machine: NucleusStateMachine:
	set(value):
		state_machine = value
		update_configuration_warnings()

@export var bindings: Array[NucleusAIStateBinding] = []:
	set(value):
		bindings = value
		update_configuration_warnings()

@export var fallback_state_id: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if (
		brain != null
		and not brain.decision_changed.is_connected(
			_on_decision_changed
		)
	):
		brain.decision_changed.connect(
			_on_decision_changed
		)


func _exit_tree() -> void:
	if (
		brain != null
		and is_instance_valid(brain)
		and brain.decision_changed.is_connected(
			_on_decision_changed
		)
	):
		brain.decision_changed.disconnect(
			_on_decision_changed
		)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var known_options: Dictionary[StringName, bool] = {}

	if brain == null:
		warnings.append("Assign a NucleusAIUtilityBrain.")

	if state_machine == null:
		warnings.append("Assign a NucleusStateMachine.")

	for index: int in range(bindings.size()):
		var binding: NucleusAIStateBinding = bindings[index]

		if binding == null:
			warnings.append("AI state binding %d is null." % index)
			continue

		if binding.option_id == &"" or binding.state_id == &"":
			warnings.append(
				"AI state binding %d requires option_id and state_id." % index
			)
			continue

		if known_options.has(binding.option_id):
			warnings.append(
				"Duplicate AI state binding for '%s'." % binding.option_id
			)
			continue

		known_options[binding.option_id] = true

	return warnings


func apply_current_decision() -> Error:
	if brain == null or state_machine == null:
		return ERR_UNCONFIGURED

	var option: NucleusAIUtilityOption = brain.current_option
	var option_id: StringName = (
		option.option_id
		if option != null
		else &""
	)
	var state_id: StringName = _resolve_state_id(option_id)

	if state_id == &"":
		return ERR_DOES_NOT_EXIST

	return state_machine.change_state(
		state_id,
		{
			&"ai_option_id": String(option_id),
			&"ai_score": brain.get_score(option_id),
			&"ai_context": brain.get_last_context(),
		},
	)


func _on_decision_changed(
	current: NucleusAIUtilityOption,
	_previous: NucleusAIUtilityOption,
	score: float,
	context: Dictionary,
) -> void:
	if state_machine == null:
		return

	var option_id: StringName = (
		current.option_id
		if current != null
		else &""
	)
	var state_id: StringName = _resolve_state_id(option_id)

	if state_id == &"":
		return

	var transition_context: Dictionary = context.duplicate()
	transition_context[&"ai_option_id"] = String(option_id)
	transition_context[&"ai_score"] = score

	var error: Error = state_machine.change_state(
		state_id,
		transition_context,
	)

	if error != OK:
		transition_failed.emit(
			option_id,
			state_id,
			error,
		)


func _resolve_state_id(
	option_id: StringName,
) -> StringName:
	for binding: NucleusAIStateBinding in bindings:
		if (
			binding != null
			and binding.option_id == option_id
		):
			return binding.state_id

	return fallback_state_id
