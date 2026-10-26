extends Resource
class_name NucleusScreenHotspot

## Normalized bounds refer to the full authored image, not window pixels.
@export var id: StringName
@export var bounds := Rect2(0.0, 0.0, 0.2, 0.2)
@export var enabled := true
@export var priority := 0
@export var destination: StringName
@export var description_key: StringName


func is_valid_hotspot() -> bool:
	return not id.is_empty() and bounds.has_area() and (
		bounds.position.x >= 0.0 and bounds.position.y >= 0.0
		and bounds.end.x <= 1.0 and bounds.end.y <= 1.0
	)


func contains_normalized(point: Vector2) -> bool:
	return enabled and is_valid_hotspot() and bounds.has_point(point)
