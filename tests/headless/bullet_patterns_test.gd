extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var pattern := NucleusBulletPattern2D.new()
	pattern.count = 4
	pattern.speed = 100.0
	expect_true(pattern.velocity_at(0).is_equal_approx(Vector2(100, 0)), "Radial starts right.")
	expect_true(pattern.velocity_at(1).is_equal_approx(Vector2(0, 100)), "Radial quarter turn.")
	pattern.mode = NucleusBulletPattern2D.Mode.FAN
	pattern.count = 1
	expect_true(pattern.velocity_at(0).is_equal_approx(Vector2(100, 0)), "Single pellet centered.")
	pattern.count = 3
	pattern.spread = PI / 2.0
	expect_float(pattern.velocity_at(0).angle(), -PI / 4.0, "Fan left edge.")
	expect_float(pattern.velocity_at(2).angle(), PI / 4.0, "Fan right edge.")
	pattern.mode = NucleusBulletPattern2D.Mode.LINE
	pattern.line_spacing = 10
	expect_true(pattern.offset_at(0).is_equal_approx(Vector2(0, -10)), "Line symmetric start.")
	expect_true(pattern.offset_at(2).is_equal_approx(Vector2(0, 10)), "Line symmetric end.")
	pattern.mode = NucleusBulletPattern2D.Mode.LOTUS
	pattern.count = 8
	pattern.petals = 4
	expect_float(pattern.velocity_at(0).length(), 100, "Lotus petal tip speed.")
	expect_float(pattern.velocity_at(1).length(), 20, "Lotus valley speed.")
	pattern.mode = NucleusBulletPattern2D.Mode.SPIRAL
	expect_float(pattern.velocity_at(0).length(), 20, "Spiral inner speed.")
	expect_float(pattern.velocity_at(7).length(), 100, "Spiral outer speed.")
	var field := NucleusBulletField2D.new()
	field.capacity = 32
	field.max_spawns_per_frame = 8
	expect_equal(field.reserve_storage(), OK, "Explicit warmup.")
	var storage := field.storage_count()
	expect_equal(pattern.emit_into(field, Vector2.ZERO), 8, "Pattern admitted within budget.")
	expect_equal(pattern.emit_into(field, Vector2.ZERO), 0, "No budget overflow.")
	field.clear_bullets()
	expect_equal(field.storage_count(), storage, "Clear retains allocated storage.")
	expect_equal(field.available_spawns(), 0, "Clear cannot bypass tick budget.")
	field._physics_process(0.01)
	for cycle in 100:
		field.spawn(Vector2.ZERO, Vector2.RIGHT, 0.01)
		field._physics_process(0.02)
	expect_equal(field.storage_count(), storage, "Repeated spawn/expiry does not resize buffers.")
	expect_equal(field.active_count(), 0, "Expired entries are inactive.")
	field.cull_outside_bounds = true
	field.simulation_bounds = Rect2(-1, -1, 2, 2)
	field.spawn(Vector2.ZERO, Vector2.RIGHT * 100, 10)
	field._physics_process(0.1)
	expect_equal(field.active_count(), 0, "Optional field-local bounds reclaim bullets.")
	field.cull_outside_bounds = false
	field.spawn(Vector2.ZERO, Vector2.ZERO, 0.01)
	field.spawn(Vector2.ZERO, Vector2.ZERO, 0.01)
	field.bullet_expired.connect(func(_id: int) -> void: field.clear_bullets())
	field._physics_process(1.0)
	expect_equal(field.active_count(), 0, "Expiry callbacks may clear the field safely.")
	field.free()
	var root := Node2D.new()
	attach_test_node(root)
	field = NucleusBulletField2D.new()
	field.capacity = 100
	field.max_spawns_per_frame = 100
	root.add_child(field)
	field.set_physics_process(false)
	var emitter := NucleusBulletEmitter2D.new()
	emitter.bullet_field = field
	emitter.pattern = NucleusBulletPattern2D.new()
	emitter.pattern.count = 2
	emitter.interval = 0.1
	emitter.maximum_bursts_per_tick = 3
	root.add_child(emitter)
	emitter.set_physics_process(false)
	expect_equal(emitter.advance(2.0), 6, "Hitch catch-up is bounded.")
	expect_equal(emitter.advance(0.0), 0, "No unbounded debt after hitch.")
	field.simulation_enabled = false
	expect_equal(emitter.advance(2.0), 0, "Paused field does not admit continuous bursts.")
	var renderer := NucleusBulletMultiMesh2D.new()
	renderer.bullet_field = field
	root.add_child(renderer)
	renderer.sync_bullets()
	expect_equal(renderer.multimesh.visible_instance_count, 6, "Native renderer uses live count.")
	field.free()
	renderer.sync_bullets()
	expect_equal(renderer.multimesh.visible_instance_count, 0, "Freed field hides stale instances.")
	free_test_node(root)
	return finish()
