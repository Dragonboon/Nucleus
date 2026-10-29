class_name NucleusSceneFlowService
extends Node
## Cross-scene loading, preflight, presentation, and replacement coordination.
##
## Scene Flow owns sequencing, not game state. Visual transitions are optional
## NucleusSceneTransitionProfile resources and remain replaceable by a custom
## NucleusSceneTransitionOverlay scene.

signal transition_started(from_scene: String, to_scene: String)
signal load_progress(scene_path: String, progress: float)
signal transition_completed(scene_path: String, scene: Node)
signal transition_finished(scene_path: String, scene: Node)
signal transition_failed(scene_path: String, error: Error)
signal transition_failed_detailed(details: Dictionary)
signal transition_visual_failed(
	scene_path: String,
	phase: StringName,
	error: Error,
)
signal rollback_started(failed_scene_path: String, rollback_scene_path: String)
signal rollback_completed(
	failed_scene_path: String,
	rollback_scene_path: String,
	scene: Node,
)
signal rollback_failed(
	failed_scene_path: String,
	rollback_scene_path: String,
	error: Error,
)
signal busy_changed(is_busy: bool)

enum State {
	IDLE,
	LOADING,
	COVERING,
	SWITCHING,
	REVEALING,
	RECOVERING,
	ROLLING_BACK,
}

enum FailureStage {
	NONE,
	VALIDATION,
	LOAD_REQUEST,
	LOAD,
	INSTANTIATION,
	PRESENTATION,
	SWITCH,
	SWITCH_TIMEOUT,
	ROLLBACK,
}

const LOG_CONTEXT: StringName = &"SceneFlow"

var state: State = State.IDLE
var default_transition_profile: NucleusSceneTransitionProfile
var switch_timeout_seconds: float = 10.0

var _pending_scene_path: String = ""
var _previous_scene_path: String = ""
var _rollback_scene_path: String = ""
var _return_scene_path: String = ""
var _progress: float = 0.0
var _pending_scene_instance: Node
var _switch_target: Node
var _rollback_target: Node
var _transition_profile: NucleusSceneTransitionProfile
var _transition_overlay: NucleusSceneTransitionOverlay
var _threaded_loading: bool = false
var _load_ready: bool = false
var _cover_ready: bool = true
var _cover_started_usec: int = 0
var _phase_started_usec: int = 0
var _last_failure: Dictionary = {}
var _failure_emitted: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(_delta: float) -> void:
	if _threaded_loading:
		_poll_threaded_load()

	if (
		_transition_overlay != null
		and not _cover_ready
		and _presentation_timed_out()
	):
		_fail_before_switch(
			ERR_TIMEOUT,
			FailureStage.PRESENTATION,
		)
		return

	if state == State.SWITCHING and _phase_timed_out(switch_timeout_seconds):
		_resolve_switch_timeout()
		return

	if (
		state == State.REVEALING
		and _phase_timed_out(_transition_profile.presentation_timeout_seconds)
	):
		transition_visual_failed.emit(
			_pending_scene_path,
			&"reveal",
			ERR_TIMEOUT,
		)
		_finish_success()
		return

	if (
		state == State.RECOVERING
		and _phase_timed_out(_transition_profile.presentation_timeout_seconds)
	):
		_finish_failure_cleanup()
		return

	if state == State.ROLLING_BACK and _phase_timed_out(switch_timeout_seconds):
		if get_tree().current_scene == _rollback_target:
			_disconnect_scene_changed(_on_rollback_scene_changed)
			_on_rollback_scene_changed()
		else:
			_fail_rollback(ERR_TIMEOUT)


