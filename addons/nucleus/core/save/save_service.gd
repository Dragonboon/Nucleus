class_name NucleusSaveService
extends Node
## Application-wide storage facade for versioned save documents.
##
## Game state capture and restore are intentionally owned by scene-level
## [NucleusSaveSession] instances.

signal save_completed(result: NucleusSaveResult)
signal save_failed(result: NucleusSaveResult)
signal load_completed(result: NucleusSaveResult)
signal load_failed(result: NucleusSaveResult)
signal slot_deleted(slot_id: String)

const LOG_CONTEXT: StringName = &"Save"

@export var profile: NucleusSaveProfile

var _security := NucleusSaveSecurity.new()
var _repository: NucleusSaveRepository
var _initialized: bool = false


func _ready() -> void:
	if profile:
		profile = profile.duplicate(true)
		profile.base_directory = profile.get_base_directory()

	if not _validate_profile():
		return

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		profile.base_directory
	)

	if directory_error not in [OK, ERR_ALREADY_EXISTS]:
		NucleusLog.error(
			"Could not create save directory: %s"
			% error_string(directory_error),
			LOG_CONTEXT,
		)
		return

	_repository = NucleusSaveRepository.new(profile, _security)
	_initialized = true


func is_initialized() -> bool:
	return _initialized


func configure_password(password: String) -> Error:
	return _security.configure_password(password)


func configure_raw_key(key: PackedByteArray) -> Error:
	return _security.configure_raw_key(key)


func clear_credentials() -> void:
	_security.clear_credentials()


func save_manual(
	slot_id: String,
	payload: Dictionary,
	metadata: Dictionary = {},
	format: int = -1,
) -> NucleusSaveResult:
	return _save(
		slot_id,
		NucleusSaveTypes.Kind.MANUAL,
		payload,
		metadata,
		format,
		0,
	)


func save_quick(
	slot_id: String,
	payload: Dictionary,
	metadata: Dictionary = {},
	format: int = -1,
) -> NucleusSaveResult:
	return _save(
		slot_id,
		NucleusSaveTypes.Kind.QUICKSAVE,
		payload,
		metadata,
		format,
		0,
	)


func save_autosave(
	slot_id: String,
	payload: Dictionary,
	metadata: Dictionary = {},
	max_slots: int = 3,
	format: int = -1,
) -> NucleusSaveResult:
	return _save(
		slot_id,
		NucleusSaveTypes.Kind.AUTOSAVE,
		payload,
		metadata,
		format,
		max_slots,
	)


func load_manual(slot_id: String) -> NucleusSaveResult:
	if not _initialized:
		return _unconfigured_result()

	var result: NucleusSaveResult = _repository.load_manual(slot_id)

	return _finish_load(result, true)


func load_quick(slot_id: String) -> NucleusSaveResult:
	if not _initialized:
		return _unconfigured_result()

	var result: NucleusSaveResult = _repository.load_quick(slot_id)

	return _finish_load(result, true)


func load_latest_autosave(slot_id: String) -> NucleusSaveResult:
	if not _initialized:
		return _unconfigured_result()

	var result: NucleusSaveResult = _repository.load_latest_autosave(
		slot_id
	)

	return _finish_load(result, false)


## Loads the newest successful candidate across the requested save kinds.
##
## Empty [param kinds] uses autosave, quicksave, then manual as the
## exact-timestamp tie-break order. Timestamp always wins before kind order.
func load_latest(
	slot_id: String,
	kinds: PackedInt32Array = PackedInt32Array(),
) -> NucleusSaveResult:
	if not _initialized:
		return _unconfigured_result()

	var order := NucleusSaveResumePolicy.normalize_kind_order(kinds)

	if order.is_empty():
		var invalid_result := NucleusSaveResult.new()
		invalid_result.error = ERR_INVALID_PARAMETER
		return _finish_load(invalid_result, false)

	var candidates: Array[NucleusSaveResult] = []
	var fallback_error: NucleusSaveResult = null

	for kind: int in order:
		var candidate := _load_raw_kind(slot_id, kind)
		candidates.append(candidate)

		if (
			not candidate.succeeded()
			and candidate.error != ERR_FILE_NOT_FOUND
			and fallback_error == null
		):
			fallback_error = candidate

	var selected := NucleusSaveResumePolicy.choose_latest(
		candidates,
		order,
	)

	if selected == null:
		if fallback_error == null:
			fallback_error = NucleusSaveResult.new()
			fallback_error.error = ERR_FILE_NOT_FOUND

		return _finish_load(fallback_error, false)

	var rewrite_if_migrated := (
		selected.document.kind != NucleusSaveTypes.Kind.AUTOSAVE
	)
	return _finish_load(selected, rewrite_if_migrated)


func list_slots() -> PackedStringArray:
	if not _initialized:
		return PackedStringArray()

	return _repository.list_slots()


func list_autosave_paths(slot_id: String) -> PackedStringArray:
	if not _initialized:
		return PackedStringArray()

	return _repository.list_autosave_paths(slot_id)


func delete_slot(slot_id: String) -> Error:
	if not _initialized:
		return ERR_UNCONFIGURED

	var normalized_slot: String = NucleusSavePaths.sanitize_slot_id(
		slot_id
	)

	if normalized_slot.is_empty():
		return ERR_INVALID_PARAMETER

	var error: Error = _repository.delete_slot(normalized_slot)

	if error == OK:
		slot_deleted.emit(normalized_slot)

	return error


