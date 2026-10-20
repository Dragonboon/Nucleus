extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	var field := NucleusBulletField2D.new()
	field.projectile_radius = 1.0
	field.spawn(Vector2.ZERO, Vector2.RIGHT * 100.0, 2.0)
	field._physics_process(0.1)
	var targets := NucleusBulletTargetBatch2D.new()
	expect_equal(targets.upsert_circle(17, Vector2(5, 0), 2.0), OK,
		"Target can be registered.")
	expect_equal(targets.query_bullet_hits(field), [Vector2i(1, 17)],
		"Swept bullet hits intermediate circle.")
	targets.upsert_circle(17, Vector2(50, 0), 2.0)
	expect_equal(targets.query_bullet_hits(field).size(), 0,
		"Moved target no longer registers stale hits.")
	var crowd := NucleusSpatialPointIndex2D.new()
	crowd.upsert(1, Vector2.ZERO)
	crowd.upsert(2, Vector2(10, 0))
	var steering := NucleusCrowdSeparation2D.calculate(
		1, Vector2.ZERO, crowd, 20.0,
	)
	expect_true(steering.x < 0.0, "Crowd steering repels close neighbors.")
	field.free()
	return finish()
