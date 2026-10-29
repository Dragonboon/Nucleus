class_name NucleusFileUtils
extends RefCounted
## Host/user filesystem helpers.
##
## Do not use recursive filesystem enumeration to discover packaged res://
## resources in exported games. Use ResourceLoader for project resources.

static func ensure_directory(path: String) -> Error:
	if not _is_valid_absolute_path(path):
		return ERR_INVALID_PARAMETER

	if DirAccess.dir_exists_absolute(path):
		return OK

	return DirAccess.make_dir_recursive_absolute(path)


## Returns recursively discovered files in deterministic alphabetical order.
##
## [param extensions] may contain values such as "json" or ".json".
static func list_files_recursive(
	path: String,
	extensions: PackedStringArray = PackedStringArray(),
) -> Array[String]:
	var result: Array[String] = []

	if (
		not _is_valid_absolute_path(path)
		or not DirAccess.dir_exists_absolute(path)
	):
		return result

	var normalized_extensions: PackedStringArray = (
		_normalize_extensions(extensions)
	)

	_collect_files_recursive(
		path,
		normalized_extensions,
		result,
	)
	result.sort()

	return result


## Recursively copies a directory tree.
static func copy_directory_recursive(
	source_path: String,
	destination_path: String,
) -> Error:
	if (
		not _is_valid_absolute_path(source_path)
		or not _is_valid_absolute_path(destination_path)
	):
		return ERR_INVALID_PARAMETER

	if not DirAccess.dir_exists_absolute(source_path):
		return ERR_DOES_NOT_EXIST

	var create_error: Error = ensure_directory(destination_path)

	if create_error != OK:
		return create_error

	for file_name: String in DirAccess.get_files_at(source_path):
		var copy_error: Error = DirAccess.copy_absolute(
			source_path.path_join(file_name),
			destination_path.path_join(file_name),
		)

		if copy_error != OK:
			return copy_error

	for directory_name: String in DirAccess.get_directories_at(
		source_path
	):
		var copy_error: Error = copy_directory_recursive(
			source_path.path_join(directory_name),
			destination_path.path_join(directory_name),
		)

		if copy_error != OK:
			return copy_error

	return OK


## Permanently removes a directory and all descendants.
static func remove_directory_recursive(path: String) -> Error:
	if not _is_valid_absolute_path(path):
		return ERR_INVALID_PARAMETER

	if not DirAccess.dir_exists_absolute(path):
		return ERR_DOES_NOT_EXIST

	for file_name: String in DirAccess.get_files_at(path):
		var remove_error: Error = DirAccess.remove_absolute(
			path.path_join(file_name)
		)

		if remove_error != OK:
			return remove_error

	for directory_name: String in DirAccess.get_directories_at(path):
		var remove_error: Error = remove_directory_recursive(
			path.path_join(directory_name)
		)

		if remove_error != OK:
			return remove_error

	return DirAccess.remove_absolute(path)


static func _collect_files_recursive(
	path: String,
	extensions: PackedStringArray,
	result: Array[String],
) -> void:
	for file_name: String in DirAccess.get_files_at(path):
		var file_path: String = path.path_join(file_name)

		if (
			extensions.is_empty()
			or file_path.get_extension().to_lower() in extensions
		):
			result.append(file_path)

	for directory_name: String in DirAccess.get_directories_at(path):
		_collect_files_recursive(
			path.path_join(directory_name),
			extensions,
			result,
		)


static func _normalize_extensions(
	extensions: PackedStringArray,
) -> PackedStringArray:
	var result := PackedStringArray()

	for extension: String in extensions:
		var normalized: String = (
			extension
			.strip_edges()
			.trim_prefix(".")
			.to_lower()
		)

		if (
			not normalized.is_empty()
			and normalized not in result
		):
			result.append(normalized)

	return result


static func _is_valid_absolute_path(path: String) -> bool:
	return (
		not path.is_empty()
		and path.is_absolute_path()
	)
