extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_argument_parsing()
	_test_command_line_tokenizer()
	_test_registry_registration_and_search()
	_test_execution_and_defaults()
	_test_alias_collision()
	_test_history_capacity()
	return finish()


func _test_argument_parsing() -> void:
	var int_argument := NucleusDevelopmentCommandArgument.build(&"count", TYPE_INT)
	var bool_argument := NucleusDevelopmentCommandArgument.build(&"enabled", TYPE_BOOL)

	var parsed_int := int_argument.parse("42")
	expect_true(bool(parsed_int.get("ok", false)), "Integer arguments parse valid values.")
	expect_equal(parsed_int.get("value"), 42, "Integer parsing preserves the value.")

	var parsed_bool := bool_argument.parse("on")
	expect_true(bool(parsed_bool.get("ok", false)), "Boolean arguments accept on/off syntax.")
	expect_equal(parsed_bool.get("value"), true, "Boolean on maps to true.")

	var invalid := int_argument.parse("forty-two")
	expect_false(bool(invalid.get("ok", false)), "Invalid typed arguments are rejected.")


func _test_command_line_tokenizer() -> void:
	var registry := NucleusDevelopmentCommandRegistry.new()
	var parsed := registry.parse_line('spawn.boat 3 "Harbor Patrol" true')
	expect_true(bool(parsed.get("ok", false)), "Quoted command lines parse successfully.")
	var tokens: PackedStringArray = parsed.get("tokens", PackedStringArray())
	expect_equal(tokens.size(), 4, "Tokenizer preserves four logical tokens.")
	expect_equal(tokens[2], "Harbor Patrol", "Tokenizer preserves quoted whitespace.")

	var escaped := registry.parse_line('dev.echo hello\\ world')
	var escaped_tokens: PackedStringArray = escaped.get("tokens", PackedStringArray())
	expect_equal(escaped_tokens[1], "hello world", "Tokenizer supports escaped whitespace.")

	var invalid := registry.parse_line('dev.echo "unterminated')
	expect_false(bool(invalid.get("ok", false)), "Unterminated quotes are rejected.")
	registry.free()


func _test_registry_registration_and_search() -> void:
	var registry := NucleusDevelopmentCommandRegistry.new()
	var callback := func(_arguments: Array, _context: Dictionary) -> String:
		return "reloaded"
	var command := NucleusDevelopmentCommand.build(
		&"scene.reload",
		"Reload current scene",
		callback,
		"Reloads through scene flow.",
		&"Scene",
		[],
		PackedStringArray(["reload"]),
	)

	expect_equal(registry.register_command(command), OK, "Registry accepts a valid command.")
	expect_true(registry.has_command(&"scene.reload"), "Registered IDs resolve.")
	expect_true(registry.has_command(&"reload"), "Registered aliases resolve.")
	var results := registry.search("reload")
	expect_equal(results.size(), 1, "Search finds command titles and aliases.")
	expect_equal(results[0].id, &"scene.reload", "Search returns the expected command.")
	var multiword := registry.search("reload scene")
	expect_equal(multiword.size(), 1, "Search supports multiword discovery queries.")
	registry.free()


func _test_execution_and_defaults() -> void:
	var registry := NucleusDevelopmentCommandRegistry.new()
	var state := {"captured": []}
	var callback := func(arguments: Array, _context: Dictionary) -> NucleusDevelopmentCommandResult:
		state["captured"] = arguments.duplicate()
		return NucleusDevelopmentCommandResult.success("spawned")
	var command := NucleusDevelopmentCommand.build(
		&"world.spawn",
		"Spawn entities",
		callback,
		"Spawns a development fixture.",
		&"World",
		[
			NucleusDevelopmentCommandArgument.build(&"count", TYPE_INT),
			NucleusDevelopmentCommandArgument.build(
				&"active",
				TYPE_BOOL,
				"Whether entities start active.",
				true,
				true,
			),
		],
	)
	registry.register_command(command)

	var result := registry.execute_line("world.spawn 5")
	expect_true(result.is_success(), "Valid command lines execute successfully.")
	var captured: Array = state["captured"]
	expect_equal(captured[0], 5, "Execution passes parsed integer arguments.")
	expect_equal(captured[1], true, "Execution fills optional defaults.")
	expect_equal(registry.get_history().size(), 1, "Execution is recorded in history.")

	var bad_result := registry.execute_line("world.spawn nope")
	expect_false(bad_result.is_success(), "Invalid command arguments return failure.")
	registry.free()


func _test_alias_collision() -> void:
	var registry := NucleusDevelopmentCommandRegistry.new()
	var callback := func(_arguments: Array, _context: Dictionary) -> void:
		pass
	var first := NucleusDevelopmentCommand.build(
		&"scene.reload",
		"Reload",
		callback,
		"",
		&"Scene",
		[],
		PackedStringArray(["reload"]),
	)
	var second := NucleusDevelopmentCommand.build(
		&"world.reload",
		"Reload world",
		callback,
		"",
		&"World",
		[],
		PackedStringArray(["reload"]),
	)
	registry.register_command(first)
	expect_equal(
		registry.register_command(second),
		ERR_ALREADY_EXISTS,
		"Aliases cannot silently shadow an existing command.",
	)
	registry.free()


func _test_history_capacity() -> void:
	var registry := NucleusDevelopmentCommandRegistry.new()
	registry.history_capacity = 2
	var callback := func(_arguments: Array, _context: Dictionary) -> String:
		return "pong"
	var command := NucleusDevelopmentCommand.build(
		&"dev.ping",
		"Ping",
		callback,
	)
	registry.register_command(command)
	registry.execute_line("dev.ping")
	registry.execute_line("dev.ping")
	registry.execute_line("dev.ping")
	expect_equal(registry.get_history().size(), 2, "History remains bounded.")
	registry.free()
