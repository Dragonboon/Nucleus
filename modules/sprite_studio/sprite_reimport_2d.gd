@tool
class_name NucleusSpriteReimport2D
extends RefCounted
## Safe per-resource update with a sidecar manifest of generated clip hashes.

const FORMAT_VERSION: int = 1


static func sync(
	profile: NucleusSpriteSheetProfile2D,
	frames: SpriteFrames,
	library: AnimationLibrary,
	manifest: Dictionary,
) -> Dictionary:
	var previous_frames: Dictionary = manifest.get("frames", {})
	var previous_library: Dictionary = manifest.get("library", {})
	var frame_result := NucleusSpriteSheetBuilder2D.merge_frames(
		profile, frames, previous_frames,
	)
	var library_result := NucleusSpriteSheetBuilder2D.merge_library(
		profile, library, previous_library,
	)
	if frame_result.get("error", ERR_INVALID_DATA) != OK:
		return {"error": ERR_INVALID_DATA}
	if library_result.get("error", ERR_INVALID_DATA) != OK:
		return {"error": ERR_INVALID_DATA}
	return {
		"error": OK,
		"frames": frame_result["resource"],
		"library": library_result["resource"],
		"manifest": {
			"version": FORMAT_VERSION,
			"frames": frame_result["managed"],
			"library": library_result["managed"],
		},
		"conflicts": frame_result["conflicts"] + library_result["conflicts"],
		"updated": int(frame_result["updated"]) + int(library_result["updated"]),
	}


static func write_new_resource(resource: Resource, path: String) -> Error:
	if resource == null or not path.begins_with("res://") or ".." in path:
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(path):
		return ERR_ALREADY_EXISTS
	var dir_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return dir_error
	return ResourceSaver.save(resource, path)


static func read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != FORMAT_VERSION:
		return {}
	return data


static func write_manifest(path: String, manifest: Dictionary) -> Error:
	if not path.begins_with("res://") or ".." in path:
		return ERR_INVALID_PARAMETER
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(manifest, "\t"))
	file.flush()
	return OK
