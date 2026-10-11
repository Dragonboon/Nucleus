extends "res://tests/headless/test_case.gd"

func run() -> Dictionary:
	_test_layout()
	_test_occupancy()
	_test_modular_rules()
	return finish()

func _test_layout() -> void:
	for cell in [Vector2i(-3, 4), Vector2i.ZERO, Vector2i(2, -5)]:
		for iso in [false, true]:
			var pos := NucleusSquareLayout.cell_to_local(cell, Vector2(40, 20), iso)
			expect_equal(NucleusSquareLayout.local_to_cell(pos, Vector2(40, 20), iso),
				cell, "Square geometry roundtrip.")
	expect_equal(NucleusSquareLayout.distance(Vector2i(-2, 1), Vector2i(1, -3)),
		7, "Manhattan distance.")
	expect_equal(NucleusSquareLayout.rotate_cell(Vector2i(1, 0), 4),
		Vector2i(1, 0), "Quarter rotation wraps.")
	expect_equal(NucleusSquareLayout.line(Vector2i.ZERO, Vector2i(3, 1)).size(),
		4, "Bresenham includes all steps.")
	expect_true(NucleusSquareLayout.line(Vector2i.ZERO, Vector2i(200, 0)).is_empty(),
		"Overlong strokes are bounded.")
	var enter := func(cell: Vector2i) -> bool: return cell != Vector2i(1, 0)
	var path := NucleusSquareLayout.shortest_path(Vector2i.ZERO, Vector2i(2, 0), enter)
	expect_equal(path.size(), 5, "BFS avoids blocked cells.")

func _test_occupancy() -> void:
	var root := Node2D.new()
	expect_true(attach_test_node(root), "Board needs SceneTree.")
	var board := NucleusSquareBoard2D.new()
	root.add_child(board)
	expect_true(board.paint_cell(Vector2i.ZERO), "First tile accepted.")
	expect_true(board.paint_cell(Vector2i(1, 0)), "Adjacent tile accepted.")
	expect_false(board.paint_cell(Vector2i.ZERO), "Duplicate tile rejected.")
	expect_equal(board.shared_corner_count(), 2, "Adjacent squares share two vertices.")
	expect_true(board.rotate_tile(Vector2i.ZERO), "Tile orientation editable.")
	expect_equal(board.get_rotation_steps(Vector2i.ZERO), 1, "Quarter turn stored.")
	expect_true(board.erase_cell(Vector2i(1, 0)), "Erase releases neighbors.")
	expect_equal(board.shared_corner_count(), 0, "No stale corner edges.")
	free_test_node(root)
	var world := Node3D.new()
	expect_true(attach_test_node(world), "3D grid needs SceneTree.")
	var board3 := NucleusSquareBoard3D.new()
	world.add_child(board3)
	var cell := Vector3i(-2, 3, 1)
	expect_equal(board3.world_to_cell(board3.cell_to_world(cell), cell.z), cell,
		"3D layer roundtrip.")
	expect_true(board3.paint_cell(cell), "3D cell paints.")
	expect_true(board3.rotate_tile(cell), "3D rotation stores.")
	expect_equal(board3.get_rotation_steps(cell), 1, "3D quarter turn.")
	free_test_node(world)

func _test_modular_rules() -> void:
	var rule := NucleusModularRule.new()
	rule.neighbor_mask = 2
	rule.variant_id = &"wall_end"
	var catalog := NucleusModularRuleSet.new()
	catalog.fallback_variant = &"isolated"
	catalog.rules = [rule]
	expect_equal(catalog.resolve(2), &"wall_end", "Neighbor rule selects variant.")
	expect_equal(catalog.resolve(0), &"isolated", "Fallback for unmatched mask.")
	var occupied := func(cell: Vector2i) -> bool:
		return cell == Vector2i(1, 0)
	expect_equal(NucleusModularRuleSet.neighbor_mask(Vector2i.ZERO, occupied),
		2, "East neighbor bitmask.")
