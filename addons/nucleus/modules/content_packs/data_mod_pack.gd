class_name NucleusDataModPack
extends RefCounted
## Validated read-only view over one untrusted data mod.
##
## The API intentionally exposes bytes/text/JSON only. It does not expose a
## ResourceLoader path or mount the package into res://.

var mod_id: StringName
var display_name: String
var version: String
var manifest: Dictionary

var _source_path: String
var _is_zip: bool = false
var _files := PackedStringArray()
var _policy: NucleusDataModPolicy


func _init(
	source_path: String = "",
	is_zip: bool = false,
	files: PackedStringArray = PackedStringArray(),
	mod_manifest: Dictionary = {},
	policy: NucleusDataModPolicy = null,
) -> void:
	_source_path = source_path
	_is_zip = is_zip
	_files = files.duplicate()
	manifest = mod_manifest.duplicate(true)
	_policy = policy if policy else NucleusDataModPolicy.new()
	mod_id = StringName(str(manifest.get("mod_id", "")))
	display_name = str(manifest.get("display_name", ""))
	version = str(manifest.get("version", ""))


func list_files() -> PackedStringArray:
	return _files.duplicate()


func has_file(relative_path: String) -> bool:
	return relative_path in _files


func read_bytes(relative_path: String) -> PackedByteArray:
	if not has_file(relative_path):
		return PackedByteArray()

	if not _policy.is_relative_path_allowed(relative_path):
		return PackedByteArray()

	if _is_zip:
		return _read_zip_file(relative_path)

	var absolute_path: String = _source_path.path_join(relative_path)
	var size: int = FileAccess.get_size(absolute_path)
	if size < 0 or size > _policy.maximum_file_bytes:
		return PackedByteArray()

	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return PackedByteArray()

	var bytes: PackedByteArray = file.get_buffer(size)
	file.close()
	return bytes if bytes.size() == size else PackedByteArray()


func read_text(relative_path: String) -> String:
	return read_bytes(relative_path).get_string_from_utf8()


func read_json(relative_path: String) -> Variant:
	var bytes: PackedByteArray = read_bytes(relative_path)
	if bytes.is_empty():
		return null

	return JSON.parse_string(bytes.get_string_from_utf8())


func _read_zip_file(relative_path: String) -> PackedByteArray:
	var reader := ZIPReader.new()
	if reader.open(_source_path) != OK:
		return PackedByteArray()

	if not reader.file_exists(relative_path):
		reader.close()
		return PackedByteArray()

	if _policy.allow_store_only_zip:
		if reader.get_compression_level(relative_path) != 0:
			reader.close()
			return PackedByteArray()

	var bytes: PackedByteArray = reader.read_file(relative_path)
	reader.close()

	if bytes.size() > _policy.maximum_file_bytes:
		return PackedByteArray()

	return bytes
