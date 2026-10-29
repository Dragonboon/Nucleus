class_name NucleusUpdateScheduler
extends Node
## Scene-owned scheduler for low-frequency work that should not align on one frame.
##
## Tasks declare a cadence. The scheduler spreads their initial phases, caps the
## number of callbacks dispatched per frame, and can also enforce a wall-clock
## callback budget. Missed intervals are skipped instead of replayed.

signal task_registered(token: int)
signal task_unregistered(token: int)
signal frame_budget_exhausted(executed_callbacks: int)

const Task = preload("res://addons/nucleus/components/gameplay/timing/update_scheduler_task.gd")

const AUTO_PHASE_STEP: float = 0.6180339887498949


enum ProcessCallback {
	IDLE,
	PHYSICS,
}

@export var active: bool = true:
	set(value):
		active = value
		if is_node_ready():
			_refresh_processing()

@export var process_callback: ProcessCallback = ProcessCallback.IDLE:
	set(value):
		process_callback = value
		if is_node_ready():
			_refresh_processing()

@export_group("Frame budget")
@export_range(1, 10000, 1, "or_greater")
var max_callbacks_per_frame: int = 32
@export_range(0, 100000, 50, "or_greater")
var frame_budget_usec: int = 1500

var _tasks: Array = []
var _clock_seconds: float = 0.0
var _next_token: int = 1
var _registration_sequence: int = 0
var _dispatching: bool = false
var _needs_sort: bool = false


func _ready() -> void:
	_refresh_processing()


func _process(delta: float) -> void:
	if process_callback == ProcessCallback.IDLE:
		_advance(delta)


func _physics_process(delta: float) -> void:
	if process_callback == ProcessCallback.PHYSICS:
		_advance(delta)


## Registers one callback. The callback receives elapsed seconds since its
## previous execution. phase < 0 chooses an automatic staggered phase.
func register_task(
	callback: Callable,
	interval: float,
	phase: float = -1.0,
	priority: int = 0,
) -> int:
	if not callback.is_valid() or interval <= 0.0:
		return -1

	var task: Task = Task.new()
	task.token = _next_token
	task.callback = callback
	task.interval = interval
	task.phase = _resolve_phase(phase)
	task.priority = priority
	task.enabled = true
	task.removed = false
	task.last_run = _clock_seconds
	task.next_due = _clock_seconds + interval * task.phase

	_next_token += 1
	_registration_sequence += 1
	_tasks.append(task)
	_needs_sort = true

	if not _dispatching:
		_sort_tasks()

	task_registered.emit(task.token)
	return task.token


func unregister_task(token: int) -> Error:
	var task: Task = _find_task(token)
	if task == null:
		return ERR_DOES_NOT_EXIST

	task.removed = true
	_needs_sort = true

	if not _dispatching:
		_prune_removed()
		_sort_tasks()

	task_unregistered.emit(token)
	return OK


func set_task_enabled(token: int, enabled: bool) -> Error:
	var task: Task = _find_task(token)
	if task == null:
		return ERR_DOES_NOT_EXIST

	if bool(task.enabled) == enabled:
		return OK

	task.enabled = enabled
	if enabled:
		task.last_run = _clock_seconds
		task.next_due = _clock_seconds + float(task.interval)
	else:
		task.next_due = INF

	_needs_sort = true
	if not _dispatching:
		_sort_tasks()
	return OK


## Makes an enabled task eligible on the next scheduler dispatch.
func request_task(token: int) -> Error:
	var task: Task = _find_task(token)
	if task == null:
		return ERR_DOES_NOT_EXIST
	if not bool(task.enabled):
		return ERR_UNAVAILABLE

	task.next_due = _clock_seconds
	_needs_sort = true
	if not _dispatching:
		_sort_tasks()
	return OK


func set_task_interval(
	token: int,
	interval: float,
	reset_phase: bool = false,
) -> Error:
	if interval <= 0.0:
		return ERR_INVALID_PARAMETER

	var task: Task = _find_task(token)
	if task == null:
		return ERR_DOES_NOT_EXIST

	task.interval = interval
	if reset_phase:
		task.next_due = _clock_seconds + interval * float(task.phase)
	elif bool(task.enabled):
		task.next_due = _clock_seconds + interval

	_needs_sort = true
	if not _dispatching:
		_sort_tasks()
	return OK


