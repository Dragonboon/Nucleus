@tool
extends RefCounted
## Owns profile previews and staged directory swaps. Runtime APIs stay unchanged.

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")
const ROOT: String = "res://addons/nucleus/"
const WORK: String = "res://.nucleus/"
const STATE: String = WORK + "installation.json"
const PROFILE_FILE: String = "installation_profile.json"
const SCAN_EXTENSIONS: Array[String] = [
	"gd", "cs", "tscn", "tres", "res", "scn", "godot", "json", "cfg", "gdshader", "gdshaderinc",
]

var _busy: bool = false


func state() -> Dictionary:
	if not FileAccess.file_exists(STATE):
		var marker: Variant = null
		if FileAccess.file_exists(ROOT + PROFILE_FILE):
			marker = JSON.parse_string(FileAccess.get_file_as_string(ROOT + PROFILE_FILE))
		if (marker is Dictionary and marker.get("profile") in Inventory.PROFILES
				and marker.get("manifest_sha256") == FileAccess.get_sha256(ROOT + Inventory.MANIFEST)):
			return {"profile": marker.profile, "source": "", "commit": marker.get("commit", ""),
				"backup": ""}
		return {"profile": "full", "source": "", "commit": "", "backup": ""}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	return parsed if parsed is Dictionary else {}


func preview(profile: String, source: String = "") -> Dictionary:
	if profile not in Inventory.PROFILES:
		return {"error": "Unknown profile."}
	var current: Dictionary = Inventory.read_manifest()
	var error: String = Inventory.validate(current)
	if not error.is_empty():
		return {"error": error}
	var settings: Dictionary = state()
	var previous: String = settings.get("profile", "full")
	if previous not in Inventory.PROFILES:
		return {"error": "Invalid installed profile state."}
	error = Inventory.verify(ROOT, current, previous)
	if not error.is_empty():
		return {"error": error + ". Restore local edits before changing the addon."}
	var expected: Array = current.profiles[previous]
	for path: String in Inventory.list_files(ROOT):
		var relative: String = path.trim_prefix(ROOT)
		if relative not in expected and relative not in [
			Inventory.MANIFEST, "RELEASE_MANIFEST.json", PROFILE_FILE
		]:
			return {"error": "Unmanaged addon file: " + relative + ". Move it outside Nucleus first."}
	var incoming: Dictionary = current if source.is_empty() else Inventory.read_manifest(source)
	error = Inventory.validate(incoming)
	if not error.is_empty():
		return {"error": error}
	var removed: PackedStringArray = []
	for path: String in expected:
		if path not in incoming.profiles[profile]:
			removed.append(path)
	var blockers: PackedStringArray = find_references(removed, current)
	return {
		"error": "" if blockers.is_empty() else "Project references prevent removal.",
		"profile": profile, "remove": removed, "blockers": blockers,
		"keep_count": incoming.profiles[profile].size(),
		"version": incoming.version, "manifest": incoming,
	}


func find_references(removed: PackedStringArray, _current: Dictionary) -> PackedStringArray:
	if removed.is_empty():
		return []
	var needles: Dictionary = {}
	var class_pattern := RegEx.new()
	class_pattern.compile("(?m)^class_name\\s+(Nucleus[A-Za-z0-9_]+)")
	for path: String in removed:
		if path.ends_with(".uid"):
			var uid: String = FileAccess.get_file_as_string(ROOT + path).strip_edges()
			if not uid.is_empty():
				needles[uid] = path
		else:
			needles[ROOT + path] = path
			needles["addons/nucleus/" + path] = path
			if path.ends_with(".gd"):
				var match_result: RegExMatch = class_pattern.search(
					FileAccess.get_file_as_string(ROOT + path))
				if match_result != null:
					needles[match_result.get_string(1)] = path
	var uid_pattern := RegEx.new()
	uid_pattern.compile("uid=\"(uid://[a-z0-9]+)\"")
	for path: String in removed:
		if path.ends_with(".tscn") or path.ends_with(".tres"):
			var header: String = FileAccess.get_file_as_string(ROOT + path).get_slice("\n", 0)
			var uid_match: RegExMatch = uid_pattern.search(header)
			if uid_match != null:
				needles[uid_match.get_string(1)] = path
	# The manifest already proves dependencies within unmodified framework files.
	# Scan every host source/config resource, including other addons and C# scripts.
	var blockers: PackedStringArray = []
	for host_path: String in Inventory.list_files("res://", [".git", ".godot", ".nucleus"]):
		if host_path.begins_with(ROOT) or host_path.get_extension() not in SCAN_EXTENSIONS:
			continue
		var text: String
		if host_path.get_extension() in ["res", "scn"]:
			text = "\n".join(ResourceLoader.get_dependencies(host_path))
		else:
			text = FileAccess.get_file_as_string(host_path)
		for needle: String in needles:
			if text.contains(needle):
				blockers.append(host_path + " -> " + str(needles[needle]))
				break
	return blockers


func apply_profile(profile: String) -> Dictionary:
	var plan: Dictionary = preview(profile)
	if not plan.error.is_empty():
		return plan
	var settings: Dictionary = state()
	var source: String = settings.get("source", "")
	if source.is_empty():
		var cache: String = WORK + "sources/" + FileAccess.get_sha256(ROOT + Inventory.MANIFEST)
		source = cache + "/nucleus/"
		var error: String = copy_inventory(ROOT, source, plan.manifest, "full")
		if not error.is_empty():
			return {"error": error}
	return install(source, profile, settings.get("commit", ""))


