@tool
extends EditorPlugin
## Registers the existing six services without replacing host project policy.

const AUTOLOADS: Dictionary = {
	"NucleusApp": "res://addons/nucleus/core/application/application.gd",
	"NucleusSettings": "res://addons/nucleus/core/settings/settings.tscn",
	"NucleusInput": "res://addons/nucleus/core/input/input_service.gd",
	"NucleusAudio": "res://addons/nucleus/core/audio/audio.tscn",
	"NucleusSave": "res://addons/nucleus/core/save/save.tscn",
	"NucleusSceneFlow": "res://addons/nucleus/core/scene_flow/scene_flow_service.gd",
}
const OWNED_SETTING: String = "nucleus/editor/owned_autoloads"


func _enable_plugin() -> void:
	# Check the entire set before writing anything: no partially installed core.
	var conflicts: PackedStringArray = get_autoload_conflicts()
	if not conflicts.is_empty():
		push_error("Nucleus: Autoload conflicts: " + ", ".join(conflicts))
		call_deferred("_reject_activation")
		return
	var owned: Dictionary = ProjectSettings.get_setting(OWNED_SETTING, {}).duplicate()
	for service: String in AUTOLOADS:
		var key: String = "autoload/" + service
		if ProjectSettings.has_setting(key):
			continue
		add_autoload_singleton(service, AUTOLOADS[service])
		owned[service] = ProjectSettings.get_setting(key)
	ProjectSettings.set_setting(OWNED_SETTING, owned)
	ProjectSettings.save()


func _disable_plugin() -> void:
	# Persisted ownership survives editor restarts. Adopted or replaced entries stay.
	var owned: Dictionary = ProjectSettings.get_setting(OWNED_SETTING, {})
	var services: Array = owned.keys()
	services.reverse()
	for service: String in services:
		var key: String = "autoload/" + service
		if (AUTOLOADS.has(service)
				and ProjectSettings.get_setting(key, "") == owned[service]
				and matches_service(owned[service], AUTOLOADS[service])):
			remove_autoload_singleton(service)
	ProjectSettings.set_setting(OWNED_SETTING, null)
	ProjectSettings.save()


func get_autoload_conflicts() -> PackedStringArray:
	var conflicts: PackedStringArray = []
	for service: String in AUTOLOADS:
		var key: String = "autoload/" + service
		if (ProjectSettings.has_setting(key)
				and not matches_service(ProjectSettings.get_setting(key), AUTOLOADS[service])):
			conflicts.append(service)
	return conflicts


func _build() -> bool:
	for service: String in AUTOLOADS:
		if not matches_service(
			ProjectSettings.get_setting("autoload/" + service, ""), AUTOLOADS[service]
		):
			push_error("Nucleus: enable the addon and resolve Autoload " + service)
			return false
	return true


func _reject_activation() -> void:
	EditorInterface.set_plugin_enabled("nucleus", false)


static func matches_service(value: String, expected_path: String) -> bool:
	if not value.begins_with("*"):
		return false
	var path: String = value.substr(1)
	if path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(path)
		if not ResourceUID.has_id(id):
			return false
		path = ResourceUID.get_id_path(id)
	return path == expected_path
