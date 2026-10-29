class_name NucleusBinarySaveCodec
extends NucleusSaveCodec
## Compact, type-preserving Variant binary codec.
##
## Objects are never serialized.

func get_format() -> int:
	return NucleusSaveTypes.Format.BINARY


func get_extension() -> String:
	return "nsav"


func encode(document: Dictionary) -> PackedByteArray:
	return var_to_bytes(document)


func decode(data: PackedByteArray) -> Dictionary:
	var decoded: Variant = bytes_to_var(data)

	return decoded if typeof(decoded) == TYPE_DICTIONARY else {}
