class_name NucleusSaveResumePolicy
extends RefCounted
## Deterministic selection policy for choosing the newest usable save candidate.
##
## Timestamp wins first. Kind order is used only when timestamps are identical.


static func default_kind_order() -> PackedInt32Array:
	return PackedInt32Array([
		NucleusSaveTypes.Kind.AUTOSAVE,
		NucleusSaveTypes.Kind.QUICKSAVE,
		NucleusSaveTypes.Kind.MANUAL,
	])


static func normalize_kind_order(
	kinds: PackedInt32Array,
) -> PackedInt32Array:
	var source := kinds

	if source.is_empty():
		source = default_kind_order()

	var normalized := PackedInt32Array()

	for kind: int in source:
		if not _is_valid_kind(kind):
			continue
		if kind not in normalized:
			normalized.append(kind)

	return normalized


static func choose_latest(
	candidates: Array[NucleusSaveResult],
	kind_order: PackedInt32Array = PackedInt32Array(),
) -> NucleusSaveResult:
	var order := normalize_kind_order(kind_order)
	var best: NucleusSaveResult = null
	var best_time_usec: int = -1
	var best_priority: int = 2147483647

	for candidate: NucleusSaveResult in candidates:
		if (
			candidate == null
			or not candidate.succeeded()
			or candidate.document == null
		):
			continue

		var priority := order.find(candidate.document.kind)
		if priority < 0:
			continue

		var candidate_time := candidate.document.get_updated_at_usec()

		if (
			best == null
			or candidate_time > best_time_usec
			or (
				candidate_time == best_time_usec
				and priority < best_priority
			)
		):
			best = candidate
			best_time_usec = candidate_time
			best_priority = priority

	return best


static func _is_valid_kind(kind: int) -> bool:
	return kind in [
		NucleusSaveTypes.Kind.MANUAL,
		NucleusSaveTypes.Kind.AUTOSAVE,
		NucleusSaveTypes.Kind.QUICKSAVE,
	]
