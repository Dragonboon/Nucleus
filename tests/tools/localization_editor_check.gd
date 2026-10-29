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
		"res://addons/nucleus/core/localization") == OK, "Source folder registers recursively.")
	var source_key := NucleusLocalizationProjectTools.SOURCES
	var sources: PackedStringArray = ProjectSettings.get_setting(source_key)
	_check(sources.has("res://addons/nucleus/core/localization/defaults/common_messages.tres"),
		"Source inventory includes Resource messages.")
	var config := ConfigFile.new()
	_check(config.load("res://project.godot") == OK, "Native settings saved.")
	_check(config.get_value("internationalization", "locale/translations") == registered,
		"Saved translation settings match.")
	var parser_script := load("res://addons/nucleus/editor/localization/message_parser.gd") as Script
	var parser: EditorTranslationParserPlugin = parser_script.new()
	var entries: Array[PackedStringArray] = parser._parse_file(
		"res://addons/nucleus/core/localization/defaults/common_messages.tres")
	_check(entries.size() == 12, "Native extraction plugin supplies twelve source entries.")
	sources.append("res://tests/smoke/localization_smoke.tscn")
	ProjectSettings.set_setting(source_key, sources)
	var custom: Array[PackedStringArray] = parser._customize_strings([])
	_check(custom.size() == 1 and custom[0][0] == "Hello {name}", "Scene enrichment works.")
	var catalog: NucleusMessageCatalog = load(
		"res://addons/nucleus/core/localization/defaults/common_messages.tres")
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
	await _check_panel()
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


func _check_panel() -> void:
	var panel: Control
	for node in NucleusNodeUtils.descendants(EditorInterface.get_base_control(), true):
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("/catalog_panel.gd"):
			panel = node as Control
			break
	_check(panel != null, "Enabled addon owns the integrated localization dock tab.")
	if panel == null:
		return
	panel.refresh_files()
	_check(panel._rows.size() >= 2, "Panel lists registered catalogs.")
	panel._template.text = "res://messages.pot"
	panel._python.text = OS.get_environment("NUCLEUS_TEST_PYTHON")
	panel._start("doctor")
	await _wait_panel(panel)
	_check("available" in panel._details.text, "Panel runs dependency diagnosis asynchronously.")
	panel._start("status")
	await _wait_panel(panel)
	var first: TreeItem = panel._catalogs.get_root().get_first_child()
	_check(first.get_text(5) == "Valid", "Panel displays native gettext validation.")
	panel._locale.text = "fr"
	panel._output_path = "res://tests/fixtures/localization/panel_fr.po"
	panel._start("init")
	await _wait_panel(panel)
	_check(FileAccess.file_exists(panel._output_path), "Panel creates a real PO.")
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	for index in 5:
		await get_tree().process_frame
	_check(NucleusLocalizationProjectTools.register_translations(
		PackedStringArray([panel._output_path])) == OK, "Created panel PO imports natively.")
	panel.refresh_files()
	var row: TreeItem = panel._rows[ProjectSettings.globalize_path(panel._output_path)]
	row.select(0)
	panel._start("update")
	await _wait_panel(panel)
	_check(FileAccess.file_exists(panel._output_path + ".bak"), "Panel update creates backup.")
	panel._start("update")
	await _wait_panel(panel)
	_check("backup" in panel._details.text, "Panel surfaces refused overwrite diagnostics.")
	var key := NucleusLocalizationProjectTools.SOURCES
	var sources: PackedStringArray = ProjectSettings.get_setting(key)
	sources.append("res://deleted_source.tres")
	ProjectSettings.set_setting(key, sources)
	_check(not NucleusLocalizationProjectTools.audit_sources().is_empty(), "Missing source diagnosed.")
	_check(NucleusLocalizationProjectTools.remove_missing_sources() == OK, "Explicit source cleanup.")
	_check(not PackedStringArray(ProjectSettings.get_setting(key)).has("res://deleted_source.tres"),
		"Missing source setting removed.")
	var one := NucleusLocalizedMessage.new()
	one.source = "Conflict"
	var two := NucleusLocalizedMessage.new()
	two.source = "Conflict"
	two.plural = "Conflicts"
	ResourceSaver.save(one, "res://tests/fixtures/localization/conflict_one.tres")
	ResourceSaver.save(two, "res://tests/fixtures/localization/conflict_two.tres")
	sources = ProjectSettings.get_setting(key)
	sources.append("res://tests/fixtures/localization/conflict_one.tres")
	sources.append("res://tests/fixtures/localization/conflict_two.tres")
	ProjectSettings.set_setting(key, sources)
	var diagnostics := "\n".join(NucleusLocalizationProjectTools.audit_sources())
	_check("Conflicting plural" in diagnostics and "conflict_two.tres" in diagnostics,
		"Conflicts identify the message and source file.")


func _wait_panel(panel: Control) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while panel._pid != -1 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(panel._pid == -1, "Editor job completed within deadline.")
