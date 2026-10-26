extends Node
class_name NucleusAdventureSession
## Scene-owned semantic adventure state. Images and UI are not serialized.

signal message_requested(key: StringName)
signal action_rejected(reason: StringName)
signal state_changed
signal page_changed(id: StringName)

@export var screen: NucleusImageScreen
## Optional adapter: avoids a compile-time dependency on modules/inventory.
@export var inventory: Node
@export var shader_stack: NucleusScreenShaderStack
@export var save_session: NucleusSaveSession
@export var participant_id: StringName = &"adventure"
@export var pages: Array[NucleusAdventurePage] = []
@export var initial_page: StringName
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
	if current_page == &"":
		var first_page := initial_page
		if first_page == &"" and not _page_index.is_empty():
			first_page = _page_index.keys()[0]
		if first_page != &"":
			change_page(first_page)


func _exit_tree() -> void:
	if save_session != null and is_instance_valid(save_session):
		save_session.unregister_participant(participant_id)


func change_page(id: StringName) -> Error:
	if screen == null:
		return ERR_UNCONFIGURED
	if not _page_index.has(id):
		return ERR_DOES_NOT_EXIST
	var page: NucleusAdventurePage = _page_index[id]
	if not page.is_valid_page():
		return ERR_INVALID_DATA
	var page_image: Texture2D = page.image
	if shader_stack != null:
		var preflight := shader_stack.validate_configuration(
			page.image, page.effect_passes)
		if preflight != OK:
			return preflight
		if shader_stack.configure(page.image, page.effect_passes) != OK:
			return ERR_CANT_CREATE
		# Backbuffer effects are drawn over the screen, not baked into its texture.
		if shader_stack.backend == NucleusScreenShaderStack.Backend.VIEWPORT_CHAIN:
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
	if selected == null or not selected.is_valid_hotspot():
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
		not _inventory_ready() or not bool(inventory.call(
			"has_item", action.required_item))
	):
		action_rejected.emit(&"missing_item")
		return ERR_UNAVAILABLE
	if action.give_item != &"" and (
		not _inventory_ready()
		or not _can_add_after_removal(
			action.give_item, action.required_item if action.consume_item else &"")
	):
		return ERR_UNAVAILABLE
	var next_id := action.next_screen
	if next_id != &"" and not _page_index.has(next_id):
		return ERR_DOES_NOT_EXIST
	if next_id != &"" and shader_stack != null:
		var target_page: NucleusAdventurePage = _page_index[next_id]
		var validation := shader_stack.validate_configuration(
			target_page.image, target_page.effect_passes)
		if validation != OK:
			return validation
	_busy = true
	if action.consume_item and int(inventory.call(
		"remove_item", action.required_item)) != 1:
		_busy = false
		return ERR_UNAVAILABLE
	if action.give_item != "":
		var accepted := int(inventory.call("add_item_by_id", action.give_item))
		if accepted != 1:
			_busy = false
			return ERR_UNAVAILABLE
	for flag in action.set_flags:
		flags[String(flag)] = true
	for flag in action.clear_flags:
		flags[String(flag)] = false
	if action.one_shot:
		completed[completed_key] = true
	var result := OK
	if next_id != &"":
		result = change_page(next_id)
	else:
		state_changed.emit()
	_busy = false
	if result == OK and action.message_key != &"":
		message_requested.emit(action.message_key)
	return result


func combine_items(first: StringName, second: StringName) -> Error:
	if not _inventory_ready() or first == &"" or second == &"":
		return ERR_UNCONFIGURED
	if _busy:
		return ERR_BUSY
	for recipe in combinations:
		if recipe == null or not recipe.is_valid_recipe() or not recipe.matches(first, second):
			continue
		var amount := 2 if first == second else 1
		if not bool(inventory.call("has_item", first, amount)):
			return ERR_UNAVAILABLE
		if not bool(inventory.call("has_item", second)):
			return ERR_UNAVAILABLE
		var remove_first := first if recipe.consume_inputs else &""
		var remove_second := second if recipe.consume_inputs else &""
		if not _can_add_after_removal(recipe.result_item, remove_first, remove_second):
			return ERR_UNAVAILABLE
		_busy = true
		if recipe.consume_inputs:
			if int(inventory.call("remove_item", first, amount)) != amount:
				_busy = false
				return ERR_UNAVAILABLE
			if first != second:
				if int(inventory.call("remove_item", second)) != 1:
					_busy = false
					return ERR_UNAVAILABLE
		if int(inventory.call("add_item_by_id", recipe.result_item)) != 1:
			_busy = false
			return ERR_UNAVAILABLE
		if recipe.set_flag != &"":
			flags[String(recipe.set_flag)] = true
		_busy = false
		state_changed.emit()
		return OK
	return ERR_DOES_NOT_EXIST


## Only the established Inventory API is used. This adapter remains optional.
func _inventory_ready() -> bool:
	if inventory == null or not is_instance_valid(inventory):
		return false
	for method in [
		"has_item", "get_definition", "can_add_item", "add_item_by_id",
		"remove_item", "capture_state", "restore_state"
	]:
		if not inventory.has_method(method):
			return false
	return true


## Simulate consumption before checking capacity; never mutate live inventory on denial.
func _can_add_after_removal(
	item_id: StringName,
	first_removed: StringName = &"",
	second_removed: StringName = &"",
) -> bool:
	if not _inventory_ready():
		return false
	var item: Variant = inventory.call("get_definition", item_id)
	if item == null:
		return false
	if first_removed == &"" and second_removed == &"":
		return bool(inventory.call("can_add_item", item))
	var sample := inventory.duplicate(Node.DUPLICATE_SCRIPTS)
	if sample == null or not sample.has_method("restore_state"):
		if sample != null:
			sample.free()
		return false
	sample.call("restore_state", inventory.call("capture_state"))
	var amount := 2 if first_removed != &"" and first_removed == second_removed else 1
	if first_removed != &"":
		sample.call("remove_item", first_removed, amount)
	if second_removed != &"" and first_removed != second_removed:
		sample.call("remove_item", second_removed)
	var allowed := bool(sample.call("can_add_item", item))
	sample.free()
	return allowed

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
	var restored_flags := (snapshot["flags"] as Dictionary).duplicate(true)
	var restored_visited := (snapshot["visited"] as Dictionary).duplicate(true)
	var restored_completed := (snapshot["completed"] as Dictionary).duplicate(true)
	for data in [restored_flags, restored_visited, restored_completed]:
		for key in data:
			if not key is String or not data[key] is bool:
				return ERR_INVALID_DATA
	var old_flags := flags
	var old_visited := visited
	var old_completed := completed
	flags = restored_flags
	visited = restored_visited
	completed = restored_completed
	var restore_error := change_page(destination)
	if restore_error != OK:
		flags = old_flags
		visited = old_visited
		completed = old_completed
	return restore_error


func _on_hotspot(id: StringName, _destination: StringName) -> void:
	activate_hotspot(id)
