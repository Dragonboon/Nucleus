class_name NucleusConfigSettingsRepository
extends RefCounted
## Persists settings using ConfigFile with backup and corruption recovery.
##
## Writes go to a temporary file first. The previous valid primary file is kept
## as a backup before the temporary file replaces it.

const META_SECTION: StringName = &"__nucleus"
const SCHEMA_VERSION_KEY: StringName = &"schema_version"

const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"

var file_path: String
var backup_path: String


func _init(target_file_path: String) -> void:
	file_path = target_file_path
	backup_path = file_path + BACKUP_SUFFIX


## Loads known settings from the primary file or its backup.
func load_settings(
	definitions: Array[NucleusSettingDefinition],
) -> NucleusSettingsLoadResult:
	var primary_result: NucleusSettingsLoadResult

	if FileAccess.file_exists(file_path):
		primary_result = _load_file(
			file_path,
			definitions,
		)

		if primary_result.succeeded():
			return primary_result

		_quarantine_corrupt_primary()

	if FileAccess.file_exists(backup_path):
		var backup_result: NucleusSettingsLoadResult = _load_file(
			backup_path,
			definitions,
		)

		if backup_result.succeeded():
			backup_result.recovered_from_backup = true
			return backup_result

		if primary_result == null:
			return backup_result

	if primary_result != null:
		return primary_result

	var result := NucleusSettingsLoadResult.new()
	result.error = ERR_FILE_NOT_FOUND
	result.source_path = file_path

	return result


## Saves the complete known settings state using a transactional replacement.
func save_settings(
	schema_version: int,
	definitions: Array[NucleusSettingDefinition],
	values: Dictionary[StringName, Variant],
) -> Error:
	var directory_path: String = file_path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		directory_path
	)

	if directory_error not in [OK, ERR_ALREADY_EXISTS]:
		return directory_error

	var config := ConfigFile.new()
	config.set_value(META_SECTION, SCHEMA_VERSION_KEY, schema_version)

	for definition: NucleusSettingDefinition in definitions:
		if definition == null:
			continue

		var setting_id: StringName = definition.get_id()

		if setting_id == &"" or not values.has(setting_id):
			continue

		config.set_value(
			definition.section,
			definition.key,
			values[setting_id],
		)

	var temporary_path: String = file_path + TEMP_SUFFIX
	var save_error: Error = config.save(temporary_path)

	if save_error != OK:
		return save_error

	if FileAccess.file_exists(file_path):
		var backup_error: Error = DirAccess.copy_absolute(
			file_path,
			backup_path,
		)

		if backup_error != OK:
			NucleusLog.warning(
				"Could not refresh settings backup: %s"
				% error_string(backup_error),
				&"Settings",
			)

	var replace_error: Error = DirAccess.rename_absolute(
		temporary_path,
		file_path,
	)

	if replace_error != OK:
		DirAccess.remove_absolute(temporary_path)

	return replace_error


func _load_file(
	path: String,
	definitions: Array[NucleusSettingDefinition],
) -> NucleusSettingsLoadResult:
	var result := NucleusSettingsLoadResult.new()
	result.source_path = path

	var config := ConfigFile.new()
	result.error = config.load(path)

	if result.error != OK:
		return result

	result.schema_version = int(
		config.get_value(
			META_SECTION,
			SCHEMA_VERSION_KEY,
			0,
		)
	)

	for definition: NucleusSettingDefinition in definitions:
		if definition == null:
			continue

		if not config.has_section_key(definition.section, definition.key):
			continue

		result.values[definition.get_id()] = config.get_value(
			definition.section,
			definition.key,
		)

	return result


func _quarantine_corrupt_primary() -> void:
	if not FileAccess.file_exists(file_path):
		return

	var timestamp: String = Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-").replace("T", "_")

	var quarantine_path: String = "%s.corrupt_%s.%s" % [
		file_path.get_basename(),
		timestamp,
		file_path.get_extension(),
	]

	var quarantine_error: Error = DirAccess.rename_absolute(
		file_path,
		quarantine_path,
	)

	if quarantine_error != OK:
		NucleusLog.warning(
			"Could not quarantine invalid settings file: %s"
			% error_string(quarantine_error),
			&"Settings",
		)
