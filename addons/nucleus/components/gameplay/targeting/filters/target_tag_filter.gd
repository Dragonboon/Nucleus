class_name NucleusTargetTagFilter
extends NucleusTargetFilter
## Accepts/rejects Targetables by project-owned StringName tags.

@export var required_tags: Array[StringName] = []
@export var require_all_required_tags: bool = true
@export var blocked_tags: Array[StringName] = []


func accepts(
	_agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	if target == null:
		return false

	if (
		not blocked_tags.is_empty()
		and target.has_any_tag(blocked_tags)
	):
		return false

	if required_tags.is_empty():
		return true

	if require_all_required_tags:
		return target.has_all_tags(required_tags)

	return target.has_any_tag(required_tags)
