class_name NucleusLogFormatter
extends RefCounted
## Pure, bounded formatter for diagnostic Variant data.
##
## The formatter does not print, mutate source data, register global handlers,
## or depend on scene ownership.

const DEFAULT_MAX_DEPTH: int = 4
const DEFAULT_MAX_ITEMS: int = 12
const DEFAULT_MAX_STRING_LENGTH: int = 160
const DEFAULT_FLOAT_PRECISION: int = 3


static func format(
	value: Variant,
	options: Dictionary = {},
) -> String:
	var multiline: bool = bool(options.get("multiline", false))
	var max_depth: int = maxi(
		int(options.get("max_depth", DEFAULT_MAX_DEPTH)),
		0,
	)
	var max_items: int = maxi(
		int(options.get("max_items", DEFAULT_MAX_ITEMS)),
		1,
	)
	var max_string_length: int = maxi(
		int(
			options.get(
				"max_string_length",
				DEFAULT_MAX_STRING_LENGTH,
			)
		),
		8,
	)
	var float_precision: int = clampi(
		int(
			options.get(
				"float_precision",
				DEFAULT_FLOAT_PRECISION,
			)
		),
		0,
		8,
	)
	var sort_dictionary_keys: bool = bool(
		options.get("sort_dictionary_keys", true)
	)

	return _format_value(
		value,
		0,
		multiline,
		max_depth,
		max_items,
		max_string_length,
		float_precision,
		sort_dictionary_keys,
	)


static func format_compact(
	value: Variant,
	options: Dictionary = {},
) -> String:
	var resolved: Dictionary = options.duplicate()
	resolved["multiline"] = false
	return format(value, resolved)


static func format_multiline(
	value: Variant,
	options: Dictionary = {},
) -> String:
	var resolved: Dictionary = options.duplicate()
	resolved["multiline"] = true
	return format(value, resolved)


static func _format_value(
	value: Variant,
	depth: int,
	multiline: bool,
	max_depth: int,
	max_items: int,
	max_string_length: int,
	float_precision: int,
	sort_dictionary_keys: bool,
) -> String:
	if value == null:
		return "null"

	if value is String:
		return '"%s"' % _escape_string(
			_truncate(String(value), max_string_length)
		)

	if value is StringName:
		return '&"%s"' % _escape_string(
			_truncate(String(value), max_string_length)
		)

	if value is NodePath:
		return '^"%s"' % _escape_string(
			_truncate(String(value), max_string_length)
		)

	if value is float:
		var float_format: String = "%." + str(float_precision) + "f"
		return float_format % float(value)

	if value is Dictionary:
		return _format_dictionary(
			value,
			depth,
			multiline,
			max_depth,
			max_items,
			max_string_length,
			float_precision,
			sort_dictionary_keys,
		)

	if value is Array:
		return _format_array(
			value,
			depth,
			multiline,
			max_depth,
			max_items,
			max_string_length,
			float_precision,
			sort_dictionary_keys,
		)

	if _is_packed_array(value):
		var packed_values: Array = Array(value)
		return _format_array(
			packed_values,
			depth,
			multiline,
			max_depth,
			max_items,
			max_string_length,
			float_precision,
			sort_dictionary_keys,
		)

	if value is Object:
		return _format_object(value)

	var rendered: String = str(value)
	return _truncate(rendered, max_string_length)


static func _format_array(
	values: Array,
	depth: int,
	multiline: bool,
	max_depth: int,
	max_items: int,
	max_string_length: int,
	float_precision: int,
	sort_dictionary_keys: bool,
) -> String:
	if depth >= max_depth:
		return "[...]"

	if values.is_empty():
		return "[]"

	var count: int = mini(values.size(), max_items)
	var rendered_items: Array[String] = []

	for index: int in range(count):
		rendered_items.append(
			_format_value(
				values[index],
				depth + 1,
				multiline,
				max_depth,
				max_items,
				max_string_length,
				float_precision,
				sort_dictionary_keys,
			)
		)

	if values.size() > count:
		rendered_items.append(
			"... +%d" % (values.size() - count)
		)

	return _join_collection(
		rendered_items,
		"[",
		"]",
		depth,
		multiline,
	)


