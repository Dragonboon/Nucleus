class_name NucleusSaveSecurity
extends RefCounted
## Runtime-only save credentials.
##
## Passwords and keys are intentionally never Resources and never persisted.

const INTEGRITY_CONTEXT: String = "NucleusSaveIntegrity:"

var last_error: Error = OK

var _password: String = ""
var _raw_key: PackedByteArray = PackedByteArray()


func configure_password(password: String) -> Error:
	if password.is_empty():
		return ERR_INVALID_PARAMETER

	_password = password
	_raw_key.clear()

	return OK


func configure_raw_key(key: PackedByteArray) -> Error:
	if key.size() != 32:
		return ERR_INVALID_PARAMETER

	_raw_key = key.duplicate()
	_password = ""

	return OK


func clear_credentials() -> void:
	_password = ""
	_raw_key.fill(0)
	_raw_key.clear()


func has_credentials(encryption_mode: int) -> bool:
	match encryption_mode:
		NucleusSaveTypes.Encryption.NONE:
			return true

		NucleusSaveTypes.Encryption.PASSWORD:
			return not _password.is_empty()

		NucleusSaveTypes.Encryption.RAW_KEY:
			return _raw_key.size() == 32

		_:
			return false


func open_file(
	path: String,
	mode_flags: FileAccess.ModeFlags,
	encryption_mode: int,
) -> FileAccess:
	last_error = OK

	match encryption_mode:
		NucleusSaveTypes.Encryption.NONE:
			var file := FileAccess.open(path, mode_flags)
			last_error = FileAccess.get_open_error()
			return file

		NucleusSaveTypes.Encryption.PASSWORD:
			if _password.is_empty():
				last_error = ERR_UNCONFIGURED
				return null

			var file := FileAccess.open_encrypted_with_pass(
				path,
				mode_flags,
				_password,
			)
			last_error = FileAccess.get_open_error()
			return file

		NucleusSaveTypes.Encryption.RAW_KEY:
			if _raw_key.size() != 32:
				last_error = ERR_UNCONFIGURED
				return null

			var file := FileAccess.open_encrypted(
				path,
				mode_flags,
				_raw_key,
			)
			last_error = FileAccess.get_open_error()
			return file

		_:
			last_error = ERR_INVALID_PARAMETER
			return null


func get_authentication_key(
	encryption_mode: int,
) -> PackedByteArray:
	match encryption_mode:
		NucleusSaveTypes.Encryption.PASSWORD:
			if _password.is_empty():
				return PackedByteArray()

			return _derive_integrity_key(
				_password.to_utf8_buffer()
			)

		NucleusSaveTypes.Encryption.RAW_KEY:
			if _raw_key.size() != 32:
				return PackedByteArray()

			return _derive_integrity_key(_raw_key)

		_:
			return PackedByteArray()


func _derive_integrity_key(
	secret: PackedByteArray,
) -> PackedByteArray:
	var input := INTEGRITY_CONTEXT.to_utf8_buffer()
	input.append_array(secret)

	var context := HashingContext.new()

	if context.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()

	if context.update(input) != OK:
		return PackedByteArray()

	return context.finish()
