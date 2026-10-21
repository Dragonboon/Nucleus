@tool
extends VBoxContainer
## Profile editor and conservative batch export; never overwrites scene files.

var _picker: EditorResourcePicker
var _preview: TextureRect
var _info: Label
var _save_dialog: EditorFileDialog
var _batch_source: LineEdit
var _batch_output: LineEdit
var _cell_x: SpinBox
var _cell_y: SpinBox
var _export_scene: bool = false
var _sequence_source: LineEdit
var _sequence_output: LineEdit
var _sequence_preview: ItemList
var _sequence_discovery: Array[Dictionary] = []
var _progress: ProgressBar
var _results: RichTextLabel
var _status: Label
var _busy: bool = false
var _cancel_requested: bool = false
var _cancel_button: Button
var _actions: Array[Button] = []


func _ready() -> void:
	_picker = EditorResourcePicker.new()
	_picker.base_type = "NucleusSpriteSheetProfile2D"
	_picker.resource_changed.connect(_on_profile_changed)
	add_child(_picker)
	var actions := HFlowContainer.new()
	add_child(actions)
	_add_button(actions, "Suggest grid", _suggest_grid)
	_add_button(actions, "Generate row clips", _generate_rows)
	_add_button(actions, "Edit profile", _edit_profile)
	_add_button(actions, "Save SpriteFrames", _save_frames)
	_add_button(actions, "Save scene", _save_scene)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(420, 160)
	_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_preview)
	var section := Label.new()
	section.text = "SHEET MODE  |  Uniform grids (not numbered PNG sequences)"
	add_child(section)
	_batch_source = _line("res://assets/sprites", "Source folder, including nested folders")
	_batch_output = _line("res://generated/sprites", "Output folder")
	var size_controls := HFlowContainer.new()
	add_child(size_controls)
	_cell_x = _spin(size_controls, 32)
	_cell_y = _spin(size_controls, 32)
	_add_button(size_controls, "Preview batch", _preview_batch)
	_add_button(size_controls, "Import batch", _import_batch)
	_add_button(size_controls, "Reimport batch", _reimport_batch)
	_info = Label.new()
	add_child(_info)
	_status = Label.new()
	_status.text = "READY  |  Select a source and preview the import"
	_status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.95))
	add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 18.0
	_progress.show_percentage = true
	_progress.value = 0
	add_child(_progress)
	_results = RichTextLabel.new()
	_results.bbcode_enabled = true
	_results.fit_content = false
	_results.custom_minimum_size = Vector2(440, 130)
	add_child(_results)
	_save_dialog = EditorFileDialog.new()
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.file_selected.connect(_on_save_selected)
	add_child(_save_dialog)
	_build_sequence_workflow()
	_organize_layout()
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel after current item"
	_cancel_button.disabled = true
	_cancel_button.pressed.connect(func() -> void: _cancel_requested = true)
	add_child(_cancel_button)
	_sequence_source.text_changed.connect(func(_text: String) -> void:
		_sequence_discovery.clear()
		_sequence_preview.clear()
		_info.text = "Source changed. Detect characters again before generating."
	)
	_on_profile_changed(null)


func _line(value: String, hint: String) -> LineEdit:
	var control := LineEdit.new()
	control.text = value
	control.placeholder_text = hint
	control.tooltip_text = hint
	add_child(control)
	return control


func _spin(parent: Control, value: int) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = 1.0
	control.max_value = 1024.0
	control.value = value
	parent.add_child(control)
	return control


func _add_button(row: Control, label_text: String, callback: Callable) -> void:
	var action := Button.new()
	action.text = label_text
	action.pressed.connect(callback)
	_actions.append(action)
	row.add_child(action)


func _profile() -> NucleusSpriteSheetProfile2D:
	return _picker.edited_resource as NucleusSpriteSheetProfile2D


func _on_profile_changed(_resource: Resource) -> void:
	var profile := _profile()
	if profile == null:
		_preview.texture = null
		_preview.visible = false
		_info.text = "Create or assign a SpriteSheetProfile2D resource."
		return
	_preview.texture = profile.texture
	_preview.visible = profile.texture != null
	_info.text = "Grid: %s | Clips: %d | Issues: %s" % [
		str(profile.grid_size()), profile.clips.size(),
		", ".join(profile.validate()),
	]


func _suggest_grid() -> void:
	var profile := _profile()
	if profile != null:
		_info.text = "Suggested square cells: %s" % str(
			NucleusSpriteSheetBuilder2D.suggest_grids(profile.texture)
		)


