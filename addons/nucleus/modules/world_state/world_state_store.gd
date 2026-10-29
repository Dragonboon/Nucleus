class_name NucleusWorldStateStore
extends RefCounted
## Runtime world-state database keyed by stable region and entity identities.
##
## Records contain only save data. Live Nodes never belong in this store.

const SCHEMA_VERSION: int = 1

var _regions: Dictionary = {}


func clear() -> void:
	_regions.clear()


func has_entity(
	region_id: StringName,
	entity_id: String,
) -> bool:
	if region_id == &"" or entity_id.is_empty():
		return false

	var region_key: String = String(region_id)

	if not _regions.has(region_key):
		return false

	var region: Dictionary = _regions[region_key]
	return region.has(entity_id)


func get_entity(
	region_id: StringName,
	entity_id: String,
) -> Dictionary:
	if not has_entity(region_id, entity_id):
		return {}

	var region: Dictionary = _regions[String(region_id)]
	var record: Dictionary = region[entity_id]
	return record.duplicate(true)


func get_region(
	region_id: StringName,
) -> Dictionary:
	var region_key: String = String(region_id)

	if region_id == &"" or not _regions.has(region_key):
		return {}

	return (_regions[region_key] as Dictionary).duplicate(true)


func write_entity(
	region_id: StringName,
	entity_id: String,
	state: Dictionary,
	dynamic_scene_path: String = "",
	removed: bool = false,
) -> Error:
	if region_id == &"" or entity_id.is_empty():
		return ERR_INVALID_PARAMETER

	var region_key: String = String(region_id)
	var region: Dictionary = _regions.get(
		region_key,
		{},
	)

	region[entity_id] = {
		"removed": removed,
		"dynamic": not dynamic_scene_path.is_empty(),
		"scene_path": dynamic_scene_path,
		"state": state.duplicate(true),
	}
	_regions[region_key] = region

	return OK


func mark_removed(
	region_id: StringName,
	entity_id: String,
	dynamic_scene_path: String = "",
) -> Error:
	if region_id == &"" or entity_id.is_empty():
		return ERR_INVALID_PARAMETER

	var record: Dictionary = get_entity(
		region_id,
		entity_id,
	)
	var state: Dictionary = {}

	if record.get("state", {}) is Dictionary:
		state = (record["state"] as Dictionary).duplicate(true)

	var scene_path: String = dynamic_scene_path

	if scene_path.is_empty():
		scene_path = str(record.get("scene_path", ""))

	return write_entity(
		region_id,
		entity_id,
		state,
		scene_path,
		true,
	)


func erase_entity(
	region_id: StringName,
	entity_id: String,
) -> bool:
	if not has_entity(region_id, entity_id):
		return false

	var region_key: String = String(region_id)
	var region: Dictionary = _regions[region_key]
	region.erase(entity_id)

	if region.is_empty():
		_regions.erase(region_key)
	else:
		_regions[region_key] = region

	return true


func capture_state() -> Dictionary:
	var regions: Dictionary = {}
	var region_ids: Array = _regions.keys()
	region_ids.sort()

	for region_id: Variant in region_ids:
		var source_region: Dictionary = _regions[region_id]
		var entity_ids: Array = source_region.keys()
		var target_region: Dictionary = {}
		entity_ids.sort()

		for entity_id: Variant in entity_ids:
			target_region[str(entity_id)] = (
				source_region[entity_id] as Dictionary
			).duplicate(true)

		regions[str(region_id)] = target_region

	return {
		"schema_version": SCHEMA_VERSION,
		"regions": regions,
	}


func restore_state(data: Dictionary) -> Error:
	var schema_version: int = int(
		data.get(
			"schema_version",
			SCHEMA_VERSION,
		)
	)

	if schema_version != SCHEMA_VERSION:
		return ERR_FILE_UNRECOGNIZED

	var regions_value: Variant = data.get(
		"regions",
		{},
	)

	if not regions_value is Dictionary:
		return ERR_INVALID_DATA

	var restored_regions: Dictionary = {}
	var source_regions: Dictionary = regions_value

	for region_key: Variant in source_regions:
		if not source_regions[region_key] is Dictionary:
			continue

		var source_region: Dictionary = source_regions[region_key]
		var restored_region: Dictionary = {}

		for entity_key: Variant in source_region:
			if not source_region[entity_key] is Dictionary:
				continue

			restored_region[str(entity_key)] = (
				source_region[entity_key] as Dictionary
			).duplicate(true)

		if not restored_region.is_empty():
			restored_regions[str(region_key)] = restored_region

	_regions = restored_regions
	return OK
