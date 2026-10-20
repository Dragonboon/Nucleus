class_name NucleusSpriteSequenceImporter2D
extends RefCounted
## Detects frame sequences by filename numbering and folder structure.
## Never treats tilesets, preview GIFs or single images as animation clips.

const MAX_IMAGE_FILES: int = 4096
const MAX_SCAN_DEPTH: int = 8


static func scan_directory(source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not source.begins_with("res://") or ".." in source:
		return result
	var files := PackedStringArray()
	_collect(source.rstrip("/"), files, 0)
	files.sort()
	var pattern := RegEx.new()
	pattern.compile("^(.*?)[-_]([0-9]+)$")
	var grouped: Dictionary = {}
	for path: String in files:
		var basename := path.get_file().get_basename()
		var match_result := pattern.search(basename)
		if match_result == null:
			continue
		var stem := match_result.get_string(1)
		var order := int(match_result.get_string(2))
		var relative := path.trim_prefix(source.rstrip("/") + "/")
		var folder := relative.get_base_dir()
		var leaf := folder.get_file()
		var parent := folder.get_base_dir()
		var character := stem
		var clip_name := "default"
		var separator := stem.rfind("-")
		if separator > 0:
			character = stem.substr(0, separator)
			clip_name = stem.substr(separator + 1)
		if not leaf.is_empty() and stem.ends_with("-" + leaf):
			character = stem.trim_suffix("-" + leaf)
			clip_name = leaf
		elif stem == leaf:
			character = leaf
			clip_name = "default"
		var character_path := parent.path_join(character)
		if parent == ".":
			character_path = character
		if character == parent.get_file():
			character_path = parent
		if character_path.is_empty() or character_path == ".":
			continue
		var group_key := character_path
		if not grouped.has(group_key):
			grouped[group_key] = {}
		var animations: Dictionary = grouped[group_key]
		if not animations.has(clip_name):
			animations[clip_name] = []
		var sequence: Array = animations[clip_name]
		sequence.append({"path": path, "order": order})
	var keys := grouped.keys()
	keys.sort()
	for key: Variant in keys:
		var animations: Dictionary = grouped[key]
		var clips: Array[Dictionary] = []
		var animation_names := animations.keys()
		animation_names.sort()
		var total := 0
		for clip_name: Variant in animation_names:
			var items: Array = animations[clip_name]
			items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if int(a["order"]) != int(b["order"]):
					return int(a["order"]) < int(b["order"])
				return str(a["path"]) < str(b["path"])
			)
			var paths := PackedStringArray()
			for item: Dictionary in items:
				paths.append(str(item["path"]))
			total += paths.size()
			clips.append({"name": str(clip_name), "paths": paths})
		result.append({"id": str(key), "clips": clips, "frames": total})
	return result


static func create_profile(
	source_directory: String,
	discovery: Dictionary,
) -> NucleusSpriteSequenceProfile2D:
	var profile := NucleusSpriteSequenceProfile2D.new()
	profile.source_directory = source_directory
	profile.character_id = str(discovery.get("id", "character"))
	for descriptor: Dictionary in discovery.get("clips", []):
		var clip := NucleusSpriteSequenceClip2D.new()
		clip.animation_name = StringName(str(descriptor["name"]))
		clip.frame_paths = descriptor["paths"]
		profile.clips.append(clip)
	return profile


static func build_frames(profile: NucleusSpriteSequenceProfile2D) -> SpriteFrames:
	if profile == null or not profile.validate().is_empty():
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for clip: NucleusSpriteSequenceClip2D in profile.clips:
		frames.add_animation(clip.animation_name)
		frames.set_animation_speed(clip.animation_name, clip.fps)
		frames.set_animation_loop(clip.animation_name, clip.loop)
		for path: String in clip.frame_paths:
			var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
			if texture == null:
				return null
			frames.add_frame(clip.animation_name, texture)
	return frames


static func _collect(folder: String, files: PackedStringArray, depth: int) -> void:
	if depth > MAX_SCAN_DEPTH or files.size() >= MAX_IMAGE_FILES:
		return
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while filename != "" and files.size() < MAX_IMAGE_FILES:
		if not filename.begins_with("."):
			var path := folder.path_join(filename)
			if directory.current_is_dir():
				_collect(path, files, depth + 1)
			elif filename.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
				files.append(path)
		filename = directory.get_next()
	directory.list_dir_end()
