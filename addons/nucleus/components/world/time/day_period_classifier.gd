@tool
class_name NucleusDayPeriodClassifier
extends Node
## Maps a NucleusWorldClock time-of-day to four configurable day periods.

signal period_changed(previous_period: int, current_period: int)

enum DayPeriod {
	DAWN,
	DAY,
	DUSK,
	NIGHT,
}

@export var clock: NucleusWorldClock:
	set(value):
		if clock == value:
			return

		_disconnect_clock()
		clock = value
		update_configuration_warnings()
		_connect_clock()

@export_group("Period starts")
@export_range(0.0, 23.99, 0.01) var dawn_start_hour: float = 5.0:
	set(value):
		dawn_start_hour = value
		_boundary_changed()

@export_range(0.0, 23.99, 0.01) var day_start_hour: float = 7.0:
	set(value):
		day_start_hour = value
		_boundary_changed()

@export_range(0.0, 23.99, 0.01) var dusk_start_hour: float = 18.0:
	set(value):
		dusk_start_hour = value
		_boundary_changed()

@export_range(0.0, 23.99, 0.01) var night_start_hour: float = 21.0:
	set(value):
		night_start_hour = value
		_boundary_changed()

var current_period: DayPeriod = DayPeriod.NIGHT
var _initialized: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if clock == null:
		clock = get_parent() as NucleusWorldClock

	_connect_clock()
	refresh()


func _exit_tree() -> void:
	_disconnect_clock()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent_clock := get_parent() as NucleusWorldClock

	if clock == null and parent_clock == null:
		warnings.append(
			"Assign clock or make this node a child of NucleusWorldClock."
		)

	if not _boundaries_are_valid():
		warnings.append(
			"Period starts must satisfy dawn < day < dusk < night."
		)

	return warnings


func refresh() -> Error:
	if clock == null:
		return ERR_UNCONFIGURED

	if not _boundaries_are_valid():
		return ERR_INVALID_PARAMETER

	var next_period := classify_hour(
		clock.get_hour_fraction()
	)

	if not _initialized:
		current_period = next_period
		_initialized = true
		return OK

	if next_period == current_period:
		return OK

	var previous := current_period
	current_period = next_period
	period_changed.emit(previous, current_period)
	return OK


func classify_hour(hour: float) -> DayPeriod:
	var normalized_hour := fposmod(hour, 24.0)

	if (
		normalized_hour >= night_start_hour
		or normalized_hour < dawn_start_hour
	):
		return DayPeriod.NIGHT

	if normalized_hour < day_start_hour:
		return DayPeriod.DAWN

	if normalized_hour < dusk_start_hour:
		return DayPeriod.DAY

	return DayPeriod.DUSK


func get_current_period() -> DayPeriod:
	return current_period


func get_period_id(period: int = -1) -> StringName:
	var resolved := current_period if period < 0 else period

	match resolved:
		DayPeriod.DAWN:
			return &"dawn"
		DayPeriod.DAY:
			return &"day"
		DayPeriod.DUSK:
			return &"dusk"
		DayPeriod.NIGHT:
			return &"night"
		_:
			return &""


func is_period(period: DayPeriod) -> bool:
	return _initialized and current_period == period


func _boundary_changed() -> void:
	update_configuration_warnings()

	if is_inside_tree() and not Engine.is_editor_hint():
		refresh()


func _boundaries_are_valid() -> bool:
	return (
		dawn_start_hour < day_start_hour
		and day_start_hour < dusk_start_hour
		and dusk_start_hour < night_start_hour
	)


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
	refresh()
