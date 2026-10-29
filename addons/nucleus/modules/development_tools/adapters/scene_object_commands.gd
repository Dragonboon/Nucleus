class_name NucleusSceneObjectDevelopmentCommands
extends Node
## Command-palette bridge for safe scene-object inspection and mutation.

@export var registry_path: NodePath = NodePath("../Registry")

var _registry: NucleusDevelopmentCommandRegistry
var _registered_ids: Array[StringName] = []


func _ready() -> void:
	_registry = get_node_or_null(registry_path) as NucleusDevelopmentCommandRegistry
	if _registry == null:
		push_warning("SceneObjectDevelopmentCommands requires a command registry.")
		return

	_register_scene_queries()
	_register_property_commands()
	_register_transform_commands()
	_register_runtime_commands()


func _exit_tree() -> void:
	if _registry == null:
		return
	for id: StringName in _registered_ids:
		_registry.unregister_command(id)


func _register_scene_queries() -> void:
	_register(NucleusDevelopmentCommand.build(
		&"scene.nodes",
		"List current-scene nodes",
		Callable(self, "_scene_nodes"),
		"Lists node paths and classes. Optionally filters by path, name, or class.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(
				&"query", TYPE_STRING, "Optional search term.", true, ""
			),
			NucleusDevelopmentCommandArgument.build(
				&"limit", TYPE_INT, "Maximum results (1-200).", true, 50
			),
		],
		PackedStringArray(["nodes", "scene.find"]),
		PackedStringArray(["tree", "objects", "discover"]),
	))
	_register(NucleusDevelopmentCommand.build(
		&"scene.group",
		"List nodes in a group",
		Callable(self, "_scene_group"),
		"Lists current-scene nodes assigned to a Godot group.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"group", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(
				&"limit", TYPE_INT, "Maximum results (1-200).", true, 50
			),
		],
		PackedStringArray(),
		PackedStringArray(["groups", "objects", "discover"]),
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.inspect",
		"Inspect editable node properties",
		Callable(self, "_node_inspect"),
		"Shows editor-visible primitive/vector/color properties for one node.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(
				&"query", TYPE_STRING, "Optional property filter.", true, ""
			),
		],
		PackedStringArray(["inspect"]),
		PackedStringArray(["properties", "node", "debug"]),
	))


func _register_property_commands() -> void:
	_register(NucleusDevelopmentCommand.build(
		&"node.set",
		"Set an editable node property",
		Callable(self, "_node_set"),
		"Sets a supported editor-visible property without arbitrary method calls.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"property", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"value", TYPE_STRING),
		],
		PackedStringArray(),
		PackedStringArray(["properties", "mutate", "node"]),
	))


func _register_transform_commands() -> void:
	_register(NucleusDevelopmentCommand.build(
		&"node.position2d",
		"Move a Node2D",
		Callable(self, "_position_2d"),
		"Sets local or global 2D position.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"x", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"y", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(
				&"space",
				TYPE_STRING,
				"Coordinate space.",
				true,
				"local",
				PackedStringArray(["local", "global"]),
			),
		],
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.position3d",
		"Move a Node3D",
		Callable(self, "_position_3d"),
		"Sets local or global 3D position.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"x", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"y", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"z", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(
				&"space",
				TYPE_STRING,
				"Coordinate space.",
				true,
				"local",
				PackedStringArray(["local", "global"]),
			),
		],
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.rotation2d",
		"Rotate a Node2D",
		Callable(self, "_rotation_2d"),
		"Sets 2D rotation in degrees.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"degrees", TYPE_FLOAT),
		],
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.rotation3d",
		"Rotate a Node3D",
		Callable(self, "_rotation_3d"),
		"Sets Euler rotation in degrees.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"x", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"y", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"z", TYPE_FLOAT),
		],
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.scale2d",
		"Scale a Node2D",
		Callable(self, "_scale_2d"),
		"Sets 2D scale.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"x", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"y", TYPE_FLOAT),
		],
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.scale3d",
		"Scale a Node3D",
		Callable(self, "_scale_3d"),
		"Sets 3D scale.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"x", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"y", TYPE_FLOAT),
			NucleusDevelopmentCommandArgument.build(&"z", TYPE_FLOAT),
		],
	))


