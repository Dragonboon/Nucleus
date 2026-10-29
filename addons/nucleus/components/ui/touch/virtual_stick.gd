class_name NucleusVirtualStick
extends Control
## Scene-owned virtual stick that feeds semantic InputMap actions.
##
## Bind a local input session for per-player routing, or leave it empty for
## global single-player Input.action_press()/action_release() behavior.

signal vector_changed(value: Vector2)

@export var local_input_session: NucleusLocalInputSession
@export_range(0, 15, 1, "or_greater") var player_index: int = 0

@export_group("Actions")
@export var move_left: StringName = NucleusInputActions.MOVE_LEFT
@export var move_right: StringName = NucleusInputActions.MOVE_RIGHT
@export var move_up: StringName = NucleusInputActions.MOVE_FORWARD
@export var move_down: StringName = NucleusInputActions.MOVE_BACK

@export_group("Feel")
@export_range(16.0, 1024.0, 1.0) var maximum_radius: float = 96.0
@export_range(0.0, 0.95, 0.01) var deadzone: float = 0.12
@export var recenter_on_touch: bool = true

var value: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size * 0.5


func _exit_tree() -> void:
	_release_actions()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index != -1:
			return

		_touch_index = event.index
		if recenter_on_touch:
			_center = event.position
		else:
			_center = size * 0.5

		_update_from_position(event.position)
		accept_event()
		return

	if event.index != _touch_index:
		return

	_touch_index = -1
	_set_value(Vector2.ZERO)
	accept_event()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return

	_update_from_position(event.position)
	accept_event()


func _update_from_position(position: Vector2) -> void:
	var raw: Vector2 = (position - _center) / maximum_radius
	raw = raw.limit_length()

	var magnitude: float = raw.length()
	if magnitude <= deadzone:
		_set_value(Vector2.ZERO)
		return

	var remapped: float = inverse_lerp(deadzone, 1.0, magnitude)
	_set_value(raw.normalized() * remapped)


func _set_value(new_value: Vector2) -> void:
	value = new_value.limit_length()

	_set_action(move_left, maxf(-value.x, 0.0))
	_set_action(move_right, maxf(value.x, 0.0))
	_set_action(move_up, maxf(-value.y, 0.0))
	_set_action(move_down, maxf(value.y, 0.0))

	vector_changed.emit(value)


func _set_action(action: StringName, strength: float) -> void:
	if action == &"" or not InputMap.has_action(action):
		return

	if local_input_session:
		local_input_session.set_touch_action(
			player_index,
			action,
			strength,
		)
		return

	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_actions() -> void:
	_set_value(Vector2.ZERO)
