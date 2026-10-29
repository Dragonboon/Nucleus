class_name NucleusPerformanceSectionProfiler
extends Node
## Opt-in wall-clock instrumentation for synchronous game-owned CPU sections.
## Sections are timed with monotonic ticks, not physics delta or game time.
## An optional NucleusPerformanceSampler receives section probes and hitch traces.

signal section_measured(label: StringName, duration_ms: float)
signal section_over_budget(label: StringName, duration_ms: float, budget_ms: float)
signal frame_hitch_detected(max_interval_ms: float, sample_sequence: int)

@export_category("Capture")
@export var enabled: bool = true
@export var debug_build_only: bool = true
@export_range(1, 2048, 1) var max_active_sections: int = 128
@export_range(1, 256, 1) var max_tracked_labels: int = 64
@export_range(1, 256, 1) var max_label_length: int = 96
@export_range(1, 2048, 1) var hitch_history_capacity: int = 128

@export_category("Thresholds")
## Zero disables section warnings unless a label-specific budget is configured.
@export_range(0.0, 1000.0, 0.1, "or_greater")
var default_section_budget_ms: float = 0.0
## A frame hitch is the maximum observed interval in one sampler window.
## Zero disables frame hitch notifications.
@export_range(0.0, 1000.0, 0.1, "or_greater")
var frame_hitch_threshold_ms: float = 25.0

@export_category("Sampler Integration")
@export var sampler: NucleusPerformanceSampler
@export var publish_section_probes: bool = true
@export var trace_section_hitches: bool = true
@export var trace_frame_hitches: bool = true

var _next_token: int = 1
var _active: Dictionary = {}
var _statistics: Dictionary = {}
var _label_budgets: Dictionary = {}
var _hitch_history: Array[Dictionary] = []
var _registered_probes: Dictionary = {}
var _sampler_connected: bool = false
var _last_frame_sequence: int = 0


func _ready() -> void:
	_connect_sampler()


func _exit_tree() -> void:
	_disconnect_sampler()


## Returns 0 if capture is disabled or its bounded capacity is reached.
## Explicit timestamps are useful for deterministic tests, not clock sync.
func begin_section(label: StringName, timestamp_usec: int = -1) -> int:
	if not _can_capture() or label == &"":
		return 0
	if String(label).length() > maxi(max_label_length, 1):
		return 0
	if _active.size() >= maxi(max_active_sections, 1):
		return 0
	if not _statistics.has(label) and not _active_has_label(label):
		if _tracked_label_count() >= maxi(max_tracked_labels, 1):
			return 0

	var now_usec: int = (
		timestamp_usec if timestamp_usec >= 0 else Time.get_ticks_usec()
	)
	var token: int = _next_token
	while _active.has(token):
		token = 1 if token >= 2147483647 else token + 1
	_next_token = 1 if token >= 2147483647 else token + 1
	_active[token] = {"label": label, "started_usec": now_usec}
	return token


## Returns milliseconds, or -1 for stale/invalid tokens and reverse timestamps.
func end_section(token: int, timestamp_usec: int = -1) -> float:
	if token <= 0 or not _active.has(token):
		return -1.0

	var entry: Dictionary = _active[token]
	_active.erase(token)
	if not _can_capture():
		return -1.0

	var now_usec: int = (
		timestamp_usec if timestamp_usec >= 0 else Time.get_ticks_usec()
	)
	var started_usec: int = int(entry["started_usec"])
	if now_usec < started_usec:
		return -1.0

	var label: StringName = entry["label"]
	var duration_ms: float = float(now_usec - started_usec) / 1000.0
	var statistics: Dictionary = _statistics.get(label, {})
	var count: int = int(statistics.get("samples", 0)) + 1
	var total_ms: float = float(statistics.get("total_ms", 0.0)) + duration_ms
	var budget_ms: float = get_section_budget(label)
	var over_budget: bool = budget_ms > 0.0 and duration_ms >= budget_ms

	statistics["samples"] = count
	statistics["last_ms"] = duration_ms
	statistics["total_ms"] = total_ms
	statistics["average_ms"] = total_ms / float(count)
	statistics["minimum_ms"] = minf(
		float(statistics.get("minimum_ms", duration_ms)), duration_ms
	)
	statistics["maximum_ms"] = maxf(
		float(statistics.get("maximum_ms", duration_ms)), duration_ms
	)
	statistics["over_budget_count"] = (
		int(statistics.get("over_budget_count", 0)) + (1 if over_budget else 0)
	)
	_statistics[label] = statistics
	_register_section_probe(label)
	section_measured.emit(label, duration_ms)

	if over_budget:
		_record_hitch({
			"kind": "section",
			"label": str(label),
			"duration_ms": duration_ms,
			"threshold_ms": budget_ms,
			"timestamp_usec": now_usec,
		})
		section_over_budget.emit(label, duration_ms, budget_ms)
		if trace_section_hitches and _has_sampler():
			sampler.mark_trace(&"section_over_budget", {
				"section": str(label),
				"duration_ms": duration_ms,
				"budget_ms": budget_ms,
			})

	return duration_ms