func _register_runtime_commands() -> void:
	_register(NucleusDevelopmentCommand.build(
		&"node.visible",
		"Show or hide a scene node",
		Callable(self, "_visible"),
		"Sets CanvasItem/Node3D visibility.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"visible", TYPE_BOOL),
		],
	))
	_register(NucleusDevelopmentCommand.build(
		&"node.process",
		"Enable or disable node processing",
		Callable(self, "_process_node"),
		"Toggles both idle and physics processing on a node.",
		&"Scene Objects",
		[
			NucleusDevelopmentCommandArgument.build(&"path", TYPE_STRING),
			NucleusDevelopmentCommandArgument.build(&"enabled", TYPE_BOOL),
		],
	))


func _register(command: NucleusDevelopmentCommand) -> void:
	if _registry.register_command(command) == OK:
		_registered_ids.append(command.id)


func _scene_nodes(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var root := _current_scene()
	if root == null:
		return _no_scene()
	var result := NucleusSceneObjectTools.list_nodes(
		root,
		str(arguments[0]),
		int(arguments[1]),
	)
	return _formatted_result(result, NucleusSceneObjectTools.format_node_list(result))


func _scene_group(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var root := _current_scene()
	if root == null:
		return _no_scene()
	var result := NucleusSceneObjectTools.list_group(
		root,
		str(arguments[0]),
		int(arguments[1]),
	)
	return _formatted_result(result, NucleusSceneObjectTools.format_node_list(result))


func _node_inspect(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var root := _current_scene()
	if root == null:
		return _no_scene()
	var result := NucleusSceneObjectTools.inspect_node(
		root,
		str(arguments[0]),
		str(arguments[1]),
	)
	return _formatted_result(result, NucleusSceneObjectTools.format_inspection(result))


func _node_set(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_property(
		_current_scene(),
		str(arguments[0]),
		str(arguments[1]),
		str(arguments[2]),
	))


func _position_2d(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_position_2d(
		_current_scene(),
		str(arguments[0]),
		float(arguments[1]),
		float(arguments[2]),
		str(arguments[3]),
	))


func _position_3d(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_position_3d(
		_current_scene(),
		str(arguments[0]),
		float(arguments[1]),
		float(arguments[2]),
		float(arguments[3]),
		str(arguments[4]),
	))


func _rotation_2d(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_rotation_2d(
		_current_scene(),
		str(arguments[0]),
		float(arguments[1]),
	))


func _rotation_3d(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_rotation_3d(
		_current_scene(),
		str(arguments[0]),
		float(arguments[1]),
		float(arguments[2]),
		float(arguments[3]),
	))


func _scale_2d(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_scale_2d(
		_current_scene(),
		str(arguments[0]),
		float(arguments[1]),
		float(arguments[2]),
	))


func _scale_3d(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_scale_3d(
		_current_scene(),
		str(arguments[0]),
		float(arguments[1]),
		float(arguments[2]),
		float(arguments[3]),
	))


func _visible(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_visible(
		_current_scene(),
		str(arguments[0]),
		bool(arguments[1]),
	))


func _process_node(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	return _simple_scene_result(NucleusSceneObjectTools.set_processing(
		_current_scene(),
		str(arguments[0]),
		bool(arguments[1]),
	))


func _current_scene() -> Node:
	return get_tree().current_scene


func _simple_scene_result(result: Dictionary) -> NucleusDevelopmentCommandResult:
	return _formatted_result(result, str(result.get("message", "")))


func _formatted_result(
	result: Dictionary,
	message: String,
) -> NucleusDevelopmentCommandResult:
	if not bool(result.get("ok", false)):
		return NucleusDevelopmentCommandResult.failure(message, result)
	return NucleusDevelopmentCommandResult.success(message, result.get("data"))


func _no_scene() -> NucleusDevelopmentCommandResult:
	return NucleusDevelopmentCommandResult.failure("No current scene is available.")
