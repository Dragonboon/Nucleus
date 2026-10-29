class_name NucleusStatusRequirement
extends NucleusActionRequirement
## Gates one GameplayAction by active status effect ids/tags.

@export var status_container: NucleusStatusEffectContainer

@export_group("Required")
@export var required_effect_ids: Array[StringName] = []
@export var required_tags: Array[StringName] = []

@export_group("Blocked")
@export var blocked_effect_ids: Array[StringName] = []
@export var blocked_tags: Array[StringName] = []


func _ready() -> void:
	if status_container == null:
		status_container = _find_status_container()

	if status_container == null:
		NucleusLog.error(
			"%s requires a NucleusStatusEffectContainer." % get_path(),
			&"StatusRequirement",
		)
		return

	status_container.effects_changed.connect(
		notify_availability_changed
	)


func _exit_tree() -> void:
	if (
		status_container
		and status_container.effects_changed.is_connected(
			notify_availability_changed
		)
	):
		status_container.effects_changed.disconnect(
			notify_availability_changed
		)


func check(_context: Dictionary) -> Error:
	if status_container == null:
		return ERR_UNCONFIGURED

	for effect_id: StringName in required_effect_ids:
		if not status_container.has_effect(effect_id):
			return ERR_UNAVAILABLE

	for tag: StringName in required_tags:
		if not status_container.has_tag(tag):
			return ERR_UNAVAILABLE

	for effect_id: StringName in blocked_effect_ids:
		if status_container.has_effect(effect_id):
			return ERR_UNAVAILABLE

	if status_container.has_any_tag(blocked_tags):
		return ERR_UNAVAILABLE

	return OK


func _find_status_container() -> NucleusStatusEffectContainer:
	var root: Node = get_parent()

	while root:
		if root is NucleusStatusEffectContainer:
			return root as NucleusStatusEffectContainer

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusStatusEffectContainer:
				return node as NucleusStatusEffectContainer

		root = root.get_parent()

	return null
