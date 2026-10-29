class_name NucleusSpawner
extends Node
## Base scene-owned spawner backed by NucleusObjectPool.

signal spawned(
	instance: Node,
	context: Dictionary,
)

@export var pool: NucleusObjectPool
@export var spawn_parent: Node


func can_spawn(count: int = 1) -> bool:
	return (
		pool != null
		and pool.can_reserve(count)
	)


func spawn(_context: Dictionary = {}) -> Node:
	return null
