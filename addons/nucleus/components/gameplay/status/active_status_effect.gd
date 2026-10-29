class_name NucleusActiveStatusEffect
extends RefCounted
## Runtime instance managed by NucleusStatusEffectContainer.

var definition: NucleusStatusEffectDefinition
var stack_remaining: Array[float] = []
var tick_remaining: float = 0.0
var context: Dictionary = {}


func _init(
	effect_definition: NucleusStatusEffectDefinition = null,
	effect_context: Dictionary = {},
) -> void:
	definition = effect_definition
	context = effect_context.duplicate(true)

	if definition:
		stack_remaining.append(
			_get_initial_duration()
		)
		tick_remaining = maxf(
			0.0,
			definition.tick_interval,
		)


func get_effect_id() -> StringName:
	return (
		definition.effect_id
		if definition
		else &""
	)


func get_stack_count() -> int:
	return stack_remaining.size()


func get_remaining_time() -> float:
	var result: float = 0.0

	for remaining: float in stack_remaining:
		if remaining < 0.0:
			return -1.0

		result = maxf(result, remaining)

	return result


func is_permanent() -> bool:
	return (
		definition != null
		and definition.is_permanent()
	)


func capture_state() -> Dictionary:
	return {
		"effect_id": String(get_effect_id()),
		"stack_remaining": stack_remaining.duplicate(),
		"tick_remaining": tick_remaining,
	}


func _get_initial_duration() -> float:
	return (
		-1.0
		if definition.is_permanent()
		else definition.duration
	)
