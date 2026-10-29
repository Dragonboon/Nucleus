class_name NucleusSpawner3D
extends NucleusSpawner
## Places pooled Node3D instances at a 3D origin before activation.

@export var origin: Node3D
@export var local_offset: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	if origin == null:
		origin = get_parent() as Node3D

	if pool == null:
		pool = _find_pool()

	if origin == null:
		NucleusLog.error(
			"%s requires a Node3D origin or parent." % get_path(),
			&"Spawner3D",
		)

	if pool == null:
		NucleusLog.error(
			"%s requires a NucleusObjectPool." % get_path(),
			&"Spawner3D",
		)


func spawn(context: Dictionary = {}) -> Node:
	if pool == null or origin == null:
		return null

	var instance: Node = pool.reserve(spawn_parent)

	if instance == null:
		return null

	if not instance is Node3D:
		NucleusLog.error(
			"Pooled instance '%s' is not Node3D."
			% instance.name,
			&"Spawner3D",
		)
		pool.release(instance)
		return null

	var node_3d := instance as Node3D
	node_3d.global_transform = (
		origin.global_transform * local_offset
	)
	node_3d.reset_physics_interpolation()

	var spawn_context: Dictionary = context.duplicate(true)
	spawn_context["spawner"] = self

	var error: Error = pool.activate(
		instance,
		spawn_context,
	)

	if error != OK:
		pool.release(instance)
		return null

	spawned.emit(
		instance,
		spawn_context,
	)

	return instance


func _find_pool() -> NucleusObjectPool:
	var root: Node = get_parent()

	while root:
		var pools: Array[NucleusObjectPool] = []

		if root is NucleusObjectPool:
			pools.append(root as NucleusObjectPool)

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusObjectPool:
				pools.append(node as NucleusObjectPool)

		if pools.size() == 1:
			return pools[0]

		if pools.size() > 1:
			NucleusLog.warning(
				"%s found multiple pools; assign pool explicitly."
				% get_path(),
				&"Spawner3D",
			)
			return null

		root = root.get_parent()

	return null
