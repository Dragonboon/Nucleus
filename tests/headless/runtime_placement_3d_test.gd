extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_profile_admission_constraints()
	_test_linear_chain_layout()
	_test_support_handshake()
	_test_solver_rejects_missing_context()
	_test_edit_cancel_preserves_scene()
	_test_curved_chain_layout()
	_test_curve_self_overlap()
	_test_group_edit_cancel()
	_test_snap_resolution()
	_test_snap_horizontal()
	_test_free_preview_tracking()
	return finish()


func _profile() -> NucleusPlacementProfile3D:
	var p := NucleusPlacementProfile3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.8)
	p.clearance_shape = shape
	return p


func _test_profile_admission_constraints() -> void:
	var p := NucleusPlacementProfile3D.new()
	expect_false(p.validate().is_empty(), "Placement requires a collision envelope.")
	p = _profile()
	expect_true(p.validate().is_empty(), "Explicit shape and support policy validate.")
	p.obstacle_mask = 0
	expect_false(p.validate().is_empty(), "Zero occupancy mask must fail closed.")
	p.obstacle_mask = 1
	p.snap_to_grid = true
	p.grid_step = Vector2.ZERO
	expect_false(p.validate().is_empty(), "Invalid grid steps are rejected.")
	p.grid_step = Vector2.ONE
	p.allow_chains = true
	p.chain_spacing = 0.25
	expect_false(p.validate().is_empty(), "Forward-overlapping chain footprints are rejected.")


func _test_linear_chain_layout() -> void:
	var points := NucleusPlacementChain3D.points(
		Vector3.ZERO, Vector3(0.0, 0.0, -5.2), 2.0, 4,
	)
	expect_equal(points.size(), 3, "Chain fits exactly three authored segments.")
	expect_equal(points[0], Vector3.ZERO, "Chain includes the anchor.")
	expect_equal(points[2], Vector3(0.0, 0.0, -4.0), "Spacing is deterministic.")
	expect_float(
		NucleusPlacementChain3D.heading(Vector3.ZERO, Vector3.FORWARD),
		0.0,
		"Forward-facing segments use zero yaw.",
	)
	expect_equal(
		NucleusPlacementChain3D.points(Vector3.ZERO, Vector3(0, 0, -30), 2, 3).size(),
		0,
		"Excessive chain length rejects rather than silently truncating.",
	)
	expect_equal(
		NucleusPlacementChain3D.points(Vector3.INF, Vector3.ZERO, 1, 5).size(),
		0,
		"Nonfinite endpoints are rejected.",
	)


func _test_support_handshake() -> void:
	var root := Node3D.new()
	var body := StaticBody3D.new()
	var support := NucleusPlaceable3D.new()
	var lower := _profile()
	lower.kind = &"foundation"
	support.profile = lower
	support.target = root
	root.add_child(body)
	root.add_child(support)
	var upper := _profile()
	upper.kind = &"shelf"
	upper.allow_unowned_ground = false
	upper.supported_by_kinds = [&"foundation"]
	expect_false(
		NucleusPlacementSolver3D._allowed_support(upper, body),
		"One-way stack permission cannot admit a placement.",
	)
	lower.accepts_on_top_kinds = [&"shelf"]
	expect_true(
		NucleusPlacementSolver3D._allowed_support(upper, body),
		"Stacking needs mutual, authored approval.",
	)
	upper.supported_by_kinds.clear()
	expect_false(
		NucleusPlacementSolver3D._allowed_support(upper, body),
		"Stacking remains forbidden when candidate permission is revoked.",
	)
	var dynamic_body := RigidBody3D.new()
	expect_false(
		NucleusPlacementSolver3D._allowed_support(_profile(), dynamic_body),
		"An unowned dynamic body must not be treated as stable terrain.",
	)
	dynamic_body.free()
	root.free()


func _test_solver_rejects_missing_context() -> void:
	var profile := _profile()
	var result := NucleusPlacementSolver3D.evaluate_hit(null, profile, {})
	expect_false(result["valid"], "Unavailable physics never produces accepted placement.")
	expect_equal(result["reason"], &"invalid_profile", "Failed evaluation is inspectable.")


