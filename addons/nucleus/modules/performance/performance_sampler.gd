class_name NucleusPerformanceSampler
extends Node
## Optional scene-owned performance sampling and lightweight trace capture.
##
## Native Godot Performance monitors remain the source of truth for engine-owned
## counters. Nucleus also derives low-cost wall-clock frame-pacing windows from
## monotonic process-frame timestamps so time scale and delta smoothing do not
## masquerade as CPU budget usage.

signal snapshot_sampled(snapshot: NucleusPerformanceSnapshot)
signal diagnostics_updated(
	diagnostics: Array[NucleusPerformanceDiagnostic],
)
signal trace_marked(trace: Dictionary)

const _SECONDS_TO_MS: float = 1000.0
const _REPORT_METRICS: Array[StringName] = [
	NucleusPerformanceMetricIds.WINDOW_FPS,
	NucleusPerformanceMetricIds.FRAME_INTERVAL_AVG_MS,
	NucleusPerformanceMetricIds.FRAME_INTERVAL_P50_MS,
	NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
	NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS,
	NucleusPerformanceMetricIds.PROCESS_MS,
	NucleusPerformanceMetricIds.PHYSICS_MS,
	NucleusPerformanceMetricIds.NAVIGATION_MS,
	NucleusPerformanceMetricIds.STATIC_MEMORY_BYTES,
	NucleusPerformanceMetricIds.OBJECT_COUNT,
	NucleusPerformanceMetricIds.RESOURCE_COUNT,
	NucleusPerformanceMetricIds.NODE_COUNT,
	NucleusPerformanceMetricIds.ORPHAN_NODE_COUNT,
	NucleusPerformanceMetricIds.RENDER_OBJECTS,
	NucleusPerformanceMetricIds.RENDER_PRIMITIVES,
	NucleusPerformanceMetricIds.RENDER_DRAW_CALLS,
	NucleusPerformanceMetricIds.VIDEO_MEMORY_BYTES,
	NucleusPerformanceMetricIds.TEXTURE_MEMORY_BYTES,
	NucleusPerformanceMetricIds.BUFFER_MEMORY_BYTES,
	NucleusPerformanceMetricIds.PHYSICS_2D_ACTIVE,
	NucleusPerformanceMetricIds.PHYSICS_2D_PAIRS,
	NucleusPerformanceMetricIds.PHYSICS_3D_ACTIVE,
	NucleusPerformanceMetricIds.PHYSICS_3D_PAIRS,
	NucleusPerformanceMetricIds.NAVIGATION_2D_AGENTS,
	NucleusPerformanceMetricIds.NAVIGATION_3D_AGENTS,
]
const _NATIVE_MONITORS: Array[Dictionary] = [
	{
		"id": NucleusPerformanceMetricIds.FPS,
		"monitor": Performance.TIME_FPS,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PROCESS_MS,
		"monitor": Performance.TIME_PROCESS,
		"scale": _SECONDS_TO_MS,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_MS,
		"monitor": Performance.TIME_PHYSICS_PROCESS,
		"scale": _SECONDS_TO_MS,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_MS,
		"monitor": Performance.TIME_NAVIGATION_PROCESS,
		"scale": _SECONDS_TO_MS,
	},
	{
		"id": NucleusPerformanceMetricIds.STATIC_MEMORY_BYTES,
		"monitor": Performance.MEMORY_STATIC,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.MESSAGE_BUFFER_MAX_BYTES,
		"monitor": Performance.MEMORY_MESSAGE_BUFFER_MAX,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.OBJECT_COUNT,
		"monitor": Performance.OBJECT_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.RESOURCE_COUNT,
		"monitor": Performance.OBJECT_RESOURCE_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NODE_COUNT,
		"monitor": Performance.OBJECT_NODE_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.ORPHAN_NODE_COUNT,
		"monitor": Performance.OBJECT_ORPHAN_NODE_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.RENDER_OBJECTS,
		"monitor": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.RENDER_PRIMITIVES,
		"monitor": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.RENDER_DRAW_CALLS,
		"monitor": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.VIDEO_MEMORY_BYTES,
		"monitor": Performance.RENDER_VIDEO_MEM_USED,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.TEXTURE_MEMORY_BYTES,
		"monitor": Performance.RENDER_TEXTURE_MEM_USED,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.BUFFER_MEMORY_BYTES,
		"monitor": Performance.RENDER_BUFFER_MEM_USED,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_2D_ACTIVE,
		"monitor": Performance.PHYSICS_2D_ACTIVE_OBJECTS,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_2D_PAIRS,
		"monitor": Performance.PHYSICS_2D_COLLISION_PAIRS,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_2D_ISLANDS,
		"monitor": Performance.PHYSICS_2D_ISLAND_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_3D_ACTIVE,
		"monitor": Performance.PHYSICS_3D_ACTIVE_OBJECTS,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_3D_PAIRS,
		"monitor": Performance.PHYSICS_3D_COLLISION_PAIRS,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PHYSICS_3D_ISLANDS,
		"monitor": Performance.PHYSICS_3D_ISLAND_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_2D_REGIONS,
		"monitor": Performance.NAVIGATION_2D_REGION_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_2D_AGENTS,
		"monitor": Performance.NAVIGATION_2D_AGENT_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_2D_OBSTACLES,
		"monitor": Performance.NAVIGATION_2D_OBSTACLE_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_3D_REGIONS,
		"monitor": Performance.NAVIGATION_3D_REGION_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_3D_AGENTS,
		"monitor": Performance.NAVIGATION_3D_AGENT_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.NAVIGATION_3D_OBSTACLES,
		"monitor": Performance.NAVIGATION_3D_OBSTACLE_COUNT,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PIPELINE_CANVAS,
		"monitor": Performance.PIPELINE_COMPILATIONS_CANVAS,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PIPELINE_MESH,
		"monitor": Performance.PIPELINE_COMPILATIONS_MESH,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PIPELINE_SURFACE,
		"monitor": Performance.PIPELINE_COMPILATIONS_SURFACE,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PIPELINE_DRAW,
		"monitor": Performance.PIPELINE_COMPILATIONS_DRAW,
		"scale": 1.0,
	},
	{
		"id": NucleusPerformanceMetricIds.PIPELINE_SPECIALIZATION,
		"monitor": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
		"scale": 1.0,
	},
]

