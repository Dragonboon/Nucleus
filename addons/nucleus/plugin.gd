@tool
extends EditorPlugin
## Registers the existing six services without replacing host project policy.

const AUTOLOADS: Dictionary = {
	"NucleusApp": "res://addons/nucleus/core/application/application.gd",
	"NucleusSettings": "res://addons/nucleus/core/settings/settings.tscn",
	"NucleusInput": "res://addons/nucleus/core/input/input_service.gd",
	"NucleusAudio": "res://addons/nucleus/core/audio/audio.tscn",
	"NucleusSave": "res://addons/nucleus/core/save/save.tscn",
	"NucleusSceneFlow": "res://addons/nucleus/core/scene_flow/scene_flow_service.gd",
}
const OWNED_SETTING: String = "nucleus/editor/owned_autoloads"

const Dock = preload("res://addons/nucleus/editor/package_dock.gd")
const CatalogPanel = preload("res://addons/nucleus/editor/localization/catalog_panel.gd")
const MessageParser = preload("res://addons/nucleus/editor/localization/message_parser.gd")

var _dock: Control
var _catalog: VBoxContainer
var _parser: EditorTranslationParserPlugin
var _files: EditorFileDialog
var _folder: EditorFileDialog
var _result: AcceptDialog


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "Nucleus"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_catalog = CatalogPanel.new()
	_catalog.register_requested.connect(_show_translation_files)
	_catalog.sources_requested.connect(_show_translation_folder)
	_dock.add_localization(_catalog)
	_parser = MessageParser.new()
	add_translation_parser_plugin(_parser)
	_files = EditorFileDialog.new()
	_files.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	_files.access = EditorFileDialog.ACCESS_RESOURCES
	_files.filters = PackedStringArray(["*.po,*.mo ; Gettext translations"])
	_files.files_selected.connect(_register_translations)
	_folder = EditorFileDialog.new()
	_folder.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder.access = EditorFileDialog.ACCESS_RESOURCES
	_folder.dir_selected.connect(_register_translation_sources)
	_result = AcceptDialog.new()
	for dialog: Window in [_files, _folder, _result]:
		EditorInterface.get_base_control().add_child(dialog)
	add_tool_menu_item("Nucleus: Register PO/MO translations", _show_translation_files)
	add_tool_menu_item("Nucleus: Add translation source folder", _show_translation_folder)
	call_deferred("_retire_legacy_localization")


func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	if _parser != null:
		remove_translation_parser_plugin(_parser)
	remove_tool_menu_item("Nucleus: Register PO/MO translations")
	remove_tool_menu_item("Nucleus: Add translation source folder")
	for dialog: Window in [_files, _folder, _result]:
		if is_instance_valid(dialog):
			dialog.queue_free()


func _retire_legacy_localization() -> void:
	if EditorInterface.is_plugin_enabled("nucleus_localization"):
		EditorInterface.set_plugin_enabled("nucleus_localization", false)


func _show_translation_files() -> void:
	_files.popup_centered_ratio(0.6)


func _show_translation_folder() -> void:
	_folder.popup_centered_ratio(0.6)


func _register_translations(paths: PackedStringArray) -> void:
	var error: Error = NucleusLocalizationProjectTools.register_translations(paths)
	_result.dialog_text = "Translations registered." if error == OK else error_string(error)
	_result.popup_centered()
	_catalog.refresh_files()


func _register_translation_sources(path: String) -> void:
	var error: Error = NucleusLocalizationProjectTools.add_source_folder(path)
	_result.dialog_text = "Sources registered. Generate the POT in Project Settings > Localization."
	if error != OK:
		_result.dialog_text = error_string(error)
	_result.popup_centered()
	_catalog.refresh_files()


func _enable_plugin() -> void:
	# Check the entire set before writing anything: no partially installed core.
	var conflicts: PackedStringArray = get_autoload_conflicts()
	if not conflicts.is_empty():
		push_error("Nucleus: Autoload conflicts: " + ", ".join(conflicts))
		call_deferred("_reject_activation")
		return
	var owned: Dictionary = ProjectSettings.get_setting(OWNED_SETTING, {}).duplicate()
	for service: String in AUTOLOADS:
		var key: String = "autoload/" + service
		if ProjectSettings.has_setting(key):
			continue
		add_autoload_singleton(service, AUTOLOADS[service])
		owned[service] = ProjectSettings.get_setting(key)
	ProjectSettings.set_setting(OWNED_SETTING, owned)
	ProjectSettings.save()


func _disable_plugin() -> void:
	# Persisted ownership survives editor restarts. Adopted or replaced entries stay.
	var owned: Dictionary = ProjectSettings.get_setting(OWNED_SETTING, {})
	var services: Array = owned.keys()
	services.reverse()
	for service: String in services:
		var key: String = "autoload/" + service
		if (AUTOLOADS.has(service)
				and ProjectSettings.get_setting(key, "") == owned[service]
				and matches_service(owned[service], AUTOLOADS[service])):
			remove_autoload_singleton(service)
	ProjectSettings.set_setting(OWNED_SETTING, null)
	ProjectSettings.save()


func get_autoload_conflicts() -> PackedStringArray:
	var conflicts: PackedStringArray = []
	for service: String in AUTOLOADS:
		var key: String = "autoload/" + service
		if (ProjectSettings.has_setting(key)
				and not matches_service(ProjectSettings.get_setting(key), AUTOLOADS[service])):
			conflicts.append(service)
	return conflicts


func _build() -> bool:
	for service: String in AUTOLOADS:
		if not matches_service(
			ProjectSettings.get_setting("autoload/" + service, ""), AUTOLOADS[service]
		):
			push_error("Nucleus: enable the addon and resolve Autoload " + service)
			return false
	return true


func _reject_activation() -> void:
	EditorInterface.set_plugin_enabled("nucleus", false)


static func matches_service(value: String, expected_path: String) -> bool:
	if not value.begins_with("*"):
		return false
	var path: String = value.substr(1)
	if path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(path)
		if not ResourceUID.has_id(id):
			return false
		path = ResourceUID.get_id_path(id)
	return path == expected_path
