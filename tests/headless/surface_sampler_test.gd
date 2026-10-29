extends "res://tests/headless/test_case.gd"

const TerrainHeightSampler := preload(
	"res://addons/nucleus/modules/terrain/terrain_height_sampler.gd"
)


func run() -> Dictionary:
	_test_surface_sample_contract()
	_test_plane_sampler()
	_test_sample_into_reuses_result()
	_test_tilted_plane_sampler()
	_test_disabled_sampler()
	_test_terrain_sampler_matches_height_source()
	_test_terrain_sampler_layout_selection()
	_test_terrain_sampler_bounds()
	return finish()


func _test_surface_sample_contract() -> void:
	var source_metadata := {"kind": "test"}
	var sample := NucleusSurfaceSample3D.new(
		Vector3(2.0, 5.0, 7.0),
		Vector3(0.0, 2.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		12.5,
		source_metadata,
	)
	source_metadata["kind"] = "mutated"

	expect_true(sample.is_valid(), "A finite surface sample should validate.")
	expect_true(
		sample.normal.is_equal_approx(Vector3.UP),
		"Surface samples should normalize their normal.",
	)
	expect_float(sample.get_height(), 5.0, "Sample height should expose position.y.")
	expect_float(
		sample.get_vertical_delta(Vector3(2.0, 3.0, 7.0)),
		2.0,
		"Vertical delta should be positive when the surface is above the query.",
	)
	expect_equal(
		sample.metadata["kind"],
		"test",
		"Surface sample metadata should be copied from the caller.",
	)


func _test_plane_sampler() -> void:
	var plane := NucleusPlaneSurfaceSampler3D.new()
	plane.position = Vector3(0.0, 4.0, 0.0)
	plane.surface_velocity = Vector3(2.0, 0.0, -1.0)
	expect_true(
		attach_test_node(plane),
		"Plane sampler transform test requires a live SceneTree.",
	)
	var sample := plane.sample(Vector3(10.0, -20.0, 8.0), 3.0)

	expect_true(sample != null, "Horizontal plane should produce a surface sample.")

	if sample != null:
		expect_true(
			sample.position.is_equal_approx(Vector3(10.0, 4.0, 8.0)),
			"Plane sample should preserve query X/Z and solve surface Y.",
		)
		expect_true(
			sample.velocity.is_equal_approx(Vector3(2.0, 0.0, -1.0)),
			"Plane sampler should expose configured world-space surface velocity.",
		)
		expect_float(sample.sampled_time, 3.0, "Explicit sample time should be retained.")

	free_test_node(plane)


func _test_sample_into_reuses_result() -> void:
	var plane := NucleusPlaneSurfaceSampler3D.new()
	plane.position.y = 6.0
	expect_true(
		attach_test_node(plane),
		"Reusable plane sampler test requires a live SceneTree.",
	)
	var scratch := NucleusSurfaceSample3D.new()

	expect_true(
		plane.sample_into(Vector3(1.0, 0.0, 2.0), scratch),
		"sample_into should populate a reusable result object.",
	)
	expect_float(scratch.position.y, 6.0, "Reusable sample should contain first query.")

	plane.position.y = 9.0
	expect_true(
		plane.sample_into(Vector3(4.0, 0.0, 5.0), scratch),
		"sample_into should support repeated allocation-free queries.",
	)
	expect_true(
		scratch.position.is_equal_approx(Vector3(4.0, 9.0, 5.0)),
		"Repeated sample_into should overwrite the previous result.",
	)
	free_test_node(plane)


func _test_tilted_plane_sampler() -> void:
	var plane := NucleusPlaneSurfaceSampler3D.new()
	plane.rotation_degrees = Vector3(0.0, 0.0, 30.0)
	plane.position = Vector3(0.0, 2.0, 0.0)
	expect_true(
		attach_test_node(plane),
		"Tilted plane sampler test requires a live SceneTree.",
	)
	var query := Vector3(3.0, -10.0, -2.0)
	var sample := plane.sample(query)

	expect_true(sample != null, "A non-vertical tilted plane should remain sampleable.")

	if sample != null:
		var plane_delta := sample.position - plane.global_position
		expect_float(
			plane_delta.dot(sample.normal),
			0.0,
			"Sampled point should lie on the transformed plane.",
		)
		expect_float(sample.position.x, query.x, "Tilted sample should preserve world X.")
		expect_float(sample.position.z, query.z, "Tilted sample should preserve world Z.")

	free_test_node(plane)


func _test_disabled_sampler() -> void:
	var plane := NucleusPlaneSurfaceSampler3D.new()
	plane.enabled = false

	expect_true(
		plane.sample(Vector3.ZERO) == null,
		"Disabled surface samplers should reject queries.",
	)
	plane.free()


func _test_terrain_sampler_matches_height_source() -> void:
	var profile := _make_terrain_profile()
	var terrain := NucleusTerrainGenerator3D.new()
	terrain.profile = profile
	terrain.position = Vector3(4.0, 3.0, -6.0)
	var sampler := NucleusTerrainSurfaceSampler3D.new()
	terrain.add_child(sampler)
	expect_true(
		attach_test_node(terrain),
		"Terrain sampler transform test requires a live SceneTree.",
	)
	var local_xz := Vector2(5.0, -7.0)
	var query := terrain.to_global(Vector3(local_xz.x, 50.0, local_xz.y))
	var expected_sampler := TerrainHeightSampler.new()
	var configure_error: Error = expected_sampler.configure(profile)

	expect_equal(configure_error, OK, "Reference terrain height sampler should configure.")

	var expected_height := expected_sampler.sample_height(
		local_xz,
		profile.size,
		Vector2.ZERO,
		false,
	)
	var sample := sampler.sample(query, 42.0)

	expect_true(sample != null, "Terrain adapter should sample inside its static patch.")

	if sample != null:
		expect_float(
			sample.position.y,
			terrain.position.y + expected_height,
			"Terrain adapter should reuse the generator's analytical height source.",
		)
		expect_true(
			sample.normal.y > 0.0,
			"Terrain analytical normal should face upward.",
		)
		expect_float(sample.sampled_time, 42.0, "Terrain sample should retain query time.")
		expect_equal(
			sample.metadata["terrain_patch_index"],
			0,
			"Single terrain layout should identify patch zero.",
		)

	free_test_node(terrain)


func _test_terrain_sampler_layout_selection() -> void:
	var terrain := NucleusTerrainGenerator3D.new()
	terrain.profile = _make_terrain_profile()
	var layout := NucleusTerrainLayout.new()
	layout.mode = NucleusTerrainLayout.Mode.GRID
	layout.grid_size = Vector2i(2, 1)
	terrain.layout = layout
	var sampler := NucleusTerrainSurfaceSampler3D.new()
	terrain.add_child(sampler)
	expect_true(
		attach_test_node(terrain),
		"Terrain grid sampler test requires a live SceneTree.",
	)
	var sample := sampler.sample(Vector3(20.0, 0.0, 0.0))

	expect_true(sample != null, "Terrain grid should resolve the containing patch.")

	if sample != null:
		expect_equal(
			sample.metadata["terrain_patch_index"],
			1,
			"Terrain sampler should report the selected static layout patch.",
		)

	free_test_node(terrain)


func _test_terrain_sampler_bounds() -> void:
	var terrain := NucleusTerrainGenerator3D.new()
	terrain.profile = _make_terrain_profile()
	var sampler := NucleusTerrainSurfaceSampler3D.new()
	terrain.add_child(sampler)
	expect_true(
		attach_test_node(terrain),
		"Terrain bounds sampler test requires a live SceneTree.",
	)

	expect_true(
		sampler.sample(Vector3(1000.0, 0.0, 1000.0)) == null,
		"Terrain adapter should reject positions outside static layout coverage.",
	)
	free_test_node(terrain)


func _make_terrain_profile() -> NucleusTerrainProfile:
	var profile := NucleusTerrainProfile.new()
	var noise := FastNoiseLite.new()
	noise.seed = 7123
	noise.frequency = 0.025
	profile.noise = noise
	profile.size = Vector2(64.0, 64.0)
	profile.base_height = 2.0
	profile.height_scale = 12.0
	return profile