func _generate_rows() -> void:
	var profile := _profile()
	if profile != null:
		NucleusSpriteSheetBuilder2D.create_row_clips(profile)
		profile.emit_changed()
		_on_profile_changed(profile)


func _edit_profile() -> void:
	var profile := _profile()
	if profile != null:
		EditorInterface.edit_resource(profile)


func _save_frames() -> void:
	_begin_export(false)


func _save_scene() -> void:
	_begin_export(true)


func _begin_export(scene_export: bool) -> void:
	var profile := _profile()
	if profile == null or not profile.validate().is_empty():
		_info.text = "Invalid profile."
		return
	_export_scene = scene_export
	_save_dialog.clear_filters()
	_save_dialog.add_filter("*.tscn" if scene_export else "*.tres")
	_save_dialog.popup_centered_ratio()


func _on_save_selected(path: String) -> void:
	if FileAccess.file_exists(path):
		_info.text = "Refusing to overwrite existing file: " + path
		return
	var profile := _profile()
	if profile == null or not profile.validate().is_empty():
		return
	var resource: Resource
	if _export_scene:
		var root := NucleusSpriteSheetBuilder2D.build_scene(profile, true)
		if root == null:
			return
		var packed := PackedScene.new()
		var packed_error := packed.pack(root)
		root.free()
		if packed_error != OK:
			return
		resource = packed
	else:
		resource = NucleusSpriteSheetBuilder2D.build_frames(profile)
	var error := NucleusSpriteReimport2D.write_new_resource(resource, path)
	_info.text = "Saved" if error == OK else "Save failed: %d" % error
	if error == OK:
		EditorInterface.get_resource_filesystem().scan()


func _plan() -> Array[Dictionary]:
	return NucleusSpriteBatchImport2D.scan_plan(_batch_source.text, _batch_output.text)


func _preview_batch() -> void:
	_info.text = "Discovered %d sprite files; existing outputs will be protected." % _plan().size()


func _import_batch() -> void:
	_run_batch(false)


func _reimport_batch() -> void:
	_run_batch(true)


func _run_batch(reimport: bool) -> void:
	if _busy:
		return
	var plan := _plan()
	var cell_size := Vector2i(int(_cell_x.value), int(_cell_y.value))
	var created := 0
	var updated := 0
	var protected := 0
	var conflicts := 0
	var plan_total := plan.size()
	_begin_progress(plan_total, "Importing spritesheets")
	for entry: Dictionary in plan:
		_step_progress(str(entry["source"]))
		await get_tree().process_frame
		if _cancel_requested or not is_inside_tree():
			break
		_progress.value += 1
		if entry.has("error"):
			_report_failure(str(entry["error"]))
			protected += 1
			continue
		var source: String = entry["source"]
		var texture := ResourceLoader.load(source, "Texture2D") as Texture2D
		if texture == null:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var profile_path: String = entry["profile"]
		var profile: NucleusSpriteSheetProfile2D
		if FileAccess.file_exists(profile_path):
			profile = ResourceLoader.load(profile_path) as NucleusSpriteSheetProfile2D
		else:
			profile = NucleusSpriteBatchImport2D.create_profile(
				texture, cell_size,
			)
			if profile == null or not profile.validate().is_empty():
				_report_failure("Invalid profile, protected output or failed write; see editor log.")
				protected += 1
				continue
			if NucleusSpriteReimport2D.write_new_resource(profile, profile_path) != OK:
				_report_failure("Invalid profile, protected output or failed write; see editor log.")
				protected += 1
				continue
		if profile == null or not profile.validate().is_empty():
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var frames_path: String = entry["frames"]
		var library_path: String = entry["library"]
		var manifest_path := profile_path + ".sprite-studio.json"
		if not reimport and FileAccess.file_exists(frames_path):
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var frames: SpriteFrames
		var library: AnimationLibrary
		if FileAccess.file_exists(frames_path):
			frames = ResourceLoader.load(frames_path) as SpriteFrames
		if FileAccess.file_exists(library_path):
			library = ResourceLoader.load(library_path) as AnimationLibrary
		if (FileAccess.file_exists(frames_path) and frames == null) or (
			FileAccess.file_exists(library_path) and library == null
		):
			_report_failure("Existing output is unreadable or has the wrong resource type.")
			protected += 1
			continue
		var previous := NucleusSpriteReimport2D.read_manifest(manifest_path)
		# Unknown pre-existing output has no provenance: refuse updates.
		if (frames != null or library != null) and previous.is_empty():
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var result := NucleusSpriteReimport2D.sync(profile, frames, library, previous)
		if result.get("error", ERR_INVALID_DATA) != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var file_error := _save_generated(result["frames"], frames_path)
		if file_error != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		file_error = _save_generated(result["library"], library_path)
		if file_error != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		if NucleusSpriteReimport2D.write_manifest(manifest_path, result["manifest"]) != OK:
			_report_failure("Could not save provenance manifest; check output permissions.")
			protected += 1
			continue
		conflicts += (result["conflicts"] as Array).size()
		for conflict: String in result["conflicts"]:
			_results.add_text("  Preserved edited clip: " + conflict + "\n")
		if previous.is_empty():
			created += 1
		else:
			updated += 1
	_info.text = "Batch: %d new, %d updated, %d protected, %d conflicts" % [
		created, updated, protected, conflicts,
	]
	EditorInterface.get_resource_filesystem().scan()
	_complete_progress(created, updated, protected, conflicts)


