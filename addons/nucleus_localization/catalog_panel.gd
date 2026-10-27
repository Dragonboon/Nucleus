@tool
extends VBoxContainer
## Editor-only workflow UI. Native Godot and GNU gettext own parsing and catalog writes.

signal register_requested
signal sources_requested

const TOOLS = preload("res://modules/localization/localization_project_tools.gd")
const BRIDGE := "res://scripts/localization/editor_catalogs.py"

var _catalogs: Tree
var _sources: ItemList
var _details: TextEdit
var _template: LineEdit
var _locale: LineEdit
var _python: LineEdit
var _picker: EditorFileDialog
var _help: AcceptDialog
var _buttons: Array[Button] = []
var _cancel: Button
var _pid: int = -1
var _report_path: String = ""
var _command: String = ""
var _output_path: String = ""
var _pick_mode: String = ""
var _rows: Dictionary = {}
var _source_diagnostics := PackedStringArray()


func _ready() -> void:
	custom_minimum_size = Vector2(0, 340)
	var row: Container = HFlowContainer.new()
	add_child(row)
	_button(row, "Add sources", func() -> void: sources_requested.emit())
	_button(row, "Register PO/MO", func() -> void: register_requested.emit())
	_button(row, "POT workflow", _show_help)
	_button(row, "Refresh files", refresh_files)
	_button(row, "Check tools", func() -> void: _start("doctor"))
	_button(row, "Validate / status", func() -> void: _start("status"))
	_button(row, "Cancel job", _cancel_job)
	_cancel = _buttons[-1]
	_cancel.disabled = true
	row = HBoxContainer.new()
	add_child(row)
	_template = _field(row, "POT", "res://locale/messages.pot")
	_template.text = str(_metadata("template", ""))
	_button(row, "Choose POT", func() -> void: _choose("template"))
	_locale = _field(row, "New locale", "es, fr, pt_BR…")
	_locale.custom_minimum_size.x = 100
	_button(row, "Create PO", func() -> void: _choose("create"))
	_button(row, "Update selected PO", func() -> void: _start("update"))
	row = HBoxContainer.new()
	add_child(row)
	_python = _field(row, "Python executable", "python3 / absolute path")
	_python.text = str(_metadata("python", "python" if OS.get_name() == "Windows" else "python3"))
	_button(row, "Show selected file", _show_selected)
	_button(row, "Remove missing sources", _remove_missing_sources)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_catalogs = Tree.new()
	_catalogs.columns = 6
	_catalogs.hide_root = true
	_catalogs.column_titles_visible = true
	_catalogs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var titles := ["File / locale", "Translated", "Pending", "Review", "POT drift", "Status"]
	for index in titles.size():
		_catalogs.set_column_title(index, titles[index])
		_catalogs.set_column_expand(index, index == 0)
		_catalogs.set_column_custom_minimum_width(index, 80 if index > 0 else 240)
	_catalogs.item_selected.connect(_selection_changed)
	split.add_child(_catalogs)
	_sources = ItemList.new()
	_sources.custom_minimum_size.x = 240
	_sources.item_selected.connect(func(_index: int) -> void:
		_details.text = "\n".join(_source_diagnostics))
	split.add_child(_sources)
	_details = TextEdit.new()
	_details.editable = false
	_details.custom_minimum_size.y = 85
	add_child(_details)
	_picker = EditorFileDialog.new()
	_picker.access = EditorFileDialog.ACCESS_RESOURCES
	_picker.file_selected.connect(_picked)
	add_child(_picker)
	_help = AcceptDialog.new()
	_help.title = "Translation workflow"
	_help.dialog_text = (
		"1. Save your scenes and Resources. Add their source folder.\n"
		+ "2. Project > Project Settings > Localization > Template Generation > Generate.\n"
		+ "Godot extracts scripts/scenes; this addon includes message Resources.\n"
		+ "3. Choose that POT here, enter a locale and Create PO.\n"
		+ "4. Translate the PO with Poedit/Weblate; register the resulting file.\n"
		+ "5. Regenerate POT after content changes, then Update selected PO and Validate.\n"
		+ "Update preserves translations and creates a .po.bak; review fuzzy entries.\n\n"
		+ "Full extraction remains in Godot's native dialog: it has no public generation API.\n"
		+ "Read docs/guides/localization_workflow.md for an end-to-end example."
	)
	add_child(_help)
	refresh_files()
	_details.text = ("Choose a POT, then Validate / status. "
		+ "Python 3 + GNU gettext required for PO tools.")


func _button(parent: Control, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)


func _field(parent: Control, title: String, hint: String) -> LineEdit:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field


func refresh_files() -> void:
	if not is_node_ready() or _pid != -1:
		return
	_rows.clear()
	_catalogs.clear()
	var root := _catalogs.create_item()
	var paths: PackedStringArray = ProjectSettings.get_setting(
		TOOLS.TRANSLATIONS, PackedStringArray())
	for path in paths:
		var row := _catalogs.create_item(root)
		row.set_metadata(0, path)
		var language := "missing"
		if ResourceLoader.exists(path):
			var translation := ResourceLoader.load(path, "Translation",
				ResourceLoader.CACHE_MODE_IGNORE) as Translation
			language = translation.get_locale() if translation != null else "invalid"
		row.set_text(0, "%s [%s]" % [path, language])
		for column in range(1, 6):
			row.set_text(column, "—")
		row.set_text(5, "Compiled MO" if path.get_extension() == "mo" else "Not checked")
		_rows[ProjectSettings.globalize_path(path)] = row
	_source_diagnostics = TOOLS.audit_sources()
	_sources.tooltip_text = "\n".join(_source_diagnostics)
	_sources.clear()
	var sources: PackedStringArray = ProjectSettings.get_setting(TOOLS.SOURCES, PackedStringArray())
	for path in sources:
		_sources.add_item(("" if FileAccess.file_exists(path) else "MISSING: ") + path)


