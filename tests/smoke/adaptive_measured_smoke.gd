extends Node
## Checks real workload completion and sampling, not hardware-dependent FPS improvements.
func _ready() -> void:
	var lab: Node = preload(
		"res://examples/adaptive_performance/adaptive_measured_lab.tscn"
	).instantiate()
	lab.phase_seconds = 1.0
	add_child(lab)
	lab.comparison_finished.connect(_finished.bind(lab))
	lab.run_comparison()


func _finished(report: Dictionary, lab: Node) -> void:
	var ok: bool = true
	for phase: String in ["baseline", "adaptive", "recovery"]:
		var data: Dictionary = report.get(phase, {})
		ok = ok and not data.is_empty()
		ok = ok and not (data.get("measurement", {}).get("samples", []) as Array).is_empty()
		if phase != "recovery":
			ok = ok and int(data.get("completed_jobs", 0)) > 0
	ok = ok and lab.queue.max_steps_per_frame == 16
	ok = ok and lab.queue.get_pending_count() == 0
	if ok:
		print("ADAPTIVE_MEASURED_SMOKE: PASS")
	else:
		push_error("ADAPTIVE_MEASURED_SMOKE: FAIL: missing measured windows, jobs or restoration")
	get_tree().quit(0 if ok else 1)
