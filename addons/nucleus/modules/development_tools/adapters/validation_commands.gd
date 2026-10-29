class_name NucleusDevelopmentValidationCommands
extends Node
## Development-command bridge for the shared validation backend.

@export var registry_path: NodePath = NodePath("../Registry")

var _registry: NucleusDevelopmentCommandRegistry
var _registered_ids: Array[StringName] = []


func _ready() -> void:
	_registry = get_node_or_null(registry_path) as NucleusDevelopmentCommandRegistry
	if _registry == null:
		push_warning("DevelopmentValidationCommands requires a command registry.")
		return

	_register(NucleusDevelopmentCommand.build(
		&"validation.run",
		"Validate current scene or path",
		Callable(self, "_run"),
		"Validates the current scene, or a scene/resource path when provided.",
		&"Validation",
		[
			NucleusDevelopmentCommandArgument.build(
				&"path",
				TYPE_STRING,
				"Optional res:// scene or resource path.",
				true,
				"",
			),
		],
		PackedStringArray(["validate"]),
		PackedStringArray(["scene", "resource", "quality"]),
	))
	_register(NucleusDevelopmentCommand.build(
		&"validation.scene",
		"Validate scene",
		Callable(self, "_scene"),
		"Validates a PackedScene without adding it to the running SceneTree.",
		&"Validation",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
		],
		PackedStringArray(),
		PackedStringArray(["scene", "configuration warnings"]),
	))
	_register(NucleusDevelopmentCommand.build(
		&"validation.resource",
		"Validate resource",
		Callable(self, "_resource"),
		"Validates a Resource through its get_validation_errors() contract.",
		&"Validation",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
		],
		PackedStringArray(),
		PackedStringArray(["resource", "quality"]),
	))


func _exit_tree() -> void:
	if _registry == null:
		return
	for id: StringName in _registered_ids:
		_registry.unregister_command(id)


func _register(command: NucleusDevelopmentCommand) -> void:
	if _registry.register_command(command) == OK:
		_registered_ids.append(command.id)


func _run(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var path := str(arguments[0]).strip_edges() if not arguments.is_empty() else ""
	if path.is_empty():
		var current := get_tree().current_scene
		if current == null:
			return NucleusDevelopmentCommandResult.failure(
				"No current scene is available to validate."
			)
		return _result_from_report(
			NucleusDevelopmentValidation.validate_node_tree(current)
		)

	var loaded := ResourceLoader.load(path)
	if loaded is PackedScene:
		return _result_from_report(NucleusDevelopmentValidation.validate_scene(path))
	if loaded is Resource:
		return _result_from_report(
			NucleusDevelopmentValidation.validate_resource(path)
		)
	return NucleusDevelopmentCommandResult.failure(
		"Path does not resolve to a scene or Resource: %s" % path
	)


func _scene(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _result_from_report(
		NucleusDevelopmentValidation.validate_scene(str(arguments[0]))
	)


func _resource(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _result_from_report(
		NucleusDevelopmentValidation.validate_resource(str(arguments[0]))
	)


func _result_from_report(report: Dictionary) -> NucleusDevelopmentCommandResult:
	var message := NucleusDevelopmentValidation.format_report(report)
	if int(report.get("error_count", 0)) > 0:
		return NucleusDevelopmentCommandResult.failure(message, report)
	if int(report.get("warning_count", 0)) > 0:
		return NucleusDevelopmentCommandResult.warning(message, report)
	return NucleusDevelopmentCommandResult.success(message, report)