@export_category("Sampling")
@export var start_enabled: bool = true
@export var debug_build_only: bool = true
@export_range(0.1, 10.0, 0.1) var sample_interval_seconds: float = 0.5
@export_range(1, 3600, 1) var history_capacity: int = 120
@export_range(1, 1000, 1) var trace_capacity: int = 128

@export_category("Target")
@export var profile: NucleusPerformanceProfile

@export_category("Diagnostics")
@export var evaluate_diagnostics: bool = true
@export_range(0.0, 30.0, 0.5) var warmup_seconds: float = 3.0

@export_category("Godot Debugger")
@export var publish_summary_monitors: bool = true

var _sampling: bool = false
var _last_sample_usec: int = 0
var _last_process_usec: int = 0
var _started_usec: int = 0
var _sequence: int = 0
var _history: Array[NucleusPerformanceSnapshot] = []
var _traces: Array[Dictionary] = []
var _diagnostic_history: Array[Dictionary] = []
var _custom_probes: Dictionary = {}
var _published_probe_names: Dictionary = {}
var _registered_summary_names: Array[StringName] = []
var _latest_snapshot: NucleusPerformanceSnapshot
var _latest_diagnostics: Array[NucleusPerformanceDiagnostic] = []

var _frame_intervals_ms: Array[float] = []
var _frame_interval_sum_ms: float = 0.0
var _frame_interval_max_ms: float = 0.0


func _ready() -> void:
	if profile == null:
		profile = NucleusPerformanceProfile.new()

	if debug_build_only and not OS.is_debug_build():
		set_process(false)
		return

	if publish_summary_monitors:
		_register_summary_monitors()

	if start_enabled:
		start_sampling()
	else:
		set_process(false)


func _exit_tree() -> void:
	_unregister_summary_monitors()

	for id: Variant in _published_probe_names.keys():
		_remove_custom_monitor(_published_probe_names[id])

	_published_probe_names.clear()


func _process(_delta: float) -> void:
	if not _sampling:
		return

	var now_usec := Time.get_ticks_usec()
	_record_frame_interval(now_usec)

	var interval_usec := int(sample_interval_seconds * 1000000.0)
	if now_usec - _last_sample_usec < interval_usec:
		return

	sample_now()


func start_sampling() -> void:
	if debug_build_only and not OS.is_debug_build():
		return

	_sampling = true
	_started_usec = Time.get_ticks_usec()
	_last_sample_usec = _started_usec
	_last_process_usec = 0
	_reset_frame_window()
	set_process(true)
	sample_now()


func stop_sampling() -> void:
	_sampling = false
	_last_process_usec = 0
	set_process(false)


func is_sampling() -> bool:
	return _sampling


