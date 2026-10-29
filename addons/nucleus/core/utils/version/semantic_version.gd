class_name NucleusSemanticVersion
extends RefCounted
## SemVer 2.0.0 value object with parsing and precedence comparison.
##
## Build metadata never affects precedence.

var major: int
var minor: int
var patch: int

var prerelease: String
var build_metadata: String


func _init(
	version_major: int = 0,
	version_minor: int = 0,
	version_patch: int = 0,
	version_prerelease: String = "",
	version_build_metadata: String = "",
) -> void:
	major = maxi(0, version_major)
	minor = maxi(0, version_minor)
	patch = maxi(0, version_patch)
	prerelease = version_prerelease
	build_metadata = version_build_metadata


## Parses a SemVer 2.0.0 string. A conventional leading "v" is accepted.
##
## Returns null for malformed versions.
static func parse(value: String) -> NucleusSemanticVersion:
	var candidate: String = value.strip_edges()

	if candidate.begins_with("v"):
		candidate = candidate.substr(1)

	if candidate.is_empty():
		return null

	var parsed_build_metadata: String = ""
	var build_separator: int = candidate.find("+")

	if build_separator != -1:
		if candidate.find("+", build_separator + 1) != -1:
			return null

		parsed_build_metadata = candidate.substr(build_separator + 1)
		candidate = candidate.substr(0, build_separator)

		if not _is_valid_identifier_list(
			parsed_build_metadata,
			false,
		):
			return null

	var parsed_prerelease: String = ""
	var prerelease_separator: int = candidate.find("-")

	if prerelease_separator != -1:
		parsed_prerelease = candidate.substr(prerelease_separator + 1)
		candidate = candidate.substr(0, prerelease_separator)

		if not _is_valid_identifier_list(
			parsed_prerelease,
			true,
		):
			return null

	var parts: PackedStringArray = candidate.split(".")

	if parts.size() != 3:
		return null

	for part: String in parts:
		if not _is_valid_core_number(part):
			return null

	return NucleusSemanticVersion.new(
		parts[0].to_int(),
		parts[1].to_int(),
		parts[2].to_int(),
		parsed_prerelease,
		parsed_build_metadata,
	)


## Returns -1, 0, or 1 using SemVer precedence rules.
func compare_to(other: NucleusSemanticVersion) -> int:
	if other == null:
		return 1

	if major != other.major:
		return -1 if major < other.major else 1

	if minor != other.minor:
		return -1 if minor < other.minor else 1

	if patch != other.patch:
		return -1 if patch < other.patch else 1

	return _compare_prerelease(
		prerelease,
		other.prerelease,
	)


func equals(other: NucleusSemanticVersion) -> bool:
	if other == null:
		return false

	return (
		major == other.major
		and minor == other.minor
		and patch == other.patch
		and prerelease == other.prerelease
		and build_metadata == other.build_metadata
	)


func has_same_precedence(
	other: NucleusSemanticVersion,
) -> bool:
	return compare_to(other) == 0


func is_less_than(other: NucleusSemanticVersion) -> bool:
	return compare_to(other) < 0


func is_greater_than(other: NucleusSemanticVersion) -> bool:
	return compare_to(other) > 0


func _to_string() -> String:
	var result: String = "%d.%d.%d" % [
		major,
		minor,
		patch,
	]

	if not prerelease.is_empty():
		result += "-" + prerelease

	if not build_metadata.is_empty():
		result += "+" + build_metadata

	return result


static func _compare_prerelease(
	left: String,
	right: String,
) -> int:
	if left.is_empty() and right.is_empty():
		return 0

	if left.is_empty():
		return 1

	if right.is_empty():
		return -1

	var left_parts: PackedStringArray = left.split(".")
	var right_parts: PackedStringArray = right.split(".")
	var shared_length: int = mini(
		left_parts.size(),
		right_parts.size(),
	)

	for index: int in range(shared_length):
		var left_identifier: String = left_parts[index]
		var right_identifier: String = right_parts[index]

		if left_identifier == right_identifier:
			continue

		var left_numeric: bool = left_identifier.is_valid_int()
		var right_numeric: bool = right_identifier.is_valid_int()

		if left_numeric and right_numeric:
			var left_value: int = left_identifier.to_int()
			var right_value: int = right_identifier.to_int()

			return -1 if left_value < right_value else 1

		if left_numeric != right_numeric:
			return -1 if left_numeric else 1

		return (
			-1
			if left_identifier < right_identifier
			else 1
		)

	if left_parts.size() == right_parts.size():
		return 0

	return -1 if left_parts.size() < right_parts.size() else 1


static func _is_valid_core_number(value: String) -> bool:
	if value.is_empty() or not value.is_valid_int():
		return false

	if value.length() > 1 and value.begins_with("0"):
		return false

	return value.to_int() >= 0


static func _is_valid_identifier_list(
	value: String,
	reject_numeric_leading_zero: bool,
) -> bool:
	if value.is_empty():
		return false

	for identifier: String in value.split("."):
		if identifier.is_empty():
			return false

		for character: String in identifier:
			if not _is_identifier_character(character):
				return false

		if (
			reject_numeric_leading_zero
			and identifier.is_valid_int()
			and identifier.length() > 1
			and identifier.begins_with("0")
		):
			return false

	return true


static func _is_identifier_character(
	character: String,
) -> bool:
	var code: int = character.unicode_at(0)

	return (
		(code >= 48 and code <= 57)
		or (code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or character == "-"
	)