func _test_edit_cancel_preserves_scene() -> void:
	var world := Node3D.new()
	var root := Node3D.new()
	var component := NucleusPlaceable3D.new()
	var collider := StaticBody3D.new()
	var session := NucleusPlacementSession3D.new()
	component.profile = _profile()
	component.target = root
	collider.collision_layer = 5
	root.add_child(component)
	root.add_child(collider)
	world.add_child(root)
	world.add_child(session)
	root.position = Vector3(2.0, 1.0, 4.0)
	expect_true(attach_test_node(world), "Runtime edit fixture requires a live scene.")
	var original := root.global_transform
	expect_equal(session.begin_edit(component), OK, "Edit accepts a configured scene-owned placeable.")
	expect_equal(collider.collision_layer, 0, "Preview excludes its own collision from the world.")
	root.global_position += Vector3(6, 0, 0)
	session.cancel()
	expect_equal(root.global_transform, original, "Cancel restores the exact authored transform.")
	expect_equal(collider.collision_layer, 5, "Cancel restores original collision layers.")
	expect_equal(session.mode, NucleusPlacementSession3D.Mode.IDLE, "Edit session returns to idle.")
	expect_true(is_instance_valid(root), "Editing cancel must never delete an existing asset.")
	free_test_node(world)


func _test_curved_chain_layout() -> void:
	var straight: Array[Dictionary] = NucleusPlacementChain3D.path_layout(
		[Vector3.ZERO, Vector3(0.0, 0.0, -5.0)], 2.0, 8,
	)
	expect_equal(straight.size(), 3, "Two controls produce three straight segments.")
	expect_equal(straight[2]["position"], Vector3(0.0, 0.0, -4.0),
		"Curve sampling retains exact straight spacing.")
	expect_float(float(straight[0]["yaw"]), 0.0,
		"Straight -Z path keeps forward-facing headings.")

	var bent: Array[Dictionary] = NucleusPlacementChain3D.path_layout(
		[Vector3(0, 0, 0), Vector3(0, 0, -5), Vector3(5, 0, -5)],
		1.0, 20, 16,
	)
	expect_true(bent.size() >= 9, "A bending path retains arc-length distance.")
	expect_true(bent[0]["position"] == Vector3.ZERO,
		"A curved path always starts at its first control point.")
	var curved: bool = false
	for i: int in range(1, bent.size()):
		var previous: Vector3 = bent[i - 1]["position"]
		var current: Vector3 = bent[i]["position"]
		var distance := Vector2(current.x - previous.x, current.z - previous.z).length()
		expect_true(absf(distance - 1.0) < 0.1,
			"Curve pieces follow near-constant arc-length spacing.")
		if absf(float(bent[i]["yaw"])) > 0.05:
			curved = true
	expect_true(curved, "Curve headings respond to bends.")
	expect_true(NucleusPlacementChain3D.path_layout(
		[Vector3.ZERO, Vector3(0.0, 0.0, -30.0)], 1.0, 10,
	).is_empty(), "Long curved routes reject their cap instead of truncating.")
	expect_true(NucleusPlacementChain3D.path_layout(
		[Vector3.INF, Vector3.ZERO], 1.0, 10,
	).is_empty(), "Nonfinite control points are rejected.")
	expect_true(NucleusPlacementChain3D.path_layout(
		[Vector3.ZERO, Vector3.ZERO], 1.0, 10,
	).is_empty(), "Duplicate-only paths are rejected.")


func _test_curve_self_overlap() -> void:
	var size := Vector3(0.4, 1.6, 1.8)
	var a := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var far := Transform3D(Basis.IDENTITY, Vector3(0, 0, -2))
	var overlap := Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.5))
	expect_false(NucleusPlacementChain3D.box_footprints_overlap(a, far, size),
		"Separated fence envelopes do not overlap.")
	expect_true(NucleusPlacementChain3D.box_footprints_overlap(a, overlap, size),
		"Overlapping fence envelopes block curved-chain confirmation.")


