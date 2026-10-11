class_name NucleusPlacementChain3D
extends RefCounted
## Pure bounded straight-line layout; no meshes, physics or game rules.
## Each point is revalidated against world geometry before any commit.


static func points(
	anchor: Vector3,
	end: Vector3,
	spacing: float,
	maximum_count: int,
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not _finite(anchor) or not _finite(end):
		return result
	if not is_finite(spacing) or spacing <= 0.0 or maximum_count < 1:
		return result

	var horizontal := Vector3(end.x - anchor.x, 0.0, end.z - anchor.z)
	var distance := horizontal.length()
	if not is_finite(distance) or distance / spacing >= float(maximum_count):
		return result
	var count := floori(distance / spacing) + 1
	if count > maximum_count:
		return result
	var direction := horizontal.normalized() if distance > 0.0 else Vector3.ZERO
	for index: int in range(count):
		result.append(anchor + direction * spacing * float(index))
	return result


static func heading(anchor: Vector3, end: Vector3, fallback: float = 0.0) -> float:
	var delta := Vector2(end.x - anchor.x, end.z - anchor.z)
	if delta.length_squared() <= 0.000001:
		return fallback
	return atan2(-delta.x, -delta.y)


static func _finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


## Pure equal-distance samples along a smoothed X/Z route. The Y of each
## control point is only a hint; the placement solver re-samples every support.
## Returns [{"position": Vector3, "yaw": float}]. A two-point route is linear.
## Rejected input returns [] rather than silently truncating a structure.
static func path_layout(
	controls: Array[Vector3],
	spacing: float,
	maximum_count: int,
	subdivisions: int = 10,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if controls.size() < 2 or controls.size() > 32:
		return result
	if not is_finite(spacing) or spacing <= 0.0 or maximum_count < 1:
		return result
	if subdivisions < 2 or subdivisions > 32:
		return result
	for point: Vector3 in controls:
		if not _finite(point):
			return result

	var sampled: Array[Vector3] = [controls[0]]
	var lengths: Array[float] = [0.0]
	var total: float = 0.0
	for segment: int in range(controls.size() - 1):
		for step: int in range(1, subdivisions + 1):
			var position: Vector3 = _curve_point(
				controls, segment, float(step) / float(subdivisions)
			)
			var previous: Vector3 = sampled.back()
			var advance := Vector2(position.x - previous.x, position.z - previous.z).length()
			if advance <= 0.00001:
				continue
			total += advance
			if not is_finite(total) or total / spacing >= float(maximum_count):
				return []
			sampled.append(position)
			lengths.append(total)

	if sampled.size() < 2:
		return result
	var count := floori(total / spacing) + 1
	if count > maximum_count:
		return result
	var cursor := 1
	for index: int in range(count):
		var distance := float(index) * spacing
		while cursor < lengths.size() - 1 and lengths[cursor] < distance:
			cursor += 1
		var span := lengths[cursor] - lengths[cursor - 1]
		var ratio := (distance - lengths[cursor - 1]) / span
		var position := sampled[cursor - 1].lerp(sampled[cursor], ratio)
		var incoming := sampled[cursor] - sampled[cursor - 1]
		var direction := Vector3(incoming.x, 0.0, incoming.z).normalized()
		if cursor < sampled.size() - 1:
			var outgoing := sampled[cursor + 1] - sampled[cursor]
			var tangent := Vector3(outgoing.x, 0.0, outgoing.z).normalized()
			if not (direction + tangent).is_zero_approx():
				direction = (direction + tangent).normalized()
		result.append({
			"position": position,
			"yaw": heading(Vector3.ZERO, direction),
		})
	return result


static func _curve_point(controls: Array[Vector3], segment: int, t: float) -> Vector3:
	var p1 := controls[segment]
	var p2 := controls[segment + 1]
	if controls.size() == 2:
		return p1.lerp(p2, t)
	var p0 := controls[maxi(segment - 1, 0)]
	var p3 := controls[mini(segment + 2, controls.size() - 1)]
	# Catmull-Rom with clamped endpoint control points.
	var t2 := t * t
	var t3 := t2 * t
	return (
		p1 * 2.0
		+ (p2 - p0) * t
		+ (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2
		+ (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t3
	) * 0.5


## Conservatively prevent self-overlap between neighboring chain segments.
## This is a 2D oriented-box SAT: supports BoxShape3D clearance envelopes.
## Non-box profiles may use their own game-specific chain geometry checks.
static func box_footprints_overlap(
	first: Transform3D,
	second: Transform3D,
	box_size: Vector3,
	clearance_offset: Vector3 = Vector3.ZERO,
	margin: float = 0.01,
	second_box_size: Vector3 = Vector3.ZERO,
	second_offset: Vector3 = Vector3.ZERO,
) -> bool:
	var other_size := second_box_size if second_box_size != Vector3.ZERO else box_size
	var other_offset := second_offset if second_box_size != Vector3.ZERO else clearance_offset
	var a := first * clearance_offset
	var b := second * other_offset
	if absf(a.y - b.y) >= maxf((box_size.y + other_size.y) * 0.5 - margin, 0.0):
		return false
	var axes: Array[Vector3] = [
		first.basis.x.normalized(), first.basis.z.normalized(),
		second.basis.x.normalized(), second.basis.z.normalized(),
	]
	for axis: Vector3 in axes:
		axis.y = 0.0
		if axis.is_zero_approx():
			continue
		axis = axis.normalized()
		var ra := (
			box_size.x * 0.5 * absf(first.basis.x.normalized().dot(axis))
			+ box_size.z * 0.5 * absf(first.basis.z.normalized().dot(axis))
		)
		var rb := (
			other_size.x * 0.5 * absf(second.basis.x.normalized().dot(axis))
			+ other_size.z * 0.5 * absf(second.basis.z.normalized().dot(axis))
		)
		if absf((b - a).dot(axis)) >= maxf(ra + rb - margin, 0.0):
			return false
	return true
