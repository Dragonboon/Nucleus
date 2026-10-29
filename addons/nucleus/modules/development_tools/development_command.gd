class_name NucleusDevelopmentCommand
extends RefCounted
## One discoverable debug/development command and its argument contract.

var id: StringName
var title: String
var description: String = ""
var category: StringName = &"General"
var aliases := PackedStringArray()
var tags := PackedStringArray()
var arguments: Array[NucleusDevelopmentCommandArgument] = []
var callback: Callable


static func build(
	p_id: StringName,
	p_title: String,
	p_callback: Callable,
	p_description: String = "",
	p_category: StringName = &"General",
	p_arguments: Array = [],
	p_aliases: PackedStringArray = PackedStringArray(),
	p_tags: PackedStringArray = PackedStringArray(),
) -> NucleusDevelopmentCommand:
	var command := NucleusDevelopmentCommand.new()
	command.id = p_id
	command.title = p_title
	command.callback = p_callback
	command.description = p_description
	command.category = p_category
	command.arguments.assign(p_arguments)
	command.aliases = p_aliases.duplicate()
	command.tags = p_tags.duplicate()
	return command


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("command id cannot be empty")
	elif not _is_valid_identifier(str(id)):
		errors.append(
			"command id '%s' may only contain letters, digits, '.', '_' and '-'"
			% str(id)
		)
	if title.strip_edges().is_empty():
		errors.append("command '%s' requires a title" % str(id))
	if not callback.is_valid():
		errors.append("command '%s' requires a valid callback" % str(id))

	var normalized_id := str(id).to_lower()
	var alias_names: Dictionary = {}
	for alias: String in aliases:
		var normalized_alias := alias.strip_edges().to_lower()
		if normalized_alias.is_empty() or not _is_valid_identifier(normalized_alias):
			errors.append("command '%s' contains invalid alias '%s'" % [str(id), alias])
		elif normalized_alias == normalized_id or alias_names.has(normalized_alias):
			errors.append("command '%s' repeats alias '%s'" % [str(id), alias])
		alias_names[normalized_alias] = true

	var optional_seen := false
	var argument_names: Dictionary = {}
	for argument: NucleusDevelopmentCommandArgument in arguments:
		if argument == null:
			errors.append("command '%s' contains a null argument" % str(id))
			continue
		for error: String in argument.validate():
			errors.append("command '%s': %s" % [str(id), error])
		if argument_names.has(argument.name):
			errors.append(
				"command '%s' repeats argument '%s'"
				% [str(id), str(argument.name)]
			)
		argument_names[argument.name] = true
		if argument.optional:
			optional_seen = true
		elif optional_seen:
			errors.append(
				"command '%s' cannot place required arguments after optional ones"
				% str(id)
			)
	return errors


func usage() -> String:
	var parts := PackedStringArray([str(id)])
	for argument: NucleusDevelopmentCommandArgument in arguments:
		parts.append(argument.usage_token())
	return " ".join(parts)


func matches_id(candidate: String) -> bool:
	if str(id).nocasecmp_to(candidate) == 0:
		return true
	for alias: String in aliases:
		if alias.nocasecmp_to(candidate) == 0:
			return true
	return false


func parse_arguments(tokens: PackedStringArray) -> Dictionary:
	var required_count := 0
	for argument: NucleusDevelopmentCommandArgument in arguments:
		if not argument.optional:
			required_count += 1

	if tokens.size() < required_count:
		return {
			"ok": false,
			"error": "Missing arguments. Usage: %s" % usage(),
		}
	if tokens.size() > arguments.size():
		return {
			"ok": false,
			"error": "Too many arguments. Usage: %s" % usage(),
		}

	var values: Array = []
	for index: int in range(arguments.size()):
		var argument := arguments[index]
		if index >= tokens.size():
			values.append(argument.default_value)
			continue
		var parsed := argument.parse(tokens[index])
		if not bool(parsed.get("ok", false)):
			return {
				"ok": false,
				"error": "%s. Usage: %s" % [parsed.get("error", ""), usage()],
			}
		values.append(parsed["value"])

	return {
		"ok": true,
		"values": values,
	}


static func _is_valid_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in range(value.length()):
		var character := value.substr(index, 1)
		if character.is_valid_identifier() or character.is_valid_int():
			continue
		if character not in [".", "-", "_"]:
			return false
	return true
