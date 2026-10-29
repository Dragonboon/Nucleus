class_name NucleusUIWorldAnchorLayoutSolver
extends RefCounted
## Deterministic, priority-ordered vertical deconfliction for HUD rectangles.
## This pure helper does not depend on a renderer, viewport, or SceneTree.


## Earlier entries win. Each entry needs Vector2 position and Vector2 size.
## Returns one {position: Vector2, visible: bool} for every input entry.
static func solve(
	entries: Array[Dictionary],
	bounds: Rect2,
	padding: float = 4.0,
	maximum_lift: float = 80.0,
	lift_step: float = 8.0,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var occupied: Array[Rect2] = []
	var gap: float = maxf(0.0, padding)
	var lift: float = maxf(0.0, maximum_lift)
	var step: float = maxf(1.0, lift_step)
	var steps: int = int(ceil(lift / step))

	for entry: Dictionary in entries:
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		var size: Vector2 = entry.get("size", Vector2.ZERO)
		if (
			size.x <= 0.0 or size.y <= 0.0
			or size.x > bounds.size.x or size.y > bounds.size.y
			or not position.is_finite() or not size.is_finite()
		):
			results.append({"position": position, "visible": false})
			continue

		var preferred: Vector2 = Vector2(
			clampf(position.x, bounds.position.x, bounds.end.x - size.x),
			clampf(position.y, bounds.position.y, bounds.end.y - size.y),
		)
		var chosen: Vector2 = preferred
		var placed: bool = false

		for index: int in range(steps + 1):
			var shift: float = minf(float(index) * step, lift)
			var proposed: Vector2 = preferred - Vector2(0.0, shift)
			if proposed.y < bounds.position.y:
				continue

			var proposed_rect: Rect2 = Rect2(proposed, size)
			var clashes: bool = false
			for previous: Rect2 in occupied:
				if proposed_rect.grow(gap * 0.5).intersects(
					previous.grow(gap * 0.5)
				):
					clashes = true
					break

			if not clashes:
				chosen = proposed
				occupied.append(proposed_rect)
				placed = true
				break

		results.append({"position": chosen, "visible": placed})

	return results
