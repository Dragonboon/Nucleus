class_name NucleusSaveRepository
extends RefCounted
## Filesystem repository with transactional replacement and backup recovery.

const LOG_CONTEXT: StringName = &"Save"

var profile: NucleusSaveProfile
var security: NucleusSaveSecurity


func _init(
	save_profile: NucleusSaveProfile,
	save_security: NucleusSaveSecurity,
) -> void:
	profile = save_profile
	security = save_security


func save_manual(
	slot_id: String,
	document: NucleusSaveDocument,
	format: int = -1,
) -> NucleusSaveResult:
	return _save_named(
		slot_id,
		document,
		NucleusSaveTypes.Kind.MANUAL,
		format,
	)


func save_quick(
	slot_id: String,
	document: NucleusSaveDocument,
	format: int = -1,
) -> NucleusSaveResult:
	return _save_named(
		slot_id,
		document,
		NucleusSaveTypes.Kind.QUICKSAVE,
		format,
	)


func save_autosave(
	slot_id: String,
	document: NucleusSaveDocument,
	max_slots: int,
	format: int = -1,
) -> NucleusSaveResult:
	var result := NucleusSaveResult.new()
	var codec: NucleusSaveCodec = _resolve_codec(format)

	if codec == null:
		result.error = ERR_INVALID_PARAMETER
		return result

	var timestamp_ms: int = int(
		Time.get_unix_time_from_system() * 1000.0
	)
	var path: String = NucleusSavePaths.autosave_path(
		profile,
		slot_id,
		codec,
		profile.encryption_mode,
		timestamp_ms,
	)

	while FileAccess.file_exists(path):
		timestamp_ms += 1
		path = NucleusSavePaths.autosave_path(
			profile,
			slot_id,
			codec,
			profile.encryption_mode,
			timestamp_ms,
		)

	result = _write_document(
		path,
		document,
		codec,
		profile.encryption_mode,
		0,
	)

	if result.succeeded():
		_prune_autosaves(slot_id, maxi(1, max_slots))

	return result


func load_manual(slot_id: String) -> NucleusSaveResult:
	return _load_latest_named(slot_id, "manual.")


func load_quick(slot_id: String) -> NucleusSaveResult:
	return _load_latest_named(slot_id, "quick.")


func load_latest_autosave(slot_id: String) -> NucleusSaveResult:
	var candidates: PackedStringArray = list_autosave_paths(slot_id)

	if candidates.is_empty():
		var result := NucleusSaveResult.new()
		result.error = ERR_FILE_NOT_FOUND
		return result

	return _load_with_backups(candidates[0])


func list_slots() -> PackedStringArray:
	var slots := PackedStringArray()

	if not DirAccess.dir_exists_absolute(profile.base_directory):
		return slots

	var directory := DirAccess.open(profile.base_directory)

	if directory == null:
		return slots

	for directory_name: String in directory.get_directories():
		if not directory_name.is_empty():
			slots.append(directory_name)

	slots.sort()

	return slots


func list_autosave_paths(slot_id: String) -> PackedStringArray:
	var directory_path: String = NucleusSavePaths.autosave_directory(
		profile.base_directory,
		slot_id,
	)
	var paths: Array[String] = []

	if not DirAccess.dir_exists_absolute(directory_path):
		return PackedStringArray()

	var directory := DirAccess.open(directory_path)

	if directory == null:
		return PackedStringArray()

	for file_name: String in directory.get_files():
		if not file_name.begins_with("auto_"):
			continue

		if _is_auxiliary_file(file_name):
			continue

		var path: String = directory_path.path_join(file_name)

		if _codec_for_path(path):
			paths.append(path)

	paths.sort_custom(
		func(left: String, right: String) -> bool:
			return (
				FileAccess.get_modified_time(left)
				> FileAccess.get_modified_time(right)
			)
	)

	return PackedStringArray(paths)


func delete_slot(slot_id: String) -> Error:
	var directory_path: String = NucleusSavePaths.slot_directory(
		profile.base_directory,
		slot_id,
	)

	if not DirAccess.dir_exists_absolute(directory_path):
		return ERR_DOES_NOT_EXIST

	return NucleusFileUtils.remove_directory_recursive(directory_path)


