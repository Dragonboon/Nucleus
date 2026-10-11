extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_sequence_tracker()
	_test_rate_limiter()
	_test_snapshot_buffer_2d()
	_test_snapshot_buffer_3d()
	_test_invalid_snapshots()
	_test_teleport_sequence_2d()
	_test_teleport_sequence_3d()
	return finish()


func _test_invalid_snapshots() -> void:
	var planar := NucleusTransformSnapshotBuffer2D.new()
	var spatial := NucleusTransformSnapshotBuffer3D.new()
	expect_false(planar.push(1, NAN, Vector2.ZERO, 0.0), "2D rejects NaN arrival time.")
	expect_false(spatial.push(1, INF, Vector3.ZERO, Quaternion()), "3D rejects infinite time.")
	planar.clear()
	spatial.clear()
	expect_false(planar.push(1, 0.0, Vector2.INF, 0.0), "2D rejects non-finite positions.")
	expect_false(spatial.push(1, 0.0, Vector3.INF, Quaternion()), "3D rejects invalid positions.")
	planar.clear()
	spatial.clear()
	expect_false(planar.push(1, 0.0, Vector2.ZERO, NAN), "2D rejects non-finite rotation.")
	expect_false(
		spatial.push(1, 0.0, Vector3.ZERO, Quaternion(0.0, 0.0, 0.0, 0.0)),
		"3D rejects zero-length rotations before quaternion interpolation.",
	)
	expect_equal(planar.get_latest_sequence(), 0, "Invalid 2D state does not consume sequence.")
	expect_equal(spatial.get_latest_sequence(), 0, "Invalid 3D state does not consume sequence.")
	expect_true(planar.push(1, 1.0, Vector2.ZERO, 0.0), "Valid 2D retry is accepted.")
	expect_true(spatial.push(1, 1.0, Vector3.ZERO, Quaternion()), "Valid 3D retry is accepted.")
	expect_false(planar.push(2, 0.5, Vector2.ONE, 0.0), "2D rejects decreasing arrival time.")
	expect_false(spatial.push(2, 0.5, Vector3.ONE, Quaternion()), "3D rejects decreasing time.")
	expect_true(planar.sample(NAN).is_empty(), "Invalid sample time returns no 2D state.")
	expect_true(spatial.sample(INF).is_empty(), "Invalid sample time returns no 3D state.")
	expect_equal(planar.get_count(), 1, "Invalid 2D samples leave history intact.")
	expect_equal(spatial.get_count(), 1, "Invalid 3D samples leave history intact.")
	expect_true(planar.push(2, 1.0, Vector2.ONE, 0.0), "Equal arrival times remain valid.")
	expect_true(spatial.push(2, 1.0, Vector3.ONE, Quaternion()), "3D allows equal times.")


func _test_teleport_sequence_2d() -> void:
	var target := Node2D.new()
	var replicator := NucleusNetworkTransformReplicator2D.new()
	replicator.teleport_distance = 8.0
	target.add_child(replicator)
	replicator.target = target
	replicator.set_multiplayer_authority(2)
	expect_true(attach_test_node(target), "2D remote fixture needs a SceneTree.")
	replicator._receive_snapshot(10, Vector2(20.0, 0.0), 0.0)
	expect_equal(target.position.x, 20.0, "New 2D teleport is applied immediately.")
	replicator._receive_snapshot(9, Vector2(100.0, 0.0), 0.0)
	expect_equal(target.position.x, 20.0, "Old 2D teleport cannot roll state back.")
	expect_equal(replicator._buffer.get_latest_sequence(), 10, "2D teleport preserves admission.")
	replicator._receive_snapshot(11, Vector2.INF, 0.0)
	expect_true(target.position.is_finite(), "Invalid 2D teleport never reaches the transform.")
	replicator._receive_snapshot(11, Vector2(40.0, 0.0), 0.0)
	expect_equal(target.position.x, 40.0, "Valid retry after rejection still teleports.")
	free_test_node(target)


