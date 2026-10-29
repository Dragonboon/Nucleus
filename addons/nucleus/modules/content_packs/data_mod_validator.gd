class_name NucleusDataModValidator
extends RefCounted
## Validates untrusted community data without mounting it as a Godot pack.

const MANIFEST_FILE: String = "manifest.json"
const MANIFEST_SCHEMA_VERSION: int = 1


static func validate_directory(
	directory_path: String,
	policy: NucleusDataModPolicy = null,
) -> Dictionary:
	var resolved_policy := policy if policy else NucleusDataModPolicy.new()
	var files := PackedStringArray()
	var total_bytes: int = 0

	var walk_result: Dictionary = _walk_directory(
		directory_path,
		"",
		resolved_policy,
		files,
		total_bytes,
	)
	if walk_result.error != OK:
		return walk_result

	total_bytes = int(walk_result.total_bytes)
	return _finalize_pack(
		directory_path,
		false,
		files,
		total_bytes,
		resolved_policy,
	)


static func validate_zip(
	zip_path: String,
	policy: NucleusDataModPolicy = null,
) -> Dictionary:
	var resolved_policy := policy if policy else NucleusDataModPolicy.new()

	if not resolved_policy.allow_store_only_zip:
		return _failure(
			ERR_UNAVAILABLE,
			"ZIP data mods are disabled by policy.",
		)

	var archive_size: int = FileAccess.get_size(zip_path)
	var archive_limit: int = resolved_policy.maximum_total_bytes + 1024 * 1024
	if archive_size < 0:
		return _failure(ERR_CANT_OPEN, "Could not inspect data-mod ZIP.")
	if archive_size > archive_limit:
		return _failure(
			ERR_INVALID_DATA,
			"Data-mod ZIP exceeds the pre-read archive-size limit.",
		)

	var reader := ZIPReader.new()
	var open_error: Error = reader.open(zip_path)
	if open_error != OK:
		return _failure(open_error, "Could not open data-mod ZIP.")

	var files := PackedStringArray()
	var total_bytes: int = 0

	for relative_path: String in reader.get_files():
		if relative_path.ends_with("/"):
			continue

		if not resolved_policy.is_relative_path_allowed(relative_path):
			reader.close()
			return _failure(
				ERR_UNAUTHORIZED,
				"Blocked path in data mod: %s" % relative_path,
			)

		if reader.get_compression_level(relative_path) != 0:
			reader.close()
			return _failure(
				ERR_UNAUTHORIZED,
				"Community ZIP entries must be stored without compression.",
			)

		files.append(relative_path)
		if files.size() > resolved_policy.maximum_files:
			reader.close()
			return _failure(ERR_INVALID_DATA, "Too many files in data mod.")

		var bytes: PackedByteArray = reader.read_file(relative_path)
		if bytes.size() > resolved_policy.maximum_file_bytes:
			reader.close()
			return _failure(
				ERR_INVALID_DATA,
				"Data-mod file exceeds per-file limit.",
			)

		total_bytes += bytes.size()
		if total_bytes > resolved_policy.maximum_total_bytes:
			reader.close()
			return _failure(
				ERR_INVALID_DATA,
				"Data mod exceeds total-size limit.",
			)

	reader.close()

	return _finalize_pack(
		zip_path,
		true,
		files,
		total_bytes,
		resolved_policy,
	)


