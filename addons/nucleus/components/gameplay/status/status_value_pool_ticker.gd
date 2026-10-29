class_name NucleusStatusValuePoolTicker
extends Node
## Applies ValuePool deltas whenever matching status effects tick.

@export var status_container: NucleusStatusEffectContainer
@export var target_pool: NucleusValuePool

@export_group("Filter")
@export var effect_id: StringName
@export var required_tag: StringName

@export_group("Delta")
@export var delta_per_stack: float = 0.0
@export var allow_positive_overflow: bool = false


func _ready() -> void:
	_resolve_dependencies()

	if status_container == null or target_pool == null:
		NucleusLog.error(
			"%s requires StatusEffectContainer and ValuePool." % get_path(),
			&"StatusPoolTicker",
		)
		return

	status_container.effect_ticked.connect(
		_on_effect_ticked
	)


func _exit_tree() -> void:
	if (
		status_container
		and status_container.effect_ticked.is_connected(
			_on_effect_ticked
		)
	):
		status_container.effect_ticked.disconnect(
			_on_effect_ticked
		)


func _on_effect_ticked(
	effect: NucleusActiveStatusEffect,
) -> void:
	if not _matches(effect):
		return

	var delta: float = (
		delta_per_stack
		* effect.get_stack_count()
	)

	if delta > 0.0:
		target_pool.increase(
			delta,
			allow_positive_overflow,
		)
	elif delta < 0.0:
		target_pool.decrease(absf(delta))


func _matches(
	effect: NucleusActiveStatusEffect,
) -> bool:
	if effect == null or effect.definition == null:
		return false

	if (
		effect_id != &""
		and effect.get_effect_id() != effect_id
	):
		return false

	if (
		required_tag != &""
		and not effect.definition.has_tag(required_tag)
	):
		return false

	return effect_id != &"" or required_tag != &""


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and (
		status_container == null
		or target_pool == null
	):
		if status_container == null and root is NucleusStatusEffectContainer:
			status_container = root as NucleusStatusEffectContainer

		if target_pool == null and root is NucleusValuePool:
			target_pool = root as NucleusValuePool

		for node: Node in NucleusNodeUtils.descendants(root):
			if (
				status_container == null
				and node is NucleusStatusEffectContainer
			):
				status_container = node as NucleusStatusEffectContainer

			if target_pool == null and node is NucleusValuePool:
				target_pool = node as NucleusValuePool

		root = root.get_parent()
