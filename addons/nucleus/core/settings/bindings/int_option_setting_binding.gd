class_name NucleusIntOptionSettingBinding
extends Node
## Populates and binds an OptionButton from an integer option definition.

@export var setting: NucleusIntOptionSettingDefinition
@export var target: OptionButton
@export var clear_existing_items: bool = true


func _ready() -> void:
	if not _resolve_dependencies():
		return

	_populate_options()
	target.item_selected.connect(_on_item_selected)
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
			"%s has no option setting assigned." % get_path(),
			&"SettingsBinding",
		)
		return false

	if target == null:
		target = get_parent() as OptionButton

	if target == null:
		NucleusLog.error(
			"%s requires an OptionButton target or parent." % get_path(),
			&"SettingsBinding",
		)
		return false

	return true


func _populate_options() -> void:
	if clear_existing_items:
		target.clear()

	for option: NucleusIntSettingOption in setting.options:
		if option == null:
			continue

		var item_index: int = target.item_count
		target.add_item(option.label)
		target.set_item_metadata(item_index, option.value)


func _sync_from_settings() -> void:
	var current_value: int = NucleusSettings.get_int(
		setting.get_id(),
		int(setting.get_default_value()),
	)

	for item_index: int in range(target.item_count):
		if int(target.get_item_metadata(item_index)) == current_value:
			target.select(item_index)
			return


func _on_item_selected(index: int) -> void:
	NucleusSettings.set_value(
		setting.get_id(),
		int(target.get_item_metadata(index)),
	)


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	if setting_id != setting.get_id():
		return

	for item_index: int in range(target.item_count):
		if int(target.get_item_metadata(item_index)) == int(value):
			target.select(item_index)
			return