func install(source: String, profile: String, commit: String = "") -> Dictionary:
	if _busy:
		return {"error": "An addon operation is already running."}
	if not source.begins_with(WORK) or not source.ends_with("/nucleus/"):
		return {"error": "Expected a verified project-local staging source."}
	var incoming: Dictionary = Inventory.read_manifest(source)
	var error: String = Inventory.verify(source, incoming)
	if not error.is_empty():
		return {"error": error}
	var plan: Dictionary = preview(profile, source)
	if not plan.error.is_empty():
		return plan
	_busy = true
	var transaction: String = WORK + "backups/"
	transaction += str(Time.get_unix_time_from_system()).replace(".", "_")
	var stage: String = transaction + "/candidate/"
	error = copy_inventory(source, stage, incoming, profile)
	if error.is_empty():
		error = Inventory.verify(stage, incoming, profile)
	if error.is_empty() and not write_json(stage + PROFILE_FILE, {
		"profile": profile, "manifest_sha256": FileAccess.get_sha256(stage + Inventory.MANIFEST),
		"commit": commit,
	}):
		error = "Cannot save portable dimensional profile."
	if not error.is_empty():
		_busy = false
		return {"error": error}
	var before: Dictionary = state()
	if not write_json(transaction + "/previous_state.json", before):
		_busy = false
		return {"error": "Cannot save rollback state. Live addon unchanged."}
	var backup: String = transaction + "/nucleus/"
	var moved: Error = DirAccess.rename_absolute(global(ROOT), global(backup))
	if moved != OK:
		_busy = false
		return {"error": "Cannot back up the live addon: " + error_string(moved)}
	moved = DirAccess.rename_absolute(global(stage), global(ROOT))
	if moved != OK:
		var rollback: Error = DirAccess.rename_absolute(global(backup), global(ROOT))
		_busy = false
		return {"error": "Install failed (%s); rollback: %s. Backup: %s" % [
			error_string(moved), error_string(rollback), backup]}
	var after: Dictionary = {
		"profile": profile, "source": source, "commit": commit, "backup": backup,
		"manifest_sha256": FileAccess.get_sha256(ROOT + Inventory.MANIFEST),
	}
	if not write_json(STATE, after):
		var displaced: Error = DirAccess.rename_absolute(global(ROOT), global(stage))
		var rollback: Error = DirAccess.rename_absolute(global(backup), global(ROOT))
		_busy = false
		return {"error": "State write failed; rollback: %s / %s. Backup: %s" % [
			error_string(displaced), error_string(rollback), backup]}
	_busy = false
	return {"error": "", "backup": backup, "profile": profile, "restart_required": true}


func restore_backup() -> Dictionary:
	var settings: Dictionary = state()
	var backup: String = settings.get("backup", "")
	if not backup.begins_with(WORK + "backups/") or not backup.ends_with("/nucleus/"):
		return {"error": "No previous installation backup."}
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		backup.trim_suffix("nucleus/") + "previous_state.json"))
	if not previous is Dictionary:
		return {"error": "Backup state is unavailable."}
	var manifest: Dictionary = Inventory.read_manifest(backup)
	var profile: String = previous.get("profile", "full")
	var source: String = previous.get("source", "")
	if source.is_empty():
		source = backup
	# Backup of a pruned installation uses its retained, verified full source cache.
	if not Inventory.verify(source, manifest).is_empty():
		return {"error": "Backup source cache is incomplete; restore the saved folder manually."}
	return install(source, profile, previous.get("commit", ""))


static func copy_inventory(
	source: String, destination: String, manifest: Dictionary, profile: String
) -> String:
	if is_link(WORK.trim_suffix("/")) or is_link(ROOT.trim_suffix("/")):
		return "Refusing a symlinked addon or workspace."
	if DirAccess.make_dir_recursive_absolute(global(destination)) != OK:
		return "Cannot create staging directory."
	var ignore := FileAccess.open(WORK + ".gdignore", FileAccess.WRITE)
	if ignore == null:
		return "Cannot exclude backup scripts from Godot imports."
	ignore.close()
	var selected: Array = manifest.profiles[profile].duplicate()
	selected.append(Inventory.MANIFEST)
	for path: String in selected:
		var target: String = destination.path_join(path)
		if DirAccess.make_dir_recursive_absolute(global(target.get_base_dir())) != OK:
			return "Cannot create destination folder: " + path
		if is_link(source.path_join(path)):
			return "Refusing a linked source: " + path
		var copied: Error = DirAccess.copy_absolute(global(source.path_join(path)), global(target))
		if copied != OK:
			return "Copy failed for %s: %s" % [path, error_string(copied)]
	return ""


static func is_link(path: String) -> bool:
	var directory := DirAccess.open(path.get_base_dir())
	return directory != null and directory.is_link(path.get_file())


static func global(path: String) -> String:
	return ProjectSettings.globalize_path(path).trim_suffix("/")


static func write_json(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(global(path.get_base_dir())) != OK:
		return false
	var output := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(value, "\t") + "\n")
	output.close()
	return DirAccess.rename_absolute(global(path + ".tmp"), global(path)) == OK
