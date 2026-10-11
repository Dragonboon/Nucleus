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
	_test_duplicate_preview_cancel()
	_test_large_group_selection()
	_test_incremental_clearance()
	_test_curve_tension_and_spacing()
	_test_visual_origin_bounds()
	_test_brush_stroke_sampling()
	_test_continuous_rotation()
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


func _test_duplicate_preview_cancel() -> void:
	var world := Node3D.new()
	var session := NucleusPlacementSession3D.new()
	world.add_child(session)
	var original := Node3D.new()
	var original_component := NucleusPlaceable3D.new()
	original_component.profile = _profile()
	original_component.target = original
	original.add_child(original_component)
	world.add_child(original)
	expect_true(attach_test_node(world), "Duplicate fixture has one world tree.")
	var detached := Node3D.new()
	var copy_component := NucleusPlaceable3D.new()
	copy_component.profile = _profile()
	copy_component.target = detached
	detached.add_child(copy_component)
	var pieces: Array[Node3D] = [detached]
	expect_equal(session.begin_duplicate(pieces), OK,
		"A detached staged copy becomes a movable placement preview.")
	expect_equal(session.mode, NucleusPlacementSession3D.Mode.DUPLICATE,
		"Duplication is a preview mode, not an immediate world commit.")
	expect_true(detached.get_parent() == world,
		"The scene-owned session attaches the preview under the authored world.")
	session.cancel()
	expect_false(is_instance_valid(detached),
		"Cancelling a copied preview frees the copy, not the source.")
	expect_true(is_instance_valid(original),
		"Originals survive cancelled copy placement.")
	free_test_node(world)


func _test_large_group_selection() -> void:
	var world := Node3D.new()
	var session := NucleusPlacementSession3D.new()
	session.max_group_count = 48
	world.add_child(session)
	var items: Array[NucleusPlaceable3D] = []
	var roots: Array[Node3D] = []
	for index: int in range(36):
		var root := Node3D.new()
		root.position = Vector3(float(index) * 6.0, 1.0, 0.0)
		var component := NucleusPlaceable3D.new()
		component.profile = _profile()
		component.target = root
		root.add_child(component)
		world.add_child(root)
		items.append(component)
		roots.append(root)
	expect_true(attach_test_node(world), "Large group fixture needs a live tree.")
	expect_equal(session.begin_edit_many(items), OK,
		"Group editing accepts more than the old 32-piece limit.")
	expect_equal(session.mode, NucleusPlacementSession3D.Mode.EDIT_GROUP,
		"Large selection is one bounded edit operation.")
	session.cancel()
	for root: Node3D in roots:
		expect_true(is_instance_valid(root), "Cancel never removes selected authored objects.")
	free_test_node(world)


func _test_incremental_clearance() -> void:
	var session := NucleusPlacementSession3D.new()
	var p := _profile()
	var items: Array[NucleusPlaceable3D] = []
	for i: int in range(4):
		var item := NucleusPlaceable3D.new()
		item.profile = p
		items.append(item)
		session._placeables.append(item)
		session._pending_transforms.append(Transform3D(
			Basis.IDENTITY, Vector3(float(i) * 3.0, 0.0, 0.0),
		))
	session.mode = NucleusPlacementSession3D.Mode.PATH
	expect_equal(session._pump_pair_clearance(2), &"checking",
		"A limited pair budget defers the rest to another tick.")
	var result := &"checking"
	for _i: int in range(16):
		if result != &"checking":
			break
		result = session._pump_pair_clearance(2)
	expect_equal(result, &"", "Incremental nonoverlap checks eventually complete.")
	session._pair_i = 0
	session._pair_j = 1
	session._pending_transforms[1] = Transform3D(Basis.IDENTITY, Vector3(0.1, 0.0, 0.0))
	expect_equal(session._pump_pair_clearance(10), &"chain_self_overlap",
		"Overlapping sections reject the entire pending chain.")
	session._placeables.clear()
	session.free()
	for item: NucleusPlaceable3D in items:
		item.free()


func _test_curve_tension_and_spacing() -> void:
	var route: Array[Vector3] = [
		Vector3(0, 0, 0), Vector3(0, 0, -3),
		Vector3(1, 0, -3.5), Vector3(8, 0, -4),
	]
	var smooth := NucleusPlacementChain3D.path_layout(route, 0.7, 30, 12, 1.0)
	var straight := NucleusPlacementChain3D.path_layout(route, 0.7, 30, 12, 0.0)
	expect_true(smooth.size() > 5 and straight.size() > 5,
		"Smooth and polygonal layouts both produce usable sections.")
	expect_true(smooth.size() <= 30, "Author maximum still applies to smooth curves.")
	var saw_difference := false
	for i: int in range(mini(smooth.size(), straight.size())):
		var point: Vector3 = smooth[i]["position"]
		var linear: Vector3 = straight[i]["position"]
		if point.distance_squared_to(linear) > 0.0005:
			saw_difference = true
		var forward := Basis(Vector3.UP, smooth[i]["yaw"]) * Vector3.FORWARD
		expect_true(is_finite(forward.x) and is_finite(forward.z),
			"Smooth path keeps a usable tangent heading.")
	expect_true(saw_difference, "Per-asset tension visibly changes curved distribution.")
	expect_true(NucleusPlacementChain3D.path_layout(route, 1.0, 30, 12, -0.2).is_empty(),
		"Invalid authored tension rejects instead of guessing geometry.")


