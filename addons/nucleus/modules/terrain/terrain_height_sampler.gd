extends RefCounted
## Internal CPU sampler shared by preview, mesh, and collision generation.

static var _image_range_cache: Dictionary = {}

var _profile: NucleusTerrainProfile
var _noise: FastNoiseLite
var _shoreline_noise: FastNoiseLite
var _edge_floor_noise: FastNoiseLite
var _image: Image
var _falloff_image: Image
var _image_min: float = 0.0
var _image_range: float = 1.0


func configure(profile: NucleusTerrainProfile) -> Error:
	_profile = profile

	if _profile == null:
		return ERR_INVALID_PARAMETER

	if _profile.height_source == NucleusTerrainProfile.HeightSource.FAST_NOISE:
		if _profile.noise == null:
			return ERR_UNCONFIGURED
		_noise = _profile.noise.duplicate() as FastNoiseLite
	else:
		if _profile.image == null:
			return ERR_UNCONFIGURED
		_image = _prepare_image(_profile.image)
		if _image == null or _image.is_empty():
			return ERR_INVALID_DATA
		_prepare_image_range()

	if _profile.shoreline_noise != null:
		_shoreline_noise = _profile.shoreline_noise.duplicate() as FastNoiseLite

	if _profile.edge_floor_noise != null:
		_edge_floor_noise = _profile.edge_floor_noise.duplicate() as FastNoiseLite

	if _profile.falloff_texture != null:
		_falloff_image = _prepare_image(_profile.falloff_texture)

	return OK


func sample_height(
	local_position: Vector2,
	patch_size: Vector2,
	patch_sampling_origin: Vector2,
	force_island: bool = false,
) -> float:
	var normalized := Vector2(
		local_position.x / patch_size.x + 0.5,
		local_position.y / patch_size.y + 0.5,
	)
	var world_sample := (
		patch_sampling_origin
		+ local_position
		+ _profile.sampling_offset
	)
	var source_value := _sample_source(normalized, world_sample, patch_size)

	if _profile.elevation_curve != null:
		source_value = _profile.elevation_curve.sample(source_value)

	var height := _profile.base_height + source_value * _profile.height_scale
	var mask := _sample_shape_mask(
		normalized,
		world_sample,
		force_island,
	)
	var floor_height := _sample_edge_floor_height(world_sample)

	return lerpf(floor_height, height, mask)


func _sample_source(
	normalized: Vector2,
	world_sample: Vector2,
	patch_size: Vector2,
) -> float:
	if _profile.height_source == NucleusTerrainProfile.HeightSource.FAST_NOISE:
		return (_noise.get_noise_2d(world_sample.x, world_sample.y) + 1.0) * 0.5

	var uv := normalized

	if _profile.image_mapping == NucleusTerrainProfile.ImageMapping.WORLD_REPEAT:
		uv = Vector2(
			world_sample.x / _profile.image_world_size.x,
			world_sample.y / _profile.image_world_size.y,
		)
		uv = Vector2(_fract(uv.x), _fract(uv.y))
	elif patch_size.x <= 0.0 or patch_size.y <= 0.0:
		return 0.0

	var value := _sample_image_bilinear(_image, uv)

	if (
		_profile.height_source == NucleusTerrainProfile.HeightSource.HEIGHTMAP
		and _profile.normalize_heightmap
	):
		value = (value - _image_min) / _image_range

	return clampf(value, 0.0, 1.0)


func _sample_shape_mask(
	normalized: Vector2,
	world_sample: Vector2,
	force_island: bool,
) -> float:
	var mask := 1.0
	var island_enabled := (
		force_island
		or _profile.shape_mode == NucleusTerrainProfile.ShapeMode.ISLAND
	)

	if island_enabled:
		var centered := (normalized - Vector2(0.5, 0.5)) * 2.0
		var distance := centered.length()

		if _shoreline_noise != null and _profile.shoreline_noise_strength > 0.0:
			distance += (
				_shoreline_noise.get_noise_2d(world_sample.x, world_sample.y)
				* _profile.shoreline_noise_strength
			)

		var outer_radius := minf(
			1.0,
			_profile.island_inner_radius + _profile.island_falloff,
		)
		var edge := smoothstep(
			_profile.island_inner_radius,
			outer_radius,
			distance,
		)
		mask *= pow(maxf(0.0, 1.0 - edge), _profile.island_power)

	if _falloff_image != null and not _falloff_image.is_empty():
		mask *= _sample_image_bilinear(_falloff_image, normalized)

	return clampf(mask, 0.0, 1.0)


func _sample_edge_floor_height(world_sample: Vector2) -> float:
	var height := _profile.edge_floor_height

	if _edge_floor_noise == null or _profile.edge_floor_noise_strength <= 0.0:
		return height

	height += (
		_edge_floor_noise.get_noise_2d(world_sample.x, world_sample.y)
		* _profile.edge_floor_noise_strength
	)
	return height


func _prepare_image(texture: Texture2D) -> Image:
	var result := texture.get_image()

	if result == null:
		return null

	if result.is_compressed():
		var error: Error = result.decompress()
		if error != OK:
			return null

	return result


func _prepare_image_range() -> void:
	if (
		_profile.height_source != NucleusTerrainProfile.HeightSource.HEIGHTMAP
		or not _profile.normalize_heightmap
	):
		return

	var cache_key := _profile.image.get_instance_id()

	if _image_range_cache.has(cache_key):
		var cached: Vector2 = _image_range_cache[cache_key]
		_image_min = cached.x
		_image_range = cached.y
		return

	var minimum := 1.0
	var maximum := 0.0

	for y: int in range(_image.get_height()):
		for x: int in range(_image.get_width()):
			var value := _image.get_pixel(x, y).r
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)

	_image_min = minimum
	_image_range = maxf(0.000001, maximum - minimum)
	_image_range_cache[cache_key] = Vector2(_image_min, _image_range)


func _sample_image_bilinear(image: Image, uv: Vector2) -> float:
	if image == null or image.is_empty():
		return 0.0

	var width := image.get_width()
	var height := image.get_height()
	var px := clampf(uv.x, 0.0, 1.0) * float(width - 1)
	var py := clampf(uv.y, 0.0, 1.0) * float(height - 1)
	var x0 := clampi(int(floor(px)), 0, width - 1)
	var y0 := clampi(int(floor(py)), 0, height - 1)
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var tx := px - float(x0)
	var ty := py - float(y0)
	var a := lerpf(image.get_pixel(x0, y0).r, image.get_pixel(x1, y0).r, tx)
	var b := lerpf(image.get_pixel(x0, y1).r, image.get_pixel(x1, y1).r, tx)

	return lerpf(a, b, ty)


func _fract(value: float) -> float:
	return value - floor(value)
