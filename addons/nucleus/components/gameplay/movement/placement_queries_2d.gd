class_name NucleusPlacementQueries2D
extends RefCounted
## Stateless collision-shape placement queries for safe 2D spawn/teleport/exit points.
##
## Candidate generation and gameplay policy remain owned by the consuming scene.


static func is_transform_free(
	space_state: PhysicsDirectSpaceState2D,
	shape: Shape2D,
	transform: Transform2D,
	collision_mask: int = 0xFFFFFFFF,
	exclude: Array[RID] = [],
	collide_with_bodies: bool = true,
	collide_with_areas: bool = false,
	margin: float = 0.0,
) -> bool:
	if space_state == null or shape == null:
		return false

	var query := _create_query(
		shape,
		transform,
		collision_mask,
		exclude,
		collide_with_bodies,
		collide_with_areas,
		margin,
	)
	return space_state.intersect_shape(query, 1).is_empty()


static func find_first_free_index(
	space_state: PhysicsDirectSpaceState2D,
	shape: Shape2D,
	candidates: Array[Transform2D],
	collision_mask: int = 0xFFFFFFFF,
	exclude: Array[RID] = [],
	collide_with_bodies: bool = true,
	collide_with_areas: bool = false,
	margin: float = 0.0,
) -> int:
	if space_state == null or shape == null or candidates.is_empty():
		return -1

	var query := _create_query(
		shape,
		Transform2D.IDENTITY,
		collision_mask,
		exclude,
		collide_with_bodies,
		collide_with_areas,
		margin,
	)

	for index: int in range(candidates.size()):
		query.transform = candidates[index]

		if space_state.intersect_shape(query, 1).is_empty():
			return index

	return -1


static func _create_query(
	shape: Shape2D,
	transform: Transform2D,
	collision_mask: int,
	exclude: Array[RID],
	collide_with_bodies: bool,
	collide_with_areas: bool,
	margin: float,
) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = collision_mask
	query.exclude = exclude
	query.collide_with_bodies = collide_with_bodies
	query.collide_with_areas = collide_with_areas
	query.margin = maxf(margin, 0.0)
	return query
