extends RefCounted
## Internal deterministic math used by NucleusBuoyancy3D.


static func submerged_fraction(
	surface_height: float,
	point_height: float,
	column_height: float,
) -> float:
	if column_height <= 0.0:
		return 0.0

	return clampf(
		(surface_height - point_height + column_height * 0.5) / column_height,
		0.0,
		1.0,
	)


static func equilibrium_submersion(
	body_mass: float,
	fluid_density: float,
	displacement_volume: float,
) -> float:
	var capacity := maxf(fluid_density, 0.0) * maxf(displacement_volume, 0.0)

	if capacity <= 0.0:
		return INF

	return maxf(body_mass, 0.0) / capacity


static func damping_coefficient(
	fluid_density: float,
	gravity_magnitude: float,
	volume_per_point: float,
	column_height: float,
	point_mass: float,
	damping_ratio: float,
	physics_step: float,
) -> float:
	if (
		fluid_density <= 0.0
		or gravity_magnitude <= 0.0
		or volume_per_point <= 0.0
		or column_height <= 0.0
		or point_mass <= 0.0
	):
		return 0.0

	var stiffness := (
		fluid_density
		* gravity_magnitude
		* volume_per_point
		/ column_height
	)
	var coefficient := (
		2.0
		* maxf(damping_ratio, 0.0)
		* sqrt(stiffness * point_mass)
	)
	var timestep_limit := point_mass / maxf(physics_step, 0.001)
	return minf(coefficient, timestep_limit)


static func contact_factor(
	submerged: float,
	equilibrium: float,
) -> float:
	var contact_span := maxf(
		minf(maxf(equilibrium, 0.0), 1.0) * 0.5,
		0.01,
	)
	return smoothstep(
		0.0,
		contact_span,
		clampf(submerged, 0.0, 1.0),
	)


static func point_force(
	point_velocity: Vector3,
	surface_velocity: Vector3,
	submerged: float,
	body_mass: float,
	point_count: int,
	fluid_density: float,
	volume_per_point: float,
	gravity_magnitude: float,
	damping: float,
	contact: float,
	maximum_lift_acceleration: float,
	linear_drag: float,
) -> Vector3:
	if point_count <= 0 or body_mass <= 0.0 or gravity_magnitude <= 0.0:
		return Vector3.ZERO

	var wet := clampf(submerged, 0.0, 1.0)
	var point_mass := body_mass / float(point_count)
	var lift := (
		maxf(fluid_density, 0.0)
		* gravity_magnitude
		* maxf(volume_per_point, 0.0)
		* wet
	)
	lift -= (
		maxf(damping, 0.0)
		* (point_velocity.y - surface_velocity.y)
		* clampf(contact, 0.0, 1.0)
	)
	var maximum_lift := (
		point_mass
		* gravity_magnitude
		* maxf(maximum_lift_acceleration, 0.0)
	)
	lift = clampf(lift, 0.0, maximum_lift)

	var drag := (
		(surface_velocity - point_velocity)
		* body_mass
		* maxf(linear_drag, 0.0)
		* wet
		/ float(point_count)
	)
	drag.y = 0.0
	return Vector3.UP * lift + drag
