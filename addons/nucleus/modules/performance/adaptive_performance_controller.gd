class_name NucleusAdaptivePerformanceController
extends Node
## Scene-owned sampler subscriber. OBSERVE ONLY in this first iteration.
## Emits recommendations; never edits Settings, Viewport or RenderingServer.

signal decision_observed(decision: Dictionary)
signal render_scale_recommended(render_scale: float, reason: StringName)
signal adaptation_enabled_changed(enabled: bool)
signal observation_reset

@export var sampler: NucleusPerformanceSampler
@export var profile: NucleusAdaptivePerformanceProfile
@export var start_enabled: bool = true

var _policy: NucleusAdaptivePerformancePolicy
var _enabled: bool = true
var _latest_decision: Dictionary = {}


func _ready() -> void:
	if profile == null:
		profile = NucleusAdaptivePerformanceProfile.new()
	_policy = NucleusAdaptivePerformancePolicy.new(profile)
	_enabled = start_enabled
	if is_instance_valid(sampler):
		if not sampler.snapshot_sampled.is_connected(submit_snapshot):
			sampler.snapshot_sampled.connect(submit_snapshot)


func _exit_tree() -> void:
	if is_instance_valid(sampler):
		if sampler.snapshot_sampled.is_connected(submit_snapshot):
			sampler.snapshot_sampled.disconnect(submit_snapshot)


func set_adaptation_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	reset_observation()
	adaptation_enabled_changed.emit(_enabled)


func is_adaptation_enabled() -> bool:
	return _enabled


func reset_observation() -> void:
	if _policy == null:
		return
	_policy.reset()
	_latest_decision.clear()
	observation_reset.emit()


func get_suggested_scale() -> float:
	return _policy.get_suggested_scale() if _policy != null else 1.0


func get_latest_decision() -> Dictionary:
	return _latest_decision.duplicate(true)


## Public ingestion for deterministic simulation/tests; no second collector.
func submit_snapshot(snapshot: NucleusPerformanceSnapshot) -> void:
	if not _enabled or _policy == null:
		return
	_latest_decision = _policy.evaluate(snapshot)
	decision_observed.emit(_latest_decision.duplicate(true))
	if bool(_latest_decision["changed"]):
		render_scale_recommended.emit(
			float(_latest_decision["render_scale"]),
			_latest_decision["reason"],
		)
