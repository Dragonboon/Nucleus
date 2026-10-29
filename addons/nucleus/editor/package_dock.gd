@tool
extends VBoxContainer
## Unified Nucleus workspace, informed by the modular-addon prototype.

const Inventory = preload("res://addons/nucleus/editor/management/addon_inventory.gd")
const Manager = preload("res://addons/nucleus/editor/management/addon_manager.gd")
const Updater = preload("res://addons/nucleus/editor/management/addon_updater.gd")

var _manager: RefCounted = Manager.new()
var _updater: Node
var _tabs: TabContainer
var _message: Label
var _preview: TextEdit
var _profile: OptionButton
var _apply_profile: Button
var _check: Button
var _download: Button
var _apply_update: Button
var _restore: Button
var _cancel: Button
var _confirm: ConfirmationDialog
var _action: String = ""
var _staged: Dictionary = {}
var _restart_required: bool = false
var _profile_valid: bool = false
var _update_available: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(290, 300)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.name = "Manage"
	_tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var title := Label.new()
	title.text = "Nucleus  " + FileAccess.get_file_as_string(Inventory.ROOT + "VERSION").strip_edges()
	content.add_child(title)
	var description := Label.new()
	description.text = "Select the components your project needs. "\
		+ "Core and editor tools stay installed."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	_profile = OptionButton.new()
	_profile.add_item("Full: 2D + 3D")
	_profile.add_item("2D only + shared components")
	_profile.add_item("3D only + shared components")
	var current: String = _manager.state().get("profile", "full")
	_profile.select(maxi(0, Inventory.PROFILES.find(current)))
	_profile.item_selected.connect(_preview_profile.unbind(1))
	content.add_child(_profile)
	_button(content, "Preview profile", _preview_profile)
	_apply_profile = _button(content, "Apply profile...", _confirm_action.bind("profile"))
	_check = _button(content, "Check stable main", _check_main)
	_download = _button(content, "Download and verify update", _download_update)
	_download.disabled = true
	_apply_update = _button(content, "Apply prepared update...", _confirm_action.bind("update"))
	_apply_update.disabled = true
	_restore = _button(content, "Restore previous installation...", _confirm_action.bind("restore"))
	_restore.disabled = _manager.state().get("backup", "").is_empty()
	_cancel = _button(content, "Cancel download", _cancel_request)
	_cancel.disabled = true
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_message)
	_preview = TextEdit.new()
	_preview.editable = false
	_preview.custom_minimum_size = Vector2(0, 210)
	_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_preview)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Apply Nucleus changes"
	_confirm.confirmed.connect(_apply_confirmed)
	add_child(_confirm)
	_updater = Updater.new()
	add_child(_updater)
	_updater.status_changed.connect(_set_message)
	_updater.checked.connect(_checked)
	_updater.prepared.connect(_prepared)
	_updater.finished.connect(_refresh_busy)
	_preview_profile()


func add_localization(panel: Control) -> void:
	panel.name = "Localization"
	# The catalog panel owns its existing native layout and async gettext jobs.
	var scroll := ScrollContainer.new()
	scroll.name = "Localization"
	_tabs.add_child(scroll)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 640
	scroll.add_child(panel)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _selected_profile() -> String:
	return Inventory.PROFILES[_profile.selected]


func _preview_profile() -> void:
	if _message == null or _restart_required:
		return
	_show_plan(_manager.preview(_selected_profile()))


func _show_plan(plan: Dictionary) -> void:
	var lines: PackedStringArray = []
	if plan.has("keep_count"):
		lines.append("Profile: %s | Keep %d files | Remove %d files" % [
			plan.profile, plan.keep_count, plan.remove.size()])
		lines.append("Core, shared dependencies, public paths and retained UIDs are preserved.")
		lines.append("Review dynamic loads assembled from strings in your own scripts.")
		for path: String in plan.remove:
			lines.append("REMOVE  " + path)
	for blocker: String in plan.get("blockers", []):
		lines.append("IN USE  " + blocker)
	_preview.text = "\n".join(lines)
	_profile_valid = plan.get("error", "").is_empty()
	_apply_profile.disabled = not _profile_valid
	_set_message(plan.get("error", "") if not plan.get("error", "").is_empty() else (
		"Preview ready. Applying creates a backup; reopen the editor afterwards."))


