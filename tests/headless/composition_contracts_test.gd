extends "res://tests/headless/test_case.gd"
## Behavior-level proof that composed Nucleus owners actually communicate.


class RecordingState:
	extends NucleusState

	var allow_entry: bool = true
	var entries: int = 0
	var exits: int = 0


	func can_enter(_previous_state: NucleusState, _context: Dictionary) -> bool:
		return allow_entry


	func enter(_previous_state: NucleusState, _context: Dictionary) -> void:
		entries += 1


	func exit(_next_state: NucleusState) -> void:
		exits += 1


func run() -> Dictionary:
	_test_scene_owned_state_machine()
	_test_signal_disconnect_on_scene_release()
	_test_input_timing_reuses_performance_profiler()
	_test_animated_value_snap_and_interruption()
	_test_binding_diagnostics()
	_test_independent_image_consumers()
	return finish()


func _test_scene_owned_state_machine() -> void:
	var root := Node.new()
	var machine := NucleusStateMachine.new()
	var idle := RecordingState.new()
	var busy := RecordingState.new()
	idle.name = "Idle"
	busy.name = "Busy"
	machine.initial_state = idle
	root.add_child(machine)
	machine.add_child(idle)
	machine.add_child(busy)

	var observed: Array[StringName] = []
	machine.state_changed.connect(
		func(_from: NucleusState, next: NucleusState, _context: Dictionary) -> void:
			observed.append(next.get_state_id())
	)

	if not attach_test_node(root):
		expect_true(false, "State-machine composition needs a SceneTree.")
		root.free()
		return

	expect_equal(idle.entries, 1, "Scene-owned initial state enters once.")
	busy.allow_entry = false
	expect_equal(machine.change_state(&"Busy"), ERR_UNAVAILABLE,
		"Disallowed transition is rejected before exiting current state.")
	expect_equal(idle.exits, 0, "Rejected transition does not exit owner.")
	busy.allow_entry = true
	expect_equal(machine.change_state(&"Busy"), OK,
		"Explicit transition succeeds through NucleusStateMachine.")
	expect_equal(idle.exits, 1, "Previous state exits exactly once.")
	expect_equal(busy.entries, 1, "Next state enters exactly once.")
	expect_equal(observed, [&"Busy"], "Single authoritative change signal.")

	var snapshot: Dictionary = machine.capture_state()
	expect_equal(machine.change_state(&"Idle"), OK, "State can change again.")
	expect_equal(machine.restore_state(snapshot), OK,
		"Capturable state restores through the existing owner.")
	expect_true(machine.current_state == busy, "Restored state becomes active.")
	expect_equal(busy.entries, 2, "Restoration calls the real entry hook.")
	free_test_node(root)


func _test_signal_disconnect_on_scene_release() -> void:
	var before_count: int = NucleusSceneFlow.load_progress.get_connections().size()
	var root := Node.new()
	var bar := ProgressBar.new()
	var binding := NucleusUISceneLoadBinding.new()
	binding.progress_target = bar
	root.add_child(bar)
	root.add_child(binding)
	expect_composition_binding(binding, &"progress_target", bar)
	var binding_candidates: Array[Node] = [binding]
	expect_single_binding(binding_candidates, &"progress_target", bar)

	if not attach_test_node(root):
		expect_true(false, "Signal-lifetime fixture needs a SceneTree.")
		root.free()
		return

	expect_equal(
		NucleusSceneFlow.load_progress.get_connections().size(),
		before_count + 1,
		"Live scene binds to the existing scene-flow signal once.",
	)
	free_test_node(root)
	expect_equal(
		NucleusSceneFlow.load_progress.get_connections().size(),
		before_count,
		"Releasing scene disconnects signal and avoids stale callbacks.",
	)


