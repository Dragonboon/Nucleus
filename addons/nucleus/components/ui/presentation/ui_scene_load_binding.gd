class_name NucleusUISceneLoadBinding
extends Node
## Projects NucleusSceneFlow load progress into one scene-owned UI target.
##
## Visibility, destination labels, failure copy, and transition art remain
## game-owned. The binding only adapts SceneFlow's public progress lifecycle.

signal loading_started(scene_path: String)
signal loading_finished(scene_path: String, succeeded: bool)

@export var progress_feedback: NucleusUIProgressFeedback
@export var progress_target: Range
@export var animate_progress: bool = false
@export var reset_after_finish: bool = false


func _ready() -> void:
	if progress_feedback == null and progress_target == null:
		NucleusLog.error(
			"%s requires a progress feedback component or Range." % get_path(),
			&"UISceneLoadBinding",
		)
		return

	NucleusSceneFlow.transition_started.connect(_on_transition_started)
	NucleusSceneFlow.load_progress.connect(_on_load_progress)
	NucleusSceneFlow.transition_finished.connect(_on_transition_finished)
	NucleusSceneFlow.transition_failed.connect(_on_transition_failed)
	refresh()


func _exit_tree() -> void:
	if NucleusSceneFlow.transition_started.is_connected(_on_transition_started):
		NucleusSceneFlow.transition_started.disconnect(_on_transition_started)

	if NucleusSceneFlow.load_progress.is_connected(_on_load_progress):
		NucleusSceneFlow.load_progress.disconnect(_on_load_progress)

	if NucleusSceneFlow.transition_finished.is_connected(_on_transition_finished):
		NucleusSceneFlow.transition_finished.disconnect(_on_transition_finished)

	if NucleusSceneFlow.transition_failed.is_connected(_on_transition_failed):
		NucleusSceneFlow.transition_failed.disconnect(_on_transition_failed)


func refresh() -> void:
	_apply_progress(NucleusSceneFlow.get_progress(), false)


func _apply_progress(
	progress: float,
	animated: bool,
) -> void:
	var ratio := clampf(progress, 0.0, 1.0)

	if progress_feedback:
		progress_feedback.set_ratio(ratio, animated)
	elif progress_target:
		progress_target.value = lerpf(
			progress_target.min_value,
			progress_target.max_value,
			ratio,
		)


func _on_transition_started(
	_from_scene: String,
	to_scene: String,
) -> void:
	_apply_progress(0.0, false)
	loading_started.emit(to_scene)


func _on_load_progress(
	_scene_path: String,
	progress: float,
) -> void:
	_apply_progress(progress, animate_progress)


func _on_transition_finished(
	scene_path: String,
	_scene: Node,
) -> void:
	_apply_progress(1.0, false)
	loading_finished.emit(scene_path, true)

	if reset_after_finish:
		_apply_progress(0.0, false)


func _on_transition_failed(
	scene_path: String,
	_error: Error,
) -> void:
	loading_finished.emit(scene_path, false)

	if reset_after_finish:
		_apply_progress(0.0, false)
