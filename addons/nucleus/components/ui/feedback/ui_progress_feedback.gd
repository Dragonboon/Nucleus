class_name NucleusUIProgressFeedback
extends Node
## Polished numeric Range presentation with an optional delayed trailing bar.
##
## This component owns presentation only. Gameplay remains authoritative for the
## value being displayed.

signal value_changed(value: float, direction: int)
signal settled(value: float)

enum ChangeDirection {
	NONE,
	INCREASE,
	DECREASE,
}

@export var primary_target: Range
@export var trailing_target: Range

@export_group("Animation")
@export var motion: NucleusUIMotionProfile

@export_range(0.0, 5.0, 0.01, "or_greater")
var decrease_trail_delay: float = 0.18

@export_range(0.0, 5.0, 0.01, "or_greater")
var increase_trail_delay: float = 0.0

@export var sync_trailing_bounds: bool = true

@export_group("Optional pulse")
@export var feedback_target: Control
@export var pulse_on_decrease: bool = true
@export var pulse_on_increase: bool = false

@export_range(1.0, 3.0, 0.01)
var pulse_scale: float = 1.04

@export var pulse_motion: NucleusUIMotionProfile

var current_value: float = 0.0

var _value_tween: Tween
var _pulse_tween: Tween
var _feedback_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	if not _resolve_primary():
		return

	if motion == null:
		motion = NucleusUIMotionProfile.new()
		motion.duration = 0.2

	if pulse_motion == null:
		pulse_motion = NucleusUIMotionProfile.new()
		pulse_motion.duration = 0.12

	if feedback_target:
		_feedback_base_scale = feedback_target.scale

	_sync_bounds()
	current_value = _clamp_value(primary_target.value)

	if trailing_target:
		trailing_target.value = _map_to_trailing(current_value)


func set_value(
	value: float,
	animated: bool = true,
) -> Error:
	if primary_target == null:
		return ERR_UNCONFIGURED

	_sync_bounds()
	var target_value := _clamp_value(value)
	var direction := _direction(current_value, target_value)
	current_value = target_value

	_kill_value_tween()

	if not animated or is_zero_approx(NucleusUIMotion.get_duration(motion)):
		_apply_value_immediately(target_value)
		if animated:
			_play_optional_pulse(direction)
		value_changed.emit(target_value, direction)
		settled.emit(target_value)
		return OK

	var duration := NucleusUIMotion.get_duration(motion)
	var delay := (
		decrease_trail_delay
		if direction == ChangeDirection.DECREASE
		else increase_trail_delay
	)

	_value_tween = NucleusUIMotion.create_tween(
		self,
		motion,
	).set_parallel(true)

	_value_tween.tween_property(
		primary_target,
		"value",
		target_value,
		duration,
	)

	if trailing_target:
		_value_tween.tween_property(
			trailing_target,
			"value",
			_map_to_trailing(target_value),
			duration,
		).set_delay(maxf(0.0, delay))

	_value_tween.finished.connect(
		_on_value_tween_finished,
		CONNECT_ONE_SHOT,
	)

	_play_optional_pulse(direction)
	value_changed.emit(target_value, direction)
	return OK


func set_ratio(
	ratio: float,
	animated: bool = true,
) -> Error:
	if primary_target == null:
		return ERR_UNCONFIGURED

	return set_value(
		lerpf(
			primary_target.min_value,
			primary_target.max_value,
			clampf(ratio, 0.0, 1.0),
		),
		animated,
	)


func snap_to(value: float) -> Error:
	return set_value(value, false)


func get_ratio() -> float:
	if primary_target == null:
		return 0.0

	var span: float = primary_target.max_value - primary_target.min_value
	if is_zero_approx(span):
		return 0.0

	return clampf(
		(current_value - primary_target.min_value) / span,
		0.0,
		1.0,
	)


func capture_feedback_scale() -> void:
	if feedback_target:
		_kill_pulse_tween()
		_feedback_base_scale = feedback_target.scale


func _resolve_primary() -> bool:
	if primary_target == null:
		primary_target = get_parent() as Range

	if primary_target:
		return true

	NucleusLog.error(
		"%s requires a Range primary_target or parent." % get_path(),
		&"UIProgress",
	)

	return false


func _sync_bounds() -> void:
	if not sync_trailing_bounds or trailing_target == null:
		return

	trailing_target.min_value = primary_target.min_value
	trailing_target.max_value = primary_target.max_value
	trailing_target.step = primary_target.step


func _apply_value_immediately(value: float) -> void:
	primary_target.value = value

	if trailing_target:
		trailing_target.value = _map_to_trailing(value)


func _clamp_value(value: float) -> float:
	return clampf(
		value,
		primary_target.min_value,
		primary_target.max_value,
	)


func _map_to_trailing(value: float) -> float:
	if trailing_target == null:
		return value

	var primary_span: float = (
		primary_target.max_value
		- primary_target.min_value
	)
	if is_zero_approx(primary_span):
		return trailing_target.min_value

	var ratio := clampf(
		(value - primary_target.min_value) / primary_span,
		0.0,
		1.0,
	)

	return lerpf(
		trailing_target.min_value,
		trailing_target.max_value,
		ratio,
	)


func _direction(
	previous_value: float,
	next_value: float,
) -> int:
	if next_value > previous_value:
		return ChangeDirection.INCREASE

	if next_value < previous_value:
		return ChangeDirection.DECREASE

	return ChangeDirection.NONE


func _play_optional_pulse(direction: int) -> void:
	if feedback_target == null or direction == ChangeDirection.NONE:
		return

	if (
		direction == ChangeDirection.DECREASE
		and not pulse_on_decrease
	):
		return

	if (
		direction == ChangeDirection.INCREASE
		and not pulse_on_increase
	):
		return

	_kill_pulse_tween()
	feedback_target.scale = _feedback_base_scale
	_pulse_tween = NucleusUIMotion.punch_scale(
		feedback_target,
		pulse_scale,
		pulse_motion,
	)


func _kill_value_tween() -> void:
	if _value_tween and _value_tween.is_valid():
		_value_tween.kill()

	_value_tween = null


func _kill_pulse_tween() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_pulse_tween = null

	if feedback_target:
		feedback_target.scale = _feedback_base_scale


func _on_value_tween_finished() -> void:
	_value_tween = null
	settled.emit(current_value)
