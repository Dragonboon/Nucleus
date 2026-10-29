class_name NucleusSaveResult
extends RefCounted
## Result object returned by save/load/delete operations.

var error: Error = OK
var path: String
var document: NucleusSaveDocument

var recovered_from_backup: bool = false
var migrated: bool = false


func succeeded() -> bool:
	return error == OK
