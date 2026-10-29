class_name NucleusSavePaths
extends RefCounted
## Deterministic save path generation and slot id sanitization.


static func sanitize_slot_id(slot_id: String) -> String:
	var normalized: String = slot_id.strip_edges().to_lower()
	normalized = normalized.replace(" ", "_")

	var regex := RegEx.new()

	if regex.compile("[^a-z0-9_-]+") != OK:
		return ""

	normalized = regex.sub(normalized, "_", true)
	normalized = normalized.strip_edges().trim_prefix("_")
	normalized = normalized.trim_suffix("_")

	return normalized.left(64)


static func slot_directory(
	base_directory: String,
	slot_id: String,
) -> String:
	return base_directory.path_join(sanitize_slot_id(slot_id))


static func autosave_directory(
	base_directory: String,
	slot_id: String,
) -> String:
	return slot_directory(base_directory, slot_id).path_join(
		"autosaves"
	)


static func manual_path(
	profile: NucleusSaveProfile,
	slot_id: String,
	codec: NucleusSaveCodec,
	encryption_mode: int,
) -> String:
	return slot_directory(
		profile.base_directory,
		slot_id,
	).path_join(
		"manual.%s%s"
		% [
			codec.get_extension(),
			security_suffix(encryption_mode),
		]
	)


static func quicksave_path(
	profile: NucleusSaveProfile,
	slot_id: String,
	codec: NucleusSaveCodec,
	encryption_mode: int,
) -> String:
	return slot_directory(
		profile.base_directory,
		slot_id,
	).path_join(
		"quick.%s%s"
		% [
			codec.get_extension(),
			security_suffix(encryption_mode),
		]
	)


static func autosave_path(
	profile: NucleusSaveProfile,
	slot_id: String,
	codec: NucleusSaveCodec,
	encryption_mode: int,
	timestamp_ms: int,
) -> String:
	return autosave_directory(
		profile.base_directory,
		slot_id,
	).path_join(
		"auto_%d.%s%s"
		% [
			timestamp_ms,
			codec.get_extension(),
			security_suffix(encryption_mode),
		]
	)


static func security_suffix(encryption_mode: int) -> String:
	match encryption_mode:
		NucleusSaveTypes.Encryption.PASSWORD:
			return ".pwd"

		NucleusSaveTypes.Encryption.RAW_KEY:
			return ".key"

		_:
			return ""


static func encryption_from_path(path: String) -> int:
	if path.ends_with(".pwd"):
		return NucleusSaveTypes.Encryption.PASSWORD

	if path.ends_with(".key"):
		return NucleusSaveTypes.Encryption.RAW_KEY

	return NucleusSaveTypes.Encryption.NONE


static func codec_extension_from_path(path: String) -> String:
	var normalized: String = path

	if normalized.ends_with(".pwd") or normalized.ends_with(".key"):
		normalized = normalized.get_basename()

	return normalized.get_extension()
