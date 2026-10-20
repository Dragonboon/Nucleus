extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_flow()
	_test_procedural()
	_test_bullets()
	return finish()


func _test_flow() -> void:
	var field := NucleusFlowField2D.new()
	var cells := PackedByteArray([1, 1, 1, 1, 0, 1, 1, 1, 1])
	expect_equal(field.configure(Vector2i.ZERO, Vector2i(3, 3), cells), OK,
		"Flow field should accept a rectangular grid.")
	expect_equal(field.rebuild([Vector2i(2, 2)]), OK, "Flow rebuild succeeds.")
	expect_equal(field.distance_at(Vector2i(1, 1)), -1, "Center obstacle is blocked.")
	expect_equal(field.distance_at(Vector2i(2, 2)), 0, "Goal has zero distance.")
	expect_equal(field.distance_at(Vector2i(0, 0)), 4, "BFS walks around obstacle.")
	expect_true(field.direction_at(Vector2i(0, 0)) != Vector2.ZERO,
		"Reachable agents have a steering direction.")
	expect_equal(field.distance_at(Vector2i(9, 9)), -1, "Out of bounds blocked.")
	expect_equal(field.rebuild([]), OK, "Empty goal set is allowed.")
	expect_equal(field.distance_at(Vector2i(0, 0)),
		NucleusFlowField2D.UNREACHABLE, "No goals remain unreachable.")


func _test_procedural() -> void:
	var generator := NucleusProceduralGrid2D.new()
	generator.seed = 42
	var first := generator.generate(Vector2i(-1, 3))
	expect_equal(first.size(), 256, "Default regions have 256 cells.")
	expect_equal(first, generator.generate(Vector2i(-1, 3)),
		"Generation is stable without global mutable RNG.")
	expect_equal(generator.region_for_cell(Vector2i(-1, 0)),
		Vector2i(-1, 0), "Negative cell coordinates use floor division.")
	generator.region_size = Vector2i(1000, 1000)
	expect_equal(generator.generate(Vector2i.ZERO).size(), 0,
		"Excessively large regions are refused.")


func _test_bullets() -> void:
	var field := NucleusBulletField2D.new()
	field.capacity = 4
	field.max_spawns_per_frame = 3
	expect_equal(field.spawn_radial(Vector2.ZERO, 100.0, 4, 2.0), 3,
		"Radial emission respects the per-frame admission budget.")
	expect_equal(field.active_count(), 3, "Bullets use compact active arrays.")
	expect_equal(field.spawn(Vector2.ZERO, Vector2.RIGHT, 2.0), -1,
		"Additional emission is rejected within this frame.")
	field._physics_process(0.1)
	expect_true(field.query_swept_circle(Vector2.ZERO, 1.0).size() > 0,
		"Swept broad-phase detects movement between frames.")
	expect_true(field.remove_at(1), "Explicit removal succeeds.")
	expect_equal(field.active_count(), 2, "Swap removal compacts the arrays.")
	field.clear_bullets()
	expect_equal(field.active_count(), 0, "Clear resets every packed array.")
	field.free()
