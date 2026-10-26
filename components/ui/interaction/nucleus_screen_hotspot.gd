extends Resource
class_name NucleusScreenHotspot

## Normalized bounds refer to the full authored image, not window pixels.
@export var id: StringName
@export var bounds := Rect2(0.0, 0.0, 0.2, 0.2)
@export var enabled := true
@export var priority := 0
@export var destination: StringName
@export var description_key: StringName
@export var polygon: PackedVector2Array
@export var alpha_mask: Texture2D
@export_range(0.0, 1.0, 0.01) var alpha_threshold := 0.5
@export var action: NucleusScreenAction

var _cached_mask: Texture2D
var _cached_image: Image


func is_valid_hotspot() -> bool:
	return not id.is_empty() and bounds.has_area() and (
		bounds.position.x >= 0.0 and bounds.position.y >= 0.0
		and bounds.end.x <= 1.0 and bounds.end.y <= 1.0
		and (polygon.is_empty() or polygon.size() >= 3)
		and (action == null or action.is_valid_action())
	)


func contains_normalized(point: Vector2) -> bool:
	if not enabled or not is_valid_hotspot() or not bounds.has_point(point):
		return false
	if polygon.size() >= 3 and not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	if alpha_mask != null:
		if _cached_mask != alpha_mask:
			_cached_mask = alpha_mask
			_cached_image = alpha_mask.get_image()
		if _cached_image == null or _cached_image.is_empty():
			return false
		var uv := (point - bounds.position) / bounds.size
		var x := clampi(int(uv.x * _cached_image.get_width()), 0, image.get_width() - 1)
		var y := clampi(int(uv.y * _cached_image.get_height()), 0, image.get_height() - 1)
		return _cached_image.get_pixel(x, y).a >= alpha_threshold
	return true
