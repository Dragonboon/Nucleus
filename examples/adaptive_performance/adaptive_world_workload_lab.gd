extends Control
## Synthetic performance windows, real optional workload budget changes.
## It does not instantiate terrain, critical gameplay jobs or a second sampler.

var controller: NucleusAdaptivePerformanceController
var binding: NucleusAdaptiveWorldWorkloadBinding
var queue: NucleusMaterializationQueue
var critical_queue: NucleusMaterializationQueue
var streaming: NucleusWorldStreamLifecycle
var terrain: NucleusTerrainStreamer3D
var scatter: NucleusScatterRegion3D
var status: Label
var _sequence: int = 0


func _ready() -> void:
	controller = NucleusAdaptivePerformanceController.new()
	controller.name = "AdaptiveController"
	controller.start_enabled = true
	add_child(controller)
	queue = NucleusMaterializationQueue.new()
	queue.name = "OptionalMaterialization"
	queue.max_steps_per_frame = 8
	queue.frame_budget_usec = 2000
	queue.process_automatically = false
	add_child(queue)
	critical_queue = NucleusMaterializationQueue.new()
	critical_queue.name = "CriticalMaterialization"
	critical_queue.max_steps_per_frame = 8
	critical_queue.process_automatically = false
	add_child(critical_queue)
	streaming = NucleusWorldStreamLifecycle.new()
	streaming.name = "OptionalStreaming"
	streaming.max_load_requests_per_frame = 4
	streaming.max_unload_requests_per_frame = 3
	streaming.process_automatically = false
	add_child(streaming)
	terrain = NucleusTerrainStreamer3D.new()
	terrain.name = "OptionalTerrain"
	terrain.max_new_chunks_per_update = 4
	add_child(terrain)
	scatter = NucleusScatterRegion3D.new()
	scatter.name = "OptionalScatter"
	scatter.partition_transforms_per_frame = 400
	scatter.batches_per_frame = 4
	add_child(scatter)
	binding = NucleusAdaptiveWorldWorkloadBinding.new()
	binding.name = "WorldWorkloadBinding"
	binding.controller = controller
	binding.background_queue = queue
	binding.background_stream = streaming
	binding.background_terrain = terrain
	binding.scatter_regions = [scatter]
	add_child(binding)
	binding.workload_changed.connect(func(_pressure: float, _budgets: Dictionary
	) -> void: _refresh())
	binding.binding_state_changed.connect(func(_enabled: bool, _reason: StringName
	) -> void: _refresh())
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(470, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "ADAPTIVE WORLD WORKLOAD · NUCLEUS"
	column.add_child(title)
	var note := Label.new()
	note.text = "Synthetic FPS; changes only optional CPU-work budgets."
	column.add_child(note)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_button(actions, "Enable / Disable (E)", _toggle)
	_button(actions, "Reset (R)", _reset)
	var scenarios := HBoxContainer.new()
	column.add_child(scenarios)
	_button(scenarios, "1  Slow × 12", func() -> void: _feed(42.0, 25.0, 12))
	_button(scenarios, "2  Healthy × 30", func() -> void: _feed(60.0, 17.0, 30))
	status = Label.new()
	column.add_child(status)
	_refresh()


func _button(parent: Control, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)


func _feed(fps: float, p95: float, amount: int) -> void:
	for i in range(amount):
		_sequence += 1
		var sample := NucleusPerformanceSnapshot.new()
		sample.sequence = _sequence
		sample.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, fps)
		sample.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS, p95)
		sample.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES, 30.0)
		controller.submit_snapshot(sample)
	_refresh()


func _toggle() -> void:
	if binding.is_binding_enabled():
		binding.disable_binding()
	else:
		var error: Error = binding.enable_binding()
		if error != OK:
			status.text = "Cannot enable: " + error_string(error)
			return
	_refresh()


func _reset() -> void:
	binding.disable_binding()
	controller.reset_observation()
	_sequence = 0
	_refresh()


func _refresh() -> void:
	if status == null:
		return
	status.text = "Status: %s · Pressure: %.0f%%\n" % [
		"Active" if binding.is_binding_enabled() else "Observe only",
		binding.get_pressure() * 100.0,
	]
	status.text += "Materialization: %d steps / %d usec\n" % [
		queue.max_steps_per_frame, queue.frame_budget_usec,
	]
	status.text += "Load/unload admission: %d / %d\n" % [
		streaming.max_load_requests_per_frame,
		streaming.max_unload_requests_per_frame,
	]
	status.text += "Terrain chunks / update: %d\n" % terrain.max_new_chunks_per_update
	status.text += "Scatter partition / batches: %d / %d\n" % [
		scatter.partition_transforms_per_frame, scatter.batches_per_frame,
	]
	status.text += "Critical queue (untouched): %d steps\n" % (
		critical_queue.max_steps_per_frame
	)
	status.text += "Recommended render scale: %.0f%%" % (
		controller.get_suggested_scale() * 100.0
	)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_feed(42.0, 25.0, 12)
		KEY_2:
			_feed(60.0, 17.0, 30)
		KEY_E:
			_toggle()
		KEY_R:
			_reset()
