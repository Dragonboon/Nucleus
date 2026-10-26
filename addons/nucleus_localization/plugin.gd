@tool
extends EditorPlugin

const Parser = preload("res://addons/nucleus_localization/message_parser.gd")
var _parser: EditorTranslationParserPlugin
var _files: EditorFileDialog
var _folder: EditorFileDialog
var _result: AcceptDialog


func _enter_tree() -> void:
	_parser = Parser.new()
	add_translation_parser_plugin(_parser)
	_files = EditorFileDialog.new()
	_files.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	_files.access = EditorFileDialog.ACCESS_RESOURCES
	_files.filters = PackedStringArray(["*.po,*.mo ; Gettext translations"])
	_files.files_selected.connect(_register)
	_folder = EditorFileDialog.new()
	_folder.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder.access = EditorFileDialog.ACCESS_RESOURCES
	_folder.dir_selected.connect(_sources)
	_result = AcceptDialog.new()
	for dialog: Window in [_files, _folder, _result]:
		EditorInterface.get_base_control().add_child(dialog)
	add_tool_menu_item("Nucleus: Register PO/MO translations", _show_files)
	add_tool_menu_item("Nucleus: Add translation source folder", _show_folder)


func _exit_tree() -> void:
	remove_tool_menu_item("Nucleus: Register PO/MO translations")
	remove_tool_menu_item("Nucleus: Add translation source folder")
	remove_translation_parser_plugin(_parser)
	for dialog: Window in [_files, _folder, _result]:
		dialog.queue_free()


func _show_files() -> void:
	_files.popup_centered_ratio(0.6)


func _show_folder() -> void:
	_folder.popup_centered_ratio(0.6)


func _register(paths: PackedStringArray) -> void:
	var error := NucleusLocalizationProjectTools.register_translations(paths)
	_result.dialog_text = ("Translations registered in Project Settings."
		if error == OK else "Registration failed: " + error_string(error))
	_result.popup_centered()


func _sources(path: String) -> void:
	var error := NucleusLocalizationProjectTools.add_source_folder(path)
	_result.dialog_text = ("Sources added. Open Project Settings > Localization > "
		+ "Template Generation, then Generate to create or update your POT."
		if error == OK else "Source registration failed: " + error_string(error))
	_result.popup_centered()
