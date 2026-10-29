class_name NucleusEnumUtils
extends RefCounted
## Helpers for GDScript enum Dictionaries.
##
## Enum numeric values are never assumed to equal their key-array index.


static func names(enum_dictionary: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []

	for key: Variant in enum_dictionary:
		result.append(StringName(str(key)))

	return result


static func values(enum_dictionary: Dictionary) -> Array[int]:
	var result: Array[int] = []

	for key: Variant in enum_dictionary:
		result.append(int(enum_dictionary[key]))

	return result


static func name_for_value(
	enum_dictionary: Dictionary,
	value: int,
) -> StringName:
	for key: Variant in enum_dictionary:
		if int(enum_dictionary[key]) == value:
			return StringName(str(key))

	return &""


static func random_value(
	enum_dictionary: Dictionary,
	rng: RandomNumberGenerator = null,
) -> Variant:
	var enum_values: Array[int] = values(enum_dictionary)

	if enum_values.is_empty():
		return null

	var index: int = (
		rng.randi_range(0, enum_values.size() - 1)
		if rng
		else randi_range(0, enum_values.size() - 1)
	)

	return enum_values[index]


static func random_name(
	enum_dictionary: Dictionary,
	rng: RandomNumberGenerator = null,
) -> StringName:
	var value: Variant = random_value(
		enum_dictionary,
		rng,
	)

	if value == null:
		return &""

	return name_for_value(
		enum_dictionary,
		int(value),
	)
