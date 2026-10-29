class_name NucleusContentPackManager
extends Node
## Optional runtime owner for additive DLC and trusted resource packs.
##
## Patches are rejected here because replacements must mount during an explicit
## early bootstrap before affected resources are preloaded.

signal pack_mounted(record: NucleusContentPackRecord)
signal pack_failed(pack_id: StringName, error: int, message: String)

@export var policy: NucleusContentPackPolicy

var entitlement_checker: Callable
var registry := NucleusContentPackRegistry.new()


func _ready() -> void:
	if policy == null:
		policy = NucleusContentPackPolicy.new()


func set_entitlement_checker(checker: Callable) -> void:
	entitlement_checker = checker


func mount_official(
	archive_path: String,
	manifest_path: String,
	signature_path: String,
) -> Error:
	var verification: Dictionary = _verify_descriptor(
		archive_path,
		manifest_path,
		signature_path,
	)
	return _mount_verification(verification)


func mount_batch(descriptors: Array[Dictionary]) -> Dictionary:
	var results: Dictionary = {}
	var pending: Dictionary[StringName, Dictionary] = {}

	for descriptor: Dictionary in descriptors:
		var verification: Dictionary = _verify_descriptor(
			str(descriptor.get("archive_path", "")),
			str(descriptor.get("manifest_path", "")),
			str(descriptor.get("signature_path", "")),
		)
		if int(verification.get("error", ERR_INVALID_DATA)) != OK:
			var unknown_id := StringName(
				str(descriptor.get("pack_id", "<unknown>"))
			)
			results[unknown_id] = verification
			continue

		var manifest: NucleusContentPackManifest = verification.manifest
		if pending.has(manifest.pack_id) or registry.has_pack(manifest.pack_id):
			results[manifest.pack_id] = {
				"error": ERR_ALREADY_EXISTS,
				"message": "Duplicate content-pack id.",
			}
			continue

		pending[manifest.pack_id] = verification

	while not pending.is_empty():
		var progressed: bool = false
		var ids: Array[StringName] = pending.keys()
		ids.sort_custom(
			func(left: StringName, right: StringName) -> bool:
				return str(left) < str(right)
		)

		for pack_id: StringName in ids:
			var verification: Dictionary = pending[pack_id]
			var manifest: NucleusContentPackManifest = verification.manifest

			if not _dependencies_ready(manifest, pending):
				continue

			var error: Error = _mount_verification(verification)
			results[pack_id] = {
				"error": error,
				"message": "" if error == OK else "Mount failed.",
			}
			pending.erase(pack_id)
			progressed = true

		if not progressed:
			for unresolved_id: StringName in pending.keys():
				results[unresolved_id] = {
					"error": ERR_CYCLIC_LINK,
					"message": "Unresolved or cyclic content-pack dependencies.",
				}
			break

	return results


func _verify_descriptor(
	archive_path: String,
	manifest_path: String,
	signature_path: String,
) -> Dictionary:
	if policy == null:
		policy = NucleusContentPackPolicy.new()

	return NucleusContentPackVerifier.verify(
		archive_path,
		manifest_path,
		signature_path,
		policy.public_key_path,
		policy.resolve_game_version(),
	)


func _mount_verification(verification: Dictionary) -> Error:
	var verification_error: Error = verification.get(
		"error",
		ERR_INVALID_DATA,
	)
	if verification_error != OK:
		_emit_verification_failure(verification)
		return verification_error

	var manifest: NucleusContentPackManifest = verification.manifest

	if manifest.kind == NucleusContentPackTypes.Kind.PATCH:
		pack_failed.emit(
			manifest.pack_id,
			ERR_UNAVAILABLE,
			"Patches must mount during early bootstrap.",
		)
		return ERR_UNAVAILABLE

	if (
		manifest.kind == NucleusContentPackTypes.Kind.TRUSTED_MOD
		and not policy.allow_trusted_mod_packs
	):
		pack_failed.emit(
			manifest.pack_id,
			ERR_UNAUTHORIZED,
			"Trusted executable mod packs are disabled by policy.",
		)
		return ERR_UNAUTHORIZED

	if registry.has_pack(manifest.pack_id):
		return ERR_ALREADY_EXISTS

	var dependency_error: Error = _validate_dependencies(manifest)
	if dependency_error != OK:
		pack_failed.emit(
			manifest.pack_id,
			dependency_error,
			"Required content-pack dependency is not mounted.",
		)
		return dependency_error

	if not _has_entitlement(manifest):
		pack_failed.emit(
			manifest.pack_id,
			ERR_UNAUTHORIZED,
			"Required content entitlement is unavailable.",
		)
		return ERR_UNAUTHORIZED

	if not NucleusContentPackLoader.mount_verified_additive(verification):
		pack_failed.emit(
			manifest.pack_id,
			ERR_CANT_OPEN,
			"Godot could not mount the verified resource pack.",
		)
		return ERR_CANT_OPEN

	var record := NucleusContentPackRecord.new(
		manifest,
		str(verification.archive_path),
		str(verification.manifest_path),
		str(verification.signature_path),
	)
	record.mounted = true

	var register_error: Error = registry.register(record)
	if register_error != OK:
		return register_error

	pack_mounted.emit(record)
	return OK


func _validate_dependencies(
	manifest: NucleusContentPackManifest,
) -> Error:
	for dependency: String in manifest.dependencies:
		if not registry.has_pack(StringName(dependency)):
			return ERR_DOES_NOT_EXIST

	return OK


func _dependencies_ready(
	manifest: NucleusContentPackManifest,
	pending: Dictionary[StringName, Dictionary],
) -> bool:
	for dependency: String in manifest.dependencies:
		var dependency_id := StringName(dependency)
		if registry.has_pack(dependency_id):
			continue
		if pending.has(dependency_id):
			return false
		return false

	return true


func _has_entitlement(
	manifest: NucleusContentPackManifest,
) -> bool:
	if manifest.entitlement_id == &"":
		return true

	if not entitlement_checker.is_valid():
		return false

	return bool(entitlement_checker.call(manifest.entitlement_id))


func _emit_verification_failure(verification: Dictionary) -> void:
	var message: String = str(
		verification.get("message", "Content-pack verification failed.")
	)
	pack_failed.emit(
		&"",
		int(verification.get("error", ERR_INVALID_DATA)),
		message,
	)
