class_name NucleusArrayUtils
extends RefCounted
## Small collection helpers that are not already covered well by Array itself.


## Flattens nested Array values while preserving left-to-right order.
static func flatten(
	values: Array,
	max_depth: int = 64,
) -> Array:
	var result: Array = []

	_flatten_into(
		values,
		result,
		0,
		maxi(0, max_depth),
	)

	return result


## Returns values without duplicates while preserving first occurrence order.
static func unique(values: Array) -> Array:
	var result: Array = []

	for value: Variant in values:
		if not result.has(value):
			result.append(value)

	return result


## Splits an Array into fixed-size chunks.
##
## If [param keep_remainder] is false, a final incomplete chunk is discarded.
static func chunk(
	values: Array,
	chunk_size: int,
	keep_remainder: bool = true,
) -> Array[Array]:
	var result: Array[Array] = []

	if chunk_size <= 0:
		return result

	for start: int in range(0, values.size(), chunk_size):
		var end: int = mini(
			start + chunk_size,
			values.size(),
		)

		if not keep_remainder and end - start < chunk_size:
			break

		result.append(values.slice(start, end))

	return result


## Returns whether the Arrays share at least one equal value.
static func intersects(
	left: Array,
	right: Array,
) -> bool:
	for value: Variant in left:
		if right.has(value):
			return true

	return false


## Returns common values in left-side order.
##
## Set [param unique_result] to false to preserve duplicate occurrences.
static func intersection(
	left: Array,
	right: Array,
	unique_result: bool = true,
) -> Array:
	var result: Array = []

	for value: Variant in left:
		if not right.has(value):
			continue

		if unique_result and result.has(value):
			continue

		result.append(value)

	return result


## Counts occurrences. Values must be valid Dictionary keys.
static func frequency(values: Array) -> Dictionary:
	var result: Dictionary = {}

	for value: Variant in values:
		result[value] = int(result.get(value, 0)) + 1

	return result


## Returns the next element, wrapping to the first.
static func circular_next(
	values: Array,
	value: Variant,
) -> Variant:
	if values.size() < 2:
		return null

	var index: int = values.find(value)

	if index == -1:
		return null

	return values[(index + 1) % values.size()]


## Returns the previous element, wrapping to the last.
static func circular_previous(
	values: Array,
	value: Variant,
) -> Variant:
	if values.size() < 2:
		return null

	var index: int = values.find(value)

	if index == -1:
		return null

	return values[
		(index - 1 + values.size()) % values.size()
	]


## Creates repeated independent copies of a mutable Variant where possible.
static func repeat_deep(
	value: Variant,
	count: int,
) -> Array:
	var result: Array = []

	for _index: int in range(maxi(0, count)):
		result.append(_duplicate_variant(value))

	return result


static func _flatten_into(
	values: Array,
	result: Array,
	depth: int,
	max_depth: int,
) -> void:
	for value: Variant in values:
		if value is Array and depth < max_depth:
			_flatten_into(
				value,
				result,
				depth + 1,
				max_depth,
			)
		else:
			result.append(value)


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Array:
		return value.duplicate(true)

	if value is Dictionary:
		return value.duplicate(true)

	if value is Resource:
		return value.duplicate(true)

	return value
