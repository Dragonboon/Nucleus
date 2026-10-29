class_name NucleusRangeSettingBinding
extends Node
## Binds an integer or float setting to any Godot Range control.

@export var setting: NucleusSettingDefinition
@export var target: Range
@export var configure_range_from_definition: bool = true


func _ready() -> void:
	if not _resolve_dependencies():
		return

	if configure_range_from_definition:
		_configure_range()

	target.value_changed.connect(_on_value_changed)
	NucleusSettings.setting_changed.connect(_on_setting_changed)

	if NucleusSettings.is_initialized():
		_sync_from_settings()
	else:
		NucleusSettings.settings_loaded.connect(
			_sync_from_settings,
			CONNECT_ONE_SHOT,
		)


func _resolve_dependencies() -> bool:
	if not (
			setting is NucleusIntSettingDefinition
			or setting is NucleusFloatSettingDefinition
	):
		NucleusLog.error(
			"%s requires an int or float setting definition." % get_path(),
			&"SettingsBinding",
		)
		return false

	if target == null:
		target = get_parent() as Range

	if target == null:
		NucleusLog.error(
			"%s requires a Range target or parent." % get_path(),
			&"SettingsBinding",
		)
		return false

	return true


func _configure_range() -> void:
	if setting is NucleusIntSettingDefinition:
		var int_setting := setting as NucleusIntSettingDefinition
		target.step = int_setting.step
		target.rounded = true

		if int_setting.has_range:
			target.min_value = int_setting.minimum_value
			target.max_value = int_setting.maximum_value
			target.allow_lesser = false
			target.allow_greater = false

	elif setting is NucleusFloatSettingDefinition:
		var float_setting := setting as NucleusFloatSettingDefinition
		target.step = float_setting.step

		if float_setting.has_range:
			target.min_value = float_setting.minimum_value
			target.max_value = float_setting.maximum_value
			target.allow_lesser = false
			target.allow_greater = false


func _sync_from_settings() -> void:
	target.set_value_no_signal(
		float(
			NucleusSettings.get_value(
				setting.get_id(),
				setting.get_default_value(),
			)
		)
	)


func _on_value_changed(value: float) -> void:
	if setting is NucleusIntSettingDefinition:
		NucleusSettings.set_value(
			setting.get_id(),
			int(round(value)),
		)
	else:
		NucleusSettings.set_value(setting.get_id(), value)


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	if setting_id != setting.get_id():
		return

	target.set_value_no_signal(float(value))
