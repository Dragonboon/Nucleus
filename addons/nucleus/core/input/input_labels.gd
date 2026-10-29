class_name NucleusInputLabels
extends RefCounted
## Converts bindable InputEvents into short user-facing labels.


static func event_to_text(
	event: InputEvent,
	gamepad_family: int = NucleusInputTypes.GamepadFamily.GENERIC,
) -> String:
	if event is InputEventKey:
		return _key_to_text(event)

	if event is InputEventMouseButton:
		return _mouse_button_to_text(event)

	if event is InputEventJoypadButton:
		return NucleusGamepad.get_button_label(
			event.button_index,
			gamepad_family,
		)

	if event is InputEventJoypadMotion:
		return NucleusGamepad.get_axis_label(
			event.axis,
			event.axis_value,
			gamepad_family,
		)

	return event.as_text() if event else ""


static func _key_to_text(event: InputEventKey) -> String:
	var key_label: Key = event.key_label

	if key_label == KEY_NONE and event.physical_keycode != KEY_NONE:
		key_label = DisplayServer.keyboard_get_label_from_physical(
			event.physical_keycode
		)

	if key_label == KEY_NONE:
		key_label = event.keycode

	var parts := PackedStringArray()

	if event.ctrl_pressed:
		parts.append("Ctrl")

	if event.alt_pressed:
		parts.append("Alt")

	if event.shift_pressed:
		parts.append("Shift")

	if event.meta_pressed:
		parts.append("Cmd" if OS.get_name() == "macOS" else "Meta")

	parts.append(OS.get_keycode_string(key_label))

	return "+".join(parts)


static func _mouse_button_to_text(event: InputEventMouseButton) -> String:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "Wheel Right"
		MOUSE_BUTTON_XBUTTON1:
			return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2:
			return "Mouse 5"
		_:
			return "Mouse %d" % event.button_index
