extends "res://tests/headless/test_case.gd"

const DevelopmentValidation := preload(
	"res://addons/nucleus/modules/development_tools/validation/development_validation.gd"
)


class WarningNode:
	extends Node

	func _get_configuration_warnings() -> PackedStringArray:
		return PackedStringArray(["Synthetic configuration warning."])


class InvalidResource:
	extends Resource

	func get_validation_errors() -> PackedStringArray:
		return PackedStringArray(["Synthetic resource error."])


class ResourceHolder:
	extends Node

	@export var fixture: Resource


func run() -> Dictionary:
	_test_clean_node_tree()
	_test_configuration_warning_collection()
	_test_resource_error_collection()
	_test_exported_resource_collection()
	return finish()


func _test_clean_node_tree() -> void:
	var root := Node.new()
	root.name = "Root"

	if not _attach_fixture(root, "Clean validation fixture requires a live SceneTree."):
		return

	var report := DevelopmentValidation.validate_node_tree(root)
	expect_true(bool(report.get("ok", false)), "Clean node trees pass validation.")
	expect_equal(report.get("issue_count"), 0, "Clean node trees have no issues.")
	free_test_node(root)


func _test_configuration_warning_collection() -> void:
	var root := Node.new()
	root.name = "Root"
	var warning_node := WarningNode.new()
	warning_node.name = "WarningNode"
	root.add_child(warning_node)

	if not _attach_fixture(root, "Warning validation fixture requires a live SceneTree."):
		return

	var report := DevelopmentValidation.validate_node_tree(root)
	expect_equal(report.get("warning_count"), 1, "Node warnings are collected.")
	expect_equal(report.get("error_count"), 0, "Node warnings are not errors.")
	free_test_node(root)


func _test_resource_error_collection() -> void:
	var fixture := InvalidResource.new()
	var report := DevelopmentValidation.validate_resource_object(
		fixture,
		"fixture",
	)
	expect_equal(report.get("error_count"), 1, "Resource validation errors are collected.")
	expect_false(bool(report.get("ok", true)), "Resource errors fail validation.")


func _test_exported_resource_collection() -> void:
	var root := ResourceHolder.new()
	root.name = "Holder"
	root.fixture = InvalidResource.new()

	if not _attach_fixture(root, "Resource validation fixture requires a live SceneTree."):
		return

	var report := DevelopmentValidation.validate_node_tree(root)
	expect_equal(
		report.get("error_count"),
		1,
		"Resources exported by scene nodes participate in validation.",
	)
	free_test_node(root)


func _attach_fixture(node: Node, message: String) -> bool:
	var attached := attach_test_node(node)
	expect_true(attached, message)

	if not attached:
		node.free()

	return attached
