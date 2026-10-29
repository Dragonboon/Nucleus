@tool
class_name NucleusRegenerator
extends Node
## Periodically restores a [NucleusValuePool].
##
## The delay after a negative pool delta is useful for health/stamina recovery
## without coupling that policy into the pool itself.

signal regeneration_started
signal regeneration_stopped
signal regenerated(amount: float)

@export var target_pool: NucleusValuePool:
	set(value):
		target_pool = value
		update_configuration_warnings()

@export_range(0.0, 1.0e12, 0.01, "or_greater")
var amount_per_tick: float = 1.0:
	set(value):
		amount_per_tick = value
		update_configuration_warnings()

@export_range(0.01, 3600.0, 0.01, "or_greater")
var tick_interval: float = 1.0:
	set(value):
		tick_interval = value
		update_configuration_warnings()

@export_range(0.0, 3600.0, 0.01, "or_greater")
var delay_after_decrease: float = 0.0

@export var allow_overflow: bool = false
@export var ignore_time_scale: bool = false
@export var enabled: bool = true

var _tick_timer: Timer
var _delay_timer: Timer


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_tick_timer = Timer.new()
	_tick_timer.name = "RegenerationTickTimer"
	_tick_timer.one_shot = false
	_tick_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

	_delay_timer = Timer.new()
	_delay_timer.name = "RegenerationDelayTimer"
	_delay_timer.one_shot = true
	_delay_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_delay_timer.timeout.connect(_on_delay_finished)
	add_child(_delay_timer)


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if target_pool == null:
		target_pool = get_parent() as NucleusValuePool

	if target_pool == null:
		NucleusLog.error(
			"%s requires a NucleusValuePool target." % get_path(),
			&"Regenerator",
		)
		return

	_tick_timer.ignore_time_scale = ignore_time_scale
	_delay_timer.ignore_time_scale = ignore_time_scale

	_tick_timer.wait_time = tick_interval
	target_pool.value_changed.connect(_on_pool_value_changed)

	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent_pool := get_parent() as NucleusValuePool

	if target_pool == null and parent_pool == null:
		warnings.append(
			"Assign target_pool or make the Regenerator a child of a "
			+ "NucleusValuePool."
		)

	if amount_per_tick <= 0.0:
		warnings.append("amount_per_tick must be greater than zero.")

	if tick_interval <= 0.0:
		warnings.append("tick_interval must be greater than zero.")

	return warnings


func set_enabled(new_enabled: bool) -> void:
	if enabled == new_enabled:
		return

	enabled = new_enabled
	_refresh()


func restart_delay() -> void:
	_tick_timer.stop()

	if delay_after_decrease > 0.0:
		_delay_timer.start(delay_after_decrease)
	else:
		_start_regeneration()


func _refresh() -> void:
	if (
		not enabled
		or target_pool == null
		or amount_per_tick <= 0.0
		or _is_target_full()
	):
		_stop_regeneration()
		return

	if not _delay_timer.is_stopped():
		return

	_start_regeneration()


func _start_regeneration() -> void:
	if (
		not enabled
		or target_pool == null
		or _is_target_full()
	):
		return

	_tick_timer.wait_time = maxf(0.01, tick_interval)

	if _tick_timer.is_stopped():
		_tick_timer.start()
		regeneration_started.emit()


func _stop_regeneration() -> void:
	var was_running: bool = not _tick_timer.is_stopped()

	_tick_timer.stop()

	if was_running:
		regeneration_stopped.emit()


func _is_target_full() -> bool:
	if allow_overflow:
		return (
			target_pool.value
			>= target_pool.maximum_value + target_pool.overflow_limit
		)

	return target_pool.is_full()


func _on_tick() -> void:
	var applied: float = target_pool.increase(
		amount_per_tick,
		allow_overflow,
	)

	if applied > 0.0:
		regenerated.emit(applied)

	if _is_target_full():
		_stop_regeneration()


func _on_delay_finished() -> void:
	_start_regeneration()


func _on_pool_value_changed(
	_value: float,
	_previous_value: float,
	delta: float,
) -> void:
	if delta < 0.0 and delay_after_decrease > 0.0:
		restart_delay()
		return

	_refresh()
