class_name NucleusStatusEffectContainer
extends Node
## Scene-owned runtime for timed/stacked status effects.
##
## Status effects contribute Attribute modifier sources and expose tags/ticks.
## They do not own game-specific visuals, particles, animations, or AI logic.

signal effect_added(effect: NucleusActiveStatusEffect)
signal effect_refreshed(effect: NucleusActiveStatusEffect)
signal effect_removed(
	effect_id: StringName,
	reason: StringName,
)
signal effect_stacks_changed(
	effect: NucleusActiveStatusEffect,
	previous_stacks: int,
	current_stacks: int,
)
signal effect_ticked(effect: NucleusActiveStatusEffect)
signal effects_changed

const REMOVE_MANUAL: StringName = &"manual"
const REMOVE_EXPIRED: StringName = &"expired"
const REMOVE_CLEARED: StringName = &"cleared"
const SOURCE_PREFIX: String = "status:"

@export var attribute_set: NucleusAttributeSet
@export var known_effects: Array[NucleusStatusEffectDefinition] = []
@export var immune_tags: Array[StringName] = []

var _definitions: Dictionary[StringName, NucleusStatusEffectDefinition] = {}
var _active: Dictionary[StringName, NucleusActiveStatusEffect] = {}

var _last_real_usec: int = 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _ready() -> void:
	if attribute_set == null:
		attribute_set = _find_attribute_set()

	_build_definition_registry()
	_last_real_usec = Time.get_ticks_usec()


func can_apply_effect(
	definition: NucleusStatusEffectDefinition,
) -> Error:
	if definition == null or definition.effect_id == &"":
		return ERR_INVALID_PARAMETER

	if (
		not immune_tags.is_empty()
		and NucleusArrayUtils.intersects(
			immune_tags,
			definition.tags,
		)
	):
		return ERR_UNAVAILABLE

	if definition.duration_unit == NucleusStatusEffectDefinition.DurationUnit.TURNS:
		if definition.duration > 0.0 and not is_equal_approx(
			definition.duration, floorf(definition.duration)
		):
			return ERR_INVALID_PARAMETER
		if definition.tick_interval > 0.0 and not is_equal_approx(
			definition.tick_interval, floorf(definition.tick_interval)
		):
			return ERR_INVALID_PARAMETER

	return OK


func apply_effect(
	definition: NucleusStatusEffectDefinition,
	context: Dictionary = {},
) -> Error:
	var error: Error = can_apply_effect(definition)

	if error != OK:
		return error

	_register_definition(definition)

	if _active.has(definition.effect_id):
		_reapply_effect(
			_active[definition.effect_id],
			context,
		)
		return OK

	var active := NucleusActiveStatusEffect.new(
		definition,
		context,
	)
	_active[definition.effect_id] = active

	_sync_attribute_modifiers(active)
	_refresh_processing()

	effect_added.emit(active)
	effects_changed.emit()

	if definition.tick_on_apply and definition.tick_interval > 0.0:
		effect_ticked.emit(active)

	return OK


func remove_effect(
	effect_id: StringName,
	reason: StringName = REMOVE_MANUAL,
) -> bool:
	if not _active.has(effect_id):
		return false

	_active.erase(effect_id)

	if attribute_set:
		attribute_set.remove_modifier_source(
			_get_modifier_source_id(effect_id)
		)

	_refresh_processing()

	effect_removed.emit(
		effect_id,
		reason,
	)
	effects_changed.emit()

	return true


func clear_effects(
	reason: StringName = REMOVE_CLEARED,
) -> void:
	var effect_ids: Array = _active.keys()

	for value: Variant in effect_ids:
		remove_effect(
			StringName(str(value)),
			reason,
		)


func remove_effects_with_tag(
	tag: StringName,
	reason: StringName = REMOVE_MANUAL,
) -> int:
	var removed: int = 0

	for active: NucleusActiveStatusEffect in get_effects():
		if not active.definition.has_tag(tag):
			continue

		if remove_effect(active.get_effect_id(), reason):
			removed += 1

	return removed


func has_effect(effect_id: StringName) -> bool:
	return _active.has(effect_id)


func has_tag(tag: StringName) -> bool:
	for active: NucleusActiveStatusEffect in _active.values():
		if active.definition.has_tag(tag):
			return true

	return false


func has_any_tag(tags: Array[StringName]) -> bool:
	if tags.is_empty():
		return false

	for active: NucleusActiveStatusEffect in _active.values():
		if NucleusArrayUtils.intersects(
			active.definition.tags,
			tags,
		):
			return true

	return false


func get_effect(
	effect_id: StringName,
) -> NucleusActiveStatusEffect:
	return _active.get(effect_id)


