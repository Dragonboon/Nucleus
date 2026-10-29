@abstract
class_name NucleusSaveCodec
extends RefCounted
## Strategy interface for on-disk save representations.


@abstract func get_format() -> int


@abstract func get_extension() -> String


@abstract func encode(document: Dictionary) -> PackedByteArray


@abstract func decode(data: PackedByteArray) -> Dictionary
