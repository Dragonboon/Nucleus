extends Control
## Synthetic test laboratory. No rendering settings are changed.

var controller: NucleusAdaptivePerformanceController
var label: Label
var history: RichTextLabel
var _sequence: int = 0
var _scenario: StringName = &"healthy"


func _ready() -> void:
	controller = NucleusAdaptivePerformanceController.new()
	controller.name = "AdaptiveController"
	controller.start_enabled = true
	add_child(controller)
	controller.decision_observed.connect(_on_decision)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(395, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "ADAPTIVE PERFORMANCE · OBSERVATION LAB"
	column.add_child(heading)
	var hints := Label.new()
	hints.text = "Synthetic windows, not actual device FPS.\nNo graphics settings are changed."
	column.add_child(hints)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_button(buttons, "1  42 FPS", func() -> void: _set_scenario(&"slow"))
	_button(buttons, "2  60 FPS", func() -> void: _set_scenario(&"healthy"))
	_button(buttons, "3  55 FPS", func() -> void: _set_scenario(&"neutral"))
	_button(column, "Step one sample (Space)", _step)
	_button(column, "Run 12 samples", func() -> void:
		for i in range(12):
			_step()
	)
	_button(column, "Reset policy (R)", func() -> void:
		controller.reset_observation()
		_sequence = 0
		_refresh()
	)
	label = Label.new()
	column.add_child(label)
	history = RichTextLabel.new()
	history.custom_minimum_size.y = 190
	column.add_child(history)
	_refresh()


func _button(parent: BoxContainer, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(callback)


func _set_scenario(value: StringName) -> void:
	_scenario = value
	_refresh()


func _step() -> void:
	_sequence += 1
	var fps: float = 60.0
	var p95: float = 17.0
	match _scenario:
		&"slow":
			fps = 42.0
			p95 = 25.0
		&"neutral":
			fps = 55.0
			p95 = 18.0
	var snapshot := NucleusPerformanceSnapshot.new()
	snapshot.sequence = _sequence
	snapshot.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, fps)
	snapshot.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS, p95)
	snapshot.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES, 30.0)
	controller.submit_snapshot(snapshot)


func _on_decision(decision: Dictionary) -> void:
	if history != null:
		history.append_text("Window %d: %s → %.0f%%\n" % [
			_sequence, decision["reason"], float(decision["render_scale"]) * 100.0,
		])
	_refresh()


func _refresh() -> void:
	if label == null:
		return
	label.text = "Scenario: %s\nTarget: 60 FPS · Min: 80%%\nSuggested: %.0f%%" % [
		_scenario, controller.get_suggested_scale() * 100.0,
	]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_set_scenario(&"slow")
		KEY_2:
			_set_scenario(&"healthy")
		KEY_3:
			_set_scenario(&"neutral")
		KEY_SPACE:
			_step()
		KEY_R:
			controller.reset_observation()
			_sequence = 0
			_refresh()
