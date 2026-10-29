class_name NucleusAttributeRequirement
extends NucleusActionRequirement
## Gates a GameplayAction by one effective Attribute value.

@export var attribute_set: NucleusAttributeSet
@export var attribute_id: StringName

@export_group("Range")
@export var use_minimum: bool = false
@export var minimum_value: float = 0.0
@export var use_maximum: bool = false
@export var maximum_value: float = 0.0


func _ready() -> void:
	if attribute_set == null:
		attribute_set = _find_attribute_set()

	if attribute_set == null:
		NucleusLog.error(
			"%s requires a NucleusAttributeSet." % get_path(),
			&"AttributeRequirement",
		)
		return

	if not attribute_set.has_attribute(attribute_id):
		NucleusLog.error(
			"Unknown attribute '%s' in %s."
			% [attribute_id, get_path()],
			&"AttributeRequirement",
		)
		return

	attribute_set.attribute_changed.connect(
		_on_attribute_changed
	)


func _exit_tree() -> void:
	if (
		attribute_set
		and attribute_set.attribute_changed.is_connected(
			_on_attribute_changed
		)
	):
		attribute_set.attribute_changed.disconnect(
			_on_attribute_changed
		)


func check(_context: Dictionary) -> Error:
	if attribute_set == null:
		return ERR_UNCONFIGURED

	if not attribute_set.has_attribute(attribute_id):
		return ERR_DOES_NOT_EXIST

	var value: float = attribute_set.get_value(attribute_id)

	if use_minimum and value < minimum_value:
		return ERR_UNAVAILABLE

	if use_maximum and value > maximum_value:
		return ERR_UNAVAILABLE

	return OK


func _on_attribute_changed(
	changed_id: StringName,
	_value: float,
	_previous_value: float,
) -> void:
	if changed_id == attribute_id:
		notify_availability_changed()


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
