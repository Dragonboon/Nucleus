class_name NucleusLocalInputReader
extends RefCounted
## Polls InputMap actions for one specific local hardware device.
##
## Godot's global action polling aggregates every device. This helper evaluates
## the same InputMap bindings against one keyboard/mouse seat or one joypad id.

static func get_action_strength(
	source: int,
	device_id: int,
	action: StringName,
) -> float:
	if not InputMap.has_action(action):
		return 0.0

	var raw_strength: float = get_action_raw_strength(
		source,
		device_id,
		action,
	)
	var deadzone: float = InputMap.action_get_deadzone(action)

	if raw_strength <= deadzone:
		return 0.0

	return inverse_lerp(deadzone, 1.0, raw_strength)


static func get_action_raw_strength(
	source: int,
	device_id: int,
	action: StringName,
) -> float:
	if not InputMap.has_action(action):
		return 0.0

	var strength: float = 0.0

	for event: InputEvent in InputMap.action_get_events(action):
		strength = maxf(
			strength,
			_get_event_strength(
				source,
				device_id,
				event,
			),
		)

	return strength


static func is_action_pressed(
	source: int,
	device_id: int,
	action: StringName,
) -> bool:
	return get_action_strength(source, device_id, action) > 0.0


static func get_axis(
	source: int,
	device_id: int,
	negative_action: StringName,
	positive_action: StringName,
) -> float:
	return (
		get_action_strength(source, device_id, positive_action)
		- get_action_strength(source, device_id, negative_action)
	)


static func get_vector(
	source: int,
	device_id: int,
	negative_x: StringName,
	positive_x: StringName,
	negative_y: StringName,
	positive_y: StringName,
	deadzone: float = -1.0,
) -> Vector2:
	var vector := Vector2(
		get_action_raw_strength(source, device_id, positive_x)
		- get_action_raw_strength(source, device_id, negative_x),
		get_action_raw_strength(source, device_id, positive_y)
		- get_action_raw_strength(source, device_id, negative_y),
	).limit_length()

	var resolved_deadzone: float = deadzone

	if resolved_deadzone < 0.0:
		resolved_deadzone = (
			InputMap.action_get_deadzone(negative_x)
			+ InputMap.action_get_deadzone(positive_x)
			+ InputMap.action_get_deadzone(negative_y)
			+ InputMap.action_get_deadzone(positive_y)
		) * 0.25

	var vector_length: float = vector.length()

	if vector_length <= resolved_deadzone:
		return Vector2.ZERO

	if is_zero_approx(vector_length):
		return Vector2.ZERO

	return (
		vector / vector_length
		* inverse_lerp(resolved_deadzone, 1.0, vector_length)
	)


static func _get_event_strength(
	source: int,
	device_id: int,
	event: InputEvent,
) -> float:
	if source == NucleusInputTypes.Source.KEYBOARD_MOUSE:
		return _get_keyboard_mouse_strength(event)

	if source == NucleusInputTypes.Source.GAMEPAD:
		return _get_gamepad_strength(device_id, event)

	return 0.0


static func _get_keyboard_mouse_strength(event: InputEvent) -> float:
	if event is InputEventKey:
		if not _required_modifiers_are_pressed(event):
			return 0.0

		if event.physical_keycode != KEY_NONE:
			return (
				1.0
				if Input.is_physical_key_pressed(event.physical_keycode)
				else 0.0
			)

		if event.keycode != KEY_NONE:
			return 1.0 if Input.is_key_pressed(event.keycode) else 0.0

	if event is InputEventMouseButton:
		if not _required_modifiers_are_pressed(event):
			return 0.0

		return (
			1.0
			if Input.is_mouse_button_pressed(event.button_index)
			else 0.0
		)

	return 0.0


@warning_ignore("int_as_enum_without_cast")
static func _get_gamepad_strength(
	device_id: int,
	event: InputEvent,
) -> float:
	if device_id not in Input.get_connected_joypads():
		return 0.0

	if event is InputEventJoypadButton:
		return (
			1.0
			if Input.is_joy_button_pressed(device_id, event.button_index)
			else 0.0
		)

	if event is InputEventJoypadMotion:
		var axis_value: float = Input.get_joy_axis(
			device_id,
			event.axis,
		)
		var direction: float = -1.0 if event.axis_value < 0.0 else 1.0

		return clampf(axis_value * direction, 0.0, 1.0)

	return 0.0


static func _required_modifiers_are_pressed(
	event: InputEventWithModifiers,
) -> bool:
	if event.shift_pressed and not Input.is_key_pressed(KEY_SHIFT):
		return false

	if event.ctrl_pressed and not Input.is_key_pressed(KEY_CTRL):
		return false

	if event.alt_pressed and not Input.is_key_pressed(KEY_ALT):
		return false

	if event.meta_pressed and not Input.is_key_pressed(KEY_META):
		return false

	return true
