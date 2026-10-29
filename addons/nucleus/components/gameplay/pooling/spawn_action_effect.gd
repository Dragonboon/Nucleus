class_name NucleusSpawnActionEffect
extends NucleusActionEffect
## GameplayAction effect that spawns one or more pooled instances.

signal instances_spawned(instances: Array[Node])

@export var spawner: NucleusSpawner
@export_range(1, 1024, 1, "or_greater")
var count: int = 1


func _ready() -> void:
	if spawner == null:
		spawner = _find_spawner()

	if spawner == null:
		NucleusLog.error(
			"%s requires a NucleusSpawner." % get_path(),
			&"SpawnActionEffect",
		)


func can_apply(_context: Dictionary) -> Error:
	if spawner == null:
		return ERR_UNCONFIGURED

	return (
		OK
		if spawner.can_spawn(count)
		else ERR_CANT_CREATE
	)


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	var instances: Array[Node] = []

	for index: int in range(count):
		var spawn_context: Dictionary = context.duplicate(true)
		spawn_context["spawn_index"] = index

		var instance: Node = spawner.spawn(
			spawn_context
		)

		if instance == null:
			return ERR_CANT_CREATE

		instances.append(instance)

	instances_spawned.emit(instances)

	return OK


func _find_spawner() -> NucleusSpawner:
	var root: Node = get_parent()

	while root:
		var spawners: Array[NucleusSpawner] = []

		if root is NucleusSpawner:
			spawners.append(root as NucleusSpawner)

		for node: Node in NucleusNodeUtils.descendants(root):
			if node is NucleusSpawner:
				spawners.append(node as NucleusSpawner)

		if spawners.size() == 1:
			return spawners[0]

		if spawners.size() > 1:
			NucleusLog.warning(
				"%s found multiple spawners; assign one explicitly."
				% get_path(),
				&"SpawnActionEffect",
			)
			return null

		root = root.get_parent()

	return null
