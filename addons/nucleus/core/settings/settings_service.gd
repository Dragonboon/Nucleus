class_name NucleusSettingsService
extends Node
## Owns active application settings and coordinates persistence.
##
## Definitions are immutable Resources. Runtime values are stored exclusively
## in this service and persisted through [NucleusConfigSettingsRepository].

signal setting_changed(
	setting_id: StringName,
	value: Variant,
	previous_value: Variant,
)
signal settings_loaded
signal settings_saved(path: String)
signal settings_reset(section: StringName)
signal persistence_failed(error: Error)

const LOG_CONTEXT: StringName = &"Settings"

@export var catalog: NucleusSettingsCatalog
@export var settings_file_path: String = ""
@export_range(0.0, 10.0, 0.05, "or_greater")
var save_debounce_seconds: float = 0.35

var _definitions: Dictionary[StringName, NucleusSettingDefinition] = {}
var _values: Dictionary[StringName, Variant] = {}
var _repository: NucleusConfigSettingsRepository
var _save_timer: Timer
var _initialized: bool = false
var _dirty: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_save_timer = Timer.new()
	_save_timer.name = "SettingsSaveTimer"
	_save_timer.one_shot = true
	_save_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)


func _ready() -> void:
	if not _validate_catalog():
		return

	_definitions = catalog.build_index()

	if settings_file_path.is_empty():
		settings_file_path = NucleusPaths.settings_file()

	_repository = NucleusConfigSettingsRepository.new(settings_file_path)

	NucleusApp.application_paused.connect(_on_application_paused)
	NucleusApp.quit_requested.connect(_on_quit_requested)

	_load_initial_values()


func _exit_tree() -> void:
	if _dirty:
		save_now()


## Returns whether the service completed its initial load.
func is_initialized() -> bool:
	return _initialized


## Returns whether runtime state differs from the last successful save.
func is_dirty() -> bool:
	return _dirty


## Returns whether a setting identifier exists in the active catalog.
func has_setting(setting_id: StringName) -> bool:
	return _definitions.has(setting_id)


## Returns a setting definition or null when the id is unknown.
func get_definition(setting_id: StringName) -> NucleusSettingDefinition:
	return _definitions.get(setting_id)


## Returns the active value or the supplied fallback for an unknown setting.
func get_value(
	setting_id: StringName,
	fallback: Variant = null,
) -> Variant:
	return _values.get(setting_id, fallback)


func get_bool(setting_id: StringName, fallback: bool = false) -> bool:
	var value: Variant = get_value(setting_id, fallback)

	return value if typeof(value) == TYPE_BOOL else fallback


func get_int(setting_id: StringName, fallback: int = 0) -> int:
	var value: Variant = get_value(setting_id, fallback)

	return value if typeof(value) == TYPE_INT else fallback


func get_float(setting_id: StringName, fallback: float = 0.0) -> float:
	var value: Variant = get_value(setting_id, fallback)

	if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
		return float(value)

	return fallback


func get_string(setting_id: StringName, fallback: String = "") -> String:
	var value: Variant = get_value(setting_id, fallback)

	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return str(value)

	return fallback


func get_vector2i(
	setting_id: StringName,
	fallback: Vector2i = Vector2i.ZERO,
) -> Vector2i:
	var value: Variant = get_value(setting_id, fallback)

	return value if typeof(value) == TYPE_VECTOR2I else fallback


## Validates and updates one setting.
func set_value(
	setting_id: StringName,
	value: Variant,
	persist: bool = true,
) -> Error:
	if not _initialized:
		return ERR_UNCONFIGURED

	var definition: NucleusSettingDefinition = _definitions.get(setting_id)

	if definition == null:
		return ERR_DOES_NOT_EXIST

	if not definition.accepts_value(value):
		NucleusLog.warning(
			"Rejected incompatible value for '%s'." % setting_id,
			LOG_CONTEXT,
		)
		return ERR_INVALID_DATA

	var normalized_value: Variant = definition.normalize_value(value)
	var previous_value: Variant = _values[setting_id]

	if normalized_value == previous_value:
		return OK

	_values[setting_id] = _duplicate_runtime_value(normalized_value)
	setting_changed.emit(
		setting_id,
		_values[setting_id],
		previous_value,
	)

	if persist:
		_mark_dirty()

	return OK


