@tool
class_name NucleusSpriteClip2D
extends Resource
## Explicit animation clip: a sequence of cells, not an assumed asset-pack layout.

@export var animation_name: StringName = &"idle"
@export var cells: Array[Vector2i] = [Vector2i.ZERO]
@export_range(0.1, 240.0, 0.1) var fps: float = 8.0
@export var loop: bool = true


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
	return errors
