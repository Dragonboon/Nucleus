class_name NucleusObjectPool
extends Node
## Scene-owned PackedScene object pool.
##
## Pool lifetime owns every instance it creates, even when active instances are
## reparented elsewhere in the same SceneTree.

signal prewarmed(created_count: int)
signal prewarm_progress(
	created_count: int,
	total_count: int,
	target_total: int,
)
signal instance_created(instance: Node)
signal instance_reserved(instance: Node)
signal instance_acquired(
	instance: Node,
	context: Dictionary,
)
signal instance_released(instance: Node)
signal exhausted

@export var packed_scene: PackedScene

@export_group("Capacity")
@export_range(0, 100000, 1, "or_greater")
var prewarm_count: int = 0
@export_range(0, 100000, 1, "or_greater")
var maximum_size: int = 0
@export var allow_growth: bool = true
@export var auto_prewarm: bool = true
## Zero preserves the historical synchronous auto-prewarm behavior. A positive
## value spreads automatic prewarming across frames.
@export_range(0, 10000, 1, "or_greater")
var auto_prewarm_instances_per_frame: int = 0

@export_group("Ownership")
@export var active_parent: Node
@export var auto_add_poolable: bool = true

var _inactive_root: Node
var _available: Array[Node] = []
var _reserved: Dictionary[int, Node] = {}
var _active: Dictionary[int, Node] = {}
var _poolables: Dictionary[int, NucleusPoolable] = {}
var _incremental_prewarm_running: bool = false


func _enter_tree() -> void:
	_inactive_root = Node.new()
	_inactive_root.name = "_PoolInactive"
	add_child(_inactive_root)


func _ready() -> void:
	if active_parent == null:
		active_parent = get_parent()

	if active_parent == null:
		active_parent = self

	if packed_scene == null:
		NucleusLog.warning(
			"%s has no PackedScene assigned." % get_path(),
			&"ObjectPool",
		)
		return

	if auto_prewarm and prewarm_count > 0:
		if auto_prewarm_instances_per_frame > 0:
			_run_auto_incremental_prewarm.call_deferred()
		else:
			prewarm(prewarm_count)


func _exit_tree() -> void:
	_free_owned_instances()


func prewarm(target_total: int = -1) -> int:
	if packed_scene == null:
		return 0

	_prune_invalid()
	var desired_total: int = _resolve_prewarm_target(target_total)
	var created: int = 0

	while _get_total_count_unchecked() < desired_total:
		if _create_available_instance() == null:
			break

		created += 1

	if created > 0:
		prewarm_progress.emit(
			created,
			_get_total_count_unchecked(),
			desired_total,
		)
		prewarmed.emit(created)

	return created


## Prewarms without concentrating all PackedScene instantiation into one frame.
## The returned value is available after awaiting the call.
func prewarm_incremental(
	target_total: int = -1,
	instances_per_frame: int = 4,
) -> int:
	if packed_scene == null or instances_per_frame <= 0:
		return 0
	if _incremental_prewarm_running:
		return 0

	_prune_invalid()
	var desired_total: int = _resolve_prewarm_target(target_total)
	if _get_total_count_unchecked() >= desired_total:
		return 0

	if not is_inside_tree():
		return prewarm(desired_total)

	_incremental_prewarm_running = true
	var created: int = 0

	while _get_total_count_unchecked() < desired_total and is_inside_tree():
		var batch_created: int = 0

		while (
			batch_created < instances_per_frame
			and _get_total_count_unchecked() < desired_total
		):
			if _create_available_instance() == null:
				break

			created += 1
			batch_created += 1

		prewarm_progress.emit(
			created,
			_get_total_count_unchecked(),
			desired_total,
		)

		if batch_created == 0 or _get_total_count_unchecked() >= desired_total:
			break

		await get_tree().process_frame

	_incremental_prewarm_running = false

	if created > 0:
		prewarmed.emit(created)

	return created


func is_incremental_prewarm_running() -> bool:
	return _incremental_prewarm_running


func can_reserve(count: int = 1) -> bool:
	if count <= 0:
		return true

	_prune_invalid()

	if _available.size() >= count:
		return true

	if not allow_growth or packed_scene == null:
		return false

	if maximum_size <= 0:
		return true

	var missing: int = count - _available.size()
	return _get_total_count_unchecked() + missing <= maximum_size


## Reserves an inactive instance without activating it.
##
## This two-phase API lets spawners set transforms before acquired callbacks run.
func reserve(parent: Node = null) -> Node:
	_prune_invalid()

	var instance: Node

	if not _available.is_empty():
		instance = _available.pop_back()
	elif allow_growth and _has_growth_capacity():
		instance = _create_available_instance()

		if instance:
			_available.erase(instance)

	if instance == null:
		exhausted.emit()
		return null

	var resolved_parent: Node = parent if parent else active_parent

	if resolved_parent == null:
		resolved_parent = self

	if instance.get_parent() != resolved_parent:
		instance.reparent(
			resolved_parent,
			true,
		)

	if instance is Node2D or instance is Node3D:
		instance.reset_physics_interpolation()

	var instance_id: int = instance.get_instance_id()
	_reserved[instance_id] = instance
	instance_reserved.emit(instance)

	return instance


func activate(
	instance: Node,
	context: Dictionary = {},
) -> Error:
	if instance == null:
		return ERR_INVALID_PARAMETER

	var instance_id: int = instance.get_instance_id()

	if not _reserved.has(instance_id):
		return ERR_DOES_NOT_EXIST

	var poolable: NucleusPoolable = _poolables.get(
		instance_id
	)

	if poolable == null:
		return ERR_UNCONFIGURED

	_reserved.erase(instance_id)
	_active[instance_id] = instance

	poolable._activate(context)

	instance_acquired.emit(
		instance,
		context.duplicate(true),
	)

	return OK