func get_task_count() -> int:
	var count: int = 0
	for raw_task: Variant in _tasks:
		var task: Task = raw_task as Task
		if task != null and not bool(task.removed):
			count += 1
	return count


func clear_tasks() -> void:
	_tasks.clear()
	_needs_sort = false


func _advance(delta: float) -> int:
	if not active:
		return 0

	_clock_seconds += maxf(delta, 0.0)

	if _needs_sort:
		_prune_removed()
		_sort_tasks()

	var started_at_usec: int = Time.get_ticks_usec()
	var executed: int = 0
	var index: int = 0
	var dispatch_size: int = _tasks.size()
	_dispatching = true

	while index < dispatch_size and index < _tasks.size():
		var task: Task = _tasks[index] as Task
		if task == null or bool(task.removed):
			index += 1
			continue

		if not bool(task.enabled):
			break

		if float(task.next_due) > _clock_seconds:
			break

		if not task.callback.is_valid():
			task.removed = true
			_needs_sort = true
			index += 1
			continue

		var elapsed: float = maxf(
			_clock_seconds - float(task.last_run),
			0.0,
		)
		task.last_run = _clock_seconds
		# Schedule from now instead of replaying missed ticks. This prevents a
		# delayed frame from creating a catch-up spiral.
		task.next_due = _clock_seconds + float(task.interval)
		task.callback.call(elapsed)
		executed += 1
		_needs_sort = true
		index += 1

		if executed >= max_callbacks_per_frame:
			if _has_due_task(index, dispatch_size):
				frame_budget_exhausted.emit(executed)
			break

		if (
			frame_budget_usec > 0
			and Time.get_ticks_usec() - started_at_usec >= frame_budget_usec
		):
			if _has_due_task(index, dispatch_size):
				frame_budget_exhausted.emit(executed)
			break

	_dispatching = false

	if _needs_sort:
		_prune_removed()
		_sort_tasks()

	return executed


func _has_due_task(start_index: int, dispatch_size: int) -> bool:
	var upper_bound: int = mini(dispatch_size, _tasks.size())
	for index: int in range(start_index, upper_bound):
		var task: Task = _tasks[index] as Task
		if task == null or bool(task.removed) or not bool(task.enabled):
			continue
		if float(task.next_due) <= _clock_seconds:
			return true
	return false


func _find_task(token: int) -> Task:
	for raw_task: Variant in _tasks:
		var task: Task = raw_task as Task
		if task != null and int(task.token) == token and not bool(task.removed):
			return task
	return null


func _resolve_phase(value: float) -> float:
	if value >= 0.0:
		return clampf(value, 0.0, 1.0)

	return fposmod(
		float(_registration_sequence) * AUTO_PHASE_STEP,
		1.0,
	)


func _prune_removed() -> void:
	for index: int in range(_tasks.size() - 1, -1, -1):
		var task: Task = _tasks[index] as Task
		if (
			task == null
			or bool(task.removed)
			or not task.callback.is_valid()
		):
			_tasks.remove_at(index)


func _sort_tasks() -> void:
	_tasks.sort_custom(Callable(self, "_task_before"))
	_needs_sort = false


func _task_before(first_raw: Variant, second_raw: Variant) -> bool:
	var first: Task = first_raw as Task
	var second: Task = second_raw as Task
	if first == null:
		return false
	if second == null:
		return true

	if bool(first.enabled) != bool(second.enabled):
		return bool(first.enabled)

	if not bool(first.enabled):
		return int(first.token) < int(second.token)

	var first_due: float = float(first.next_due)
	var second_due: float = float(second.next_due)
	if not is_equal_approx(first_due, second_due):
		return first_due < second_due

	if int(first.priority) != int(second.priority):
		return int(first.priority) > int(second.priority)

	return int(first.token) < int(second.token)


func _refresh_processing() -> void:
	set_process(active and process_callback == ProcessCallback.IDLE)
	set_physics_process(active and process_callback == ProcessCallback.PHYSICS)
