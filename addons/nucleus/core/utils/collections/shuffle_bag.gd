class_name NucleusShuffleBag
extends RefCounted
## Random-without-replacement bag for repeated gameplay selections.
##
## A dedicated RandomNumberGenerator can be supplied for deterministic tests or
## seeded procedural systems.

var avoid_repeat_on_refill: bool = true

var _source: Array = []
var _bag: Array = []
var _rng: RandomNumberGenerator
var _last_drawn: Variant
var _has_last_drawn: bool = false


func _init(
	values: Array = [],
	rng: RandomNumberGenerator = null,
) -> void:
	_rng = rng

	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

	set_values(values)


func set_values(values: Array) -> void:
	_source = values.duplicate()
	_has_last_drawn = false
	_last_drawn = null
	_refill()


func reset() -> void:
	_has_last_drawn = false
	_last_drawn = null
	_refill()


func size() -> int:
	return _source.size()


func remaining() -> int:
	return _bag.size()


func is_empty() -> bool:
	return _source.is_empty()


## Draws one value. Returns null when the source bag is empty.
func draw() -> Variant:
	if _source.is_empty():
		return null

	if _bag.is_empty():
		_refill()

	var value: Variant = _bag.pop_back()

	_last_drawn = value
	_has_last_drawn = true

	return value


func draw_many(count: int) -> Array:
	var result: Array = []

	for _index: int in range(maxi(0, count)):
		if _source.is_empty():
			break

		result.append(draw())

	return result


func _refill() -> void:
	_bag = _source.duplicate()
	_shuffle()

	if (
		avoid_repeat_on_refill
		and _has_last_drawn
		and _bag.size() > 1
		and _bag.back() == _last_drawn
	):
		for index: int in range(_bag.size() - 1):
			if _bag[index] != _last_drawn:
				var replacement: Variant = _bag[index]
				_bag[index] = _bag.back()
				_bag[_bag.size() - 1] = replacement
				break


func _shuffle() -> void:
	for index: int in range(_bag.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)

		if swap_index == index:
			continue

		var value: Variant = _bag[index]
		_bag[index] = _bag[swap_index]
		_bag[swap_index] = value
