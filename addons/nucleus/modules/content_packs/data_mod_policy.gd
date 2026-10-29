class_name NucleusDataModPolicy
extends Resource
## Security policy for untrusted community data mods.
##
## The defaults are intentionally conservative. Additional media formats should
## be enabled only after the consuming game reviews its parser surface.

@export var allowed_extensions := PackedStringArray([
	"json",
	"csv",
	"txt",
])
@export_range(1, 10000, 1, "or_greater") var maximum_files: int = 512
@export_range(1, 268435456, 1, "or_greater")
var maximum_file_bytes: int = 4 * 1024 * 1024
@export_range(1, 1073741824, 1, "or_greater")
var maximum_total_bytes: int = 32 * 1024 * 1024
@export var allow_store_only_zip: bool = false


func is_relative_path_allowed(relative_path: String) -> bool:
	var normalized: String = relative_path.replace("\\", "/").strip_edges()

	if normalized.is_empty() or normalized.ends_with("/"):
		return false

	if (
		normalized.begins_with("/")
		or normalized.begins_with("res://")
		or normalized.begins_with("user://")
		or normalized.contains(":")
		or normalized.contains("\u0000")
	):
		return false

	var segments: PackedStringArray = normalized.split("/", false)
	if segments.is_empty():
		return false

	for segment: String in segments:
		if segment in [".", ".."] or segment.begins_with("."):
			return false

	var extension: String = normalized.get_extension().to_lower()
	if _is_blocked_extension(extension):
		return false

	return extension in allowed_extensions


static func _is_blocked_extension(extension: String) -> bool:
	return extension in [
		"gd",
		"gdc",
		"cs",
		"py",
		"js",
		"lua",
		"tscn",
		"scn",
		"tres",
		"res",
		"gdextension",
		"dll",
		"so",
		"dylib",
		"exe",
		"wasm",
		"pck",
		"zip",
		"apk",
		"aab",
		"jar",
	]
