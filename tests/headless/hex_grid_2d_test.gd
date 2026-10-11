extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_layout_parity()
	_test_neighbors_and_path()
	_test_board_2d()
	_test_board_3d_orientation()
	return finish()


func _test_layout_parity() -> void:
	for flat: bool in [false, true]:
		for cell: Vector2i in [
			Vector2i.ZERO, Vector2i(2, -3), Vector2i(-4, 2), Vector2i(5, 1),
		]:
			var point: Vector2 = NucleusHexLayout.axial_to_pixel(cell, 7.5, flat)
			expect_equal(
				NucleusHexLayout.pixel_to_axial(point, 7.5, flat), cell,
				"Both orientations must round-trip shared axial coordinates.",
			)
			var point_3d := NucleusHexLayout3D.axial_to_local(cell, 7.5, flat)
			expect_float(point_3d.x, point.x, "2D and 3D X coordinates agree.")
			expect_float(point_3d.z, point.y, "2D Y corresponds to 3D Z.")
			expect_equal(
				NucleusHexLayout3D.local_to_axial(point_3d, 7.5, flat), cell,
				"3D adapter must agree with shared 2D math.",
			)
	for cell: Vector2i in NucleusHexLayout.cells_in_radius(2):
		expect_equal(
			NucleusHexLayout.rotate_axial(cell, 6), cell,
			"Full hex turn preserves axial coordinate.",
		)
		expect_equal(
			NucleusHexLayout.rotate_axial(cell, 1),
			NucleusHexLayout.rotate_axial(cell, -5),
			"Negative rotations wrap to six steps.",
		)
	expect_equal(NucleusHexLayout.cells_in_radius(4).size(), 61, "Four rings total 61 cells.")
	expect_equal(
		NucleusHexLayout.line(Vector2i.ZERO, Vector2i(3, -2)).size(), 4,
		"Line traversal is contiguous with both endpoints.",
	)


func _test_neighbors_and_path() -> void:
	var start: Vector2i = Vector2i.ZERO
	for side: int in range(6):
		var neighbor: Vector2i = NucleusHexLayout.edge_neighbor(start, side)
		expect_equal(NucleusHexLayout.distance(start, neighbor), 1, "An edge joins neighbors.")
	var target: Vector2i = Vector2i(2, 0)
	var blocked: Vector2i = Vector2i(1, 0)
	var walkable := func(cell: Vector2i) -> bool:
		return cell != blocked and NucleusHexLayout.in_radius(cell, 3)
	var path: Array[Vector2i] = NucleusHexLayout.shortest_path(start, target, walkable)
	expect_equal(path.size(), 4, "Uniform-cost path detours around a blocked hex.")
	if not path.is_empty():
		expect_equal(path[0], start, "Path begins at source.")
		expect_equal(path[path.size() - 1], target, "Path ends at destination.")
		expect_false(path.has(blocked), "Blocked tile is excluded.")
	expect_true(
		NucleusHexLayout.shortest_path(start, target, walkable, 2).is_empty(),
		"Search must fail closed at its visit limit.",
	)


func _test_board_2d() -> void:
	var root := Node2D.new()
	expect_true(attach_test_node(root), "2D board needs a SceneTree parent.")
	var board := NucleusHexBoard2D.new()
	root.add_child(board)
	var stats := {"corners": 0, "disconnects": 0, "edges": 0, "edge_ends": 0}
	board.corner_connected.connect(_count_corner.bind(stats, "corners"))
	board.corner_disconnected.connect(_count_corner.bind(stats, "disconnects"))
	board.edge_connected.connect(_count_edge.bind(stats, "edges"))
	board.edge_disconnected.connect(_count_edge.bind(stats, "edge_ends"))
	var a := Vector2i.ZERO
	var b := Vector2i(1, 0)
	expect_true(board.paint_cell(a), "First 2D tile should paint.")
	expect_true(board.paint_cell(b), "Neighbor should paint.")
	expect_false(board.paint_cell(b), "Duplicate occupancy should be rejected.")
	expect_equal(int(stats["corners"]), 2, "Neighbors share two corners.")
	expect_equal(int(stats["edges"]), 1, "Neighbors share one edge.")
	expect_equal(board.shared_corner_count(), 2, "Corner index is populated.")
	board.highlight_selection(a)
	expect_true(board.rotate_tile(a, 1), "Individual rotation succeeds.")
	expect_equal(board.get_rotation_steps(a), 1, "Rotation belongs to the tile.")
	expect_equal(board.get_rotation_steps(b), 0, "Neighbor rotation does not change.")
	board.position = Vector2(120.0, -32.0)
	board.rotation = PI / 3.0
	board.set_flat_top(true)
	board.set_cell_radius(16.0)
	var cell := Vector2i(-2, 1)
	expect_equal(board.world_to_cell(board.cell_to_world(cell)), cell,
		"Board transforms and flat orientation preserve identity.")
	expect_true(board.erase_cell(b), "2D tile removal succeeds.")
	expect_equal(int(stats["disconnects"]), 2, "Removal disconnects two corners.")
	expect_equal(int(stats["edge_ends"]), 1, "Removal disconnects shared edge.")
	expect_equal(board.shared_corner_count(), 0, "No stale corners remain.")
	expect_true(board.move_tile(a, Vector2i(0, 1)), "Move to vacant 2D cell succeeds.")
	expect_equal(board.get_rotation_steps(Vector2i(0, 1)), 1, "Move preserves orientation.")
	board.clear_tiles()
	expect_equal(board.tile_count(), 0, "Clearing removes all 2D tiles.")
	free_test_node(root)


func _test_board_3d_orientation() -> void:
	var root := Node3D.new()
	expect_true(attach_test_node(root), "3D board needs a SceneTree parent.")
	var board := NucleusHexBoard3D.new()
	root.add_child(board)
	board.set_flat_top(true)
	expect_true(board.paint_cell(Vector3i.ZERO), "Flat-top 3D tile can be painted.")
	expect_true(board.paint_cell(Vector3i(1, 0, 0)), "Flat-top neighbor can paint.")
	expect_equal(board.shared_corner_count(), 2,
		"Changing visual orientation retains exact shared corners.")
	board.position = Vector3(5.0, 1.0, 3.0)
	board.rotation.y = 0.6
	var cell := Vector3i(2, -1, 0)
	expect_equal(board.world_to_cell(board.cell_to_world(cell), 0), cell,
		"Flat-top 3D grid survives board translation and rotation.")
	board.set_flat_top(false)
	expect_equal(board.world_to_cell(board.cell_to_world(cell), 0), cell,
		"Returning to pointy-top preserves tile address.")
	free_test_node(root)


func _count_corner(
	_a: Vector2i, _ca: int, _b: Vector2i, _cb: int, _p: Vector2,
	stats: Dictionary, field: String,
) -> void:
	stats[field] = int(stats[field]) + 1


func _count_edge(
	_a: Vector2i, _side: int, _b: Vector2i, stats: Dictionary, field: String,
) -> void:
	stats[field] = int(stats[field]) + 1
