@tool
extends RefCounted
## Validates GitHub source ZIPs without executing or importing their contents.

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")
const Manager = preload("res://addons/nucleus/editor/management/addon_manager.gd")


static func prepare(archive: String, manifest_bytes: PackedByteArray, commit: String) -> Dictionary:
	if not valid_commit(commit):
		return {"error": "Invalid pinned commit."}
	var parsed: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"error": "Invalid remote manifest."}
	var manifest: Dictionary = parsed
	var error: String = Inventory.validate(manifest)
	if not error.is_empty():
		return {"error": error}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(archive)
	var entries: Dictionary = central_directory(bytes)
	if entries.has("error"):
		return entries
	var zip := ZIPReader.new()
	if zip.open(archive) != OK:
		return {"error": "Cannot open downloaded ZIP."}
	var prefix: String = ""
	for path: String in entries:
		if path.ends_with("/addons/nucleus/" + Inventory.MANIFEST):
			if not prefix.is_empty():
				zip.close()
				return {"error": "Archive contains multiple Nucleus roots."}
			prefix = path.trim_suffix(Inventory.MANIFEST)
	if prefix.is_empty():
		zip.close()
		return {"error": "This main commit does not contain the supported Nucleus addon."}
	var embedded: PackedByteArray = zip.read_file(prefix + Inventory.MANIFEST)
	if embedded != manifest_bytes:
		zip.close()
		return {"error": "Archive manifest does not match the pinned commit."}
	var total: int = 0
	for path: String in entries:
		if not path.begins_with(prefix):
			continue
		var relative: String = path.trim_prefix(prefix)
		if relative in [Inventory.MANIFEST, "RELEASE_MANIFEST.json"]:
			continue
		if not manifest.files.has(relative) or entries[path] != int(manifest.files[relative].size):
			zip.close()
			return {"error": "Unexpected source file or size: " + relative}
		total += int(entries[path])
	if total > Inventory.MAX_TOTAL_BYTES:
		zip.close()
		return {"error": "Archive exceeds addon size limit."}
	var cached: String = Manager.WORK + "sources/" + commit + "/nucleus/"
	var destination: String = Manager.WORK + "staging/" + commit
	destination += "_" + str(Time.get_ticks_usec()) + "/nucleus/"
	if DirAccess.dir_exists_absolute(Manager.global(cached)):
		zip.close()
		error = Inventory.verify(cached, manifest)
		return {"error": error, "source": cached, "manifest": manifest}
	if DirAccess.make_dir_recursive_absolute(Manager.global(destination)) != OK:
		zip.close()
		return {"error": "Cannot create update staging folder."}
	var ignore := FileAccess.open(Manager.WORK + ".gdignore", FileAccess.WRITE)
	if ignore == null:
		zip.close()
		return {"error": "Cannot exclude staged source from Godot imports."}
	ignore.close()
	# No writes to the active addon occur while extracting or validating.
	for relative: String in manifest.files:
		var path: String = prefix + relative
		if not entries.has(path) or entries[path] != int(manifest.files[relative].size):
			zip.close()
			return {"error": "Missing source file: " + relative}
		var content: PackedByteArray = zip.read_file(path)
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(content)
		if (content.size() != int(manifest.files[relative].size)
				or hashing.finish().hex_encode() != manifest.files[relative].sha256):
			zip.close()
			return {"error": "Source integrity check failed: " + relative}
		if not _write_bytes(destination.path_join(relative), content):
			zip.close()
			return {"error": "Cannot stage source file: " + relative}
	zip.close()
	if not _write_bytes(destination + Inventory.MANIFEST, manifest_bytes):
		return {"error": "Cannot save staged inventory."}
	error = Inventory.verify(destination, manifest)
	if not error.is_empty():
		return {"error": error}
	if DirAccess.make_dir_recursive_absolute(Manager.global(cached.get_base_dir())) != OK:
		return {"error": "Cannot create verified source cache."}
	if DirAccess.rename_absolute(Manager.global(destination), Manager.global(cached)) != OK:
		return {"error": "Cannot publish verified source cache."}
	return {"error": "", "source": cached, "manifest": manifest}


static func valid_commit(commit: String) -> bool:
	if commit.length() != 40:
		return false
	for character: String in commit:
		if character not in "0123456789abcdef":
			return false
	return true


static func central_directory(bytes: PackedByteArray) -> Dictionary:
	# ZIPReader allocates whole files. Bound central-directory sizes first.
	# GitHub source ZIPs use ordinary single-disk ZIP; ZIP64/encryption are rejected.
	if bytes.size() < 22 or bytes.size() > Inventory.MAX_TOTAL_BYTES:
		return {"error": "ZIP size is outside supported limits."}
	var end: int = -1
	for index in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if bytes.decode_u32(index) == 0x06054b50:
			if index + 22 + bytes.decode_u16(index + 20) == bytes.size():
				end = index
				break
	if end < 0 or bytes.decode_u32(end + 4) != 0:
		return {"error": "Unsupported ZIP directory."}
	var count: int = bytes.decode_u16(end + 10)
	var offset: int = bytes.decode_u32(end + 16)
	var length: int = bytes.decode_u32(end + 12)
	if count < 1 or count > 10000 or offset + length != end:
		return {"error": "Invalid or oversized ZIP directory."}
	var entries: Dictionary = {}
	var folded: Dictionary = {}
	var total: int = 0
	for index in count:
		if offset + 46 > end or bytes.decode_u32(offset) != 0x02014b50:
			return {"error": "Invalid ZIP entry."}
		var flags: int = bytes.decode_u16(offset + 8)
		var method: int = bytes.decode_u16(offset + 10)
		var size: int = bytes.decode_u32(offset + 24)
		var name_length: int = bytes.decode_u16(offset + 28)
		var next: int = offset + 46 + name_length + bytes.decode_u16(offset + 30)
		next += bytes.decode_u16(offset + 32)
		if next > end or flags & 1 or method not in [0, 8]:
			return {"error": "Unsupported ZIP encoding or compression."}
		var mode: int = bytes.decode_u32(offset + 38) >> 16
		if mode & 0xf000 == 0xa000:
			return {"error": "ZIP links are not supported."}
		var path: String = bytes.slice(offset + 46, offset + 46 + name_length).get_string_from_utf8()
		if not Inventory.safe_path(path.trim_suffix("/")) or folded.has(path.to_lower()):
			return {"error": "Unsafe or duplicate ZIP path."}
		folded[path.to_lower()] = true
		if size > Inventory.MAX_FILE_BYTES:
			return {"error": "ZIP entry exceeds file size limit."}
		total += size
		if total > Inventory.MAX_TOTAL_BYTES:
			return {"error": "ZIP exceeds expanded size limit."}
		if not path.ends_with("/"):
			entries[path] = size
		offset = next
	if offset != end:
		return {"error": "ZIP directory length does not match its entries."}
	return entries


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(Manager.global(path.get_base_dir())) != OK:
		return false
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_buffer(bytes)
	output.close()
	return FileAccess.get_file_as_bytes(path) == bytes
