class_name NucleusUIAnimatedValue
extends Node
## Smoothly animates a numeric value into a Range and/or Label.

signal value_changed(value: float)
signal animation_finished(value: float)

@export var range_target: Range
@export var label_target: Label

@export_group("Formatting")
@export_range(0, 8, 1) var decimals: int = 0
@export var prefix: String = ""
@export var suffix: String = ""
@export var text_template: String = "{value}"

@export_group("Motion")
@export var motion: NucleusUIMotionProfile

var current_value: float = 0.0

var _tween: Tween
var _updating_range: bool = false


func _ready() -> void:
	if motion == null:
		motion = NucleusUIMotionProfile.new()
		motion.duration = 0.28

	if range_target:
		current_value = range_target.value
		range_target.value_changed.connect(
			_on_range_value_changed
		)

	_apply_value(current_value)


func set_value(
	value: float,
	animated: bool = true,
) -> Tween:
	_kill_tween()

	# Reduced-motion policy can resolve the effective duration to zero.
	# Snap synchronously instead of creating a zero-duration tween that
	# settles on a later frame and can fire a stale completion callback.
	var duration: float = NucleusUIMotion.get_duration(motion)
	if not animated or is_zero_approx(duration):
		_apply_value(value)
		animation_finished.emit(current_value)
		return null

	var target_value: float = _normalize_value(value)

	_tween = NucleusUIMotion.create_tween(
		self,
		motion,
	)
	_tween.tween_method(
		_apply_value,
		current_value,
		target_value,
		duration,
	)
	_tween.finished.connect(
		_on_animation_finished,
		CONNECT_ONE_SHOT,
	)

	return _tween


func format_value(value: float) -> String:
	var number_text: String = String.num(
		value,
		decimals,
	)

	if decimals > 0:
		number_text = number_text.pad_decimals(decimals)

	var formatted: String = prefix + number_text + suffix

	return text_template.replace(
		"{value}",
		formatted,
	)


func _apply_value(value: float) -> void:
	var normalized_value: float = _normalize_value(value)
	current_value = normalized_value

	if range_target:
		_updating_range = true
		range_target.value = normalized_value
		_updating_range = false

	if label_target:
		label_target.text = format_value(normalized_value)

	value_changed.emit(normalized_value)


func _normalize_value(value: float) -> float:
	if range_target == null:
		return value

	return clampf(
		value,
		range_target.min_value,
		range_target.max_value,
	)


func _on_range_value_changed(value: float) -> void:
	if _updating_range:
		return

	_kill_tween()
	_apply_value(value)


func _on_animation_finished() -> void:
	_tween = null
	animation_finished.emit(current_value)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = null
