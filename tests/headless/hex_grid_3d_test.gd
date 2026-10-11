extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_hex_layout()
	_test_exact_corner_identity()
	_test_board_lifecycle()
	return finish()


func _test_hex_layout() -> void:
	expect_equal(NucleusHexLayout3D.cells_in_radius(0).size(), 1, "Zero-ring grid contains one cell.")
	expect_equal(NucleusHexLayout3D.cells_in_radius(3).size(), 37, "Three-ring grid has 37 cells.")
	expect_equal(NucleusHexLayout3D.cells_in_radius(25).size(), 0, "Oversized grids fail closed.")
	expect_equal(
		NucleusHexLayout3D.distance(Vector2i.ZERO, Vector2i(2, -3)), 3,
		"Cube distance is measured in cell steps.",
	)
	expect_equal(
		NucleusHexLayout3D.stroke_cells(Vector2i.ZERO, Vector2i(3, 0)).size(), 4,
		"Fast brush movement fills every intervening axial cell.",
	)
	expect_true(
		NucleusHexLayout3D.stroke_cells(Vector2i.ZERO, Vector2i(65, 0)).is_empty(),
		"Excessively long brush strokes are rejected as a bounded operation.",
	)
	for cell: Vector2i in [
		Vector2i.ZERO, Vector2i(2, -3), Vector2i(-3, 4), Vector2i(4, 1),
	]:
		var point := NucleusHexLayout3D.axial_to_local(cell, 1.5)
		expect_equal(
			NucleusHexLayout3D.local_to_axial(point, 1.5), cell,
			"Every axial center round-trips to its original coordinate.",
		)
	var jitter := NucleusHexLayout3D.axial_to_local(Vector2i(-2, 1), 2.0)
	jitter += Vector3(0.05, 0.0, -0.07)
	expect_equal(
		NucleusHexLayout3D.local_to_axial(jitter, 2.0), Vector2i(-2, 1),
		"Sub-cell cursor noise should keep the same axial cell.",
	)


func _test_exact_corner_identity() -> void:
	var origin := Vector3i(0, 0, 0)
	var neighbor := Vector3i(1, 0, 0)
	var different_layer := Vector3i(1, 0, 1)
	var shared: int = 0
	var cross_layer: int = 0
	for a: int in range(6):
		for b: int in range(6):
			if NucleusHexLayout3D.corner_key(origin, a) == NucleusHexLayout3D.corner_key(neighbor, b):
				shared += 1
			if NucleusHexLayout3D.corner_key(origin, a) == NucleusHexLayout3D.corner_key(different_layer, b):
				cross_layer += 1
	expect_equal(shared, 2, "Adjacent hexes share exactly two corners.")
	expect_equal(cross_layer, 0, "Corners on separate elevation layers must not connect.")


func _test_board_lifecycle() -> void:
	var scene_root := Node3D.new()
	expect_true(attach_test_node(scene_root), "Hex board needs the SceneTree.")
	var board := NucleusHexBoard3D.new()
	scene_root.add_child(board)
	var stats := {"connected": 0, "disconnected": 0}
	board.corner_connected.connect(_record_connected.bind(stats))
	board.corner_disconnected.connect(_record_disconnected.bind(stats))
	var a := Vector3i(0, 0, 0)
	var b := Vector3i(1, 0, 0)
	expect_true(board.paint_cell(a), "First painted tile should be accepted.")
	expect_true(board.paint_cell(b), "Adjacent painted tile should be accepted.")
	expect_false(board.paint_cell(b), "Duplicate cell placement must fail.")
	expect_equal(stats["connected"], 2, "Adjacent tiles emit two corner-connected events.")
	expect_equal(board.shared_corner_count(), 2, "Live corner index counts the shared vertices.")
	expect_true(board.rotate_tile(a, 1), "Tiles should rotate by 60 degrees.")
	expect_equal(board.get_rotation_steps(a), 1, "Rotation step persists on the tile.")
	board.position = Vector3(8.0, 3.0, -4.0)
	board.rotation.y = PI / 3.0
	var mapped := Vector3i(-2, 1, 0)
	expect_equal(
		board.world_to_cell(board.cell_to_world(mapped), 0), mapped,
		"World round-trip must work with translated/rotated board.",
	)
	board.set_cell_radius(2.75)
	board.set_tile_height(0.8)
	board.set_layer_step(2.0)
	expect_equal(
		board.world_to_cell(board.cell_to_world(mapped), 0), mapped,
		"Dimension changes must preserve cell addresses.",
	)
	expect_true(board.erase_cell(b), "Removing neighbor must succeed.")
	expect_equal(stats["disconnected"], 2, "Neighbor removal emits matching disconnects.")
	expect_equal(board.shared_corner_count(), 0, "Disconnected tiles leave no stale links.")
	var destination := Vector3i(0, 1, 0)
	expect_true(board.move_tile(a, destination), "A tile can move into a vacant cell.")
	expect_false(board.move_tile(a, b), "A consumed move source must be rejected.")
	expect_equal(board.get_rotation_steps(destination), 1, "Move must preserve the tile orientation.")
	expect_true(board.paint_cell(Vector3i(0, 1, 1)), "Another layer allows independent occupancy.")
	expect_equal(board.shared_corner_count(), 0, "Different layers do not connect.")
	board.set_ring_count(1)
	expect_false(board.paint_cell(Vector3i(2, 0, 0)), "Grid ring bound rejects distant placement.")
	board.clear_tiles()
	expect_equal(board.tile_count(), 0, "Clearing the board removes every tile.")
	free_test_node(scene_root)


func _record_connected(
	_cell: Vector3i, _corner: int, _other: Vector3i, _other_corner: int,
	_point: Vector3, stats: Dictionary,
) -> void:
	stats["connected"] = int(stats["connected"]) + 1


func _record_disconnected(
	_cell: Vector3i, _corner: int, _other: Vector3i, _other_corner: int,
	_point: Vector3, stats: Dictionary,
) -> void:
	stats["disconnected"] = int(stats["disconnected"]) + 1
