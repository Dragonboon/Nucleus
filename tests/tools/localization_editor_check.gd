@tool
extends EditorPlugin
## Run only in an isolated project copy: validates persisted editor operations.

var _failures := PackedStringArray()


func _enter_tree() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in 10:
		await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	var key := NucleusLocalizationProjectTools.TRANSLATIONS
	var before: PackedStringArray = ProjectSettings.get_setting(key)
	_check(NucleusLocalizationProjectTools.register_translations(
		PackedStringArray(["res://tests/fixtures/localization/es.po",
			"res://tests/fixtures/localization/es.mo"])) == OK, "PO registers.")
	_check(NucleusLocalizationProjectTools.register_translations(
		PackedStringArray(["res://tests/fixtures/localization/es.po",
			"res://tests/fixtures/localization/es.mo"])) == OK, "Register idempotent.")
	var registered: PackedStringArray = ProjectSettings.get_setting(key)
	_check(registered.size() == before.size() + 2, "No duplicate registered paths.")
	_check(NucleusLocalizationProjectTools.register_translations(PackedStringArray([
		"res://tests/fixtures/localization/es.po", "res://missing.po"])) != OK, "Bad batch rejects.")
	_check(ProjectSettings.get_setting(key) == registered, "Failed registration preserves settings.")
	_check(NucleusLocalizationProjectTools.add_source_folder(
		"res://core/localization") == OK, "Source folder registers recursively.")
	var source_key := NucleusLocalizationProjectTools.SOURCES
	var sources: PackedStringArray = ProjectSettings.get_setting(source_key)
	_check(sources.has("res://core/localization/defaults/common_messages.tres"),
		"Source inventory includes Resource messages.")
	var config := ConfigFile.new()
	_check(config.load("res://project.godot") == OK, "Native settings saved.")
	_check(config.get_value("internationalization", "locale/translations") == registered,
		"Saved translation settings match.")
	var parser_script := load("res://addons/nucleus_localization/message_parser.gd") as Script
	var parser: EditorTranslationParserPlugin = parser_script.new()
	var entries: Array[PackedStringArray] = parser._parse_file(
		"res://core/localization/defaults/common_messages.tres")
	_check(entries.size() == 12, "Native extraction plugin supplies twelve source entries.")
	sources.append("res://tests/smoke/localization_smoke.tscn")
	ProjectSettings.set_setting(source_key, sources)
	var custom: Array[PackedStringArray] = parser._customize_strings([])
	_check(custom.size() == 1 and custom[0][0] == "Hello {name}", "Scene enrichment works.")
	var catalog: NucleusMessageCatalog = load(
		"res://core/localization/defaults/common_messages.tres")
	var messages: Array[NucleusLocalizedMessage] = catalog.messages.duplicate()
	var plural := NucleusLocalizedMessage.new()
	plural.source = "{count} item"
	plural.plural = "{count} items"
	plural.context = &"inventory"
	messages.append(plural)
	var escaped := NucleusLocalizedMessage.new()
	escaped.source = "Line \"one\"\nSlash \\ and café"
	escaped.context = &"quoted"
	messages.append(escaped)
	_check(NucleusTranslationTemplates.write_pot("res://messages.pot", messages) == OK,
		"Editor writes real template for gettext tooling.")
	if _failures.is_empty():
		print("Nucleus localization editor pipeline: PASS")
	else:
		for failure: String in _failures:
			push_error(failure)
	for index in 5:
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
