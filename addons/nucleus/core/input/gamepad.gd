class_name NucleusGamepad
extends RefCounted
## Gamepad family detection and text-label helpers.
##
## Godot normalizes supported controllers through its SDL-derived controller
## database. Family detection is presentation-only and never affects bindings.


static func detect_family(device_id: int) -> int:
	if device_id < 0 or device_id not in Input.get_connected_joypads():
		return NucleusInputTypes.GamepadFamily.GENERIC

	var normalized_name: String = Input.get_joy_name(device_id).to_lower()
	var joy_info: Dictionary = Input.get_joy_info(device_id)
	var raw_name: String = str(joy_info.get("raw_name", "")).to_lower()
	var searchable_name: String = "%s %s" % [normalized_name, raw_name]

	if (
			searchable_name.contains("xbox")
			or searchable_name.contains("xinput")
	):
		return NucleusInputTypes.GamepadFamily.XBOX

	if (
			searchable_name.contains("dualsense")
			or searchable_name.contains("dualshock")
			or searchable_name.contains("playstation")
			or searchable_name.contains("ps3")
			or searchable_name.contains("ps4")
			or searchable_name.contains("ps5")
	):
		return NucleusInputTypes.GamepadFamily.PLAYSTATION

	if (
			searchable_name.contains("nintendo")
			or searchable_name.contains("switch")
			or searchable_name.contains("joy-con")
	):
		return NucleusInputTypes.GamepadFamily.NINTENDO

	if (
			searchable_name.contains("steam")
			or searchable_name.contains("valve")
	):
		return NucleusInputTypes.GamepadFamily.STEAM

	return NucleusInputTypes.GamepadFamily.GENERIC


static func get_button_label(button: int, family: int) -> String:
	match family:
		NucleusInputTypes.GamepadFamily.PLAYSTATION:
			return _get_playstation_button_label(button)

		NucleusInputTypes.GamepadFamily.NINTENDO:
			return _get_nintendo_button_label(button)

		NucleusInputTypes.GamepadFamily.STEAM:
			return _get_steam_button_label(button)

		NucleusInputTypes.GamepadFamily.XBOX:
			return _get_xbox_button_label(button)

		_:
			return _get_generic_button_label(button)


static func get_axis_label(axis: int, axis_value: float, family: int) -> String:
	var positive: bool = axis_value >= 0.0

	match axis:
		JOY_AXIS_LEFT_X:
			return "Left Stick %s" % ("Right" if positive else "Left")

		JOY_AXIS_LEFT_Y:
			return "Left Stick %s" % ("Down" if positive else "Up")

		JOY_AXIS_RIGHT_X:
			return "Right Stick %s" % ("Right" if positive else "Left")

		JOY_AXIS_RIGHT_Y:
			return "Right Stick %s" % ("Down" if positive else "Up")

		JOY_AXIS_TRIGGER_LEFT:
			return _get_trigger_label(false, family)

		JOY_AXIS_TRIGGER_RIGHT:
			return _get_trigger_label(true, family)

		_:
			return "Axis %d %s" % [
				axis,
				"+" if positive else "-",
			]


static func _get_generic_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_GUIDE:
			return "Guide"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad Right"
		_:
			return "Button %d" % button


static func _get_xbox_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_BACK:
			return "View"
		JOY_BUTTON_GUIDE:
			return "Xbox"
		JOY_BUTTON_START:
			return "Menu"
		_:
			return _get_generic_button_label(button)


static func _get_playstation_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "Cross"
		JOY_BUTTON_B:
			return "Circle"
		JOY_BUTTON_X:
			return "Square"
		JOY_BUTTON_Y:
			return "Triangle"
		JOY_BUTTON_BACK:
			return "Create"
		JOY_BUTTON_GUIDE:
			return "PS"
		JOY_BUTTON_START:
			return "Options"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1"
		_:
			return _get_generic_button_label(button)


static func _get_nintendo_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "B"
		JOY_BUTTON_B:
			return "A"
		JOY_BUTTON_X:
			return "Y"
		JOY_BUTTON_Y:
			return "X"
		JOY_BUTTON_BACK:
			return "-"
		JOY_BUTTON_GUIDE:
			return "Home"
		JOY_BUTTON_START:
			return "+"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R"
		_:
			return _get_generic_button_label(button)


static func _get_steam_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_BACK:
			return "View"
		JOY_BUTTON_GUIDE:
			return "Steam"
		JOY_BUTTON_START:
			return "Menu"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1"
		_:
			return _get_generic_button_label(button)


static func _get_trigger_label(right_trigger: bool, family: int) -> String:
	match family:
		NucleusInputTypes.GamepadFamily.PLAYSTATION:
			return "R2" if right_trigger else "L2"

		NucleusInputTypes.GamepadFamily.NINTENDO:
			return "ZR" if right_trigger else "ZL"

		_:
			return "RT" if right_trigger else "LT"
