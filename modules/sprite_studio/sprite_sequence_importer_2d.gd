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
	var records: Array[Dictionary] = []
	var sibling_prefixes: Dictionary = {}
	for path: String in files:
		var basename := path.get_file().get_basename()
		var matched := pattern.search(basename)
		if matched == null:
			continue
		var stem := matched.get_string(1)
		var relative := path.trim_prefix(source.rstrip("/") + "/")
		var folder := relative.get_base_dir()
		var leaf := folder.get_file()
		var parent := folder.get_base_dir()
		records.append({
			"path": path, "stem": stem, "leaf": leaf, "parent": parent,
			"order": int(matched.get_string(2)),
		})
		# Sibling folder pattern: grasshopper-idle, grasshopper-jump, ...
		if stem == leaf and leaf.contains("-"):
			var split := leaf.rfind("-")
			var prefix := parent.path_join(leaf.substr(0, split))
			var suffix := leaf.substr(split + 1)
			if not suffix.is_empty():
				var existing: Dictionary = sibling_prefixes.get(prefix, {})
				existing[leaf] = true
				sibling_prefixes[prefix] = existing
	var grouped: Dictionary = {}
	for record: Dictionary in records:
		var stem: String = record["stem"]
		var leaf: String = record["leaf"]
		var parent: String = record["parent"]
		var character := stem
		var clip_name := "default"
		if not leaf.is_empty() and stem.ends_with("-" + leaf):
			character = stem.trim_suffix("-" + leaf)
			clip_name = leaf
		elif stem == leaf:
			var split := leaf.rfind("-")
			if split > 0:
				var prefix := parent.path_join(leaf.substr(0, split))
				if (sibling_prefixes.get(prefix, {}) as Dictionary).size() >= 2:
					character = leaf.substr(0, split)
					clip_name = leaf.substr(split + 1)
		var character_path := parent.path_join(character)
		if parent == ".":
			character_path = character
		if character == parent.get_file():
			character_path = parent
		if character_path.is_empty() or character_path == ".":
			continue
		if not grouped.has(character_path):
			grouped[character_path] = {}
		var animations: Dictionary = grouped[character_path]
		if not animations.has(clip_name):
			animations[clip_name] = []
		var sequence: Array = animations[clip_name]
		sequence.append({"path": record["path"], "order": record["order"]})
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
		if not filename.begins_with(".") and not directory.is_link(filename):
			var path := folder.path_join(filename)
			if directory.current_is_dir():
				_collect(path, files, depth + 1)
			elif filename.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
				files.append(path)
		filename = directory.get_next()
	directory.list_dir_end()