func set_section_budget(label: StringName, budget_ms: float) -> Error:
	if label == &"" or not is_finite(budget_ms) or budget_ms < 0.0:
		return ERR_INVALID_PARAMETER
	if String(label).length() > maxi(max_label_length, 1):
		return ERR_INVALID_PARAMETER
	if budget_ms == 0.0:
		_label_budgets.erase(label)
	else:
		if not _label_budgets.has(label):
			if _label_budgets.size() >= maxi(max_tracked_labels, 1):
				return ERR_BUSY
		_label_budgets[label] = budget_ms
	return OK


func get_section_budget(label: StringName) -> float:
	return float(_label_budgets.get(label, default_section_budget_ms))


func get_section_statistics(label: StringName) -> Dictionary:
	if not _statistics.has(label):
		return {"samples": 0}
	var statistics: Dictionary = _statistics[label]
	return statistics.duplicate(true)


func get_all_section_statistics() -> Dictionary:
	var result: Dictionary = {}
	for label: Variant in _statistics:
		var statistics: Dictionary = _statistics[label]
		result[str(label)] = statistics.duplicate(true)
	return result


func get_hitch_history() -> Array[Dictionary]:
	return _hitch_history.duplicate(true)


func get_active_section_count() -> int:
	return _active.size()


## Drops in-flight tokens and measured state; retains authored budgets.
func clear_capture() -> void:
	_active.clear()
	_statistics.clear()
	_hitch_history.clear()
	_next_token = 1
	_last_frame_sequence = 0
	_unregister_probes()


## Rebinds after a scene swap; the profiler never owns the sampler lifetime.
func bind_sampler(next_sampler: NucleusPerformanceSampler) -> void:
	_disconnect_sampler()
	sampler = next_sampler
	if is_inside_tree():
		_connect_sampler()


func _on_snapshot_sampled(snapshot: NucleusPerformanceSnapshot) -> void:
	if not _can_capture() or snapshot == null:
		return
	if frame_hitch_threshold_ms <= 0.0:
		return
	if not snapshot.has_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS):
		return
	if snapshot.sequence > 0 and snapshot.sequence <= _last_frame_sequence:
		return
	_last_frame_sequence = snapshot.sequence

	var max_ms: float = snapshot.get_metric(
		NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS
	)
	if max_ms < frame_hitch_threshold_ms:
		return

	_record_hitch({
		"kind": "frame_window",
		"duration_ms": max_ms,
		"threshold_ms": frame_hitch_threshold_ms,
		"sample_sequence": snapshot.sequence,
		"timestamp_usec": snapshot.timestamp_usec,
	})
	frame_hitch_detected.emit(max_ms, snapshot.sequence)
	if trace_frame_hitches and _has_sampler():
		sampler.mark_trace(&"frame_interval_hitch", {
			"max_interval_ms": max_ms,
			"sample_sequence": snapshot.sequence,
		})


func _can_capture() -> bool:
	return enabled and (not debug_build_only or OS.is_debug_build())


func _has_sampler() -> bool:
	return sampler != null and is_instance_valid(sampler)


func _connect_sampler() -> void:
	if not _has_sampler():
		return
	if not sampler.snapshot_sampled.is_connected(_on_snapshot_sampled):
		sampler.snapshot_sampled.connect(_on_snapshot_sampled)
	_sampler_connected = true
	if publish_section_probes:
		for label: Variant in _statistics:
			_register_section_probe(label)


func _disconnect_sampler() -> void:
	if _has_sampler():
		if _sampler_connected and sampler.snapshot_sampled.is_connected(
			_on_snapshot_sampled
		):
			sampler.snapshot_sampled.disconnect(_on_snapshot_sampled)
	_unregister_probes()
	_sampler_connected = false


func _register_section_probe(label: StringName) -> void:
	if not publish_section_probes or not _has_sampler():
		return
	if not is_inside_tree() or _registered_probes.has(label):
		return
	var metric_id := StringName("section/%s/last_ms" % str(label))
	var error: Error = sampler.register_probe(
		metric_id,
		Callable(self, "_get_last_section_ms").bind(label)
	)
	if error == OK:
		_registered_probes[label] = metric_id


func _get_last_section_ms(label: StringName) -> float:
	var stats: Dictionary = _statistics.get(label, {})
	return float(stats.get("last_ms", 0.0))


func _unregister_probes() -> void:
	if _has_sampler():
		for label: Variant in _registered_probes:
			sampler.unregister_probe(_registered_probes[label])
	_registered_probes.clear()


func _record_hitch(event: Dictionary) -> void:
	_hitch_history.append(event)
	while _hitch_history.size() > maxi(hitch_history_capacity, 1):
		_hitch_history.pop_front()


func _active_has_label(label: StringName) -> bool:
	for entry_value: Variant in _active.values():
		var entry: Dictionary = entry_value
		if entry["label"] == label:
			return true
	return false


func _tracked_label_count() -> int:
	var labels: Dictionary = {}
	for label: Variant in _statistics:
		labels[label] = true
	for entry_value: Variant in _active.values():
		var entry: Dictionary = entry_value
		labels[entry["label"]] = true
	return labels.size()
