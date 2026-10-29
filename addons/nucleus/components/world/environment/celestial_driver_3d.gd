@tool
class_name NucleusCelestialDriver3D
extends Node
## Scene-owned bridge from NucleusWorldClock to derived celestial state.
##
## Simulation time remains authoritative in NucleusWorldClock. This driver only
## decides when presentation-facing celestial state is recomputed.

signal state_changed(state: NucleusCelestialState3D)
signal horizon_changed(
	sun_above_horizon: bool,
	moon_above_horizon: bool,
)

enum UpdateMode {
	IMMEDIATE,
	SCHEDULED,
	MANUAL,
}

@export var clock: NucleusWorldClock:
	set(value):
		if clock == value:
			return

		_disconnect_clock()
		clock = value
		update_configuration_warnings()
		_connect_clock()
		_mark_dirty()
		_refresh_if_immediate()

@export var source: NucleusCelestialSource3D:
	set(value):
		source = value
		update_configuration_warnings()
		_mark_dirty()
		_refresh_if_immediate()

@export_group("Update cadence")
@export var update_mode: UpdateMode = UpdateMode.IMMEDIATE:
	set(value):
		if update_mode == value:
			return

		update_mode = value
		update_configuration_warnings()
		_sync_scheduler_task()
		_mark_dirty()
		_refresh_if_immediate()

@export var scheduler: NucleusUpdateScheduler:
	set(value):
		if scheduler == value:
			return

		_unregister_scheduler_task()
		scheduler = value
		update_configuration_warnings()
		_sync_scheduler_task()

@export_range(0.016, 60.0, 0.001, "or_greater")
var update_interval: float = 0.1:
	set(value):
		update_interval = maxf(value, 0.016)

		if scheduler != null and _scheduler_token != -1:
			scheduler.set_task_interval(
				_scheduler_token,
				update_interval,
			)

@export_range(-1.0, 1.0, 0.001)
var scheduler_phase: float = -1.0:
	set(value):
		scheduler_phase = clampf(value, -1.0, 1.0)
		_restart_scheduler_task()

@export var scheduler_priority: int = 0:
	set(value):
		scheduler_priority = value
		_restart_scheduler_task()

var _state: NucleusCelestialState3D = NucleusCelestialState3D.new()
var _fallback_source: NucleusSimpleCelestialSource3D = (
	NucleusSimpleCelestialSource3D.new()
)
var _scheduler_token: int = -1
var _has_state: bool = false
var _dirty: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if clock == null:
		clock = get_parent() as NucleusWorldClock

	_connect_clock()
	_sync_scheduler_task()
	refresh_now()


func _exit_tree() -> void:
	_disconnect_clock()
	_unregister_scheduler_task()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	var parent_clock: NucleusWorldClock = get_parent() as NucleusWorldClock

	if clock == null and parent_clock == null:
		warnings.append(
			"Assign clock or make this node a child of NucleusWorldClock."
		)

	if (
		update_mode == UpdateMode.SCHEDULED
		and scheduler == null
	):
		warnings.append(
			"SCHEDULED update mode requires NucleusUpdateScheduler."
		)

	var active_source: NucleusCelestialSource3D = _get_active_source()
	var source_errors: PackedStringArray = (
		active_source.get_validation_errors()
	)

	for error_text: String in source_errors:
		warnings.append(error_text)

	return warnings


func refresh_now() -> Error:
	if clock == null:
		return ERR_UNCONFIGURED

	var active_source: NucleusCelestialSource3D = _get_active_source()
	var previous_sun_above: bool = _state.sun_above_horizon
	var previous_moon_above: bool = _state.moon_above_horizon
	var sample_error: Error = active_source.sample_state(
		clock.get_normalized_day_time(),
		_state,
	)

	if sample_error != OK:
		return sample_error

	_dirty = false
	state_changed.emit(_state)

	if (
		_has_state
		and (
			previous_sun_above != _state.sun_above_horizon
			or previous_moon_above != _state.moon_above_horizon
		)
	):
		horizon_changed.emit(
			_state.sun_above_horizon,
			_state.moon_above_horizon,
		)

	_has_state = true
	return OK


func request_refresh() -> Error:
	if update_mode != UpdateMode.SCHEDULED:
		return refresh_now()

	if scheduler == null or _scheduler_token == -1:
		return ERR_UNCONFIGURED

	_dirty = true
	return scheduler.request_task(_scheduler_token)


func get_state() -> NucleusCelestialState3D:
	return _state


func has_state() -> bool:
	return _has_state


func is_dirty() -> bool:
	return _dirty


func _get_active_source() -> NucleusCelestialSource3D:
	if source != null:
		return source

	return _fallback_source


func _mark_dirty() -> void:
	_dirty = true


func _refresh_if_immediate() -> void:
	if (
		not is_inside_tree()
		or Engine.is_editor_hint()
		or update_mode != UpdateMode.IMMEDIATE
	):
		return

	refresh_now()


func _connect_clock() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	if clock == null:
		return

	if not clock.time_changed.is_connected(_on_clock_time_changed):
		clock.time_changed.connect(_on_clock_time_changed)


func _disconnect_clock() -> void:
	if clock == null:
		return

	if clock.time_changed.is_connected(_on_clock_time_changed):
		clock.time_changed.disconnect(_on_clock_time_changed)


func _on_clock_time_changed(
	_previous_total_seconds: float,
	_total_seconds: float,
) -> void:
	_dirty = true

	if update_mode == UpdateMode.IMMEDIATE:
		refresh_now()


func _sync_scheduler_task() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return

	if update_mode != UpdateMode.SCHEDULED:
		_unregister_scheduler_task()
		return

	if scheduler == null:
		_unregister_scheduler_task()
		return

	if _scheduler_token != -1:
		scheduler.set_task_interval(
			_scheduler_token,
			update_interval,
		)
		return

	_scheduler_token = scheduler.register_task(
		Callable(self, "_on_scheduled_update"),
		update_interval,
		scheduler_phase,
		scheduler_priority,
	)


func _restart_scheduler_task() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return

	if update_mode != UpdateMode.SCHEDULED:
		return

	_unregister_scheduler_task()
	_sync_scheduler_task()


func _unregister_scheduler_task() -> void:
	if _scheduler_token == -1:
		return

	if is_instance_valid(scheduler):
		scheduler.unregister_task(_scheduler_token)

	_scheduler_token = -1


func _on_scheduled_update(_elapsed: float) -> void:
	if not _dirty:
		return

	refresh_now()
