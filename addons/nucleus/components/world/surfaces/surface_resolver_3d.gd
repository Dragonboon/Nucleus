class_name NucleusSurfaceResolver3D
extends RefCounted
## Resolves semantic 3D surfaces from Godot collision results.
##
## Resolution prefers the impacted shape owner, then the collider, then nearest
## ancestors. Sources in one scope are evaluated by descending priority.


static func resolve(
	query: NucleusSurfaceQuery3D,
) -> NucleusSurfaceProfile:
	for source: NucleusSurfaceSource3D in find_sources(query):
		var profile := source.resolve_surface(query)

		if profile != null:
			return profile

	return null


static func resolve_collider(
	collider: Object,
	world_position: Vector3 = Vector3.ZERO,
	surface_normal: Vector3 = Vector3.ZERO,
	shape_index: int = -1,
	face_index: int = -1,
) -> NucleusSurfaceProfile:
	return resolve(
		NucleusSurfaceQuery3D.new(
			collider,
			world_position,
			surface_normal,
			shape_index,
			face_index,
		)
	)


static func resolve_raycast(
	ray_cast: RayCast3D,
) -> NucleusSurfaceProfile:
	var query := query_from_raycast(ray_cast)

	if query == null:
		return null

	return resolve(query)


static func resolve_kinematic_collision(
	collision: KinematicCollision3D,
	collision_index: int = 0,
) -> NucleusSurfaceProfile:
	var query := query_from_kinematic_collision(
		collision,
		collision_index,
	)

	if query == null:
		return null

	return resolve(query)


static func query_from_raycast(
	ray_cast: RayCast3D,
) -> NucleusSurfaceQuery3D:
	if ray_cast == null or not ray_cast.is_colliding():
		return null

	return NucleusSurfaceQuery3D.new(
		ray_cast.get_collider(),
		ray_cast.get_collision_point(),
		ray_cast.get_collision_normal(),
		ray_cast.get_collider_shape(),
		ray_cast.get_collision_face_index(),
	)


static func query_from_kinematic_collision(
	collision: KinematicCollision3D,
	collision_index: int = 0,
) -> NucleusSurfaceQuery3D:
	if collision == null:
		return null

	if (
		collision_index < 0
		or collision_index >= collision.get_collision_count()
	):
		return null

	return NucleusSurfaceQuery3D.new(
		collision.get_collider(collision_index),
		collision.get_position(collision_index),
		collision.get_normal(collision_index),
		collision.get_collider_shape_index(collision_index),
	)


static func find_sources(
	query: NucleusSurfaceQuery3D,
) -> Array[NucleusSurfaceSource3D]:
	var result: Array[NucleusSurfaceSource3D] = []

	if query == null or not query.is_valid():
		return result

	var collider_node := query.get_collider_node()

	if collider_node == null:
		return result

	var seen: Dictionary[int, bool] = {}
	var shape_owner := _resolve_shape_owner(
		collider_node,
		query.shape_index,
	)

	_append_scope_sources(shape_owner, result, seen)

	if collider_node != shape_owner:
		_append_scope_sources(collider_node, result, seen)

	var ancestor := collider_node.get_parent()

	while ancestor != null:
		if ancestor != shape_owner:
			_append_scope_sources(ancestor, result, seen)

		ancestor = ancestor.get_parent()

	return result


static func _resolve_shape_owner(
	collider_node: Node,
	shape_index: int,
) -> Node:
	if shape_index < 0 or not (collider_node is CollisionObject3D):
		return null

	var collision_object := collider_node as CollisionObject3D
	var owner_id := collision_object.shape_find_owner(shape_index)
	var owner := collision_object.shape_owner_get_owner(owner_id)

	if owner is Node:
		return owner as Node

	return null


static func _append_scope_sources(
	scope: Node,
	result: Array[NucleusSurfaceSource3D],
	seen: Dictionary[int, bool],
) -> void:
	if scope == null:
		return

	var local_sources: Array[NucleusSurfaceSource3D] = []

	if scope is NucleusSurfaceSource3D:
		local_sources.append(scope as NucleusSurfaceSource3D)

	for child: Node in scope.get_children():
		if child is NucleusSurfaceSource3D:
			local_sources.append(child as NucleusSurfaceSource3D)

	_order_by_priority(local_sources)

	for source: NucleusSurfaceSource3D in local_sources:
		var instance_id := source.get_instance_id()

		if seen.has(instance_id):
			continue

		seen[instance_id] = true
		result.append(source)


static func _order_by_priority(
	sources: Array[NucleusSurfaceSource3D],
) -> void:
	for index: int in range(1, sources.size()):
		var source := sources[index]
		var insert_at := index

		while (
			insert_at > 0
			and source.priority > sources[insert_at - 1].priority
		):
			sources[insert_at] = sources[insert_at - 1]
			insert_at -= 1

		sources[insert_at] = source