func _save(
	slot_id: String,
	kind: int,
	payload: Dictionary,
	metadata: Dictionary,
	format: int,
	autosave_limit: int,
) -> NucleusSaveResult:
	if not _initialized:
		return _emit_save_result(_unconfigured_result())

	var normalized_slot: String = NucleusSavePaths.sanitize_slot_id(
		slot_id
	)

	if normalized_slot.is_empty():
		var invalid_result := NucleusSaveResult.new()
		invalid_result.error = ERR_INVALID_PARAMETER
		return _emit_save_result(invalid_result)

	var payload_error: Error = NucleusSaveDataValidator.validate(payload)

	if payload_error != OK:
		var invalid_payload_result := NucleusSaveResult.new()
		invalid_payload_result.error = payload_error
		return _emit_save_result(invalid_payload_result)

	var metadata_error: Error = NucleusSaveDataValidator.validate(metadata)

	if metadata_error != OK:
		var invalid_metadata_result := NucleusSaveResult.new()
		invalid_metadata_result.error = metadata_error
		return _emit_save_result(invalid_metadata_result)

	var created_at_usec: int = _resolve_creation_timestamp_usec(
		normalized_slot,
		kind,
	)
	var document := _create_document(
		normalized_slot,
		kind,
		payload,
		metadata,
		created_at_usec,
	)

	var result: NucleusSaveResult

	match kind:
		NucleusSaveTypes.Kind.MANUAL:
			result = _repository.save_manual(
				normalized_slot,
				document,
				format,
			)

		NucleusSaveTypes.Kind.QUICKSAVE:
			result = _repository.save_quick(
				normalized_slot,
				document,
				format,
			)

		NucleusSaveTypes.Kind.AUTOSAVE:
			result = _repository.save_autosave(
				normalized_slot,
				document,
				maxi(1, autosave_limit),
				format,
			)

		_:
			result = NucleusSaveResult.new()
			result.error = ERR_INVALID_PARAMETER

	return _emit_save_result(result)


func _finish_load(
	result: NucleusSaveResult,
	rewrite_if_migrated: bool,
) -> NucleusSaveResult:
	if not result.succeeded():
		load_failed.emit(result)
		return result

	if result.document.schema_version != profile.schema_version:
		var migration_error: Error = NucleusSaveMigrationPipeline.migrate(
			result.document,
			profile.schema_version,
			profile.migrations,
		)

		if migration_error != OK:
			result.error = migration_error
			load_failed.emit(result)
			return result

		result.migrated = true

		if rewrite_if_migrated and profile.rewrite_migrated_saves:
			_rewrite_migrated_document(result.document)

	load_completed.emit(result)

	return result


func _rewrite_migrated_document(
	document: NucleusSaveDocument,
) -> void:
	match document.kind:
		NucleusSaveTypes.Kind.MANUAL:
			_repository.save_manual(
				document.slot_id,
				document,
			)

		NucleusSaveTypes.Kind.QUICKSAVE:
			_repository.save_quick(
				document.slot_id,
				document,
			)


func _create_document(
	slot_id: String,
	kind: int,
	payload: Dictionary,
	metadata: Dictionary,
	created_at_usec: int = 0,
) -> NucleusSaveDocument:
	var now_usec := int(Time.get_unix_time_from_system() * 1000000.0)
	var now := int(float(now_usec) / 1000000.0)
	var document := NucleusSaveDocument.new()

	document.slot_id = slot_id
	document.kind = kind
	document.schema_version = profile.schema_version
	document.created_at_unix_usec = (
		created_at_usec
		if created_at_usec > 0
		else now_usec
	)
	document.created_at_unix = int(
		float(document.created_at_unix_usec) / 1000000.0
	)
	document.updated_at_unix = now
	document.updated_at_unix_usec = now_usec
	document.game_version = str(
		ProjectSettings.get_setting(
			"application/config/version",
			"",
		)
	)
	document.engine_version = str(
		Engine.get_version_info().get("string", "")
	)
	document.metadata = metadata.duplicate(true)
	document.payload = payload.duplicate(true)

	return document


func _resolve_creation_timestamp_usec(
	slot_id: String,
	kind: int,
) -> int:
	var existing_result: NucleusSaveResult

	match kind:
		NucleusSaveTypes.Kind.MANUAL:
			existing_result = _repository.load_manual(slot_id)

		NucleusSaveTypes.Kind.QUICKSAVE:
			existing_result = _repository.load_quick(slot_id)

		_:
			return 0

	if (
		existing_result
		and existing_result.succeeded()
		and existing_result.document
	):
		return existing_result.document.get_created_at_usec()

	return 0


func _load_raw_kind(
	slot_id: String,
	kind: int,
) -> NucleusSaveResult:
	match kind:
		NucleusSaveTypes.Kind.MANUAL:
			return _repository.load_manual(slot_id)

		NucleusSaveTypes.Kind.QUICKSAVE:
			return _repository.load_quick(slot_id)

		NucleusSaveTypes.Kind.AUTOSAVE:
			return _repository.load_latest_autosave(slot_id)

	var invalid_result := NucleusSaveResult.new()
	invalid_result.error = ERR_INVALID_PARAMETER
	return invalid_result


func _emit_save_result(
	result: NucleusSaveResult,
) -> NucleusSaveResult:
	if result.succeeded():
		save_completed.emit(result)
	else:
		save_failed.emit(result)

	return result


func _unconfigured_result() -> NucleusSaveResult:
	var result := NucleusSaveResult.new()
	result.error = ERR_UNCONFIGURED

	return result


func _validate_profile() -> bool:
	if profile == null:
		NucleusLog.error("No save profile is assigned.", LOG_CONTEXT)
		return false

	var errors: PackedStringArray = profile.get_validation_errors()

	if errors.is_empty():
		return true

	for validation_error: String in errors:
		NucleusLog.error(validation_error, LOG_CONTEXT)

	return false
