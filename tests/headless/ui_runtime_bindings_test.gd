extends "res://tests/headless/test_case.gd"

const FIXTURE_A := "res://tests/fixtures/loading/load_fixture_a.tres"


func run() -> Dictionary:
	_test_default_bus_layout_bootstrap_path()
	_test_value_pool_progress_binding()
	_test_resource_load_binding()
	_test_scene_load_binding()
	return finish()


func _test_default_bus_layout_bootstrap_path() -> void:
	var bus_layout := str(
		ProjectSettings.get_setting(
			"audio/buses/default_bus_layout",
			"",
		)
	)
	expect_equal(
		bus_layout,
		"res://addons/nucleus/core/audio/default_bus_layout.tres",
		"Default AudioBusLayout should avoid early project-setting UID lookup.",
	)


func _test_value_pool_progress_binding() -> void:
	var root := Node.new()
	var pool := NucleusValuePool.new()
	var bar := ProgressBar.new()
	var feedback := NucleusUIProgressFeedback.new()
	var binding := NucleusUIValuePoolProgressBinding.new()

	pool.minimum_value = 0.0
	pool.maximum_value = 100.0
	pool.initial_value = 100.0
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	feedback.primary_target = bar
	binding.source = pool
	binding.target = feedback
	binding.animate_changes = false
	binding.snap_initial = false

	root.add_child(pool)
	root.add_child(bar)
	root.add_child(feedback)
	root.add_child(binding)

	expect_true(
		attach_test_node(root),
		"ValuePool UI binding fixture requires a live SceneTree.",
	)
	expect_equal(
		binding.refresh(false),
		OK,
		"ValuePool UI binding should refresh when configured.",
	)
	expect_float(
		bar.value,
		1.0,
		"Initial ValuePool ratio should reach the progress presentation.",
	)

	pool.decrease(25.0)
	expect_float(
		bar.value,
		0.75,
		"ValuePool changes should update progress presentation ratio.",
	)

	free_test_node(root)


func _test_resource_load_binding() -> void:
	var cached := ResourceLoader.load(FIXTURE_A)
	expect_true(cached != null, "Loading fixture should be available for UI binding test.")

	var root := Node.new()
	var queue := NucleusResourceLoadQueue.new()
	var bar := ProgressBar.new()
	var count := Label.new()
	var item := Label.new()
	var binding := NucleusUIResourceLoadBinding.new()

	bar.min_value = 0.0
	bar.max_value = 100.0
	binding.source = queue
	binding.progress_target = bar
	binding.count_label = count
	binding.item_label = item

	root.add_child(queue)
	root.add_child(bar)
	root.add_child(count)
	root.add_child(item)
	root.add_child(binding)

	expect_true(
		attach_test_node(root),
		"Resource-load UI binding fixture requires a live SceneTree.",
	)

	var entry := NucleusLoadEntry.new()
	entry.path = FIXTURE_A
	entry.display_name = "Fixture A"
	entry.retain = true

	var plan := NucleusLoadPlan.new()
	plan.entries = [entry]

	expect_equal(queue.start(plan), OK, "Cached UI loading plan should start.")
	expect_float(bar.value, 100.0, "Loading UI should reach full progress.")
	expect_equal(count.text, "1 / 1", "Loading UI should expose processed count.")
	expect_equal(item.text, "Fixture A", "Loading UI should expose authored item label.")

	free_test_node(root)


func _test_scene_load_binding() -> void:
	var root := Node.new()
	var bar := ProgressBar.new()
	var binding := NucleusUISceneLoadBinding.new()

	bar.min_value = 0.0
	bar.max_value = 200.0
	bar.value = 0.0
	binding.progress_target = bar
	binding.animate_progress = false

	root.add_child(bar)
	root.add_child(binding)

	expect_true(
		attach_test_node(root),
		"Scene-load UI binding fixture requires a live SceneTree.",
	)

	NucleusSceneFlow.load_progress.emit(
		"res://tests/fixtures/example_scene.tscn",
		0.42,
	)
	expect_float(
		bar.value,
		84.0,
		"SceneFlow progress should map into the target Range bounds.",
	)

	free_test_node(root)
