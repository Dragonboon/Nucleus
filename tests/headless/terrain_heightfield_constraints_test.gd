extends "res://tests/headless/test_case.gd"

const TerrainSampler = preload("res://addons/nucleus/modules/terrain/terrain_height_sampler.gd")


func run() -> Dictionary:
	_test_sample_constraints()
	_test_image_conversion_and_native_sampling()
	_test_invalid_inputs()
	return finish()


func _test_sample_constraints() -> void:
	var samples := PackedFloat32Array([
		0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0,
	])
	var slope_degrees := 30.0
	var size := Vector2i(5, 5)
	var cell_m := Vector2(2.0, 3.0)
	var height_scale_m := 10.0
	var limited := NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		samples, size, cell_m, height_scale_m, slope_degrees)
	expect_equal(limited.size(), samples.size(),
		"Slope filtering preserves rectangular grid shape.")
	expect_float(samples[12], 1.0,
		"Slope filtering never changes the authored input array.")
	expect_true(limited[12] < 1.0 and limited[12] > 0.0,
		"One-cell height spikes are lowered, not deleted wholesale.")
	var limit := tan(deg_to_rad(slope_degrees))
	for y: int in range(size.y):
		for x: int in range(size.x):
			var index := y * size.x + x
			expect_true(limited[index] <= samples[index] + 0.00001,
				"Slope filtering must never raise an authored elevation.")
			if x > 0:
				var dx_m := absf(limited[index] - limited[index - 1])
				dx_m *= height_scale_m / cell_m.x
				expect_true(dx_m <= limit + 0.0001,
					"Horizontal derivatives stay within the slope budget.")
			if y > 0:
				var dy_m := absf(limited[index] - limited[index - size.x])
				dy_m *= height_scale_m / cell_m.y
				expect_true(dy_m <= limit + 0.0001,
					"Vertical derivatives stay within the slope budget.")

	var flat := PackedFloat32Array([0.2, 0.2, 0.2, 0.2])
	var unchanged := NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		flat, Vector2i(2, 2), Vector2.ONE, 10.0, 30.0)
	expect_equal(unchanged, flat,
		"Uniform heightfields are preserved exactly.")
	var zero_slope := NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		PackedFloat32Array([0.1, 0.8, 0.5, 0.3]),
		Vector2i(2, 2), Vector2.ONE, 10.0, 0.0)
	for value: float in zero_slope:
		expect_float(value, 0.1,
			"A zero-degree slope converges to the minimum elevation.")


func _test_image_conversion_and_native_sampling() -> void:
	var image := Image.create_empty(3, 3, false, Image.FORMAT_RF)
	image.fill(Color.BLACK)
	image.set_pixel(1, 1, Color(1.0, 0.0, 0.0))
	var limited := NucleusTerrainHeightmapProcessor.limit_heightmap_slopes(
		image, Vector2(2.0, 2.0), 10.0, 35.0)
	expect_true(limited != null,
		"Valid image heightfields produce an independent result.")
	if limited == null:
		return
	expect_equal(limited.get_format(), Image.FORMAT_RF,
		"The generated heightmap uses explicit scalar float data.")
	expect_equal(Vector2i(limited.get_width(), limited.get_height()),
		Vector2i(3, 3), "Image dimensions are preserved.")
	expect_float(image.get_pixel(1, 1).r, 1.0,
		"The caller's original heightmap is not mutated.")
	expect_true(limited.get_pixel(1, 1).r < 1.0,
		"Excessive isolated relief is constrained.")

	# Verify the final Godot sampler, not only the intermediate pixel array.
	var profile := NucleusTerrainProfile.new()
	profile.height_source = NucleusTerrainProfile.HeightSource.HEIGHTMAP
	profile.normalize_heightmap = false
	profile.shape_mode = NucleusTerrainProfile.ShapeMode.RECTANGLE
	profile.size = Vector2(2.0, 2.0)
	profile.height_scale = 10.0
	profile.image = ImageTexture.create_from_image(limited)
	var sampler := TerrainSampler.new()
	expect_equal(sampler.configure(profile), OK,
		"The native terrain sampler accepts the processed heightmap.")
	var max_gradient := tan(deg_to_rad(35.0))
	for y: int in range(8):
		for x: int in range(8):
			var local := Vector2(-1.0, -1.0) + Vector2(x, y) * 0.25
			var h := sampler.sample_height(local, profile.size, Vector2.ZERO)
			var east := sampler.sample_height(
				local + Vector2(0.25, 0.0), profile.size, Vector2.ZERO)
			var south := sampler.sample_height(
				local + Vector2(0.0, 0.25), profile.size, Vector2.ZERO)
			var gradient := Vector2((east - h) / 0.25, (south - h) / 0.25)
			expect_true(gradient.length() <= max_gradient + 0.0002,
				"The native bilinear sampler respects the authored slope bound.")


func _test_invalid_inputs() -> void:
	var source := PackedFloat32Array([0.0, 0.1, 0.2, 0.3])
	expect_true(NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		source, Vector2i(3, 2), Vector2.ONE, 10.0, 35.0).is_empty(),
		"Mismatched sample counts are rejected.")
	expect_true(NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		source, Vector2i(2, 2), Vector2.ZERO, 10.0, 35.0).is_empty(),
		"Invalid physical cell sizes are rejected.")
	expect_true(NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		source, Vector2i(2, 2), Vector2.ONE, 0.0, 35.0).is_empty(),
		"A zero elevation scale is rejected.")
	expect_true(NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		source, Vector2i(2, 2), Vector2.ONE, 10.0, 90.0).is_empty(),
		"Near-vertical slope limits are rejected.")
	expect_true(NucleusTerrainHeightmapProcessor.limit_sample_slopes(
		PackedFloat32Array([NAN, 0.0, 0.0, 0.0]),
		Vector2i(2, 2), Vector2.ONE, 10.0, 35.0).is_empty(),
		"Nonfinite height samples are rejected.")
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RF)
	image.fill(Color(0.5, 0.0, 0.0))
	expect_true(NucleusTerrainHeightmapProcessor.limit_heightmap_slopes(
		image, Vector2.ZERO, 10.0, 35.0) == null,
		"Invalid terrain dimensions return null, not partial results.")
