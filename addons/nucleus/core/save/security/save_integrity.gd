class_name NucleusSaveIntegrity
extends RefCounted
## SHA-256 corruption detection with optional HMAC-SHA256 authentication.

const CHECKSUM_KEY: String = "sha256"
const HMAC_KEY: String = "hmac_sha256"


static func sign_document(
	document: NucleusSaveDocument,
	authentication_key: PackedByteArray = PackedByteArray(),
) -> void:
	var bytes: PackedByteArray = _canonical_bytes(
		document.to_dictionary(false)
	)

	document.integrity = {
		CHECKSUM_KEY: _sha256(bytes).hex_encode(),
	}

	if not authentication_key.is_empty():
		var crypto := Crypto.new()
		var digest: PackedByteArray = crypto.hmac_digest(
			HashingContext.HASH_SHA256,
			authentication_key,
			bytes,
		)
		document.integrity[HMAC_KEY] = digest.hex_encode()


static func verify_document(
	document: NucleusSaveDocument,
	authentication_key: PackedByteArray = PackedByteArray(),
) -> Error:
	var expected_checksum: String = str(
		document.integrity.get(CHECKSUM_KEY, "")
	)

	if expected_checksum.is_empty():
		return ERR_FILE_CORRUPT

	var bytes: PackedByteArray = _canonical_bytes(
		document.to_dictionary(false)
	)
	var actual_checksum: String = _sha256(bytes).hex_encode()

	if actual_checksum != expected_checksum:
		return ERR_FILE_CORRUPT

	var expected_hmac: String = str(
		document.integrity.get(HMAC_KEY, "")
	)

	if expected_hmac.is_empty():
		return OK

	if authentication_key.is_empty():
		return ERR_UNCONFIGURED

	var crypto := Crypto.new()
	var actual_hmac: String = crypto.hmac_digest(
		HashingContext.HASH_SHA256,
		authentication_key,
		bytes,
	).hex_encode()

	return OK if actual_hmac == expected_hmac else ERR_FILE_CORRUPT


static func _canonical_bytes(value: Variant) -> PackedByteArray:
	return var_to_bytes(_canonicalize(value))


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()

		keys.sort_custom(
			func(left: Variant, right: Variant) -> bool:
				return str(left) < str(right)
		)

		for key: Variant in keys:
			result[str(key)] = _canonicalize(value[key])

		return result

	if value is Array:
		var result: Array = []

		for child: Variant in value:
			result.append(_canonicalize(child))

		return result

	return value


static func _sha256(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	var start_error: Error = context.start(
		HashingContext.HASH_SHA256
	)

	if start_error != OK:
		return PackedByteArray()

	var update_error: Error = context.update(bytes)

	if update_error != OK:
		return PackedByteArray()

	return context.finish()