## Changes to a PackedScene resource path.
##
## The target is loaded and instantiated before SceneTree removes the current
## scene. This keeps ordinary load/parse/instantiation failures transactional.
func change_scene(
	scene_path: String,
	background_loading: bool = true,
	use_sub_threads: bool = false,
	transition: NucleusSceneTransitionProfile = null,
	fallback_scene_path: String = "",
) -> Error:
	var validation_error := _validate_request(
		scene_path,
		transition,
		fallback_scene_path,
	)

	if validation_error != OK:
		_record_admission_failure(
			scene_path,
			validation_error,
			fallback_scene_path,
		)
		return validation_error

	var profile := _resolve_transition_profile(transition)
	_begin_transition(
		scene_path,
		profile,
		fallback_scene_path,
	)

	var presentation_error := _start_presentation()
	if presentation_error != OK:
		_fail_before_switch(
			presentation_error,
			FailureStage.PRESENTATION,
		)
		return presentation_error

	if background_loading and NucleusPlatform.supports_threads():
		var request_error: Error = ResourceLoader.load_threaded_request(
			scene_path,
			"PackedScene",
			use_sub_threads,
		)

		if request_error != OK:
			_fail_before_switch(
				request_error,
				FailureStage.LOAD_REQUEST,
			)
			return request_error

		_threaded_loading = true
		_refresh_pre_switch_state()
		_update_processing()
		return OK

	var resource: Resource = ResourceLoader.load(
		scene_path,
		"PackedScene",
	)
	var load_error := _accept_loaded_resource(resource)

	if load_error != OK:
		var failure_stage := (
			FailureStage.INSTANTIATION
			if load_error == ERR_CANT_CREATE
			else FailureStage.LOAD
		)
		_fail_before_switch(load_error, failure_stage)
		return load_error

	_try_switch()
	return OK


## Changes to an already loaded PackedScene after instantiating it as preflight.
func change_scene_to_packed(
	scene: PackedScene,
	scene_path: String = "",
	transition: NucleusSceneTransitionProfile = null,
	fallback_scene_path: String = "",
) -> Error:
	if is_busy():
		return ERR_BUSY

	if scene == null:
		return ERR_INVALID_PARAMETER

	var profile := _resolve_transition_profile(transition)
	if profile != null and not profile.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER

	var resolved_path := scene_path
	if resolved_path.is_empty():
		resolved_path = scene.resource_path

	if not fallback_scene_path.is_empty():
		if not _is_valid_scene_path(fallback_scene_path):
			return ERR_INVALID_PARAMETER
		if not ResourceLoader.exists(fallback_scene_path):
			return ERR_FILE_NOT_FOUND

	_begin_transition(
		resolved_path,
		profile,
		fallback_scene_path,
	)

	var presentation_error := _start_presentation()
	if presentation_error != OK:
		_fail_before_switch(
			presentation_error,
			FailureStage.PRESENTATION,
		)
		return presentation_error

	var preparation_error := _prepare_packed_scene(scene)
	if preparation_error != OK:
		_fail_before_switch(
			preparation_error,
			FailureStage.INSTANTIATION,
		)
		return preparation_error

	_set_progress(1.0)
	_try_switch()
	return OK


## Reloads the current scene through the same preflight/transition pipeline.
func reload_current_scene(
	transition: NucleusSceneTransitionProfile = null,
) -> Error:
	if is_busy():
		return ERR_BUSY

	var current_path := get_current_scene_path()
	if current_path.is_empty():
		return ERR_UNCONFIGURED

	return change_scene(
		current_path,
		true,
		false,
		transition,
		current_path,
	)


## Returns to the file-backed scene active before the last successful change.
## Runtime-only state from that former instance is not restored.
func return_to_previous_scene(
	transition: NucleusSceneTransitionProfile = null,
) -> Error:
	if _return_scene_path.is_empty():
		return ERR_DOES_NOT_EXIST

	return change_scene(
		_return_scene_path,
		true,
		false,
		transition,
	)


## Bypasses default_transition_profile for an intentionally direct change.
func change_scene_direct(
	scene_path: String,
	background_loading: bool = true,
	use_sub_threads: bool = false,
) -> Error:
	var saved_default := default_transition_profile
	default_transition_profile = null
	var error := change_scene(
		scene_path,
		background_loading,
		use_sub_threads,
	)
	default_transition_profile = saved_default
	return error


