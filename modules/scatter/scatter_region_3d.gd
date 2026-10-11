class_name NucleusScatterRegion3D
extends Node3D
## Scene-owned scatter region. The game controls admission, priority and eviction.
## Generates with the existing materialization queue, then stages GPU batches.

signal region_ready(region_id: StringName, instance_count: int)
signal region_failed(region_id: StringName, error: Error)

@export var profile: NucleusScatterProfile3D
@export var surface: NucleusSurfaceSampler3D
@export var region_id: StringName = &"region"
@export var region_size: Vector2 = Vector2(32.0, 32.0)
@export var density_volumes: Array[NucleusScatterDensityVolume3D] = []
## Runtime callback; bind it before start_build(). Kept out of authored Resources.
var density_filter: Callable
@export_range(1, 4096, 1) var candidates_per_step: int = 128
@export_range(1, 512, 1) var batch_size_limit: int = 256
@export_range(1.0, 4096.0, 1.0) var spatial_batch_size: float = 16.0
@export_range(1, 8192, 1) var partition_transforms_per_frame: int = 512
@export_range(1, 32, 1) var batches_per_frame: int = 2

var _build_job: NucleusScatterBuildJob3D
var _queue: NucleusMaterializationQueue
var _generation_token: int = 0
var _pending_batches: Array[Dictionary] = []
var _generated_nodes: Array[NucleusScatterBatch3D] = []
var _instance_count: int = 0

# Partitioning is also bounded: no all-results scan in the completion callback.
var _source_groups: Dictionary = {}
var _source_keys: Array = []
var _source_group_index: int = 0
var _source_item_index: int = 0
var _buckets: Dictionary = {}
var _flush_keys: Array = []
var _flush_index: int = 0
var _flushing: bool = false
var _preparation_finished: bool = true


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	unload()


func _process(_delta: float) -> void:
	if not _preparation_finished:
		_partition_step()
	var count: int = mini(batches_per_frame, _pending_batches.size())
	for _index: int in range(count):
		var spec: Dictionary = _pending_batches.pop_front()
		var variant_id: int = int(spec["variant_id"])
		var transforms_value: Variant = spec["transforms"]
		var transforms: Array[Transform3D] = []
		if transforms_value is Array:
			transforms.assign(transforms_value)
		var variant: NucleusScatterVariant3D = profile.variants[variant_id]
		var batch: NucleusScatterBatch3D = NucleusScatterBatch3D.new()
		batch.name = "ScatterBatch_%d" % variant_id
		add_child(batch)
		var error: Error = batch.configure(variant, transforms)
		if error != OK:
			remove_child(batch)
			batch.free()
			_fail_active_build(error)
			return
		_generated_nodes.append(batch)
		_instance_count += transforms.size()
	if _preparation_finished and _pending_batches.is_empty():
		set_process(false)
		region_ready.emit(region_id, _instance_count)


func start_build(queue: NucleusMaterializationQueue) -> Error:
	if (
		queue == null or profile == null or surface == null
		or region_id == &"" or not is_inside_tree()
		or region_size.x <= 0.0 or region_size.y <= 0.0
		or spatial_batch_size <= 0.0 or batch_size_limit <= 0
	):
		return ERR_INVALID_PARAMETER
	if not profile.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER
	_generation_token += 1
	_cancel_active_job()
	_reset_staging()
	set_process(false)
	var next_job: NucleusScatterBuildJob3D = NucleusScatterBuildJob3D.new()
	next_job.cells_per_step = candidates_per_step
	var error: Error = next_job.configure(
		profile,
		surface,
		Vector2(global_position.x, global_position.z),
		region_size,
		region_id,
		density_volumes,
		density_filter,
	)
	if error != OK:
		return error
	_build_job = next_job
	_queue = queue
	var token: int = _generation_token
	next_job.completed.connect(
		func(result: Variant) -> void:
			_on_generation_complete(token, result)
	)
	next_job.failed.connect(
		func(job_error: Error) -> void:
			if token == _generation_token:
				region_failed.emit(region_id, job_error)
	)
	var job_id: int = queue.enqueue(next_job)
	if job_id <= 0:
		_build_job = null
		_queue = null
		return ERR_CANT_CREATE
	return OK


