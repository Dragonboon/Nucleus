@tool
class_name NucleusSpriteBatchImport2D
extends RefCounted
## Explicit, bounded project-folder batch. No deletion of authored scenes.

const MAX_FILES: int = 2048
const MAX_SCAN_DEPTH: int = 8


static func discover(folder: String) -> PackedStringArray:
	var files := PackedStringArray()
	if not folder.begins_with("res://") or ".." in folder:
		return files
	_collect(folder, files, 0)
	files.sort()
	return files


static func _collect(folder: String, files: PackedStringArray, depth: int) -> void:
	if depth > MAX_SCAN_DEPTH or files.size() >= MAX_FILES:
		return
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	var entries := directory.get_directories()
	entries.sort()
	var images := directory.get_files()
	images.sort()
	for entry: String in images:
		if files.size() >= MAX_FILES:
			return
		if entry.begins_with(".") or directory.is_link(entry):
			continue
		if entry.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
			files.append(folder.path_join(entry))
	for entry: String in entries:
		if not entry.begins_with(".") and not directory.is_link(entry):
			_collect(folder.path_join(entry), files, depth + 1)


static func create_profile(texture: Texture2D, cell_size: Vector2i) -> NucleusSpriteSheetProfile2D:
	if texture == null or cell_size.x <= 0 or cell_size.y <= 0:
		return null
	var profile := NucleusSpriteSheetProfile2D.new()
	profile.texture = texture
	profile.cell_size = cell_size
	NucleusSpriteSheetBuilder2D.create_row_clips(profile)
	return profile


static func output_stem(source: String, root: String, output: String) -> String:
	if not source.begins_with(root.path_join("")):
		return ""
	var relative := source.trim_prefix(root.path_join(""))
	var parent := relative.get_base_dir()
	var file := relative.get_file().get_basename()
	return output.path_join(parent).path_join(file)


static func scan_plan(folder: String, output: String) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if not output.begins_with("res://") or ".." in output:
		return plan
	var sources := discover(folder)
	var stems: Dictionary = {}
	for source: String in sources:
		var stem := output_stem(source, folder, output)
		var key := stem.to_lower()
		stems[key] = int(stems.get(key, 0)) + 1
	for source: String in sources:
		var stem := output_stem(source, folder, output)
		if stem.is_empty():
			continue
		# Ambiguous output identities cannot safely own one profile on all platforms.
		if int(stems.get(stem.to_lower(), 0)) > 1:
			plan.append({"source": source, "error": "Ambiguous output name: " + stem})
			continue
		plan.append({
			"source": source,
			"profile": stem + ".profile.tres",
			"frames": stem + ".frames.tres",
			"library": stem + ".animations.tres",
		})
	return plan
