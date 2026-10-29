class_name NucleusAttributeSet
extends Node
## Scene-owned numeric attribute runtime with source-based modifiers.
##
## Base values are persistent actor data. Modifier sources are runtime overlays
## supplied by systems such as status effects, equipment, perks, or difficulty.

signal attribute_changed(
	attribute_id: StringName,
	value: float,
	previous_value: float,
)
signal base_value_changed(
	attribute_id: StringName,
	base_value: float,
)
signal modifier_source_changed(source_id: StringName)

@export var definitions: Array[NucleusAttributeDefinition] = []

var _definitions: Dictionary[StringName, NucleusAttributeDefinition] = {}
var _base_values: Dictionary[StringName, float] = {}
var _values: Dictionary[StringName, float] = {}

## source_id -> {"modifiers": Array[NucleusAttributeModifier], "stacks": int}
var _modifier_sources: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	_build_definitions()


func has_attribute(attribute_id: StringName) -> bool:
	return _definitions.has(attribute_id)


func get_value(
	attribute_id: StringName,
	fallback: float = 0.0,
) -> float:
	return _values.get(attribute_id, fallback)


func get_base_value(
	attribute_id: StringName,
	fallback: float = 0.0,
) -> float:
	return _base_values.get(attribute_id, fallback)


func set_base_value(
	attribute_id: StringName,
	value: float,
) -> Error:
	if not has_attribute(attribute_id):
		return ERR_DOES_NOT_EXIST

	if is_equal_approx(
		_base_values[attribute_id],
		value,
	):
		return OK

	_base_values[attribute_id] = value
	base_value_changed.emit(
		attribute_id,
		value,
	)
	_recalculate_attribute(attribute_id)

	return OK


func set_modifier_source(
	source_id: StringName,
	modifiers: Array[NucleusAttributeModifier],
	stack_count: int = 1,
) -> Error:
	if source_id == &"":
		return ERR_INVALID_PARAMETER

	var safe_modifiers: Array[NucleusAttributeModifier] = []

	for modifier: NucleusAttributeModifier in modifiers:
		if modifier == null:
			continue

		if not has_attribute(modifier.attribute_id):
			NucleusLog.warning(
				"Modifier source '%s' references unknown attribute '%s'."
				% [source_id, modifier.attribute_id],
				&"Attributes",
			)
			continue

		safe_modifiers.append(modifier)

	_modifier_sources[source_id] = {
		"modifiers": safe_modifiers,
		"stacks": maxi(1, stack_count),
	}

	_recalculate_all()
	modifier_source_changed.emit(source_id)

	return OK


func update_modifier_source_stacks(
	source_id: StringName,
	stack_count: int,
) -> Error:
	if not _modifier_sources.has(source_id):
		return ERR_DOES_NOT_EXIST

	var source: Dictionary = _modifier_sources[source_id]
	source["stacks"] = maxi(
		1,
		stack_count,
	)
	_modifier_sources[source_id] = source

	_recalculate_all()
	modifier_source_changed.emit(source_id)

	return OK


func remove_modifier_source(source_id: StringName) -> bool:
	if not _modifier_sources.has(source_id):
		return false

	_modifier_sources.erase(source_id)
	_recalculate_all()
	modifier_source_changed.emit(source_id)

	return true


func has_modifier_source(source_id: StringName) -> bool:
	return _modifier_sources.has(source_id)


func clear_modifier_sources() -> void:
	if _modifier_sources.is_empty():
		return

	var source_ids: Array = _modifier_sources.keys()
	_modifier_sources.clear()
	_recalculate_all()

	for source_id: Variant in source_ids:
		modifier_source_changed.emit(
			StringName(str(source_id))
		)


func get_attribute_ids() -> Array[StringName]:
	var result: Array[StringName] = []

	for attribute_id: StringName in _definitions:
		result.append(attribute_id)

	return result


func capture_state() -> Dictionary:
	var base_values: Dictionary = {}

	for attribute_id: StringName in _base_values:
		base_values[String(attribute_id)] = (
			_base_values[attribute_id]
		)

	return {
		"base_values": base_values,
	}


func restore_state(data: Dictionary) -> void:
	var stored_values: Variant = data.get(
		"base_values",
		{},
	)

	if not stored_values is Dictionary:
		return

	for key: Variant in stored_values:
		var attribute_id := StringName(str(key))

		if not has_attribute(attribute_id):
			continue

		_base_values[attribute_id] = float(
			stored_values[key]
		)

	_recalculate_all()


func _build_definitions() -> void:
	_definitions.clear()
	_base_values.clear()
	_values.clear()

	for definition: NucleusAttributeDefinition in definitions:
		if definition == null:
			continue

		if definition.attribute_id == &"":
			NucleusLog.error(
				"Attribute definition has an empty id.",
				&"Attributes",
			)
			continue

		if _definitions.has(definition.attribute_id):
			NucleusLog.error(
				"Duplicate attribute id '%s'."
				% definition.attribute_id,
				&"Attributes",
			)
			continue

		_definitions[definition.attribute_id] = definition
		_base_values[definition.attribute_id] = (
			definition.base_value
		)
		_values[definition.attribute_id] = (
			definition.clamp_value(
				definition.base_value
			)
		)


func _recalculate_all() -> void:
	for attribute_id: StringName in _definitions:
		_recalculate_attribute(attribute_id)


func _recalculate_attribute(
	attribute_id: StringName,
) -> void:
	if not has_attribute(attribute_id):
		return

	var previous_value: float = _values[attribute_id]
	var value: float = _base_values[attribute_id]

	var flat_add: float = 0.0
	var percent_add: float = 0.0
	var multiplier: float = 1.0

	var has_override: bool = false
	var override_value: float = 0.0
	var override_priority: int = -2147483648
	var override_key: String = ""

	for source_id: StringName in _modifier_sources:
		var source: Dictionary = _modifier_sources[source_id]
		var stacks: int = int(source["stacks"])
		var modifiers: Array = source["modifiers"]

		for index: int in range(modifiers.size()):
			var modifier: NucleusAttributeModifier = modifiers[index]

			if modifier.attribute_id != attribute_id:
				continue

			var effective: float = modifier.get_effective_value(
				stacks
			)

			match modifier.operation:
				NucleusAttributeModifier.Operation.ADD:
					flat_add += effective

				NucleusAttributeModifier.Operation.ADD_PERCENT:
					percent_add += effective

				NucleusAttributeModifier.Operation.MULTIPLY:
					multiplier *= effective

				NucleusAttributeModifier.Operation.OVERRIDE:
					var candidate_key: String = (
						"%s:%06d"
						% [source_id, index]
					)

					if (
						not has_override
						or modifier.priority > override_priority
						or (
							modifier.priority == override_priority
							and candidate_key > override_key
						)
					):
						has_override = true
						override_value = effective
						override_priority = modifier.priority
						override_key = candidate_key

	value = (
		(value + flat_add)
		* (1.0 + percent_add)
		* multiplier
	)

	if has_override:
		value = override_value

	value = _definitions[attribute_id].clamp_value(value)
	_values[attribute_id] = value

	if not is_equal_approx(previous_value, value):
		attribute_changed.emit(
			attribute_id,
			value,
			previous_value,
		)
