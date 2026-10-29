class_name NucleusContentPackManifest
extends RefCounted
## Detached metadata for one trusted resource pack.
##
## The manifest is stored outside the PCK so it can be validated and signed
## before the pack is ever mounted into res://.

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var pack_id: StringName
var display_name: String
var version: String
var kind: int = -1
var minimum_game_version: String = ""
var maximum_game_version: String = ""
var dependencies: PackedStringArray = PackedStringArray()
var entitlement_id: StringName = &""
var resource_prefix: String = ""
var archive_sha256: String = ""


static func from_dictionary(data: Dictionary) -> NucleusContentPackManifest:
	var manifest := NucleusContentPackManifest.new()
	manifest.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	manifest.pack_id = StringName(str(data.get("pack_id", "")))
	manifest.display_name = str(data.get("display_name", ""))
	manifest.version = str(data.get("version", ""))
	manifest.kind = NucleusContentPackTypes.parse_kind(data.get("kind", -1))
	manifest.minimum_game_version = str(
		data.get("minimum_game_version", "")
	)
	manifest.maximum_game_version = str(
		data.get("maximum_game_version", "")
	)
	manifest.entitlement_id = StringName(
		str(data.get("entitlement_id", ""))
	)
	manifest.resource_prefix = str(data.get("resource_prefix", ""))
	manifest.archive_sha256 = str(data.get("archive_sha256", "")).to_lower()

	var raw_dependencies: Variant = data.get("dependencies", [])
	if typeof(raw_dependencies) == TYPE_ARRAY:
		for raw_dependency: Variant in raw_dependencies:
			manifest.dependencies.append(str(raw_dependency))

	return manifest


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"pack_id": str(pack_id),
		"display_name": display_name,
		"version": version,
		"kind": NucleusContentPackTypes.kind_to_string(kind),
		"minimum_game_version": minimum_game_version,
		"maximum_game_version": maximum_game_version,
		"dependencies": Array(dependencies),
		"entitlement_id": str(entitlement_id),
		"resource_prefix": resource_prefix,
		"archive_sha256": archive_sha256,
	}


func validate(require_archive_hash: bool = true) -> PackedStringArray:
	var errors := PackedStringArray()

	if schema_version != SCHEMA_VERSION:
		errors.append(
			"Unsupported content-pack manifest schema %d." % schema_version
		)

	if not is_valid_identifier(str(pack_id)):
		errors.append("pack_id must use lowercase [a-z0-9._-].")

	if display_name.strip_edges().is_empty():
		errors.append("display_name must not be empty.")

	if NucleusSemanticVersion.parse(version) == null:
		errors.append("version must be valid Semantic Versioning.")

	if kind not in NucleusContentPackTypes.Kind.values():
		errors.append("kind must be patch, dlc, or trusted_mod.")

	if not minimum_game_version.is_empty():
		if NucleusSemanticVersion.parse(minimum_game_version) == null:
			errors.append("minimum_game_version is not valid SemVer.")

	if not maximum_game_version.is_empty():
		if NucleusSemanticVersion.parse(maximum_game_version) == null:
			errors.append("maximum_game_version is not valid SemVer.")

	if (
		not minimum_game_version.is_empty()
		and not maximum_game_version.is_empty()
	):
		var minimum := NucleusSemanticVersion.parse(minimum_game_version)
		var maximum := NucleusSemanticVersion.parse(maximum_game_version)
		if minimum and maximum and minimum.is_greater_than(maximum):
			errors.append(
				"minimum_game_version cannot exceed maximum_game_version."
			)

	var seen_dependencies: Dictionary[String, bool] = {}
	for dependency: String in dependencies:
		if not is_valid_identifier(dependency):
			errors.append("Invalid dependency id '%s'." % dependency)
			continue
		if dependency == str(pack_id):
			errors.append("A content pack cannot depend on itself.")
		if seen_dependencies.has(dependency):
			errors.append("Duplicate dependency '%s'." % dependency)
		seen_dependencies[dependency] = true

	if kind in [
		NucleusContentPackTypes.Kind.DLC,
		NucleusContentPackTypes.Kind.TRUSTED_MOD,
	]:
		var expected_prefix: String = (
			"res://content/%s/" % str(pack_id)
		)
		if resource_prefix != expected_prefix:
			errors.append(
				"Additive packs must declare resource_prefix '%s'."
				% expected_prefix
			)

	if require_archive_hash and not _is_sha256_hex(archive_sha256):
		errors.append("archive_sha256 must be a 64-character SHA-256 hex digest.")

	return errors


func is_game_version_compatible(game_version: String) -> bool:
	var current := NucleusSemanticVersion.parse(game_version)
	if current == null:
		return false

	if not minimum_game_version.is_empty():
		var minimum := NucleusSemanticVersion.parse(minimum_game_version)
		if minimum and current.is_less_than(minimum):
			return false

	if not maximum_game_version.is_empty():
		var maximum := NucleusSemanticVersion.parse(maximum_game_version)
		if maximum and current.is_greater_than(maximum):
			return false

	return true


static func is_valid_identifier(value: String) -> bool:
	if value.is_empty():
		return false

	for character: String in value:
		var code: int = character.unicode_at(0)
		var allowed: bool = (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or character in [".", "_", "-"]
		)
		if not allowed:
			return false

	return true


static func _is_sha256_hex(value: String) -> bool:
	if value.length() != 64:
		return false

	for character: String in value.to_lower():
		var code: int = character.unicode_at(0)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 102)
		):
			return false

	return true
