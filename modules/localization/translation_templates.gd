@tool
class_name NucleusTranslationTemplates
extends RefCounted
## Optional development-time collection and deterministic gettext template output.
## No PO parser, translator, global registry, or interception of runtime tr() calls.

static func collect_scene(root: Node) -> Array[NucleusLocalizedMessage]:
	var result: Array[NucleusLocalizedMessage] = []
	if not is_instance_valid(root):
		return result
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is NucleusLocalizedTextBinding and node.message != null:
			result.append(node.message)
		pending.append_array(node.get_children())
	return result


static func collect_resource(resource: Resource) -> Array[NucleusLocalizedMessage]:
	var result: Array[NucleusLocalizedMessage] = []
	_collect(resource, result, {}, 0)
	return result


static func _collect(
	value: Variant, result: Array[NucleusLocalizedMessage], visited: Dictionary, depth: int,
) -> void:
	if depth > 64:
		return
	if value is NucleusLocalizedMessage:
		if not result.has(value):
			result.append(value)
	elif value is PackedScene:
		_collect_state(value.get_state(), result, visited, depth + 1)
	elif value is Resource and not value is Script:
		if visited.has(value.get_instance_id()):
			return
		visited[value.get_instance_id()] = true
		for property: Dictionary in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
				_collect(value.get(property.name), result, visited, depth + 1)
	elif value is Array or value is Dictionary:
		var items: Array = value.values() if value is Dictionary else value
		for item: Variant in items:
			_collect(item, result, visited, depth + 1)


static func _collect_state(
	state: SceneState, result: Array[NucleusLocalizedMessage], visited: Dictionary, depth: int,
) -> void:
	if state == null or depth > 64 or visited.has(state.get_instance_id()):
		return
	visited[state.get_instance_id()] = true
	_collect_state(state.get_base_scene_state(), result, visited, depth + 1)
	for node in state.get_node_count():
		_collect(state.get_node_instance(node), result, visited, depth + 1)
		for index in state.get_node_property_count(node):
			_collect(state.get_node_property_value(node, index), result, visited, depth + 1)


static func build_pot(messages: Array[NucleusLocalizedMessage]) -> Dictionary:
	var entries: Dictionary = {}
	for message: NucleusLocalizedMessage in messages:
		if message == null or message.source.is_empty():
			return {"error": ERR_INVALID_DATA, "text": ""}
		var key := JSON.stringify([String(message.context), message.source])
		if entries.has(key) and entries[key].plural != message.plural:
			return {"error": ERR_INVALID_DATA, "text": ""}
		if not entries.has(key):
			entries[key] = message
	var keys: Array = entries.keys()
	keys.sort()
	var output := "msgid \"\"\nmsgstr \"\"\n"
	output += "\"MIME-Version: 1.0\\n\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"\n"
	for key: String in keys:
		var message: NucleusLocalizedMessage = entries[key]
		output += "\n"
		for line: String in message.translator_comment.split("\n"):
			if not line.is_empty():
				output += "#. " + line + "\n"
		if "{" in message.source or "{" in message.plural:
			output += "#, python-brace-format\n"
		if message.context != &"":
			output += "msgctxt " + _quote(message.context) + "\n"
		output += "msgid " + _quote(message.source) + "\n"
		if message.plural.is_empty():
			output += "msgstr \"\"\n"
		else:
			output += "msgid_plural " + _quote(message.plural) + "\n"
			output += "msgstr[0] \"\"\nmsgstr[1] \"\"\n"
	return {"error": OK, "text": output}


static func write_pot(
	path: String, messages: Array[NucleusLocalizedMessage], overwrite: bool = false,
) -> Error:
	var canonical := path.simplify_path()
	if (not canonical.begins_with("user://")
		and not (Engine.is_editor_hint() and canonical.begins_with("res://"))):
		return ERR_INVALID_PARAMETER
	if canonical.get_extension() != "pot":
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(canonical) and not overwrite:
		return ERR_ALREADY_EXISTS
	var generated := build_pot(messages)
	if generated.error != OK:
		return generated.error as Error
	var temporary := canonical + ".%d.tmp" % Time.get_ticks_usec()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(generated.text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, canonical)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func _quote(value: String) -> String:
	return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"").replace(
		"\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + "\""
