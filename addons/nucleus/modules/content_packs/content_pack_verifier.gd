class_name NucleusContentPackVerifier
extends RefCounted
## Pre-mount verification for trusted official PCK/ZIP resource packs.
##
## Verification happens before the engine resource-pack mount boundary sees
## the archive.

const MAX_MANIFEST_BYTES: int = 64 * 1024
const MAX_SIGNATURE_BYTES: int = 16 * 1024


static func verify(
	archive_path: String,
	manifest_path: String,
	signature_path: String,
	public_key_path: String,
	game_version: String,
) -> Dictionary:
	if not FileAccess.file_exists(archive_path):
		return _failure(ERR_FILE_NOT_FOUND, "Archive does not exist.")

	if not FileAccess.file_exists(manifest_path):
		return _failure(ERR_FILE_NOT_FOUND, "Manifest does not exist.")

	if not FileAccess.file_exists(signature_path):
		return _failure(ERR_FILE_NOT_FOUND, "Signature does not exist.")

	if public_key_path.strip_edges().is_empty():
		return _failure(
			ERR_INVALID_PARAMETER,
			"A public verification key is required.",
		)

	var manifest_result: Dictionary = _read_bounded(
		manifest_path,
		MAX_MANIFEST_BYTES,
	)
	if manifest_result.error != OK:
		return manifest_result

	var manifest_bytes: PackedByteArray = manifest_result.bytes
	var parsed: Variant = JSON.parse_string(
		manifest_bytes.get_string_from_utf8()
	)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure(ERR_PARSE_ERROR, "Manifest must be a JSON object.")

	var manifest := NucleusContentPackManifest.from_dictionary(parsed)
	var manifest_errors: PackedStringArray = manifest.validate(true)
	if not manifest_errors.is_empty():
		return _failure(
			ERR_INVALID_DATA,
			"; ".join(manifest_errors),
		)

	if not game_version.strip_edges().is_empty():
		if not manifest.is_game_version_compatible(game_version):
			return _failure(
				ERR_UNAVAILABLE,
				"Content pack is incompatible with game version %s."
				% game_version,
			)

	var signature_result: Dictionary = _read_bounded(
		signature_path,
		MAX_SIGNATURE_BYTES,
	)
	if signature_result.error != OK:
		return signature_result

	var public_key := CryptoKey.new()
	var key_error: Error = public_key.load(public_key_path, true)
	if key_error != OK:
		return _failure(
			key_error,
			"Could not load public verification key.",
		)

	if not public_key.is_public_only():
		return _failure(
			ERR_INVALID_DATA,
			"Runtime verification key must be public-only.",
		)

	if not verify_signature(
		manifest_bytes,
		signature_result.bytes,
		public_key,
	):
		return _failure(
			ERR_UNAUTHORIZED,
			"Manifest signature verification failed.",
		)

	var archive_sha256: String = FileAccess.get_sha256(archive_path)
	if archive_sha256.is_empty():
		return _failure(ERR_CANT_OPEN, "Could not hash content-pack archive.")

	if archive_sha256.to_lower() != manifest.archive_sha256:
		return _failure(
			ERR_FILE_CORRUPT,
			"Archive SHA-256 does not match the signed manifest.",
		)

	return {
		"error": OK,
		"message": "",
		"verified": true,
		"manifest": manifest,
		"archive_path": archive_path,
		"manifest_path": manifest_path,
		"signature_path": signature_path,
	}


static func verify_signature(
	manifest_bytes: PackedByteArray,
	signature: PackedByteArray,
	public_key: CryptoKey,
) -> bool:
	if (
		manifest_bytes.is_empty()
		or signature.is_empty()
		or public_key == null
	):
		return false

	var context := HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return false

	var update_error: Error = context.update(manifest_bytes)
	if update_error != OK:
		return false

	var manifest_hash: PackedByteArray = context.finish()
	var crypto := Crypto.new()

	return crypto.verify(
		HashingContext.HASH_SHA256,
		manifest_hash,
		signature,
		public_key,
	)


static func _read_bounded(
	path: String,
	maximum_bytes: int,
) -> Dictionary:
	var size: int = FileAccess.get_size(path)
	if size < 0:
		return _failure(ERR_CANT_OPEN, "Could not inspect '%s'." % path)

	if size > maximum_bytes:
		return _failure(
			ERR_INVALID_DATA,
			"File '%s' exceeds the allowed size." % path,
		)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(FileAccess.get_open_error(), "Could not open '%s'." % path)

	var bytes: PackedByteArray = file.get_buffer(size)
	file.close()

	if bytes.size() != size:
		return _failure(ERR_FILE_CORRUPT, "Short read from '%s'." % path)

	return {
		"error": OK,
		"message": "",
		"bytes": bytes,
	}


static func _failure(error: Error, message: String) -> Dictionary:
	return {
		"error": error,
		"message": message,
		"verified": false,
	}
