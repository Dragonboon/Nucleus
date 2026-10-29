@tool
class_name NucleusPackedScenePreflight
extends RefCounted
## Inspect an authored PackedScene's stored SceneState without instantiating it.
## This is a tooling convenience, NOT a security scanner or dependency audit.


static func inspect(
	scene: PackedScene,
	required_direct_markers: PackedStringArray = PackedStringArray(),
	require_root_3d: bool = false,
	reject_scripts: bool = false,
	reject_collision: bool = false,
	max_nodes: int = 4096,
) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var markers := PackedStringArray()
	if scene == null:
		errors.append("SCENE_MISSING: PackedScene is null.")
		return _report(0, markers, errors, warnings)
	var state := scene.get_state()
	if state == null:
		errors.append("STATE_MISSING: PackedScene has no readable SceneState.")
		return _report(0, markers, errors, warnings)
	var count := state.get_node_count()
	if count == 0:
		errors.append("SCENE_EMPTY: PackedScene contains no nodes.")
		return _report(count, markers, errors, warnings)
	if count > maxi(max_nodes, 1):
		errors.append("NODE_LIMIT: Scene exceeds the configured inspection limit.")
		return _report(count, markers, errors, warnings)

	if require_root_3d and not _is_type(state.get_node_type(0), &"Node3D"):
		errors.append("ROOT_TYPE: Scene root must derive from Node3D.")

	for index: int in range(count):
		var kind: StringName = state.get_node_type(index)
		var name: String = String(state.get_node_name(index))
		var path: String = String(state.get_node_path(index))
		if reject_collision and _is_collision_type(kind):
			errors.append("COLLISION: Disallowed collider at %s." % path)
		if index > 0 and _is_type(kind, &"Marker3D"):
			if path == name or path == "./" + name:
				markers.append(name)
		if reject_scripts:
			for property_index: int in range(state.get_node_property_count(index)):
				if state.get_node_property_name(index, property_index) != &"script":
					continue
				if state.get_node_property_value(index, property_index) != null:
					errors.append("SCRIPT: Disallowed script at %s." % path)
				break

	for marker: String in required_direct_markers:
		if marker.is_empty():
			errors.append("MARKER_NAME: Required marker name cannot be empty.")
		elif not markers.has(marker):
			errors.append("MARKER_MISSING: Required direct Marker3D '%s'." % marker)
	return _report(count, markers, errors, warnings)


static func _is_type(kind: StringName, parent: StringName) -> bool:
	return kind == parent or (
		ClassDB.class_exists(kind) and ClassDB.is_parent_class(kind, parent)
	)


static func _is_collision_type(kind: StringName) -> bool:
	return (
		_is_type(kind, &"CollisionObject3D")
		or _is_type(kind, &"CollisionObject2D")
		or _is_type(kind, &"CollisionShape3D")
		or _is_type(kind, &"CollisionShape2D")
		or _is_type(kind, &"CollisionPolygon3D")
		or _is_type(kind, &"CollisionPolygon2D")
	)


static func _report(
	count: int,
	markers: PackedStringArray,
	errors: PackedStringArray,
	warnings: PackedStringArray,
) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"node_count": count,
		"direct_markers": markers,
		"errors": errors,
		"warnings": warnings,
	}
