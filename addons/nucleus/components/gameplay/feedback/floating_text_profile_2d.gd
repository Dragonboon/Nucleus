class_name NucleusFloatingTextProfile2D
extends Resource
## Presentation only; text and numeric semantics belong to the caller.

@export var font: Font
@export_range(1, 256) var font_size: int = 18
@export var color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK
@export_range(0, 32) var outline_size: int = 2
@export_range(0.01, 10.0) var duration: float = 0.7
@export_range(0.0, 1.0) var fade_start: float = 0.35
@export var offset: Vector2 = Vector2(0, -24)
@export var travel: Vector2 = Vector2(0, -24)


func is_valid() -> bool:
	return (font_size > 0 and font_size <= 256 and outline_size >= 0 and outline_size <= 32
		and is_finite(duration) and duration > 0.0
		and is_finite(fade_start) and fade_start >= 0.0 and fade_start < 1.0
		and offset.is_finite() and travel.is_finite()
		and is_finite(color.r) and is_finite(color.g) and is_finite(color.b)
		and is_finite(color.a) and is_finite(outline_color.r) and is_finite(outline_color.g)
		and is_finite(outline_color.b) and is_finite(outline_color.a))
