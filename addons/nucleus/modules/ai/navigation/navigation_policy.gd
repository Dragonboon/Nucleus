class_name NucleusNavigationPolicy
extends RefCounted
## Shared target-repath policy for 2D/3D navigation followers.

static func should_repath(
	target_displacement: float,
	repath_distance: float,
	elapsed: float,
	minimum_interval: float,
	has_previous_target: bool,
) -> bool:
	if not has_previous_target:
		return true

	if elapsed < maxf(
		0.0,
		minimum_interval,
	):
		return false

	return target_displacement >= maxf(
		0.0,
		repath_distance,
	)
