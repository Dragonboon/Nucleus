class_name NucleusPooledLifetimeBinding
extends Node
## Reuses NucleusLifetime by returning its target to a pool on expiry.

@export var poolable: NucleusPoolable
@export var lifetime: NucleusLifetime
@export var restart_on_acquire: bool = true


func _ready() -> void:
	_resolve_dependencies()

	if poolable == null or lifetime == null:
		NucleusLog.error(
			"%s requires NucleusPoolable and NucleusLifetime."
			% get_path(),
			&"PooledLifetime",
		)
		return

	# The pool owns activation, so _ready() must never start a lifetime that can
	# expire while the instance is still prewarmed/inactive.
	lifetime.start_on_ready = false
	lifetime.auto_free_on_expire = false
	lifetime.cancel()

	poolable.acquired.connect(
		_on_acquired
	)
	poolable.released.connect(
		_on_released
	)
	lifetime.expired.connect(
		_on_expired
	)



func _exit_tree() -> void:
	if poolable:
		if poolable.acquired.is_connected(_on_acquired):
			poolable.acquired.disconnect(_on_acquired)

		if poolable.released.is_connected(_on_released):
			poolable.released.disconnect(_on_released)

	if lifetime and lifetime.expired.is_connected(_on_expired):
		lifetime.expired.disconnect(_on_expired)


func _on_acquired(_context: Dictionary) -> void:
	if restart_on_acquire:
		lifetime.start()


func _on_released() -> void:
	lifetime.cancel()


func _on_expired() -> void:
	var error: Error = poolable.request_release()

	if error != OK:
		NucleusLog.warning(
			"Could not return expired pooled object: %s"
			% error_string(error),
			&"PooledLifetime",
		)


func _resolve_dependencies() -> void:
	var root: Node = get_parent()

	while root and (poolable == null or lifetime == null):
		if poolable == null and root is NucleusPoolable:
			poolable = root as NucleusPoolable

		if lifetime == null and root is NucleusLifetime:
			lifetime = root as NucleusLifetime

		for node: Node in NucleusNodeUtils.descendants(root):
			if poolable == null and node is NucleusPoolable:
				poolable = node as NucleusPoolable

			if lifetime == null and node is NucleusLifetime:
				lifetime = node as NucleusLifetime

		root = root.get_parent()
