class_name NucleusSaveDataValidator
extends RefCounted
## Validates values accepted by Nucleus save payloads.
##
## Objects, Callables, Signals and RIDs are rejected. Dictionary keys must be
## String or StringName so integrity hashing remains deterministic.

const MAX_RECURSION_DEPTH: int = 128


static func validate(value: Variant) -> Error:
	return _validate_recursive(value, 0)


static func is_json_compatible(value: Variant) -> bool:
	return _is_json_compatible_recursive(value, 0)


static func _validate_recursive(value: Variant, depth: int) -> Error:
	if depth > MAX_RECURSION_DEPTH:
		return ERR_OUT_OF_MEMORY

	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return ERR_INVALID_DATA

		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return ERR_INVALID_DATA

				var child_error: Error = _validate_recursive(
					value[key],
					depth + 1,
				)

				if child_error != OK:
					return child_error

		TYPE_ARRAY:
			for child: Variant in value:
				var child_error: Error = _validate_recursive(
					child,
					depth + 1,
				)

				if child_error != OK:
					return child_error

	return OK


static func _is_json_compatible_recursive(
	value: Variant,
	depth: int,
) -> bool:
	if depth > MAX_RECURSION_DEPTH:
		return false

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true

		TYPE_STRING_NAME:
			return true

		TYPE_ARRAY:
			for child: Variant in value:
				if not _is_json_compatible_recursive(
					child,
					depth + 1,
				):
					return false

			return true

		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return false

				if not _is_json_compatible_recursive(
					value[key],
					depth + 1,
				):
					return false

			return true

		_:
			return false
