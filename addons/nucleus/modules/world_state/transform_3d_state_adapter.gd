@tool
class_name NucleusTransform3DStateAdapter
extends NucleusWorldStateAdapter
## JSON-safe Transform3D persistence for a Node3D.

@export var target: Node3D:
	set(value):
		target = value
		update_configuration_warnings()

@export var use_global_transform: bool = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()

	if _resolve_target() == null:
		warnings.append(
			"Assign a Node3D target or parent this adapter under one."
		)

	return warnings


func capture_state() -> Variant:
	var resolved: Node3D = _resolve_target()

	if resolved == null:
		return {}

	var transform: Transform3D = (
		resolved.global_transform
		if use_global_transform
		else resolved.transform
	)

	return {
		"basis": [
			transform.basis.x.x,
			transform.basis.x.y,
			transform.basis.x.z,
			transform.basis.y.x,
			transform.basis.y.y,
			transform.basis.y.z,
			transform.basis.z.x,
			transform.basis.z.y,
			transform.basis.z.z,
		],
		"origin": [
			transform.origin.x,
			transform.origin.y,
			transform.origin.z,
		],
	}


func restore_state(state: Variant) -> void:
	var resolved: Node3D = _resolve_target()

	if resolved == null or not state is Dictionary:
		return

	var values: Dictionary = state
	var basis_value: Variant = values.get(
		"basis",
		[],
	)
	var origin_value: Variant = values.get(
		"origin",
		[],
	)

	if not basis_value is Array or not origin_value is Array:
		return

	var basis_values: Array = basis_value
	var origin_values: Array = origin_value

	if basis_values.size() != 9 or origin_values.size() != 3:
		return

	var transform := Transform3D(
		Basis(
			Vector3(
				float(basis_values[0]),
				float(basis_values[1]),
				float(basis_values[2]),
			),
			Vector3(
				float(basis_values[3]),
				float(basis_values[4]),
				float(basis_values[5]),
			),
			Vector3(
				float(basis_values[6]),
				float(basis_values[7]),
				float(basis_values[8]),
			),
		),
		Vector3(
			float(origin_values[0]),
			float(origin_values[1]),
			float(origin_values[2]),
		),
	)

	if use_global_transform:
		resolved.global_transform = transform
	else:
		resolved.transform = transform


func _resolve_target() -> Node3D:
	if target != null:
		return target

	return get_parent() as Node3D
