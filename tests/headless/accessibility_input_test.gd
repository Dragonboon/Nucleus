extends "res://tests/headless/test_case.gd"

const DEFAULT_CATALOG := preload(
	"res://addons/nucleus/core/settings/defaults/default_settings_catalog.tres"
)


func run() -> Dictionary:
	_test_accessibility_defaults()
	_test_hold_activation()
	_test_toggle_activation()
	return finish()


func _test_accessibility_defaults() -> void:
	var index := DEFAULT_CATALOG.build_index()
	var required_ids: Array[StringName] = [
		NucleusSettingIds.ACCESSIBILITY_UI_SCALE,
		NucleusSettingIds.ACCESSIBILITY_HIGH_CONTRAST,
		NucleusSettingIds.INPUT_MOUSE_LOOK_SENSITIVITY_SCALE,
		NucleusSettingIds.INPUT_GAMEPAD_LOOK_SENSITIVITY_SCALE,
		NucleusSettingIds.INPUT_GAMEPAD_MOVE_DEADZONE,
		NucleusSettingIds.INPUT_GAMEPAD_LOOK_DEADZONE,
	]

	for setting_id: StringName in required_ids:
		expect_true(
			index.has(setting_id),
			"Default catalog includes %s" % setting_id,
		)

	expect_float(
		index[NucleusSettingIds.ACCESSIBILITY_UI_SCALE].get_default_value(),
		1.0,
		"UI scale is neutral by default",
	)
	expect_false(
		bool(
			index[NucleusSettingIds.ACCESSIBILITY_HIGH_CONTRAST].get_default_value()
		),
		"High contrast remains opt-in",
	)
	expect_float(
		index[
			NucleusSettingIds.INPUT_GAMEPAD_MOVE_DEADZONE
		].get_default_value(),
		0.2,
		"Controller movement deadzone has a conservative default",
	)


func _test_hold_activation() -> void:
	var state := NucleusInputActivationState.new()

	expect_false(state.update_state(false), "Hold starts inactive")
	expect_true(state.update_state(true), "Hold follows a pressed action")
	expect_true(state.update_state(true), "Hold remains active while pressed")
	expect_false(state.update_state(false), "Hold releases with the action")


func _test_toggle_activation() -> void:
	var state := NucleusInputActivationState.new()
	expect_equal(
		state.set_mode(NucleusInputActivationState.Mode.TOGGLE),
		OK,
		"Toggle mode can be selected",
	)

	expect_true(state.update_state(true), "First press toggles on")
	expect_true(state.update_state(true), "Held button does not retrigger toggle")
	expect_true(state.update_state(false), "Release preserves toggled state")
	expect_false(state.update_state(true), "Second press toggles off")

	state.reset()
	expect_false(state.active, "Reset clears toggle state")
	expect_equal(
		state.set_mode(99),
		ERR_INVALID_PARAMETER,
		"Invalid activation modes are rejected",
	)
