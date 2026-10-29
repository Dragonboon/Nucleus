class_name NucleusInputRebindCapture
extends Node
## Presentation-agnostic runtime input capture for remapping one InputMap slot.
##
## UI may start/cancel capture and decide how conflicts are presented. This
## component owns event capture only; NucleusInput remains the binding authority.

signal capture_started(
	action: StringName,
	source: int,
	binding_index: int,
)
signal candidate_captured(
	action: StringName,
	event: InputEvent,
)
signal conflict_detected(
	action: StringName,
	source: int,
	binding_index: int,
	event: InputEvent,
	conflicts: Array[StringName],
)
signal conflict_rejected(
	action: StringName,
	source: int,
	binding_index: int,
)
signal capture_committed(
	action: StringName,
	source: int,
	binding_index: int,
	event: InputEvent,
)
signal capture_canceled(
	action: StringName,
	source: int,
	binding_index: int,
)
signal capture_failed(
	action: StringName,
	source: int,
	binding_index: int,
	error: Error,
)

enum ConflictPolicy {
	ALLOW,
	REJECT,
	PROMPT,
}

@export_range(0.1, 1.0, 0.05)
var joypad_axis_capture_threshold: float = 0.7

var _listening: bool = false
var _action: StringName
var _source: int = NucleusInputTypes.Source.ANY
var _binding_index: int = 0
var _conflict_policy: int = ConflictPolicy.PROMPT

var _pending_event: InputEvent
var _pending_conflicts: Array[StringName] = []


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)


func _exit_tree() -> void:
	_cancel_without_signal()


func begin_capture(
	action: StringName,
	source: int,
	binding_index: int = 0,
	conflict_policy: int = ConflictPolicy.PROMPT,
) -> Error:
	if _listening or has_pending_conflict():
		return ERR_BUSY

	if not NucleusInput.is_action_rebindable(action):
		return ERR_DOES_NOT_EXIST

	if source not in [
		NucleusInputTypes.Source.KEYBOARD_MOUSE,
		NucleusInputTypes.Source.GAMEPAD,
	]:
		return ERR_INVALID_PARAMETER

	if binding_index < 0:
		return ERR_INVALID_PARAMETER

	_action = action
	_source = source
	_binding_index = binding_index
	_conflict_policy = conflict_policy
	_listening = true
	set_process_input(true)

	capture_started.emit(
		_action,
		_source,
		_binding_index,
	)

	return OK


func cancel_capture() -> void:
	if not _listening and not has_pending_conflict():
		return

	var canceled_action: StringName = _action
	var canceled_source: int = _source
	var canceled_index: int = _binding_index

	_cancel_without_signal()
	capture_canceled.emit(
		canceled_action,
		canceled_source,
		canceled_index,
	)


func is_listening() -> bool:
	return _listening


func has_pending_conflict() -> bool:
	return _pending_event != null


func get_pending_event() -> InputEvent:
	return _pending_event


func get_pending_conflicts() -> Array[StringName]:
	return _pending_conflicts.duplicate()


func get_action() -> StringName:
	return _action


func get_source() -> int:
	return _source


func get_binding_index() -> int:
	return _binding_index


func accept_pending_conflict() -> Error:
	if _pending_event == null:
		return ERR_DOES_NOT_EXIST

	var event: InputEvent = _pending_event
	_clear_pending_conflict()

	return _commit_event(event)


func reject_pending_conflict() -> void:
	if _pending_event == null:
		return

	_clear_pending_conflict()
	_listening = true
	set_process_input(true)
	conflict_rejected.emit(
		_action,
		_source,
		_binding_index,
	)


func _input(event: InputEvent) -> void:
	if not _listening:
		return

	if not NucleusInputBindingCodec.is_capture_candidate(
		event,
		joypad_axis_capture_threshold,
	):
		return

	if NucleusInputBindingCodec.get_source(event) != _source:
		return

	var normalized_event: InputEvent = (
		NucleusInputBindingCodec.normalize(event)
	)

	if normalized_event == null:
		return

	get_viewport().set_input_as_handled()
	candidate_captured.emit(
		_action,
		normalized_event,
	)

	var conflicts: Array[StringName] = NucleusInput.find_conflicts(
		normalized_event,
		_action,
	)

	if conflicts.is_empty():
		_commit_event(normalized_event)
		return

	match _conflict_policy:
		ConflictPolicy.ALLOW:
			_commit_event(normalized_event)

		ConflictPolicy.REJECT:
			conflict_detected.emit(
				_action,
				_source,
				_binding_index,
				normalized_event,
				conflicts,
			)

		ConflictPolicy.PROMPT:
			_pending_event = normalized_event
			_pending_conflicts = conflicts.duplicate()
			_listening = false
			set_process_input(false)

			conflict_detected.emit(
				_action,
				_source,
				_binding_index,
				normalized_event,
				conflicts,
			)


func _commit_event(event: InputEvent) -> Error:
	var error: Error = NucleusInput.set_binding(
		_action,
		_source,
		_binding_index,
		event,
	)

	if error != OK:
		_listening = true
		set_process_input(true)
		capture_failed.emit(
			_action,
			_source,
			_binding_index,
			error,
		)
		return error

	var committed_action: StringName = _action
	var committed_source: int = _source
	var committed_index: int = _binding_index

	_cancel_without_signal()

	capture_committed.emit(
		committed_action,
		committed_source,
		committed_index,
		event,
	)

	return OK


func _clear_pending_conflict() -> void:
	_pending_event = null
	_pending_conflicts.clear()


func _cancel_without_signal() -> void:
	_listening = false
	set_process_input(false)
	_clear_pending_conflict()

	_action = &""
	_source = NucleusInputTypes.Source.ANY
	_binding_index = 0
