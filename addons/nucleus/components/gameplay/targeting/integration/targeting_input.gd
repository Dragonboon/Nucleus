class_name NucleusTargetingInput
extends Node
## Routes project-defined semantic InputMap actions into TargetingAgent.
##
## Prefer NucleusMotionInput so couch multiplayer reuses existing per-device
## InputEvent routing.

@export var agent: NucleusTargetingAgent
@export var motion_input: NucleusMotionInput

@export_group("Actions")
@export var toggle_lock_action: StringName = &""
@export var cycle_next_action: StringName = &""
@export var cycle_previous_action: StringName = &""
@export var unlock_action: StringName = &""

@export_group("Behavior")
@export var enabled: bool = true
@export var lock_when_cycling: bool = true
@export var mark_global_input_handled: bool = true

var _using_motion_stream: bool = false


func _ready() -> void:
	if agent == null:
		agent = NucleusTargetResolver.find_agent(self)

	if motion_input == null:
		motion_input = _find_motion_input()

	if agent == null:
		NucleusLog.error(
			"%s requires a NucleusTargetingAgent." % get_path(),
			&"TargetingInput",
		)
		return

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
	if not enabled or agent == null:
		return

	var handled: bool = false

	if _pressed(event, toggle_lock_action):
		agent.toggle_lock()
		handled = true
	elif _pressed(event, cycle_next_action):
		var next: NucleusTargetable = agent.select_next()

		if lock_when_cycling and next and not agent.is_locked():
			agent.lock_target(next)

		handled = true
	elif _pressed(event, cycle_previous_action):
		var previous: NucleusTargetable = agent.select_previous()

		if lock_when_cycling and previous and not agent.is_locked():
			agent.lock_target(previous)

		handled = true
	elif _pressed(event, unlock_action):
		agent.unlock_target()
		handled = true

	if not handled:
		return

	var global_stream: bool = (
		global_fallback
		or (
			motion_input
			and motion_input.local_player_input == null
		)
	)

	if global_stream and mark_global_input_handled:
		get_viewport().set_input_as_handled()


func _pressed(
	event: InputEvent,
	action: StringName,
) -> bool:
	return (
		action != &""
		and InputMap.has_action(action)
		and event.is_action_pressed(action)
	)


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
