class_name NucleusContentPackCompatibility
extends RefCounted
## Read-only comparison of trusted content-pack manifest inventories.
##
## This is a compatibility hint, not signature verification, entitlement,
## download permission, or an authority decision. The caller owns transport
## and validates remote data before creating manifests from it.

const MAX_PACKS: int = 256


## Compares required (e.g. server) and available (e.g. local) packs.
## Local extras fail by default: they may change game behavior. The game may
## opt out only when it can prove extras cannot affect the current session.
## Returns error, compatible, missing, mismatched, extra, and message.
static func compare(
	required: Array[NucleusContentPackManifest],
	available: Array[NucleusContentPackManifest],
	allow_extra_local: bool = false,
) -> Dictionary:
	if required.size() > MAX_PACKS or available.size() > MAX_PACKS:
		return _invalid("Content-pack inventory exceeds %d entries." % MAX_PACKS)

	var required_index: Dictionary = _make_index(required)
	if int(required_index["error"]) != OK:
		return _invalid(str(required_index["message"]))

	var available_index: Dictionary = _make_index(available)
	if int(available_index["error"]) != OK:
		return _invalid(str(available_index["message"]))

	var required_by_id: Dictionary = required_index["by_id"]
	var available_by_id: Dictionary = available_index["by_id"]
	var missing: Array[String] = []
	var mismatched: Array[Dictionary] = []
	var extra: Array[String] = []
	var required_ids: Array = required_by_id.keys()
	required_ids.sort()

	for pack_id: String in required_ids:
		var expected: NucleusContentPackManifest = required_by_id[pack_id]
		if not available_by_id.has(pack_id):
			missing.append(pack_id)
			continue

		var actual: NucleusContentPackManifest = available_by_id[pack_id]
		var differences: PackedStringArray = []
		if expected.version != actual.version:
			differences.append("version")
		if expected.archive_sha256.to_lower() != actual.archive_sha256.to_lower():
			differences.append("archive_sha256")
		if expected.kind != actual.kind:
			differences.append("kind")
		if expected.resource_prefix != actual.resource_prefix:
			differences.append("resource_prefix")
		var required_dependencies: Array = Array(expected.dependencies)
		var local_dependencies: Array = Array(actual.dependencies)
		required_dependencies.sort()
		local_dependencies.sort()
		if required_dependencies != local_dependencies:
			differences.append("dependencies")
		if expected.minimum_game_version != actual.minimum_game_version:
			differences.append("minimum_game_version")
		if expected.maximum_game_version != actual.maximum_game_version:
			differences.append("maximum_game_version")
		if expected.entitlement_id != actual.entitlement_id:
			differences.append("entitlement_id")

		if not differences.is_empty():
			mismatched.append({
				"pack_id": pack_id,
				"fields": differences,
			})

	var available_ids: Array = available_by_id.keys()
	available_ids.sort()
	for pack_id: String in available_ids:
		if not required_by_id.has(pack_id):
			extra.append(pack_id)

	return {
		"error": OK,
		"message": "",
		"compatible": (
			missing.is_empty()
			and mismatched.is_empty()
			and (allow_extra_local or extra.is_empty())
		),
		"missing": missing,
		"mismatched": mismatched,
		"extra": extra,
	}


static func _make_index(packs: Array[NucleusContentPackManifest]) -> Dictionary:
	var result: Dictionary = {}
	for pack: NucleusContentPackManifest in packs:
		if pack == null:
			return _invalid("Content-pack inventory contains a null manifest.")
		var errors: PackedStringArray = pack.validate(true)
		if not errors.is_empty():
			return _invalid(
				"Invalid manifest for '%s': %s"
				% [str(pack.pack_id), "; ".join(errors)]
			)
		var pack_id: String = str(pack.pack_id)
		if result.has(pack_id):
			return _invalid("Duplicate content-pack id '%s'." % pack_id)
		result[pack_id] = pack

	return {"error": OK, "message": "", "by_id": result}


static func _invalid(message: String) -> Dictionary:
	return {
		"error": ERR_INVALID_DATA,
		"message": message,
		"compatible": false,
		"missing": [],
		"mismatched": [],
		"extra": [],
	}