func is_busy() -> bool:
	return state != State.IDLE


func get_progress() -> float:
	return _progress


func get_current_scene_path() -> String:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return ""

	return current_scene.scene_file_path


func get_previous_scene_path() -> String:
	return _return_scene_path


func get_last_failure() -> Dictionary:
	return _last_failure.duplicate(true)


func clear_last_failure() -> void:
	_last_failure.clear()


func _record_admission_failure(
	scene_path: String,
	error: Error,
	fallback_scene_path: String,
) -> void:
	_last_failure = {
		"scene_path": scene_path,
		"previous_scene_path": get_current_scene_path(),
		"rollback_scene_path": fallback_scene_path,
		"stage": FailureStage.VALIDATION,
		"stage_name": _failure_stage_name(FailureStage.VALIDATION),
		"error": error,
		"error_name": error_string(error),
	}


func _validate_request(
	scene_path: String,
	transition: NucleusSceneTransitionProfile,
	fallback_scene_path: String,
) -> Error:
	if is_busy():
		return ERR_BUSY

	if not _is_valid_scene_path(scene_path):
		return ERR_INVALID_PARAMETER

	if not ResourceLoader.exists(scene_path):
		return ERR_FILE_NOT_FOUND

	if not fallback_scene_path.is_empty():
		if not _is_valid_scene_path(fallback_scene_path):
			return ERR_INVALID_PARAMETER
		if not ResourceLoader.exists(fallback_scene_path):
			return ERR_FILE_NOT_FOUND

	var profile := _resolve_transition_profile(transition)
	if profile != null and not profile.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER

	return OK


func _resolve_transition_profile(
	transition: NucleusSceneTransitionProfile,
) -> NucleusSceneTransitionProfile:
	return (
		transition
		if transition != null
		else default_transition_profile
	)


func _begin_transition(
	scene_path: String,
	profile: NucleusSceneTransitionProfile,
	fallback_scene_path: String,
) -> void:
	_pending_scene_path = scene_path
	_previous_scene_path = get_current_scene_path()
	_rollback_scene_path = (
		fallback_scene_path
		if not fallback_scene_path.is_empty()
		else _previous_scene_path
	)
	_transition_profile = profile
	_progress = 0.0
	_load_ready = false
	_cover_ready = profile == null
	_cover_started_usec = 0
	_phase_started_usec = Time.get_ticks_usec()
	_failure_emitted = false
	_pending_scene_instance = null
	_switch_target = null
	_rollback_target = null
	_last_failure.clear()

	transition_started.emit(
		_previous_scene_path,
		_pending_scene_path,
	)
	_set_progress(0.0)
	_refresh_pre_switch_state()


func _start_presentation() -> Error:
	if _transition_profile == null:
		_cover_ready = true
		return OK

	var overlay: Node
	if _transition_profile.overlay_scene != null:
		overlay = _transition_profile.overlay_scene.instantiate()
	else:
		overlay = NucleusSceneTransitionOverlay.new()

	if not overlay is NucleusSceneTransitionOverlay:
		if overlay != null:
			overlay.free()
		return ERR_INVALID_DATA

	_transition_overlay = overlay as NucleusSceneTransitionOverlay
	_transition_overlay.configure(_transition_profile)
	_transition_overlay.covered.connect(
		_on_overlay_covered,
		CONNECT_ONE_SHOT,
	)
	_transition_overlay.revealed.connect(_on_overlay_revealed)
	get_tree().root.add_child(_transition_overlay)
	_cover_started_usec = Time.get_ticks_usec()

	var error := _transition_overlay.begin_cover()
	_update_processing()
	return error


