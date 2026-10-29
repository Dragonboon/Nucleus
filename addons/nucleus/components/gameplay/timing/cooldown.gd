class_name NucleusCooldown
extends Node
## Reusable one-shot cooldown built on Godot's native Timer.
##
## Cooldown state can be captured/restored so action sets compose directly with
## the existing NucleusSaveSession participant model.

signal started(duration: float)
signal progress_changed(progress: float)
signal became_ready
signal canceled

@export_range(0.001, 3600.0, 0.001, "or_greater")
var duration: float = 1.0
@export var ignore_time_scale: bool = false
@export var emit_progress: bool = false

var _timer: Timer


func _enter_tree() -> void:
	_timer = Timer.new()
	_timer.name = "CooldownTimer"
	_timer.one_shot = true
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	set_process(false)


func _ready() -> void:
	_timer.ignore_time_scale = ignore_time_scale


func _process(_delta: float) -> void:
	if not emit_progress:
		set_process(false)
		return

	progress_changed.emit(get_progress())


func start(custom_duration: float = -1.0) -> void:
	var resolved_duration: float = (
		custom_duration
		if custom_duration > 0.0
		else duration
	)

	_timer.start(maxf(0.001, resolved_duration))
	set_process(emit_progress)

	started.emit(_timer.wait_time)

	if emit_progress:
		progress_changed.emit(0.0)


func try_start(custom_duration: float = -1.0) -> bool:
	if not is_ready():
		return false

	start(custom_duration)
	return true


func restart(custom_duration: float = -1.0) -> void:
	start(custom_duration)


func cancel() -> void:
	if _timer.is_stopped():
		return

	_timer.stop()
	set_process(false)
	canceled.emit()


func is_ready() -> bool:
	return _timer.is_stopped()


func is_running() -> bool:
	return not _timer.is_stopped()


func get_time_left() -> float:
	return _timer.time_left


func get_progress() -> float:
	if _timer.is_stopped():
		return 1.0

	if _timer.wait_time <= 0.0:
		return 1.0

	return clampf(
		1.0 - _timer.time_left / _timer.wait_time,
		0.0,
		1.0,
	)


func capture_state() -> Dictionary:
	return {
		"running": is_running(),
		"time_left": get_time_left(),
	}


func restore_state(data: Dictionary) -> void:
	var should_run: bool = bool(
		data.get("running", false)
	)
	var time_left: float = maxf(
		0.0,
		float(data.get("time_left", 0.0)),
	)

	if should_run and time_left > 0.0:
		start(time_left)
		return

	cancel()


func _on_timeout() -> void:
	set_process(false)

	if emit_progress:
		progress_changed.emit(1.0)

	became_ready.emit()
