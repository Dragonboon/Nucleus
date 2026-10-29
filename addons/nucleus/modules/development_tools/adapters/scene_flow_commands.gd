class_name NucleusSceneFlowDevelopmentCommands
extends Node
## Development commands that route scene operations through NucleusSceneFlow.

@export var registry_path: NodePath = NodePath("../Registry")

var _registry: NucleusDevelopmentCommandRegistry
var _scene_flow: NucleusSceneFlowService
var _registered_ids: Array[StringName] = []


func _ready() -> void:
	_registry = get_node_or_null(registry_path) as NucleusDevelopmentCommandRegistry
	_scene_flow = get_node_or_null("/root/NucleusSceneFlow") as NucleusSceneFlowService
	if _registry == null or _scene_flow == null:
		push_warning("SceneFlowDevelopmentCommands requires Registry and NucleusSceneFlow.")
		return

	_register(
		NucleusDevelopmentCommand.build(
			&"scene.current",
			"Show current scene",
			Callable(self, "_current_scene"),
			"Prints the current SceneTree scene resource path.",
			&"Scene",
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"scene.reload",
			"Reload current scene",
			Callable(self, "_reload_scene"),
			"Reloads the current scene through NucleusSceneFlow.",
			&"Scene",
			[],
			PackedStringArray(["reload"]),
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"scene.goto",
			"Change scene",
			Callable(self, "_goto_scene"),
			"Loads a res:// PackedScene through NucleusSceneFlow.",
			&"Scene",
			[
				NucleusDevelopmentCommandArgument.build(
					&"path",
					TYPE_STRING,
					"res:// path to a PackedScene.",
				),
			],
			PackedStringArray(["goto"]),
		)
	)


func _exit_tree() -> void:
	if _registry == null:
		return
	for id: StringName in _registered_ids:
		_registry.unregister_command(id)


func _register(command: NucleusDevelopmentCommand) -> void:
	if _registry.register_command(command) == OK:
		_registered_ids.append(command.id)


func _current_scene(
	_arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var path := _scene_flow.get_current_scene_path()
	if path.is_empty():
		return NucleusDevelopmentCommandResult.warning("No current scene path.")
	return NucleusDevelopmentCommandResult.success(path)


func _reload_scene(
	_arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var path := _scene_flow.get_current_scene_path()
	var error := _scene_flow.reload_current_scene()
	if error != OK:
		return NucleusDevelopmentCommandResult.failure(
			"Unable to reload '%s': %s" % [path, error_string(error)]
		)
	return NucleusDevelopmentCommandResult.success("Reloading %s" % path)


func _goto_scene(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var path := str(arguments[0])
	var error := _scene_flow.change_scene(path)
	if error != OK:
		return NucleusDevelopmentCommandResult.failure(
			"Unable to load '%s': %s" % [path, error_string(error)]
		)
	return NucleusDevelopmentCommandResult.success("Loading %s" % path)
