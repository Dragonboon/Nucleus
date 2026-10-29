class_name NucleusBoolSettingBinding
extends Node
## Binds a boolean setting to any BaseButton used as a toggle.

@export var setting: NucleusBoolSettingDefinition
@export var target: BaseButton


func _ready() -> void:
	if not _resolve_dependencies():
		return

	target.toggle_mode = true
	target.toggled.connect(_on_toggled)
	NucleusSettings.setting_changed.connect(_on_setting_changed)

	if NucleusSettings.is_initialized():
		_sync_from_settings()
	else:
		NucleusSettings.settings_loaded.connect(
			_sync_from_settings,
			CONNECT_ONE_SHOT,
		)


func _resolve_dependencies() -> bool:
	if setting == null:
		NucleusLog.error(
			"%s has no boolean setting assigned." % get_path(),
			&"SettingsBinding",
		)
		return false

	if target == null:
		target = get_parent() as BaseButton

	if target == null:
		NucleusLog.error(
			"%s requires a BaseButton target or parent." % get_path(),
			&"SettingsBinding",
		)
		return false

	return true


func _sync_from_settings() -> void:
	target.set_pressed_no_signal(
		NucleusSettings.get_bool(
			setting.get_id(),
			setting.default_value,
		)
	)


func _on_toggled(enabled: bool) -> void:
	NucleusSettings.set_value(setting.get_id(), enabled)


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	if setting_id != setting.get_id():
		return

	target.set_pressed_no_signal(bool(value))
