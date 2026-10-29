class_name NucleusPlacementSolver3D
extends RefCounted
## Stateless terrain/support/occupancy admission using native PhysicsDirectSpaceState3D.
## An invalid or unverified surface always produces an explicit rejection.


static func evaluate_hit(
	space: PhysicsDirectSpaceState3D,
	profile: NucleusPlacementProfile3D,
	hit: Dictionary,
	yaw: float = 0.0,
	exclude: Array[RID] = [],
	snap_settings: Dictionary = {},
	visual_bounds: Dictionary = {},
) -> Dictionary:
	if space == null or profile == null or not profile.validate().is_empty():
		return _reject(&"invalid_profile")
	if hit.is_empty() or not hit.get("collider") is CollisionObject3D:
		return _reject(&"no_surface")
	var point: Vector3 = hit.get("position", Vector3.INF)
	if not _finite(point):
		return _reject(&"no_surface")
	var snap := snap_settings if not snap_settings.is_empty() else profile.resolve_snap()
	var pos: Vector3 = point
	if bool(snap.get("enabled", false)):
		var step: Vector2 = snap.get("step", Vector2.ZERO)
		var origin: Vector2 = snap.get("origin", Vector2.ZERO)
		if not valid_grid(step, origin):
			return _reject(&"invalid_snap")
		pos = snap_horizontal(pos, step, origin)
		if Vector2(pos.x - point.x, pos.z - point.z).length_squared() > 0.000001:
			# Snap may switch support (ground vs platform). Recast BEFORE policy checks.
			var ray := PhysicsRayQueryParameters3D.create(
				pos + Vector3.UP * profile.support_cast_above,
				pos - Vector3.UP * profile.support_cast_below,
				profile.support_mask, exclude,
			)
			ray.collide_with_areas = false
			hit = space.intersect_ray(ray)
			if hit.is_empty():
				return _reject(&"no_surface")
			point = hit.get("position", Vector3.INF)
			if not _finite(point):
				return _reject(&"no_surface")
			pos = point

	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if not _valid_normal(normal):
		return _reject(&"no_surface")
	var collider: Object = hit["collider"]
	if not _allowed_support(profile, collider):
		return _reject(&"forbidden_support")
	if not _required_tags_match(profile, hit):
		return _reject(&"surface_tags")
	if _slope_degrees(normal) > profile.max_slope_degrees:
		return _reject(&"steep_surface")

	var flat_basis := Basis(Vector3.UP, yaw)
	var offsets: Array[Vector3] = [Vector3.ZERO]
	var h := profile.support_half_extents
	if h.x > 0.0 or h.y > 0.0:
		for x: float in [-h.x, h.x]:
			for z: float in [-h.y, h.y]:
				offsets.append(Vector3(x, 0.0, z))

	var min_height: float = INF
	var max_height: float = -INF
	var mean_normal: Vector3 = Vector3.ZERO
	var sample_heights: Array[float] = []
	var reference_owner := NucleusPlaceable3D.find_for_collider(collider)
	# One ray query reused for all footprint samples. The first sample is
	# the snapped center, so it also supplies the authoritative final height.
	var query := PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * profile.support_cast_above,
		pos - Vector3.UP * profile.support_cast_below,
		profile.support_mask,
		exclude,
	)
	query.collide_with_areas = false
	for offset: Vector3 in offsets:
		var p: Vector3 = pos + flat_basis * offset
		query.from = p + Vector3.UP * profile.support_cast_above
		query.to = p - Vector3.UP * profile.support_cast_below
		var sample: Dictionary = space.intersect_ray(query)
		if sample.is_empty():
			return _reject(&"unsupported_footprint")
		if not _allowed_support(profile, sample.get("collider")):
			return _reject(&"forbidden_support")
		if not _required_tags_match(profile, sample):
			return _reject(&"surface_tags")
		var sample_owner := NucleusPlaceable3D.find_for_collider(sample.get("collider"))
		if sample_owner != reference_owner:
			return _reject(&"mixed_support")
		var sample_normal: Vector3 = sample.get("normal", Vector3.ZERO)
		if not _valid_normal(sample_normal):
			return _reject(&"unsupported_footprint")
		if _slope_degrees(sample_normal) > profile.max_slope_degrees:
			return _reject(&"steep_surface")
		var sample_position: Vector3 = sample.get("position", Vector3.INF)
		if not _finite(sample_position):
			return _reject(&"unsupported_footprint")
		sample_heights.append(sample_position.y)
		min_height = minf(min_height, sample_position.y)
		max_height = maxf(max_height, sample_position.y)
		mean_normal += sample_normal.normalized()

	var deviation: float = max_height - min_height
	if profile.align_to_surface:
		# A rigid piece can tilt to follow a planar slope. Measure the
		# residual variation *from that plane*, not absolute corner heights.
		var plane_normal := mean_normal.normalized()
		if not _valid_normal(plane_normal):
			return _reject(&"invalid_normal")
		deviation = 0.0
		for index: int in range(offsets.size()):
			var offset: Vector3 = flat_basis * offsets[index]
			var expected_y: float = sample_heights[0] - (
				plane_normal.x * offset.x + plane_normal.z * offset.z
			) / plane_normal.y
			deviation = maxf(deviation, absf(sample_heights[index] - expected_y))
	if deviation > profile.max_height_spread:
		return _reject(&"uneven_surface")

	# The central sample is already measured at the snapped X/Z position.
	# A second center ray was redundant and caused extra allocations/work.
	pos.y = sample_heights[0] + profile.surface_offset

	var up := Vector3.UP
	if profile.align_to_surface:
		up = mean_normal.normalized()
		if not _valid_normal(up):
			return _reject(&"invalid_normal")
	var forward := flat_basis * Vector3.FORWARD
	forward = (forward - up * forward.dot(up)).normalized()
	if forward.is_zero_approx():
		return _reject(&"invalid_normal")
	var right := forward.cross(up).normalized()
	var basis := Basis(right, up, right.cross(up)).orthonormalized()
	var transform := Transform3D(basis, pos)
	if profile.origin_mode == NucleusPlacementProfile3D.OriginMode.VISUAL_BOTTOM:
		if not bool(visual_bounds.get("valid", false)):
			return _reject(&"no_visual_bounds")
		var bounds: AABB = visual_bounds["bounds"]
		transform.origin += NucleusPlacementGeometry3D.bottom_correction(bounds, basis, up)
	var shape_transform := transform * Transform3D(Basis.IDENTITY, profile.clearance_offset)
	if not NucleusPlacementQueries3D.is_transform_free(
		space,
		profile.clearance_shape,
		shape_transform,
		profile.obstacle_mask,
		exclude,
		true,
		profile.check_areas,
		profile.collision_margin,
	):
		return _reject(&"occupied")

	return {"valid": true, "reason": &"", "transform": transform, "support": collider}


