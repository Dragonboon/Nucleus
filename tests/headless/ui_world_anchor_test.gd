extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_solver_priority_and_padding()
	_test_solver_limits_and_bounds()
	_test_projection_and_visibility()
	_test_layout_budget_and_collision()
	return finish()


func _test_solver_priority_and_padding() -> void:
	var entries: Array[Dictionary] = [
		{"position": Vector2(40.0, 50.0), "size": Vector2(80.0, 20.0)},
		{"position": Vector2(40.0, 50.0), "size": Vector2(80.0, 20.0)},
	]
	var result: Array[Dictionary] = NucleusUIWorldAnchorLayoutSolver.solve(
		entries, Rect2(0.0, 0.0, 200.0, 100.0), 4.0, 48.0, 4.0
	)
	var first_position: Vector2 = result[0]["position"]
	var second_position: Vector2 = result[1]["position"]

	expect_true(bool(result[0]["visible"]), "First label retains priority.")
	expect_true(bool(result[1]["visible"]), "Second label can move upwards.")
	expect_equal(first_position, Vector2(40.0, 50.0), "First label is not displaced.")
	expect_true(
		second_position.y <= 26.0,
		"Second label moves by its height plus collision padding.",
	)
	expect_false(
		Rect2(first_position, Vector2(80.0, 20.0)).grow(2.0).intersects(
			Rect2(second_position, Vector2(80.0, 20.0)).grow(2.0)
		),
		"Resolved HUD label rectangles have no overlap.",
	)


func _test_solver_limits_and_bounds() -> void:
	var entries: Array[Dictionary] = [
		{"position": Vector2(90.0, 90.0), "size": Vector2(20.0, 20.0)},
		{"position": Vector2(90.0, 90.0), "size": Vector2(20.0, 20.0)},
		{"position": Vector2(0.0, 0.0), "size": Vector2(200.0, 10.0)},
	]
	var result: Array[Dictionary] = NucleusUIWorldAnchorLayoutSolver.solve(
		entries, Rect2(0.0, 0.0, 100.0, 100.0), 4.0, 0.0, 8.0
	)
	var first_position: Vector2 = result[0]["position"]

	expect_equal(first_position, Vector2(80.0, 80.0), "Labels clamp to HUD bounds.")
	expect_true(bool(result[0]["visible"]), "Clamped label is admissible.")
	expect_false(bool(result[1]["visible"]), "Unresolvable collision is hidden.")
	expect_false(bool(result[2]["visible"]), "Oversized labels are hidden.")
	expect_equal(result.size(), entries.size(), "Solver returns one result per item.")


