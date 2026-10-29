class_name NucleusContentPackRegistry
extends RefCounted
## Process-lifetime registry of mounted trusted content packs.

var _records: Dictionary[StringName, NucleusContentPackRecord] = {}


func register(record: NucleusContentPackRecord) -> Error:
	if record == null or record.manifest == null:
		return ERR_INVALID_PARAMETER

	var pack_id: StringName = record.manifest.pack_id
	if pack_id == &"":
		return ERR_INVALID_PARAMETER

	if _records.has(pack_id):
		return ERR_ALREADY_EXISTS

	_records[pack_id] = record
	return OK


func has_pack(pack_id: StringName) -> bool:
	return _records.has(pack_id)


func get_pack(pack_id: StringName) -> NucleusContentPackRecord:
	return _records.get(pack_id)


func get_packs() -> Array[NucleusContentPackRecord]:
	var result: Array[NucleusContentPackRecord] = []
	var ids: Array[StringName] = _records.keys()
	ids.sort_custom(
		func(left: StringName, right: StringName) -> bool:
			return str(left) < str(right)
	)

	for pack_id: StringName in ids:
		result.append(_records[pack_id])

	return result