func _test_input_timing_reuses_performance_profiler() -> void:
	var profiler := NucleusPerformanceSectionProfiler.new()
	profiler.debug_build_only = false
	var token: int = profiler.begin_section(&"input.received_to_consumed", 1000000)
	expect_true(token > 0, "Existing profiler accepts explicit timestamps.")
	expect_float(profiler.end_section(token, 1002450), 2.45,
		"Input reception-to-consumption interval is measurable in milliseconds.")
	expect_equal(profiler.end_section(token, 1003000), -1.0,
		"A completed profiling token cannot be reused.")
	expect_equal(
		profiler.get_section_statistics(&"input.received_to_consumed")["samples"],
		1,
		"One input span contributes exactly one statistic.",
	)
	profiler.free()


func _test_animated_value_snap_and_interruption() -> void:
	var root := Node.new()
	var label := Label.new()
	var view := NucleusUIAnimatedValue.new()
	var profile := NucleusUIMotionProfile.new()
	profile.duration = 0.0
	view.label_target = label
	view.motion = profile
	root.add_child(label)
	root.add_child(view)

	if not attach_test_node(root):
		expect_true(false, "Animated-value fixture needs a SceneTree.")
		root.free()
		return

	var completed: Array[float] = []
	view.animation_finished.connect(
		func(value: float) -> void:
			completed.append(value)
	)
	expect_true(view.set_value(24.0, true) == null,
		"Zero-duration motion snaps immediately instead of scheduling a tween.")
	expect_equal(label.text, "24", "Synchronous snap updates the label.")
	expect_equal(completed, [24.0], "Snap completes exactly once.")

	profile.duration = 1.0
	profile.respect_reduced_motion = false
	var tween: Tween = view.set_value(90.0, true)
	expect_true(tween != null, "Enabled motion creates a tween.")
	view.set_value(5.0, false)
	expect_equal(label.text, "5", "A newer immediate value supersedes animation.")
	expect_equal(completed, [24.0, 5.0],
		"Interrupting the tween does not emit its old completion.")
	free_test_node(root)


class BindingOwner extends Node:
	var target: Node


func _test_binding_diagnostics() -> void:
	var target := Node.new()
	var first := BindingOwner.new()
	var second := BindingOwner.new()
	first.target = target
	var candidates: Array[Node] = [first, second]
	expect_composition_binding(first, &"target", target)
	expect_single_binding(candidates, &"target", target)
	var probe: Variant = load("res://tests/headless/test_case.gd").new()
	probe.expect_composition_binding(second, &"target", target)
	second.target = target
	probe.expect_single_binding(candidates, &"target", target)
	probe.expect_composition_binding(first, &"missing", target)
	expect_equal(probe.finish()["failures"].size(), 3,
		"Missing, unbound and duplicate declared owners produce diagnostics.")
	first.free()
	second.free()
	target.free()


func _test_independent_image_consumers() -> void:
	# A one-way catalog and a returnable inspection use the same optional adapter.
	for returnable in [false, true]:
		var root := Node.new()
		var screen := NucleusImageScreen.new()
		var session := NucleusAdventureSession.new()
		var first := NucleusAdventurePage.new()
		var second := NucleusAdventurePage.new()
		first.id = &"index"
		second.id = &"detail"
		var image := ImageTexture.create_from_image(
			Image.create(4, 4, false, Image.FORMAT_RGBA8))
		first.image = image
		second.image = image
		var link := NucleusScreenHotspot.new()
		link.id = &"open"
		link.destination = second.id
		first.hotspots = [link]
		if returnable:
			second.back_page = first.id
			second.navigation_edge_fraction = Vector2(0.07, 0.065)
		session.pages = [first, second]
		session.screen = screen
		root.add_child(screen)
		root.add_child(session)
		if not attach_test_node(root):
			expect_true(false, "Consumer composition requires SceneTree attachment.")
			root.free()
			continue
		expect_composition_binding(session, &"screen", screen)
		expect_true(session.validate_configuration(returnable).is_empty(),
			"Independent consumer policy is admitted without mandatory inventory or effects.")
		screen.activate(&"open")
		expect_equal(session.current_page, second.id, "Both consumers use the same activation owner.")
		expect_equal(session.go_back(), OK if returnable else ERR_DOES_NOT_EXIST,
			"Returnability is consumer policy, not an implicit framework default.")
		root.free()