func _selection_changed() -> void:
	var row := _catalogs.get_selected()
	if row != null:
		_details.text = str(row.get_metadata(1)) if row.get_metadata(1) != null else str(
			row.get_metadata(0)) + "\nValidate to inspect translation state."


func _choose(mode: String) -> void:
	_pick_mode = mode
	_picker.file_mode = (EditorFileDialog.FILE_MODE_SAVE_FILE if mode == "create"
		else EditorFileDialog.FILE_MODE_OPEN_FILE)
	_picker.filters = PackedStringArray(["*.po ; Translation catalog"] if mode == "create"
		else ["*.pot ; Translation template"])
	_picker.popup_centered_ratio(0.7)


func _picked(path: String) -> void:
	if _pick_mode == "template":
		_template.text = path
		_save_preferences()
	else:
		_output_path = path
		_start("init")


func _show_help() -> void:
	_help.popup_centered(Vector2i(820, 360))


func _show_selected() -> void:
	var row := _catalogs.get_selected()
	if row != null:
		EditorInterface.get_file_system_dock().navigate_to_path(str(row.get_metadata(0)))


func _remove_missing_sources() -> void:
	var error := TOOLS.remove_missing_sources()
	refresh_files()
	_details.text = "Missing source entries removed: " + error_string(error)


func _start(command: String) -> void:
	if _pid != -1:
		return
	_save_preferences()
	var arguments := PackedStringArray([ProjectSettings.globalize_path(BRIDGE)])
	_report_path = "user://nucleus_localization_%d_%d.json" % [
		get_instance_id(), Time.get_ticks_usec()]
	arguments.append_array(["--report", ProjectSettings.globalize_path(_report_path), command])
	if command in ["init", "update"] and _template.text.is_empty():
		_details.text = "Choose the generated POT first."
		return
	if not _template.text.is_empty() and command != "doctor":
		arguments.append_array(["--template", ProjectSettings.globalize_path(_template.text)])
	if command == "status":
		for path: String in _rows:
			if path.get_extension() == "po":
				arguments.append(path)
	elif command in ["init", "update"]:
		if command == "update":
			var selected := _catalogs.get_selected()
			if selected == null:
				_details.text = "Select a registered PO to update."
				return
			_output_path = str(selected.get_metadata(0))
		if not _output_path.begins_with("res://") or _output_path.get_extension() != "po":
			_details.text = "Choose an editable .po under res://; MO files are compiled output."
			return
		arguments.append_array(["--output", ProjectSettings.globalize_path(_output_path)])
		if command == "init":
			arguments.append_array(["--locale", _locale.text.strip_edges()])
	_pid = OS.create_process(_python.text.strip_edges(), arguments)
	if _pid < 0:
		_details.text = "Could not start Python. Set its executable path and Check tools."
		_pid = -1
		return
	_command = command
	_details.text = "Running %s…" % command
	for button in _buttons:
		button.disabled = button != _cancel


func _process(_delta: float) -> void:
	if _pid == -1 or OS.is_process_running(_pid):
		return
	_pid = -1
	for button in _buttons:
		button.disabled = button == _cancel
	if not FileAccess.file_exists(_report_path):
		_details.text = "Tool exited without a report. Check Python path/version and editor output."
		return
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(_report_path))
	DirAccess.remove_absolute(_report_path)
	if not result is Dictionary:
		_details.text = "Invalid tool report."
		return
	if _command == "status":
		for entry: Dictionary in result.get("catalogs", []):
			var row: TreeItem = _rows.get(entry.path)
			if row == null:
				continue
			row.set_text(1, str(entry.translated))
			row.set_text(2, str(entry.untranslated))
			row.set_text(3, str(entry.fuzzy))
			row.set_text(4, "Unknown" if entry.needs_update == null else (
				"Update" if entry.needs_update else "Current"))
			row.set_text(5, "Valid" if entry.ok else "ERROR")
			row.set_metadata(1, entry.diagnostics)
	elif result.get("ok", false) and _command in ["init", "update"]:
		EditorInterface.get_resource_filesystem().scan()
	_details.text = str(result.get("diagnostics", "Validation finished. Select a row for details."))
	if not _source_diagnostics.is_empty():
		_details.text += "\n" + "\n".join(_source_diagnostics)
	if result.get("ok", false) and _command == "init":
		_details.text += "\nRegister the new PO after Godot finishes importing: " + _output_path


func _metadata(key: String, fallback: Variant) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(
		"nucleus_localization", key, fallback)


func _save_preferences() -> void:
	var settings := EditorInterface.get_editor_settings()
	settings.set_project_metadata("nucleus_localization", "template", _template.text)
	settings.set_project_metadata("nucleus_localization", "python", _python.text)


func _exit_tree() -> void:
	if _pid != -1 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if not _report_path.is_empty() and FileAccess.file_exists(_report_path):
		DirAccess.remove_absolute(_report_path)


func _cancel_job() -> void:
	if _pid != -1 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	for button in _buttons:
		button.disabled = button == _cancel
	_details.text = "Job stopped. Already committed files are preserved; refresh to inspect state."
	if FileAccess.file_exists(_report_path):
		DirAccess.remove_absolute(_report_path)
