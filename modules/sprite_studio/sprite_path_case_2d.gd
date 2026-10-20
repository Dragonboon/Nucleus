@tool
class_name NucleusSpritePathCase2D
extends RefCounted
## Resolve project resource paths to their exact on-disk spelling.
## FileAccess on case-insensitive systems is not proof an export will work.


static func canonical_path(source: String) -> String:
	if not source.begins_with("res://") or ".." in source:
		return ""
	var remainder := source.trim_prefix("res://").trim_suffix("/")
	if remainder.is_empty():
		return "res://"
	var segments := remainder.split("/", false)
	var resolved := "res://"
	for index in range(segments.size()):
		var folder := DirAccess.open(resolved)
		if folder == null:
			return ""
		var names := folder.get_directories()
		if index == segments.size() - 1:
			names.append_array(folder.get_files())
		var segment := segments[index]
		var chosen := ""
		if segment in names:
			chosen = segment
		else:
			for item: String in names:
				if item.to_lower() != segment.to_lower():
					continue
				if not chosen.is_empty():
					return "" # Ambiguous spelling; do not guess.
				chosen = item
		if chosen.is_empty():
			return ""
		resolved = resolved.path_join(chosen)
	return resolved


static func normalize_sequence_profile(profile: NucleusSpriteSequenceProfile2D) -> Dictionary:
	if profile == null:
		return {"error": ERR_INVALID_PARAMETER, "changes": 0}
	var base := canonical_path(profile.source_directory)
	if base.is_empty():
		return {"error": ERR_FILE_NOT_FOUND, "path": profile.source_directory}
	var prepared: Array[PackedStringArray] = []
	var changes := int(base != profile.source_directory)
	for clip: NucleusSpriteSequenceClip2D in profile.clips:
		if clip == null:
			return {"error": ERR_INVALID_DATA}
		var paths := PackedStringArray()
		for path: String in clip.frame_paths:
			var resolved := canonical_path(path)
			if resolved.is_empty():
				return {"error": ERR_FILE_NOT_FOUND, "path": path}
			if resolved != path:
				changes += 1
			paths.append(resolved)
		prepared.append(paths)
	# Commit changes only after every path was successfully resolved.
	profile.source_directory = base
	for index in range(profile.clips.size()):
		profile.clips[index].frame_paths = prepared[index]
	return {"error": OK, "changes": changes}