func _save_generated(resource: Resource, path: String) -> Error:
	if resource == null or not path.begins_with("res://") or ".." in path:
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(path):
		return ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	return NucleusSpriteReimport2D.write_new_resource(resource, path)


func _build_sequence_workflow() -> void:
	var heading := Label.new()
	heading.text = "CHARACTER MODE  |  Numbered frames -> complete scenes"
	add_child(heading)
	_sequence_source = _line("res://assets/SPRITES", "Choose the folder containing frames")
	_sequence_output = _line("res://generated/characters", "Generated scenes and resources")
	var controls := HFlowContainer.new()
	add_child(controls)
	_add_button(controls, "Detect characters", _scan_sequences)
	_add_button(controls, "Generate selected", _generate_sequences)
	_add_button(controls, "Edit selected profile", _edit_sequence_profile)
	_add_button(controls, "Open selected scene", _open_sequence_scene)
	_add_button(controls, "Repair profile paths", _repair_sequence_paths)
	_sequence_preview = ItemList.new()
	_sequence_preview.select_mode = ItemList.SELECT_MULTI
	_sequence_preview.tooltip_text = (
		"All detected groups start selected. Ctrl/Shift to select a subset."
	)
	_sequence_preview.custom_minimum_size = Vector2(400, 110)
	add_child(_sequence_preview)


func _scan_sequences() -> void:
	if _busy:
		return
	_sequence_discovery.clear()
	_sequence_preview.clear()
	var canonical := NucleusSpritePathCase2D.canonical_path(_sequence_source.text)
	if canonical.is_empty():
		_info.text = "Source folder not found; check capitalization."
		return
	_sequence_source.text = canonical
	_sequence_discovery = NucleusSpriteSequenceImporter2D.scan_directory(canonical)
	_sequence_preview.clear()
	for entry: Dictionary in _sequence_discovery:
		var names := PackedStringArray()
		for clip: Dictionary in entry["clips"]:
			names.append("%s (%d)" % [clip["name"], (clip["paths"] as PackedStringArray).size()])
		_sequence_preview.add_item("%s: %s" % [entry["id"], ", ".join(names)])
		_sequence_preview.select(_sequence_preview.item_count - 1, false)
	_info.text = "%d characters detected. Review selection before Generate selected." % [
		_sequence_discovery.size(),
	]


