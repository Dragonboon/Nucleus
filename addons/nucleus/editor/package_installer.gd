@tool
extends RefCounted
## Controlled, non-destructive ZIP package installer.
## The release process must create archives rooted at components/ or modules/.
## Never follow arbitrary paths from a downloaded archive.

static func install_zip(bytes: PackedByteArray, allowed_root: String) -> String:
	if not (allowed_root.begins_with("components/") or allowed_root.begins_with("modules/")):
		return "Invalid installation root."
	var tmp := "user://nucleus-package-staging.zip"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return "Unable to create staging ZIP."
	file.store_buffer(bytes)
	file.close()
	var zip := ZIPReader.new()
	if zip.open(tmp) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return "Invalid ZIP."
	var entries := zip.get_files()
	if entries.is_empty():
		zip.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return "Empty archive."
	for entry in entries:
		if entry.begins_with("/") or entry.contains("..") or entry.contains("\\") or not entry.begins_with(allowed_root):
			zip.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
			return "Archive contains an unexpected path: %s" % entry
		if entry.ends_with(".gd.uid") or entry.ends_with(".tscn") or entry.ends_with(".tres") or entry.ends_with(".gd") or entry.ends_with(".md") or entry.ends_with(".json") or entry.ends_with(".png") or entry.ends_with(".svg") or entry.ends_with(".shader") or entry.ends_with("/"):
			continue
		zip.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return "Archive contains an unsupported file type."
	# Preflight every target. Refuse overwrites until upgrade/rollback support exists.
	for entry in entries:
		if not entry.ends_with("/") and FileAccess.file_exists("res://" + entry):
			zip.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
			return "Destination already exists: %s" % entry
	for entry in entries:
		var destination := "res://" + entry
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
		var output := FileAccess.open(destination, FileAccess.WRITE)
		if output == null:
			zip.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
			return "Cannot write %s; review partial files before retrying." % entry
		output.store_buffer(zip.read_file(entry))
		output.close()
	zip.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return ""
