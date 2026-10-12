extends Control
## Demonstrates real temporary scale application with synthetic FPS samples.
## The persistent Settings value is never touched by adaptive recommendations.

var controller: NucleusAdaptivePerformanceController
var binding: NucleusAdaptiveQualityBinding
var _applier: NucleusDisplaySettingsApplier
var _status: Label
var _history: Label
var _button: Button
var _sequence: int = 0


func _ready() -> void:
	controller = NucleusAdaptivePerformanceController.new()
	controller.name = "AdaptiveController"
	controller.start_enabled = true
	add_child(controller)
	var settings := get_node_or_null("/root/NucleusSettings") as NucleusSettingsService
	if settings != null:
		_applier = settings.get_node_or_null(
			"DisplaySettingsApplier"
		) as NucleusDisplaySettingsApplier
	binding = NucleusAdaptiveQualityBinding.new()
	binding.name = "AdaptiveQualityBinding"
	binding.controller = controller
	binding.display_applier = _applier
	add_child(binding)
	controller.decision_observed.connect(_on_decision)
	binding.binding_state_changed.connect(_on_binding_state)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(360, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "ADAPTIVE QUALITY · TEMPORARY"
	column.add_child(title)
	var note := Label.new()
	note.text = "Simulated frame samples, real render-scale override.\n"
	note.text += "Persistent settings remain unchanged."
	column.add_child(note)
	_button = Button.new()
	_button.text = "Enable adaptation (opt in)"
	_button.pressed.connect(_toggle)
	column.add_child(_button)
	var row := HBoxContainer.new()
	column.add_child(row)
	_add_button(row, "1 Slow", func() -> void: _feed(42.0, 25.0))
	_add_button(row, "2 Healthy", func() -> void: _feed(60.0, 17.0))
	_add_button(row, "R Reset", _reset)
	_status = Label.new()
	column.add_child(_status)
	_history = Label.new()
	column.add_child(_history)
	_refresh()


func _add_button(parent: Control, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)


func _toggle() -> void:
	if binding.is_binding_enabled():
		binding.disable_binding()
	else:
		var status: Error = binding.enable_binding()
		if status != OK:
			_history.text = "Cannot enable: " + error_string(status)
	_refresh()


func _feed(fps: float, p95: float) -> void:
	for _i in range(12):
		_sequence += 1
		var sample := NucleusPerformanceSnapshot.new()
		sample.sequence = _sequence
		sample.set_metric(NucleusPerformanceMetricIds.WINDOW_FPS, fps)
		sample.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS, p95)
		sample.set_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_SAMPLES, 30.0)
		controller.submit_snapshot(sample)
	_refresh()


func _reset() -> void:
	binding.disable_binding()
	controller.reset_observation()
	_sequence = 0
	_history.text = "Policy reset; the authored preference is restored."
	_refresh()


func _on_decision(decision: Dictionary) -> void:
	if _history != null and bool(decision.get("changed", false)):
		_history.text = "%s: recommended %.0f%%" % [
			decision["reason"], float(decision["render_scale"]) * 100.0
		]
	_refresh()


func _on_binding_state(_active: bool, reason: StringName) -> void:
	if _history != null:
		_history.text = "Binding: " + str(reason)
	_refresh()


func _refresh() -> void:
	if _status == null:
		return
	var authored: float = 1.0
	var effective: float = 1.0
	var settings := get_node_or_null("/root/NucleusSettings") as NucleusSettingsService
	if settings != null and settings.is_initialized():
		authored = settings.get_float(NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0)
	if _applier != null:
		effective = _applier.get_effective_render_scale()
	_status.text = "Saved preference: %.0f%%\nRecommended: %.0f%%\n" % [
		authored * 100.0, controller.get_suggested_scale() * 100.0
	]
	_status.text += "Effective: %.0f%%\nBinding: %s" % [
		effective * 100.0, "ON" if binding.is_binding_enabled() else "OFF"
	]
	_button.text = (
		"Disable and restore" if binding.is_binding_enabled()
		else "Enable adaptation (opt in)"
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_feed(42.0, 25.0)
			KEY_2:
				_feed(60.0, 17.0)
			KEY_R:
				_reset()
