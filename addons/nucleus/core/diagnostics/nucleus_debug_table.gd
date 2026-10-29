class_name NucleusDebugTable
extends RefCounted
## Pure formatter for bounded, plain-text diagnostic tables.

const DEFAULT_MAX_CELL_WIDTH: int = 32
const DEFAULT_MAX_ROWS: int = 20


static func format(
	rows: Array,
	columns: Array = [],
	max_cell_width: int = DEFAULT_MAX_CELL_WIDTH,
	max_rows: int = DEFAULT_MAX_ROWS,
) -> String:
	if rows.is_empty():
		return "(empty)"

	var safe_cell_width: int = maxi(max_cell_width, 8)
	var safe_max_rows: int = maxi(max_rows, 1)
	var descriptors: Array[Dictionary] = _resolve_columns(
		rows,
		columns,
	)

	if descriptors.is_empty():
		return "(no columns)"

	var rendered_rows: Array[Array] = []
	var widths: Array[int] = []

	for descriptor: Dictionary in descriptors:
		var label: String = String(descriptor["label"])
		widths.append(mini(label.length(), safe_cell_width))

	var row_count: int = mini(rows.size(), safe_max_rows)

	for row_index: int in range(row_count):
		var row: Variant = rows[row_index]
		var rendered: Array[String] = []

		for column_index: int in range(descriptors.size()):
			var descriptor: Dictionary = descriptors[column_index]
			var cell_value: Variant = _read_cell(row, descriptor)
			var cell_text: String = _format_cell(
				cell_value,
				safe_cell_width,
			)
			rendered.append(cell_text)
			widths[column_index] = mini(
				maxi(
					widths[column_index],
					cell_text.length(),
				),
				safe_cell_width,
			)

		rendered_rows.append(rendered)

	var lines: PackedStringArray = []
	lines.append(_format_header(descriptors, widths))
	lines.append(_format_separator(widths))

	for rendered: Array in rendered_rows:
		lines.append(_format_row(rendered, widths))

	if rows.size() > row_count:
		lines.append(
			"... %d more row(s)" % (rows.size() - row_count)
		)

	return "\n".join(lines)


static func _resolve_columns(
	rows: Array,
	columns: Array,
) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []

	if not columns.is_empty():
		for column: Variant in columns:
			descriptors.append({
				"label": str(column),
				"key": column,
			})

		return descriptors

	var first: Variant = rows[0]

	if first is Dictionary:
		var keys: Array = (first as Dictionary).keys()
		keys.sort_custom(
			func(left: Variant, right: Variant) -> bool:
				return str(left) < str(right)
		)

		for key: Variant in keys:
			descriptors.append({
				"label": str(key),
				"key": key,
			})

		return descriptors

	if first is Array:
		var widest: int = 0

		for row: Variant in rows:
			if row is Array:
				widest = maxi(widest, (row as Array).size())

		for index: int in range(widest):
			descriptors.append({
				"label": "Column %d" % (index + 1),
				"index": index,
			})

		return descriptors

	return [{
		"label": "Value",
		"scalar": true,
	}]


static func _read_cell(
	row: Variant,
	descriptor: Dictionary,
) -> Variant:
	if bool(descriptor.get("scalar", false)):
		return row

	if descriptor.has("index"):
		if not row is Array:
			return null

		var index: int = int(descriptor["index"])
		var array_row: Array = row as Array

		if index < 0 or index >= array_row.size():
			return null

		return array_row[index]

	if not row is Dictionary:
		return null

	var dictionary_row: Dictionary = row as Dictionary
	var key: Variant = descriptor.get("key")

	if dictionary_row.has(key):
		return dictionary_row[key]

	var string_key: String = str(key)

	if dictionary_row.has(string_key):
		return dictionary_row[string_key]

	var string_name_key: StringName = StringName(string_key)

	if dictionary_row.has(string_name_key):
		return dictionary_row[string_name_key]

	return null


static func _format_cell(
	value: Variant,
	max_cell_width: int,
) -> String:
	if value is String or value is StringName or value is NodePath:
		return _truncate(str(value), max_cell_width)

	var rendered: String = NucleusLogFormatter.format_compact(
		value,
		{
			"max_depth": 2,
			"max_items": 4,
			"max_string_length": max_cell_width,
		},
	)
	rendered = rendered.replace("\n", "\\n")
	return _truncate(rendered, max_cell_width)


static func _format_header(
	descriptors: Array[Dictionary],
	widths: Array[int],
) -> String:
	var values: Array[String] = []

	for index: int in range(descriptors.size()):
		var label: String = String(descriptors[index]["label"])
		values.append(_pad(_truncate(label, widths[index]), widths[index]))

	return "| %s |" % " | ".join(values)


static func _format_separator(widths: Array[int]) -> String:
	var values: Array[String] = []

	for width: int in widths:
		var separator: String = ""

		for _index: int in range(maxi(width, 3)):
			separator += "-"

		values.append(separator)

	return "|-%s-|" % "-|-".join(values)


static func _format_row(
	values: Array,
	widths: Array[int],
) -> String:
	var cells: Array[String] = []

	for index: int in range(widths.size()):
		var value: String = String(values[index])
		cells.append(
			_pad(
				_truncate(value, widths[index]),
				widths[index],
			)
		)

	return "| %s |" % " | ".join(cells)


static func _pad(
	value: String,
	width: int,
) -> String:
	var result: String = value

	while result.length() < width:
		result += " "

	return result


static func _truncate(
	value: String,
	max_length: int,
) -> String:
	if value.length() <= max_length:
		return value

	if max_length <= 3:
		return value.left(max_length)

	return value.left(max_length - 3) + "..."