func sample_now() -> NucleusPerformanceSnapshot:
	var previous := _latest_snapshot
	var snapshot := NucleusPerformanceSnapshot.new()
	_sequence += 1
	snapshot.sequence = _sequence
	snapshot.timestamp_usec = Time.get_ticks_usec()
	_last_sample_usec = snapshot.timestamp_usec

	for entry: Dictionary in _NATIVE_MONITORS:
		var monitor: int = int(entry["monitor"])
		var scale: float = float(entry["scale"])
		var id: StringName = entry["id"]
		snapshot.set_metric(id, Performance.get_monitor(monitor) * scale)

	_sample_frame_window(snapshot)
	_sample_custom_probes(snapshot)
	_reset_frame_window()

	_latest_snapshot = snapshot
	_push_history(snapshot)

	if evaluate_diagnostics:
		var warmup_complete := _warmup_complete()
		_latest_diagnostics = NucleusPerformanceAdvisor.evaluate(
			snapshot,
			previous,
			profile,
			warmup_complete,
			_history,
		)
	else:
		_latest_diagnostics.clear()

	_record_diagnostics(snapshot)
	snapshot_sampled.emit(snapshot)
	diagnostics_updated.emit(_latest_diagnostics.duplicate())
	return snapshot


func register_probe(
	id: StringName,
	callable: Callable,
	publish_to_debugger: bool = false,
	monitor_type: int = Performance.MONITOR_TYPE_QUANTITY,
) -> Error:
	if id.is_empty() or not callable.is_valid():
		return ERR_INVALID_PARAMETER
	if _custom_probes.has(id):
		return ERR_ALREADY_EXISTS

	_custom_probes[id] = callable

	if publish_to_debugger:
		var monitor_name := _probe_monitor_name(id)
		if Performance.has_custom_monitor(monitor_name):
			_custom_probes.erase(id)
			return ERR_ALREADY_EXISTS

		Performance.add_custom_monitor(
			monitor_name,
			callable,
			[],
			monitor_type,
		)
		_published_probe_names[id] = monitor_name

	return OK


func unregister_probe(id: StringName) -> void:
	_custom_probes.erase(id)

	if not _published_probe_names.has(id):
		return

	_remove_custom_monitor(_published_probe_names[id])
	_published_probe_names.erase(id)


func mark_trace(
	label: StringName,
	metadata: Dictionary = {},
) -> void:
	var trace := {
		"label": str(label),
		"timestamp_usec": Time.get_ticks_usec(),
		"sample_sequence": _sequence,
		"metadata": metadata.duplicate(true),
	}
	_traces.append(trace)

	while _traces.size() > trace_capacity:
		_traces.pop_front()

	trace_marked.emit(trace.duplicate(true))


func get_latest_snapshot() -> NucleusPerformanceSnapshot:
	return _latest_snapshot


func get_latest_diagnostics() -> Array[NucleusPerformanceDiagnostic]:
	return _latest_diagnostics.duplicate()


func get_history() -> Array[NucleusPerformanceSnapshot]:
	return _history.duplicate()


func get_traces() -> Array[Dictionary]:
	return _traces.duplicate(true)


func get_diagnostic_history() -> Array[Dictionary]:
	return _diagnostic_history.duplicate(true)


func get_metric_statistics(
	id: StringName,
	sample_count: int = 0,
) -> Dictionary:
	var values: Array[float] = []
	var first := 0
	if sample_count > 0:
		first = maxi(0, _history.size() - sample_count)

	for index: int in range(first, _history.size()):
		var snapshot := _history[index]
		if snapshot != null and snapshot.has_metric(id):
			values.append(snapshot.get_metric(id))

	if values.is_empty():
		return {"samples": 0}

	var sorted_values: Array[float] = []
	sorted_values.assign(values)
	sorted_values.sort()

	var total := 0.0
	for value: float in values:
		total += value

	return {
		"samples": values.size(),
		"latest": values.back(),
		"minimum": sorted_values[0],
		"maximum": sorted_values.back(),
		"average": total / float(values.size()),
		"p50": _percentile(sorted_values, 0.50),
		"p95": _percentile(sorted_values, 0.95),
	}


func get_metric_series(
	id: StringName,
	sample_count: int = 0,
	positive_only: bool = false,
) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	var first := 0
	if sample_count > 0:
		first = maxi(0, _history.size() - sample_count)

	for index: int in range(first, _history.size()):
		var snapshot := _history[index]
		if snapshot == null or not snapshot.has_metric(id):
			continue

		var value := snapshot.get_metric(id)
		if positive_only and value <= 0.0:
			continue
		values.append(value)

	return values


