class_name NucleusContentPackPolicy
extends Resource
## Runtime policy for trusted official DLC/PCK loading.
##
## Private signing keys never belong here. Only a public verification key is
## consumed by runtime code.

@export_file("*.pub") var public_key_path: String = ""
@export var game_version: String = ""
@export var allow_trusted_mod_packs: bool = false


func resolve_game_version() -> String:
	if not game_version.strip_edges().is_empty():
		return game_version.strip_edges()

	return str(
		ProjectSettings.get_setting(
			"application/config/version",
			"0.0.0",
		)
	)