func _generate_sequences() -> void:
	if _busy:
		return
	if not _sequence_output.text.begins_with("res://") or ".." in _sequence_output.text:
		_info.text = "Output must be a safe res:// folder."
		return
	if _sequence_discovery.is_empty():
		_scan_sequences()
	var selected: Array[Dictionary] = []
	for index: int in _sequence_preview.get_selected_items():
		selected.append(_sequence_discovery[index].duplicate(true))
	if selected.is_empty():
		_info.text = "Select at least one detected character."
		return
	var output := _sequence_output.text
	var source := _sequence_source.text
	var created := 0
	var updated := 0
	var protected := 0
	var conflicts := 0
	_begin_progress(selected.size(), "Generating character scenes")
	for descriptor: Dictionary in selected:
		_step_progress(str(descriptor["id"]))
		await get_tree().process_frame
		if _cancel_requested or not is_inside_tree():
			break
		_progress.value += 1
		var key := str(descriptor["id"])
		if key.is_empty() or ".." in key:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var stem := output.path_join(key)
		var profile_path := stem + ".profile.tres"
		var frames_path := stem + ".frames.tres"
		var library_path := stem + ".animations.tres"
		var scene_path := stem + ".tscn"
		var manifest_path := stem + ".sprite-studio.json"
		var profile: NucleusSpriteSequenceProfile2D
		if FileAccess.file_exists(profile_path):
			profile = ResourceLoader.load(profile_path) as NucleusSpriteSequenceProfile2D
		else:
			profile = NucleusSpriteSequenceImporter2D.create_profile(
				source, descriptor,
			)
			var create_error := NucleusSpriteReimport2D.write_new_resource(
				profile, profile_path,
			)
			if create_error != OK:
				_report_failure("Invalid profile, protected output or failed write; see editor log.")
				protected += 1
				continue
		if profile == null or not profile.validate().is_empty():
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var old_manifest := NucleusSpriteReimport2D.read_manifest(manifest_path)
		if (FileAccess.file_exists(frames_path) or FileAccess.file_exists(library_path)):
			if old_manifest.is_empty():
				_report_failure("Invalid profile, protected output or failed write; see editor log.")
				protected += 1
				continue
		var expected_frames := NucleusSpriteSequenceImporter2D.build_frames(profile)
		var expected_library := NucleusSpriteSequencePipeline2D.build_library(profile)
		if expected_frames == null or expected_library == null:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var frames: SpriteFrames
		var library: AnimationLibrary
		if FileAccess.file_exists(frames_path):
			frames = ResourceLoader.load(frames_path) as SpriteFrames
		if FileAccess.file_exists(library_path):
			library = ResourceLoader.load(library_path) as AnimationLibrary
		if (FileAccess.file_exists(frames_path) and frames == null) or (
			FileAccess.file_exists(library_path) and library == null
		):
			_report_failure("Existing output is unreadable or has the wrong resource type.")
			protected += 1
			continue
		var frame_merge := NucleusSpriteSequencePipeline2D.merge_frames(
			expected_frames, frames, old_manifest.get("frames", {}),
		)
		var library_merge := NucleusSpriteSequencePipeline2D.merge_library(
			expected_library, library, old_manifest.get("library", {}),
		)
		if frame_merge.get("error") != OK or library_merge.get("error") != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		conflicts += (frame_merge["conflicts"] as Array).size()
		conflicts += (library_merge["conflicts"] as Array).size()
		for conflict: String in frame_merge["conflicts"] + library_merge["conflicts"]:
			_results.add_text("  Preserved edited clip: " + conflict + "\n")
		if _save_generated(frame_merge["resource"], frames_path) != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		if _save_generated(library_merge["resource"], library_path) != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		var manifest: Dictionary = {
			"version": 1,
			"frames": frame_merge["managed"],
			"library": library_merge["managed"],
		}
		if NucleusSpriteReimport2D.write_manifest(manifest_path, manifest) != OK:
			_report_failure("Invalid profile, protected output or failed write; see editor log.")
			protected += 1
			continue
		if not FileAccess.file_exists(scene_path):
			var stored_frames := ResourceLoader.load(
				frames_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE,
			) as SpriteFrames
			var stored_library := ResourceLoader.load(
				library_path, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE,
			) as AnimationLibrary
			var root := NucleusSpriteSequencePipeline2D.create_scene(
				stored_frames, stored_library,
			)
			if root == null:
				_report_failure("Invalid profile, protected output or failed write; see editor log.")
				protected += 1
				continue
			var packed := PackedScene.new()
			var pack_error := packed.pack(root)
			root.free()
			if pack_error != OK or (
				NucleusSpriteReimport2D.write_new_resource(packed, scene_path) != OK
			):
				_report_failure("Invalid profile, protected output or failed write; see editor log.")
				protected += 1
				continue
			created += 1
		else:
			updated += 1
	_info.text = "%d new scenes, %d updated resources, %d protected, %d conflicts" % [
		created, updated, protected, conflicts,
	]
	EditorInterface.get_resource_filesystem().scan()
	_complete_progress(created, updated, protected, conflicts)


func _begin_progress(total: int, title_text: String) -> void:
	_cancel_requested = false
	_set_busy(true)
	_progress.max_value = maxi(total, 1)
	_progress.value = 0
	_status.text = "WORKING  |  " + title_text
	_status.add_theme_color_override("font_color", Color(0.95, 0.77, 0.29))
	_results.clear()


func _step_progress(label_text: String) -> void:
	_results.add_text("Processing  " + label_text + "\n")


func _complete_progress(created: int, updated: int, blocked: int, conflicts: int) -> void:
	_set_busy(false)
	var succeeded := created + updated
	_status.text = "%s  |  %d succeeded, %d skipped, %d conflicts" % [
		"CANCELLED" if _cancel_requested else "COMPLETE", succeeded, blocked, conflicts,
	]
	_status.add_theme_color_override(
		"font_color", Color(0.42, 0.85, 0.53) if blocked == 0 else Color(0.96, 0.7, 0.3),
	)
	_results.append_text(
		"\n[color=#6fd999]Created: %d | Updated: %d[/color]\n" % [created, updated]
	)
	if blocked > 0 or conflicts > 0:
		_results.append_text(
			"[color=#f3ba58]Skipped: %d | Conflicts: %d[/color]\n" % [blocked, conflicts]
	)