func _check_main() -> void:
	_staged = {}
	_download.disabled = true
	_apply_update.disabled = true
	_updater.check_main()
	_refresh_busy()


func _checked(result: Dictionary) -> void:
	if result.has("error"):
		_download.disabled = true
		return
	var manifest: Dictionary = result.manifest
	_update_available = manifest != Inventory.read_manifest()
	var installed: Dictionary = _manager.state()
	var source: String = installed.get("source", "")
	var needs_source: bool = installed.get("profile", "full") != "full" and (
		source.is_empty() or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(source)))
	_update_available = _update_available or needs_source
	_download.disabled = not _update_available
	if not _update_available:
		_set_message("Nucleus already matches the latest successful main commit.")
		return
	_preview.text = "Stable main: %s\nVersion: %s\nFiles: %d\n" % [
		result.commit, manifest.version, manifest.files.size()]
	_preview.text += "Successful main CI confirmed. Downloads stay outside the active addon."
	_set_message("Stable main is ready to download and verify.")


func _download_update() -> void:
	_updater.download()
	_refresh_busy()


func _prepared(result: Dictionary) -> void:
	if not result.get("error", "").is_empty():
		_set_message(result.error)
		return
	_staged = result
	var plan: Dictionary = _manager.preview(_selected_profile(), _staged.source)
	_show_plan(plan)
	_apply_update.disabled = not plan.error.is_empty()
	if plan.error.is_empty():
		_set_message("Update verified and staged. Apply to keep the selected dimensional profile.")


func _confirm_action(action: String) -> void:
	if EditorInterface.is_playing_scene():
		_set_message("Stop the running game before changing addon files.")
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		_set_message("Wait for Godot's filesystem scan to finish.")
		return
	_action = action
	_confirm.dialog_text = "Apply %s to addons/nucleus only?\n" % action
	_confirm.dialog_text += "A rollback copy will be saved in .nucleus/backups/.\n"
	_confirm.dialog_text += "Save your work and reopen the editor after applying."
	_confirm.popup_centered(Vector2i(480, 180))


func _apply_confirmed() -> void:
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if EditorInterface.is_playing_scene() or filesystem.is_scanning() or filesystem.is_importing():
		_set_message("Stop playback and wait for imports before applying.")
		return
	var result: Dictionary
	match _action:
		"profile":
			result = _manager.apply_profile(_selected_profile())
		"update":
			if _staged.is_empty():
				return
			result = _manager.install(_staged.source, _selected_profile(), _updater.target_commit)
		"restore":
			result = _manager.restore_backup()
		_:
			return
	if not result.get("error", "").is_empty():
		_set_message(result.error)
		return
	_restart_required = true
	_set_message("Applied. Reopen the editor before further changes. Backup: " + result.backup)
	_refresh_busy()
	EditorInterface.get_resource_filesystem().call_deferred("scan")


func _cancel_request() -> void:
	_updater.cancel()
	_set_message("Download cancelled. Installed files are unchanged.")


func _refresh_busy() -> void:
	var blocked: bool = _restart_required or _updater.busy
	_profile.disabled = blocked
	_check.disabled = blocked
	_apply_profile.disabled = blocked or not _profile_valid
	_restore.disabled = blocked or _manager.state().get("backup", "").is_empty()
	_cancel.disabled = not _updater.busy
	if blocked:
		_download.disabled = true
		_apply_update.disabled = true
	elif _update_available:
		_download.disabled = false


func _set_message(message: String) -> void:
	_message.text = message
