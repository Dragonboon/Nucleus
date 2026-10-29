@tool
class_name NucleusWorldRegion
extends Node
## Stable world/level boundary reconciled against NucleusWorldStateStore.

@export var region_id: StringName:
	set(value):
		region_id = value
		update_configuration_warnings()

## Runtime-spawned persistent scenes are added here. Defaults to this region.
@export var runtime_parent: Node

@export_tool_button("Generate Region ID")
var generate_region_id_action = generate_region_id

var _service: Node
var _entities: Dictionary[String, NucleusWorldEntity] = {}
var _authored_baselines: Dictionary[String, Dictionary] = {}
var _active: bool = false


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	if _active:
		commit_all()

	_active = false
	_service = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if region_id == &"":
		warnings.append("Assign a stable region_id.")
		return warnings

	var known_ids: Dictionary[String, bool] = {}

	for node: Node in NucleusNodeUtils.descendants(self):
		if not node is NucleusWorldEntity:
			continue

		var entity := node as NucleusWorldEntity

		if entity.persistent_id.is_empty():
			continue

		if known_ids.has(entity.persistent_id):
			warnings.append(
				"Duplicate persistent_id '%s' in region '%s'."
				% [entity.persistent_id, region_id]
			)
			continue

		known_ids[entity.persistent_id] = true

	return warnings


func generate_region_id() -> void:
	region_id = StringName(NucleusUuid.v4())
	notify_property_list_changed()
	update_configuration_warnings()


func is_active() -> bool:
	return _active


func activate(service: Node) -> Error:
	if service == null or region_id == &"":
		return ERR_INVALID_PARAMETER

	if not service.has_method(&"get_store"):
		return ERR_INVALID_PARAMETER

	_service = service
	_active = true
	_rebuild_entity_registry()
	return reconcile()


func reconcile() -> Error:
	var store: NucleusWorldStateStore = _get_store()

	if store == null or region_id == &"":
		return ERR_UNCONFIGURED

	_rebuild_entity_registry()

	var suppress: Array[NucleusWorldEntity] = []

	for entity_id: String in _entities:
		var entity: NucleusWorldEntity = _entities[entity_id]
		var has_record: bool = store.has_entity(
			region_id,
			entity_id,
		)

		if not has_record:
			if entity.is_dynamic_runtime_entity():
				suppress.append(entity)
				continue

			if _authored_baselines.has(entity_id):
				entity.restore_state(
					_authored_baselines[entity_id]
				)

			continue

		var record: Dictionary = store.get_entity(
			region_id,
			entity_id,
		)

		if bool(record.get("removed", false)):
			suppress.append(entity)
			continue

		var state_value: Variant = record.get(
			"state",
			{},
		)

		if state_value is Dictionary:
			entity.restore_state(
				state_value as Dictionary
			)

	for entity: NucleusWorldEntity in suppress:
		_entities.erase(entity.persistent_id)
		entity._suppress_from_world_state()

	_restore_missing_dynamic_entities(store)
	return OK


func commit_all() -> void:
	var live_entities: Array[NucleusWorldEntity] = []

	for entity_id: String in _entities:
		var entity: NucleusWorldEntity = _entities[entity_id]

		if entity != null and is_instance_valid(entity):
			live_entities.append(entity)

	for entity: NucleusWorldEntity in live_entities:
		commit_entity(entity)


func commit_entity(entity: NucleusWorldEntity) -> Error:
	var store: NucleusWorldStateStore = _get_store()

	if (
		store == null
		or entity == null
		or entity.persistent_id.is_empty()
	):
		return ERR_UNCONFIGURED

	return store.write_entity(
		region_id,
		entity.persistent_id,
		entity.capture_state(),
		entity.get_dynamic_scene_path(),
		false,
	)


func mark_entity_removed(
	entity: NucleusWorldEntity,
) -> Error:
	var store: NucleusWorldStateStore = _get_store()

	if (
		store == null
		or entity == null
		or entity.persistent_id.is_empty()
	):
		return ERR_UNCONFIGURED

	_entities.erase(entity.persistent_id)

	return store.mark_removed(
		region_id,
		entity.persistent_id,
		entity.get_dynamic_scene_path(),
	)


