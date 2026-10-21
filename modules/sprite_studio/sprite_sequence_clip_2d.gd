@tool
class_name NucleusSpriteSequenceClip2D
extends Resource
## Animation assembled from distinct image files rather than atlas cells.

@export var animation_name: StringName = &"idle"
@export var frame_paths: PackedStringArray = PackedStringArray()
@export_range(0.1, 120.0, 0.1) var fps: float = 8.0
@export var loop: bool = true
## Optional milliseconds per frame. Empty preserves the existing FPS-only behavior.
@export var frame_durations_ms: PackedFloat32Array = PackedFloat32Array()


func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if animation_name == &"" or String(animation_name).contains("/"):
		issues.append("Clip needs a valid animation name.")
	if not is_finite(fps) or fps <= 0.0:
		issues.append("Clip FPS must be positive.")
	if frame_paths.is_empty():
		issues.append("Clip must have at least one PNG frame.")
	for path: String in frame_paths:
		if not path.begins_with("res://") or not path.get_extension().to_lower() in [
			"png", "webp", "jpg", "jpeg",
		]:
			issues.append("Invalid image path: %s" % path)
	if not frame_durations_ms.is_empty():
		if frame_durations_ms.size() != frame_paths.size():
			issues.append("Provide one duration per frame, or leave durations empty.")
		for duration: float in frame_durations_ms:
			if not is_finite(duration) or duration <= 0.0:
				issues.append("Frame durations must be finite positive milliseconds.")
				break
	return issues


func frame_seconds(index: int) -> float:
	return frame_durations_ms[index] / 1000.0 if not frame_durations_ms.is_empty() else 1.0 / fps
