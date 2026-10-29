@tool
class_name NucleusWorldEntity
extends Node
## Stable persistent identity and explicit state adapters for one world object.
##
## This component should normally be a child of the Node it persists.

signal persistent_removal_requested(entity_id: String)

@export var persistent_id: String = "":
	set(value):
		persistent_id = value.strip_edges()
		update_configuration_warnings()

## Enable on runtime-spawn templates whose ID is assigned by WorldRegion.
@export var runtime_identity_only: bool = false:
	set(value):
		runtime_identity_only = value
		update_configuration_warnings()

@export var target: Node:
	set(value):
		target = value
		update_configuration_warnings()

@export_tool_button("Generate Persistent ID")
var generate_id_action = generate_persistent_id

var _region: Node
var _dynamic_scene_path: String = ""
var _removed_persistently: bool = false
var _suppressing_from_state: bool = false


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	if (
		_region == null
		or _removed_persistently
		or _suppressing_from_state
	):
		return

	if _region.has_method(&"commit_entity"):
		_region.call(
			&"commit_entity",
			self,
		)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if persistent_id.is_empty() and not runtime_identity_only:
		warnings.append(
			"Generate/assign a stable persistent_id before using this authored object."
		)

	var known_adapter_ids: Dictionary[StringName, bool] = {}

	for adapter: NucleusWorldStateAdapter in get_state_adapters():
		if adapter.adapter_id == &"":
			continue

		if known_adapter_ids.has(adapter.adapter_id):
			warnings.append(
				"Duplicate state adapter_id '%s'." % adapter.adapter_id
			)
			continue

		known_adapter_ids[adapter.adapter_id] = true

	return warnings


func generate_persistent_id() -> void:
	persistent_id = NucleusUuid.v4()
	notify_property_list_changed()
	update_configuration_warnings()


func get_persistent_target() -> Node:
	if target != null:
		return target

	return get_parent()


func get_state_adapters() -> Array[NucleusWorldStateAdapter]:
	var adapters: Array[NucleusWorldStateAdapter] = []

	for node: Node in NucleusNodeUtils.descendants(self):
		if node is NucleusWorldStateAdapter:
			adapters.append(
				node as NucleusWorldStateAdapter
			)

	return adapters


func capture_state() -> Dictionary:
	var state: Dictionary = {}

	for adapter: NucleusWorldStateAdapter in get_state_adapters():
		if adapter.adapter_id == &"":
			continue

		state[String(adapter.adapter_id)] = (
			adapter.capture_state()
		)

	return state


func restore_state(state: Dictionary) -> void:
	for adapter: NucleusWorldStateAdapter in get_state_adapters():
		if adapter.adapter_id == &"":
			continue

		var key: String = String(adapter.adapter_id)

		if state.has(key):
			adapter.restore_state(state[key])


func commit_state() -> Error:
	if _region == null or not _region.has_method(&"commit_entity"):
		return ERR_UNCONFIGURED

	return int(
		_region.call(
			&"commit_entity",
			self,
		)
	) as Error


func remove_persistently() -> Error:
	if (
		_region == null
		or not _region.has_method(&"mark_entity_removed")
	):
		return ERR_UNCONFIGURED

	var error: Error = int(
		_region.call(
			&"mark_entity_removed",
			self,
		)
	) as Error

	if error != OK:
		return error

	_removed_persistently = true
	persistent_removal_requested.emit(persistent_id)

	var resolved_target: Node = get_persistent_target()

	if resolved_target != null:
		resolved_target.queue_free()

	return OK


func is_dynamic_runtime_entity() -> bool:
	return not _dynamic_scene_path.is_empty()


func get_dynamic_scene_path() -> String:
	return _dynamic_scene_path


func _bind_region(region: Node) -> void:
	_region = region


func _configure_dynamic(
	entity_id: String,
	scene_path: String,
) -> void:
	persistent_id = entity_id
	_dynamic_scene_path = scene_path
	runtime_identity_only = true
	_removed_persistently = false
	_suppressing_from_state = false


func _suppress_from_world_state() -> void:
	_suppressing_from_state = true

	var resolved_target: Node = get_persistent_target()

	if resolved_target != null:
		resolved_target.queue_free()