func _test_teleport_sequence_3d() -> void:
	var target := Node3D.new()
	var replicator := NucleusNetworkTransformReplicator3D.new()
	target.add_child(replicator)
	replicator.target = target
	replicator.set_multiplayer_authority(2)
	expect_true(attach_test_node(target), "3D remote fixture needs a SceneTree.")
	replicator._receive_snapshot(10, Vector3(20.0, 0.0, 0.0), Quaternion())
	expect_equal(target.position.x, 20.0, "New 3D teleport is applied immediately.")
	replicator._receive_snapshot(9, Vector3(100.0, 0.0, 0.0), Quaternion())
	expect_equal(target.position.x, 20.0, "Old 3D teleport cannot roll state back.")
	expect_equal(replicator._buffer.get_latest_sequence(), 10, "3D teleport preserves admission.")
	replicator._receive_snapshot(11, Vector3.INF, Quaternion())
	expect_true(target.position.is_finite(), "Invalid 3D teleport never reaches the transform.")
	replicator._receive_snapshot(11, Vector3(40.0, 0.0, 0.0), Quaternion())
	expect_equal(target.position.x, 40.0, "Valid 3D retry after rejection still teleports.")
	free_test_node(target)


func _test_sequence_tracker() -> void:
	var tracker := NucleusNetworkSequenceTracker.new()

	expect_true(
		tracker.accept(
			7,
			&"movement",
			1,
		),
		"First positive sequence should be accepted.",
	)
	expect_false(
		tracker.accept(
			7,
			&"movement",
			1,
		),
		"Duplicate sequence should be rejected.",
	)
	expect_false(
		tracker.accept(
			7,
			&"movement",
			0,
		),
		"Older sequence should be rejected.",
	)
	expect_true(
		tracker.accept(
			7,
			&"movement",
			2,
		),
		"Newer sequence should be accepted.",
	)
	expect_true(
		tracker.accept(
			7,
			&"actions",
			1,
		),
		"Independent streams should maintain independent sequences.",
	)


func _test_rate_limiter() -> void:
	var limiter := NucleusNetworkRateLimiter.new()

	expect_true(
		limiter.allow(
			4,
			1000,
			2,
		),
		"First event in a rate window should pass.",
	)
	expect_true(
		limiter.allow(
			4,
			1100,
			2,
		),
		"Events up to the configured limit should pass.",
	)
	expect_false(
		limiter.allow(
			4,
			1200,
			2,
		),
		"Events beyond the configured limit should be rejected.",
	)
	expect_true(
		limiter.allow(
			4,
			2000,
			2,
		),
		"A new time window should reset admission.",
	)


func _test_snapshot_buffer_2d() -> void:
	var buffer := NucleusTransformSnapshotBuffer2D.new()

	expect_true(
		buffer.push(
			1,
			0.0,
			Vector2.ZERO,
			0.0,
		),
		"First 2D transform snapshot should be accepted.",
	)
	expect_true(
		buffer.push(
			2,
			1.0,
			Vector2(10.0, 0.0),
			1.0,
		),
		"Newer 2D transform snapshot should be accepted.",
	)
	expect_false(
		buffer.push(
			2,
			2.0,
			Vector2(20.0, 0.0),
			2.0,
		),
		"Duplicate 2D snapshot sequence should be rejected.",
	)

	var state: Dictionary = buffer.sample(0.5)
	var position: Vector2 = state["position"]

	expect_true(
		position.is_equal_approx(
			Vector2(5.0, 0.0)
		),
		"2D snapshot buffer should interpolate position.",
	)
	expect_float(
		float(state["rotation"]),
		0.5,
		"2D snapshot buffer should interpolate rotation.",
	)


func _test_snapshot_buffer_3d() -> void:
	var buffer := NucleusTransformSnapshotBuffer3D.new()
	var target_rotation := Quaternion(
		Vector3.UP,
		PI * 0.5,
	)

	buffer.push(
		1,
		0.0,
		Vector3.ZERO,
		Quaternion(),
	)
	buffer.push(
		2,
		1.0,
		Vector3(0.0, 0.0, 10.0),
		target_rotation,
	)

	var state: Dictionary = buffer.sample(0.5)
	var position: Vector3 = state["position"]
	var rotation: Quaternion = state["rotation"]

	expect_true(
		position.is_equal_approx(
			Vector3(0.0, 0.0, 5.0)
		),
		"3D snapshot buffer should interpolate position.",
	)
	expect_true(
		is_equal_approx(
			rotation.length(),
			1.0,
		),
		"Interpolated quaternion should remain normalized.",
	)
