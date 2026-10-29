class_name NucleusPerformanceSnapshot
extends RefCounted
## One sampled view of native/custom performance metrics.

var sequence: int = 0
var timestamp_usec: int = 0
var values: Dictionary = {}


func set_metric(id: StringName, value: float) -> void:
	values[id] = value


func has_metric(id: StringName) -> bool:
	return values.has(id)


func get_metric(id: StringName, fallback: float = 0.0) -> float:
	return float(values.get(id, fallback))


func delta_from(
	previous: NucleusPerformanceSnapshot,
	id: StringName,
) -> float:
	if previous == null:
		return 0.0

	return get_metric(id) - previous.get_metric(id)


func to_dictionary() -> Dictionary:
	var serialized_values: Dictionary = {}

	for id: Variant in values:
		serialized_values[str(id)] = values[id]

	return {
		"sequence": sequence,
		"timestamp_usec": timestamp_usec,
		"values": serialized_values,
	}
