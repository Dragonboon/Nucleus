extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_index()
	_test_placement()
	_test_region_cache()
	_test_pattern()
	return finish()


func _test_index() -> void:
	var index := NucleusSpatialPointIndex2D.new()
	expect_equal(index.configure_cell_size(10.0), OK, "Cell size accepted.")
	expect_equal(index.upsert(1, Vector2(-5, -5)), OK, "Negative position accepted.")
	expect_equal(index.upsert(2, Vector2(40, 20)), OK, "Far position accepted.")
	expect_equal(index.query_radius(Vector2(-5, -5), 2.0), [1],
		"Radius query rejects distant point.")
	index.upsert(1, Vector2(40, 21))
	expect_true(index.query_radius(Vector2(-5, -5), 2.0).is_empty(),
		"Moving a point clears its previous bucket.")
	expect_equal(index.query_radius(Vector2(40, 20), 2.0), [1, 2],
		"Moving a point updates its bucket.")
	expect_true(index.remove(1), "Point can be removed.")
	expect_equal(index.query_radius(Vector2(40, 20), 2.0), [2],
		"Removed IDs do not leak into queries.")


func _test_placement() -> void:
	var placement := NucleusSpawnPlacement2D.new()
	placement.minimum_radius = 20.0
	placement.maximum_radius = 20.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var result := placement.find_position(Vector2.ZERO, rng)
	expect_true(result["found"], "Empty world admits a bounded placement.")
	expect_true(is_equal_approx(result["position"].length(), 20.0),
		"Spawn respects the authored annulus.")
	rng.seed = 7
	var denied := placement.find_position(
		Vector2.ZERO, rng, [Rect2(-30, -30, 60, 60)],
	)
	expect_false(denied["found"], "Excluded camera rectangle is respected.")
	expect_equal(denied["attempts"], placement.maximum_attempts,
		"Failed placement has bounded attempts.")


func _test_region_cache() -> void:
	var generator := NucleusProceduralGrid2D.new()
	var cache := NucleusProceduralRegionCache2D.new()
	cache.generator = generator
	cache.maximum_regions = 2
	var first := cache.get_region(Vector2i.ZERO)
	cache.get_region(Vector2i.ONE)
	cache.get_region(Vector2i(2, 2))
	expect_equal(cache.cached_count(), 2, "Cache keeps bounded regions.")
	expect_equal(first, cache.get_region(Vector2i.ZERO),
		"Evicted regions regenerate deterministically.")
	first[0] = 255
	expect_false(first == cache.get_region(Vector2i.ZERO),
		"Caller mutations do not alter cached regions.")


func _test_pattern() -> void:
	var field := NucleusBulletField2D.new()
	field.capacity = 32
	field.max_spawns_per_frame = 32
	var pattern := NucleusBulletPattern2D.new()
	pattern.count = 12
	expect_equal(pattern.emit_into(field, Vector2.ZERO), 12,
		"Pattern emits the configured number.")
	expect_equal(field.available_spawns(), 20, "Admission budget reflects emissions.")
	pattern.mode = NucleusBulletPattern2D.Mode.FAN
	pattern.count = 5
	expect_equal(pattern.emit_into(field, Vector2.ZERO), 5,
		"Fan uses the existing compact bullet simulation.")
	field.free()