func _poll_threaded_load() -> void:
	if _pending_scene_path.is_empty():
		_threaded_loading = false
		_update_processing()
		return

	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = (
		ResourceLoader.load_threaded_get_status(
			_pending_scene_path,
			progress,
		)
	)

	if not progress.is_empty():
		_set_progress(float(progress[0]))

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_threaded_loading = false
			var resource := ResourceLoader.load_threaded_get(
				_pending_scene_path
			)
			var error := _accept_loaded_resource(resource)
			if error != OK:
				var failure_stage := (
					FailureStage.INSTANTIATION
					if error == ERR_CANT_CREATE
					else FailureStage.LOAD
				)
				_fail_before_switch(error, failure_stage)
				return
			_try_switch()
		ResourceLoader.THREAD_LOAD_FAILED:
			_threaded_loading = false
			_fail_before_switch(
				ERR_FILE_CANT_OPEN,
				FailureStage.LOAD,
			)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_threaded_loading = false
			_fail_before_switch(
				ERR_FILE_UNRECOGNIZED,
				FailureStage.LOAD,
			)


func _accept_loaded_resource(resource: Resource) -> Error:
	if not resource is PackedScene:
		return ERR_FILE_UNRECOGNIZED

	var error := _prepare_packed_scene(resource as PackedScene)
	if error != OK:
		return error

	_set_progress(1.0)
	return OK


func _prepare_packed_scene(scene: PackedScene) -> Error:
	if scene == null or not scene.can_instantiate():
		return ERR_CANT_CREATE

	var instance: Node = scene.instantiate()
	if instance == null:
		return ERR_CANT_CREATE

	_pending_scene_instance = instance
	_load_ready = true
	_refresh_pre_switch_state()
	return OK


func _try_switch() -> void:
	if not _load_ready or not _cover_ready:
		_refresh_pre_switch_state()
		return

	if _pending_scene_instance == null:
		_fail_before_switch(
			ERR_CANT_CREATE,
			FailureStage.INSTANTIATION,
		)
		return

	_threaded_loading = false
	_switch_target = _pending_scene_instance
	_set_state(State.SWITCHING)
	_phase_started_usec = Time.get_ticks_usec()
	_connect_scene_changed(_on_scene_changed)

	var error := get_tree().change_scene_to_node(_switch_target)
	if error != OK:
		_disconnect_scene_changed(_on_scene_changed)
		_handle_switch_error(error, FailureStage.SWITCH)
		return

	_update_processing()


func _handle_switch_error(error: Error, stage: FailureStage) -> void:
	if get_tree().current_scene == null:
		_start_rollback(error, stage)
		return

	_fail_before_switch(error, stage)


func _resolve_switch_timeout() -> void:
	if get_tree().current_scene == _switch_target:
		_disconnect_scene_changed(_on_scene_changed)
		_on_scene_changed()
		return

	_handle_switch_error(
		ERR_TIMEOUT,
		FailureStage.SWITCH_TIMEOUT,
	)


func _on_scene_changed() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		_start_rollback(
			ERR_CANT_CREATE,
			FailureStage.SWITCH,
		)
		return

	var completed_path := _pending_scene_path
	_return_scene_path = _previous_scene_path
	_pending_scene_instance = null
	_switch_target = null
	transition_completed.emit(completed_path, current_scene)

	if _transition_overlay == null:
		_finish_success()
		return

	_set_state(State.REVEALING)
	_phase_started_usec = Time.get_ticks_usec()
	var error := _transition_overlay.begin_reveal()
	if error != OK:
		transition_visual_failed.emit(
			completed_path,
			&"reveal",
			error,
		)
		_finish_success()
		return

	_update_processing()


func _on_overlay_covered() -> void:
	_cover_ready = true
	_refresh_pre_switch_state()
	_try_switch()


func _on_overlay_revealed() -> void:
	match state:
		State.REVEALING:
			_finish_success()
		State.RECOVERING:
			_finish_failure_cleanup()
		_:
			pass