func _test_projection_and_visibility() -> void:
	var root := Node.new()
	var camera := Camera3D.new()
	var target := Node3D.new()
	var overlay := Control.new()
	var label := Label.new()
	var anchor := NucleusUIWorldAnchor3D.new()

	root.add_child(camera)
	root.add_child(target)
	root.add_child(overlay)
	overlay.add_child(label)
	root.add_child(anchor)
	overlay.size = Vector2(1600.0, 900.0)
	label.size = Vector2(100.0, 20.0)
	target.position = Vector3(0.0, 0.0, -5.0)
	anchor.camera = camera
	anchor.world_target = target
	anchor.overlay = overlay
	anchor.visual = label
	anchor.update_automatically = false

	expect_true(attach_test_node(root), "3D projection fixture needs a SceneTree.")
	expect_true(anchor.refresh_projection(), "Object ahead of the camera projects.")
	expect_true(anchor.has_projection(), "Successful projection is observable.")
	expect_true(label.visible, "Projected label becomes visible.")

	var expected_center: Vector2 = camera.unproject_position(target.global_position)
	# A Theme may increase Label minimum size when it enters the tree.
	var expected_position: Vector2 = expected_center - label.size * Vector2(0.5, 1.0)
	expect_true(
		label.position.is_equal_approx(expected_position),
		"HUD placement uses the viewport projection and label alignment.",
	)

	overlay.position = Vector2(40.0, 20.0)
	expect_true(anchor.refresh_projection(), "Shifted UI overlay can be projected into.")
	expect_true(
		label.position.is_equal_approx(expected_position - overlay.position),
		"Projection respects the overlay CanvasItem transform.",
	)
	overlay.position = Vector2.ZERO
	anchor.refresh_projection()

	target.position = Vector3(0.0, 0.0, 5.0)
	expect_false(anchor.refresh_projection(), "Camera-backward targets are rejected.")
	expect_false(label.visible, "Hidden-behind-camera targets hide their labels.")

	target.position = Vector3(5000.0, 0.0, -5.0)
	expect_false(anchor.refresh_projection(), "Outside-viewport targets are rejected.")

	target.position = Vector3(0.0, 0.0, -5.0)
	anchor.maximum_distance = 4.0
	expect_false(anchor.refresh_projection(), "Max-distance cutoff hides distant labels.")
	anchor.maximum_distance = 0.0
	expect_true(anchor.refresh_projection(), "Disabling distance cutoff restores projection.")

	anchor.apply_layout(Vector2(10.0, 25.0), true)
	expect_equal(label.position, Vector2(10.0, 25.0), "Layout owns the final position.")
	anchor.reset_layout()
	expect_true(
		label.position.is_equal_approx(expected_position),
		"Reset returns the label to its independent projection.",
	)

	free_test_node(root)


func _test_layout_budget_and_collision() -> void:
	var root := Node.new()
	var camera := Camera3D.new()
	var target := Node3D.new()
	var overlay := Control.new()
	var layout := NucleusUIWorldAnchorLayout.new()
	var first := NucleusUIWorldAnchor3D.new()
	var second := NucleusUIWorldAnchor3D.new()
	var first_visual := Label.new()
	var second_visual := Label.new()

	root.add_child(camera)
	root.add_child(target)
	root.add_child(overlay)
	overlay.add_child(first_visual)
	overlay.add_child(second_visual)
	root.add_child(first)
	root.add_child(second)
	root.add_child(layout)
	target.position = Vector3(0.0, 0.0, -5.0)
	overlay.size = Vector2(1800.0, 1000.0)
	first_visual.size = Vector2(100.0, 20.0)
	second_visual.size = Vector2(100.0, 20.0)

	for anchor: NucleusUIWorldAnchor3D in [first, second]:
		anchor.camera = camera
		anchor.world_target = target
		anchor.overlay = overlay
		anchor.update_automatically = false
	first.visual = first_visual
	second.visual = second_visual
	layout.overlay = overlay
	layout.anchors.append(first)
	layout.anchors.append(second)
	layout.update_interval = 1.0

	expect_true(attach_test_node(root), "Anchor layout fixture needs a SceneTree.")
	expect_equal(layout.refresh_layout(), 2, "Two labels fit with vertical separation.")
	expect_true(first_visual.visible, "Higher-priority label stays visible.")
	expect_true(second_visual.visible, "Lower-priority label finds a free space.")
	expect_true(
		second_visual.position.y < first_visual.position.y,
		"Later overlapping label is lifted rather than stacked on top.",
	)

	layout.maximum_projection_checks = 1
	expect_equal(layout.refresh_layout(), 1, "Projection work respects admission budget.")
	expect_false(second_visual.visible, "Beyond-budget labels never remain stale.")

	layout.maximum_projection_checks = 2
	layout.maximum_visible_labels = 1
	expect_equal(layout.refresh_layout(), 1, "Visible-label budget is enforced.")
	expect_false(second_visual.visible, "Over-budget labels remain hidden.")

	layout.maximum_visible_labels = 2
	overlay.size = Vector2.ZERO
	expect_equal(layout.refresh_layout(), 0, "Empty HUD bounds hide all labels.")
	expect_false(first_visual.visible, "Invalid overlay hides the first label.")
	expect_false(second_visual.visible, "Invalid overlay hides the second label.")

	free_test_node(root)
