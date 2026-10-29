@tool
class_name NucleusWorldClock
extends Node
## Scene-owned 24-hour simulation clock.
##
## The clock owns elapsed game time only. Calendars, seasons, weather, lighting,
## schedules, persistence policy, and multiplayer authority stay in consumers.

signal time_changed(
	previous_total_seconds: float,
	total_seconds: float,
)
signal day_changed(previous_day: int, current_day: int)
signal hour_changed(previous_hour: int, current_hour: int)
signal minute_changed(previous_minute: int, current_minute: int)
signal running_changed(running: bool)
signal time_scale_changed(previous_scale: float, current_scale: float)

enum AdvanceMode {
	IDLE,
	PHYSICS,
	MANUAL,
}

const HOURS_PER_DAY: int = 24
const MINUTES_PER_HOUR: int = 60
const SECONDS_PER_MINUTE: float = 60.0
const SECONDS_PER_HOUR: float = 3600.0
const SECONDS_PER_DAY: float = 86400.0

@export var advance_mode: AdvanceMode = AdvanceMode.IDLE:
	set(value):
		advance_mode = value
		_sync_processing()

@export var running: bool = true:
	set(value):
		if running == value:
			return

		running = value
		_sync_processing()
		running_changed.emit(running)

@export_range(0.0, 86400.0, 0.001, "or_greater")
var game_seconds_per_real_second: float = 60.0:
	set(value):
		var resolved := maxf(0.0, value)

		if is_equal_approx(game_seconds_per_real_second, resolved):
			return

		var previous := game_seconds_per_real_second
		game_seconds_per_real_second = resolved
		time_scale_changed.emit(previous, game_seconds_per_real_second)

@export_group("Initial time")
@export var start_day: int = 0
@export_range(0, 23, 1) var start_hour: int = 8
@export_range(0, 59, 1) var start_minute: int = 0
@export_range(0.0, 59.999, 0.001) var start_second: float = 0.0

var _day: int = 0
var _seconds_of_day: float = 0.0
var _time_initialized: bool = false


func _ready() -> void:
	if not _time_initialized:
		set_time_hms(
			maxi(0, start_day),
			start_hour,
			start_minute,
			start_second,
			false,
		)

	_sync_processing()


func _process(delta: float) -> void:
	advance(delta)


func _physics_process(delta: float) -> void:
	advance(delta)


func set_running(value: bool) -> void:
	running = value


func set_time_scale(value: float) -> void:
	game_seconds_per_real_second = value


func advance(real_seconds: float) -> void:
	if not running or real_seconds <= 0.0:
		return

	if game_seconds_per_real_second <= 0.0:
		return

	advance_game_seconds(
		real_seconds * game_seconds_per_real_second
	)


func advance_game_seconds(game_seconds: float) -> void:
	if not running or is_zero_approx(game_seconds):
		return

	set_total_game_seconds(
		get_total_game_seconds() + game_seconds
	)


func set_time_hms(
	day: int,
	hour: int,
	minute: int,
	second: float = 0.0,
	emit_signals: bool = true,
) -> Error:
	if day < 0:
		return ERR_INVALID_PARAMETER

	if hour < 0 or hour >= HOURS_PER_DAY:
		return ERR_INVALID_PARAMETER

	if minute < 0 or minute >= MINUTES_PER_HOUR:
		return ERR_INVALID_PARAMETER

	if second < 0.0 or second >= SECONDS_PER_MINUTE:
		return ERR_INVALID_PARAMETER

	var seconds_of_day := (
		float(hour) * SECONDS_PER_HOUR
		+ float(minute) * SECONDS_PER_MINUTE
		+ second
	)

	set_time(day, seconds_of_day, emit_signals)
	return OK


func set_time(
	day: int,
	seconds_of_day: float,
	emit_signals: bool = true,
) -> void:
	var total := (
		float(maxi(day, 0)) * SECONDS_PER_DAY
		+ seconds_of_day
	)
	set_total_game_seconds(total, emit_signals)


func set_time_of_day_seconds(
	seconds_of_day: float,
	emit_signals: bool = true,
) -> Error:
	if seconds_of_day < 0.0 or seconds_of_day >= SECONDS_PER_DAY:
		return ERR_INVALID_PARAMETER

	set_time(_day, seconds_of_day, emit_signals)
	return OK


func set_total_game_seconds(
	total_seconds: float,
	emit_signals: bool = true,
) -> void:
	var resolved_total := maxf(0.0, total_seconds)
	var previous_total := get_total_game_seconds()
	var previous_day := _day
	var previous_hour := get_hour()
	var previous_minute := get_minute()

	_day = int(floor(resolved_total / SECONDS_PER_DAY))
	_seconds_of_day = (
		resolved_total
		- float(_day) * SECONDS_PER_DAY
	)

	if _seconds_of_day >= SECONDS_PER_DAY:
		_day += 1
		_seconds_of_day = 0.0

	_time_initialized = true

	if not emit_signals:
		return

	var current_total := get_total_game_seconds()

	if is_equal_approx(previous_total, current_total):
		return

	time_changed.emit(previous_total, current_total)

	if previous_day != _day:
		day_changed.emit(previous_day, _day)

	var current_hour := get_hour()
	if previous_hour != current_hour:
		hour_changed.emit(previous_hour, current_hour)

	var current_minute := get_minute()
	if previous_minute != current_minute:
		minute_changed.emit(previous_minute, current_minute)


func get_day() -> int:
	return _day


func get_hour() -> int:
	return int(floor(_seconds_of_day / SECONDS_PER_HOUR))


func get_minute() -> int:
	var seconds_into_hour := fmod(
		_seconds_of_day,
		SECONDS_PER_HOUR,
	)
	return int(floor(seconds_into_hour / SECONDS_PER_MINUTE))


func get_second() -> float:
	return fmod(_seconds_of_day, SECONDS_PER_MINUTE)


func get_hour_fraction() -> float:
	return _seconds_of_day / SECONDS_PER_HOUR


func get_seconds_of_day() -> float:
	return _seconds_of_day


func get_normalized_day_time() -> float:
	return clampf(
		_seconds_of_day / SECONDS_PER_DAY,
		0.0,
		1.0,
	)


func get_total_game_seconds() -> float:
	return float(_day) * SECONDS_PER_DAY + _seconds_of_day


func capture_state() -> Dictionary:
	return {
		"schema_version": 1,
		"day": _day,
		"seconds_of_day": _seconds_of_day,
		"running": running,
		"game_seconds_per_real_second": (
			game_seconds_per_real_second
		),
	}


func restore_state(data: Dictionary) -> Error:
	if not data.has("day") or not data.has("seconds_of_day"):
		return ERR_INVALID_DATA

	var restored_day := int(data.get("day", 0))
	var restored_seconds := float(
		data.get("seconds_of_day", 0.0)
	)

	if restored_day < 0:
		return ERR_INVALID_DATA

	if restored_seconds < 0.0 or restored_seconds >= SECONDS_PER_DAY:
		return ERR_INVALID_DATA

	set_time(restored_day, restored_seconds)

	if data.has("game_seconds_per_real_second"):
		set_time_scale(
			float(data["game_seconds_per_real_second"])
		)

	if data.has("running"):
		set_running(bool(data["running"]))

	return OK


func _sync_processing() -> void:
	if not is_inside_tree():
		return

	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return

	set_process(
		running and advance_mode == AdvanceMode.IDLE
	)
	set_physics_process(
		running and advance_mode == AdvanceMode.PHYSICS
	)
