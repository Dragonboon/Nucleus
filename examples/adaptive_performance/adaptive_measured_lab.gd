extends Node3D
## Real terrain jobs and measured frame windows; no simulated FPS or busy waits.
## A/B runs use the same bounded workload. Throughput and recovery matter alongside FPS.

signal comparison_finished(report: Dictionary)

@export_range(0.5, 60.0, 0.5) var phase_seconds: float = 8.0
var sampler: NucleusPerformanceSampler
var controller: NucleusAdaptivePerformanceController
var binding: NucleusAdaptiveWorldWorkloadBinding
var queue: NucleusMaterializationQueue
var running: bool = false
var report: Dictionary = {}
var _profile: NucleusTerrainProfile
var _refill: bool = false
var _completed: int = 0
var _submitted: int = 0
var _preview: Node3D
var _label: Label
var _phase: String = "Ready"
var _minimum_scale: float = 1.0
var _epoch: int = 0
var _phase_started_usec: int = 0


func _ready() -> void:
	queue = NucleusMaterializationQueue.new()
	queue.max_steps_per_frame = 16
	queue.frame_budget_usec = 0
	add_child(queue)
	sampler = NucleusPerformanceSampler.new()
	sampler.sample_interval_seconds = 0.25
	sampler.warmup_seconds = 0.0
	add_child(sampler)
	controller = NucleusAdaptivePerformanceController.new()
	controller.sampler = sampler
	controller.profile = NucleusAdaptivePerformanceProfile.new()
	# Shorter observation for this bounded lab; target and minimum remain 60 / 80%.
	controller.profile.minimum_frame_samples = 2
	controller.profile.degradation_windows = 2
	controller.profile.recovery_windows = 3
	controller.profile.cooldown_windows = 1
	add_child(controller)
	binding = NucleusAdaptiveWorldWorkloadBinding.new()
	binding.controller = controller
	binding.background_queue = queue
	add_child(binding)
	_profile = NucleusTerrainProfile.new()
	_profile.resolution = 96
	_profile.size = Vector2(24, 24)
	_profile.height_scale = 5.0
	_profile.noise = FastNoiseLite.new()
	_profile.noise.seed = 1337
	_profile.collision_mode = NucleusTerrainProfile.CollisionMode.DISABLED
	var camera := Camera3D.new()
	camera.position = Vector3(23, 23, 28)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -20, 0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 16)
	canvas.add_child(panel)
	var start := Button.new()
	start.text = "Run real A/B workload + recovery"
	start.pressed.connect(run_comparison)
	panel.add_child(start)
	_label = Label.new()
	panel.add_child(_label)
	sampler.snapshot_sampled.connect(_show_sample)


func run_comparison() -> void:
	if running:
		return
	running = true
	report.clear()
	for adaptive: bool in [false, true]:
		_reset_phase()
		_phase = "Adaptive" if adaptive else "Baseline"
		if adaptive:
			binding.enable_binding()
		_refill = true
		for slot in range(4):
			_enqueue()
		await get_tree().create_timer(phase_seconds).timeout
		report[_phase.to_lower()] = _phase_report()
		_refill = false
		queue.cancel_all()
	_phase = "Recovery"
	_completed = 0
	_submitted = 0
	_minimum_scale = controller.get_suggested_scale()
	_phase_started_usec = Time.get_ticks_usec()
	# Keep the measured sequence and degraded policy alive while workload drains.
	await get_tree().create_timer(phase_seconds).timeout
	report["recovery"] = _phase_report()
	binding.disable_binding()
	_phase = "Complete"
	report["note"] = "Measured local workload, not a device benchmark or an FPS guarantee."
	var file := FileAccess.open("user://adaptive_measured_comparison.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	var destination: String = "user://adaptive_measured_comparison.json"
	if file == null:
		destination = "Report remains in memory; write failed: " + (
			error_string(FileAccess.get_open_error())
		)
	_label.text = "Complete: " + destination + "\n" + (
		"Compare p95 frame time, jobs completed and recovery; faster is not assumed."
	)
	running = false
	comparison_finished.emit(report)


func _reset_phase() -> void:
	_epoch += 1
	_phase_started_usec = Time.get_ticks_usec()
	_refill = false
	queue.cancel_all()
	binding.disable_binding()
	controller.reset_observation()
	sampler.clear_history()
	_completed = 0
	_submitted = 0
	_minimum_scale = 1.0


func _enqueue(expected_epoch: int = -1) -> void:
	if not _refill or (expected_epoch >= 0 and expected_epoch != _epoch):
		return
	var job := NucleusTerrainBuildJob.new()
	job.rows_per_step = 8
	job.configure(_profile, null, Vector3.ZERO, 1.0, false, 0, false, false)
	_submitted += 1
	job.completed.connect(_on_patch)
	queue.enqueue(job)


func _on_patch(result: Variant) -> void:
	var patch: Node3D = result["node"]
	if is_instance_valid(_preview):
		remove_child(_preview)
		_preview.queue_free()
	_preview = patch
	add_child(patch)
	_completed += 1
	call_deferred("_enqueue", _epoch)


func _phase_report() -> Dictionary:
	var measurement: Dictionary = sampler.build_report()
	var samples: Array = measurement["samples"]
	measurement["samples"] = samples.filter(func(sample: Dictionary) -> bool:
		return int(sample["timestamp_usec"]) >= _phase_started_usec
	)
	if _phase == "Recovery":
		# Aggregates span the retained adaptive history; expose only raw recovery windows.
		measurement.erase("summary")
		measurement.erase("metric_summary")
	return {
		"measurement": measurement, "completed_jobs": _completed,
		"submitted_jobs": _submitted, "minimum_recommended_scale": _minimum_scale,
		"final_recommended_scale": controller.get_suggested_scale(),
		"remaining_jobs": queue.get_pending_count(), "phase_seconds": phase_seconds,
	}


func _show_sample(sample: NucleusPerformanceSnapshot) -> void:
	_minimum_scale = minf(_minimum_scale, controller.get_suggested_scale())
	if _label == null or _phase == "Complete":
		return
	_label.text = "%s · actual terrain jobs: %d\nFPS %.1f · p95 %.1f ms · queue steps %d" % [
		_phase, _completed, sample.get_metric(NucleusPerformanceMetricIds.WINDOW_FPS),
		sample.get_metric(NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS),
		queue.max_steps_per_frame,
	]


func _exit_tree() -> void:
	_refill = false
	if is_instance_valid(queue):
		queue.cancel_all()
