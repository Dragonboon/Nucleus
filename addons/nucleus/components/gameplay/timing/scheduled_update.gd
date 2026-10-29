class_name NucleusScheduledUpdate
extends Node
## Inspector-friendly adapter for one NucleusUpdateScheduler task.

signal tick(elapsed: float)

@export var scheduler: NucleusUpdateScheduler
@export_range(0.001, 3600.0, 0.001, "or_greater")
var interval: float = 0.25
@export_range(-1.0, 1.0, 0.001)
var phase: float = -1.0
@export var priority: int = 0
@export var start_enabled: bool = true

var _token: int = -1


func _ready() -> void:
	if scheduler == null:
		scheduler = _find_scheduler_ancestor()

	if scheduler == null:
		NucleusLog.error(
			"%s requires a NucleusUpdateScheduler." % get_path(),
			&"ScheduledUpdate",
		)
		return

	_token = scheduler.register_task(
		Callable(self, "_on_scheduler_tick"),
		interval,
		phase,
		priority,
	)

	if _token != -1 and not start_enabled:
		scheduler.set_task_enabled(_token, false)


func _exit_tree() -> void:
	if scheduler != null and _token != -1:
		scheduler.unregister_task(_token)
	_token = -1


func set_enabled(enabled: bool) -> Error:
	if scheduler == null or _token == -1:
		return ERR_UNCONFIGURED
	return scheduler.set_task_enabled(_token, enabled)


func request() -> Error:
	if scheduler == null or _token == -1:
		return ERR_UNCONFIGURED
	return scheduler.request_task(_token)


func set_interval(value: float) -> Error:
	if value <= 0.0:
		return ERR_INVALID_PARAMETER

	interval = value
	if scheduler == null or _token == -1:
		return OK
	return scheduler.set_task_interval(_token, interval)


func _on_scheduler_tick(elapsed: float) -> void:
	tick.emit(elapsed)


func _find_scheduler_ancestor() -> NucleusUpdateScheduler:
	var current: Node = get_parent()
	while current != null:
		if current is NucleusUpdateScheduler:
			return current as NucleusUpdateScheduler
		current = current.get_parent()
	return null
