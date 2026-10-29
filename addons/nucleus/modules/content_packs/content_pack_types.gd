class_name NucleusContentPackTypes
extends RefCounted
## Shared enums and labels for trusted Godot resource packs.


enum Kind {
	PATCH,
	DLC,
	TRUSTED_MOD,
}


static func kind_to_string(kind: int) -> String:
	match kind:
		Kind.PATCH:
			return "patch"
		Kind.DLC:
			return "dlc"
		Kind.TRUSTED_MOD:
			return "trusted_mod"
		_:
			return "unknown"


static func parse_kind(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var numeric: int = int(value)
		return numeric if numeric in Kind.values() else -1

	var normalized: String = str(value).strip_edges().to_lower()

	match normalized:
		"patch":
			return Kind.PATCH
		"dlc":
			return Kind.DLC
		"trusted_mod":
			return Kind.TRUSTED_MOD
		_:
			return -1