func _test_group_edit_cancel() -> void:
	var world := Node3D.new()
	var session := NucleusPlacementSession3D.new()
	world.add_child(session)
	var roots: Array[Node3D] = []
	var items: Array[NucleusPlaceable3D] = []
	var colliders: Array[StaticBody3D] = []
	for i: int in range(2):
		var root := Node3D.new()
		root.position = Vector3(float(i * 3), 1.0, 4.0)
		var component := NucleusPlaceable3D.new()
		component.profile = _profile()
		component.target = root
		var collider := StaticBody3D.new()
		collider.collision_layer = 2
		root.add_child(component)
		root.add_child(collider)
		world.add_child(root)
		roots.append(root)
		items.append(component)
		colliders.append(collider)
	expect_true(attach_test_node(world), "Group edit requires a live scene tree.")
	var before: Array[Transform3D] = []
	for root: Node3D in roots:
		before.append(root.global_transform)
	expect_equal(session.begin_edit_many(items), OK,
		"Configured multiple components share one edit session.")
	expect_equal(session.mode, NucleusPlacementSession3D.Mode.EDIT_GROUP,
		"Group edit mode is explicit.")
	expect_equal(session.set_snap_defaults(true, Vector2.ONE), OK,
		"Editing may enable session snap without restarting group selection.")
	var entries := session._layout_entries({"position": Vector3(1.3, 1.0, 4.8)})
	expect_equal(entries.size(), 2, "Snapped group retains both pieces.")
	var first_position: Vector3 = entries[0]["position"]
	var second_position: Vector3 = entries[1]["position"]
	expect_float(second_position.x - first_position.x, 3.0,
		"Group snapping preserves relative horizontal spacing.")
	expect_float(second_position.z - first_position.z, 0.0,
		"Group snapping does not destroy the original row layout.")
	for i: int in range(2):
		expect_equal(colliders[i].collision_layer, 0,
			"All group colliders are temporarily excluded from physics.")
		roots[i].global_position += Vector3(7, 2, 5)
	session.cancel()
	for i: int in range(2):
		expect_true(roots[i].global_transform.is_equal_approx(before[i]),
			"Cancel restores every group member's original transform.")
		expect_equal(colliders[i].collision_layer, 2,
			"Cancel restores every group member's collider layer.")
	expect_equal(session.mode, NucleusPlacementSession3D.Mode.IDLE,
		"Cancel leaves the editor idle.")
	free_test_node(world)


func _test_snap_resolution() -> void:
	var p := _profile()
	var inherited := p.resolve_snap(true, Vector2(0.5, 2.0), Vector2(0.25, -1.0))
	expect_true(inherited["enabled"], "Default session snap reaches inheriting assets.")
	expect_equal(inherited["step"], Vector2(0.5, 2.0), "Inherited steps match session.")
	expect_equal(inherited["origin"], Vector2(0.25, -1.0), "Origin is world anchored.")
	p.snap_mode = NucleusPlacementProfile3D.SnapMode.DISABLED
	expect_false(p.resolve_snap(true)["enabled"], "Asset can force snap off.")
	p.snap_mode = NucleusPlacementProfile3D.SnapMode.ENABLED
	p.grid_step = Vector2(0.5, 0.5)
	expect_true(p.resolve_snap(false)["enabled"], "Asset can force snap on.")
	expect_equal(p.resolve_snap(false)["step"], Vector2(0.5, 0.5),
		"Explicit asset grid has precedence over session.")
	p.snap_mode = NucleusPlacementProfile3D.SnapMode.INHERIT
	p.snap_to_grid = true
	expect_true(p.resolve_snap(false)["enabled"], "Legacy snap_to_grid stays effective.")
	p.snap_to_grid = false
	p.use_custom_snap_grid = true
	expect_false(p.resolve_snap(false)["enabled"],
		"Custom grid alone does not force the default session mode on.")
	expect_equal(p.resolve_snap(true, Vector2(3.0, 3.0))["step"],
		Vector2(0.5, 0.5), "Inheriting asset may customize the active grid.")
	var session := NucleusPlacementSession3D.new()
	expect_equal(session.set_snap_defaults(true, Vector2(0.5, 1.0)), OK,
		"Live session accepts positive, finite grid steps.")
	expect_true(session.get_snap_settings(p)["enabled"],
		"Session resolves the authored asset without replacing the profile.")
	p.snap_mode = NucleusPlacementProfile3D.SnapMode.ENABLED
	p.grid_step = Vector2.ONE
	expect_equal(session.set_snap_defaults(
		false, Vector2.ONE, Vector2.ZERO, true,
	), OK, "Free override can be enabled with one atomic revalidation.")
	expect_false(session.get_snap_settings(p)["enabled"],
		"Explicit free mode overrides an asset that forces snap on.")
	expect_equal(session.get_snap_settings(p)["source"], &"free_override",
		"Free policy is inspectable for the UI.")
	p.snap_mode = NucleusPlacementProfile3D.SnapMode.INHERIT
	p.snap_to_grid = true
	expect_false(session.get_snap_settings(p)["enabled"],
		"Explicit free mode also overrides legacy snap_to_grid resources.")
	p.snap_to_grid = false
	expect_equal(session.set_snap_defaults(
		true, Vector2(0.5, 0.5), Vector2.ZERO, false,
	), OK, "Re-enabling snap restores asset and session policy.")
	expect_true(session.get_snap_settings(p)["enabled"],
		"Session snapping resumes after leaving free mode.")
	expect_true(session._continuous_free_preview() == false,
		"Idle sessions do not poll physics for continuous previews.")
	expect_equal(session.set_snap_defaults(true, Vector2.ZERO), ERR_INVALID_PARAMETER,
		"Session refuses a zero grid step.")
	expect_equal(session.set_snap_defaults(
		true, Vector2.ONE, Vector2.ZERO, "not_bool",
	), ERR_INVALID_PARAMETER, "Free override accepts bool or omitted only.")
	expect_true(session.snap_enabled_by_default,
		"Invalid configuration cannot mutate the active default.")
	session.free()


