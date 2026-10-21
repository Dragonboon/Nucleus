@tool
class_name NucleusSpriteClip2D
extends Resource
## Explicit animation clip: a sequence of cells, not an assumed asset-pack layout.

@export var animation_name: StringName = &"idle"
@export var cells: Array[Vector2i] = [Vector2i.ZERO]
@export_range(0.1, 240.0, 0.1) var fps: float = 8.0
@export var loop: bool = true
## Optional milliseconds per frame. Empty preserves the existing FPS-only behavior.
@export var frame_durations_ms: PackedFloat32Array = PackedFloat32Array()


func validate(grid_size: Vector2i) -> PackedStringArray:
	var errors := PackedStringArray()
	if animation_name == &"" or String(animation_name).contains("/"):
		errors.append("Animation name must be nonempty and may not contain '/'.")
	if not is_finite(fps) or fps <= 0.0:
		errors.append("FPS must be positive.")
	if cells.is_empty():
		errors.append("Clip must include at least one cell.")
	for cell: Vector2i in cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
			errors.append("Animation contains a cell outside the sheet.")
			break
	if not frame_durations_ms.is_empty():
		if frame_durations_ms.size() != cells.size():
			errors.append("Provide one duration per frame, or leave durations empty.")
		for duration: float in frame_durations_ms:
			if not is_finite(duration) or duration <= 0.0:
				errors.append("Frame durations must be finite positive milliseconds.")
				break
	return errors


func frame_seconds(index: int) -> float:
	return frame_durations_ms[index] / 1000.0 if not frame_durations_ms.is_empty() else 1.0 / fps
