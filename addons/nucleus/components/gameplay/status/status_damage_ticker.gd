class_name NucleusStatusDamageTicker
extends Node
## Routes matching status ticks through the existing DamageReceiver pipeline.

@export var status_container: NucleusStatusEffectContainer
@export var receiver: NucleusDamageReceiver

@export_group("Filter")
@export var effect_id: StringName
@export var required_tag: StringName

@export_group("Damage")
@export_range(0.0, 1.0e12, 0.01, "or_greater")
var damage_per_stack: float = 1.0
@export var additional_tags: Array[StringName] = []


func _ready() -> void:
	_resolve_dependencies()

	if status_container == null or receiver == null:
		NucleusLog.error(
			"%s requires StatusEffectContainer and DamageReceiver."
			% get_path(),
			&"StatusDamageTicker",
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

	var tags: Array = NucleusArrayUtils.unique(
		effect.definition.tags + additional_tags
	)
	var typed_tags: Array[StringName] = []

	for tag: Variant in tags:
		typed_tags.append(StringName(str(tag)))

	var source: Node
	var context_source: Variant = effect.context.get(
		"source"
	)

	if context_source is Node:
		source = context_source as Node

	var payload := NucleusHitPayload.new(
		damage_per_stack * effect.get_stack_count(),
		source,
		null,
		typed_tags,
		{
			"status_effect": effect.get_effect_id(),
		},
	)

	receiver.receive_hit(payload)


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
		or receiver == null
	):
		if status_container == null and root is NucleusStatusEffectContainer:
			status_container = root as NucleusStatusEffectContainer

		if receiver == null and root is NucleusDamageReceiver:
			receiver = root as NucleusDamageReceiver

		for node: Node in NucleusNodeUtils.descendants(root):
			if (
				status_container == null
				and node is NucleusStatusEffectContainer
			):
				status_container = node as NucleusStatusEffectContainer

			if receiver == null and node is NucleusDamageReceiver:
				receiver = node as NucleusDamageReceiver

		root = root.get_parent()
