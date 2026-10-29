class_name NucleusEnvironmentSettingsApplier
extends Node
## Opt-in bridge from NucleusSettings to a scene-owned Environment resource.
##
## The component never creates or owns an Environment. Add it below a
## WorldEnvironment, or assign target explicitly, when a game chooses to expose
## these rendering preferences in its settings catalog.

const LOG_CONTEXT: StringName = &"EnvironmentSettings"

@export var target: WorldEnvironment
@export var use_parent_world_environment: bool = true

var _settings: NucleusSettingsService
var _environment: Environment


func _ready() -> void:
	_settings = get_node_or_null("/root/NucleusSettings") as NucleusSettingsService

	if _settings == null:
		NucleusLog.error("NucleusSettings Autoload is unavailable.", LOG_CONTEXT)
		return

	_environment = _resolve_environment()

	if _environment == null:
		NucleusLog.warning("No Environment target is available.", LOG_CONTEXT)

	_settings.setting_changed.connect(_on_setting_changed)
	_settings.settings_loaded.connect(_apply_all)

	if _settings.is_initialized():
		_apply_all()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if _resolve_environment() == null:
		warnings.append(
			"Assign a WorldEnvironment target or parent this component to one."
		)

	return warnings


## Re-resolves the target and applies every registered Environment setting.
func apply_now() -> void:
	if _settings == null:
		_settings = get_node_or_null("/root/NucleusSettings") as NucleusSettingsService

	if _settings == null:
		return

	_apply_all()


func _resolve_environment() -> Environment:
	if target != null:
		return target.environment

	if use_parent_world_environment:
		var parent_world := get_parent() as WorldEnvironment

		if parent_world != null:
			return parent_world.environment

	return null


func _apply_all() -> void:
	_environment = _resolve_environment()

	if _environment == null:
		return

	_apply_bool_if_registered(
		NucleusSettingIds.ENVIRONMENT_SSAO_ENABLED,
		&"ssao_enabled",
	)
	_apply_bool_if_registered(
		NucleusSettingIds.ENVIRONMENT_SSIL_ENABLED,
		&"ssil_enabled",
	)
	_apply_bool_if_registered(
		NucleusSettingIds.ENVIRONMENT_GLOW_ENABLED,
		&"glow_enabled",
	)
	_apply_bool_if_registered(
		NucleusSettingIds.ENVIRONMENT_VOLUMETRIC_FOG_ENABLED,
		&"volumetric_fog_enabled",
	)
	_apply_bool_if_registered(
		NucleusSettingIds.ENVIRONMENT_SDFGI_ENABLED,
		&"sdfgi_enabled",
	)

	if _settings.has_setting(NucleusSettingIds.ENVIRONMENT_TONEMAP_MODE):
		_apply_tonemap(
			_settings.get_int(NucleusSettingIds.ENVIRONMENT_TONEMAP_MODE)
		)


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	_environment = _resolve_environment()

	if _environment == null:
		return

	if setting_id == NucleusSettingIds.ENVIRONMENT_SSAO_ENABLED:
		_environment.ssao_enabled = bool(value)
	elif setting_id == NucleusSettingIds.ENVIRONMENT_SSIL_ENABLED:
		_environment.ssil_enabled = bool(value)
	elif setting_id == NucleusSettingIds.ENVIRONMENT_GLOW_ENABLED:
		_environment.glow_enabled = bool(value)
	elif setting_id == NucleusSettingIds.ENVIRONMENT_VOLUMETRIC_FOG_ENABLED:
		_environment.volumetric_fog_enabled = bool(value)
	elif setting_id == NucleusSettingIds.ENVIRONMENT_SDFGI_ENABLED:
		_environment.sdfgi_enabled = bool(value)
	elif setting_id == NucleusSettingIds.ENVIRONMENT_TONEMAP_MODE:
		_apply_tonemap(int(value))


func _apply_bool_if_registered(setting_id: StringName, property: StringName) -> void:
	if not _settings.has_setting(setting_id):
		return

	_environment.set(property, _settings.get_bool(setting_id))


@warning_ignore("int_as_enum_without_cast")
func _apply_tonemap(value: int) -> void:
	_environment.tonemap_mode = value
