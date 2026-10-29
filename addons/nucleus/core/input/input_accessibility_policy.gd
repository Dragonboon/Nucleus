class_name NucleusInputAccessibilityPolicy
extends RefCounted
## Resolves reusable input accessibility preferences from NucleusSettings.
##
## Authored component values remain the baseline. Sensitivity settings are
## multipliers, while deadzone settings are defaults used only when a consuming
## component has not supplied an explicit override.

const MIN_SENSITIVITY_SCALE: float = 0.1
const MAX_SENSITIVITY_SCALE: float = 4.0
const MIN_DEADZONE: float = 0.0
const MAX_DEADZONE: float = 0.95


static func get_mouse_look_sensitivity_scale() -> float:
	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.INPUT_MOUSE_LOOK_SENSITIVITY_SCALE,
			1.0,
		),
		MIN_SENSITIVITY_SCALE,
		MAX_SENSITIVITY_SCALE,
	)


static func get_gamepad_look_sensitivity_scale() -> float:
	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.INPUT_GAMEPAD_LOOK_SENSITIVITY_SCALE,
			1.0,
		),
		MIN_SENSITIVITY_SCALE,
		MAX_SENSITIVITY_SCALE,
	)


static func get_gamepad_move_deadzone() -> float:
	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.INPUT_GAMEPAD_MOVE_DEADZONE,
			0.2,
		),
		MIN_DEADZONE,
		MAX_DEADZONE,
	)


static func get_gamepad_look_deadzone() -> float:
	return clampf(
		NucleusSettings.get_float(
			NucleusSettingIds.INPUT_GAMEPAD_LOOK_DEADZONE,
			0.2,
		),
		MIN_DEADZONE,
		MAX_DEADZONE,
	)
