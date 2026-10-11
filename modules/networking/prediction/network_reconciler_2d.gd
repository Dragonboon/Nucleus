class_name NucleusNetworkReconciler2D
extends RefCounted
## Replay-only helper; the consuming game owns simulation and transforms.
var history := NucleusNetworkInputBuffer.new()
var fixed_delta: float = 1.0 / 30.0

func record(sequence: int, command: Dictionary, predicted: Dictionary) -> bool:
	var point: Variant = predicted.get("position")
	return point is Vector2 and point.is_finite() and history.push(sequence, command, predicted)

## simulate(state, command, delta) must return finite positional state.
func reconcile(sequence: int, authoritative: Dictionary, simulate: Callable) -> Dictionary:
	var point: Variant = authoritative.get("position")
	if not point is Vector2 or not point.is_finite() or not simulate.is_valid():
		return {}
	if sequence <= history.last_acknowledged() or not history.has_sequence(sequence):
		return {}
	var state: Dictionary = authoritative.duplicate(true)
	var replayed: Array[Dictionary] = []
	for entry in history.pending_after(sequence):
		var next_state: Variant = simulate.call(
			state.duplicate(true), (entry["command"] as Dictionary).duplicate(true), fixed_delta
		)
		if not next_state is Dictionary:
			return {}
		var next_point: Variant = (next_state as Dictionary).get("position")
		if not next_point is Vector2 or not next_point.is_finite():
			return {}
		state = (next_state as Dictionary).duplicate(true)
		replayed.append(state.duplicate(true))
	if not history.commit(sequence, replayed):
		return {}
	return {"state": state, "replayed": replayed.size()}

func reset() -> void:
	history.reset()