static func _is_packed_array(value: Variant) -> bool:
	return typeof(value) in [
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]


static func _format_dictionary(
	values: Dictionary,
	depth: int,
	multiline: bool,
	max_depth: int,
	max_items: int,
	max_string_length: int,
	float_precision: int,
	sort_dictionary_keys: bool,
) -> String:
	if depth >= max_depth:
		return "{...}"

	if values.is_empty():
		return "{}"

	var entries: Array[Dictionary] = []

	for key: Variant in values.keys():
		var key_text: String = _format_dictionary_key(
			key,
			max_string_length,
		)
		entries.append({
			"key": key,
			"sort_key": key_text,
		})

	if sort_dictionary_keys:
		entries.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				return String(left["sort_key"]) < String(right["sort_key"])
		)

	var count: int = mini(entries.size(), max_items)
	var rendered_items: Array[String] = []

	for index: int in range(count):
		var entry: Dictionary = entries[index]
		var key: Variant = entry["key"]
		var key_text: String = String(entry["sort_key"])
		var value_text: String = _format_value(
			values[key],
			depth + 1,
			multiline,
			max_depth,
			max_items,
			max_string_length,
			float_precision,
			sort_dictionary_keys,
		)
		rendered_items.append("%s: %s" % [key_text, value_text])

	if entries.size() > count:
		rendered_items.append(
			"... +%d" % (entries.size() - count)
		)

	return _join_collection(
		rendered_items,
		"{",
		"}",
		depth,
		multiline,
	)


static func _format_dictionary_key(
	key: Variant,
	max_string_length: int,
) -> String:
	if key is String:
		return '"%s"' % _escape_string(
			_truncate(String(key), max_string_length)
		)

	if key is StringName:
		return '&"%s"' % _escape_string(
			_truncate(String(key), max_string_length)
		)

	return _truncate(str(key), max_string_length)


static func _format_object(value: Object) -> String:
	if not is_instance_valid(value):
		return "<invalid Object>"

	var class_name_text: String = str(value.get_class())

	if value is Resource:
		var resource: Resource = value as Resource

		if not resource.resource_path.is_empty():
			return "<%s %s>" % [
				class_name_text,
				resource.resource_path,
			]

	if value is Node:
		var node: Node = value as Node
		return '<%s name="%s"#%d>' % [
			class_name_text,
			_escape_string(node.name),
			node.get_instance_id(),
		]

	return "<%s#%d>" % [
		class_name_text,
		value.get_instance_id(),
	]


static func _join_collection(
	items: Array[String],
	opening: String,
	closing: String,
	depth: int,
	multiline: bool,
) -> String:
	if not multiline:
		return "%s%s%s" % [
			opening,
			", ".join(items),
			closing,
		]

	var child_indent: String = _indent(depth + 1)
	var closing_indent: String = _indent(depth)
	return "%s\n%s%s\n%s%s" % [
		opening,
		child_indent,
		(",\n" + child_indent).join(items),
		closing_indent,
		closing,
	]


static func _indent(depth: int) -> String:
	var result: String = ""

	for _index: int in range(maxi(depth, 0)):
		result += "\t"

	return result


static func _escape_string(value: String) -> String:
	return (
		value
		.replace("\\", "\\\\")
		.replace('"', '\\"')
		.replace("\n", "\\n")
		.replace("\r", "\\r")
		.replace("\t", "\\t")
	)


static func _truncate(
	value: String,
	max_length: int,
) -> String:
	if value.length() <= max_length:
		return value

	if max_length <= 3:
		return value.left(max_length)

	return value.left(max_length - 3) + "..."
