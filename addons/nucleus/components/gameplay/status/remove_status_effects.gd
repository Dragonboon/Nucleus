class_name NucleusRemoveStatusEffects
extends NucleusActionEffect
## GameplayAction effect for cleanse/dispel-style status removal.

@export var target_container: NucleusStatusEffectContainer

@export_group("Selection")
@export var clear_all: bool = false
@export var effect_ids: Array[StringName] = []
@export var tags: Array[StringName] = []

@export_group("Dynamic target")
@export var resolve_from_context: bool = false
@export var context_target_key: StringName = &"target"


func can_apply(context: Dictionary) -> Error:
	return (
		OK
		if _resolve_container(context)
		else ERR_UNCONFIGURED
	)


func apply(context: Dictionary) -> Error:
	var container: NucleusStatusEffectContainer = _resolve_container(
		context
	)

	if container == null:
		return ERR_UNCONFIGURED

	if clear_all:
		container.clear_effects(&"action_remove")
		return OK

	for effect_id: StringName in effect_ids:
		container.remove_effect(
			effect_id,
			&"action_remove",
		)

	for tag: StringName in tags:
		container.remove_effects_with_tag(
			tag,
			&"action_remove",
		)

	return OK


func _resolve_container(
	context: Dictionary,
) -> NucleusStatusEffectContainer:
	if resolve_from_context:
		var dynamic_target: Variant = context.get(
			context_target_key
		)

		if dynamic_target is NucleusStatusEffectContainer:
			return dynamic_target as NucleusStatusEffectContainer

		if dynamic_target is Node:
			for node: Node in NucleusNodeUtils.descendants(
				dynamic_target as Node,
				true,
			):
				if node is NucleusStatusEffectContainer:
					return node as NucleusStatusEffectContainer

	if target_container:
		return target_container

	var root: Node = get_parent()

	while root:
		if root is NucleusStatusEffectContainer:
			return root as NucleusStatusEffectContainer

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusStatusEffectContainer:
				return node as NucleusStatusEffectContainer

		root = root.get_parent()

	return null