func _test_snap_horizontal() -> void:
	var point := Vector3(-2.27, 4.25, 3.61)
	var result := NucleusPlacementSolver3D.snap_horizontal(
		point, Vector2(0.5, 2.0), Vector2(0.25, -1.0),
	)
	expect_float(result.x, -2.25, "Snap supports negative world coordinates.")
	expect_float(result.z, 3.0, "Snap uses an authored offset origin.")
	expect_float(result.y, point.y, "Snap never quantizes terrain/stack height.")
	expect_equal(NucleusPlacementSolver3D.snap_horizontal(
		point, Vector2.ZERO, Vector2.ZERO,
	), point, "Invalid grid cannot produce a misleading snapped position.")
	expect_true(NucleusPlacementSolver3D.valid_grid(Vector2.ONE, Vector2.ZERO),
		"A finite, positive grid is usable.")
	expect_false(NucleusPlacementSolver3D.valid_grid(Vector2(INF, 1), Vector2.ZERO),
		"Nonfinite steps must be rejected.")


func _test_free_preview_tracking() -> void:
	var session := NucleusPlacementSession3D.new()
	var item := NucleusPlaceable3D.new()
	item.profile = _profile()
	session._placeables.append(item)
	session.mode = NucleusPlacementSession3D.Mode.SINGLE
	session.force_free_placement = true
	expect_true(session._continuous_free_preview(),
		"A single free placeable is eligible for per-physics-tick updates.")
	var origin := {"position": Vector3(0.35, 0.0, 0.0)}
	var moved := {"position": Vector3(0.355, 0.0, 0.0)}
	expect_true(session._hit_changed(moved, origin, 0.001),
		"Free cursor movement is not rounded to a 4 cm threshold.")
	expect_false(session._hit_changed(moved, origin, 0.01),
		"Larger configured tolerances still suppress minor jitter.")
	session.force_free_placement = false
	item.profile.snap_mode = NucleusPlacementProfile3D.SnapMode.ENABLED
	expect_false(session._continuous_free_preview(),
		"Snapped previews retain the bounded scheduling policy.")
	session.force_free_placement = true
	session.mode = NucleusPlacementSession3D.Mode.CHAIN
	expect_false(session._continuous_free_preview(),
		"Long free chains do not bypass the incremental physics budget.")
	session.mode = NucleusPlacementSession3D.Mode.IDLE
	session._placeables.clear()
	item.free()
	session.free()
