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


## Equal arc-length spacing on a bounded centripetal Catmull-Rom route.
## Positions are centres of rigid pieces (not their endpoints). Orient a piece
## using the chord joining nearby arc positions, rather than a sparse polygon
## edge: long fence sections fit the physical centreline more faithfully.
## Tension 0 follows a polyline; tension 1 uses the smooth centripetal spline.
static func path_layout(
	controls: Array[Vector3],
	spacing: float,
	maximum_count: int,
	subdivisions: int = 10,
	tension: float = 0.7,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if controls.size() < 2 or controls.size() > 32:
		return result
	if not is_finite(spacing) or spacing <= 0.0 or maximum_count < 1:
		return result
	if subdivisions < 2 or subdivisions > 32 or not is_finite(tension):
		return result
	if tension < 0.0 or tension > 1.0:
		return result
	for point: Vector3 in controls:
		if not _finite(point):
			return result
	var sampled: Array[Vector3] = [controls[0]]
	var lengths: Array[float] = [0.0]
	var total := 0.0
	for segment: int in range(controls.size() - 1):
		var start := controls[segment]
		var end := controls[segment + 1]
		var chord := Vector2(end.x - start.x, end.z - start.z).length()
		if chord <= 0.00001:
			return []
		# Enough samples for short segments and sharply curved routes, but a
		# strict per-segment bound prevents unbounded editing-frame CPU cost.
		var steps := mini(128, maxi(subdivisions, ceili(chord / (spacing * 0.12))))
		for step: int in range(1, steps + 1):
			var point := _curve_point(controls, segment, float(step) / float(steps), tension)
			var last: Vector3 = sampled[sampled.size() - 1]
			var advance := Vector2(point.x - last.x, point.z - last.z).length()
			if advance <= 0.000001:
				continue
			total += advance
			if not is_finite(total) or total / spacing >= float(maximum_count):
				return []
			sampled.append(point)
			lengths.append(total)
	if sampled.size() < 2:
		return []
	var count := floori(total / spacing) + 1
	if count > maximum_count:
		return []
	for index: int in range(count):
		var arc := float(index) * spacing
		var position := _at_distance(sampled, lengths, arc)
		# An oriented rigid section follows a chord spanning a representative
		# portion of its own length; this suppresses wobble at tight knots.
		var half := minf(spacing * 0.45, total * 0.5)
		var behind := _at_distance(sampled, lengths, maxf(0.0, arc - half))
		var ahead := _at_distance(sampled, lengths, minf(total, arc + half))
		var tangent := ahead - behind
		if Vector2(tangent.x, tangent.z).length_squared() <= 0.000001:
			return []
		result.append({
			"position": position,
			"yaw": heading(Vector3.ZERO, tangent),
		})
	return result


static func _at_distance(
	sampled: Array[Vector3], lengths: Array[float], distance: float,
) -> Vector3:
	if distance <= 0.0:
		return sampled[0]
	if distance >= lengths.back():
		return sampled[sampled.size() - 1]
	var lo := 0
	var hi := lengths.size() - 1
	while hi - lo > 1:
		var mid := int(float(lo + hi) * 0.5)
		if lengths[mid] < distance:
			lo = mid
		else:
			hi = mid
	var fraction := (distance - lengths[lo]) / (lengths[hi] - lengths[lo])
	return sampled[lo].lerp(sampled[hi], fraction)


static func _curve_point(
	controls: Array[Vector3], segment: int, t: float, tension: float = 0.7,
) -> Vector3:
	var b := controls[segment]
	var c := controls[segment + 1]
	var linear := b.lerp(c, t)
	if controls.size() == 2 or tension <= 0.0:
		return linear
	var a := controls[segment - 1] if segment > 0 else b + (b - c)
	var d := controls[segment + 2] if segment + 2 < controls.size() else c + (c - b)
	var t0 := 0.0
	var t1 := t0 + maxf(a.distance_to(b), 0.0001) ** 0.5
	var t2 := t1 + maxf(b.distance_to(c), 0.0001) ** 0.5
	var t3 := t2 + maxf(c.distance_to(d), 0.0001) ** 0.5
	var u := lerpf(t1, t2, t)
	var a1 := a.lerp(b, (u - t0) / (t1 - t0))
	var a2 := b.lerp(c, (u - t1) / (t2 - t1))
	var a3 := c.lerp(d, (u - t2) / (t3 - t2))
	var b1 := a1.lerp(a2, (u - t0) / (t2 - t0))
	var b2 := a2.lerp(a3, (u - t1) / (t3 - t1))
	var curved := b1.lerp(b2, (u - t1) / (t2 - t1))
	return linear.lerp(curved, tension)


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
