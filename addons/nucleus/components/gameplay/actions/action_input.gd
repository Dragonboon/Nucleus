class_name NucleusGameplayActionInput
extends Node
## Routes one InputMap action into one NucleusGameplayAction.
##
## Prefer a NucleusMotionInput reference so local multiplayer reuses the same
## per-player event stream already used by movement/camera.
##
## Child NucleusActionContextProvider nodes may enrich the execution context.

signal input_execution_finished(
	error: Error,
	action: NucleusGameplayAction,
)

@export var gameplay_action: NucleusGameplayAction
@export var motion_input: NucleusMotionInput
@export var input_action: StringName
@export var source: Node
@export var enabled: bool = true
@export var mark_global_input_handled: bool = true

@export_group("Context")
@export var context_root: Node

var _using_motion_stream: bool = false


func _ready() -> void:
	if gameplay_action == null:
		gameplay_action = get_parent() as NucleusGameplayAction

	if source == null:
		source = _find_source()

	if motion_input == null:
		motion_input = _find_motion_input()

	if context_root == null:
		context_root = self

	if gameplay_action == null:
		NucleusLog.error(
			"%s requires a NucleusGameplayAction." % get_path(),
			&"ActionInput",
		)
		return

	if input_action == &"":
		NucleusLog.warning(
			"%s has no InputMap action assigned." % get_path(),
			&"ActionInput",
		)

	if motion_input:
		motion_input.input_event_received.connect(
			_on_input_event
		)
		_using_motion_stream = true


func _exit_tree() -> void:
	if (
		motion_input
		and motion_input.input_event_received.is_connected(
			_on_input_event
		)
	):
		motion_input.input_event_received.disconnect(
			_on_input_event
		)


func _unhandled_input(event: InputEvent) -> void:
	if _using_motion_stream:
		return

	_handle_event(
		event,
		true,
	)


func _on_input_event(event: InputEvent) -> void:
	_handle_event(
		event,
		false,
	)


func _handle_event(
	event: InputEvent,
	global_fallback: bool,
) -> void:
	if (
		not enabled
		or gameplay_action == null
		or input_action == &""
		or not InputMap.has_action(input_action)
	):
		return

	if not event.is_action_pressed(input_action):
		return

	var context: Dictionary = {
		"source": source,
		"input_event": event,
		"input_action": input_action,
	}

	if motion_input and motion_input.local_player_input:
		context["local_player_input"] = (
			motion_input.local_player_input
		)
		context["player_index"] = (
			motion_input.local_player_input.player_index
		)

	NucleusActionContextProvider.contribute_from(
		context_root,
		context,
	)

	var error: Error = gameplay_action.try_execute(
		context
	)

	input_execution_finished.emit(
		error,
		gameplay_action,
	)

	var global_stream: bool = (
		global_fallback
		or (
			motion_input
			and motion_input.local_player_input == null
		)
	)

	if (
		global_stream
		and error == OK
		and mark_global_input_handled
	):
		get_viewport().set_input_as_handled()


func _find_motion_input() -> NucleusMotionInput:
	var root: Node = get_parent()

	while root:
		if root is NucleusMotionInput:
			return root as NucleusMotionInput

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusMotionInput:
				return node as NucleusMotionInput

		root = root.get_parent()

	return null


func _find_source() -> Node:
	var current: Node = get_parent()

	while current:
		if (
			current is CharacterBody2D
			or current is CharacterBody3D
		):
			return current

		current = current.get_parent()

	return get_parent()
