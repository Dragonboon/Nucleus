class_name NucleusValuePool
extends Node
## Generic bounded numeric pool for health, stamina, mana, shields, fuel, etc.
##
## The component intentionally has no combat semantics. Damage and regeneration
## are separate components that operate on this API.

signal value_changed(
	value: float,
	previous_value: float,
	delta: float,
)
signal limits_changed(
	minimum_value: float,
	maximum_value: float,
	overflow_limit: float,
)
signal depleted
signal filled
signal overflow_started
signal overflow_ended

@export var minimum_value: float = 0.0
@export var maximum_value: float = 100.0
@export_range(0.0, 1.0e12, 0.01, "or_greater")
var overflow_limit: float = 0.0
@export var initial_value: float = 100.0

var value: float = 0.0


func _ready() -> void:
	_normalize_limits()
	value = clampf(
		initial_value,
		minimum_value,
		_get_upper_bound(),
	)


func set_value(
	new_value: float,
	allow_overflow: bool = false,
) -> float:
	var previous_value: float = value
	var upper_bound: float = (
		_get_upper_bound()
		if allow_overflow
		else maximum_value
	)

	value = clampf(
		new_value,
		minimum_value,
		upper_bound,
	)

	if is_equal_approx(value, previous_value):
		return 0.0

	var delta: float = value - previous_value

	value_changed.emit(
		value,
		previous_value,
		delta,
	)

	_emit_threshold_events(
		previous_value,
		value,
	)

	return delta


func increase(
	amount: float,
	allow_overflow: bool = false,
) -> float:
	return set_value(
		value + absf(amount),
		allow_overflow,
	)


func decrease(amount: float) -> float:
	# Preserve existing overflow while moving downward. Clamping to the normal
	# maximum here would consume the whole overflow portion on the first decrease.
	return set_value(
		value - absf(amount),
		true,
	)


func fill(include_overflow: bool = false) -> float:
	return set_value(
		_get_upper_bound() if include_overflow else maximum_value,
		include_overflow,
	)


func empty() -> float:
	return set_value(minimum_value)


func set_limits(
	new_minimum: float,
	new_maximum: float,
	new_overflow_limit: float = 0.0,
	preserve_ratio: bool = false,
) -> void:
	var previous_ratio: float = get_ratio()

	minimum_value = new_minimum
	maximum_value = new_maximum
	overflow_limit = maxf(0.0, new_overflow_limit)

	_normalize_limits()

	if preserve_ratio:
		var span: float = maximum_value - minimum_value
		set_value(
			minimum_value + span * previous_ratio,
			false,
		)
	else:
		set_value(value, true)

	limits_changed.emit(
		minimum_value,
		maximum_value,
		overflow_limit,
	)


func get_ratio() -> float:
	var span: float = maximum_value - minimum_value

	if span <= 0.0:
		return 0.0

	return clampf(
		(value - minimum_value) / span,
		0.0,
		1.0,
	)


func get_overflow() -> float:
	return maxf(
		0.0,
		value - maximum_value,
	)


func get_overflow_ratio() -> float:
	if overflow_limit <= 0.0:
		return 0.0

	return clampf(
		get_overflow() / overflow_limit,
		0.0,
		1.0,
	)


func is_depleted() -> bool:
	return value <= minimum_value or is_equal_approx(
		value,
		minimum_value,
	)


func is_full() -> bool:
	return value >= maximum_value or is_equal_approx(
		value,
		maximum_value,
	)


func capture_state() -> Dictionary:
	return {
		"value": value,
		"minimum_value": minimum_value,
		"maximum_value": maximum_value,
		"overflow_limit": overflow_limit,
	}


func restore_state(data: Dictionary) -> void:
	var restored_minimum: float = float(
		data.get("minimum_value", minimum_value)
	)
	var restored_maximum: float = float(
		data.get("maximum_value", maximum_value)
	)
	var restored_overflow: float = float(
		data.get("overflow_limit", overflow_limit)
	)

	set_limits(
		restored_minimum,
		restored_maximum,
		restored_overflow,
		false,
	)

	set_value(
		float(data.get("value", value)),
		true,
	)


func _normalize_limits() -> void:
	if maximum_value < minimum_value:
		var previous_minimum: float = minimum_value
		minimum_value = maximum_value
		maximum_value = previous_minimum

	overflow_limit = maxf(0.0, overflow_limit)


func _get_upper_bound() -> float:
	return maximum_value + overflow_limit


func _emit_threshold_events(
	previous_value: float,
	new_value: float,
) -> void:
	if (
		previous_value > minimum_value
		and new_value <= minimum_value
	):
		depleted.emit()

	if (
		previous_value < maximum_value
		and new_value >= maximum_value
	):
		filled.emit()

	if (
		previous_value <= maximum_value
		and new_value > maximum_value
	):
		overflow_started.emit()

	if (
		previous_value > maximum_value
		and new_value <= maximum_value
	):
		overflow_ended.emit()
