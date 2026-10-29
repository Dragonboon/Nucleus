class_name NucleusUIResourceLoadBinding
extends Node
## Projects one scene-owned ResourceLoadQueue into arbitrary loading Controls.
##
## The binding does not decide visibility, transitions, retry policy, or failure
## UX. Those remain owned by the consuming UI/coordinator.

signal loading_started(total_items: int)
signal loading_finished(state: int)

@export var source: NucleusResourceLoadQueue

@export_group("Progress")
@export var progress_feedback: NucleusUIProgressFeedback
@export var progress_target: Range
@export var animate_progress: bool = false
## When enabled, multiple progress signals in one message-queue burst apply only
## the latest value. Lifecycle start/finish updates remain immediate.
@export var coalesce_progress_updates: bool = false

@export_group("Optional text")
@export var count_label: Label
@export var item_label: Label
@export var count_template: String = "{processed} / {total}"
@export var clear_item_on_finish: bool = false

var _progress_flush_pending: bool = false
var _pending_progress: float = 0.0
var _pending_processed: int = 0
var _pending_total: int = 0


func _ready() -> void:
	if source == null:
		source = get_parent() as NucleusResourceLoadQueue

	if source == null:
		NucleusLog.error(
			"%s requires a NucleusResourceLoadQueue source." % get_path(),
			&"UIResourceLoadBinding",
		)
		return

	if not _has_presentation_target():
		NucleusLog.error(
			"%s requires at least one loading presentation target." % get_path(),
			&"UIResourceLoadBinding",
		)
		return

	_connect_source()
	refresh()


func _exit_tree() -> void:
	_progress_flush_pending = false
	_disconnect_source()


func bind(queue: NucleusResourceLoadQueue) -> Error:
	if queue == null:
		return ERR_INVALID_PARAMETER

	_disconnect_source()
	source = queue
	_progress_flush_pending = false

	if is_inside_tree():
		_connect_source()
		refresh()

	return OK


func refresh() -> Error:
	if source == null:
		return ERR_UNCONFIGURED

	_apply_progress(
		source.get_progress(),
		source.get_processed_count(),
		source.get_total_count(),
	)
	return OK


func _has_presentation_target() -> bool:
	return (
		progress_feedback != null
		or progress_target != null
		or count_label != null
		or item_label != null
	)


func _connect_source() -> void:
	if not source.batch_started.is_connected(_on_batch_started):
		source.batch_started.connect(_on_batch_started)

	if not source.progress_changed.is_connected(_on_progress_changed):
		source.progress_changed.connect(_on_progress_changed)

	if not source.item_started.is_connected(_on_item_started):
		source.item_started.connect(_on_item_started)

	if not source.batch_completed.is_connected(_on_batch_completed):
		source.batch_completed.connect(_on_batch_completed)

	if not source.batch_failed.is_connected(_on_batch_failed):
		source.batch_failed.connect(_on_batch_failed)

	if not source.batch_cancelled.is_connected(_on_batch_cancelled):
		source.batch_cancelled.connect(_on_batch_cancelled)


func _disconnect_source() -> void:
	if source == null or not is_instance_valid(source):
		return

	if source.batch_started.is_connected(_on_batch_started):
		source.batch_started.disconnect(_on_batch_started)

	if source.progress_changed.is_connected(_on_progress_changed):
		source.progress_changed.disconnect(_on_progress_changed)

	if source.item_started.is_connected(_on_item_started):
		source.item_started.disconnect(_on_item_started)

	if source.batch_completed.is_connected(_on_batch_completed):
		source.batch_completed.disconnect(_on_batch_completed)

	if source.batch_failed.is_connected(_on_batch_failed):
		source.batch_failed.disconnect(_on_batch_failed)

	if source.batch_cancelled.is_connected(_on_batch_cancelled):
		source.batch_cancelled.disconnect(_on_batch_cancelled)


func _apply_progress(
	progress: float,
	processed: int,
	total: int,
) -> void:
	var ratio := clampf(progress, 0.0, 1.0)

	if progress_feedback:
		progress_feedback.set_ratio(ratio, animate_progress)
	elif progress_target:
		progress_target.value = lerpf(
			progress_target.min_value,
			progress_target.max_value,
			ratio,
		)

	if count_label:
		count_label.text = count_template.replace(
			"{processed}",
			str(processed),
		).replace(
			"{total}",
			str(total),
		)


func _queue_progress(
	progress: float,
	processed: int,
	total: int,
) -> void:
	_pending_progress = progress
	_pending_processed = processed
	_pending_total = total

	if _progress_flush_pending:
		return

	_progress_flush_pending = true
	call_deferred("_flush_pending_progress")


func _flush_pending_progress() -> void:
	if not _progress_flush_pending:
		return

	_progress_flush_pending = false
	_apply_progress(
		_pending_progress,
		_pending_processed,
		_pending_total,
	)


func _on_batch_started(
	_plan: NucleusLoadPlan,
	total_items: int,
) -> void:
	_progress_flush_pending = false
	_apply_progress(0.0, 0, total_items)

	if item_label:
		item_label.text = ""

	loading_started.emit(total_items)


func _on_progress_changed(
	progress: float,
	processed_items: int,
	total_items: int,
) -> void:
	if coalesce_progress_updates:
		_queue_progress(
			progress,
			processed_items,
			total_items,
		)
		return

	_apply_progress(
		progress,
		processed_items,
		total_items,
	)


func _on_item_started(entry: NucleusLoadEntry) -> void:
	if item_label:
		item_label.text = entry.get_display_name()


func _on_batch_completed(_plan: NucleusLoadPlan) -> void:
	_finish_presentation()


func _on_batch_failed(
	_plan: NucleusLoadPlan,
	_failures: Array[Dictionary],
) -> void:
	_finish_presentation()


func _on_batch_cancelled(_plan: NucleusLoadPlan) -> void:
	_finish_presentation()


func _finish_presentation() -> void:
	_progress_flush_pending = false
	refresh()

	if clear_item_on_finish and item_label:
		item_label.text = ""

	loading_finished.emit(source.state)
