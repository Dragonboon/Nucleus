@tool
class_name NucleusSpriteSequenceClip2D
extends Resource
## Animation assembled from distinct image files rather than atlas cells.

@export var animation_name: StringName = &"idle"
@export var frame_paths: PackedStringArray = PackedStringArray()
@export_range(0.1, 120.0, 0.1) var fps: float = 8.0
@export var loop: bool = true


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
	return issues
