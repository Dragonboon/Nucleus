@tool
class_name NucleusAdaptivePerformanceProfile
extends Resource
## An opt-in response policy, not a renderer or settings owner.
## Input windows come exclusively from NucleusPerformanceSampler.

@export_group("Performance Target")
@export_range(15, 240, 1) var target_fps: int = 60
@export_range(0.25, 1.0, 0.01) var minimum_render_scale: float = 0.80
@export_range(0.25, 1.0, 0.01) var maximum_render_scale: float = 1.00
@export_range(0.01, 0.20, 0.01) var render_scale_step: float = 0.05
@export var allow_quality_recovery: bool = true

@export_group("Window Quality")
@export_range(2, 120, 1) var minimum_frame_samples: int = 8
@export_range(0.1, 1.0, 0.01) var degradation_fps_ratio: float = 0.90
@export_range(0.1, 1.0, 0.01) var recovery_fps_ratio: float = 0.98
@export_range(1.0, 4.0, 0.01) var degradation_p95_ratio: float = 1.12
@export_range(1.0, 4.0, 0.01) var recovery_p95_ratio: float = 1.15

@export_group("Hysteresis")
@export_range(2, 120, 1) var degradation_windows: int = 4
@export_range(2, 120, 1) var recovery_windows: int = 10
@export_range(0, 120, 1) var cooldown_windows: int = 3


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_fps < 15 or target_fps > 240:
		errors.append("Target FPS must be in [15, 240].")
	if (
		not is_finite(minimum_render_scale) or not is_finite(maximum_render_scale)
		or minimum_render_scale < 0.25
		or maximum_render_scale > 1.0
		or minimum_render_scale > maximum_render_scale
	):
		errors.append("Render scale bounds must be ordered within [0.25, 1.0].")
	if not is_finite(render_scale_step) or render_scale_step <= 0.0:
		errors.append("Render scale step must be positive and finite.")
	if (
		not is_finite(degradation_fps_ratio)
		or not is_finite(recovery_fps_ratio)
		or degradation_fps_ratio <= 0.0
		or recovery_fps_ratio > 1.0
		or degradation_fps_ratio >= recovery_fps_ratio
	):
		errors.append("FPS thresholds must form a hysteresis interval.")
	if (
		not is_finite(degradation_p95_ratio)
		or not is_finite(recovery_p95_ratio)
		or degradation_p95_ratio < 1.0 or recovery_p95_ratio < 1.0
	):
		errors.append("Frame pacing ratios must be finite and >= 1.")
	if minimum_frame_samples < 2:
		errors.append("At least two frame intervals are required per window.")
	if degradation_windows < 2 or recovery_windows < 2:
		errors.append("Require multiple consecutive windows before changing quality.")
	if cooldown_windows < 0:
		errors.append("Cooldown cannot be negative.")
	return errors
