extends RefCounted

var _checks: int = 0
var _failures := PackedStringArray()


func expect_true(value: bool, message: String) -> void:
	_checks += 1

	if not value:
		_failures.append(message)


func expect_false(value: bool, message: String) -> void:
	expect_true(not value, message)


func expect_equal(
	actual: Variant,
	expected: Variant,
	message: String,
) -> void:
	_checks += 1

	if actual != expected:
		_failures.append(
			"%s (expected=%s actual=%s)"
			% [message, str(expected), str(actual)]
		)


func expect_float(
	actual: float,
	expected: float,
	message: String,
) -> void:
	_checks += 1

	if not is_equal_approx(actual, expected):
		_failures.append(
			"%s (expected=%s actual=%s)"
			% [message, str(expected), str(actual)]
		)


## Attaches a parentless test subtree to the active SceneTree root.
## Use this before testing APIs that require global transforms or lifecycle.
func attach_test_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	if node.is_inside_tree():
		return true

	if node.get_parent() != null:
		return false

	var main_loop := Engine.get_main_loop()

	if not main_loop is SceneTree:
		return false

	var tree := main_loop as SceneTree
	tree.root.add_child(node)
	return node.is_inside_tree()


func free_test_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	node.free()


func finish() -> Dictionary:
	return {
		"checks": _checks,
		"failures": _failures,
	}


## Caller declares candidates explicitly; this does not infer arbitrary state writers.
func expect_single_binding(candidates: Array[Node], property: StringName, target: Node) -> void:
	var matches := 0
	for candidate in candidates:
		if is_instance_valid(candidate) and property in candidate:
			if candidate.get(property) == target:
				matches += 1
	expect_equal(matches, 1, "Exactly one declared component must bind %s." % property)


func expect_composition_binding(component: Node, property: StringName, target: Node) -> void:
	var valid := is_instance_valid(component) and is_instance_valid(target)
	expect_true(valid and property in component and component.get(property) == target,
		"Composition binding %s must reference its actual target." % property)


func expect_composition_signal(source: Signal, callback: Callable) -> void:
	expect_true(not source.is_null() and callback.is_valid() and source.is_connected(callback),
		"Composition callback must be connected to its actual signal owner.")