func compare_report(
	baseline_report: Dictionary,
	warning_ratio: float = 0.10,
	critical_ratio: float = 0.25,
) -> Dictionary:
	return NucleusPerformanceReportComparator.compare(
		build_report(),
		baseline_report,
		warning_ratio,
		critical_ratio,
	)


func clear_history() -> void:
	_history.clear()
	_traces.clear()
	_diagnostic_history.clear()
	_latest_snapshot = null
	_latest_diagnostics.clear()
	_sequence = 0
	_started_usec = Time.get_ticks_usec()
	_last_sample_usec = _started_usec
	_last_process_usec = 0
	_reset_frame_window()


func build_report() -> Dictionary:
	var samples: Array[Dictionary] = []
	for snapshot: NucleusPerformanceSnapshot in _history:
		samples.append(snapshot.to_dictionary())

	var diagnostics: Array[Dictionary] = []
	for diagnostic: NucleusPerformanceDiagnostic in _latest_diagnostics:
		diagnostics.append(diagnostic.to_dictionary())

	return {
		"schema_version": 3,
		"engine": Engine.get_version_info(),
		"os": OS.get_name(),
		"debug_build": OS.is_debug_build(),
		"embedded_in_editor": Engine.is_embedded_in_editor(),
		"renderer_method": ProjectSettings.get_setting(
			"rendering/renderer/rendering_method",
			"",
		),
		"frame_timing": {
			"health_source": "window_fps_and_frame_interval_p95",
			"native_process_ms_informational": true,
		},
		"profile": profile.to_dictionary() if profile != null else {},
		"summary": _build_report_summary(),
		"metric_summary": _build_metric_summary(),
		"samples": samples,
		"traces": get_traces(),
		"diagnostic_events": get_diagnostic_history(),
		"latest_diagnostics": diagnostics,
	}


func save_report(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(build_report(), "\t"))
	return OK


func _build_report_summary() -> Dictionary:
	return {
		"window_fps": get_metric_statistics(
			NucleusPerformanceMetricIds.WINDOW_FPS
		),
		"frame_interval_p50_ms": get_metric_statistics(
			NucleusPerformanceMetricIds.FRAME_INTERVAL_P50_MS
		),
		"frame_interval_p95_ms": get_metric_statistics(
			NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
		),
		"frame_interval_max_ms": get_metric_statistics(
			NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS
		),
		"native_process_ms": get_metric_statistics(
			NucleusPerformanceMetricIds.PROCESS_MS
		),
	}


func _build_metric_summary() -> Dictionary:
	var summary: Dictionary = {}
	for metric_id: StringName in _REPORT_METRICS:
		var statistics := get_metric_statistics(metric_id)
		if int(statistics.get("samples", 0)) > 0:
			summary[str(metric_id)] = statistics
	return summary


func _record_diagnostics(snapshot: NucleusPerformanceSnapshot) -> void:
	if _latest_diagnostics.is_empty():
		return

	var serialized: Array[Dictionary] = []
	for diagnostic: NucleusPerformanceDiagnostic in _latest_diagnostics:
		serialized.append(diagnostic.to_dictionary())

	_diagnostic_history.append(
		{
			"sample_sequence": snapshot.sequence,
			"timestamp_usec": snapshot.timestamp_usec,
			"diagnostics": serialized,
		}
	)

	while _diagnostic_history.size() > history_capacity:
		_diagnostic_history.pop_front()


func _record_frame_interval(now_usec: int) -> void:
	if _last_process_usec <= 0:
		_last_process_usec = now_usec
		return

	var interval_usec := now_usec - _last_process_usec
	_last_process_usec = now_usec
	if interval_usec <= 0:
		return

	var interval_ms := float(interval_usec) / 1000.0
	_frame_intervals_ms.append(interval_ms)
	_frame_interval_sum_ms += interval_ms
	_frame_interval_max_ms = maxf(_frame_interval_max_ms, interval_ms)


func _sample_frame_window(snapshot: NucleusPerformanceSnapshot) -> void:
	var frame_count := _frame_intervals_ms.size()
	if frame_count <= 0 or _frame_interval_sum_ms <= 0.0:
		return

	var sorted_intervals: Array[float] = []
	sorted_intervals.assign(_frame_intervals_ms)
	sorted_intervals.sort()

	var average_ms := _frame_interval_sum_ms / float(frame_count)
	var elapsed_seconds := _frame_interval_sum_ms / _SECONDS_TO_MS
	var window_fps := float(frame_count) / elapsed_seconds

	snapshot.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, window_fps)
	snapshot.set_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_AVG_MS,
		average_ms,
	)
	snapshot.set_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P50_MS,
		_percentile(sorted_intervals, 0.50),
	)
	snapshot.set_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
		_percentile(sorted_intervals, 0.95),
	)
	snapshot.set_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS,
		_frame_interval_max_ms,
	)
	snapshot.set_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES,
		float(frame_count),
	)


