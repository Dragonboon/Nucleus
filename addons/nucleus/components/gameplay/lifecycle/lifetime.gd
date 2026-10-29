class_name NucleusLifetime
extends Node
## Expires a target Node after a configurable lifetime.
##
## By default the target is queue_free()'d. Pooling adapters can disable
## auto_free_on_expire and consume the expired signal instead.

signal started(duration: float)
signal canceled
signal expired

@export var target: Node
@export_range(0.001, 3600.0, 0.001, "or_greater")
var duration: float = 1.0
@export var start_on_ready: bool = true
@export var ignore_time_scale: bool = false
@export var auto_free_on_expire: bool = true

var _timer: Timer


func _enter_tree() -> void:
	_timer = Timer.new()
	_timer.name = "LifetimeTimer"
	_timer.one_shot = true
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)


func _ready() -> void:
	if target == null:
		target = get_parent()

	_timer.ignore_time_scale = ignore_time_scale

	if start_on_ready:
		start()


func start(custom_duration: float = -1.0) -> void:
	var resolved_duration: float = (
		custom_duration
		if custom_duration > 0.0
		else duration
	)

	_timer.start(maxf(0.001, resolved_duration))
	started.emit(_timer.wait_time)


func cancel() -> void:
	if _timer.is_stopped():
		return

	_timer.stop()
	canceled.emit()


func get_time_left() -> float:
	return _timer.time_left


func is_running() -> bool:
	return not _timer.is_stopped()


func _on_timeout() -> void:
	expired.emit()

	if (
		auto_free_on_expire
		and target
		and is_instance_valid(target)
	):
		target.queue_free()
