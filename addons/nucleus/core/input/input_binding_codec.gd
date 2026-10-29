class_name NucleusInputBindingCodec
extends RefCounted
## Stable serialization for InputEvent types supported by runtime rebinding.
##
## Display text is never persisted. Only engine-level binding data is stored.

const INPUT_MAP_ALL_DEVICES: int = -1

const TYPE_KEY: StringName = &"key"
const TYPE_MOUSE_BUTTON: StringName = &"mouse_button"
const TYPE_JOYPAD_BUTTON: StringName = &"joypad_button"
const TYPE_JOYPAD_MOTION: StringName = &"joypad_motion"


static func is_bindable_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		or event is InputEventMouseButton
		or event is InputEventJoypadButton
		or event is InputEventJoypadMotion
	)


static func is_capture_candidate(
	event: InputEvent,
	axis_threshold: float = 0.7,
) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo

	if event is InputEventMouseButton:
		return event.pressed

	if event is InputEventJoypadButton:
		return event.pressed

	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= axis_threshold

	return false


static func get_source(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return NucleusInputTypes.Source.KEYBOARD_MOUSE

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return NucleusInputTypes.Source.GAMEPAD

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return NucleusInputTypes.Source.TOUCH

	return NucleusInputTypes.Source.ANY


static func normalize(event: InputEvent) -> InputEvent:
	if not is_bindable_event(event):
		return null

	return decode(encode(event))


static func encode_events(events: Array[InputEvent]) -> Array[Dictionary]:
	var encoded_events: Array[Dictionary] = []

	for event: InputEvent in events:
		var encoded_event: Dictionary = encode(event)

		if not encoded_event.is_empty():
			encoded_events.append(encoded_event)

	return encoded_events


static func decode_events(encoded_events: Array) -> Array[InputEvent]:
	var events: Array[InputEvent] = []

	for encoded_event: Variant in encoded_events:
		if typeof(encoded_event) != TYPE_DICTIONARY:
			continue

		var event: InputEvent = decode(encoded_event)

		if event:
			events.append(event)

	return events


static func encode(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var physical_keycode: int = int(event.physical_keycode)
		var keycode: int = int(event.keycode)

		if physical_keycode != KEY_NONE:
			keycode = KEY_NONE

		if physical_keycode == KEY_NONE and keycode == KEY_NONE:
			return {}

		return {
			"type": TYPE_KEY,
			"physical_keycode": physical_keycode,
			"keycode": keycode,
			"location": int(event.location),
			"alt": event.alt_pressed,
			"shift": event.shift_pressed,
			"ctrl": event.ctrl_pressed,
			"meta": event.meta_pressed,
		}

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_NONE:
			return {}

		return {
			"type": TYPE_MOUSE_BUTTON,
			"button_index": int(event.button_index),
			"alt": event.alt_pressed,
			"shift": event.shift_pressed,
			"ctrl": event.ctrl_pressed,
			"meta": event.meta_pressed,
		}

	if event is InputEventJoypadButton:
		return {
			"type": TYPE_JOYPAD_BUTTON,
			"button_index": int(event.button_index),
		}

	if event is InputEventJoypadMotion:
		if is_zero_approx(event.axis_value):
			return {}

		return {
			"type": TYPE_JOYPAD_MOTION,
			"axis": int(event.axis),
			"axis_value": -1.0 if event.axis_value < 0.0 else 1.0,
		}

	return {}


static func decode(data: Dictionary) -> InputEvent:
	var binding_type := StringName(str(data.get("type", "")))

	match binding_type:
		TYPE_KEY:
			var key_event := InputEventKey.new()
			key_event.device = INPUT_MAP_ALL_DEVICES
			key_event.physical_keycode = (
				int(data.get("physical_keycode", KEY_NONE)) as Key
			)
			key_event.keycode = int(data.get("keycode", KEY_NONE)) as Key
			key_event.location = int(data.get("location", 0)) as KeyLocation
			_apply_modifiers(key_event, data)
			return key_event

		TYPE_MOUSE_BUTTON:
			var mouse_event := InputEventMouseButton.new()
			mouse_event.device = INPUT_MAP_ALL_DEVICES
			mouse_event.button_index = (
				int(data.get("button_index", MOUSE_BUTTON_NONE)) as MouseButton
			)
			_apply_modifiers(mouse_event, data)
			return mouse_event

		TYPE_JOYPAD_BUTTON:
			var button_event := InputEventJoypadButton.new()
			button_event.device = INPUT_MAP_ALL_DEVICES
			button_event.button_index = (
				int(data.get("button_index", JOY_BUTTON_INVALID)) as JoyButton
			)
			return button_event

		TYPE_JOYPAD_MOTION:
			var motion_event := InputEventJoypadMotion.new()
			motion_event.device = INPUT_MAP_ALL_DEVICES
			motion_event.axis = (
				int(data.get("axis", JOY_AXIS_LEFT_X)) as JoyAxis
			)
			motion_event.axis_value = (
				-1.0
				if float(data.get("axis_value", 1.0)) < 0.0
				else 1.0
			)
			return motion_event

		_:
			return null


static func _apply_modifiers(
	event: InputEventWithModifiers,
	data: Dictionary,
) -> void:
	event.alt_pressed = bool(data.get("alt", false))
	event.shift_pressed = bool(data.get("shift", false))
	event.ctrl_pressed = bool(data.get("ctrl", false))
	event.meta_pressed = bool(data.get("meta", false))
