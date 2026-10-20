@tool
class_name NucleusSpriteBatchImport2D
extends RefCounted
## Explicit, bounded project-folder batch. No deletion of authored scenes.

const MAX_FILES: int = 2048


static func discover(folder: String) -> PackedStringArray:
	var files := PackedStringArray()
	if not folder.begins_with("res://") or ".." in folder:
		return files
	var directory := DirAccess.open(folder)
	if directory == null:
		return files
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if directory.current_is_dir():
			if not entry.begins_with("."):
				files.append_array(discover(folder.path_join(entry)))
		elif entry.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
			files.append(folder.path_join(entry))
		if files.size() >= MAX_FILES:
			break
		entry = directory.get_next()
	directory.list_dir_end()
	files.sort()
	return files


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
	for source: String in discover(folder):
		var stem := output_stem(source, folder, output)
		if stem.is_empty():
			continue
		plan.append({
			"source": source,
			"profile": stem + ".profile.tres",
			"frames": stem + ".frames.tres",
			"library": stem + ".animations.tres",
		})
	return plan
