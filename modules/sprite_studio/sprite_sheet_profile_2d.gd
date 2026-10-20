@tool
class_name NucleusSpriteSheetProfile2D
extends Resource
## Non-destructive, pack-agnostic source of truth for 2D frame slicing.

@export var texture: Texture2D
@export var cell_size: Vector2i = Vector2i(32, 32)
@export var margin: Vector2i = Vector2i.ZERO
@export var separation: Vector2i = Vector2i.ZERO
@export var clips: Array[NucleusSpriteClip2D] = []


func grid_size() -> Vector2i:
	if texture == null or cell_size.x <= 0 or cell_size.y <= 0:
		return Vector2i.ZERO
	var available := Vector2i(texture.get_size()) - margin * 2
	var stride := cell_size + separation
	if stride.x <= 0 or stride.y <= 0:
		return Vector2i.ZERO
	return Vector2i(
		maxi(0, (available.x + separation.x) / stride.x),
		maxi(0, (available.y + separation.y) / stride.y),
	)


func frame_rect(cell: Vector2i) -> Rect2i:
	return Rect2i(margin + cell * (cell_size + separation), cell_size)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if texture == null:
		errors.append("Assign a texture.")
	if cell_size.x <= 0 or cell_size.y <= 0:
		errors.append("Cell size must be positive.")
	if margin.x < 0 or margin.y < 0 or separation.x < 0 or separation.y < 0:
		errors.append("Margins and separation must be nonnegative.")
	var grid := grid_size()
	if grid.x == 0 or grid.y == 0:
		errors.append("No complete cells fit the sheet.")
	if clips.is_empty():
		errors.append("Create at least one animation clip.")
	var names: Dictionary = {}
	for clip: NucleusSpriteClip2D in clips:
		if clip == null:
			errors.append("Null clip.")
			continue
		if names.has(clip.animation_name):
			errors.append("Duplicate animation name: %s" % clip.animation_name)
		names[clip.animation_name] = true
		errors.append_array(clip.validate(grid))
	return errors
