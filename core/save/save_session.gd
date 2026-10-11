class_name NucleusSaveSession
extends Node
## Scene-owned game-state coordinator with configurable autosaving.
##
## Participants register explicit capture/restore Callables. The global storage
## service never scans SceneTree groups and never imports gameplay types.
## Example: register_participant(&"player", player.capture_state, player.restore_state).
## Capture freezes the callback set, not the game world. Only attached sessions
## listen for application autosave events; reentry resumes the same timer.

signal snapshot_saved(result: NucleusSaveResult)
signal snapshot_loaded(result: NucleusSaveResult)
signal autosave_skipped(reason: String)
signal snapshot_capture_started(total_participants: int)
signal snapshot_capture_progress(processed: int, total: int)
signal snapshot_capture_completed

@export var slot_id: String = "slot_1"
@export var autosave_policy: NucleusAutosavePolicy

var _participants: Dictionary[StringName, Dictionary] = {}
var _metadata_provider: Callable
var _pending_payload: Dictionary = {}

var _autosave_timer: Timer
var _last_autosave_msec: int = -1
var _saving: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if autosave_policy == null:
		autosave_policy = NucleusAutosavePolicy.new()

	if not is_instance_valid(_autosave_timer):
		_autosave_timer = Timer.new()
		_autosave_timer.name = "AutosaveTimer"
		_autosave_timer.one_shot = false
		_autosave_timer.ignore_time_scale = true
		_autosave_timer.process_callback = Timer.TIMER_PROCESS_IDLE
		_autosave_timer.timeout.connect(autosave)
		add_child(_autosave_timer)

	NucleusApp.application_paused.connect(_on_application_paused)
	NucleusApp.focus_changed.connect(_on_focus_changed)
	NucleusApp.quit_requested.connect(_on_quit_requested)

	_refresh_autosave_timer()


func _exit_tree() -> void:
	if is_instance_valid(_autosave_timer):
		_autosave_timer.stop()
	if is_instance_valid(NucleusApp):
		if NucleusApp.application_paused.is_connected(_on_application_paused):
			NucleusApp.application_paused.disconnect(_on_application_paused)
		if NucleusApp.focus_changed.is_connected(_on_focus_changed):
			NucleusApp.focus_changed.disconnect(_on_focus_changed)
		if NucleusApp.quit_requested.is_connected(_on_quit_requested):
			NucleusApp.quit_requested.disconnect(_on_quit_requested)
	request_ready()


func register_participant(
	participant_id: StringName,
	capture: Callable,
	restore: Callable = Callable(),
) -> Error:
	if participant_id == &"" or not capture.is_valid():
		return ERR_INVALID_PARAMETER

	_participants[participant_id] = {
		"capture": capture,
		"restore": restore,
	}

	if _pending_payload.has(String(participant_id)) and restore.is_valid():
		restore.call(_pending_payload[String(participant_id)])

	return OK


func unregister_participant(participant_id: StringName) -> void:
	_participants.erase(participant_id)


func set_metadata_provider(provider: Callable) -> void:
	_metadata_provider = provider


func set_slot_id(new_slot_id: String) -> Error:
	var normalized: String = NucleusSavePaths.sanitize_slot_id(
		new_slot_id
	)

	if normalized.is_empty():
		return ERR_INVALID_PARAMETER

	slot_id = normalized

	return OK


func save_manual(format: int = -1) -> NucleusSaveResult:
	var result: NucleusSaveResult = NucleusSave.save_manual(
		slot_id,
		capture_snapshot(),
		_capture_metadata(),
		format,
	)

	snapshot_saved.emit(result)

	return result


func save_quick(format: int = -1) -> NucleusSaveResult:
	var result: NucleusSaveResult = NucleusSave.save_quick(
		slot_id,
		capture_snapshot(),
		_capture_metadata(),
		format,
	)

	snapshot_saved.emit(result)

	return result


func autosave(force: bool = false) -> NucleusSaveResult:
	if _saving:
		return _skipped_result("save already in progress")

	if not autosave_policy.enabled:
		return _skipped_result("autosave disabled")

	if not force and not _autosave_interval_elapsed():
		return _skipped_result("minimum autosave interval not reached")

	_saving = true

	var result: NucleusSaveResult = NucleusSave.save_autosave(
		slot_id,
		capture_snapshot(),
		_capture_metadata(),
		autosave_policy.max_slots,
	)

	_saving = false

	if result.succeeded():
		_last_autosave_msec = Time.get_ticks_msec()

	snapshot_saved.emit(result)

	return result


func save_manual_incremental(
	participants_per_frame: int = 8,
	format: int = -1,
) -> NucleusSaveResult:
	var payload: Dictionary = await capture_snapshot_incremental(
		participants_per_frame
	)
	var result: NucleusSaveResult = NucleusSave.save_manual(
		slot_id,
		payload,
		_capture_metadata(),
		format,
	)

	snapshot_saved.emit(result)
	return result


