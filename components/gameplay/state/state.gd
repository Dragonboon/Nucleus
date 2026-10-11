class_name NucleusState
extends Node
## Base class for one state in [NucleusStateMachine].
##
## Override the lifecycle/input methods that your state needs. State identity is
## a stable StringName instead of relying on script-class names.

@warning_ignore("unused_signal")
signal entered(
	previous_state: NucleusState,
	context: Dictionary,
)
@warning_ignore("unused_signal")
signal exited(next_state: NucleusState)

@export var state_id: StringName

var machine: NucleusStateMachine


func get_state_id() -> StringName:
	return (
		state_id
		if state_id != &""
		else StringName(name)
	)


func request_transition(
	next_state_id: StringName,
	context: Dictionary = {},
) -> Error:
	if machine == null:
		return ERR_UNCONFIGURED

	return machine.change_state(
		next_state_id,
		context,
	)


## Resolve the actor selected by the owner, or null if it was freed.
func get_actor() -> Node:
	return machine.get_actor() if is_instance_valid(machine) else null


## Explicit deferred request; change_state() remains immediate-only.
func request_deferred_transition(
	next_state_id: StringName,
	context: Dictionary = {},
) -> Error:
	if not is_instance_valid(machine):
		return ERR_UNCONFIGURED
	return machine.request_state(next_state_id, context)


func can_enter(
	_previous_state: NucleusState,
	_context: Dictionary,
) -> bool:
	return true


func can_exit(
	_next_state: NucleusState,
	_context: Dictionary,
) -> bool:
	return true


func state_ready() -> void:
	pass


func enter(
	_previous_state: NucleusState,
	_context: Dictionary,
) -> void:
	pass


func exit(_next_state: NucleusState) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func handle_unhandled_input(_event: InputEvent) -> void:
	pass
