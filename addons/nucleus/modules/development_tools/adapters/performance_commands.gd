class_name NucleusPerformanceDevelopmentCommands
extends Node
## Optional bridge from Development Tools into Nucleus Performance / Diagnostics.

@export var registry_path: NodePath
@export var sampler_path: NodePath
@export var default_report_path: String = "user://performance_report.json"

var _registry: NucleusDevelopmentCommandRegistry
var _sampler: NucleusPerformanceSampler
var _registered_ids: Array[StringName] = []


func _ready() -> void:
	_registry = get_node_or_null(registry_path) as NucleusDevelopmentCommandRegistry
	_sampler = get_node_or_null(sampler_path) as NucleusPerformanceSampler
	if _registry == null or _sampler == null:
		push_warning("PerformanceDevelopmentCommands requires registry and sampler paths.")
		return

	_register(
		NucleusDevelopmentCommand.build(
			&"performance.report",
			"Save performance report",
			Callable(self, "_save_report"),
			"Saves the sampler history and diagnostics as JSON.",
			&"Performance",
			[
				NucleusDevelopmentCommandArgument.build(
					&"path",
					TYPE_STRING,
					"Target JSON path.",
					true,
					default_report_path,
				),
			],
			PackedStringArray(["perf.report"]),
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"performance.clear",
			"Clear performance history",
			Callable(self, "_clear_history"),
			"Clears samples, traces, and diagnostic history.",
			&"Performance",
			[],
			PackedStringArray(["perf.clear"]),
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"performance.trace",
			"Mark performance trace",
			Callable(self, "_mark_trace"),
			"Marks an authored event in the current performance capture.",
			&"Performance",
			[
				NucleusDevelopmentCommandArgument.build(
					&"label",
					TYPE_STRING,
					"Trace label.",
				),
			],
			PackedStringArray(["perf.trace"]),
		)
	)
	_register(
		NucleusDevelopmentCommand.build(
			&"performance.compare",
			"Compare performance baseline",
			Callable(self, "_compare_report"),
			"Compares the current sampler report with a saved baseline JSON report.",
			&"Performance",
			[
				NucleusDevelopmentCommandArgument.build(
					&"baseline",
					TYPE_STRING,
					"Saved baseline report path.",
				),
			],
			PackedStringArray(["perf.compare"]),
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


func _save_report(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var path := str(arguments[0])
	var error := _sampler.save_report(path)
	if error != OK:
		return NucleusDevelopmentCommandResult.failure(
			"Unable to save report: %s" % error_string(error)
		)
	return NucleusDevelopmentCommandResult.success("Saved performance report: %s" % path)


func _clear_history(
	_arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	_sampler.clear_history()
	return NucleusDevelopmentCommandResult.success("Performance history cleared.")


func _mark_trace(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var label := StringName(str(arguments[0]))
	_sampler.mark_trace(label)
	return NucleusDevelopmentCommandResult.success("Marked trace: %s" % str(label))


func _compare_report(
	arguments: Array,
	_context: Dictionary,
) -> NucleusDevelopmentCommandResult:
	var baseline_path := str(arguments[0])
	var baseline := NucleusPerformanceReportComparator.load_report(baseline_path)
	if baseline.is_empty():
		return NucleusDevelopmentCommandResult.failure(
			"Unable to load baseline report: %s" % baseline_path
		)
	var comparison := _sampler.compare_report(baseline)
	var regressions: Array = comparison.get("regressions", [])
	var improvements: Array = comparison.get("improvements", [])
	var context_warnings: PackedStringArray = comparison.get(
		"context_warnings",
		PackedStringArray(),
	)
	var lines := PackedStringArray([
		"Regressions: %d" % regressions.size(),
		"Improvements: %d" % improvements.size(),
	])
	if not context_warnings.is_empty():
		lines.append("Context warnings: %s" % "; ".join(context_warnings))
	for regression: Dictionary in regressions.slice(0, 5):
		lines.append(
			"%s: %+0.1f%% (%s)"
			% [
				str(regression.get("label", regression.get("metric_id", "metric"))),
				float(regression.get("relative_change", 0.0)) * 100.0,
				str(regression.get("severity", "warning")),
			]
		)
	var message := "\n".join(lines)
	if regressions.is_empty() and context_warnings.is_empty():
		return NucleusDevelopmentCommandResult.success(message, comparison)
	return NucleusDevelopmentCommandResult.warning(message, comparison)
