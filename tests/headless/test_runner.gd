extends Node
## Project-scene runner for the dependency-free native test suites.
##
## Running as a normal project scene ensures project Autoloads are registered
## before the manifest and its transitive scripts are compiled.

const TEST_MANIFEST := preload("res://tests/headless/test_manifest.gd")


func _ready() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var selected: Array[Script] = []
	var requested := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--nucleus-suites="):
			requested = argument.trim_prefix("--nucleus-suites=").split(",", false)
			if requested.is_empty():
				push_error("Empty Nucleus suite selection.")
				get_tree().quit(2)
				return
	var filtered := not requested.is_empty()
	for suite_script: Script in TEST_MANIFEST.SUITES:
		if not filtered or suite_script.resource_path.get_file() in requested:
			selected.append(suite_script)
			requested.erase(suite_script.resource_path.get_file())
	if not requested.is_empty():
		push_error("Unknown Nucleus suite selection: %s" % requested)
		get_tree().quit(2)
		return
	var result: Dictionary = _execute_suites(selected)
	var failures: PackedStringArray = result["failures"]
	var total_checks: int = result["checks"]
	var suite_count: int = selected.size()
	var exit_code := 0

	if failures.is_empty():
		print(
			"Nucleus headless tests: PASS (%d checks, %d suites)."
			% [total_checks, suite_count]
		)
	else:
		exit_code = 1
		push_error(
			"Nucleus headless tests: FAIL (%d failures / %d checks)."
			% [failures.size(), total_checks]
		)

		for failure: String in failures:
			push_error("  - " + failure)

	await _flush_engine_cleanup()
	get_tree().quit(exit_code)


func _execute_suites(selected: Array[Script]) -> Dictionary:
	# Presentation assertions use a deterministic source locale on every developer OS.
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var total_checks: int = 0
	var failures := PackedStringArray()

	for suite_script: Script in selected:
		var suite: Variant = suite_script.new()
		var result: Dictionary = suite.run()
		total_checks += int(result.get("checks", 0))

		for failure: String in result.get("failures", PackedStringArray()):
			failures.append(
				"%s: %s"
				% [suite_script.resource_path.get_file(), failure]
			)

	TranslationServer.set_locale(previous_locale)
	return {
		"checks": total_checks,
		"failures": failures,
	}


func _flush_engine_cleanup() -> void:
	# Several tests create rendering/physics objects and some production code
	# uses queue_free(). Give Godot normal frame boundaries before process exit.
	await get_tree().process_frame
	await get_tree().process_frame
