class_name NucleusTurnCounter
extends Node
## Reusable event counter: rounds, turns, actions, or other discrete units.

signal changed(previous: int, current: int)
signal reached_limit

@export_range(0, 2147483647, 1, "or_greater") var limit: int = 0
@export var reset_on_limit: bool = false

var count: int = 0


func advance(amount: int = 1) -> Error:
	if amount < 1 or amount > 2147483647 - count:
		return ERR_INVALID_PARAMETER
	var previous: int = count
	count += amount
	changed.emit(previous, count)
	if limit > 0 and count >= limit:
		reached_limit.emit()
		if reset_on_limit:
			reset()
	return OK


func reset() -> void:
	var previous: int = count
	count = 0
	if previous != 0:
		changed.emit(previous, count)


func capture_state() -> Dictionary:
	return {"count": count}


func restore_state(data: Dictionary) -> Error:
	var restored: Variant = data.get("count", -1)
	if not (restored is int) or restored < 0:
		return ERR_INVALID_DATA
	var previous: int = count
	count = restored
	if count != previous:
		changed.emit(previous, count)
	return OK
