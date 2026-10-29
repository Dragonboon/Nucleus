class_name NucleusTargetLineOfSightFilter2D
extends NucleusTargetFilter
## Uses PhysicsDirectSpaceState2D to reject occluded targets.

@export var ray_origin: Node2D
@export_flags_2d_physics var collision_mask: int = 0xFFFFFFFF
@export var collide_with_bodies: bool = true
@export var collide_with_areas: bool = false
@export var exclude_origin_collision_object: bool = true


func accepts(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	if target == null or not target.has_position_2d():
		return false

	var origin: Node2D = (
		ray_origin
		if ray_origin
		else NucleusTargetingSpace.origin_2d(agent)
	)

	if origin == null or not origin.is_inside_tree():
		return false

	var from: Vector2 = origin.global_position
	var to: Vector2 = target.get_position_2d()

	if from.is_equal_approx(to):
		return true

	var excluded: Array[RID] = []

	if exclude_origin_collision_object:
		var collision_origin: CollisionObject2D = (
			NucleusTargetingSpace.collision_object_2d(agent)
		)

		if collision_origin:
			excluded.append(collision_origin.get_rid())

	var query := PhysicsRayQueryParameters2D.create(
		from,
		to,
		collision_mask,
		excluded,
	)
	query.collide_with_bodies = collide_with_bodies
	query.collide_with_areas = collide_with_areas

	var result: Dictionary = origin.get_world_2d().direct_space_state.intersect_ray(
		query
	)

	if result.is_empty():
		return true

	var collider: Variant = result.get("collider")

	if not collider is Node:
		return false

	return (
		NucleusTargetResolver.find_targetable(
			collider as Node
		)
		== target
	)
