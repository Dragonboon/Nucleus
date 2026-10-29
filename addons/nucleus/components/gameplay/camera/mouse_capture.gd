class_name NucleusMouseCapture
extends Node
## Scene-owned mouse capture policy built on [NucleusCursor].
##
## The component never owns pause-menu behavior. Games may call [method release]
## and [method capture] explicitly when opening or closing UI.

signal captured
signal released

@export var capture_on_ready: bool = true
@export var restore_previous_mode_on_exit: bool = true
@export var release_on_application_pause: bool = true
@export var recapture_on_application_resume: bool = true

var _previous_mode: int = Input.MOUSE_MODE_VISIBLE
var _resume_should_capture: bool = false


func _ready() -> void:
	_previous_mode = NucleusCursor.get_mode()

	if release_on_application_pause:
		NucleusApp.application_paused.connect(
			_on_application_paused
		)

	if recapture_on_application_resume:
		NucleusApp.application_resumed.connect(
			_on_application_resumed
		)

	if capture_on_ready:
		capture()


func _exit_tree() -> void:
	if (
		release_on_application_pause
		and NucleusApp.application_paused.is_connected(
			_on_application_paused
		)
	):
		NucleusApp.application_paused.disconnect(
			_on_application_paused
		)

	if (
		recapture_on_application_resume
		and NucleusApp.application_resumed.is_connected(
			_on_application_resumed
		)
	):
		NucleusApp.application_resumed.disconnect(
			_on_application_resumed
		)

	if restore_previous_mode_on_exit:
		NucleusCursor.set_mode(_previous_mode)


func capture() -> void:
	if NucleusCursor.is_captured():
		return

	NucleusCursor.capture()
	captured.emit()


func release() -> void:
	if NucleusCursor.is_visible():
		return

	NucleusCursor.show()
	released.emit()


func toggle() -> void:
	if NucleusCursor.is_captured():
		release()
	else:
		capture()


func _on_application_paused() -> void:
	_resume_should_capture = NucleusCursor.is_captured()

	if _resume_should_capture:
		release()


func _on_application_resumed() -> void:
	if (
		recapture_on_application_resume
		and _resume_should_capture
	):
		capture()

	_resume_should_capture = false