func _save_named(
	slot_id: String,
	document: NucleusSaveDocument,
	kind: int,
	format: int,
) -> NucleusSaveResult:
	var result := NucleusSaveResult.new()
	var codec: NucleusSaveCodec = _resolve_codec(format)

	if codec == null:
		result.error = ERR_INVALID_PARAMETER
		return result

	var path: String

	match kind:
		NucleusSaveTypes.Kind.MANUAL:
			path = NucleusSavePaths.manual_path(
				profile,
				slot_id,
				codec,
				profile.encryption_mode,
			)

		NucleusSaveTypes.Kind.QUICKSAVE:
			path = NucleusSavePaths.quicksave_path(
				profile,
				slot_id,
				codec,
				profile.encryption_mode,
			)

		_:
			result.error = ERR_INVALID_PARAMETER
			return result

	return _write_document(
		path,
		document,
		codec,
		profile.encryption_mode,
		profile.backup_count,
	)


func _write_document(
	path: String,
	document: NucleusSaveDocument,
	codec: NucleusSaveCodec,
	encryption_mode: int,
	backup_count: int,
) -> NucleusSaveResult:
	var result := NucleusSaveResult.new()
	result.path = path
	result.document = document

	if not security.has_credentials(encryption_mode):
		result.error = ERR_UNCONFIGURED
		return result

	NucleusSaveIntegrity.sign_document(
		document,
		security.get_authentication_key(encryption_mode),
	)

	var encoded: PackedByteArray = codec.encode(
		document.to_dictionary()
	)

	if encoded.is_empty():
		result.error = ERR_INVALID_DATA
		return result

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		path.get_base_dir()
	)

	if directory_error not in [OK, ERR_ALREADY_EXISTS]:
		result.error = directory_error
		return result

	var temporary_path: String = path + ".tmp"
	var file: FileAccess = security.open_file(
		temporary_path,
		FileAccess.WRITE,
		encryption_mode,
	)

	if file == null:
		result.error = security.last_error
		return result

	var wrote_buffer: bool = file.store_buffer(encoded)
	file.flush()
	file.close()

	if not wrote_buffer:
		DirAccess.remove_absolute(temporary_path)
		result.error = ERR_FILE_CANT_WRITE
		return result

	var rotate_error: Error = _rotate_backups(
		path,
		backup_count,
	)

	if rotate_error != OK:
		DirAccess.remove_absolute(temporary_path)
		result.error = rotate_error
		return result

	var replace_error: Error = DirAccess.rename_absolute(
		temporary_path,
		path,
	)

	if replace_error != OK:
		_restore_primary_backup(path)
		DirAccess.remove_absolute(temporary_path)
		result.error = replace_error
		return result

	result.error = OK

	return result


func _load_latest_named(
	slot_id: String,
	prefix: String,
) -> NucleusSaveResult:
	var directory_path: String = NucleusSavePaths.slot_directory(
		profile.base_directory,
		slot_id,
	)
	var candidates: Array[String] = []

	if not DirAccess.dir_exists_absolute(directory_path):
		var missing_result := NucleusSaveResult.new()
		missing_result.error = ERR_FILE_NOT_FOUND
		return missing_result

	var directory := DirAccess.open(directory_path)

	if directory == null:
		var open_result := NucleusSaveResult.new()
		open_result.error = DirAccess.get_open_error()
		return open_result

	for file_name: String in directory.get_files():
		if not file_name.begins_with(prefix):
			continue

		if _is_auxiliary_file(file_name):
			continue

		var path: String = directory_path.path_join(file_name)

		if _codec_for_path(path):
			candidates.append(path)

	if candidates.is_empty():
		var missing_result := NucleusSaveResult.new()
		missing_result.error = ERR_FILE_NOT_FOUND
		return missing_result

	candidates.sort_custom(
		func(left: String, right: String) -> bool:
			return (
				FileAccess.get_modified_time(left)
				> FileAccess.get_modified_time(right)
			)
	)

	return _load_with_backups(candidates.front())


