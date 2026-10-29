class_name NucleusValuePoolAttributeBinding
extends Node
## Applies Attribute values to NucleusValuePool limits through set_limits().
##
## This specialized binding avoids mutating maximum_value directly and keeps the
## pool's clamping/signals semantics intact.

@export var attribute_set: NucleusAttributeSet
@export var target_pool: NucleusValuePool

@export_group("Attributes")
@export var minimum_attribute: StringName
@export var maximum_attribute: StringName
@export var overflow_attribute: StringName

@export_group("Behavior")
@export var preserve_ratio: bool = true


func _ready() -> void:
	_resolve_dependencies()

	if attribute_set == null or target_pool == null:
		NucleusLog.error(
			"%s requires AttributeSet and ValuePool." % get_path(),
			&"PoolAttributeBinding",
		)
		return

	attribute_set.attribute_changed.connect(
		_on_attribute_changed
	)
	_apply_limits()


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


func _apply_limits() -> void:
	var minimum: float = target_pool.minimum_value
	var maximum: float = target_pool.maximum_value
	var overflow: float = target_pool.overflow_limit

	if (
		minimum_attribute != &""
		and attribute_set.has_attribute(minimum_attribute)
	):
		minimum = attribute_set.get_value(minimum_attribute)

	if (
		maximum_attribute != &""
		and attribute_set.has_attribute(maximum_attribute)
	):
		maximum = attribute_set.get_value(maximum_attribute)

	if (
		overflow_attribute != &""
		and attribute_set.has_attribute(overflow_attribute)
	):
		overflow = attribute_set.get_value(overflow_attribute)

	target_pool.set_limits(
		minimum,
		maximum,
		maxf(0.0, overflow),
		preserve_ratio,
	)


func _on_attribute_changed(
	attribute_id: StringName,
	_value: float,
	_previous_value: float,
) -> void:
	if attribute_id in [
		minimum_attribute,
		maximum_attribute,
		overflow_attribute,
	]:
		_apply_limits()


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and attribute_set == null:
		if root is NucleusAttributeSet:
			attribute_set = root as NucleusAttributeSet
			break

		var attribute_sets: Array[NucleusAttributeSet] = []

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusAttributeSet:
				attribute_sets.append(node as NucleusAttributeSet)

		if attribute_sets.size() == 1:
			attribute_set = attribute_sets[0]
			break

		if attribute_sets.size() > 1:
			NucleusLog.warning(
				"%s found multiple AttributeSets; assign one explicitly."
				% get_path(),
				&"PoolAttributeBinding",
			)
			break

		root = root.get_parent()

	if target_pool != null:
		return

	if get_parent() is NucleusValuePool:
		target_pool = get_parent() as NucleusValuePool
		return

	root = get_parent()

	while root:
		var pools: Array[NucleusValuePool] = []

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusValuePool:
				pools.append(node as NucleusValuePool)

		if pools.size() == 1:
			target_pool = pools[0]
			return

		if pools.size() > 1:
			NucleusLog.warning(
				"%s found multiple ValuePools; assign target_pool explicitly."
				% get_path(),
				&"PoolAttributeBinding",
			)
			return

		root = root.get_parent()