func get_effects() -> Array[NucleusActiveStatusEffect]:
	var result: Array[NucleusActiveStatusEffect] = []

	for active: NucleusActiveStatusEffect in _active.values():
		result.append(active)

	return result


func get_effects_with_tag(
	tag: StringName,
) -> Array[NucleusActiveStatusEffect]:
	var result: Array[NucleusActiveStatusEffect] = []

	for active: NucleusActiveStatusEffect in _active.values():
		if active.definition.has_tag(tag):
			result.append(active)

	return result


func register_definition(
	definition: NucleusStatusEffectDefinition,
) -> Error:
	if definition == null or definition.effect_id == &"":
		return ERR_INVALID_PARAMETER

	_register_definition(definition)
	return OK


func capture_state() -> Dictionary:
	var active_effects: Array[Dictionary] = []

	for active: NucleusActiveStatusEffect in _active.values():
		if not active.definition.persist:
			continue

		active_effects.append(
			active.capture_state()
		)

	return {
		"effects": active_effects,
	}


func restore_state(data: Dictionary) -> void:
	clear_effects(&"restore")

	var stored_effects: Variant = data.get(
		"effects",
		[],
	)

	if not stored_effects is Array:
		return

	for entry: Variant in stored_effects:
		if not entry is Dictionary:
			continue

		var effect_id := StringName(
			str(entry.get("effect_id", ""))
		)
		var definition: NucleusStatusEffectDefinition = (
			_definitions.get(effect_id)
		)

		if definition == null:
			NucleusLog.warning(
				"Cannot restore unknown status effect '%s'."
				% effect_id,
				&"StatusEffects",
			)
			continue

		var active := NucleusActiveStatusEffect.new(
			definition
		)
		var restored_remaining: Array[float] = []

		for remaining: Variant in entry.get(
			"stack_remaining",
			[],
		):
			restored_remaining.append(
				float(remaining)
			)

		if restored_remaining.is_empty():
			continue

		active.stack_remaining = restored_remaining
		active.tick_remaining = maxf(
			0.0,
			float(
				entry.get(
					"tick_remaining",
					definition.tick_interval,
				)
			),
		)

		_active[effect_id] = active
		_sync_attribute_modifiers(active)
		effect_added.emit(active)

	_refresh_processing()
	effects_changed.emit()


func _process(delta: float) -> void:
	if _active.is_empty():
		set_process(false)
		return

	var now_usec: int = Time.get_ticks_usec()
	var real_delta: float = maxf(
		0.0,
		(now_usec - _last_real_usec) / 1_000_000.0,
	)
	_last_real_usec = now_usec

	var game_delta: float = (
		0.0
		if get_tree().paused
		else delta
	)

	for active: NucleusActiveStatusEffect in get_effects():
		if active.definition.duration_unit != NucleusStatusEffectDefinition.DurationUnit.SECONDS:
			continue
		var effect_delta: float = (
			real_delta
			if active.definition.ignore_time_scale
			else game_delta
		)

		if effect_delta <= 0.0:
			continue

		_update_effect(
			active,
			effect_delta,
		)


## Explicit discrete clock, independent of _process() and Godot's time scale.
func advance_turns(steps: int = 1) -> Error:
	if steps < 1 or steps > 1000000:
		return ERR_INVALID_PARAMETER
	for active: NucleusActiveStatusEffect in get_effects():
		if active.definition.duration_unit != NucleusStatusEffectDefinition.DurationUnit.TURNS:
			continue
		if _active.get(active.get_effect_id()) != active:
			continue
		_update_effect(active, float(steps))
	return OK


func _update_effect(
	active: NucleusActiveStatusEffect,
	delta: float,
) -> void:
	var previous_stacks: int = active.get_stack_count()
	var remaining_lifetime: float = active.get_remaining_time()
	var tick_delta: float = delta

	if remaining_lifetime >= 0.0:
		tick_delta = minf(
			delta,
			remaining_lifetime,
		)

	_update_tick(
		active,
		tick_delta,
	)

	for index: int in range(
		active.stack_remaining.size() - 1,
		-1,
		-1,
	):
		if active.stack_remaining[index] < 0.0:
			continue

		active.stack_remaining[index] -= delta

		if active.stack_remaining[index] <= 0.0:
			active.stack_remaining.remove_at(index)

	if active.stack_remaining.is_empty():
		remove_effect(
			active.get_effect_id(),
			REMOVE_EXPIRED,
		)
		return

	var current_stacks: int = active.get_stack_count()

	if current_stacks != previous_stacks:
		_sync_attribute_modifiers(active)
		effect_stacks_changed.emit(
			active,
			previous_stacks,
			current_stacks,
		)
		effects_changed.emit()