func acquire(
	parent: Node = null,
	context: Dictionary = {},
) -> Node:
	var instance: Node = reserve(parent)

	if instance == null:
		return null

	var error: Error = activate(
		instance,
		context,
	)

	if error != OK:
		release(instance)
		return null

	return instance


func release(instance: Node) -> Error:
	if instance == null:
		return ERR_INVALID_PARAMETER

	var instance_id: int = instance.get_instance_id()

	if not _poolables.has(instance_id):
		return ERR_DOES_NOT_EXIST

	if instance in _available:
		return OK

	var poolable: NucleusPoolable = _poolables[instance_id]

	_active.erase(instance_id)
	_reserved.erase(instance_id)

	poolable._set_inactive(true)

	if (
		is_instance_valid(_inactive_root)
		and instance.get_parent() != _inactive_root
	):
		instance.reparent(
			_inactive_root,
			true,
		)

	_available.append(instance)
	instance_released.emit(instance)

	return OK


func release_all() -> void:
	var instances: Array[Node] = []

	for instance: Node in _active.values():
		instances.append(instance)

	for instance: Node in _reserved.values():
		if instance not in instances:
			instances.append(instance)

	for instance: Node in instances:
		if is_instance_valid(instance):
			release(instance)


func owns(instance: Node) -> bool:
	if instance == null:
		return false

	return _poolables.has(
		instance.get_instance_id()
	)


func get_poolable(
	instance: Node,
) -> NucleusPoolable:
	if not owns(instance):
		return null

	return _poolables.get(
		instance.get_instance_id()
	)


func get_total_count() -> int:
	_prune_invalid()
	return _get_total_count_unchecked()


func get_available_count() -> int:
	_prune_invalid()
	return _available.size()


func get_reserved_count() -> int:
	_prune_invalid()
	return _reserved.size()


func get_active_count() -> int:
	_prune_invalid()
	return _active.size()


func get_active_instances() -> Array[Node]:
	_prune_invalid()

	var result: Array[Node] = []

	for instance: Node in _active.values():
		result.append(instance)

	return result


func _run_auto_incremental_prewarm() -> void:
	await prewarm_incremental(
		prewarm_count,
		auto_prewarm_instances_per_frame,
	)


func _resolve_prewarm_target(target_total: int) -> int:
	var desired_total: int = (
		prewarm_count
		if target_total < 0
		else maxi(0, target_total)
	)

	if maximum_size > 0:
		desired_total = mini(
			desired_total,
			maximum_size,
		)

	return desired_total


func _create_available_instance() -> Node:
	if packed_scene == null or not _has_growth_capacity():
		return null

	var instance: Node = packed_scene.instantiate()

	if instance == null:
		return null

	var poolable: NucleusPoolable = _find_poolable(
		instance
	)

	if poolable == null and auto_add_poolable:
		poolable = NucleusPoolable.new()
		poolable.name = "Poolable"
		instance.add_child(poolable)

	if poolable == null:
		NucleusLog.error(
			"Pooled scene '%s' requires NucleusPoolable."
			% packed_scene.resource_path,
			&"ObjectPool",
		)
		instance.queue_free()
		return null

	# Compose Poolable before the scene enters the tree so sibling adapters can
	# discover it from their first _ready() callback.
	_inactive_root.add_child(instance)

	var instance_id: int = instance.get_instance_id()
	_poolables[instance_id] = poolable

	poolable._bind_pool(
		self,
		instance,
	)

	_available.append(instance)
	instance_created.emit(instance)

	return instance


func _find_poolable(
	instance: Node,
) -> NucleusPoolable:
	if instance is NucleusPoolable:
		return instance as NucleusPoolable

	for node: Node in NucleusNodeUtils.descendants(
		instance,
		true,
	):
		if node is NucleusPoolable:
			return node as NucleusPoolable

	return null


func _has_growth_capacity() -> bool:
	if maximum_size <= 0:
		return true

	return _get_total_count_unchecked() < maximum_size


func _get_total_count_unchecked() -> int:
	return (
		_available.size()
		+ _reserved.size()
		+ _active.size()
	)


func _prune_invalid() -> void:
	for instance_id: int in _poolables.keys():
		if not is_instance_valid(_poolables[instance_id]):
			_poolables.erase(instance_id)

	for index: int in range(
		_available.size() - 1,
		-1,
		-1,
	):
		if not is_instance_valid(_available[index]):
			_available.remove_at(index)

	for instance_id: int in _reserved.keys():
		if not is_instance_valid(_reserved[instance_id]):
			_reserved.erase(instance_id)
			_poolables.erase(instance_id)

	for instance_id: int in _active.keys():
		if not is_instance_valid(_active[instance_id]):
			_active.erase(instance_id)
			_poolables.erase(instance_id)


func _free_owned_instances() -> void:
	_incremental_prewarm_running = false
	var instances: Array[Node] = []

	for instance: Node in _available:
		instances.append(instance)

	for instance: Node in _reserved.values():
		if instance not in instances:
			instances.append(instance)

	for instance: Node in _active.values():
		if instance not in instances:
			instances.append(instance)

	_available.clear()
	_reserved.clear()
	_active.clear()
	_poolables.clear()

	for instance: Node in instances:
		if is_instance_valid(instance):
			instance.queue_free()
