class_name NucleusDictionaryUtils
extends RefCounted
## Focused helpers for nested and declarative Dictionary data.


static func has_all_keys(
	target: Dictionary,
	keys: Array,
) -> bool:
	for key: Variant in keys:
		if not target.has(key):
			return false

	return true


static func has_any_key(
	target: Dictionary,
	keys: Array,
) -> bool:
	for key: Variant in keys:
		if target.has(key):
			return true

	return false


## Returns a recursively merged copy without mutating either input.
##
## Dictionary branches are merged recursively. Other values from [param overlay]
## replace values from [param base] when [param overwrite] is true.
static func deep_merge(
	base: Dictionary,
	overlay: Dictionary,
	overwrite: bool = true,
) -> Dictionary:
	var result: Dictionary = base.duplicate(true)

	for key: Variant in overlay:
		var overlay_value: Variant = overlay[key]

		if (
			result.has(key)
			and result[key] is Dictionary
			and overlay_value is Dictionary
		):
			result[key] = deep_merge(
				result[key],
				overlay_value,
				overwrite,
			)
			continue

		if overwrite or not result.has(key):
			result[key] = _duplicate_variant(overlay_value)

	return result


## Reads a nested Dictionary path without throwing on missing branches.
static func deep_get(
	target: Dictionary,
	path: Array,
	fallback: Variant = null,
) -> Variant:
	var current: Variant = target

	for key: Variant in path:
		if not (current is Dictionary):
			return fallback

		if not current.has(key):
			return fallback

		current = current[key]

	return current


## Writes a nested Dictionary path, creating intermediate Dictionaries.
static func deep_set(
	target: Dictionary,
	path: Array,
	value: Variant,
) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER

	var current: Dictionary = target

	for index: int in range(path.size() - 1):
		var key: Variant = path[index]

		if not current.has(key):
			current[key] = {}
		elif not (current[key] is Dictionary):
			return ERR_INVALID_DATA

		current = current[key]

	current[path.back()] = _duplicate_variant(value)

	return OK


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Array:
		return value.duplicate(true)

	if value is Dictionary:
		return value.duplicate(true)

	if value is Resource:
		return value.duplicate(true)

	return value
