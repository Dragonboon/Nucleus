@tool
extends EditorPlugin
## Isolated host integration probe; driven by check_addon_installation.py.

const PluginScript = preload("res://addons/nucleus/plugin.gd")
var _failures: PackedStringArray = []


func _enter_tree() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in 10:
		await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	var phase: int = ProjectSettings.get_setting("probe/phase", 0)
	if phase == 0:
		EditorInterface.set_plugin_enabled("nucleus", true)
		_check_services()
		EditorInterface.set_plugin_enabled("nucleus_localization", true)
		_check(ProjectSettings.get_setting(PluginScript.OWNED_SETTING, {}).size() == 6,
			"Activation owns six new services.")
		ProjectSettings.set_setting("probe/phase", 1)
	else:
		EditorInterface.set_plugin_enabled("nucleus_localization", false)
		_check_services()
		EditorInterface.set_plugin_enabled("nucleus", false)
		for service: String in PluginScript.AUTOLOADS:
			_check(not ProjectSettings.has_setting("autoload/" + service),
				"Disable removes owned service after editor restart: " + service)
		# Pre-existing entries must be adopted, never removed on uninstall.
		var app_key: String = "autoload/NucleusApp"
		var app_path: String = "*" + str(PluginScript.AUTOLOADS["NucleusApp"])
		ProjectSettings.set_setting(app_key, app_path)
		EditorInterface.set_plugin_enabled("nucleus", true)
		_check(ProjectSettings.get_setting(PluginScript.OWNED_SETTING, {}).size() == 5,
			"Activation adopts pre-existing matching service.")
		EditorInterface.set_plugin_enabled("nucleus", false)
		_check(ProjectSettings.get_setting(app_key, "") == app_path,
			"Disable preserves pre-existing entry.")
		ProjectSettings.set_setting(app_key, null)
		EditorInterface.set_plugin_enabled("nucleus", true)
		ProjectSettings.set_setting(app_key, "*res://host.gd")
		var probe: EditorPlugin = PluginScript.new()
		_check(probe.get_autoload_conflicts().has("NucleusApp"),
			"Conflict preflight identifies host service.")
		probe.free()
		EditorInterface.set_plugin_enabled("nucleus", false)
		_check(ProjectSettings.get_setting(app_key, "") == "*res://host.gd",
			"Disable preserves user replacement.")
		# Negative activation: conflict must leave all other entries absent.
		EditorInterface.set_plugin_enabled("nucleus", true)
		for index in 3:
			await get_tree().process_frame
		_check(not EditorInterface.is_plugin_enabled("nucleus"),
			"Conflict rejects activation.")
		for service: String in PluginScript.AUTOLOADS:
			if service != "NucleusApp":
				_check(not ProjectSettings.has_setting("autoload/" + service),
					"Conflict leaves no partial core: " + service)
	ProjectSettings.save()
	for failure: String in _failures:
		push_error(failure)
	print("Nucleus addon installation phase %s: %s" % [phase,
		"PASS" if _failures.is_empty() else "FAIL"])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_services() -> void:
	for service: String in PluginScript.AUTOLOADS:
		_check(PluginScript.matches_service(
			ProjectSettings.get_setting("autoload/" + service, ""),
			PluginScript.AUTOLOADS[service]), "Registered " + service)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