func _reset_frame_window() -> void:
	_frame_intervals_ms.clear()
	_frame_interval_sum_ms = 0.0
	_frame_interval_max_ms = 0.0


func _sample_custom_probes(snapshot: NucleusPerformanceSnapshot) -> void:
	for id: Variant in _custom_probes:
		var callable: Callable = _custom_probes[id]
		if not callable.is_valid():
			continue

		var value: Variant = callable.call()
		if value is int or value is float:
			snapshot.set_metric(id, float(value))


func _push_history(snapshot: NucleusPerformanceSnapshot) -> void:
	_history.append(snapshot)

	while _history.size() > history_capacity:
		_history.pop_front()


func _warmup_complete() -> bool:
	if _started_usec <= 0:
		return true

	var elapsed_seconds := (
		float(Time.get_ticks_usec() - _started_usec)
		/ 1000000.0
	)
	return elapsed_seconds >= warmup_seconds


func _percentile(sorted_values: Array[float], ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	if sorted_values.size() == 1:
		return sorted_values[0]

	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var position := float(sorted_values.size() - 1) * clamped_ratio
	var lower := int(floor(position))
	var upper := mini(lower + 1, sorted_values.size() - 1)
	var weight := position - float(lower)
	return lerpf(sorted_values[lower], sorted_values[upper], weight)


func _register_summary_monitors() -> void:
	_register_summary_monitor(
		&"Nucleus/FrameBudget",
		Callable(self, "_debugger_frame_budget_ratio"),
		Performance.MONITOR_TYPE_PERCENTAGE,
	)
	_register_summary_monitor(
		&"Nucleus/FrameP95",
		Callable(self, "_debugger_frame_p95_seconds"),
		Performance.MONITOR_TYPE_TIME,
	)
	_register_summary_monitor(
		&"Nucleus/Warnings",
		Callable(self, "_debugger_warning_count"),
		Performance.MONITOR_TYPE_QUANTITY,
	)
	_register_summary_monitor(
		&"Nucleus/Criticals",
		Callable(self, "_debugger_critical_count"),
		Performance.MONITOR_TYPE_QUANTITY,
	)


func _register_summary_monitor(
	id: StringName,
	callable: Callable,
	monitor_type: int,
) -> void:
	if Performance.has_custom_monitor(id):
		return

	Performance.add_custom_monitor(id, callable, [], monitor_type)
	_registered_summary_names.append(id)


func _unregister_summary_monitors() -> void:
	for id: StringName in _registered_summary_names:
		_remove_custom_monitor(id)

	_registered_summary_names.clear()


func _remove_custom_monitor(id: StringName) -> void:
	if Performance.has_custom_monitor(id):
		Performance.remove_custom_monitor(id)


func _probe_monitor_name(id: StringName) -> StringName:
	return StringName(
		"NucleusGame/%s" % str(id).replace("/", ".")
	)


func _debugger_frame_budget_ratio() -> float:
	if _latest_snapshot == null or profile == null:
		return 0.0
	if not _latest_snapshot.has_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
	):
		return 0.0

	var budget_ms := profile.frame_budget_ms()
	if budget_ms <= 0.0:
		return 0.0

	return (
		_latest_snapshot.get_metric(
			NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
		)
		/ budget_ms
	)


func _debugger_frame_p95_seconds() -> float:
	if _latest_snapshot == null:
		return 0.0

	return (
		_latest_snapshot.get_metric(
			NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
		)
		/ _SECONDS_TO_MS
	)


func _debugger_warning_count() -> float:
	var count: int = 0

	for diagnostic: NucleusPerformanceDiagnostic in _latest_diagnostics:
		if diagnostic.severity == NucleusPerformanceDiagnostic.Severity.WARNING:
			count += 1

	return float(count)


func _debugger_critical_count() -> float:
	var count: int = 0

	for diagnostic: NucleusPerformanceDiagnostic in _latest_diagnostics:
		if diagnostic.severity == NucleusPerformanceDiagnostic.Severity.CRITICAL:
			count += 1

	return float(count)
