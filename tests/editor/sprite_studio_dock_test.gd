extends SceneTree
## Editor-only UI regression harness; run with --headless --editor --script.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var dock_script := load("res://addons/nucleus_sprite_studio/studio_dock.gd") as Script
	var dock: VBoxContainer = dock_script.new()
	root.add_child(dock)
	await process_frame
	dock.call("_begin_progress", 2, "Regression test")
	_check(dock.get("_busy"), "Starting a job locks the dock.")
	var source: LineEdit = dock.get("_sequence_source")
	_check(not source.editable, "Source cannot change during a batch.")
	var progress: ProgressBar = dock.get("_progress")
	dock.call("_generate_sequences")
	_check(progress.max_value == 2, "A second job cannot replace the active progress.")
	dock.set("_cancel_requested", true)
	dock.call("_complete_progress", 0, 0, 0, 0)
	_check(not dock.get("_busy") and source.editable, "Completion unlocks the source.")
	var status: Label = dock.get("_status")
	_check(status.text.begins_with("CANCELLED"), "Cancellation has a truthful status.")
	var discovery: Array[Dictionary] = [{"id": "old", "clips": [], "frames": 1}]
	dock.set("_sequence_discovery", discovery)
	var preview: ItemList = dock.get("_sequence_preview")
	preview.add_item("Old group")
	source.text = "res://missing_source"
	source.text_changed.emit(source.text)
	_check(preview.item_count == 0, "Changing source clears stale preview rows.")
	_check((dock.get("_sequence_discovery") as Array).is_empty(),
		"Changing source invalidates the generation plan.")
	dock.queue_free()
	for frame in range(30):
		await process_frame
	print("Sprite Studio editor dock: %s (7 checks)." % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
