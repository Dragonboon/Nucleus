class_name NucleusNavigationQueries3D
extends RefCounted
## Ground-plane random point sampling projected onto a navigation map.

static func random_point_in_radius(
	navigation_map: RID,
	origin: Vector3,
	radius: float,
	rng: RandomNumberGenerator,
	navigation_layers: int = 1,
	attempts: int = 8,
) -> Vector3:
	if (
		not navigation_map.is_valid()
		or rng == null
		or radius <= 0.0
		or navigation_layers <= 0
	):
		return origin

	var maximum_distance: float = maxf(
		0.0,
		radius,
	)

	for _attempt: int in range(maxi(1, attempts)):
		var angle: float = rng.randf_range(
			-PI,
			PI,
		)
		var distance: float = sqrt(rng.randf()) * maximum_distance
		var candidate: Vector3 = origin + Vector3(
			cos(angle) * distance,
			0.0,
			sin(angle) * distance,
		)
		var closest_point: Vector3 = NavigationServer3D.map_get_closest_point(
			navigation_map,
			candidate,
		)

		var owner: RID = NavigationServer3D.map_get_closest_point_owner(
			navigation_map,
			closest_point,
		)

		if owner.is_valid() and navigation_layers > 0:
			var owner_layers: int = (
				NavigationServer3D.region_get_navigation_layers(owner)
			)

			if (owner_layers & navigation_layers) == 0:
				continue

		var planar_distance: float = Vector2(
			closest_point.x - origin.x,
			closest_point.z - origin.z,
		).length()

		if planar_distance <= maximum_distance + 0.001:
			return closest_point

	return origin