func _load_with_backups(path: String) -> NucleusSaveResult:
	var primary_result: NucleusSaveResult = _load_path(path)

	if primary_result.succeeded():
		return primary_result

	for backup_index: int in range(1, profile.backup_count + 1):
		var backup_path: String = "%s.bak%d" % [
			path,
			backup_index,
		]

		if not FileAccess.file_exists(backup_path):
			continue

		var backup_result: NucleusSaveResult = _load_path(
			backup_path,
			path,
		)

		if backup_result.succeeded():
			backup_result.recovered_from_backup = true
			return backup_result

	return primary_result


func _load_path(
	path: String,
	format_source_path: String = "",
) -> NucleusSaveResult:
	var result := NucleusSaveResult.new()
	result.path = path

	if not FileAccess.file_exists(path):
		result.error = ERR_FILE_NOT_FOUND
		return result

	if FileAccess.get_size(path) > profile.max_file_size_mb * 1024 * 1024:
		result.error = ERR_FILE_CORRUPT
		return result

	var source_path: String = (
		format_source_path
		if not format_source_path.is_empty()
		else path
	)
	var codec: NucleusSaveCodec = _codec_for_path(source_path)

	if codec == null:
		result.error = ERR_FILE_UNRECOGNIZED
		return result

	var encryption_mode: int = NucleusSavePaths.encryption_from_path(
		source_path
	)

	if not security.has_credentials(encryption_mode):
		result.error = ERR_UNCONFIGURED
		return result

	var file: FileAccess = security.open_file(
		path,
		FileAccess.READ,
		encryption_mode,
	)

	if file == null:
		result.error = security.last_error
		return result

	var encoded: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	var decoded: Dictionary = codec.decode(encoded)

	if decoded.is_empty():
		result.error = ERR_FILE_CORRUPT
		return result

	var document: NucleusSaveDocument = (
		NucleusSaveDocument.from_dictionary(decoded)
	)

	if document == null:
		result.error = ERR_FILE_CORRUPT
		return result

	var integrity_error: Error = NucleusSaveIntegrity.verify_document(
		document,
		security.get_authentication_key(encryption_mode),
	)

	if integrity_error != OK:
		result.error = integrity_error
		return result

	result.document = document
	result.error = OK

	return result


func _resolve_codec(format: int) -> NucleusSaveCodec:
	var resolved_format: int = (
		profile.default_format
		if format < 0
		else format
	)

	return NucleusSaveCodecRegistry.create_for_format(resolved_format)


func _codec_for_path(path: String) -> NucleusSaveCodec:
	var source_path: String = path

	if source_path.get_file().contains(".bak"):
		source_path = source_path.get_basename()

	var extension: String = NucleusSavePaths.codec_extension_from_path(
		source_path
	)

	return NucleusSaveCodecRegistry.create_for_extension(extension)


func _rotate_backups(path: String, backup_count: int) -> Error:
	if backup_count <= 0 or not FileAccess.file_exists(path):
		return OK

	for index: int in range(backup_count, 0, -1):
		var destination: String = "%s.bak%d" % [path, index]

		if FileAccess.file_exists(destination):
			var remove_error: Error = DirAccess.remove_absolute(destination)

			if remove_error != OK:
				return remove_error

		var source: String = (
			path
			if index == 1
			else "%s.bak%d" % [path, index - 1]
		)

		if not FileAccess.file_exists(source):
			continue

		var rename_error: Error = DirAccess.rename_absolute(
			source,
			destination,
		)

		if rename_error != OK:
			return rename_error

	return OK


func _restore_primary_backup(path: String) -> void:
	var first_backup: String = "%s.bak1" % path

	if (
		not FileAccess.file_exists(path)
		and FileAccess.file_exists(first_backup)
	):
		DirAccess.rename_absolute(first_backup, path)


func _prune_autosaves(slot_id: String, max_slots: int) -> void:
	var paths: PackedStringArray = list_autosave_paths(slot_id)

	while paths.size() > max_slots:
		var oldest_path: String = paths[paths.size() - 1]
		DirAccess.remove_absolute(oldest_path)
		paths.resize(paths.size() - 1)


func _is_auxiliary_file(file_name: String) -> bool:
	return (
		file_name.ends_with(".tmp")
		or file_name.contains(".bak")
	)

