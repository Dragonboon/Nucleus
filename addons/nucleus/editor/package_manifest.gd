@tool
extends RefCounted
## Validates package metadata before any files are installed.

static func validate(entry: Dictionary) -> String:
	for field in ["id", "version", "path", "description", "dependencies"]:
		if not entry.has(field):
			return "Missing manifest field: %s" % field
	if not (entry["id"] is String and entry["version"] is String and entry["path"] is String):
		return "Invalid manifest scalar field."
	if not entry["dependencies"] is Array:
		return "Dependencies must be an array."
	var path: String = entry["path"]
	if path.is_empty() or path.begins_with("/") or path.contains("..") or path.contains("\\"):
		return "Unsafe package path."
	if not (path.begins_with("components/") or path.begins_with("modules/")):
		return "Package must reside in components/ or modules/."
	for dep in entry["dependencies"]:
		if not dep is String:
			return "Dependency IDs must be strings."
	return ""
