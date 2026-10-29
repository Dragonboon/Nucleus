class_name NucleusTouchLookArea
extends Control
## Touch-drag look surface for an existing NucleusMotionInput.
##
## This keeps camera rigs device-agnostic: touch contributes pointer delta to
## the same MotionInput already consumed by NucleusLookRig3D.

@export var motion_input: NucleusMotionInput
@export_range(0.01, 10.0, 0.01, "or_greater")
var sensitivity: float = 1.0

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			accept_event()
		return

	if event is InputEventScreenDrag:
		if event.index != _touch_index or motion_input == null:
			return

		motion_input.add_pointer_delta(
			event.relative * sensitivity
		)
		accept_event()
