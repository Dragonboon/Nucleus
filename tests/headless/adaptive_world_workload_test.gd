extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_composition()
	return finish()


func _sample(sequence: int, fps: float, p95: float) -> NucleusPerformanceSnapshot:
	var snapshot := NucleusPerformanceSnapshot.new()
	snapshot.sequence = sequence
	snapshot.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, fps)
	snapshot.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS, p95)
	snapshot.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES, 30.0)
	return snapshot


func _test_composition() -> void:
	var root := Node.new()
	var controller := NucleusAdaptivePerformanceController.new()
	controller.start_enabled = true
	root.add_child(controller)
	var queue := NucleusMaterializationQueue.new()
	queue.max_steps_per_frame = 8
	queue.frame_budget_usec = 2000
	root.add_child(queue)
	var critical_queue := NucleusMaterializationQueue.new()
	critical_queue.max_steps_per_frame = 8
	root.add_child(critical_queue)
	var stream := NucleusWorldStreamLifecycle.new()
	stream.max_load_requests_per_frame = 4
	stream.max_unload_requests_per_frame = 3
	root.add_child(stream)
	var terrain := NucleusTerrainStreamer3D.new()
	terrain.max_new_chunks_per_update = 4
	root.add_child(terrain)
	var scatter := NucleusScatterRegion3D.new()
	scatter.partition_transforms_per_frame = 400
	scatter.batches_per_frame = 4
	root.add_child(scatter)
	var binding := NucleusAdaptiveWorldWorkloadBinding.new()
	binding.controller = controller
	binding.background_queue = queue
	binding.background_stream = stream
	binding.background_terrain = terrain
	binding.scatter_regions = [scatter]
	root.add_child(binding)
	expect_true(attach_test_node(root), "Adaptive workload scene enters tree.")
	expect_true(binding.profile.validate().is_empty(), "Profile validates.")
	expect_false(binding.is_binding_enabled(), "Adaptive world budgets require opt-in.")
	expect_equal(binding.enable_binding(), OK, "Explicit workload consent succeeds.")
	var contender := NucleusAdaptiveWorldWorkloadBinding.new()
	contender.controller = controller
	contender.background_queue = queue
	root.add_child(contender)
	expect_equal(contender.enable_binding(), ERR_BUSY, "Single writer per work queue.")
	for i in range(40):
		controller.submit_snapshot(_sample(i + 1, 42.0, 25.0))
	expect_true(binding.get_pressure() > 0.95, "Sustained overload reaches max pressure.")
	expect_true(queue.max_steps_per_frame < 8, "Background queue reduces steps.")
	expect_true(queue.max_steps_per_frame >= 1, "Background queue keeps progressing.")
	expect_true(queue.frame_budget_usec >= 250, "Queue time remains positive.")
	expect_true(stream.max_load_requests_per_frame < 4, "Load admission is reduced.")
	expect_equal(stream.max_unload_requests_per_frame, 3, "Unloads remain unthrottled.")
	expect_equal(critical_queue.max_steps_per_frame, 8, "Critical queue is untouched.")
	expect_true(terrain.max_new_chunks_per_update >= 1, "Terrain can still progress.")
	expect_true(scatter.batches_per_frame >= 1, "Scatter can still flush batches.")
	var slow_steps: int = queue.max_steps_per_frame
	for i in range(70):
		controller.submit_snapshot(_sample(i + 41, 60.0, 17.0))
	expect_true(queue.max_steps_per_frame > slow_steps, "Recovery restores capacity.")
	expect_equal(queue.max_steps_per_frame, 8, "Full recovery restores original steps.")
	expect_float(binding.get_pressure(), 0.0, "No workload pressure after recovery.")
	for i in range(24):
		controller.submit_snapshot(_sample(i + 111, 42.0, 25.0))
	queue.max_steps_per_frame = 7
	controller.submit_snapshot(_sample(135, 42.0, 25.0))
	expect_false(binding.is_binding_enabled(), "External edits revoke adaptive binding.")
	expect_equal(queue.max_steps_per_frame, 7, "External queue edit is preserved.")
	expect_equal(stream.max_load_requests_per_frame, 4,
		"Other owned budgets restore on revocation.")
	expect_equal(binding.enable_binding(), OK, "Can re-enable after external edit.")
	controller.set_adaptation_enabled(false)
	expect_false(binding.is_binding_enabled(), "Disabling controller releases budgets.")
	expect_equal(queue.max_steps_per_frame, 7, "Authored budget restored.")
	free_test_node(root)