## Restores one setting to its catalog default.
func reset_setting(
	setting_id: StringName,
	persist: bool = true,
) -> Error:
	var definition: NucleusSettingDefinition = _definitions.get(setting_id)

	if definition == null:
		return ERR_DOES_NOT_EXIST

	return set_value(
		setting_id,
		definition.get_default_value(),
		persist,
	)


## Restores every setting in a section to its default.
func reset_section(section: StringName) -> void:
	for definition: NucleusSettingDefinition in _definitions.values():
		if definition.section == section:
			reset_setting(definition.get_id(), false)

	_mark_dirty()
	settings_reset.emit(section)


## Restores the complete catalog to defaults.
func reset_all() -> void:
	for definition: NucleusSettingDefinition in _definitions.values():
		reset_setting(definition.get_id(), false)

	_mark_dirty()
	settings_reset.emit(&"")


## Writes dirty settings immediately.
func save_now() -> Error:
	if not _initialized or not _dirty:
		return OK

	var error: Error = _repository.save_settings(
		catalog.schema_version,
		catalog.settings,
		_values,
	)

	if error != OK:
		persistence_failed.emit(error)
		NucleusLog.error(
			"Could not save settings: %s" % error_string(error),
			LOG_CONTEXT,
		)
		return error

	_dirty = false

	if _save_timer:
		_save_timer.stop()

	settings_saved.emit(settings_file_path)

	return OK


func _load_initial_values() -> void:
	_values.clear()

	for definition: NucleusSettingDefinition in _definitions.values():
		_values[definition.get_id()] = _duplicate_runtime_value(
			definition.get_default_value()
		)

	var load_result: NucleusSettingsLoadResult = _repository.load_settings(
		catalog.settings
	)
	var should_rewrite_file: bool = false

	if load_result.succeeded():
		for setting_id: StringName in load_result.values:
			var definition: NucleusSettingDefinition = _definitions.get(
				setting_id
			)
			var persisted_value: Variant = load_result.values[setting_id]

			if definition == null:
				continue

			if not definition.accepts_value(persisted_value):
				should_rewrite_file = true
				NucleusLog.warning(
					"Using default for invalid persisted value '%s'."
					% setting_id,
					LOG_CONTEXT,
				)
				continue

			_values[setting_id] = _duplicate_runtime_value(
				definition.normalize_value(persisted_value)
			)

		if load_result.schema_version != catalog.schema_version:
			should_rewrite_file = true
			NucleusLog.info(
				"Settings schema %d loaded into schema %d."
				% [
					load_result.schema_version,
					catalog.schema_version,
				],
				LOG_CONTEXT,
			)

		if load_result.recovered_from_backup:
			should_rewrite_file = true
			NucleusLog.warning(
				"Recovered settings from the backup file.",
				LOG_CONTEXT,
			)
	else:
		should_rewrite_file = true

		if load_result.error != ERR_FILE_NOT_FOUND:
			NucleusLog.warning(
				"Settings load failed; defaults will be used: %s"
				% error_string(load_result.error),
				LOG_CONTEXT,
			)

	_initialized = true
	settings_loaded.emit()

	if should_rewrite_file:
		_dirty = true
		save_now()


func _validate_catalog() -> bool:
	if catalog == null:
		NucleusLog.error(
			"No settings catalog is assigned.",
			LOG_CONTEXT,
		)
		return false

	var validation_errors: PackedStringArray = catalog.get_validation_errors()

	if validation_errors.is_empty():
		return true

	for validation_error: String in validation_errors:
		NucleusLog.error(validation_error, LOG_CONTEXT)

	return false


func _mark_dirty() -> void:
	_dirty = true

	if save_debounce_seconds <= 0.0:
		save_now()
		return

	_save_timer.start(save_debounce_seconds)


func _duplicate_runtime_value(value: Variant) -> Variant:
	if value is Array:
		return value.duplicate(true)

	if value is Dictionary:
		return value.duplicate(true)

	return value


func _on_application_paused() -> void:
	save_now()


func _on_quit_requested(_exit_code: int) -> void:
	save_now()
