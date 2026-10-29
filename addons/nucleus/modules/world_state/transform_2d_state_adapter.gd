@tool
class_name NucleusTransform2DStateAdapter
extends NucleusWorldStateAdapter
## JSON-safe Transform2D persistence for a Node2D.

@export var target: Node2D:
	set(value):
		target = value
		update_configuration_warnings()

@export var use_global_transform: bool = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()

	if _resolve_target() == null:
		warnings.append(
			"Assign a Node2D target or parent this adapter under one."
		)

	return warnings


func capture_state() -> Variant:
	var resolved: Node2D = _resolve_target()

	if resolved == null:
		return {}

	var transform: Transform2D = (
		resolved.global_transform
		if use_global_transform
		else resolved.transform
	)

	return {
		"x": [
			transform.x.x,
			transform.x.y,
		],
		"y": [
			transform.y.x,
			transform.y.y,
		],
		"origin": [
			transform.origin.x,
			transform.origin.y,
		],
	}


func restore_state(state: Variant) -> void:
	var resolved: Node2D = _resolve_target()

	if resolved == null or not state is Dictionary:
		return

	var values: Dictionary = state
	var x_value: Variant = values.get("x", [])
	var y_value: Variant = values.get("y", [])
	var origin_value: Variant = values.get("origin", [])

	if (
		not x_value is Array
		or not y_value is Array
		or not origin_value is Array
	):
		return

	var x_values: Array = x_value
	var y_values: Array = y_value
	var origin_values: Array = origin_value

	if (
		x_values.size() != 2
		or y_values.size() != 2
		or origin_values.size() != 2
	):
		return

	var transform := Transform2D(
		Vector2(
			float(x_values[0]),
			float(x_values[1]),
		),
		Vector2(
			float(y_values[0]),
			float(y_values[1]),
		),
		Vector2(
			float(origin_values[0]),
			float(origin_values[1]),
		),
	)

	if use_global_transform:
		resolved.global_transform = transform
	else:
		resolved.transform = transform


func _resolve_target() -> Node2D:
	if target != null:
		return target

	return get_parent() as Node2D
