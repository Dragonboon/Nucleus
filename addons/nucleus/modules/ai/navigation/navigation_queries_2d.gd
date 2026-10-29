class_name NucleusNavigationQueries2D
extends RefCounted
## Small navigation queries not directly represented by one Godot helper.

static func random_point_in_radius(
	navigation_map: RID,
	origin: Vector2,
	radius: float,
	rng: RandomNumberGenerator,
	navigation_layers: int = 1,
	attempts: int = 8,
) -> Vector2:
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
		var candidate: Vector2 = origin + Vector2(
			cos(angle),
			sin(angle),
		) * distance
		var closest_point: Vector2 = NavigationServer2D.map_get_closest_point(
			navigation_map,
			candidate,
		)

		var owner: RID = NavigationServer2D.map_get_closest_point_owner(
			navigation_map,
			closest_point,
		)

		if owner.is_valid() and navigation_layers > 0:
			var owner_layers: int = (
				NavigationServer2D.region_get_navigation_layers(owner)
			)

			if (owner_layers & navigation_layers) == 0:
				continue

		if closest_point.distance_to(origin) <= maximum_distance + 0.001:
			return closest_point

	return origin
