class_name NucleusContentPackLoader
extends RefCounted
## Sole Nucleus owner of ProjectSettings.load_resource_pack().
##
## Additive DLC/trusted-mod packs never replace existing res:// paths. Patch
## packs are intentionally exposed through a separate early-boot method.

static func mount_verified_additive(verification: Dictionary) -> bool:
	if not _is_verified(verification):
		return false

	var manifest: NucleusContentPackManifest = verification.manifest
	if manifest.kind == NucleusContentPackTypes.Kind.PATCH:
		return false

	return ProjectSettings.load_resource_pack(
		str(verification.archive_path),
		false,
	)


static func mount_verified_patch(verification: Dictionary) -> bool:
	if not _is_verified(verification):
		return false

	var manifest: NucleusContentPackManifest = verification.manifest
	if manifest.kind != NucleusContentPackTypes.Kind.PATCH:
		return false

	return ProjectSettings.load_resource_pack(
		str(verification.archive_path),
		true,
	)


static func _is_verified(verification: Dictionary) -> bool:
	return (
		bool(verification.get("verified", false))
		and int(verification.get("error", ERR_INVALID_DATA)) == OK
		and verification.get("manifest") is NucleusContentPackManifest
		and not str(verification.get("archive_path", "")).is_empty()
	)
