class_name NucleusDevelopmentCommandRegistry
extends Node
## Scene-owned registry, parser, search index, and execution history for dev tools.

signal command_registered(command: NucleusDevelopmentCommand)
signal command_unregistered(id: StringName)
signal command_executed(entry: Dictionary)
signal history_cleared

@export var debug_build_only: bool = true
@export_range(1, 500, 1) var history_capacity: int = 50

var _commands: Dictionary = {}
var _aliases: Dictionary = {}
var _history: Array[Dictionary] = []
var _enabled: bool = false


func _init() -> void:
	_enabled = not debug_build_only or OS.is_debug_build()


func _ready() -> void:
	_enabled = not debug_build_only or OS.is_debug_build()


func is_enabled() -> bool:
	return _enabled


func register_command(command: NucleusDevelopmentCommand) -> Error:
	if not _enabled:
		return ERR_UNAVAILABLE
	if command == null:
		return ERR_INVALID_PARAMETER
	if not command.validate().is_empty():
		return ERR_INVALID_PARAMETER

	var canonical := _normalize_id(str(command.id))
	if _commands.has(canonical) or _aliases.has(canonical):
		return ERR_ALREADY_EXISTS

	for alias: String in command.aliases:
		var normalized_alias := _normalize_id(alias)
		if normalized_alias.is_empty():
			return ERR_INVALID_PARAMETER
		if _commands.has(normalized_alias) or _aliases.has(normalized_alias):
			return ERR_ALREADY_EXISTS

	_commands[canonical] = command
	for alias: String in command.aliases:
		_aliases[_normalize_id(alias)] = canonical
	command_registered.emit(command)
	return OK


func unregister_command(id: StringName) -> void:
	var canonical := _resolve_canonical(str(id))
	if canonical.is_empty() or not _commands.has(canonical):
		return

	var command := _commands[canonical] as NucleusDevelopmentCommand
	for alias: String in command.aliases:
		_aliases.erase(_normalize_id(alias))
	_commands.erase(canonical)
	command_unregistered.emit(command.id)


func has_command(id: StringName) -> bool:
	return resolve_command(str(id)) != null


func resolve_command(id_or_alias: String) -> NucleusDevelopmentCommand:
	var canonical := _resolve_canonical(id_or_alias)
	if canonical.is_empty():
		return null
	return _commands.get(canonical) as NucleusDevelopmentCommand


func get_commands() -> Array[NucleusDevelopmentCommand]:
	var commands: Array[NucleusDevelopmentCommand] = []
	for value: Variant in _commands.values():
		commands.append(value as NucleusDevelopmentCommand)
	commands.sort_custom(_sort_commands)
	return commands


func search(
	query: String,
	limit: int = 12,
) -> Array[NucleusDevelopmentCommand]:
	var normalized_query := query.strip_edges().to_lower()
	var scored: Array[Dictionary] = []

	for command: NucleusDevelopmentCommand in get_commands():
		var score := _search_score(command, normalized_query)
		if score < 0:
			continue
		scored.append({
			"command": command,
			"score": score,
		})

	scored.sort_custom(_sort_scored_commands)
	var results: Array[NucleusDevelopmentCommand] = []
	var result_limit := maxi(limit, 1)
	for item: Dictionary in scored:
		results.append(item["command"] as NucleusDevelopmentCommand)
		if results.size() >= result_limit:
			break
	return results


func parse_line(line: String) -> Dictionary:
	var tokens := PackedStringArray()
	var current := ""
	var quote := ""
	var escaping := false
	var token_started := false

	for index: int in range(line.length()):
		var character := line.substr(index, 1)
		if escaping:
			current += character
			escaping = false
			token_started = true
			continue
		if character == "\\":
			escaping = true
			token_started = true
			continue
		if not quote.is_empty():
			if character == quote:
				quote = ""
			else:
				current += character
			token_started = true
			continue
		if character in ['"', "'"]:
			quote = character
			token_started = true
			continue
		if character in [" ", "\t", "\n"]:
			if token_started:
				tokens.append(current)
				current = ""
				token_started = false
			continue
		current += character
		token_started = true

	if escaping:
		return {"ok": false, "error": "Command line ends with an escape character."}
	if not quote.is_empty():
		return {"ok": false, "error": "Command line contains an unterminated quote."}
	if token_started:
		tokens.append(current)

	return {
		"ok": true,
		"tokens": tokens,
	}


func execute_line(
	line: String,
	context: Dictionary = {},
) -> NucleusDevelopmentCommandResult:
	if not _enabled:
		return NucleusDevelopmentCommandResult.failure(
			"Development commands are disabled in this build."
		)

	var parsed_line := parse_line(line)
	if not bool(parsed_line.get("ok", false)):
		return _record_parse_failure(line, str(parsed_line.get("error", "Invalid command.")))

	var tokens: PackedStringArray = parsed_line["tokens"]
	if tokens.is_empty():
		return _record_parse_failure(line, "Enter a command.")

	var command := resolve_command(tokens[0])
	if command == null:
		return _record_parse_failure(line, "Unknown command: %s" % tokens[0])

	var argument_tokens := PackedStringArray()
	for index: int in range(1, tokens.size()):
		argument_tokens.append(tokens[index])
	var parsed_arguments := command.parse_arguments(argument_tokens)
	if not bool(parsed_arguments.get("ok", false)):
		return _record_execution(
			command,
			[],
			line,
			NucleusDevelopmentCommandResult.failure(
				str(parsed_arguments.get("error", "Invalid arguments."))
			),
		)

	return _execute_command(
		command,
		parsed_arguments["values"],
		context,
		line,
	)