## Instantiates a PackedScene and gives its NucleusWorldEntity a persistent UUID.
##
## The PackedScene must have a resource_path and contain one WorldEntity.
func spawn_persistent(
	scene: PackedScene,
	parent: Node = null,
	desired_id: String = "",
) -> Node:
	if scene == null or not _active:
		return null

	if scene.resource_path.is_empty():
		NucleusLog.error(
			"Persistent runtime scenes must have a resource_path.",
			&"WorldState",
		)
		return null

	var instance: Node = scene.instantiate()
	var entity: NucleusWorldEntity = _find_world_entity(instance)

	if entity == null:
		NucleusLog.error(
			"Persistent runtime scene '%s' has no NucleusWorldEntity."
			% scene.resource_path,
			&"WorldState",
		)
		instance.free()
		return null

	var entity_id: String = desired_id.strip_edges()

	if entity_id.is_empty():
		entity_id = NucleusUuid.v4()

	var store: NucleusWorldStateStore = _get_store()

	if (
		_entities.has(entity_id)
		or (
			store != null
			and store.has_entity(
				region_id,
				entity_id,
			)
		)
	):
		NucleusLog.error(
			"Persistent entity ID '%s' already exists in region '%s'."
			% [entity_id, region_id],
			&"WorldState",
		)
		instance.free()
		return null

	entity._configure_dynamic(
		entity_id,
		scene.resource_path,
	)

	var resolved_parent: Node = parent

	if resolved_parent == null:
		resolved_parent = (
			runtime_parent
			if runtime_parent != null
			else self
		)

	resolved_parent.add_child(instance)
	_register_entity(entity)
	commit_entity(entity)

	return instance


func _rebuild_entity_registry() -> void:
	_entities.clear()

	for node: Node in NucleusNodeUtils.descendants(self):
		if not node is NucleusWorldEntity:
			continue

		_register_entity(
			node as NucleusWorldEntity
		)


func _register_entity(
	entity: NucleusWorldEntity,
) -> bool:
	if entity == null or entity.persistent_id.is_empty():
		return false

	if _entities.has(entity.persistent_id):
		if _entities[entity.persistent_id] == entity:
			return true

		NucleusLog.error(
			"Duplicate persistent entity '%s' in region '%s'."
			% [entity.persistent_id, region_id],
			&"WorldState",
		)
		return false

	_entities[entity.persistent_id] = entity
	entity._bind_region(self)

	if (
		not entity.is_dynamic_runtime_entity()
		and not _authored_baselines.has(entity.persistent_id)
	):
		_authored_baselines[entity.persistent_id] = (
			entity.capture_state()
		)

	return true


func _restore_missing_dynamic_entities(
	store: NucleusWorldStateStore,
) -> void:
	var records: Dictionary = store.get_region(region_id)

	for entity_id: Variant in records:
		var id_string: String = str(entity_id)
		var record: Dictionary = records[entity_id]

		if not bool(record.get("dynamic", false)):
			continue

		if bool(record.get("removed", false)):
			continue

		if _entities.has(id_string):
			continue

		var scene_path: String = str(
			record.get(
				"scene_path",
				"",
			)
		)

		if scene_path.is_empty():
			continue

		var resource: Resource = ResourceLoader.load(
			scene_path,
			"PackedScene",
		)

		if not resource is PackedScene:
			NucleusLog.warning(
				"Could not restore persistent scene '%s'."
				% scene_path,
				&"WorldState",
			)
			continue

		var instance: Node = (
			resource as PackedScene
		).instantiate()
		var entity: NucleusWorldEntity = _find_world_entity(
			instance
		)

		if entity == null:
			NucleusLog.warning(
				"Restored scene '%s' has no NucleusWorldEntity."
				% scene_path,
				&"WorldState",
			)
			instance.free()
			continue

		entity._configure_dynamic(
			id_string,
			scene_path,
		)

		var resolved_parent: Node = (
			runtime_parent
			if runtime_parent != null
			else self
		)
		resolved_parent.add_child(instance)

		if not _register_entity(entity):
			instance.queue_free()
			continue

		var state_value: Variant = record.get(
			"state",
			{},
		)

		if state_value is Dictionary:
			entity.restore_state(
				state_value as Dictionary
			)


func _find_world_entity(
	root: Node,
) -> NucleusWorldEntity:
	if root is NucleusWorldEntity:
		return root as NucleusWorldEntity

	for node: Node in NucleusNodeUtils.descendants(root):
		if node is NucleusWorldEntity:
			return node as NucleusWorldEntity

	return null


func _get_store() -> NucleusWorldStateStore:
	if (
		_service == null
		or not is_instance_valid(_service)
		or not _service.has_method(&"get_store")
	):
		return null

	return (
		_service.call(&"get_store")
		as NucleusWorldStateStore
	)
