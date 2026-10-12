extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_profile()
	_test_degrade_and_recover()
	_test_insufficient_and_stale()
	_test_controller()
	return finish()


func _sample(sequence: int, fps: float, p95: float, count: float = 30.0
) -> NucleusPerformanceSnapshot:
	var result := NucleusPerformanceSnapshot.new()
	result.sequence = sequence
	result.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, fps)
	result.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS, p95)
	result.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES, count)
	return result


func _test_profile() -> void:
	var profile := NucleusAdaptivePerformanceProfile.new()
	expect_true(profile.validate().is_empty(), "Default policy is valid.")
	expect_equal(profile.target_fps, 60, "Target is 60 FPS.")
	expect_float(profile.minimum_render_scale, 0.8, "Floor is 80%.")
	expect_true(profile.allow_quality_recovery, "Recovery is enabled.")
	profile.minimum_render_scale = 1.1
	expect_false(profile.validate().is_empty(), "Invalid scale range rejected.")


func _test_degrade_and_recover() -> void:
	var profile := NucleusAdaptivePerformanceProfile.new()
	profile.degradation_windows = 2
	profile.recovery_windows = 3
	profile.cooldown_windows = 1
	var policy := NucleusAdaptivePerformancePolicy.new(profile)
	var sequence := 0
	for _i in range(32):
		sequence += 1
		var decision: Dictionary = policy.evaluate(_sample(sequence, 42.0, 25.0))
		expect_true(float(decision["render_scale"]) >= 0.8,
			"Scale never falls below the configured floor.")
	expect_float(policy.get_suggested_scale(), 0.8, "Degradation reaches the floor.")
	for _i in range(30):
		sequence += 1
		policy.evaluate(_sample(sequence, 60.0, 17.0))
	expect_float(policy.get_suggested_scale(), 1.0, "Quality recovers to 100%.")
	var stable := policy.evaluate(_sample(sequence + 1, 55.0, 18.0))
	expect_false(stable["changed"], "Neutral interval does not oscillate.")


func _test_insufficient_and_stale() -> void:
	var policy := NucleusAdaptivePerformancePolicy.new()
	var first: Dictionary = policy.evaluate(_sample(10, 42.0, 25.0, 2.0))
	expect_equal(first["reason"], &"insufficient_data",
		"Missing frame evidence is not a load regression.")
	expect_equal(policy.evaluate(_sample(10, 42.0, 25.0))["reason"],
		&"stale_sample", "Duplicate sample sequence is ignored.")
	expect_equal(policy.evaluate(null)["reason"], &"missing_sample",
		"Null snapshots fail closed.")
	expect_float(policy.get_suggested_scale(), 1.0,
		"Invalid samples do not reduce quality.")
	var profile := NucleusAdaptivePerformanceProfile.new()
	profile.allow_quality_recovery = false
	policy = NucleusAdaptivePerformancePolicy.new(profile)
	for i in range(15):
		policy.evaluate(_sample(i + 1, 40.0, 25.0))
	var floor_before: float = policy.get_suggested_scale()
	for i in range(40):
		policy.evaluate(_sample(i + 16, 60.0, 17.0))
	expect_float(policy.get_suggested_scale(), floor_before,
		"Disabled recovery never raises the recommendation.")


func _test_controller() -> void:
	var root := Node.new()
	var controller := NucleusAdaptivePerformanceController.new()
	controller.start_enabled = false
	root.add_child(controller)
	expect_true(attach_test_node(root), "Controller enters the SceneTree.")
	expect_false(controller.is_adaptation_enabled(), "Observe state is explicit.")
	controller.submit_snapshot(_sample(1, 30.0, 40.0))
	expect_float(controller.get_suggested_scale(), 1.0,
		"Disabled controller ignores samples.")
	controller.set_adaptation_enabled(true)
	for i in range(8):
		controller.submit_snapshot(_sample(i + 1, 40.0, 25.0))
	expect_true(controller.get_suggested_scale() < 1.0,
		"Enabled controller exposes the policy recommendation.")
	controller.set_adaptation_enabled(false)
	expect_float(controller.get_suggested_scale(), 1.0,
		"Disabling resets outstanding temporary recommendations.")
	free_test_node(root)