func _fail_before_switch(
	error: Error,
	stage: FailureStage,
) -> void:
	_record_failure(error, stage)
	_free_pending_scene_instance()
	_threaded_loading = false
	_disconnect_scene_changed(_on_scene_changed)

	if _transition_overlay == null:
		_finish_failure_cleanup()
		return

	_set_state(State.RECOVERING)
	_phase_started_usec = Time.get_ticks_usec()
	var reveal_error := _transition_overlay.begin_reveal()
	if reveal_error != OK:
		transition_visual_failed.emit(
			_pending_scene_path,
			&"recovery",
			reveal_error,
		)
		_finish_failure_cleanup()
		return

	_update_processing()


func _start_rollback(error: Error, stage: FailureStage) -> void:
	_record_failure(error, stage)
	_free_pending_scene_instance()
	_threaded_loading = false
	_disconnect_scene_changed(_on_scene_changed)

	if (
		_rollback_scene_path.is_empty()
		or not ResourceLoader.exists(_rollback_scene_path)
	):
		_fail_rollback(ERR_FILE_NOT_FOUND)
		return

	rollback_started.emit(
		_pending_scene_path,
		_rollback_scene_path,
	)

	var resource := ResourceLoader.load(
		_rollback_scene_path,
		"PackedScene",
	)
	if not resource is PackedScene:
		_fail_rollback(ERR_FILE_UNRECOGNIZED)
		return

	var packed := resource as PackedScene
	if not packed.can_instantiate():
		_fail_rollback(ERR_CANT_CREATE)
		return

	var instance := packed.instantiate()
	if instance == null:
		_fail_rollback(ERR_CANT_CREATE)
		return

	_set_state(State.ROLLING_BACK)
	_phase_started_usec = Time.get_ticks_usec()
	_connect_scene_changed(_on_rollback_scene_changed)

	_rollback_target = instance
	var rollback_error := get_tree().change_scene_to_node(instance)
	if rollback_error != OK:
		_disconnect_scene_changed(_on_rollback_scene_changed)
		if not instance.is_inside_tree():
			instance.free()
		_fail_rollback(rollback_error)
		return

	_update_processing()


func _on_rollback_scene_changed() -> void:
	var current_scene := get_tree().current_scene
	_rollback_target = null
	rollback_completed.emit(
		_pending_scene_path,
		_rollback_scene_path,
		current_scene,
	)

	if _transition_overlay == null:
		_finish_failure_cleanup()
		return

	_set_state(State.RECOVERING)
	_phase_started_usec = Time.get_ticks_usec()
	var error := _transition_overlay.begin_reveal()
	if error != OK:
		transition_visual_failed.emit(
			_pending_scene_path,
			&"rollback_reveal",
			error,
		)
		_finish_failure_cleanup()
		return

	_update_processing()


func _fail_rollback(error: Error) -> void:
	_disconnect_scene_changed(_on_rollback_scene_changed)
	_rollback_target = null
	_last_failure["rollback_error"] = error
	_last_failure["rollback_error_name"] = error_string(error)
	rollback_failed.emit(
		_pending_scene_path,
		_rollback_scene_path,
		error,
	)
	_finish_failure_cleanup()


func _record_failure(error: Error, stage: FailureStage) -> void:
	if _failure_emitted:
		return

	_failure_emitted = true
	_last_failure = {
		"scene_path": _pending_scene_path,
		"previous_scene_path": _previous_scene_path,
		"rollback_scene_path": _rollback_scene_path,
		"stage": stage,
		"stage_name": _failure_stage_name(stage),
		"error": error,
		"error_name": error_string(error),
	}

	NucleusLog.error(
		"Scene transition failed for '%s' during %s: %s"
		% [
			_pending_scene_path,
			_failure_stage_name(stage),
			error_string(error),
		],
		LOG_CONTEXT,
	)
	transition_failed.emit(_pending_scene_path, error)
	transition_failed_detailed.emit(_last_failure.duplicate(true))


