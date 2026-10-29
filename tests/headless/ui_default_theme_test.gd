extends "res://tests/headless/test_case.gd"

const BASE: Theme = preload("res://addons/nucleus/components/ui/theme/nucleus_base_theme.tres")
const HIGH: Theme = preload(
	"res://addons/nucleus/components/ui/theme/nucleus_high_contrast_theme.tres"
)
const BASE_PATH: String = "res://addons/nucleus/components/ui/theme/nucleus_base_theme.tres"


func run() -> Dictionary:
	_test_project_default()
	_test_button_states(BASE, "Default")
	_test_button_states(HIGH, "High contrast")
	_test_text_contrast()
	_test_focus_visibility()
	_test_native_control_coverage()
	_test_game_can_override_without_mutation()
	_test_surface_parity_and_scrollbars()
	return finish()


func _test_project_default() -> void:
	expect_equal(
		str(ProjectSettings.get_setting("gui/theme/custom", "")),
		BASE_PATH,
		"A freshly started project uses the baseline Theme automatically.",
	)
	expect_equal(BASE.default_font_size, 18, "Baseline font is readable by default.")
	expect_equal(HIGH.default_font_size, 18, "Contrast variant preserves geometry.")
	expect_true(BASE.default_font == null, "Do not force an external font asset.")


func _test_button_states(theme_resource: Theme, context: String) -> void:
	for name: StringName in [
		&"normal", &"hover", &"pressed", &"disabled", &"focus",
	]:
		expect_true(
			theme_resource.has_stylebox(name, &"Button"),
			"%s: Button exposes the %s state." % [context, name],
		)
	var normal := theme_resource.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	expect_true(normal != null, "%s: Button uses native StyleBoxFlat." % context)
	if normal != null:
		expect_true(
			normal.content_margin_top >= 11 and normal.content_margin_bottom >= 11,
			"%s: Button has larger vertical interaction padding." % context,
		)


func _test_text_contrast() -> void:
	for theme_resource: Theme in [BASE, HIGH]:
		var button := theme_resource.get_stylebox(&"normal", &"Button") as StyleBoxFlat
		var foreground := theme_resource.get_color(&"font_color", &"Button")
		expect_true(
			_contrast(foreground, button.bg_color) >= 4.5,
			"Normal Button text meets the WCAG AA normal-text contrast threshold.",
		)
		var input := theme_resource.get_stylebox(&"normal", &"LineEdit") as StyleBoxFlat
		var input_text := theme_resource.get_color(&"font_color", &"LineEdit")
		expect_true(
			_contrast(input_text, input.bg_color) >= 4.5,
			"Text input has readable normal-text contrast.",
		)


func _test_focus_visibility() -> void:
	for theme_resource: Theme in [BASE, HIGH]:
		var focus := theme_resource.get_stylebox(&"focus", &"Button") as StyleBoxFlat
		expect_true(focus != null, "Native focus StyleBox exists.")
		if focus != null:
			expect_true(
				focus.border_width_left >= 2 and not focus.draw_center,
				"Focus draws a prominent outline without obscuring the control.",
			)
		expect_true(
			theme_resource.has_stylebox(&"focus", &"LineEdit"),
			"Keyboard focus also applies to text inputs.",
		)


func _test_native_control_coverage() -> void:
	for type_name: StringName in [
		&"Button", &"OptionButton", &"CheckBox", &"CheckButton", &"LineEdit",
		&"TextEdit", &"PanelContainer", &"ProgressBar", &"Tree", &"ItemList",
		&"TabContainer", &"PopupMenu",
	]:
		expect_true(BASE.get_theme_item_list(Theme.DATA_TYPE_STYLEBOX, type_name).size() > 0,
			"Base Theme contains styles for %s." % type_name)


func _test_surface_parity_and_scrollbars() -> void:
	for theme_resource: Theme in [BASE, HIGH]:
		for type_name: StringName in [
			&"HScrollBar", &"VScrollBar",
		]:
			for part: StringName in [
				&"scroll", &"grabber", &"grabber_highlight",
				&"grabber_pressed",
			]:
				expect_true(
					theme_resource.has_stylebox(part, type_name),
					"%s has a themed %s." % [type_name, part],
				)
		for type_name: StringName in [&"HSeparator", &"VSeparator"]:
			expect_true(
				theme_resource.has_stylebox(&"separator", type_name),
				"%s uses the shared separator token." % type_name,
			)
		var progress_bg := (
			theme_resource.get_stylebox(&"background", &"ProgressBar")
			as StyleBoxFlat
		)
		var progress_fg := (
			theme_resource.get_stylebox(&"fill", &"ProgressBar")
			as StyleBoxFlat
		)
		expect_true(
			progress_bg != null and progress_fg != null,
			"ProgressBar has separate neutral track and visible progress.",
		)
		if progress_bg != null and progress_fg != null:
			expect_true(
				_contrast(progress_fg.bg_color, progress_bg.bg_color) >= 3.0,
				"Progress amount contrasts with its track by at least 3:1.",
			)
		for type_name: StringName in [
			&"Button", &"MenuButton", &"OptionButton",
		]:
			for state: StringName in [&"normal", &"hover", &"pressed"]:
				var surface := (
					theme_resource.get_stylebox(state, type_name)
					as StyleBoxFlat
				)
				var text_color := theme_resource.get_color(
					&"font_color", type_name
				)
				expect_true(
					surface != null and (
						_contrast(text_color, surface.bg_color) >= 4.5
					),
					"%s %s remains readable." % [type_name, state],
				)


func _test_game_can_override_without_mutation() -> void:
	var original := BASE.get_color(&"font_color", &"Button")
	var customized := BASE.duplicate(true) as Theme
	customized.set_color(&"font_color", &"Button", Color(1.0, 0.1, 0.1))
	expect_true(
		BASE.get_color(&"font_color", &"Button").is_equal_approx(original),
		"A game's duplicated Theme cannot modify the shared template Theme.",
	)


func _contrast(a: Color, b: Color) -> float:
	var first := _luminance(a)
	var second := _luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


func _luminance(color: Color) -> float:
	return (
		0.2126 * _linear(color.r)
		+ 0.7152 * _linear(color.g)
		+ 0.0722 * _linear(color.b)
	)


func _linear(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)
