class_name NucleusTargetLineOfSightFilter3D
extends NucleusTargetFilter
## Uses PhysicsDirectSpaceState3D to reject occluded targets.

@export var ray_origin: Node3D
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF
@export var collide_with_bodies: bool = true
@export var collide_with_areas: bool = false
@export var exclude_origin_collision_object: bool = true


func accepts(
	agent: NucleusTargetingAgent,
	target: NucleusTargetable,
	_context: Dictionary,
) -> bool:
	if target == null or not target.has_position_3d():
		return false

	var origin: Node3D = (
		ray_origin
		if ray_origin
		else NucleusTargetingSpace.origin_3d(agent)
	)

	if origin == null or not origin.is_inside_tree():
		return false

	var from: Vector3 = origin.global_position
	var to: Vector3 = target.get_position_3d()

	if from.is_equal_approx(to):
		return true

	var excluded: Array[RID] = []

	if exclude_origin_collision_object:
		var collision_origin: CollisionObject3D = (
			NucleusTargetingSpace.collision_object_3d(agent)
		)

		if collision_origin:
			excluded.append(collision_origin.get_rid())

	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		collision_mask,
		excluded,
	)
	query.collide_with_bodies = collide_with_bodies
	query.collide_with_areas = collide_with_areas

	var result: Dictionary = origin.get_world_3d().direct_space_state.intersect_ray(
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
