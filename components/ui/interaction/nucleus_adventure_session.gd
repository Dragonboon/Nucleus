extends Node
class_name NucleusAdventureSession
## Scene-owned semantic adventure state. Images and UI are not serialized.

signal message_requested(key: StringName)
signal action_rejected(reason: StringName)
signal state_changed
signal page_changed(id: StringName)

@export var screen: NucleusImageScreen
@export var inventory: NucleusInventory
@export var shader_stack: NucleusScreenShaderStack
@export var save_session: NucleusSaveSession
@export var participant_id: StringName = &"adventure"
@export var pages: Array[NucleusAdventurePage] = []
@export var combinations: Array[NucleusScreenCombination] = []

var current_page: StringName
var flags: Dictionary = {}
var visited: Dictionary = {}
var completed: Dictionary = {}
var _page_index: Dictionary = {}
var _busy := false


func _ready() -> void:
	for page in pages:
		if page != null and page.is_valid_page() and not _page_index.has(page.id):
			_page_index[page.id] = page
	if screen != null:
		screen.hotspot_activated.connect(_on_hotspot)
	if save_session != null and participant_id != &"":
		save_session.register_participant(participant_id, capture_state, restore_state)
	if current_page == &"" and not pages.is_empty() and pages[0] != null:
		change_page(pages[0].id)


func _exit_tree() -> void:
	if save_session != null and is_instance_valid(save_session):
		save_session.unregister_participant(participant_id)


func change_page(id: StringName) -> Error:
	if not _page_index.has(id) or screen == null:
		return ERR_DOES_NOT_EXIST
	var page: NucleusAdventurePage = _page_index[id]
	var page_image: Texture2D = page.image
	if shader_stack != null:
		var preflight := shader_stack.validate_configuration(
			page.image, page.effect_passes)
		if preflight != OK:
			return preflight
		if shader_stack.configure(page.image, page.effect_passes) != OK:
			return ERR_CANT_CREATE
		page_image = shader_stack.output_texture()
	var result := screen.set_screen(page.id, page_image, page.hotspots)
	if result != OK:
		return result
	current_page = id
	visited[String(id)] = true
	page_changed.emit(id)
	state_changed.emit()
	return OK


func has_flag(id: StringName) -> bool:
	return bool(flags.get(String(id), false))


func set_flag(id: StringName, value: bool = true) -> void:
	if id == &"":
		return
	flags[String(id)] = value
	state_changed.emit()


func activate_hotspot(id: StringName) -> Error:
	if _busy or screen == null or current_page == &"":
		return ERR_BUSY
	var selected: NucleusScreenHotspot
	for entry in screen.hotspots:
		if entry != null and entry.id == id and entry.enabled:
			selected = entry
			break
	if selected == null:
		return ERR_DOES_NOT_EXIST
	if selected.action == null:
		if selected.destination != &"":
			return change_page(selected.destination)
		return OK
	var action := selected.action
	var completed_key := "%s/%s" % [current_page, id]
	if action.one_shot and completed.has(completed_key):
		return ERR_UNAVAILABLE
	for required in action.required_flags:
		if not has_flag(required):
			action_rejected.emit(&"missing_flag")
			return ERR_UNAVAILABLE
	for forbidden in action.forbidden_flags:
		if has_flag(forbidden):
			action_rejected.emit(&"forbidden_flag")
			return ERR_UNAVAILABLE
	if action.required_item != &"" and (
		inventory == null or not inventory.has_item(action.required_item)
	):
		action_rejected.emit(&"missing_item")
		return ERR_UNAVAILABLE
	if action.give_item != &"" and (
		inventory == null or not inventory.can_add_item(
			inventory.get_definition(action.give_item))
	):
		return ERR_UNAVAILABLE
	var next_id := action.next_screen
	if next_id != &"" and not _page_index.has(next_id):
		return ERR_DOES_NOT_EXIST
	_busy = true
	if action.consume_item and inventory.remove_item(action.required_item) != 1:
		_busy = false
		return ERR_UNAVAILABLE
	if action.give_item != &"":
		inventory.add_item_by_id(action.give_item)
	for flag in action.set_flags:
		flags[String(flag)] = true
	for flag in action.clear_flags:
		flags[String(flag)] = false
	if action.one_shot:
		completed[completed_key] = true
	_busy = false
	if action.message_key != &"":
		message_requested.emit(action.message_key)
	if next_id != &"":
		change_page(next_id)
	else:
		state_changed.emit()
	return OK


func combine_items(first: StringName, second: StringName) -> Error:
	if inventory == null or first == &"" or second == &"":
		return ERR_UNCONFIGURED
	for recipe in combinations:
		if recipe == null or not recipe.is_valid_recipe() or not recipe.matches(first, second):
			continue
		var required_amount := 2 if first == second else 1
		if not inventory.has_item(first, required_amount) or not inventory.has_item(second):
			return ERR_UNAVAILABLE
		var output := inventory.get_definition(recipe.result_item)
		if output == null:
			return ERR_DOES_NOT_EXIST
		if not inventory.can_add_item(output):
			return ERR_UNAVAILABLE
		if recipe.consume_inputs:
			inventory.remove_item(first, required_amount)
			if first != second:
				inventory.remove_item(second)
		inventory.add_item(output)
		if recipe.set_flag != &"":
			set_flag(recipe.set_flag)
		state_changed.emit()
		return OK
	return ERR_DOES_NOT_EXIST


func capture_state() -> Dictionary:
	return {
		"version": 1,
		"page": String(current_page),
		"flags": flags.duplicate(true),
		"visited": visited.duplicate(true),
		"completed": completed.duplicate(true),
	}


func restore_state(snapshot: Dictionary) -> Error:
	if snapshot.get("version", -1) != 1:
		return ERR_FILE_UNRECOGNIZED
	for key in ["flags", "visited", "completed"]:
		if not snapshot.get(key) is Dictionary:
			return ERR_INVALID_DATA
	var destination := StringName(str(snapshot.get("page", "")))
	if not _page_index.has(destination):
		return ERR_DOES_NOT_EXIST
	if change_page(destination) != OK:
		return ERR_CANT_CREATE
	flags = (snapshot["flags"] as Dictionary).duplicate(true)
	visited = (snapshot["visited"] as Dictionary).duplicate(true)
	completed = (snapshot["completed"] as Dictionary).duplicate(true)
	state_changed.emit()
	return OK


func _on_hotspot(id: StringName, _destination: StringName) -> void:
	activate_hotspot(id)
