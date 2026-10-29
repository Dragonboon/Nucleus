class_name NucleusDevelopmentDefaultCommands
extends Node
## Framework-owned commands that are useful in every Nucleus development shell.

@export var registry_path: NodePath = NodePath("../Registry")

var _registry: NucleusDevelopmentCommandRegistry
var _registered_ids: Array[StringName] = []


func _ready() -> void:
	_registry = get_node_or_null(registry_path) as NucleusDevelopmentCommandRegistry
	if _registry == null:
		push_warning("DevelopmentDefaultCommands requires a command registry.")
		return

	_register(
		NucleusDevelopmentCommand.build(
			&"dev.context",
			"Show runtime context",
			Callable(self, "_context"),
			"Shows scene, Godot, OS, renderer, and editor-embedding context.",
			&"Development",
			[],
			PackedStringArray(["context"]),
			PackedStringArray(["runtime", "environment"]),
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"dev.help",
			"List matching commands",
			Callable(self, "_help"),
			"Lists command IDs and usage, optionally filtered by a search term.",
			&"Development",
			[
				NucleusDevelopmentCommandArgument.build(
					&"query",
					TYPE_STRING,
					"Optional command search term.",
					true,
					"",
				),
			],
			PackedStringArray(["help"]),
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"dev.history.clear",
			"Clear command history",
			Callable(self, "_clear_history"),
			"Clears the in-memory development command execution history.",
			&"Development",
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


func _context(
	_arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var scene_path := ""
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	if scene_path.is_empty():
		scene_path = "<none>"
	var renderer := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	)
	var version := Engine.get_version_info()
	var message := "\n".join(PackedStringArray([
		"Scene: %s" % scene_path,
		"Godot: %s" % str(version.get("string", "unknown")),
		"OS: %s" % OS.get_name(),
		"Renderer: %s" % renderer,
		"Editor embedded: %s" % str(Engine.is_embedded_in_editor()),
	]))
	return NucleusDevelopmentCommandResult.success(message)


func _help(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var query := str(arguments[0]) if not arguments.is_empty() else ""
	var commands := _registry.search(query, 50)
	if commands.is_empty():
		return NucleusDevelopmentCommandResult.warning("No matching commands.")
	var lines := PackedStringArray()
	for command: NucleusDevelopmentCommand in commands:
		lines.append("%s — %s" % [command.usage(), command.title])
	return NucleusDevelopmentCommandResult.success("\n".join(lines))


func _clear_history(
	_arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	_registry.clear_history()
	return NucleusDevelopmentCommandResult.success("Command history cleared.")