static func _walk_directory(
	root_path: String,
	relative_directory: String,
	policy: NucleusDataModPolicy,
	files: PackedStringArray,
	total_bytes: int,
) -> Dictionary:
	var absolute_directory: String = (
		root_path
		if relative_directory.is_empty()
		else root_path.path_join(relative_directory)
	)
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return _failure(
			DirAccess.get_open_error(),
			"Could not open data-mod directory.",
		)

	directory.include_hidden = true
	var entries: PackedStringArray = directory.get_files()
	var subdirectories: PackedStringArray = directory.get_directories()

	for name: String in entries:
		if directory.is_link(name):
			return _failure(
				ERR_UNAUTHORIZED,
				"Symbolic links are not allowed in community mods.",
			)

		var relative_path: String = (
			name
			if relative_directory.is_empty()
			else relative_directory.path_join(name)
		).replace("\\", "/")

		if not policy.is_relative_path_allowed(relative_path):
			return _failure(
				ERR_UNAUTHORIZED,
				"Blocked path in data mod: %s" % relative_path,
			)

		var absolute_path: String = root_path.path_join(relative_path)
		var size: int = FileAccess.get_size(absolute_path)
		if size < 0:
			return _failure(ERR_CANT_OPEN, "Could not inspect data-mod file.")

		if size > policy.maximum_file_bytes:
			return _failure(
				ERR_INVALID_DATA,
				"Data-mod file exceeds per-file limit.",
			)

		total_bytes += size
		if total_bytes > policy.maximum_total_bytes:
			return _failure(
				ERR_INVALID_DATA,
				"Data mod exceeds total-size limit.",
			)

		files.append(relative_path)
		if files.size() > policy.maximum_files:
			return _failure(ERR_INVALID_DATA, "Too many files in data mod.")

	for name: String in subdirectories:
		if directory.is_link(name):
			return _failure(
				ERR_UNAUTHORIZED,
				"Symbolic links are not allowed in community mods.",
			)

		var child_relative: String = (
			name
			if relative_directory.is_empty()
			else relative_directory.path_join(name)
		)
		var child_result: Dictionary = _walk_directory(
			root_path,
			child_relative,
			policy,
			files,
			total_bytes,
		)
		if child_result.error != OK:
			return child_result

		total_bytes = int(child_result.total_bytes)

	return {
		"error": OK,
		"message": "",
		"total_bytes": total_bytes,
	}


static func _finalize_pack(
	source_path: String,
	is_zip: bool,
	files: PackedStringArray,
	total_bytes: int,
	policy: NucleusDataModPolicy,
) -> Dictionary:
	if MANIFEST_FILE not in files:
		return _failure(ERR_FILE_NOT_FOUND, "Data mod requires manifest.json.")

	files.sort()
	var manifest_bytes: PackedByteArray

	if is_zip:
		var reader := ZIPReader.new()
		if reader.open(source_path) != OK:
			return _failure(ERR_CANT_OPEN, "Could not reopen data-mod ZIP.")
		manifest_bytes = reader.read_file(MANIFEST_FILE)
		reader.close()
	else:
		var manifest_path: String = source_path.path_join(MANIFEST_FILE)
		var manifest_size: int = FileAccess.get_size(manifest_path)
		var file := FileAccess.open(manifest_path, FileAccess.READ)
		if file == null:
			return _failure(ERR_CANT_OPEN, "Could not read data-mod manifest.")
		manifest_bytes = file.get_buffer(manifest_size)
		file.close()

	var parsed: Variant = JSON.parse_string(
		manifest_bytes.get_string_from_utf8()
	)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure(ERR_PARSE_ERROR, "Data-mod manifest must be JSON.")

	var manifest: Dictionary = parsed
	var manifest_error: String = _validate_manifest(manifest)
	if not manifest_error.is_empty():
		return _failure(ERR_INVALID_DATA, manifest_error)

	var pack := NucleusDataModPack.new(
		source_path,
		is_zip,
		files,
		manifest,
		policy,
	)

	return {
		"error": OK,
		"message": "",
		"pack": pack,
		"total_bytes": total_bytes,
	}


static func _validate_manifest(manifest: Dictionary) -> String:
	if int(manifest.get("schema_version", -1)) != MANIFEST_SCHEMA_VERSION:
		return "Unsupported data-mod manifest schema."

	var mod_id: String = str(manifest.get("mod_id", ""))
	if not NucleusContentPackManifest.is_valid_identifier(mod_id):
		return "mod_id must use lowercase [a-z0-9._-]."

	if str(manifest.get("display_name", "")).strip_edges().is_empty():
		return "display_name must not be empty."

	if NucleusSemanticVersion.parse(str(manifest.get("version", ""))) == null:
		return "version must be valid Semantic Versioning."

	return ""


static func _failure(error: Error, message: String) -> Dictionary:
	return {
		"error": error,
		"message": message,
	}
