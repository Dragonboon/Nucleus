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


func _ready() -> void:
	_picker = EditorResourcePicker.new()
	_picker.base_type = "NucleusSpriteSheetProfile2D"
	_picker.resource_changed.connect(_on_profile_changed)
	add_child(_picker)
	var actions := HBoxContainer.new()
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
	section.text = "Batch: folder of spritesheets -> editable profiles and native resources"
	add_child(section)
	_batch_source = _line("res://assets/sprites", "Source folder, including nested folders")
	_batch_output = _line("res://generated/sprites", "Output folder")
	var size_controls := HBoxContainer.new()
	add_child(size_controls)
	_cell_x = _spin(size_controls, 32)
	_cell_y = _spin(size_controls, 32)
	_add_button(size_controls, "Preview batch", _preview_batch)
	_add_button(size_controls, "Import batch", _import_batch)
	_add_button(size_controls, "Reimport batch", _reimport_batch)
	_info = Label.new()
	add_child(_info)
	_save_dialog = EditorFileDialog.new()
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.file_selected.connect(_on_save_selected)
	add_child(_save_dialog)
	_on_profile_changed(null)


func _line(value: String, hint: String) -> LineEdit:
	var control := LineEdit.new()
	control.text = value
	control.placeholder_text = hint
	add_child(control)
	return control


func _spin(parent: Control, value: int) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = 1.0
	control.max_value = 1024.0
	control.value = value
	parent.add_child(control)
	return control


func _add_button(row: HBoxContainer, label_text: String, callback: Callable) -> void:
	var action := Button.new()
	action.text = label_text
	action.pressed.connect(callback)
	row.add_child(action)


func _profile() -> NucleusSpriteSheetProfile2D:
	return _picker.edited_resource as NucleusSpriteSheetProfile2D


func _on_profile_changed(_resource: Resource) -> void:
	var profile := _profile()
	if profile == null:
		_preview.texture = null
		_info.text = "Create or assign a SpriteSheetProfile2D resource."
		return
	_preview.texture = profile.texture
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
	var created := 0
	var updated := 0
	var protected := 0
	var conflicts := 0
	for entry: Dictionary in _plan():
		var source: String = entry["source"]
		var texture := ResourceLoader.load(source, "Texture2D") as Texture2D
		if texture == null:
			protected += 1
			continue
		var profile_path: String = entry["profile"]
		var profile: NucleusSpriteSheetProfile2D
		if FileAccess.file_exists(profile_path):
			profile = ResourceLoader.load(profile_path) as NucleusSpriteSheetProfile2D
		else:
			profile = NucleusSpriteBatchImport2D.create_profile(
				texture, Vector2i(int(_cell_x.value), int(_cell_y.value)),
			)
			if profile == null or not profile.validate().is_empty():
				protected += 1
				continue
			if NucleusSpriteReimport2D.write_new_resource(profile, profile_path) != OK:
				protected += 1
				continue
		if profile == null or not profile.validate().is_empty():
			protected += 1
			continue
		var frames_path: String = entry["frames"]
		var library_path: String = entry["library"]
		var manifest_path := profile_path + ".sprite-studio.json"
		if not reimport and FileAccess.file_exists(frames_path):
			protected += 1
			continue
		var frames: SpriteFrames
		var library: AnimationLibrary
		if FileAccess.file_exists(frames_path):
			frames = ResourceLoader.load(frames_path) as SpriteFrames
		if FileAccess.file_exists(library_path):
			library = ResourceLoader.load(library_path) as AnimationLibrary
		var previous := NucleusSpriteReimport2D.read_manifest(manifest_path)
		# Unknown pre-existing output has no provenance: refuse updates.
		if (frames != null or library != null) and previous.is_empty():
			protected += 1
			continue
		var result := NucleusSpriteReimport2D.sync(profile, frames, library, previous)
		if result.get("error", ERR_INVALID_DATA) != OK:
			protected += 1
			continue
		var file_error := _save_generated(result["frames"], frames_path)
		if file_error != OK:
			protected += 1
			continue
		file_error = _save_generated(result["library"], library_path)
		if file_error != OK:
			protected += 1
			continue
		NucleusSpriteReimport2D.write_manifest(manifest_path, result["manifest"])
		conflicts += (result["conflicts"] as Array).size()
		if previous.is_empty():
			created += 1
		else:
			updated += 1
	_info.text = "Batch: %d new, %d updated, %d protected, %d conflicts" % [
		created, updated, protected, conflicts,
	]
	EditorInterface.get_resource_filesystem().scan()


func _save_generated(resource: Resource, path: String) -> Error:
	if FileAccess.file_exists(path):
		return ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	return NucleusSpriteReimport2D.write_new_resource(resource, path)
