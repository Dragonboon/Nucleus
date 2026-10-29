class_name NucleusSceneObjectTools
extends RefCounted
## Safe scene-object discovery, inspection, and mutation helpers for dev tooling.

const DEFAULT_LIMIT := 50
const MAX_LIMIT := 200
const BLOCKED_PROPERTIES := {
	&"name": true,
	&"owner": true,
	&"script": true,
	&"scene_file_path": true,
}
const SUPPORTED_PROPERTY_TYPES := [
	TYPE_BOOL,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_STRING_NAME,
	TYPE_VECTOR2,
	TYPE_VECTOR2I,
	TYPE_VECTOR3,
	TYPE_VECTOR3I,
	TYPE_COLOR,
]


static func list_nodes(
	root: Node,
	query: String = "",
	limit: int = DEFAULT_LIMIT,
) -> Dictionary:
	if root == null:
		return _failure("Scene root is null.")

	var normalized_query := query.strip_edges().to_lower()
	var matches: Array[Dictionary] = []
	_collect_matching_nodes(
		root,
		root,
		normalized_query,
		clampi(limit, 1, MAX_LIMIT),
		matches,
	)
	return _success(
		"Found %d matching node(s)." % matches.size(),
		matches,
	)


static func list_group(
	root: Node,
	group_name: String,
	limit: int = DEFAULT_LIMIT,
) -> Dictionary:
	if root == null:
		return _failure("Scene root is null.")

	var normalized_group := group_name.strip_edges()
	if normalized_group.is_empty():
		return _failure("Group name cannot be empty.")

	var matches: Array[Dictionary] = []
	_collect_group_nodes(
		root,
		root,
		StringName(normalized_group),
		clampi(limit, 1, MAX_LIMIT),
		matches,
	)
	return _success(
		"Found %d node(s) in group '%s'." % [matches.size(), normalized_group],
		matches,
	)


