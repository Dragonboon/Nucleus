class_name NucleusUuid
extends RefCounted
## RFC 4122/9562-compatible UUID version 4 helpers.
##
## UUIDs use Godot's cryptographically secure [Crypto] random byte generator.
## Gameplay randomness should continue using Godot's normal PRNG APIs.

const BYTE_COUNT: int = 16
const VERSION_BYTE_INDEX: int = 6
const VARIANT_BYTE_INDEX: int = 8

const VERSION_MASK: int = 0x0F
const VERSION_4_BITS: int = 0x40
const VARIANT_MASK: int = 0x3F
const RFC_VARIANT_BITS: int = 0x80


## Generates a lowercase UUIDv4 string.
static func v4() -> String:
	return bytes_to_string(v4_bytes())


## Generates the 16 raw bytes of an RFC-compatible UUIDv4.
static func v4_bytes() -> PackedByteArray:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(
		BYTE_COUNT
	)

	if bytes.size() != BYTE_COUNT:
		return PackedByteArray()

	bytes[VERSION_BYTE_INDEX] = (
		(bytes[VERSION_BYTE_INDEX] & VERSION_MASK)
		| VERSION_4_BITS
	)
	bytes[VARIANT_BYTE_INDEX] = (
		(bytes[VARIANT_BYTE_INDEX] & VARIANT_MASK)
		| RFC_VARIANT_BITS
	)

	return bytes


## Formats exactly 16 UUID bytes using the canonical 8-4-4-4-12 layout.
static func bytes_to_string(bytes: PackedByteArray) -> String:
	if bytes.size() != BYTE_COUNT:
		return ""

	return (
		"%02x%02x%02x%02x-"
		+ "%02x%02x-"
		+ "%02x%02x-"
		+ "%02x%02x-"
		+ "%02x%02x%02x%02x%02x%02x"
	) % [
		bytes[0],
		bytes[1],
		bytes[2],
		bytes[3],
		bytes[4],
		bytes[5],
		bytes[6],
		bytes[7],
		bytes[8],
		bytes[9],
		bytes[10],
		bytes[11],
		bytes[12],
		bytes[13],
		bytes[14],
		bytes[15],
	]


## Returns whether a string has canonical UUID syntax.
##
## This validates layout and hexadecimal characters. It accepts UUID versions
## other than v4 so it is also useful for externally supplied UUIDs.
static func is_valid(value: String) -> bool:
	if value.length() != 36:
		return false

	for index: int in [8, 13, 18, 23]:
		if value[index] != "-":
			return false

	for index: int in range(value.length()):
		if index in [8, 13, 18, 23]:
			continue

		if not _is_hex_character(value[index]):
			return false

	return true


static func _is_hex_character(character: String) -> bool:
	if character.length() != 1:
		return false

	var code: int = character.unicode_at(0)

	return (
		(code >= 48 and code <= 57)
		or (code >= 65 and code <= 70)
		or (code >= 97 and code <= 102)
	)
