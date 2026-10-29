class_name NucleusLocalizationSettingsApplier
extends Node
## Applies the persisted interface locale through TranslationServer.

const LOG_CONTEXT: StringName = &"LocalizationSettings"

var _settings: NucleusSettingsService


func _ready() -> void:
	if not ProjectSettings.get_setting("nucleus/integration/manage_project_preferences", false):
		return
	_settings = get_parent() as NucleusSettingsService

	if _settings == null:
		NucleusLog.error(
			"Localization settings applier requires NucleusSettingsService "
			+ "as parent.",
			LOG_CONTEXT,
		)
		return

	_settings.setting_changed.connect(_on_setting_changed)
	_settings.settings_loaded.connect(_apply_locale)

	if _settings.is_initialized():
		_apply_locale()


func _apply_locale() -> void:
	var requested_locale: String = str(
		_settings.get_value(
			NucleusSettingIds.LOCALIZATION_LOCALE,
			NucleusLocalization.AUTOMATIC_LOCALE,
		)
	)

	var applied_locale: String = NucleusLocalization.apply_locale(
		requested_locale
	)

	if applied_locale.is_empty():
		NucleusLog.warning(
			"Could not resolve locale '%s'." % requested_locale,
			LOG_CONTEXT,
		)


func _on_setting_changed(
	setting_id: StringName,
	_value: Variant,
	_previous_value: Variant,
) -> void:
	if setting_id == NucleusSettingIds.LOCALIZATION_LOCALE:
		_apply_locale()
