extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_binding_lifetime()
	_test_scene_wiring()
	return finish()


func _test_binding_lifetime() -> void:
	var settings := Engine.get_main_loop().root.get_node_or_null(
		"NucleusSettings"
	) as NucleusSettingsService
	expect_true(settings != null and settings.is_initialized(),
		"Settings autoload initializes for integration tests.")
	if settings == null or not settings.is_initialized():
		return
	var applier := settings.get_node_or_null(
		"DisplaySettingsApplier"
	) as NucleusDisplaySettingsApplier
	expect_true(applier != null, "The sole render-scale writer is available.")
	if applier == null:
		return
	var original: float = settings.get_float(
		NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0
	)
	var root := Node.new()
	var controller := NucleusAdaptivePerformanceController.new()
	controller.start_enabled = true
	root.add_child(controller)
	var binding := NucleusAdaptiveQualityBinding.new()
	binding.controller = controller
	binding.display_applier = applier
	root.add_child(binding)
	expect_true(attach_test_node(root), "Binding enters SceneTree.")
	expect_false(binding.is_binding_enabled(), "Binding never auto-enables.")
	expect_equal(binding.enable_binding(), OK, "Explicit opt-in succeeds.")
	expect_float(applier.get_effective_render_scale(), minf(original, 1.0),
		"Initial binding respects the persisted preference.")
	var other := Node.new()
	root.add_child(other)
	expect_equal(applier.request_temporary_render_scale(other, 0.85), ERR_BUSY,
		"Only one temporary owner may be active.")
	for i in range(12):
		var sample := NucleusPerformanceSnapshot.new()
		sample.sequence = i + 1
		sample.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, 42.0)
		sample.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS, 25.0)
		sample.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES, 30.0)
		controller.submit_snapshot(sample)
	expect_true(applier.get_temporary_render_scale() < 1.0,
		"Real applier receives adaptive recommendations.")
	expect_float(settings.get_float(
		NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0
	), original, "Temporary quality cannot change the saved setting.")
	var alternate: float = 0.95 if original != 0.95 else 0.90
	expect_equal(settings.set_value(
		NucleusSettingIds.GRAPHICS_RENDER_SCALE, alternate, false
	), OK, "Player's manual preference can change.")
	expect_false(binding.is_binding_enabled(),
		"Manual preference revokes the active binding.")
	expect_float(applier.get_effective_render_scale(), alternate,
		"Manual preference takes effect immediately.")
	expect_equal(applier.get_temporary_render_scale(), -1.0,
		"Stale temporary override is discarded.")
	expect_equal(settings.set_value(
		NucleusSettingIds.GRAPHICS_RENDER_SCALE, original, false
	), OK, "Test restores the original preference without persisting.")
	expect_equal(binding.enable_binding(), OK, "User can explicitly opt in again.")
	free_test_node(root)
	expect_float(applier.get_effective_render_scale(), original,
		"Scene exit restores the authored value.")
	expect_equal(applier.get_temporary_render_scale(), -1.0,
		"Teardown releases the temporary owner.")


func _test_scene_wiring() -> void:
	var scene := load(
		"res://examples/adaptive_performance/adaptive_quality_lab.tscn"
	) as PackedScene
	expect_true(scene != null, "Adaptive quality demo loads.")
	if scene == null:
		return
	var lab := scene.instantiate()
	expect_true(attach_test_node(lab), "Adaptive quality lab runs.")
	var controller := lab.get_node_or_null(
		"AdaptiveController"
	) as NucleusAdaptivePerformanceController
	var binding := lab.get_node_or_null(
		"AdaptiveQualityBinding"
	) as NucleusAdaptiveQualityBinding
	expect_true(controller != null, "Lab owns an adaptive controller.")
	expect_true(binding != null, "Lab owns a settings binding.")
	if binding != null:
		expect_false(binding.is_binding_enabled(), "Lab begins without consent.")
	free_test_node(lab)
