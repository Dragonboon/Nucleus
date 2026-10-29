class_name NucleusPerformanceReportComparator
extends RefCounted
## Compares two Nucleus performance reports and highlights meaningful regressions.
##
## Reports remain plain Dictionaries so they can be loaded from JSON in games,
## CI, or external tooling. Comparisons are only trustworthy when capture context
## matches; context mismatches are returned explicitly instead of being hidden.

const SEVERITY_NORMAL: StringName = &"normal"
const SEVERITY_WARNING: StringName = &"warning"
const SEVERITY_CRITICAL: StringName = &"critical"

const _HIGHER_IS_BETTER: int = 1
const _LOWER_IS_BETTER: int = -1
const _MINIMUM_SAMPLES: int = 3

const _RULES: Array[Dictionary] = [
	{
		"id": NucleusPerformanceMetricIds.WINDOW_FPS,
		"label": "Effective FPS",
		"category": "timing",
		"stat": "average",
		"direction": _HIGHER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
		"label": "Frame pacing p95",
		"category": "timing",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS,
		"label": "Frame interval max",
		"category": "timing",
		"stat": "p95",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_MS,
		"label": "Physics time",
		"category": "cpu",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_MS,
		"label": "Navigation time",
		"category": "cpu",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.RENDER_DRAW_CALLS,
		"label": "Draw calls",
		"category": "rendering",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.RENDER_OBJECTS,
		"label": "Rendered objects",
		"category": "rendering",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.RENDER_PRIMITIVES,
		"label": "Rendered primitives",
		"category": "rendering",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.VIDEO_MEMORY_BYTES,
		"label": "Video memory",
		"category": "memory",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.STATIC_MEMORY_BYTES,
		"label": "Static memory",
		"category": "memory",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
	{
		"id": NucleusPerformanceMetricIds.NODE_COUNT,
		"label": "Node count",
		"category": "scene",
		"stat": "average",
		"direction": _LOWER_IS_BETTER,
	},
]


static func compare(
	current_report: Dictionary,
	baseline_report: Dictionary,
	warning_ratio: float = 0.10,
	critical_ratio: float = 0.25,
) -> Dictionary:
	var warnings := _context_warnings(current_report, baseline_report)
	var changes: Array[Dictionary] = []
	var regressions: Array[Dictionary] = []
	var improvements: Array[Dictionary] = []
	var warning_threshold := maxf(warning_ratio, 0.0)
	var critical_threshold := maxf(critical_ratio, warning_threshold)

	for rule: Dictionary in _RULES:
		var change := _compare_rule(
			current_report,
			baseline_report,
			rule,
			warning_threshold,
			critical_threshold,
		)
		if change.is_empty():
			continue

		changes.append(change)
		var severity: StringName = change["severity"]
		var relative_change := float(change["relative_change"])

		if severity != SEVERITY_NORMAL:
			regressions.append(change)
		elif relative_change <= -warning_threshold:
			improvements.append(change)

	regressions.sort_custom(_sort_regressions)
	improvements.sort_custom(_sort_improvements)

	return {
		"schema_version": 1,
		"comparable_context": warnings.is_empty(),
		"context_warnings": warnings,
		"warning_ratio": warning_threshold,
		"critical_ratio": critical_threshold,
		"changes": changes,
		"regressions": regressions,
		"improvements": improvements,
	}


static func load_report(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed

	return {}


static func _compare_rule(
	current_report: Dictionary,
	baseline_report: Dictionary,
	rule: Dictionary,
	warning_ratio: float,
	critical_ratio: float,
) -> Dictionary:
	var metric_id: StringName = rule["id"]
	var current_stats := _metric_stats(current_report, metric_id)
	var baseline_stats := _metric_stats(baseline_report, metric_id)
	if current_stats.is_empty() or baseline_stats.is_empty():
		return {}

	var current_samples := int(current_stats.get("samples", 0))
	var baseline_samples := int(baseline_stats.get("samples", 0))
	if current_samples < _MINIMUM_SAMPLES or baseline_samples < _MINIMUM_SAMPLES:
		return {}

	var stat: String = rule["stat"]
	if not current_stats.has(stat) or not baseline_stats.has(stat):
		return {}

	var current_value := float(current_stats[stat])
	var baseline_value := float(baseline_stats[stat])
	if absf(baseline_value) <= 0.000001:
		return {}

	var direction := int(rule["direction"])
	var raw_delta := current_value - baseline_value
	var raw_ratio := raw_delta / absf(baseline_value)
	var relative_change := raw_ratio
	if direction == _HIGHER_IS_BETTER:
		relative_change = -raw_ratio

	var severity := SEVERITY_NORMAL
	if relative_change >= critical_ratio:
		severity = SEVERITY_CRITICAL
	elif relative_change >= warning_ratio:
		severity = SEVERITY_WARNING

	return {
		"metric_id": str(metric_id),
		"label": str(rule["label"]),
		"category": str(rule["category"]),
		"stat": stat,
		"baseline": baseline_value,
		"current": current_value,
		"delta": raw_delta,
		"relative_change": relative_change,
		"severity": severity,
		"baseline_samples": baseline_samples,
		"current_samples": current_samples,
	}


static func _metric_stats(report: Dictionary, metric_id: StringName) -> Dictionary:
	var summary: Variant = report.get("metric_summary", {})
	if summary is Dictionary:
		var summary_dict := summary as Dictionary
		var stats: Variant = summary_dict.get(str(metric_id), {})
		if stats is Dictionary and not stats.is_empty():
			return stats

	return _legacy_metric_stats(report, metric_id)


static func _legacy_metric_stats(
	report: Dictionary,
	metric_id: StringName,
) -> Dictionary:
	var summary: Variant = report.get("summary", {})
	if not summary is Dictionary:
		return {}
	var summary_dict := summary as Dictionary

	var legacy_key := ""
	match metric_id:
		NucleusPerformanceMetricIds.WINDOW_FPS:
			legacy_key = "window_fps"
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS:
			legacy_key = "frame_interval_p95_ms"
		NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS:
			legacy_key = "frame_interval_max_ms"
		NucleusPerformanceMetricIds.PROCESS_MS:
			legacy_key = "native_process_ms"
		_:
			return {}

	var stats: Variant = summary_dict.get(legacy_key, {})
	if stats is Dictionary:
		return stats
	return {}


static func _context_warnings(
	current_report: Dictionary,
	baseline_report: Dictionary,
) -> PackedStringArray:
	var warnings := PackedStringArray()
	_compare_context_value(
		warnings,
		current_report,
		baseline_report,
		"os",
		"Operating system differs between captures.",
	)
	_compare_context_value(
		warnings,
		current_report,
		baseline_report,
		"renderer_method",
		"Renderer method differs between captures.",
	)
	_compare_context_value(
		warnings,
		current_report,
		baseline_report,
		"embedded_in_editor",
		"Editor-embedding mode differs between captures.",
	)
	_compare_context_value(
		warnings,
		current_report,
		baseline_report,
		"debug_build",
		"Debug/release build mode differs between captures.",
	)

	var current_profile: Variant = current_report.get("profile", {})
	var baseline_profile: Variant = baseline_report.get("profile", {})
	if current_profile is Dictionary and baseline_profile is Dictionary:
		var current_profile_dict := current_profile as Dictionary
		var baseline_profile_dict := baseline_profile as Dictionary
		var current_target := int(current_profile_dict.get("target_fps", 0))
		var baseline_target := int(baseline_profile_dict.get("target_fps", 0))
		if current_target > 0 and baseline_target > 0:
			if current_target != baseline_target:
				warnings.append("Target FPS differs between captures.")

	var current_engine := _engine_major_minor(current_report)
	var baseline_engine := _engine_major_minor(baseline_report)
	if not current_engine.is_empty() and not baseline_engine.is_empty():
		if current_engine != baseline_engine:
			warnings.append("Godot major/minor version differs between captures.")

	return warnings


static func _compare_context_value(
	warnings: PackedStringArray,
	current_report: Dictionary,
	baseline_report: Dictionary,
	key: String,
	message: String,
) -> void:
	if not current_report.has(key) or not baseline_report.has(key):
		return
	if current_report[key] != baseline_report[key]:
		warnings.append(message)


static func _engine_major_minor(report: Dictionary) -> String:
	var engine: Variant = report.get("engine", {})
	if not engine is Dictionary:
		return ""
	var engine_dict := engine as Dictionary

	var major := int(engine_dict.get("major", -1))
	var minor := int(engine_dict.get("minor", -1))
	if major < 0 or minor < 0:
		return ""
	return "%d.%d" % [major, minor]


static func _sort_regressions(a: Dictionary, b: Dictionary) -> bool:
	var severity_a := _severity_rank(a["severity"])
	var severity_b := _severity_rank(b["severity"])
	if severity_a == severity_b:
		return float(a["relative_change"]) > float(b["relative_change"])
	return severity_a > severity_b


static func _sort_improvements(a: Dictionary, b: Dictionary) -> bool:
	return float(a["relative_change"]) < float(b["relative_change"])


static func _severity_rank(severity: StringName) -> int:
	match severity:
		SEVERITY_CRITICAL:
			return 2
		SEVERITY_WARNING:
			return 1
		_:
			return 0
