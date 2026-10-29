class_name NucleusInputRebindButtonBinding
extends Node
## Turns a regular Button into a runtime input-rebinding control by composition.
##
## Capture is delegated to NucleusInputRebindCapture so custom settings UIs can
## reuse the same capture/conflict flow without depending on Button.

signal rebind_started(action: StringName)
signal rebind_finished(action: StringName, event: InputEvent)
signal conflict_detected(
	action: StringName,
	event: InputEvent,
	conflicts: Array[StringName],
)

@export var action: StringName
@export_enum("Keyboard & Mouse:1", "Gamepad:2")
var source: int = NucleusInputTypes.Source.KEYBOARD_MOUSE
@export_range(0, 8, 1, "or_greater") var binding_index: int = 0

@export_group("Behavior")
@export var allow_conflicts: bool = true
## When enabled, a conflict pauses capture until external UI accepts/rejects it.
@export var prompt_conflicts: bool = false
@export_range(0.1, 1.0, 0.05)
var joypad_axis_capture_threshold: float = 0.7

@export_group("Presentation")
@export var target: Button
@export var capture: NucleusInputRebindCapture
@export var listening_text: String = "Press an input..."
@export var conflict_text: String = "Binding already in use"
@export var unbound_text: String = "Unbound"



func _ready() -> void:
	if target == null:
		target = get_parent() as Button

	if target == null:
		NucleusLog.error(
			"%s requires a Button target or parent." % get_path(),
			&"InputBinding",
		)
		return

	if action == &"":
		NucleusLog.error(
			"%s has no input action assigned." % get_path(),
			&"InputBinding",
		)
		return

	_resolve_capture()

	target.pressed.connect(begin_rebind)
	NucleusInput.action_binding_changed.connect(
		_on_action_binding_changed
	)
	NucleusInput.active_gamepad_changed.connect(
		_on_active_gamepad_changed
	)

	capture.capture_committed.connect(
		_on_capture_committed
	)
	capture.capture_canceled.connect(
		_on_capture_canceled
	)
	capture.capture_failed.connect(
		_on_capture_failed
	)
	capture.conflict_detected.connect(
		_on_conflict_detected
	)
	capture.conflict_rejected.connect(
		_on_conflict_rejected
	)

	_update_text()


func _exit_tree() -> void:
	if target and target.pressed.is_connected(begin_rebind):
		target.pressed.disconnect(begin_rebind)

	if (
		NucleusInput.action_binding_changed.is_connected(
			_on_action_binding_changed
		)
	):
		NucleusInput.action_binding_changed.disconnect(
			_on_action_binding_changed
		)

	if (
		NucleusInput.active_gamepad_changed.is_connected(
			_on_active_gamepad_changed
		)
	):
		NucleusInput.active_gamepad_changed.disconnect(
			_on_active_gamepad_changed
		)

	_disconnect_capture()


## Starts listening for a replacement hardware event.
func begin_rebind() -> void:
	if capture == null:
		return

	capture.joypad_axis_capture_threshold = (
		joypad_axis_capture_threshold
	)

	var policy: int = (
		NucleusInputRebindCapture.ConflictPolicy.ALLOW
	)

	if prompt_conflicts:
		policy = NucleusInputRebindCapture.ConflictPolicy.PROMPT
	elif not allow_conflicts:
		policy = NucleusInputRebindCapture.ConflictPolicy.REJECT

	var error: Error = capture.begin_capture(
		action,
		source,
		binding_index,
		policy,
	)

	if error != OK:
		return

	target.text = listening_text
	rebind_started.emit(action)


## Cancels an active capture without modifying the binding.
func cancel_rebind() -> void:
	if capture == null:
		return

	if not _capture_matches():
		return

	capture.cancel_capture()


## Accepts the pending conflicting binding when prompt_conflicts is enabled.
func accept_conflict() -> Error:
	if capture == null or not _capture_matches():
		return ERR_DOES_NOT_EXIST

	return capture.accept_pending_conflict()


## Rejects the pending conflict and resumes listening.
func reject_conflict() -> void:
	if capture and _capture_matches():
		capture.reject_pending_conflict()


func _resolve_capture() -> void:
	if capture:
		return

	capture = NucleusInputRebindCapture.new()
	capture.name = "InputRebindCapture"
	add_child(capture)


func _disconnect_capture() -> void:
	if capture == null:
		return

	if capture.capture_committed.is_connected(
		_on_capture_committed
	):
		capture.capture_committed.disconnect(
			_on_capture_committed
		)

	if capture.capture_canceled.is_connected(
		_on_capture_canceled
	):
		capture.capture_canceled.disconnect(
			_on_capture_canceled
		)

	if capture.capture_failed.is_connected(
		_on_capture_failed
	):
		capture.capture_failed.disconnect(
			_on_capture_failed
		)

	if capture.conflict_detected.is_connected(
		_on_conflict_detected
	):
		capture.conflict_detected.disconnect(
			_on_conflict_detected
		)

	if capture.conflict_rejected.is_connected(
		_on_conflict_rejected
	):
		capture.conflict_rejected.disconnect(
			_on_conflict_rejected
		)


func _capture_matches() -> bool:
	return (
		capture
		and capture.get_action() == action
		and capture.get_source() == source
		and capture.get_binding_index() == binding_index
	)


func _matches_values(
	captured_action: StringName,
	captured_source: int,
	captured_index: int,
) -> bool:
	return (
		captured_action == action
		and captured_source == source
		and captured_index == binding_index
	)


func _update_text() -> void:
	if target == null:
		return

	var binding_text: String = NucleusInput.get_binding_text(
		action,
		source,
		binding_index,
	)

	target.text = unbound_text if binding_text.is_empty() else binding_text


func _on_capture_committed(
	captured_action: StringName,
	captured_source: int,
	captured_index: int,
	event: InputEvent,
) -> void:
	if not _matches_values(
		captured_action,
		captured_source,
		captured_index,
	):
		return

	_update_text()
	rebind_finished.emit(
		action,
		event,
	)


func _on_capture_canceled(
	captured_action: StringName,
	captured_source: int,
	captured_index: int,
) -> void:
	if _matches_values(
		captured_action,
		captured_source,
		captured_index,
	):
		_update_text()


func _on_capture_failed(
	captured_action: StringName,
	captured_source: int,
	captured_index: int,
	_error: Error,
) -> void:
	if _matches_values(
		captured_action,
		captured_source,
		captured_index,
	):
		target.text = listening_text


func _on_conflict_detected(
	captured_action: StringName,
	captured_source: int,
	captured_index: int,
	event: InputEvent,
	conflicts: Array[StringName],
) -> void:
	if not _matches_values(
		captured_action,
		captured_source,
		captured_index,
	):
		return

	if prompt_conflicts:
		target.text = conflict_text

	conflict_detected.emit(
		action,
		event,
		conflicts,
	)


func _on_conflict_rejected(
	captured_action: StringName,
	captured_source: int,
	captured_index: int,
) -> void:
	if _matches_values(
		captured_action,
		captured_source,
		captured_index,
	):
		target.text = listening_text


func _on_action_binding_changed(changed_action: StringName) -> void:
	if changed_action == action and not _capture_matches():
		_update_text()


func _on_active_gamepad_changed(
	_device_id: int,
	_family: int,
) -> void:
	if (
		source == NucleusInputTypes.Source.GAMEPAD
		and not _capture_matches()
	):
		_update_text()
