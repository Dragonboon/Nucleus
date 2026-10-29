class_name NucleusApplyStatusEffect
extends NucleusActionEffect
## GameplayAction effect that applies a NucleusStatusEffectDefinition.

@export var definition: NucleusStatusEffectDefinition
@export var target_container: NucleusStatusEffectContainer

@export_group("Dynamic target")
@export var resolve_from_context: bool = false
@export var context_target_key: StringName = &"target"


func can_apply(context: Dictionary) -> Error:
	if definition == null:
		return ERR_UNCONFIGURED

	var container: NucleusStatusEffectContainer = _resolve_container(
		context
	)

	if container == null:
		return ERR_UNCONFIGURED

	return container.can_apply_effect(definition)


func apply(context: Dictionary) -> Error:
	var container: NucleusStatusEffectContainer = _resolve_container(
		context
	)

	if container == null or definition == null:
		return ERR_UNCONFIGURED

	return container.apply_effect(
		definition,
		context,
	)


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
			var node := dynamic_target as Node

			for descendant: Node in NucleusNodeUtils.descendants(
				node,
				true,
			):
				if descendant is NucleusStatusEffectContainer:
					return descendant as NucleusStatusEffectContainer

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
