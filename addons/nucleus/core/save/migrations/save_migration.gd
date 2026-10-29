@abstract
class_name NucleusSaveMigration
extends Resource
## One explicit save schema migration.
##
## Game projects subclass this Resource and mutate payload/metadata in place.

@export_range(1, 2147483647, 1, "or_greater")
var from_version: int = 1
@export_range(1, 2147483647, 1, "or_greater")
var to_version: int = 2


@abstract func migrate(
	payload: Dictionary,
	metadata: Dictionary,
) -> Error


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if from_version < 1:
		errors.append("migration from_version must be at least 1")

	if to_version <= from_version:
		errors.append(
			"migration to_version must be greater than from_version"
		)

	return errors
