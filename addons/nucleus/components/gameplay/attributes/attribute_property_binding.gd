class_name NucleusAttributePropertyBinding
extends Node
## Pushes one NucleusAttributeSet value into an existing Godot/Nucleus property.
##
## Object.set_indexed() keeps this adapter generic without teaching Attributes
## about CharacterMotor, DamageReceiver, Camera, or game-specific scripts.

@export var attribute_set: NucleusAttributeSet
@export var attribute_id: StringName

@export_group("Target")
@export var target: Node
@export var property_path: NodePath

@export_group("Transform")
@export var value_scale: float = 1.0
@export var value_offset: float = 0.0


func _ready() -> void:
	if attribute_set == null:
		attribute_set = _find_attribute_set()

	if target == null:
		target = get_parent()

	if attribute_set == null:
		NucleusLog.error(
			"%s requires a NucleusAttributeSet." % get_path(),
			&"AttributeBinding",
		)
		return

	if target == null or property_path.is_empty():
		NucleusLog.error(
			"%s requires target and property_path." % get_path(),
			&"AttributeBinding",
		)
		return

	if not attribute_set.has_attribute(attribute_id):
		NucleusLog.error(
			"Unknown attribute '%s' in %s."
			% [attribute_id, get_path()],
			&"AttributeBinding",
		)
		return

	attribute_set.attribute_changed.connect(
		_on_attribute_changed
	)
	_apply_value(
		attribute_set.get_value(attribute_id)
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


func refresh() -> void:
	if attribute_set and attribute_set.has_attribute(attribute_id):
		_apply_value(
			attribute_set.get_value(attribute_id)
		)


func _apply_value(value: float) -> void:
	if target == null:
		return

	target.set_indexed(
		property_path,
		value * value_scale + value_offset,
	)


func _on_attribute_changed(
	changed_id: StringName,
	value: float,
	_previous_value: float,
) -> void:
	if changed_id == attribute_id:
		_apply_value(value)


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
