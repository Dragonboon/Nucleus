class_name NucleusInputActivationState
extends RefCounted
## Converts one semantic pressed state into hold or toggle activation semantics.
##
## Create one instance per gameplay action that offers a hold/toggle preference.
## Physical bindings remain owned by InputMap/NucleusInput.

signal active_changed(active: bool)

enum Mode {
	HOLD,
	TOGGLE,
}

var mode: int = Mode.HOLD
var active: bool = false
var _was_pressed: bool = false


func set_mode(value: int, preserve_active: bool = false) -> Error:
	if value not in [Mode.HOLD, Mode.TOGGLE]:
		return ERR_INVALID_PARAMETER

	if mode == value:
		return OK

	mode = value
	_was_pressed = false

	if not preserve_active:
		_set_active(false)

	return OK


func update_state(is_pressed: bool) -> bool:
	if mode == Mode.HOLD:
		_set_active(is_pressed)
	elif is_pressed and not _was_pressed:
		_set_active(not active)

	_was_pressed = is_pressed
	return active


func reset() -> void:
	_was_pressed = false
	_set_active(false)


func _set_active(value: bool) -> void:
	if active == value:
		return

	active = value
	active_changed.emit(active)
