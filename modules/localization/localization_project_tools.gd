@tool
class_name NucleusLocalizationProjectTools
extends RefCounted
## Editor-only adapters over native PO/MO loading and localization project settings.

const TRANSLATIONS := "internationalization/locale/translations"
const SOURCES := "internationalization/locale/translations_pot_files"


static func register_translations(paths: PackedStringArray, persist: bool = true) -> Error:
	if not Engine.is_editor_hint():
		return ERR_UNAVAILABLE
	var normalized := PackedStringArray()
	for path: String in paths:
		var clean := path.simplify_path()
		if not clean.begins_with("res://") or clean.get_extension() not in ["po", "mo"]:
			return ERR_INVALID_PARAMETER
		if not ResourceLoader.exists(clean):
			return ERR_FILE_NOT_FOUND
		var translation := ResourceLoader.load(clean, "Translation") as Translation
		if translation == null or translation.get_locale().is_empty():
			return ERR_INVALID_DATA
		normalized.append(clean)
	return _append_setting(TRANSLATIONS, normalized, persist)


static func add_source_folder(folder: String, persist: bool = true) -> Error:
	if not Engine.is_editor_hint():
		return ERR_UNAVAILABLE
	var clean := folder.simplify_path()
	if not clean.begins_with("res://") or not DirAccess.dir_exists_absolute(clean):
		return ERR_INVALID_PARAMETER
	var paths := PackedStringArray()
	var error := _scan(clean, paths)
	if error != OK:
		return error
	paths.sort()
	return _append_setting(SOURCES, paths, persist)


static func _scan(folder: String, paths: PackedStringArray) -> Error:
	var directory := DirAccess.open(folder)
	if directory == null:
		return DirAccess.get_open_error()
	for file: String in directory.get_files():
		if file.get_extension() in ["gd", "tscn", "tres"]:
			paths.append(folder.path_join(file))
	for child: String in directory.get_directories():
		var path := folder.path_join(child)
		if child.begins_with(".") or child in ["addons", "tests", "build"]:
			continue
		if directory.is_link(child):
			continue
		var error := _scan(path, paths)
		if error != OK:
			return error
	return OK


static func _append_setting(key: String, paths: PackedStringArray, persist: bool) -> Error:
	var existed := ProjectSettings.has_setting(key)
	var previous: Variant = ProjectSettings.get_setting(key, PackedStringArray())
	var updated := PackedStringArray(previous)
	for path: String in paths:
		if path not in updated:
			updated.append(path)
	ProjectSettings.set_setting(key, updated)
	var error := ProjectSettings.save() if persist else OK
	if error != OK:
		ProjectSettings.set_setting(key, previous if existed else null)
	return error
