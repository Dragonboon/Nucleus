class_name NucleusSettingsCatalog
extends Resource
## Versioned collection of setting definitions available to the application.

@export_range(1, 2147483647, 1, "or_greater")
var schema_version: int = 1

@export var settings: Array[NucleusSettingDefinition] = []


## Creates an identifier-to-definition lookup table.
func build_index() -> Dictionary[StringName, NucleusSettingDefinition]:
	var index: Dictionary[StringName, NucleusSettingDefinition] = {}

	for setting: NucleusSettingDefinition in settings:
		if setting == null:
			continue

		var setting_id: StringName = setting.get_id()

		if setting_id == &"" or index.has(setting_id):
			continue

		index[setting_id] = setting

	return index


## Returns configuration errors for the complete catalog.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary[StringName, bool] = {}

	if schema_version < 1:
		errors.append("schema_version must be at least 1")

	for index: int in range(settings.size()):
		var setting: NucleusSettingDefinition = settings[index]

		if setting == null:
			errors.append("settings[%d] cannot be null" % index)
			continue

		var setting_id: StringName = setting.get_id()

		for definition_error: String in setting.get_validation_errors():
			errors.append(
				"settings[%d] (%s): %s"
				% [index, setting_id, definition_error]
			)

		if setting_id == &"":
			continue

		if seen_ids.has(setting_id):
			errors.append("duplicate setting id: %s" % setting_id)
		else:
			seen_ids[setting_id] = true

	return errors
