class_name NucleusSettingsLoadResult
extends RefCounted
## Result object returned by [NucleusConfigSettingsRepository.load_settings].

var error: Error = OK
var schema_version: int = 0
var values: Dictionary[StringName, Variant] = {}
var source_path: String
var recovered_from_backup: bool = false


func succeeded() -> bool:
	return error == OK
