@tool
extends RefCounted
## Data-only inventory; never loads or executes scripts when preparing changes.

const ROOT: String = "res://addons/nucleus/"
const MANIFEST: String = "addon_manifest.json"
const PROFILES: Array[String] = ["full", "2d", "3d"]
const MAX_FILE_BYTES: int = 8 * 1024 * 1024
const MAX_TOTAL_BYTES: int = 64 * 1024 * 1024
const MAX_FILES: int = 6000


static func read_manifest(folder: String = ROOT) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(MANIFEST)))
	return parsed if parsed is Dictionary else {}


static func safe_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):
		return false
	for part: String in path.split("/"):
		if part in ["", ".", ".."] or part.ends_with(".") or part.ends_with(" "):
			return false
	return true


static func validate(manifest: Dictionary) -> String:
	if (manifest.get("schema") != 1 or manifest.get("repository") != "Dragonboon/Nucleus"
			or manifest.get("godot") != "4.7" or not manifest.get("version") is String
			or not manifest.get("files") is Dictionary
			or not manifest.get("profiles") is Dictionary):
		return "Unsupported Nucleus inventory."
	var files: Dictionary = manifest.files
	if files.is_empty() or files.size() > MAX_FILES:
		return "Invalid inventory size."
	var total: int = 0
	var folded: Dictionary = {}
	for path: Variant in files:
		if not path is String or not safe_path(path) or folded.has(path.to_lower()):
			return "Unsafe or duplicate inventory path."
		folded[path.to_lower()] = true
		var entry: Variant = files[path]
		if not entry is Dictionary:
			return "Invalid inventory entry: " + path
		var size: Variant = entry.get("size")
		if not (size is float or size is int):
			return "Invalid source size: " + path
		if (not entry.get("sha256") is String or entry.sha256.length() != 64
				or not entry.get("dependencies") is Array
				or entry.get("dimension") not in ["shared", "2d", "3d"]):
			return "Invalid inventory entry: " + path
		for character: String in entry.sha256:
			if character not in "0123456789abcdef":
				return "Invalid source digest: " + path
		if float(int(size)) != float(size):
			return "Fractional source size: " + path
		if entry.size < 0 or entry.size > MAX_FILE_BYTES:
			return "File exceeds installation limit: " + path
		total += int(entry.size)
		for dependency: Variant in entry.dependencies:
			if not dependency is String or not files.has(dependency):
				return "Missing dependency in inventory: " + path
	if total > MAX_TOTAL_BYTES:
		return "Addon exceeds installation limit."
	for profile: String in PROFILES:
		var selected: Variant = manifest.profiles.get(profile)
		if not selected is Array or selected.is_empty():
			return "Missing dimensional profile: " + profile
		var selected_set: Dictionary = {}
		for path: Variant in selected:
			if not path is String or not files.has(path) or selected_set.has(path):
				return "Invalid profile entry."
			selected_set[path] = true
		for path: String in selected_set:
			if (profile == "2d" and files[path].dimension == "3d"
					or profile == "3d" and files[path].dimension == "2d"):
				return "Profile retains an excluded dimensional component: " + path
			for dependency: String in files[path].dependencies:
				if not selected_set.has(dependency):
					return "Profile has an unresolved dependency: " + path
		for required: String in ["plugin.cfg", "plugin.gd", "VERSION", "LICENSE"]:
			if not selected_set.has(required):
				return "Profile omits required file: " + required
		for path: String in files:
			if path.begins_with("core/") or path.begins_with("editor/"):
				if not selected_set.has(path):
					return "Profile omits core/editor code: " + path
	if manifest.profiles.full.size() != files.size():
		return "Full profile must include every source file."
	return ""


static func list_files(folder: String, skip: Array[String] = []) -> PackedStringArray:
	var result: PackedStringArray = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return result
	for child: String in directory.get_files():
		if not child.ends_with(".import"):
			result.append(folder.path_join(child))
	for child: String in directory.get_directories():
		if child in skip or directory.is_link(child):
			continue
		result.append_array(list_files(folder.path_join(child), skip))
	return result


static func verify(folder: String, manifest: Dictionary, profile: String = "full") -> String:
	var error: String = validate(manifest)
	if profile not in PROFILES:
		return "Unknown dimensional profile."
	if not error.is_empty():
		return error
	for path: String in manifest.profiles[profile]:
		var target: String = folder.path_join(path)
		if not FileAccess.file_exists(target):
			return "Missing source file: " + path
		if FileAccess.get_sha256(target) != manifest.files[path].sha256:
			return "Modified source file: " + path
	if FileAccess.get_file_as_string(folder.path_join("VERSION")).strip_edges() != manifest.version:
		return "Source version does not match the inventory."
	var config := ConfigFile.new()
	if (config.load(folder.path_join("plugin.cfg")) != OK
			or config.get_value("plugin", "version", "") != manifest.version
			or config.get_value("plugin", "script", "") != "plugin.gd"):
		return "Plugin metadata does not match the inventory."
	return ""
