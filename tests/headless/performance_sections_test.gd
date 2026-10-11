extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_nested_and_out_of_order_sections()
	_test_capacity_and_bad_tokens()
	_test_budgets_and_bounded_hitch_history()
	_test_sampler_probes_and_frame_hitches()
	return finish()


func _test_nested_and_out_of_order_sections() -> void:
	var profiler := NucleusPerformanceSectionProfiler.new()
	profiler.debug_build_only = false

	var outer: int = profiler.begin_section(&"render", 1000000)
	var inner: int = profiler.begin_section(&"render", 1002000)
	expect_true(outer > 0 and inner > outer, "Nested sections get unique tokens.")
	expect_float(
		profiler.end_section(outer, 1010000),
		10.0,
		"An outer section may finish before a nested section.",
	)
	expect_float(
		profiler.end_section(inner, 1006000),
		4.0,
		"The inner section retains its own start timestamp.",
	)
	var stats: Dictionary = profiler.get_section_statistics(&"render")
	expect_equal(int(stats["samples"]), 2, "Two timings accumulate under one label.")
	expect_float(float(stats["average_ms"]), 7.0, "Average uses both timings.")
	expect_float(float(stats["minimum_ms"]), 4.0, "Minimum is retained.")
	expect_float(float(stats["maximum_ms"]), 10.0, "Maximum is retained.")
	expect_equal(profiler.get_active_section_count(), 0, "All tokens are released.")
	expect_float(profiler.end_section(inner, 1007000), -1.0, "Duplicate end is ignored.")
	profiler.free()


func _test_capacity_and_bad_tokens() -> void:
	var profiler := NucleusPerformanceSectionProfiler.new()
	profiler.debug_build_only = false
	profiler.max_active_sections = 2
	profiler.max_tracked_labels = 1
	var first: int = profiler.begin_section(&"stream", 10)
	var second: int = profiler.begin_section(&"stream", 20)
	expect_true(first > 0 and second > 0, "One label may have overlapping scopes.")
	expect_equal(profiler.begin_section(&"other", 30), 0, "Active budget is bounded.")
	expect_float(profiler.end_section(first, 0), -1.0, "Reverse timestamps are rejected.")
	expect_equal(
		profiler.begin_section(&"other", 40),
		0,
		"Label budget counts currently active labels.",
	)
	expect_float(profiler.end_section(second, 3020), 3.0, "Remaining token works.")
	expect_equal(
		profiler.begin_section(&"other", 4000),
		0,
		"Label cap remains bounded by completed statistics.",
	)
	profiler.clear_capture()
	expect_true(
		profiler.begin_section(&"other", 5000) > 0,
		"Clearing capture releases label capacity.",
	)
	profiler.enabled = false
	expect_equal(profiler.begin_section(&"disabled", 0), 0, "Disabled capture is inert.")
	profiler.free()


func _test_budgets_and_bounded_hitch_history() -> void:
	var profiler := NucleusPerformanceSectionProfiler.new()
	profiler.debug_build_only = false
	profiler.default_section_budget_ms = 5.0
	profiler.hitch_history_capacity = 1
	expect_equal(
		profiler.set_section_budget(&"ai", -1.0),
		ERR_INVALID_PARAMETER,
		"Negative section budgets are rejected.",
	)
	expect_equal(profiler.set_section_budget(&"ai", 2.0), OK, "Custom budget accepted.")
	var first: int = profiler.begin_section(&"ai", 1000)
	profiler.end_section(first, 4000)
	var second: int = profiler.begin_section(&"ai", 5000)
	profiler.end_section(second, 9000)
	var stats: Dictionary = profiler.get_section_statistics(&"ai")
	expect_equal(stats["over_budget_count"], 2, "Each over-budget scope is counted.")
	var events: Array[Dictionary] = profiler.get_hitch_history()
	expect_equal(events.size(), 1, "Hitch history has a strict capacity.")
	expect_float(
		float(events[0]["duration_ms"]),
		4.0,
		"Hitch ring retains the most recent event.",
	)
	var stats_copy: Dictionary = profiler.get_section_statistics(&"ai")
	stats_copy["samples"] = 999
	expect_equal(
		profiler.get_section_statistics(&"ai")["samples"],
		2,
		"Statistics are returned by value, not mutable reference.",
	)
	profiler.free()


func _test_sampler_probes_and_frame_hitches() -> void:
	var root := Node.new()
	var sampler := NucleusPerformanceSampler.new()
	sampler.start_enabled = false
	sampler.publish_summary_monitors = false
	sampler.evaluate_diagnostics = false
	var profiler := NucleusPerformanceSectionProfiler.new()
	profiler.debug_build_only = false
	profiler.sampler = sampler
	root.add_child(sampler)
	root.add_child(profiler)
	expect_true(attach_test_node(root), "Sampler integration requires a SceneTree.")

	var token: int = profiler.begin_section(&"load", 1000000)
	profiler.end_section(token, 1012000)
	var sampled: NucleusPerformanceSnapshot = sampler.sample_now()
	expect_true(
		sampled.has_metric(&"section/load/last_ms"),
		"Section timing registers a sampler probe.",
	)
	expect_float(
		sampled.get_metric(&"section/load/last_ms"),
		12.0,
		"Sampler stores the most recent measured section duration.",
	)

	var snapshot := NucleusPerformanceSnapshot.new()
	snapshot.sequence = 50
	snapshot.timestamp_usec = 9000000
	snapshot.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_MAX_MS, 40.0)
	profiler._on_snapshot_sampled(snapshot)
	profiler._on_snapshot_sampled(snapshot)
	expect_equal(
		profiler.get_hitch_history().size(),
		1,
		"One sampler window produces at most one frame hitch.",
	)
	expect_equal(sampler.get_traces().size(), 1, "Frame hitch reaches sampler traces.")
	profiler.bind_sampler(null)
	sampler.sample_now()
	expect_false(
		sampler.get_latest_snapshot().has_metric(&"section/load/last_ms"),
		"Rebinding unregisters the profiler-owned sampler probe.",
	)
	free_test_node(root)
