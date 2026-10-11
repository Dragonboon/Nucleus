class_name NucleusMotionMath
extends RefCounted
## Small movement-specific math helpers shared by gameplay Components.


static func exponential_weight(
	response: float,
	delta: float,
) -> float:
	if response <= 0.0:
		return 1.0

	return clampf(
		1.0 - exp(-response * maxf(0.0, delta)),
		0.0,
		1.0,
	)


static func planar_direction_3d(
	input_direction: Vector2,
	basis: Basis,
	up_direction: Vector3,
) -> Vector3:
	if input_direction.is_zero_approx():
		return Vector3.ZERO

	var up: Vector3 = up_direction.normalized()

	if up.is_zero_approx():
		up = Vector3.UP

	var back: Vector3 = basis.z.slide(up)

	if back.is_zero_approx():
		# At a camera pole, retain its right axis instead of snapping to world Z.
		back = basis.x.slide(up).cross(up)

	if back.is_zero_approx():
		var fallback: Vector3 = Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT
		back = fallback.slide(up)

	back = back.normalized()

	var right: Vector3 = up.cross(back).normalized()
	var direction: Vector3 = (
		right * input_direction.x
		+ back * input_direction.y
	)

	return direction.limit_length(1.0)


static func planar_component_3d(
	vector: Vector3,
	up_direction: Vector3,
) -> Vector3:
	var up: Vector3 = up_direction.normalized()

	if up.is_zero_approx():
		up = Vector3.UP

	return vector - up * vector.dot(up)


static func vertical_component_3d(
	vector: Vector3,
	up_direction: Vector3,
) -> Vector3:
	var up: Vector3 = up_direction.normalized()

	if up.is_zero_approx():
		up = Vector3.UP

	return up * vector.dot(up)


static func right_from_up_2d(up_direction: Vector2) -> Vector2:
	var up: Vector2 = up_direction.normalized()

	if up.is_zero_approx():
		up = Vector2.UP

	return Vector2(-up.y, up.x)
