class_name NucleusContentPackRecord
extends RefCounted
## Runtime record for one successfully mounted trusted content pack.

var manifest: NucleusContentPackManifest
var archive_path: String
var manifest_path: String
var signature_path: String
var mounted: bool = false


func _init(
	pack_manifest: NucleusContentPackManifest = null,
	pack_archive_path: String = "",
	pack_manifest_path: String = "",
	pack_signature_path: String = "",
) -> void:
	manifest = pack_manifest
	archive_path = pack_archive_path
	manifest_path = pack_manifest_path
	signature_path = pack_signature_path


func get_pack_id() -> StringName:
	return manifest.pack_id if manifest else &""
