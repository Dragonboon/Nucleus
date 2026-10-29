class_name NucleusLocaleOptionBinding
extends Node
## Populates an OptionButton from loaded Godot translations and binds it to
## one persisted String setting.

const DEFAULT_SETTING := preload(
	"res://addons/nucleus/core/settings/defaults/localization_locale.tres"
)
const DEFAULT_CATALOG := preload(
	"res://addons/nucleus/core/localization/defaults/default_locale_catalog.tres"
)

@export var target: OptionButton
@export var setting: NucleusStringSettingDefinition = DEFAULT_SETTING
@export var locale_catalog: NucleusLocaleCatalog = DEFAULT_CATALOG

@export var include_automatic: bool = true
@export var loaded_locales_only: bool = true
@export var use_native_names: bool = true
@export var show_locale_code: bool = false

@export_group("Automatic option")
@export var automatic_label: String = "Automatic"
@export var translate_automatic_label: bool = true


func _enter_tree() -> void:
	if is_node_ready():
		_bind()


func _ready() -> void:
	_bind()


func _bind() -> void:
	if not _resolve_dependencies():
		return
	if not target.item_selected.is_connected(_on_item_selected):
		target.item_selected.connect(_on_item_selected)
	if not NucleusSettings.setting_changed.is_connected(_on_setting_changed):
		NucleusSettings.setting_changed.connect(_on_setting_changed)
	refresh()
	if not NucleusSettings.is_initialized():
		if not NucleusSettings.settings_loaded.is_connected(_sync_from_settings):
			NucleusSettings.settings_loaded.connect(_sync_from_settings, CONNECT_ONE_SHOT)


func refresh() -> void:
	if is_instance_valid(target) and setting != null and is_inside_tree():
		_populate()
		_sync_from_settings()


func _exit_tree() -> void:
	if is_instance_valid(target) and target.item_selected.is_connected(_on_item_selected):
		target.item_selected.disconnect(_on_item_selected)
	if NucleusSettings.setting_changed.is_connected(_on_setting_changed):
		NucleusSettings.setting_changed.disconnect(_on_setting_changed)
	if NucleusSettings.settings_loaded.is_connected(_sync_from_settings):
		NucleusSettings.settings_loaded.disconnect(_sync_from_settings)


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_TRANSLATION_CHANGED
		and is_instance_valid(target)
		and is_inside_tree()
	):
		refresh()


func _resolve_dependencies() -> bool:
	if not is_instance_valid(target):
		target = get_parent() as OptionButton

	if not is_instance_valid(target):
		NucleusLog.error(
			"%s requires an OptionButton target or parent." % get_path(),
			&"LocaleBinding",
		)
		return false

	if setting == null:
		NucleusLog.error(
			"%s requires a String setting definition." % get_path(),
			&"LocaleBinding",
		)
		return false

	return true


func _populate() -> void:
	target.clear()

	if include_automatic:
		_add_option(
			NucleusLocalization.AUTOMATIC_LOCALE,
			_translate_automatic_label(),
		)

	var definitions: Array[NucleusLocaleDefinition] = (
		NucleusLocalization.get_selectable_locales(
			locale_catalog,
			loaded_locales_only,
		)
	)

	for definition: NucleusLocaleDefinition in definitions:
		var locale: String = definition.get_standardized_locale()
		var label: String = definition.get_display_name(
			use_native_names
		)

		if show_locale_code:
			label = "%s [%s]" % [label, locale]

		_add_option(locale, label)


func _add_option(
	locale: String,
	label: String,
) -> void:
	var item_index: int = target.item_count

	target.add_item(label)
	target.set_item_metadata(item_index, locale)


func _sync_from_settings() -> void:
	if not is_instance_valid(target) or setting == null:
		return
	var current_value: String = str(
		NucleusSettings.get_value(
			setting.get_id(),
			setting.get_default_value(),
		)
	)

	for item_index: int in range(target.item_count):
		if (
			str(target.get_item_metadata(item_index))
			== current_value
		):
			target.select(item_index)
			return

	if current_value != NucleusLocalization.AUTOMATIC_LOCALE:
		var resolved := NucleusLocalization.resolve_locale(current_value)
		for item_index: int in range(target.item_count):
			if str(target.get_item_metadata(item_index)) == resolved:
				target.select(item_index)
				return
	if include_automatic and target.item_count > 0:
		target.select(0)


func _translate_automatic_label() -> String:
	if not translate_automatic_label:
		return automatic_label

	return str(tr(automatic_label))


func _on_item_selected(index: int) -> void:
	NucleusSettings.set_value(
		setting.get_id(),
		str(target.get_item_metadata(index)),
	)


func _on_setting_changed(
	setting_id: StringName,
	_value: Variant,
	_previous_value: Variant,
) -> void:
	if setting_id == setting.get_id():
		_sync_from_settings()
