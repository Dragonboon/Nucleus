class_name NucleusUIAccessibilityBinding
extends Node
## Scene-owned bridge from accessibility settings to game-owned UI presentation.
##
## This component deliberately does not scale Controls or recolor Themes. It
## emits stable preference signals so the game can update its native Theme,
## layout, icons, and contrast treatment without Nucleus owning art direction.

signal ui_scale_changed(value: float)
signal high_contrast_changed(enabled: bool)

var ui_scale: float = 1.0
var high_contrast_enabled: bool = false
var _initialized: bool = false


func _ready() -> void:
	NucleusSettings.setting_changed.connect(_on_setting_changed)
	refresh(true)


func _exit_tree() -> void:
	if NucleusSettings.setting_changed.is_connected(_on_setting_changed):
		NucleusSettings.setting_changed.disconnect(_on_setting_changed)


func refresh(force_emit: bool = false) -> void:
	var next_scale: float = NucleusUIAccessibilityPolicy.get_ui_scale()
	var next_high_contrast: bool = (
		NucleusUIAccessibilityPolicy.is_high_contrast_enabled()
	)

	if force_emit or not _initialized or not is_equal_approx(ui_scale, next_scale):
		ui_scale = next_scale
		ui_scale_changed.emit(ui_scale)

	if (
		force_emit
		or not _initialized
		or high_contrast_enabled != next_high_contrast
	):
		high_contrast_enabled = next_high_contrast
		high_contrast_changed.emit(high_contrast_enabled)

	_initialized = true


func _on_setting_changed(
	setting_id: StringName,
	_value: Variant,
	_previous_value: Variant,
) -> void:
	if setting_id in [
		NucleusSettingIds.ACCESSIBILITY_UI_SCALE,
		NucleusSettingIds.ACCESSIBILITY_HIGH_CONTRAST,
	]:
		refresh()
