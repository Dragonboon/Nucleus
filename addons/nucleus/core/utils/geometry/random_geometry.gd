class_name NucleusRandomGeometry
extends RefCounted
## Uniform random sampling helpers for common 2D/3D gameplay shapes.


static func point_in_circle(
	center: Vector2 = Vector2.ZERO,
	radius: float = 1.0,
	rng: RandomNumberGenerator = null,
) -> Vector2:
	var safe_radius: float = maxf(0.0, radius)
	var angle: float = _randf_range(rng, 0.0, TAU)
	var distance: float = (
		sqrt(_randf(rng)) * safe_radius
	)

	return center + Vector2.from_angle(angle) * distance


static func point_on_circle(
	center: Vector2 = Vector2.ZERO,
	radius: float = 1.0,
	rng: RandomNumberGenerator = null,
) -> Vector2:
	var angle: float = _randf_range(rng, 0.0, TAU)

	return (
		center
		+ Vector2.from_angle(angle) * maxf(0.0, radius)
	)


static func point_in_annulus(
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	rng: RandomNumberGenerator = null,
) -> Vector2:
	var inner: float = maxf(
		0.0,
		minf(inner_radius, outer_radius),
	)
	var outer: float = maxf(
		inner,
		maxf(inner_radius, outer_radius),
	)
	var angle: float = _randf_range(rng, 0.0, TAU)
	var radius_squared: float = lerpf(
		inner * inner,
		outer * outer,
		_randf(rng),
	)

	return (
		center
		+ Vector2.from_angle(angle)
		* sqrt(radius_squared)
	)


static func point_in_rect(
	rect: Rect2,
	rng: RandomNumberGenerator = null,
) -> Vector2:
	var min_x: float = minf(rect.position.x, rect.end.x)
	var max_x: float = maxf(rect.position.x, rect.end.x)
	var min_y: float = minf(rect.position.y, rect.end.y)
	var max_y: float = maxf(rect.position.y, rect.end.y)

	return Vector2(
		_randf_range(rng, min_x, max_x),
		_randf_range(rng, min_y, max_y),
	)


static func direction_2d(
	rng: RandomNumberGenerator = null,
) -> Vector2:
	return Vector2.from_angle(
		_randf_range(rng, 0.0, TAU)
	)


## Returns a uniformly distributed unit vector on a sphere.
static func direction_3d(
	rng: RandomNumberGenerator = null,
) -> Vector3:
	var y: float = _randf_range(rng, -1.0, 1.0)
	var angle: float = _randf_range(rng, 0.0, TAU)
	var horizontal_radius: float = sqrt(
		maxf(0.0, 1.0 - y * y)
	)

	return Vector3(
		horizontal_radius * cos(angle),
		y,
		horizontal_radius * sin(angle),
	)


static func _randf(
	rng: RandomNumberGenerator,
) -> float:
	return rng.randf() if rng else randf()


static func _randf_range(
	rng: RandomNumberGenerator,
	minimum: float,
	maximum: float,
) -> float:
	return (
		rng.randf_range(minimum, maximum)
		if rng
		else randf_range(minimum, maximum)
	)
