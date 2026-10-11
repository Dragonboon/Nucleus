class_name NucleusModularNeighborhood
extends RefCounted
## Deterministic, fixed-cost reassessment of an edited cell and its 4 neighbors.
## Pure descriptors: consumers own materialization, placement and persistence.

const MAX_AFFECTED: int = 5


## occupied(Vector3i) -> bool. Other elevation layers are never consulted.
## Includes removed cells as occupied=false so presenters can dispose their asset.
static func resolve_around(
	changed: Vector3i,
	occupied: Callable,
	rules: NucleusModularRuleSet,
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not occupied.is_valid() or rules == null:
		return output
	var points: Array[Vector3i] = [changed]
	for side in range(4):
		var neighbor: Vector2i = NucleusSquareLayout.neighbor(
			Vector2i(changed.x, changed.y), side
		)
		points.append(Vector3i(neighbor.x, neighbor.y, changed.z))
	for cell: Vector3i in points:
		var present: bool = bool(occupied.call(cell))
		var resolved: Dictionary = {}
		if present:
			var same_layer := func(other: Vector2i) -> bool:
				return bool(occupied.call(Vector3i(other.x, other.y, cell.z)))
			var mask: int = NucleusModularRuleSet.neighbor_mask(
				Vector2i(cell.x, cell.y), same_layer
			)
			resolved = rules.resolve_variant(mask)
		output.append({
			"cell": cell,
			"occupied": present,
			"variant_id": resolved.get("variant_id", &""),
			"rotation_steps": int(resolved.get("rotation_steps", 0)),
			"neighbor_mask": int(resolved.get("neighbor_mask", 0)),
		})
	return output