func _organize_layout() -> void:
	## Build the views from the existing widgets to keep all import behavior.
	## EditorDock controls positioning; TabContainer controls short-window usability.
	var widgets := get_children()
	# Widgets in original creation order (save dialog must remain at root).
	# 0 picker; 1 actions; 2 preview; 3 heading; 4-6 sheet controls;
	# 7-10 footer; 11 file dialog; 12-16 character controls.
	var tabs := TabContainer.new()
	tabs.name = "ImportWorkflows"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	add_child(tabs)
	move_child(tabs, 0)
	_create_tab(tabs, "Characters", [
		widgets[12], widgets[13], widgets[14], widgets[15], widgets[16],
	])
	_create_tab(tabs, "Spritesheets", [
		widgets[3], widgets[4], widgets[5], widgets[6],
	])
	_create_tab(tabs, "Single profile", [
		widgets[0], widgets[1], widgets[2],
	])
	tabs.current_tab = 0
	# The results stay visible while changing tabs and cannot push out actions.
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.custom_minimum_size = Vector2(0, 84)
	_results.size_flags_vertical = Control.SIZE_SHRINK_END
	_progress.custom_minimum_size.y = 14
	_preview.custom_minimum_size = Vector2(0, 100)
	_sequence_preview.custom_minimum_size = Vector2(0, 100)
	custom_minimum_size = Vector2(340, 280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _create_tab(tabs: TabContainer, title_text: String, widgets: Array) -> void:
	var scrolling := ScrollContainer.new()
	scrolling.name = title_text
	scrolling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrolling.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scrolling)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrolling.add_child(contents)
	for widget: Control in widgets:
		if widget is Label:
			(widget as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		widget.reparent(contents)
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _repair_sequence_paths() -> void:
	if _busy:
		return
	## Explicit action: update only profiles already generated for discovered characters.
	var root := _sequence_output.text
	if not root.begins_with("res://") or ".." in root:
		_info.text = "Select a valid generated characters folder."
		return
	if _sequence_discovery.is_empty():
		_scan_sequences()
	var repaired := 0
	var blocked := 0
	for descriptor: Dictionary in _sequence_discovery:
		var key := str(descriptor["id"])
		var path := root.path_join(key) + ".profile.tres"
		if not FileAccess.file_exists(path):
			continue
		var profile := ResourceLoader.load(path) as NucleusSpriteSequenceProfile2D
		if profile == null:
			blocked += 1
			continue
		var result := NucleusSpritePathCase2D.normalize_sequence_profile(profile)
		if result.get("error", ERR_INVALID_DATA) != OK:
			blocked += 1
			continue
		if int(result.get("changes", 0)) <= 0:
			continue
		if ResourceSaver.save(profile, path) == OK:
			repaired += 1
		else:
			blocked += 1
	_info.text = "Path repair: %d profiles saved, %d blocked." % [repaired, blocked]
	if repaired > 0:
		EditorInterface.get_resource_filesystem().scan()


func _set_busy(value: bool) -> void:
	_busy = value
	for action: Button in _actions:
		action.disabled = value
	for field: LineEdit in [_batch_source, _batch_output, _sequence_source, _sequence_output]:
		field.editable = not value
	_cell_x.editable = not value
	_cell_y.editable = not value
	_picker.editable = not value
	_cancel_button.disabled = not value


func _report_failure(reason: String) -> void:
	_results.add_text("  Skipped: " + reason + "\n")


func _selected_sequence_path(extension: String) -> String:
	var selected := _sequence_preview.get_selected_items()
	if selected.size() != 1:
		_info.text = "Select exactly one character for this action."
		return ""
	var key := str(_sequence_discovery[selected[0]]["id"])
	var path := _sequence_output.text.path_join(key) + extension
	if not path.begins_with("res://") or ".." in path or not FileAccess.file_exists(path):
		_info.text = "Generate this character first: " + path
		return ""
	return path


func _edit_sequence_profile() -> void:
	var path := _selected_sequence_path(".profile.tres")
	if not path.is_empty():
		EditorInterface.edit_resource(ResourceLoader.load(path))


func _open_sequence_scene() -> void:
	var path := _selected_sequence_path(".tscn")
	if not path.is_empty():
		EditorInterface.open_scene_from_path(path)


func _exit_tree() -> void:
	_cancel_requested = true
