class_name NucleusAdaptivePerformancePolicy
extends RefCounted
## Hysteretic, sample-driven scale recommendations. No engine settings writes.
## Uses measured window FPS AND p95; no TIME_PROCESS or GPU guesswork.

var profile: NucleusAdaptivePerformanceProfile

var _suggested_scale: float = 1.0
var _bad_windows: int = 0
var _good_windows: int = 0
var _cooldown_left: int = 0
var _last_sequence: int = -1


func _init(configuration: NucleusAdaptivePerformanceProfile = null) -> void:
	profile = configuration if configuration != null else (
		NucleusAdaptivePerformanceProfile.new()
	)
	reset()


func reset() -> void:
	_suggested_scale = (
		profile.maximum_render_scale if profile != null else 1.0
	)
	_bad_windows = 0
	_good_windows = 0
	_cooldown_left = 0
	_last_sequence = -1


func get_suggested_scale() -> float:
	return _suggested_scale


func evaluate(snapshot: NucleusPerformanceSnapshot) -> Dictionary:
	if profile == null or not profile.validate().is_empty():
		return _decision(&"invalid_profile", false)
	if snapshot == null:
		return _decision(&"missing_sample", false)
	if snapshot.sequence <= _last_sequence:
		return _decision(&"stale_sample", false)
	_last_sequence = snapshot.sequence
	var fps_id := NucleusPerformanceMetricIds.WINDOW_FPS
	var p95_id := NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS
	var count_id := NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES
	if (
		not snapshot.has_metric(fps_id) or not snapshot.has_metric(p95_id)
		or not snapshot.has_metric(count_id)
	):
		return _invalidate_window()
	var fps: float = snapshot.get_metric(fps_id)
	var p95: float = snapshot.get_metric(p95_id)
	var count: float = snapshot.get_metric(count_id)
	if (
		not is_finite(fps) or not is_finite(p95) or not is_finite(count)
		or fps <= 0.0 or p95 <= 0.0
		or count < float(profile.minimum_frame_samples)
	):
		return _invalidate_window()
	if _cooldown_left > 0:
		_cooldown_left -= 1
		_bad_windows = 0
		_good_windows = 0
		return _decision(&"cooldown", false)
	var target_ms: float = 1000.0 / float(profile.target_fps)
	var overloaded: bool = (
		fps < float(profile.target_fps) * profile.degradation_fps_ratio
		and p95 > target_ms * profile.degradation_p95_ratio
	)
	var recovered: bool = (
		fps >= float(profile.target_fps) * profile.recovery_fps_ratio
		and p95 <= target_ms * profile.recovery_p95_ratio
	)
	if overloaded:
		_bad_windows += 1
		_good_windows = 0
		if _bad_windows >= profile.degradation_windows:
			_bad_windows = 0
			var next_scale: float = maxf(
				profile.minimum_render_scale,
				_suggested_scale - profile.render_scale_step
			)
			return _change_or_hold(next_scale, &"degrade", &"at_minimum")
		return _decision(&"under_target", false)
	if recovered:
		_good_windows += 1
		_bad_windows = 0
		if profile.allow_quality_recovery and _good_windows >= profile.recovery_windows:
			_good_windows = 0
			var next_scale: float = minf(
				profile.maximum_render_scale,
				_suggested_scale + profile.render_scale_step
			)
			return _change_or_hold(next_scale, &"recover", &"at_maximum")
		return _decision(&"recovering", false)
	_bad_windows = 0
	_good_windows = 0
	return _decision(&"neutral", false)


func _change_or_hold(
	next_scale: float, change_reason: StringName, limit_reason: StringName
) -> Dictionary:
	if is_equal_approx(next_scale, _suggested_scale):
		return _decision(limit_reason, false)
	_suggested_scale = snappedf(next_scale, 0.0001)
	_suggested_scale = clampf(
		_suggested_scale, profile.minimum_render_scale, profile.maximum_render_scale
	)
	_cooldown_left = profile.cooldown_windows
	return _decision(change_reason, true)


func _invalidate_window() -> Dictionary:
	_bad_windows = 0
	_good_windows = 0
	return _decision(&"insufficient_data", false)


func _decision(reason: StringName, changed: bool) -> Dictionary:
	return {
		"reason": reason,
		"changed": changed,
		"render_scale": _suggested_scale,
		"target_fps": profile.target_fps if profile != null else 0,
		"bad_windows": _bad_windows,
		"good_windows": _good_windows,
		"cooldown_left": _cooldown_left,
	}