func _update_tick(
	active: NucleusActiveStatusEffect,
	delta: float,
) -> void:
	var interval: float = active.definition.tick_interval

	if interval <= 0.0:
		return

	active.tick_remaining -= delta

	while active.tick_remaining <= 0.0:
		effect_ticked.emit(active)
		active.tick_remaining += interval


func _reapply_effect(
	active: NucleusActiveStatusEffect,
	context: Dictionary,
) -> void:
	var definition: NucleusStatusEffectDefinition = active.definition
	var previous_stacks: int = active.get_stack_count()
	var duration: float = (
		-1.0
		if definition.is_permanent()
		else definition.duration
	)

	match definition.reapply_policy:
		NucleusStatusEffectDefinition.ReapplyPolicy.REFRESH:
			active.stack_remaining.clear()
			active.stack_remaining.append(duration)

		NucleusStatusEffectDefinition.ReapplyPolicy.ADD_STACK_REFRESH:
			if active.get_stack_count() < definition.maximum_stacks:
				active.stack_remaining.append(duration)

			for index: int in range(active.stack_remaining.size()):
				active.stack_remaining[index] = duration

		NucleusStatusEffectDefinition.ReapplyPolicy.ADD_STACK_INDEPENDENT:
			if active.get_stack_count() < definition.maximum_stacks:
				active.stack_remaining.append(duration)
			else:
				_refresh_shortest_stack(
					active,
					duration,
				)

		NucleusStatusEffectDefinition.ReapplyPolicy.EXTEND_DURATION:
			if active.stack_remaining.is_empty():
				active.stack_remaining.append(duration)
			elif active.stack_remaining[0] >= 0.0 and duration >= 0.0:
				active.stack_remaining[0] += duration

	active.context = context.duplicate(true)

	if definition.tick_interval > 0.0:
		active.tick_remaining = definition.tick_interval

	var current_stacks: int = active.get_stack_count()

	if current_stacks != previous_stacks:
		_sync_attribute_modifiers(active)
		effect_stacks_changed.emit(
			active,
			previous_stacks,
			current_stacks,
		)

	effect_refreshed.emit(active)
	effects_changed.emit()

	if definition.tick_on_apply and definition.tick_interval > 0.0:
		effect_ticked.emit(active)


func _refresh_shortest_stack(
	active: NucleusActiveStatusEffect,
	duration: float,
) -> void:
	if active.stack_remaining.is_empty():
		active.stack_remaining.append(duration)
		return

	var shortest_index: int = 0
	var shortest_value: float = INF

	for index: int in range(active.stack_remaining.size()):
		var remaining: float = active.stack_remaining[index]

		if remaining < 0.0:
			return

		if remaining < shortest_value:
			shortest_value = remaining
			shortest_index = index

	active.stack_remaining[shortest_index] = duration


func _sync_attribute_modifiers(
	active: NucleusActiveStatusEffect,
) -> void:
	if attribute_set == null:
		return

	var source_id: StringName = _get_modifier_source_id(
		active.get_effect_id()
	)

	if active.definition.modifiers.is_empty():
		attribute_set.remove_modifier_source(source_id)
		return

	attribute_set.set_modifier_source(
		source_id,
		active.definition.modifiers,
		active.get_stack_count(),
	)


func _get_modifier_source_id(
	effect_id: StringName,
) -> StringName:
	return StringName(
		SOURCE_PREFIX + String(effect_id)
	)


func _build_definition_registry() -> void:
	_definitions.clear()

	for definition: NucleusStatusEffectDefinition in known_effects:
		if definition:
			_register_definition(definition)


func _register_definition(
	definition: NucleusStatusEffectDefinition,
) -> void:
	if definition.effect_id == &"":
		NucleusLog.error(
			"Status effect definition has an empty id.",
			&"StatusEffects",
		)
		return

	if (
		_definitions.has(definition.effect_id)
		and _definitions[definition.effect_id] != definition
	):
		NucleusLog.warning(
			"Status effect '%s' definition was replaced."
			% definition.effect_id,
			&"StatusEffects",
		)

	_definitions[definition.effect_id] = definition


func _refresh_processing() -> void:
	_last_real_usec = Time.get_ticks_usec()
	var has_seconds: bool = false
	for active: NucleusActiveStatusEffect in _active.values():
		if active.definition.duration_unit == NucleusStatusEffectDefinition.DurationUnit.SECONDS:
			has_seconds = true
			break
	set_process(has_seconds)


func _find_attribute_set() -> NucleusAttributeSet:
	var root: Node = get_parent()

	while root:
		if root is NucleusAttributeSet:
			return root as NucleusAttributeSet

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusAttributeSet:
				return node as NucleusAttributeSet

		root = root.get_parent()

	return null
