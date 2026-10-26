extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var rects := NucleusSpatialRectIndex2D.new()
	for id in 40:
		rects.upsert(id, Rect2(id, id, 10, 10), id % 3)
	var output: Array[int] = [999]
	var scratch := {999: true}
	var region := Rect2(0, 0, 30, 30)
	rects.query_region_into(region, output, scratch)
	expect_equal(output, rects.query_region(region), "Reusable query preserves ordering.")
	rects.max_query_cells = 1
	rects.query_region_into(Rect2(-100, -100, 500, 500), output, scratch)
	expect_equal(output.size(), 40, "Large exact query never truncates candidates.")
	rects.query_region_into(Rect2(Vector2(INF, 0), Vector2.ONE), output, scratch)
	expect_true(output.is_empty() and scratch.is_empty(), "Invalid query clears stale output.")
	var points := NucleusSpatialPointIndex2D.new()
	for id in 1000:
		points.upsert(id, Vector2(id % 5, id % 7))
	var nearby := points.query_radius_bounded(Vector2.ZERO, 20, 24, 10, 64, 0)
	expect_equal(nearby.size(), 9, "Inspection cap includes excluded candidates.")
	expect_false(nearby.has(0), "Self excluded before result admission.")
	expect_equal(nearby, points.query_radius_bounded(Vector2.ZERO, 20, 24, 10, 64, 0),
		"Stable unchanged membership.")
	expect_equal(points.query_radius(Vector2.ZERO, 20).size(), 1000,
		"Exact public query remains complete.")
	var field := NucleusBulletField2D.new()
	field.capacity = 200
	field.max_spawns_per_frame = 200
	for id in 200:
		field.spawn(Vector2.ZERO, Vector2.ZERO, 10)
	var batch := NucleusBulletTargetBatch2D.new()
	for id in 100:
		batch.upsert_circle(id, Vector2.ZERO, 1)
	var hits: Array[Vector2i] = []
	batch.query_bullet_hits_into(field, hits)
	expect_equal(hits.size(), 20000, "Uncapped path resolves all hits beyond old cap.")
	expect_equal(batch.query_bullet_hits(field, 7), hits.slice(0, 7),
		"Legacy hit order and positive cap preserved.")
	expect_true(batch.query_bullet_hits(field, 0).is_empty(), "Legacy zero cap preserved.")
	batch.clear()
	batch.query_bullet_hits_into(field, hits)
	expect_true(hits.is_empty(), "No targets clears reused hits.")
	field.free()
	return finish()