func unload() -> void:
	_generation_token += 1
	_cancel_active_job()
	_reset_staging()
	set_process(false)
	_clear_rendered()


func get_instance_count() -> int:
	return _instance_count


func get_batch_count() -> int:
	return _generated_nodes.size()


func is_building() -> bool:
	return (
		_build_job != null
		or not _preparation_finished
		or not _pending_batches.is_empty()
	)


func get_pending_batch_count() -> int:
	return _pending_batches.size()


func _cancel_active_job() -> void:
	if _build_job != null and not _build_job.is_terminal():
		if _queue != null:
			_queue.cancel_job(_build_job)
		else:
			_build_job.cancel()
	_build_job = null
	_queue = null


func _on_generation_complete(token: int, result: Variant) -> void:
	if token != _generation_token or not is_inside_tree():
		return
	_build_job = null
	_queue = null
	if not result is Dictionary:
		_fail_active_build(ERR_INVALID_DATA)
		return
	var payload: Dictionary = result
	var grouped_value: Variant = payload.get("groups", {})
	if not grouped_value is Dictionary:
		_fail_active_build(ERR_INVALID_DATA)
		return
	_reset_staging()
	_source_groups = grouped_value
	_source_keys = _source_groups.keys()
	_preparation_finished = false
	_clear_rendered()
	set_process(true)


func _partition_step() -> void:
	var budget: int = maxi(partition_transforms_per_frame, 1)
	while _source_group_index < _source_keys.size() and budget > 0:
		var variant_id: int = int(_source_keys[_source_group_index])
		var group_value: Variant = _source_groups.get(variant_id, [])
		if not group_value is Array:
			_source_group_index += 1
			_source_item_index = 0
			continue
		var group: Array = group_value
		if _source_item_index >= group.size():
			_source_group_index += 1
			_source_item_index = 0
			continue
		var value: Variant = group[_source_item_index]
		_source_item_index += 1
		budget -= 1
		if not value is Transform3D:
			continue
		var transform: Transform3D = value
		var position: Vector3 = transform.origin
		var key: Vector3i = Vector3i(
			variant_id,
			floori(position.x / spatial_batch_size),
			floori(position.z / spatial_batch_size),
		)
		if not _buckets.has(key):
			_buckets[key] = []
		var bucket: Array = _buckets[key]
		bucket.append(transform)
		var limit: int = mini(
			batch_size_limit, NucleusScatterBatch3D.MAX_BATCH_INSTANCES,
		)
		if bucket.size() >= limit:
			_pending_batches.append({
				"variant_id": variant_id,
				"transforms": bucket,
			})
			_buckets.erase(key)
	if _source_group_index < _source_keys.size():
		return
	if not _flushing:
		_flushing = true
		_flush_keys = _buckets.keys()
	while _flush_index < _flush_keys.size() and budget > 0:
		var key_value: Variant = _flush_keys[_flush_index]
		var bucket_value: Variant = _buckets.get(key_value, [])
		var key: Vector3i = key_value
		if bucket_value is Array:
			var bucket: Array = bucket_value
			if not bucket.is_empty():
				_pending_batches.append({
					"variant_id": key.x,
					"transforms": bucket,
				})
		_buckets.erase(key_value)
		_flush_index += 1
		budget -= 1
	if _flush_index >= _flush_keys.size():
		_preparation_finished = true
		_source_groups.clear()
		_source_keys.clear()
		_flush_keys.clear()


func _reset_staging() -> void:
	_pending_batches.clear()
	_source_groups.clear()
	_source_keys.clear()
	_source_group_index = 0
	_source_item_index = 0
	_buckets.clear()
	_flush_keys.clear()
	_flush_index = 0
	_flushing = false
	_preparation_finished = true


func _clear_rendered() -> void:
	for batch: NucleusScatterBatch3D in _generated_nodes:
		if is_instance_valid(batch):
			remove_child(batch)
			batch.queue_free()
	_generated_nodes.clear()
	_instance_count = 0


func _fail_active_build(error: Error) -> void:
	_reset_staging()
	set_process(false)
	_clear_rendered()
	region_failed.emit(region_id, error)
