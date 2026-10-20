@tool
extends VBoxContainer
## Opt-in editor surface; resources remain authored and source files untouched.

var _picker: EditorResourcePicker
var _preview: TextureRect
var _info: Label
var _save_dialog: EditorFileDialog
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

	_info = Label.new()
	add_child(_info)

	_save_dialog = EditorFileDialog.new()
	_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.file_selected.connect(_on_save_selected)
	add_child(_save_dialog)
	_on_profile_changed(null)


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
	if profile == null:
		return
	var sizes := NucleusSpriteSheetBuilder2D.suggest_grids(profile.texture)
	_info.text = "Possible square cell sizes: %s. Select one in the profile." % str(sizes)


func _generate_rows() -> void:
	var profile := _profile()
	if profile == null:
		return
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
		_info.text = "Profile is invalid; inspect the report before exporting."
		return
	_export_scene = scene_export
	_save_dialog.clear_filters()
	_save_dialog.add_filter("*.tscn" if scene_export else "*.tres")
	_save_dialog.popup_centered_ratio()


func _on_save_selected(path: String) -> void:
	if FileAccess.file_exists(path):
		_info.text = "Refusing to overwrite an existing file: " + path
		return
	var profile := _profile()
	if profile == null or not profile.validate().is_empty():
		return
	var output: Resource
	if _export_scene:
		var root := NucleusSpriteSheetBuilder2D.build_scene(profile, true)
		if root == null:
			return
		var packed := PackedScene.new()
		if packed.pack(root) != OK:
			root.free()
			return
		root.free()
		output = packed
	else:
		output = NucleusSpriteSheetBuilder2D.build_frames(profile)
	if output == null:
		return
	var error := ResourceSaver.save(output, path)
	_info.text = (
		"Saved: " + path if error == OK else "Save failed, code: %d" % error
	)
	if error == OK:
		EditorInterface.get_resource_filesystem().scan()
