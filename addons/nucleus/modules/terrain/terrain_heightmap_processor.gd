class_name NucleusTerrainHeightmapProcessor
extends RefCounted
## Deterministic preprocessing helpers for heightfield source images.
##
## Processing is explicit and non-destructive: every operation returns a new
## Image. Use this during world generation/loading, not as a per-frame effect.


static func transformed(
	source: Image,
	quarter_turns: int = 0,
	mirror_x: bool = false,
	mirror_y: bool = false,
) -> Image:
	var working := _editable_copy(source)

	if working == null:
		return null

	var turns := ((quarter_turns % 4) + 4) % 4

	for _turn: int in range(turns):
		working = _rotate_clockwise(working)

	if mirror_x:
		working.flip_x()

	if mirror_y:
		working.flip_y()

	return working


static func prefilter_for_resolution(
	source: Image,
	terrain_resolution: int,
	restore_source_dimensions: bool = true,
) -> Image:
	if source == null or source.is_empty():
		return null

	var sample_limit := maxi(2, terrain_resolution + 1)
	return prefilter_to_sample_limit(
		source,
		sample_limit,
		restore_source_dimensions,
	)


static func prefilter_to_sample_limit(
	source: Image,
	maximum_dimension: int,
	restore_source_dimensions: bool = true,
) -> Image:
	var working := _editable_copy(source)

	if working == null:
		return null

	var source_size := Vector2i(
		working.get_width(),
		working.get_height(),
	)
	var target_size := _fit_within(
		source_size,
		maxi(2, maximum_dimension),
	)

	if target_size == source_size:
		return working

	working.resize(
		target_size.x,
		target_size.y,
		Image.INTERPOLATE_LANCZOS,
	)

	if restore_source_dimensions:
		working.resize(
			source_size.x,
			source_size.y,
			Image.INTERPOLATE_CUBIC,
		)

	return working


static func texture_prefiltered_for_resolution(
	source: Texture2D,
	terrain_resolution: int,
	restore_source_dimensions: bool = true,
) -> ImageTexture:
	if source == null:
		return null

	var source_image := source.get_image()
	var processed := prefilter_for_resolution(
		source_image,
		terrain_resolution,
		restore_source_dimensions,
	)

	if processed == null:
		return null

	return ImageTexture.create_from_image(processed)


static func suggested_sample_limit(
	source_size: Vector2i,
	terrain_resolution: int,
) -> Vector2i:
	if source_size.x <= 0 or source_size.y <= 0:
		return Vector2i.ZERO

	return _fit_within(
		source_size,
		maxi(2, terrain_resolution + 1),
	)


## Limit terrain slopes on a normalized RED heightmap without changing its source.
## Returns FORMAT_RF data. Invalid input returns null, never a partial result.
## Call after any resampling, curve baking or artistic height modifications.
static func limit_heightmap_slopes(
	source: Image,
	terrain_size_m: Vector2,
	height_scale_m: float,
	maximum_slope_degrees: float,
) -> Image:
	var working := _editable_copy(source)
	if working == null:
		return null

	var dimensions := Vector2i(working.get_width(), working.get_height())
	if dimensions.x < 2 or dimensions.y < 2:
		return null
	if not terrain_size_m.is_finite():
		return null

	var values := PackedFloat32Array()
	values.resize(dimensions.x * dimensions.y)
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var value := working.get_pixel(x, y).r
			if not is_finite(value):
				return null
			values[y * dimensions.x + x] = value

	var spacing := terrain_size_m / Vector2(dimensions - Vector2i.ONE)
	var limited := limit_sample_slopes(
		values,
		dimensions,
		spacing,
		height_scale_m,
		maximum_slope_degrees,
	)
	if limited.is_empty():
		return null

	var result := Image.create_empty(
		dimensions.x,
		dimensions.y,
		false,
		Image.FORMAT_RF,
	)
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			result.set_pixel(
				x,
				y,
				Color(limited[y * dimensions.x + x], 0.0, 0.0),
			)
	return result


## Conservative horizontal slope bound in metres, including bilinear cells.
## Two in-place min-plus scans lower sharp peaks without raising any samples.
## Input and returned sample arrays never share mutable storage.
## Empty return means the dimensions, spacings, scale or samples are invalid.
static func limit_sample_slopes(
	values: PackedFloat32Array,
	sample_size: Vector2i,
	meters_per_cell: Vector2,
	height_scale_m: float,
	maximum_slope_degrees: float,
) -> PackedFloat32Array:
	var empty := PackedFloat32Array()
	if sample_size.x < 2 or sample_size.y < 2:
		return empty
	if sample_size.x > values.size() / sample_size.y:
		return empty
	if values.size() != sample_size.x * sample_size.y:
		return empty
	if not meters_per_cell.is_finite():
		return empty
	if meters_per_cell.x <= 0.0 or meters_per_cell.y <= 0.0:
		return empty
	if not is_finite(height_scale_m) or height_scale_m <= 0.0:
		return empty
	if not is_finite(maximum_slope_degrees):
		return empty
	if maximum_slope_degrees < 0.0 or maximum_slope_degrees >= 89.9:
		return empty

	for value: float in values:
		if not is_finite(value):
			return empty

	# Bound each axis by tan(theta) / sqrt(2). Both partial derivatives
	# then fit inside tan(theta) even on a bilinearly interpolated cell.
	var maximum_gradient := tan(deg_to_rad(maximum_slope_degrees))
	var normalized_gradient := maximum_gradient / (height_scale_m * sqrt(2.0))
	var step_x := normalized_gradient * meters_per_cell.x
	var step_y := normalized_gradient * meters_per_cell.y
	if not is_finite(step_x) or not is_finite(step_y):
		return empty

	var result := values.duplicate()
	for y: int in range(sample_size.y):
		for x: int in range(sample_size.x):
			var index := y * sample_size.x + x
			var current: float = result[index]
			if x > 0:
				current = minf(current, result[index - 1] + step_x)
			if y > 0:
				current = minf(current, result[index - sample_size.x] + step_y)
			result[index] = current

	for y: int in range(sample_size.y - 1, -1, -1):
		for x: int in range(sample_size.x - 1, -1, -1):
			var index := y * sample_size.x + x
			var current: float = result[index]
			if x + 1 < sample_size.x:
				current = minf(current, result[index + 1] + step_x)
			if y + 1 < sample_size.y:
				current = minf(current, result[index + sample_size.x] + step_y)
			result[index] = current

	return result


static func _editable_copy(source: Image) -> Image:
	if source == null or source.is_empty():
		return null

	var working := source.duplicate()

	if working.is_compressed():
		var decompress_error: Error = working.decompress()

		if decompress_error != OK:
			return null

	return working


static func _fit_within(
	source_size: Vector2i,
	maximum_dimension: int,
) -> Vector2i:
	var largest := maxi(source_size.x, source_size.y)

	if largest <= maximum_dimension:
		return source_size

	var factor := float(maximum_dimension) / float(largest)
	return Vector2i(
		maxi(2, int(round(float(source_size.x) * factor))),
		maxi(2, int(round(float(source_size.y) * factor))),
	)


static func _rotate_clockwise(source: Image) -> Image:
	var target := Image.create_empty(
		source.get_height(),
		source.get_width(),
		false,
		source.get_format(),
	)

	for source_y: int in range(source.get_height()):
		for source_x: int in range(source.get_width()):
			target.set_pixel(
				source.get_height() - 1 - source_y,
				source_x,
				source.get_pixel(source_x, source_y),
			)

	return target
