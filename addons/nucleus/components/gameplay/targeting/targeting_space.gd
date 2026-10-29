class_name NucleusTargetingSpace
extends RefCounted
## Small dimension-specific geometry helpers shared by targeting rules.


static func source_2d(agent: NucleusTargetingAgent) -> Node2D:
	if agent == null:
		return null

	if agent.orientation_source is Node2D:
		return agent.orientation_source as Node2D

	if agent.source is Node2D:
		return agent.source as Node2D

	return null


static func source_3d(agent: NucleusTargetingAgent) -> Node3D:
	if agent == null:
		return null

	if agent.orientation_source is Node3D:
		return agent.orientation_source as Node3D

	if agent.source is Node3D:
		return agent.source as Node3D

	return null


static func origin_2d(agent: NucleusTargetingAgent) -> Node2D:
	if agent == null:
		return null

	if agent.origin is Node2D:
		return agent.origin as Node2D

	if agent.source is Node2D:
		return agent.source as Node2D

	return null


static func origin_3d(agent: NucleusTargetingAgent) -> Node3D:
	if agent == null:
		return null

	if agent.origin is Node3D:
		return agent.origin as Node3D

	if agent.source is Node3D:
		return agent.source as Node3D

	return null


static func forward_2d(agent: NucleusTargetingAgent) -> Vector2:
	var node: Node2D = source_2d(agent)

	if node == null:
		return Vector2.RIGHT

	return node.global_transform.x.normalized()


static func forward_3d(agent: NucleusTargetingAgent) -> Vector3:
	var node: Node3D = source_3d(agent)

	if node == null:
		return Vector3.FORWARD

	return -node.global_basis.z.normalized()


static func collision_object_2d(
	agent: NucleusTargetingAgent,
) -> CollisionObject2D:
	if agent == null:
		return null

	var start: Node = agent.source

	if start is CollisionObject2D:
		return start as CollisionObject2D

	var descendants: Array[CollisionObject2D] = []

	for node: Node in NucleusNodeUtils.descendants(start):
		if node is CollisionObject2D:
			descendants.append(node as CollisionObject2D)

	if descendants.size() == 1:
		return descendants[0]

	for ancestor: Node in NucleusNodeUtils.ancestors(start):
		if ancestor is CollisionObject2D:
			return ancestor as CollisionObject2D

	return null


static func collision_object_3d(
	agent: NucleusTargetingAgent,
) -> CollisionObject3D:
	if agent == null:
		return null

	var start: Node = agent.source

	if start is CollisionObject3D:
		return start as CollisionObject3D

	var descendants: Array[CollisionObject3D] = []

	for node: Node in NucleusNodeUtils.descendants(start):
		if node is CollisionObject3D:
			descendants.append(node as CollisionObject3D)

	if descendants.size() == 1:
		return descendants[0]

	for ancestor: Node in NucleusNodeUtils.ancestors(start):
		if ancestor is CollisionObject3D:
			return ancestor as CollisionObject3D

	return null
