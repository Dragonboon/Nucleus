class_name NucleusNodeUtils
extends RefCounted
## Traversal helpers that complement Godot's Node find APIs.


static func descendants(
	root: Node,
	include_internal: bool = false,
) -> Array[Node]:
	var result: Array[Node] = []

	if root == null:
		return result

	_append_descendants(
		root,
		result,
		include_internal,
	)

	return result


## Returns parents from nearest to farthest.
static func ancestors(
	node: Node,
	include_tree_root: bool = true,
) -> Array[Node]:
	var result: Array[Node] = []

	if node == null:
		return result

	var current: Node = node.get_parent()

	while current:
		if (
			include_tree_root
			or current.get_parent() != null
		):
			result.append(current)

		current = current.get_parent()

	return result


static func tree_depth(node: Node) -> int:
	var depth: int = 0
	var current: Node = node

	while current and current.get_parent():
		depth += 1
		current = current.get_parent()

	return depth


## Sets a PackedScene owner recursively without changing tree structure.
static func set_owner_recursive(
	root: Node,
	owner: Node,
	include_root: bool = false,
) -> void:
	if root == null:
		return

	if include_root:
		root.owner = owner

	for child: Node in descendants(root, true):
		child.owner = owner


static func _append_descendants(
	root: Node,
	result: Array[Node],
	include_internal: bool,
) -> void:
	for child: Node in root.get_children(
		include_internal,
	):
		result.append(child)
		_append_descendants(
			child,
			result,
			include_internal,
		)
