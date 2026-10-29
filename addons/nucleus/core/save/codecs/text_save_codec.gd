class_name NucleusTextSaveCodec
extends NucleusSaveCodec
## Human-readable Godot Variant text codec.
##
## Unlike JSON, Godot-specific built-in Variant types remain representable.

func get_format() -> int:
	return NucleusSaveTypes.Format.TEXT


func get_extension() -> String:
	return "nsv"


func encode(document: Dictionary) -> PackedByteArray:
	return var_to_str(document).to_utf8_buffer()


func decode(data: PackedByteArray) -> Dictionary:
	var decoded: Variant = str_to_var(data.get_string_from_utf8())

	return decoded if typeof(decoded) == TYPE_DICTIONARY else {}
