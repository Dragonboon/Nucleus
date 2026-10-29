class_name NucleusSaveCodecRegistry
extends RefCounted
## Creates save codecs from configured format or file extension.


static func create_for_format(format: int) -> NucleusSaveCodec:
	match format:
		NucleusSaveTypes.Format.BINARY:
			return NucleusBinarySaveCodec.new()

		NucleusSaveTypes.Format.TEXT:
			return NucleusTextSaveCodec.new()

		NucleusSaveTypes.Format.JSON:
			return NucleusJsonSaveCodec.new()

		_:
			return null


static func create_for_extension(extension: String) -> NucleusSaveCodec:
	match extension.to_lower():
		"nsav":
			return NucleusBinarySaveCodec.new()

		"nsv":
			return NucleusTextSaveCodec.new()

		"json":
			return NucleusJsonSaveCodec.new()

		_:
			return null


static func supported_extensions() -> PackedStringArray:
	return PackedStringArray(["nsav", "nsv", "json"])
