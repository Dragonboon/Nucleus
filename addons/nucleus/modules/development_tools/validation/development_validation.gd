class_name NucleusDevelopmentValidation extends RefCounted
## Shared scene/resource validation backend for local tools and headless checks.

enum Severity {
	WARNING,
	ERROR,
}


static func validate_node_tree(root: Node) -> Dictionary:
	if root == null:
		return _report("<null node>", [_issue(
			Severity.ERROR,
			"node",
			"<null>",
			"Validation root is null.",
		)])

	var issues: Array[Dictionary] = []
	var visited_resources: Dictionary = {}
	_collect_node(root, root, issues, visited_resources)
	return _report(_node_report_target(root), issues)


static func validate_scene(scene_path: String) -> Dictionary:
	var normalized := scene_path.strip_edges()
	if normalized.is_empty():
		return _report("<empty scene path>", [_issue(
			Severity.ERROR,
			"scene",
			"<empty>",
			"Scene path cannot be empty.",
		)])

	var loaded := ResourceLoader.load(normalized)
	if not loaded is PackedScene:
		return _report(normalized, [_issue(
			Severity.ERROR,
			"scene",
			normalized,
			"Path does not resolve to a PackedScene.",
		)])

	var instance := (loaded as PackedScene).instantiate()
	if instance == null:
		return _report(normalized, [_issue(
			Severity.ERROR,
			"scene",
			normalized,
			"PackedScene could not be instantiated.",
		)])

	var issues: Array[Dictionary] = []
	var visited_resources: Dictionary = {}
	_collect_node(instance, instance, issues, visited_resources)
	instance.free()
	return _report(normalized, issues)


static func validate_resource(resource_path: String) -> Dictionary:
	var normalized := resource_path.strip_edges()
	if normalized.is_empty():
		return _report("<empty resource path>", [_issue(
			Severity.ERROR,
			"resource",
			"<empty>",
			"Resource path cannot be empty.",
		)])

	var loaded := ResourceLoader.load(normalized)
	if not loaded is Resource:
		return _report(normalized, [_issue(
			Severity.ERROR,
			"resource",
			normalized,
			"Path does not resolve to a Resource.",
		)])

	return validate_resource_object(loaded as Resource, normalized)


static func validate_resource_object(
	resource: Resource,
	context_path: String = "<resource>",
) -> Dictionary:
	if resource == null:
		return _report(context_path, [_issue(
			Severity.ERROR,
			"resource",
			context_path,
			"Resource is null.",
		)])

	var issues: Array[Dictionary] = []
	var visited_resources: Dictionary = {}
	_collect_resource(resource, context_path, issues, visited_resources)
	return _report(context_path, issues)


static func format_report(report: Dictionary) -> String:
	var issues: Array = report.get("issues", [])
	var target := str(report.get("target", "<unknown>"))
	if issues.is_empty():
		return "Validation passed: %s" % target

	var lines := PackedStringArray()
	lines.append(
		"Validation: %d issue(s), %d warning(s), %d error(s) — %s"
		% [
			int(report.get("issue_count", issues.size())),
			int(report.get("warning_count", 0)),
			int(report.get("error_count", 0)),
			target,
		]
	)
	for value: Variant in issues:
		var issue := value as Dictionary
		lines.append(
			"[%s] %s: %s"
			% [
				str(issue.get("severity", "WARNING")),
				str(issue.get("path", "<unknown>")),
				str(issue.get("message", "")),
			]
		)
	return "
".join(lines)


static func _collect_node(
	node: Node,
	root: Node,
	issues: Array[Dictionary],
	visited_resources: Dictionary,
) -> void:
	var node_path := _relative_node_path(root, node)

	if node.has_method("_get_configuration_warnings"):
		var raw_warnings: Variant = node.call("_get_configuration_warnings")
		if raw_warnings is PackedStringArray or raw_warnings is Array:
			for warning: Variant in raw_warnings:
				var message := str(warning).strip_edges()
				if not message.is_empty():
					issues.append(_issue(
						Severity.WARNING,
						"node",
						node_path,
						message,
					))

	_collect_object_resources(node, node_path, issues, visited_resources)
	for child: Node in node.get_children():
		_collect_node(child, root, issues, visited_resources)


static func _collect_object_resources(
	object: Object,
	context_path: String,
	issues: Array[Dictionary],
	visited_resources: Dictionary,
) -> void:
	for property: Dictionary in object.get_property_list():
		var usage := int(property.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name := str(property.get("name", ""))
		if property_name.is_empty() or property_name == "script":
			continue
		var value: Variant = object.get(property_name)
		_collect_resource_value(
			value,
			"%s.%s" % [context_path, property_name],
			issues,
			visited_resources,
		)


static func _collect_resource_value(
	value: Variant,
	context_path: String,
	issues: Array[Dictionary],
	visited_resources: Dictionary,
) -> void:
	if value is Resource:
		_collect_resource(
			value as Resource,
			context_path,
			issues,
			visited_resources,
		)
		return
	if value is Array:
		for index: int in range(value.size()):
			_collect_resource_value(
				value[index],
				"%s[%d]" % [context_path, index],
				issues,
				visited_resources,
			)
		return
	if value is Dictionary:
		for key: Variant in value.keys():
			_collect_resource_value(
				value[key],
				"%s[%s]" % [context_path, str(key)],
				issues,
				visited_resources,
			)


static func _collect_resource(
	resource: Resource,
	context_path: String,
	issues: Array[Dictionary],
	visited_resources: Dictionary,
) -> void:
	if resource == null:
		return
	var instance_id := resource.get_instance_id()
	if visited_resources.has(instance_id):
		return
	visited_resources[instance_id] = true

	var display_path := context_path
	if not resource.resource_path.is_empty():
		display_path = resource.resource_path

	if resource.has_method("get_validation_errors"):
		var raw_errors: Variant = resource.call("get_validation_errors")
		if raw_errors is PackedStringArray or raw_errors is Array:
			for error: Variant in raw_errors:
				var message := str(error).strip_edges()
				if not message.is_empty():
					issues.append(_issue(
						Severity.ERROR,
						"resource",
						display_path,
						message,
					))

	_collect_object_resources(resource, context_path, issues, visited_resources)


static func _node_report_target(root: Node) -> String:
	if root.is_inside_tree():
		return str(root.get_path())

	if not root.name.is_empty():
		return "<detached>/%s" % root.name

	return "<detached node>"


static func _relative_node_path(root: Node, node: Node) -> String:
	if root == node:
		return "."

	var parts := PackedStringArray()
	var current := node

	while current != null and current != root:
		parts.insert(0, str(current.name))
		current = current.get_parent()

	if current != root:
		return str(node.name)

	return "/".join(parts)


static func _report(target: String, issues: Array[Dictionary]) -> Dictionary:
	var warning_count := 0
	var error_count := 0
	for issue: Dictionary in issues:
		match str(issue.get("severity", "WARNING")):
			"ERROR":
				error_count += 1
			_:
				warning_count += 1
	return {
		"target": target,
		"issues": issues,
		"issue_count": issues.size(),
		"warning_count": warning_count,
		"error_count": error_count,
		"ok": issues.is_empty(),
	}


static func _issue(
	severity: Severity,
	source: String,
	path: String,
	message: String,
) -> Dictionary:
	return {
		"severity": "ERROR" if severity == Severity.ERROR else "WARNING",
		"source": source,
		"path": path,
		"message": message,
	}