## Cast vertically from an authored point, for chain points or custom cursor tools.
static func evaluate_at(
	space: PhysicsDirectSpaceState3D,
	profile: NucleusPlacementProfile3D,
	position: Vector3,
	yaw: float = 0.0,
	exclude: Array[RID] = [],
	snap_settings: Dictionary = {},
	visual_bounds: Dictionary = {},
) -> Dictionary:
	if space == null or profile == null or not _finite(position):
		return _reject(&"invalid_profile")
	var snap := snap_settings if not snap_settings.is_empty() else profile.resolve_snap()
	if bool(snap.get("enabled", false)):
		var step: Vector2 = snap.get("step", Vector2.ZERO)
		var origin: Vector2 = snap.get("origin", Vector2.ZERO)
		if not valid_grid(step, origin):
			return _reject(&"invalid_snap")
		position = snap_horizontal(position, step, origin)
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * profile.support_cast_above,
		position - Vector3.UP * profile.support_cast_below,
		profile.support_mask,
		exclude,
	)
	query.collide_with_areas = false
	return evaluate_hit(space, profile, space.intersect_ray(query), yaw, exclude, snap, visual_bounds)


## Grid quantization is world-X/Z only; Y always comes from actual support.
static func snap_horizontal(position: Vector3, step: Vector2, origin: Vector2) -> Vector3:
	if not _finite(position) or not valid_grid(step, origin):
		return position
	return Vector3(
		snappedf(position.x - origin.x, step.x) + origin.x,
		position.y,
		snappedf(position.z - origin.y, step.y) + origin.y,
	)


static func valid_grid(step: Vector2, origin: Vector2) -> bool:
	return (
		is_finite(step.x) and is_finite(step.y)
		and is_finite(origin.x) and is_finite(origin.y)
		and step.x > 0.0 and step.y > 0.0
	)


static func _allowed_support(profile: NucleusPlacementProfile3D, collider: Object) -> bool:
	if not is_instance_valid(collider) or not collider is CollisionObject3D:
		return false
	var owner := NucleusPlaceable3D.find_for_collider(collider)
	if owner == null:
		return (
			profile.allow_unowned_ground
			and (collider is StaticBody3D or profile.allow_nonstatic_support)
		)
	if owner.profile == null:
		return false
	return (
		owner.profile.kind in profile.supported_by_kinds
		and profile.kind in owner.profile.accepts_on_top_kinds
	)


static func _required_tags_match(profile: NucleusPlacementProfile3D, hit: Dictionary) -> bool:
	if profile.required_surface_tags.is_empty():
		return true
	var semantic := NucleusSurfaceResolver3D.resolve_collider(
		hit.get("collider"),
		hit.get("position", Vector3.ZERO),
		hit.get("normal", Vector3.UP),
		int(hit.get("shape", -1)),
		int(hit.get("face_index", -1)),
	)
	return semantic != null and semantic.has_all_tags(profile.required_surface_tags)


static func _valid_normal(value: Vector3) -> bool:
	return _finite(value) and value.length_squared() > 0.001 and value.dot(Vector3.UP) > 0.0


static func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func _slope_degrees(value: Vector3) -> float:
	return rad_to_deg(acos(clampf(value.normalized().dot(Vector3.UP), -1.0, 1.0)))


static func _reject(reason: StringName) -> Dictionary:
	return {"valid": false, "reason": reason}