static func inspect_node(
	root: Node,
	path: String,
	query: String = "",
) -> Dictionary:
	var node := resolve_node(root, path)
	if node == null:
		return _failure("Node not found in current scene: %s" % path)

	var normalized_query := query.strip_edges().to_lower()
	var properties: Array[Dictionary] = []
	for property: Dictionary in node.get_property_list():
		if not _is_inspectable_property(property):
			continue

		var property_name := str(property.get("name", ""))
		var type_id := int(property.get("type", TYPE_NIL))
		var hint_string := str(property.get("hint_string", ""))
		var haystack := "%s %s %s" % [
			property_name.to_lower(),
			_type_name(type_id).to_lower(),
			hint_string.to_lower(),
		]
		if not normalized_query.is_empty() and not haystack.contains(normalized_query):
			continue

		var usage := int(property.get("usage", 0))
		properties.append({
			"name": property_name,
			"type": type_id,
			"type_name": _type_name(type_id),
			"value": node.get(property_name),
			"hint": int(property.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": hint_string,
			"read_only": usage & PROPERTY_USAGE_READ_ONLY != 0,
		})

	return _success(
		"Inspectable properties for %s." % _relative_path(root, node),
		{
			"path": _relative_path(root, node),
			"class": node.get_class(),
			"properties": properties,
		},
	)


static func set_property(
	root: Node,
	path: String,
	property_name: String,
	value_text: String,
) -> Dictionary:
	var node := resolve_node(root, path)
	if node == null:
		return _failure("Node not found in current scene: %s" % path)

	var property := _find_editable_property(node, property_name)
	if property.is_empty():
		return _failure(
			"Property is unavailable, read-only, structural, or unsupported: %s"
			% property_name
		)

	var parsed := _parse_property_value(property, value_text)
	if not bool(parsed.get("ok", false)):
		return parsed

	node.set(StringName(property_name), parsed["value"])
	return _success(
		"%s.%s = %s" % [
			_relative_path(root, node),
			property_name,
			_format_value(node.get(StringName(property_name))),
		],
		node.get(StringName(property_name)),
	)


static func set_position_2d(
	root: Node,
	path: String,
	x: float,
	y: float,
	space: String = "local",
) -> Dictionary:
	var node := resolve_node(root, path) as Node2D
	if node == null:
		return _failure("Node2D not found in current scene: %s" % path)

	var value := Vector2(x, y)
	if space.nocasecmp_to("global") == 0:
		node.global_position = value
	else:
		node.position = value
	return _success(
		"%s %s position = %s" % [_relative_path(root, node), space, value],
		value,
	)


static func set_position_3d(
	root: Node,
	path: String,
	x: float,
	y: float,
	z: float,
	space: String = "local",
) -> Dictionary:
	var node := resolve_node(root, path) as Node3D
	if node == null:
		return _failure("Node3D not found in current scene: %s" % path)

	var value := Vector3(x, y, z)
	if space.nocasecmp_to("global") == 0:
		node.global_position = value
	else:
		node.position = value
	return _success(
		"%s %s position = %s" % [_relative_path(root, node), space, value],
		value,
	)


static func set_rotation_2d(
	root: Node,
	path: String,
	degrees_value: float,
) -> Dictionary:
	var node := resolve_node(root, path) as Node2D
	if node == null:
		return _failure("Node2D not found in current scene: %s" % path)

	node.rotation_degrees = degrees_value
	return _success(
		"%s rotation = %.3f deg" % [_relative_path(root, node), degrees_value],
		degrees_value,
	)


static func set_rotation_3d(
	root: Node,
	path: String,
	x_degrees: float,
	y_degrees: float,
	z_degrees: float,
) -> Dictionary:
	var node := resolve_node(root, path) as Node3D
	if node == null:
		return _failure("Node3D not found in current scene: %s" % path)

	var value := Vector3(x_degrees, y_degrees, z_degrees)
	node.rotation_degrees = value
	return _success(
		"%s rotation = %s deg" % [_relative_path(root, node), value],
		value,
	)


static func set_scale_2d(
	root: Node,
	path: String,
	x: float,
	y: float,
) -> Dictionary:
	var node := resolve_node(root, path) as Node2D
	if node == null:
		return _failure("Node2D not found in current scene: %s" % path)

	var value := Vector2(x, y)
	node.scale = value
	return _success(
		"%s scale = %s" % [_relative_path(root, node), value],
		value,
	)


static func set_scale_3d(
	root: Node,
	path: String,
	x: float,
	y: float,
	z: float,
) -> Dictionary:
	var node := resolve_node(root, path) as Node3D
	if node == null:
		return _failure("Node3D not found in current scene: %s" % path)

	var value := Vector3(x, y, z)
	node.scale = value
	return _success(
		"%s scale = %s" % [_relative_path(root, node), value],
		value,
	)


static func set_visible(
	root: Node,
	path: String,
	visible: bool,
) -> Dictionary:
	var node := resolve_node(root, path)
	if node == null:
		return _failure("Node not found in current scene: %s" % path)
	if not node is CanvasItem and not node is Node3D:
		return _failure("Node does not expose scene visibility: %s" % path)

	node.set(&"visible", visible)
	return _success(
		"%s visible = %s" % [_relative_path(root, node), str(visible)],
		visible,
	)


static func set_processing(
	root: Node,
	path: String,
	enabled: bool,
) -> Dictionary:
	var node := resolve_node(root, path)
	if node == null:
		return _failure("Node not found in current scene: %s" % path)

	node.set_process(enabled)
	node.set_physics_process(enabled)
	return _success(
		"%s idle/physics processing = %s"
		% [_relative_path(root, node), str(enabled)],
		enabled,
	)


static func resolve_node(root: Node, path: String) -> Node:
	if root == null:
		return null

	var normalized := path.strip_edges()
	if normalized.is_empty() or normalized == ".":
		return root
	if normalized.begins_with("/"):
		return null

	if normalized == root.name:
		return root
	var root_prefix := "%s/" % root.name
	if normalized.begins_with(root_prefix):
		normalized = normalized.trim_prefix(root_prefix)

	var candidate := root.get_node_or_null(NodePath(normalized))
	if candidate == null:
		return null
	if candidate != root and not root.is_ancestor_of(candidate):
		return null
	return candidate


static func format_node_list(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return str(result.get("message", "Scene object query failed."))

	var entries: Array = result.get("data", [])
	if entries.is_empty():
		return str(result.get("message", "No matching nodes."))

	var lines := PackedStringArray([str(result.get("message", ""))])
	for value: Variant in entries:
		var entry := value as Dictionary
		var groups: PackedStringArray = entry.get("groups", PackedStringArray())
		var suffix := ""
		if not groups.is_empty():
			suffix = " groups=%s" % ",".join(groups)
		lines.append(
			"%s [%s]%s"
			% [entry.get("path", "."), entry.get("class", "Node"), suffix]
		)
	return "\n".join(lines)


static func format_inspection(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return str(result.get("message", "Node inspection failed."))

	var data: Dictionary = result.get("data", {})
	var lines := PackedStringArray([
		"%s [%s]" % [data.get("path", "."), data.get("class", "Node")],
	])
	var properties: Array = data.get("properties", [])
	if properties.is_empty():
		lines.append("No supported editor-visible properties matched.")
		return "\n".join(lines)

	for value: Variant in properties:
		var property := value as Dictionary
		var suffix := " [read-only]" if bool(property.get("read_only", false)) else ""
		var hint_string := str(property.get("hint_string", ""))
		if not hint_string.is_empty():
			suffix += " {%s}" % hint_string
		lines.append(
			"%s: %s = %s%s"
			% [
				property.get("name", ""),
				property.get("type_name", "Variant"),
				_format_value(property.get("value")),
				suffix,
			]
		)
	return "\n".join(lines)


static func _collect_matching_nodes(
	node: Node,
	root: Node,
	query: String,
	limit: int,
	matches: Array[Dictionary],
) -> void:
	if matches.size() >= limit:
		return

	var path := _relative_path(root, node)
	var haystack := "%s %s %s" % [
		path.to_lower(),
		str(node.name).to_lower(),
		node.get_class().to_lower(),
	]
	if query.is_empty() or haystack.contains(query):
		matches.append(_node_entry(root, node))
		if matches.size() >= limit:
			return

	for child: Node in node.get_children():
		_collect_matching_nodes(child, root, query, limit, matches)
		if matches.size() >= limit:
			return


static func _collect_group_nodes(
	node: Node,
	root: Node,
	group_name: StringName,
	limit: int,
	matches: Array[Dictionary],
) -> void:
	if matches.size() >= limit:
		return
	if node.is_in_group(group_name):
		matches.append(_node_entry(root, node))
		if matches.size() >= limit:
			return
	for child: Node in node.get_children():
		_collect_group_nodes(child, root, group_name, limit, matches)
		if matches.size() >= limit:
			return


static func _node_entry(root: Node, node: Node) -> Dictionary:
	var groups := PackedStringArray()
	for group: StringName in node.get_groups():
		groups.append(str(group))
	groups.sort()
	return {
		"path": _relative_path(root, node),
		"name": str(node.name),
		"class": node.get_class(),
		"groups": groups,
	}


static func _relative_path(root: Node, node: Node) -> String:
	if root == node:
		return "."
	return str(root.get_path_to(node))


static func _is_inspectable_property(property: Dictionary) -> bool:
	var usage := int(property.get("usage", 0))
	var type_id := int(property.get("type", TYPE_NIL))
	return (
		usage & PROPERTY_USAGE_EDITOR != 0
		and type_id in SUPPORTED_PROPERTY_TYPES
	)


static func _find_editable_property(
	node: Node,
	property_name: String,
) -> Dictionary:
	var normalized := StringName(property_name.strip_edges())
	if normalized.is_empty() or BLOCKED_PROPERTIES.has(normalized):
		return {}

	for property: Dictionary in node.get_property_list():
		if StringName(property.get("name", "")) != normalized:
			continue
		if not _is_inspectable_property(property):
			return {}
		if int(property.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY != 0:
			return {}
		return property
	return {}


static func _parse_property_value(
	property: Dictionary,
	value_text: String,
) -> Dictionary:
	var type_id := int(property.get("type", TYPE_NIL))
	var normalized := value_text.strip_edges()
	match type_id:
		TYPE_BOOL:
			return _parse_bool(normalized)
		TYPE_INT:
			return _parse_int(property, normalized)
		TYPE_FLOAT:
			if normalized.is_valid_float():
				return _success_value(normalized.to_float())
		TYPE_STRING:
			return _success_value(value_text)
		TYPE_STRING_NAME:
			return _success_value(StringName(value_text))
		TYPE_VECTOR2:
			return _parse_vector2(normalized, false)
		TYPE_VECTOR2I:
			return _parse_vector2(normalized, true)
		TYPE_VECTOR3:
			return _parse_vector3(normalized, false)
		TYPE_VECTOR3I:
			return _parse_vector3(normalized, true)
		TYPE_COLOR:
			return _parse_color(normalized)
	return _failure(
		"Unsupported property type: %s" % _type_name(type_id)
	)


static func _parse_bool(value: String) -> Dictionary:
	match value.to_lower():
		"true", "1", "yes", "on":
			return _success_value(true)
		"false", "0", "no", "off":
			return _success_value(false)
	return _failure("Expected a boolean: true/false, yes/no, on/off, or 1/0.")


static func _parse_int(property: Dictionary, value: String) -> Dictionary:
	if int(property.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_ENUM:
		var enum_value := _parse_enum_value(
			str(property.get("hint_string", "")),
			value,
		)
		if bool(enum_value.get("ok", false)):
			return enum_value
	if value.is_valid_int():
		return _success_value(value.to_int())
	return _failure("Expected an integer or enum option.")


static func _parse_enum_value(hint_string: String, value: String) -> Dictionary:
	var normalized := value.strip_edges().to_lower()
	var implicit_value := 0
	for raw_option: String in hint_string.split(",", false):
		var option := raw_option.strip_edges()
		var label := option
		var numeric_value := implicit_value
		var separator := option.rfind(":")
		if separator >= 0:
			var suffix := option.substr(separator + 1).strip_edges()
			if suffix.is_valid_int():
				label = option.substr(0, separator).strip_edges()
				numeric_value = suffix.to_int()
		if label.to_lower() == normalized:
			return _success_value(numeric_value)
		implicit_value = numeric_value + 1
	return _failure("Unknown enum option: %s" % value)


static func _parse_vector2(value: String, integer: bool) -> Dictionary:
	var parts := _vector_parts(value, 2)
	if parts.is_empty():
		return _failure("Expected two comma-separated components, for example 10,20.")
	if integer:
		if not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return _failure("Vector2i components must be integers.")
		return _success_value(Vector2i(parts[0].to_int(), parts[1].to_int()))
	if not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return _failure("Vector2 components must be numeric.")
	return _success_value(Vector2(parts[0].to_float(), parts[1].to_float()))


static func _parse_vector3(value: String, integer: bool) -> Dictionary:
	var parts := _vector_parts(value, 3)
	if parts.is_empty():
		return _failure(
			"Expected three comma-separated components, for example 10,20,-3."
		)
	if integer:
		for part: String in parts:
			if not part.is_valid_int():
				return _failure("Vector3i components must be integers.")
		return _success_value(Vector3i(
			parts[0].to_int(),
			parts[1].to_int(),
			parts[2].to_int(),
		))
	for part: String in parts:
		if not part.is_valid_float():
			return _failure("Vector3 components must be numeric.")
	return _success_value(Vector3(
		parts[0].to_float(),
		parts[1].to_float(),
		parts[2].to_float(),
	))


static func _parse_color(value: String) -> Dictionary:
	if Color.html_is_valid(value):
		return _success_value(Color.html(value))
	var invalid_color := Color(-1.0, -1.0, -1.0, -1.0)
	var named_color := Color.from_string(value, invalid_color)
	if named_color != invalid_color:
		return _success_value(named_color)

	var parts := _vector_parts(value, 4, true)
	if parts.size() not in [3, 4]:
		return _failure("Expected #RRGGBB, a named color, or r,g,b[,a].")
	for part: String in parts:
		if not part.is_valid_float():
			return _failure("Color components must be numeric.")
	var alpha := parts[3].to_float() if parts.size() == 4 else 1.0
	return _success_value(Color(
		parts[0].to_float(),
		parts[1].to_float(),
		parts[2].to_float(),
		alpha,
	))


static func _vector_parts(
	value: String,
	expected: int,
	allow_shorter: bool = false,
) -> PackedStringArray:
	var cleaned := value.strip_edges()
	for prefix: String in ["Vector2i", "Vector2", "Vector3i", "Vector3", "Color"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.trim_prefix(prefix).strip_edges()
	cleaned = cleaned.trim_prefix("(").trim_suffix(")")
	cleaned = cleaned.trim_prefix("[").trim_suffix("]")
	var raw := cleaned.split(",", false)
	if not allow_shorter and raw.size() != expected:
		return PackedStringArray()
	if allow_shorter and (raw.size() < 3 or raw.size() > expected):
		return PackedStringArray()
	var result := PackedStringArray()
	for part: String in raw:
		result.append(part.strip_edges())
	return result


static func _type_name(type_id: int) -> String:
	match type_id:
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_COLOR:
			return "Color"
	return "Variant"


static func _format_value(value: Variant) -> String:
	if value is String or value is StringName:
		return '"%s"' % str(value)
	return str(value)


static func _success(message: String, data: Variant = null) -> Dictionary:
	return {
		"ok": true,
		"message": message,
		"data": data,
	}


static func _success_value(value: Variant) -> Dictionary:
	return {
		"ok": true,
		"value": value,
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