func execute(
	id: StringName,
	arguments: Array = [],
	context: Dictionary = {},
) -> NucleusDevelopmentCommandResult:
	if not _enabled:
		return NucleusDevelopmentCommandResult.failure(
			"Development commands are disabled in this build."
		)
	var command := resolve_command(str(id))
	if command == null:
		return NucleusDevelopmentCommandResult.failure("Unknown command: %s" % str(id))
	if arguments.size() != command.arguments.size():
		var required := 0
		for argument: NucleusDevelopmentCommandArgument in command.arguments:
			if not argument.optional:
				required += 1
		if arguments.size() < required or arguments.size() > command.arguments.size():
			return NucleusDevelopmentCommandResult.failure(
				"Invalid argument count. Usage: %s" % command.usage()
			)
	var values := arguments.duplicate()
	while values.size() < command.arguments.size():
		values.append(command.arguments[values.size()].default_value)
	var line_parts := PackedStringArray([str(command.id)])
	for value: Variant in arguments:
		line_parts.append(str(value))
	return _execute_command(command, values, context, " ".join(line_parts))


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func clear_history() -> void:
	_history.clear()
	history_cleared.emit()


func _execute_command(
	command: NucleusDevelopmentCommand,
	arguments: Array,
	context: Dictionary,
	raw_line: String,
) -> NucleusDevelopmentCommandResult:
	var execution_context := context.duplicate()
	execution_context["registry"] = self
	execution_context["command_id"] = command.id

	var raw_result: Variant = command.callback.call(arguments, execution_context)
	var result := _normalize_result(raw_result)
	return _record_execution(command, arguments, raw_line, result)


func _normalize_result(value: Variant) -> NucleusDevelopmentCommandResult:
	if value is NucleusDevelopmentCommandResult:
		return value
	if value == null:
		return NucleusDevelopmentCommandResult.success()
	if value is String:
		return NucleusDevelopmentCommandResult.success(value)
	if value is bool:
		if value:
			return NucleusDevelopmentCommandResult.success()
		return NucleusDevelopmentCommandResult.failure("Command returned false.")
	return NucleusDevelopmentCommandResult.success(str(value), value)


func _record_parse_failure(
	raw_line: String,
	message: String,
) -> NucleusDevelopmentCommandResult:
	var result := NucleusDevelopmentCommandResult.failure(message)
	var entry := {
		"timestamp_usec": Time.get_ticks_usec(),
		"command_id": "",
		"raw_line": raw_line,
		"arguments": [],
		"status": result.status_name(),
		"message": result.message,
	}
	_push_history(entry)
	command_executed.emit(entry.duplicate(true))
	return result


func _record_execution(
	command: NucleusDevelopmentCommand,
	arguments: Array,
	raw_line: String,
	result: NucleusDevelopmentCommandResult,
) -> NucleusDevelopmentCommandResult:
	var entry := {
		"timestamp_usec": Time.get_ticks_usec(),
		"command_id": str(command.id),
		"raw_line": raw_line,
		"arguments": arguments.duplicate(true),
		"status": result.status_name(),
		"message": result.message,
	}
	_push_history(entry)
	command_executed.emit(entry.duplicate(true))
	return result


func _push_history(entry: Dictionary) -> void:
	_history.append(entry)
	while _history.size() > history_capacity:
		_history.pop_front()


func _resolve_canonical(id_or_alias: String) -> String:
	var normalized := _normalize_id(id_or_alias)
	if _commands.has(normalized):
		return normalized
	return str(_aliases.get(normalized, ""))


func _normalize_id(value: String) -> String:
	return value.strip_edges().to_lower()


func _search_score(
	command: NucleusDevelopmentCommand,
	query: String,
) -> int:
	if query.is_empty():
		return 0
	var command_id := str(command.id).to_lower()
	var title := command.title.to_lower()
	if command_id == query:
		return 1000
	if command_id.begins_with(query):
		return 800
	for alias: String in command.aliases:
		var normalized_alias := alias.to_lower()
		if normalized_alias == query:
			return 950
		if normalized_alias.begins_with(query):
			return 750
	if title.begins_with(query):
		return 700
	if command_id.contains(query):
		return 600
	if title.contains(query):
		return 500
	if str(command.category).to_lower().contains(query):
		return 300
	for tag: String in command.tags:
		if tag.to_lower().contains(query):
			return 250
	if command.description.to_lower().contains(query):
		return 100

	var haystack := " ".join(PackedStringArray([
		command_id,
		title,
		str(command.category).to_lower(),
		" ".join(command.aliases).to_lower(),
		" ".join(command.tags).to_lower(),
		command.description.to_lower(),
	]))
	var query_tokens := query.split(" ", false)
	if query_tokens.size() > 1:
		for token: String in query_tokens:
			if not haystack.contains(token):
				return -1
		return 400 + query_tokens.size()
	return -1


func _sort_commands(
	a: NucleusDevelopmentCommand,
	b: NucleusDevelopmentCommand,
) -> bool:
	var category_comparison := str(a.category).nocasecmp_to(str(b.category))
	if category_comparison == 0:
		return a.title.nocasecmp_to(b.title) < 0
	return category_comparison < 0


func _sort_scored_commands(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a["score"])
	var score_b := int(b["score"])
	if score_a != score_b:
		return score_a > score_b
	var command_a := a["command"] as NucleusDevelopmentCommand
	var command_b := b["command"] as NucleusDevelopmentCommand
	return _sort_commands(command_a, command_b)
