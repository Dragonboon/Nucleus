class_name NucleusMotionInput
extends Node
## Shared move/look input bridge for gameplay movement and cameras.
##
## Global single-player input uses Godot's Input action polling. Couch
## multiplayer binds an existing [NucleusLocalPlayerInput], preserving Core's
## per-device routing. Mouse look remains event-based.

signal input_event_received(event: InputEvent)
signal local_player_input_changed(
	player_input: NucleusLocalPlayerInput,
)

@export var enabled: bool = true

@export_group("Movement actions")
@export var move_left: StringName = NucleusInputActions.MOVE_LEFT
@export var move_right: StringName = NucleusInputActions.MOVE_RIGHT
@export var move_forward: StringName = NucleusInputActions.MOVE_FORWARD
@export var move_back: StringName = NucleusInputActions.MOVE_BACK
@export_range(-1.0, 1.0, 0.01) var move_deadzone: float = -1.0

@export_group("Look actions")
@export var look_left: StringName = NucleusInputActions.LOOK_LEFT
@export var look_right: StringName = NucleusInputActions.LOOK_RIGHT
@export var look_up: StringName = NucleusInputActions.LOOK_UP
@export var look_down: StringName = NucleusInputActions.LOOK_DOWN
@export_range(-1.0, 1.0, 0.01) var look_deadzone: float = -1.0

@export_group("Pointer look")
@export var pointer_requires_captured_mouse: bool = true

var local_player_input: NucleusLocalPlayerInput

var _pointer_delta: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if local_player_input != null:
		return

	_route_event(event)


func _exit_tree() -> void:
	unbind_local_player_input()


func bind_local_player_input(
	player_input: NucleusLocalPlayerInput,
) -> void:
	if local_player_input == player_input:
		return

	unbind_local_player_input()
	local_player_input = player_input

	if local_player_input:
		local_player_input.input_received.connect(
			_on_local_player_input
		)

	clear_pointer_delta()
	local_player_input_changed.emit(local_player_input)


func unbind_local_player_input() -> void:
	if (
		local_player_input
		and local_player_input.input_received.is_connected(
			_on_local_player_input
		)
	):
		local_player_input.input_received.disconnect(
			_on_local_player_input
		)

	if local_player_input:
		local_player_input = null
		clear_pointer_delta()
		local_player_input_changed.emit(null)


func get_move_vector() -> Vector2:
	if not enabled:
		return Vector2.ZERO

	var resolved_deadzone: float = _resolve_deadzone(
		move_deadzone,
		false,
	)

	if local_player_input:
		return local_player_input.get_vector(
			move_left,
			move_right,
			move_forward,
			move_back,
			resolved_deadzone,
		)

	return Input.get_vector(
		move_left,
		move_right,
		move_forward,
		move_back,
		resolved_deadzone,
	)


func get_look_vector() -> Vector2:
	if not enabled:
		return Vector2.ZERO

	var resolved_deadzone: float = _resolve_deadzone(
		look_deadzone,
		true,
	)

	if local_player_input:
		return local_player_input.get_vector(
			look_left,
			look_right,
			look_up,
			look_down,
			resolved_deadzone,
		)

	return Input.get_vector(
		look_left,
		look_right,
		look_up,
		look_down,
		resolved_deadzone,
	)


func get_action_strength(action: StringName) -> float:
	if not enabled or action == &"" or not InputMap.has_action(action):
		return 0.0

	if local_player_input:
		return local_player_input.get_action_strength(action)

	return Input.get_action_strength(action)


func is_action_pressed(action: StringName) -> bool:
	if not enabled or action == &"" or not InputMap.has_action(action):
		return false

	if local_player_input:
		return local_player_input.is_action_pressed(action)

	return Input.is_action_pressed(action)


func consume_pointer_delta() -> Vector2:
	var result: Vector2 = _pointer_delta
	_pointer_delta = Vector2.ZERO
	return result


func peek_pointer_delta() -> Vector2:
	return _pointer_delta


func add_pointer_delta(delta: Vector2) -> void:
	if enabled:
		_pointer_delta += delta


func clear_pointer_delta() -> void:
	_pointer_delta = Vector2.ZERO


func _on_local_player_input(event: InputEvent) -> void:
	_route_event(event)


func _route_event(event: InputEvent) -> void:
	if not enabled:
		return

	input_event_received.emit(event)

	if not (event is InputEventMouseMotion):
		return

	if local_player_input and not local_player_input.is_keyboard_mouse():
		return

	if (
		pointer_requires_captured_mouse
		and not NucleusCursor.is_captured()
	):
		return

	var mouse_motion := event as InputEventMouseMotion
	_pointer_delta += mouse_motion.screen_relative


func _resolve_deadzone(authored_deadzone: float, look: bool) -> float:
	if authored_deadzone >= 0.0:
		return authored_deadzone

	if not _uses_gamepad_input():
		return -1.0

	if look:
		return NucleusInputAccessibilityPolicy.get_gamepad_look_deadzone()

	return NucleusInputAccessibilityPolicy.get_gamepad_move_deadzone()


func _uses_gamepad_input() -> bool:
	if local_player_input:
		return local_player_input.is_gamepad()

	return NucleusInput.active_source == NucleusInputTypes.Source.GAMEPAD
