@tool
class_name NucleusWorldMask3D
extends Node3D
## Scene-owned scalar data over local X/Z. No rendering, weather or scatter policy.

enum Channel { RED, GREEN, BLUE, ALPHA, LUMINANCE }

@export var texture: Texture2D:
	set(value):
		if texture == value:
			return
		if texture != null and texture.changed.is_connected(invalidate_cache):
			texture.changed.disconnect(invalidate_cache)
		texture = value
		if texture != null:
			texture.changed.connect(invalidate_cache)
		invalidate_cache()
@export var coverage_size: Vector2 = Vector2(32.0, 32.0):
	set(value):
		coverage_size = value
		if is_inside_tree():
			update_configuration_warnings()
@export var channel: Channel = Channel.RED
@export var inverse: bool = false
## Final fallback, not inverted: used outside coverage or when no valid data exists.
@export_range(0.0, 1.0, 0.01) var outside_value: float = 0.0

var _image: Image
var _cache_dirty: bool = true
var _cache_error: String = ""


func _ready() -> void:
	_ensure_cache()
	update_configuration_warnings()


## Call after modifying texture content that does not emit Resource.changed.
func invalidate_cache() -> void:
	_image = null
	_cache_dirty = true
	_cache_error = ""
	if is_inside_tree():
		update_configuration_warnings()


## Explicit warm-up/readback boundary. Queries otherwise refresh lazily once.
func refresh_cache() -> bool:
	invalidate_cache()
	var available: bool = _ensure_cache()
	if is_inside_tree():
		update_configuration_warnings()
	return available


## UV (0,0) is local (-size.x/2, -size.y/2); local Y is ignored.
## Invalid mappings return Vector2(INF, INF), never plausible in-bounds UVs.
func local_to_uv(local_position: Vector3) -> Vector2:
	if not local_position.is_finite() or not _valid_coverage():
		return Vector2(INF, INF)
	return Vector2(local_position.x, local_position.z) / coverage_size + Vector2.ONE * 0.5


func world_to_uv(world_position: Vector3) -> Vector2:
	if not world_position.is_finite():
		return Vector2(INF, INF)
	var pose: Transform3D = global_transform if is_inside_tree() else transform
	if not pose.is_finite() or absf(pose.basis.determinant()) <= 0.00000001:
		return Vector2(INF, INF)
	return local_to_uv(pose.affine_inverse() * world_position)


func sample_world(world_position: Vector3) -> float:
	var uv: Vector2 = world_to_uv(world_position)
	if not uv.is_finite() or uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return _fallback()
	if not _ensure_cache():
		return _fallback()
	# Nearest texel by cell: intervals [i/width, (i+1)/width), last edge inclusive.
	var x: int = mini(int(floor(uv.x * _image.get_width())), _image.get_width() - 1)
	var y: int = mini(int(floor(uv.y * _image.get_height())), _image.get_height() - 1)
	var pixel: Color = _image.get_pixel(x, y)
	var value: float = pixel.r
	match channel:
		Channel.GREEN:
			value = pixel.g
		Channel.BLUE:
			value = pixel.b
		Channel.ALPHA:
			value = pixel.a
		Channel.LUMINANCE:
			value = pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
	if not is_finite(value):
		return _fallback()
	value = clampf(value, 0.0, 1.0)
	return 1.0 - value if inverse else value


## Nine equal-weight samples: centre and eight fixed points on a world-X/Z ring.
## This is bounded footprint smoothing, not an exact integral or minimum filter.
func sample_world_average(world_position: Vector3, radius: float) -> float:
	if not is_finite(radius) or not world_position.is_finite():
		return _fallback()
	if radius <= 0.0:
		return sample_world(world_position)
	var diagonal: float = radius * 0.7071067811865476
	var total: float = sample_world(world_position)
	total += sample_world(world_position + Vector3(radius, 0, 0))
	total += sample_world(world_position + Vector3(-radius, 0, 0))
	total += sample_world(world_position + Vector3(0, 0, radius))
	total += sample_world(world_position + Vector3(0, 0, -radius))
	total += sample_world(world_position + Vector3(diagonal, 0, diagonal))
	total += sample_world(world_position + Vector3(-diagonal, 0, diagonal))
	total += sample_world(world_position + Vector3(diagonal, 0, -diagonal))
	total += sample_world(world_position + Vector3(-diagonal, 0, -diagonal))
	return total / 9.0


func _ensure_cache() -> bool:
	if not _cache_dirty:
		return _image != null
	_cache_dirty = false
	if texture == null:
		return false
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		_cache_error = "Texture has no readable image. Refresh after it becomes available."
		return false
	# Own a snapshot, including when custom textures return a shared mutable Image.
	_image = source.duplicate() as Image
	if _image.is_compressed() and _image.decompress() != OK:
		_image = null
		_cache_error = "Texture compression cannot be decoded. Use an uncompressed data mask."
		return false
	return true


func _valid_coverage() -> bool:
	return coverage_size.is_finite() and coverage_size.x > 0.0 and coverage_size.y > 0.0


func _fallback() -> float:
	return clampf(outside_value, 0.0, 1.0) if is_finite(outside_value) else 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if texture == null:
		warnings.append("Assign an authored data texture; missing data returns outside_value.")
	if not _valid_coverage():
		warnings.append("coverage_size must have two finite positive dimensions.")
	var pose: Transform3D = global_transform if is_inside_tree() else transform
	if not pose.is_finite() or absf(pose.basis.determinant()) <= 0.00000001:
		warnings.append("The mask transform must be finite and invertible.")
	if not _cache_error.is_empty():
		warnings.append(_cache_error)
	return warnings