func save_quick_incremental(
	participants_per_frame: int = 8,
	format: int = -1,
) -> NucleusSaveResult:
	var payload: Dictionary = await capture_snapshot_incremental(
		participants_per_frame
	)
	var result: NucleusSaveResult = NucleusSave.save_quick(
		slot_id,
		payload,
		_capture_metadata(),
		format,
	)

	snapshot_saved.emit(result)
	return result


func autosave_incremental(
	force: bool = false,
	participants_per_frame: int = 8,
	format: int = -1,
) -> NucleusSaveResult:
	if _saving:
		return _skipped_result("save already in progress")

	if not autosave_policy.enabled:
		return _skipped_result("autosave disabled")

	if not force and not _autosave_interval_elapsed():
		return _skipped_result("minimum autosave interval not reached")

	_saving = true
	var payload: Dictionary = await capture_snapshot_incremental(
		participants_per_frame
	)
	var result: NucleusSaveResult = NucleusSave.save_autosave(
		slot_id,
		payload,
		_capture_metadata(),
		autosave_policy.max_slots,
		format,
	)
	_saving = false

	if result.succeeded():
		_last_autosave_msec = Time.get_ticks_msec()

	snapshot_saved.emit(result)
	return result


func load_manual() -> NucleusSaveResult:
	var result: NucleusSaveResult = NucleusSave.load_manual(slot_id)

	if result.succeeded():
		apply_snapshot(result.document.payload)

	snapshot_loaded.emit(result)

	return result


func load_quick() -> NucleusSaveResult:
	var result: NucleusSaveResult = NucleusSave.load_quick(slot_id)

	if result.succeeded():
		apply_snapshot(result.document.payload)

	snapshot_loaded.emit(result)

	return result


func load_latest_autosave() -> NucleusSaveResult:
	var result: NucleusSaveResult = NucleusSave.load_latest_autosave(
		slot_id
	)

	if result.succeeded():
		apply_snapshot(result.document.payload)

	snapshot_loaded.emit(result)

	return result


func load_latest(
	kinds: PackedInt32Array = PackedInt32Array(),
) -> NucleusSaveResult:
	var result: NucleusSaveResult = NucleusSave.load_latest(
		slot_id,
		kinds,
	)

	if result.succeeded():
		apply_snapshot(result.document.payload)

	snapshot_loaded.emit(result)
	return result


func capture_snapshot() -> Dictionary:
	var job: NucleusSaveCaptureJob = create_capture_job()
	job.step(job.get_total_count())
	return job.take_snapshot()


func create_capture_job() -> NucleusSaveCaptureJob:
	return NucleusSaveCaptureJob.new(_participants)


func capture_snapshot_incremental(
	participants_per_frame: int = 8,
) -> Dictionary:
	var batch_size: int = maxi(participants_per_frame, 1)
	var job: NucleusSaveCaptureJob = create_capture_job()
	var total: int = job.get_total_count()

	snapshot_capture_started.emit(total)

	while not job.is_completed():
		job.step(batch_size)
		snapshot_capture_progress.emit(
			job.get_processed_count(),
			total,
		)

		if not job.is_completed() and is_inside_tree():
			await get_tree().process_frame

	var snapshot: Dictionary = job.take_snapshot()
	snapshot_capture_completed.emit()
	return snapshot


func apply_snapshot(payload: Dictionary) -> void:
	_pending_payload = payload.duplicate(true)

	for participant_id: StringName in _participants:
		var key: String = String(participant_id)

		if not _pending_payload.has(key):
			continue

		var participant: Dictionary = _participants[participant_id]
		var restore: Callable = participant["restore"]

		if restore.is_valid():
			restore.call(_pending_payload[key])


func refresh_autosave_policy() -> void:
	_refresh_autosave_timer()


func _capture_metadata() -> Dictionary:
	if not _metadata_provider.is_valid():
		return {}

	var value: Variant = _metadata_provider.call()

	return value if typeof(value) == TYPE_DICTIONARY else {}


func _refresh_autosave_timer() -> void:
	if not is_inside_tree() or not is_instance_valid(_autosave_timer):
		return
	if autosave_policy == null or not autosave_policy.enabled:
		_autosave_timer.stop()
		return

	_autosave_timer.wait_time = maxf(
		1.0,
		autosave_policy.interval_seconds,
	)
	_autosave_timer.start()


func _autosave_interval_elapsed() -> bool:
	if _last_autosave_msec < 0:
		return true

	var elapsed_seconds: float = (
		Time.get_ticks_msec() - _last_autosave_msec
	) / 1000.0

	return (
		elapsed_seconds
		>= autosave_policy.minimum_interval_seconds
	)


func _skipped_result(reason: String) -> NucleusSaveResult:
	var result := NucleusSaveResult.new()
	result.error = ERR_BUSY

	autosave_skipped.emit(reason)

	return result


func _on_application_paused() -> void:
	if autosave_policy.save_on_application_pause:
		autosave(true)


func _on_focus_changed(is_focused: bool) -> void:
	if (
		not is_focused
		and autosave_policy.save_on_focus_lost
	):
		autosave()


func _on_quit_requested(_exit_code: int) -> void:
	if autosave_policy.save_on_application_quit:
		autosave(true)
