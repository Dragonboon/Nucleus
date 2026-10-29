class_name NucleusJsonSaveCodec
extends NucleusSaveCodec
## Interoperable JSON codec.
##
## JSON cannot preserve Godot-specific types such as Vector3 or Color. This
## codec rejects unsupported values rather than silently changing them.

func get_format() -> int:
	return NucleusSaveTypes.Format.JSON


func get_extension() -> String:
	return "json"


func encode(document: Dictionary) -> PackedByteArray:
	if not NucleusSaveDataValidator.is_json_compatible(document):
		return PackedByteArray()

	return JSON.stringify(document, "\t").to_utf8_buffer()


func decode(data: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var error: Error = json.parse(data.get_string_from_utf8())

	if error != OK:
		return {}

	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}