func _finish_success() -> void:
	var completed_path := _pending_scene_path
	var current_scene := get_tree().current_scene
	_cleanup_transition_overlay()
	_reset_active_transition()
	_set_state(State.IDLE)
	transition_finished.emit(completed_path, current_scene)


func _finish_failure_cleanup() -> void:
	_cleanup_transition_overlay()
	_reset_active_transition()
	_set_state(State.IDLE)


func _reset_active_transition() -> void:
	set_process(false)
	_pending_scene_path = ""
	_previous_scene_path = ""
	_rollback_scene_path = ""
	_progress = 0.0
	_pending_scene_instance = null
	_switch_target = null
	_rollback_target = null
	_transition_profile = null
	_threaded_loading = false
	_load_ready = false
	_cover_ready = true
	_cover_started_usec = 0
	_phase_started_usec = 0
	_failure_emitted = false


func _cleanup_transition_overlay() -> void:
	if _transition_overlay == null:
		return

	_transition_overlay.cancel_animation()
	if is_instance_valid(_transition_overlay):
		_transition_overlay.queue_free()
	_transition_overlay = null


func _free_pending_scene_instance() -> void:
	if _pending_scene_instance == null:
		return

	if is_instance_valid(_pending_scene_instance):
		if _pending_scene_instance.is_inside_tree():
			_pending_scene_instance.queue_free()
		else:
			_pending_scene_instance.free()

	_pending_scene_instance = null
	_switch_target = null


func _refresh_pre_switch_state() -> void:
	if _load_ready and _cover_ready:
		return

	if not _load_ready:
		_set_state(State.LOADING)
	else:
		_set_state(State.COVERING)

	_update_processing()


func _connect_scene_changed(callback: Callable) -> void:
	_disconnect_scene_changed(callback)
	get_tree().scene_changed.connect(callback, CONNECT_ONE_SHOT)


func _disconnect_scene_changed(callback: Callable) -> void:
	if get_tree().scene_changed.is_connected(callback):
		get_tree().scene_changed.disconnect(callback)


func _set_progress(value: float) -> void:
	var normalized_progress := clampf(value, 0.0, 1.0)

	if is_equal_approx(normalized_progress, _progress) and value != 0.0:
		return

	_progress = normalized_progress
	load_progress.emit(_pending_scene_path, _progress)


func _set_state(new_state: State) -> void:
	var was_busy := is_busy()
	state = new_state
	var now_busy := is_busy()

	if was_busy != now_busy:
		busy_changed.emit(now_busy)


func _update_processing() -> void:
	set_process(
		_threaded_loading
		or not _cover_ready
		or state in [
			State.SWITCHING,
			State.REVEALING,
			State.RECOVERING,
			State.ROLLING_BACK,
		]
	)


func _presentation_timed_out() -> bool:
	if _transition_profile == null or _cover_started_usec <= 0:
		return false

	return _elapsed_seconds(_cover_started_usec) > (
		_transition_profile.presentation_timeout_seconds
	)


func _phase_timed_out(timeout_seconds: float) -> bool:
	if timeout_seconds <= 0.0 or _phase_started_usec <= 0:
		return false

	return _elapsed_seconds(_phase_started_usec) > timeout_seconds


func _elapsed_seconds(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000000.0


func _is_valid_scene_path(scene_path: String) -> bool:
	return (
		not scene_path.is_empty()
		and scene_path.begins_with("res://")
	)


func _failure_stage_name(stage: FailureStage) -> String:
	match stage:
		FailureStage.VALIDATION:
			return "validation"
		FailureStage.LOAD_REQUEST:
			return "load_request"
		FailureStage.LOAD:
			return "load"
		FailureStage.INSTANTIATION:
			return "instantiation"
		FailureStage.PRESENTATION:
			return "presentation"
		FailureStage.SWITCH:
			return "switch"
		FailureStage.SWITCH_TIMEOUT:
			return "switch_timeout"
		FailureStage.ROLLBACK:
			return "rollback"
		_:
			return "none"