func _test_visual_origin_bounds() -> void:
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = Vector3(2, 2, 2)
	box.mesh = visual
	box.position = Vector3(0.25, -0.5, 0.0)
	root.add_child(box)
	var other := MeshInstance3D.new()
	var cap := BoxMesh.new()
	cap.size = Vector3(0.5, 0.5, 0.5)
	other.mesh = cap
	other.position = Vector3(0, 1.25, 0)
	root.add_child(other)
	var result: Dictionary = NucleusPlacementGeometry3D.get_visual_bounds(root)
	expect_true(bool(result.get("valid", false)), "A compound mesh exposes visual bounds.")
	var bounds: AABB = result["bounds"]
	expect_float(bounds.position.y, -1.5, "Child offsets determine the lowest visual point.")
	expect_float(bounds.end.y, 1.5, "Child mesh bounds are merged.")
	var correction: Vector3 = NucleusPlacementGeometry3D.bottom_correction(
		bounds, Basis.IDENTITY, Vector3.UP,
	)
	expect_float(correction.y, 1.5, "Central pivot is moved above ground to touch it.")
	var yaw: Basis = Basis(Vector3.UP, PI * 0.5)
	var rotated: Vector3 = NucleusPlacementGeometry3D.bottom_correction(
		bounds, yaw, Vector3.UP,
	)
	expect_float(rotated.y, 1.5, "Yaw does not change bottom contact height.")
	var no_mesh := Node3D.new()
	expect_false(bool(NucleusPlacementGeometry3D.get_visual_bounds(no_mesh)["valid"]),
		"Absent visual geometry must not invent an offset.")
	var profile := _profile()
	expect_equal(profile.origin_mode, NucleusPlacementProfile3D.OriginMode.AUTHORED_ORIGIN,
		"Existing assets retain their authored pivot by default.")
	profile.origin_mode = NucleusPlacementProfile3D.OriginMode.VISUAL_BOTTOM
	expect_true(profile.validate().is_empty(), "Visual bottom is an opt-in valid profile.")
	root.free()
	no_mesh.free()


func _test_brush_stroke_sampling() -> void:
	var sampler := NucleusPlacementBrush3D.new()
	expect_equal(sampler.begin(1.0, 0.0, 5, 17), OK,
		"Brush accepts a bounded profile.")
	var first: Array[Vector3] = sampler.add_cursor(Vector3.ZERO)
	expect_equal(first.size(), 1, "A stroke stamps its first point exactly once.")
	expect_equal(first[0], Vector3.ZERO, "Zero-radius brush keeps the cursor position.")
	var sample: Array[Vector3] = sampler.add_cursor(Vector3(2.5, 0, 0))
	expect_equal(sample.size(), 2, "Sparse input generates evenly spaced stamps.")
	expect_float(sample[0].x, 1.0, "First interpolated stamp is one metre along.")
	expect_float(sample[1].x, 2.0, "Second interpolated stamp is two metres along.")
	expect_true(sampler.add_cursor(Vector3(2.5, 0, 0)).is_empty(),
		"Stationary cursor never paints duplicates.")
	var tail: Array[Vector3] = sampler.add_cursor(Vector3(200, 0, 0))
	expect_equal(tail.size(), 2, "The limit caps a long input jump.")
	expect_equal(sampler.get_count(), 5, "No stroke may exceed authored maximum.")
	expect_true(sampler.is_full(), "Limit exhaustion is observable to the consumer.")
	expect_true(sampler.add_cursor(Vector3(300, 0, 0)).is_empty(),
		"A full stroke rejects further candidates.")
	sampler.end()
	expect_true(sampler.add_cursor(Vector3.ZERO).is_empty(),
		"Ended strokes do not mutate the world.")
	expect_equal(sampler.begin(0.0), ERR_INVALID_PARAMETER,
		"Zero spacing is rejected.")
	var a := NucleusPlacementBrush3D.new()
	var b := NucleusPlacementBrush3D.new()
	a.begin(1.0, 2.0, 8, 123)
	b.begin(1.0, 2.0, 8, 123)
	expect_equal(a.add_cursor(Vector3.ZERO), b.add_cursor(Vector3.ZERO),
		"A fixed seed reproduces radial jitter.")
	expect_equal(a.add_cursor(Vector3(3, 0, 0)), b.add_cursor(Vector3(3, 0, 0)),
		"A stroke seed reproduces later stamps too.")

## Rotation speed is authored per asset, independent of step increments.
func _test_continuous_rotation() -> void:
	var world := Node3D.new()
	var session := NucleusPlacementSession3D.new()
	world.add_child(session)
	var placeable := NucleusPlaceable3D.new()
	placeable.profile = _profile()
	placeable.profile.rotation_speed_degrees_per_second = 90.0
	world.add_child(placeable)
	session._placeables.append(placeable)
	session.mode = NucleusPlacementSession3D.Mode.SINGLE
	expect_equal(session.rotate_held(0.0, 0.25), OK,
		"Zero input is valid and makes no rotation.")
	expect_equal(session.rotate_held(1.0, -0.1), ERR_INVALID_PARAMETER,
		"Negative elapsed time is rejected.")
	expect_equal(session.rotate_held(1.0, 0.1), OK,
		"Held rotation uses the profile velocity.")
	expect_float(session._yaw, deg_to_rad(9.0),
		"100 milliseconds at 90 degrees/s rotates nine degrees.")
	expect_equal(session.rotate_held(-1.0, 0.1), OK,
		"Held reverse rotation is symmetrical.")
	expect_float(session._yaw, 0.0, "Opposing input returns to initial heading.")
	placeable.profile.can_rotate = false
	expect_equal(session.rotate_held(1.0, 0.1), ERR_UNAVAILABLE,
		"Continuous rotation respects can_rotate.")
	world.free()
