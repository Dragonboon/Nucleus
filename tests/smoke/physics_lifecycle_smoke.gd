extends Node

var _failures: Array[String] = []
var _refreshes: int = 0
var _paths: int = 0
var _evaluations: int = 0


func _ready() -> void:
	await _check_pool_sleep()
	await _check_collision_release()
	await _check_scheduling()
	if _failures.is_empty():
		print("Physics lifecycle composition: PASS")
	else:
		for failure in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _ticks(count: int = 3) -> void:
	for index in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func _check_pool_sleep() -> void:
	for body: Node in [RigidBody2D.new(), RigidBody3D.new()]:
		body.set("gravity_scale", 0.0)
		add_child(body)
		await _ticks()
		var adapter := NucleusPoolable.new()
		adapter.target = body
		adapter.manage_process_modes = false
		body.add_child(adapter)
		adapter._capture_baseline(false)
		adapter._set_inactive()
		await _ticks()
		if not bool(body.get("sleeping")):
			_failures.append("Released %s must sleep after physics synchronization." % body.get_class())
		adapter._activate({})
		await _ticks()
		if bool(body.get("sleeping")):
			_failures.append("Acquired %s must restore awake baseline." % body.get_class())
		body.queue_free()
		await _ticks()


func _check_scheduling() -> void:
	var scheduler := NucleusUpdateScheduler.new()
	scheduler.max_callbacks_per_frame = 2
	add_child(scheduler)
	var brain := NucleusAIUtilityBrain.new()
	brain.update_scheduler = scheduler
	brain.evaluation_completed.connect(func(
		_option: NucleusAIUtilityOption, _score: float, _context: Dictionary,
	) -> void: _evaluations += 1)
	add_child(brain)
	await _ticks(20)
	if _evaluations == 0:
		_failures.append("Scheduled utility AI did not evaluate.")
	brain.process_mode = Node.PROCESS_MODE_DISABLED
	var old_evaluations := _evaluations
	await _ticks(20)
	if _evaluations != old_evaluations:
		_failures.append("Scheduled utility AI bypassed disabled processing.")
	remove_child(brain)
	brain.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(brain)
	await _ticks(20)
	if _evaluations <= old_evaluations:
		_failures.append("Utility AI failed to resume after re-entry.")
	brain.queue_free()
	var selector := NucleusTargetingAgent.new()
	selector.update_scheduler = scheduler
	selector.selection_refreshed.connect(func(_target: NucleusTargetable) -> void:
		_refreshes += 1)
	add_child(selector)
	await _ticks(15)
	if _refreshes == 0 or selector.is_physics_processing():
		_failures.append("Targeting must dispatch through its scheduler.")
	remove_child(selector)
	var previous := _refreshes
	await _ticks(15)
	if _refreshes != previous:
		_failures.append("Detached targeting retained a callback.")
	add_child(selector)
	await _ticks(15)
	if _refreshes <= previous:
		_failures.append("Targeting failed to register on re-entry.")
	selector.process_mode = Node.PROCESS_MODE_DISABLED
	previous = _refreshes
	await _ticks(15)
	if _refreshes != previous:
		_failures.append("Scheduler bypassed disabled targeting.")
	selector.queue_free()
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(-10, 0, -10), Vector3(-10, 0, 10),
		Vector3(10, 0, 10), Vector3(10, 0, -10),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	add_child(region)
	var actor := Node3D.new()
	add_child(actor)
	var agent := NavigationAgent3D.new()
	actor.add_child(agent)
	var follower := NucleusNavigationFollower3D.new()
	follower.agent = agent
	follower.origin = actor
	follower.update_scheduler = scheduler
	follower.target_changed.connect(func(_position: Vector3) -> void: _paths += 1)
	actor.add_child(follower)
	follower.set_target_position(Vector3(5, 0, 0))
	await _ticks(30)
	if _paths == 0 or follower.output_velocity.length() <= 0.0:
		_failures.append("Scheduled 3D navigation did not produce native path velocity.")
	actor.remove_child(follower)
	previous = _paths
	await _ticks(15)
	if _paths != previous:
		_failures.append("Detached navigation retained work.")
	actor.add_child(follower)
	follower.set_target_position(Vector3(-5, 0, 0))
	await _ticks(30)
	if _paths <= previous or follower.output_velocity.x >= 0.0:
		_failures.append("3D navigation did not resume on re-entry.")
	actor.queue_free()
	region.queue_free()
	scheduler.queue_free()
	await _ticks()


func _check_collision_release() -> void:
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	shape.owner = body
	var packed := PackedScene.new()
	packed.pack(body)
	body.free()
	var pool := NucleusObjectPool.new()
	pool.packed_scene = packed
	pool.prewarm_count = 1
	pool.maximum_size = 1
	add_child(pool)
	var area := Area2D.new()
	var sensor_shape := CollisionShape2D.new()
	sensor_shape.shape = CircleShape2D.new()
	area.add_child(sensor_shape)
	add_child(area)
	var release_on_contact := func(instance: Node2D) -> void: pool.release(instance)
	area.body_entered.connect(release_on_contact)
	var instance := pool.acquire() as CharacterBody2D
	instance.velocity = Vector2(100, 0)
	await _ticks(8)
	if pool.get_active_count() != 0 or not instance.velocity.is_zero_approx():
		_failures.append("Release from overlap callback failed to reset root body.")
	if not (instance.get_child(0) as CollisionShape2D).disabled:
		_failures.append("Deferred release left a collision shape active.")
	area.body_entered.disconnect(release_on_contact)
	var reused := pool.acquire() as CharacterBody2D
	await _ticks()
	if reused != instance or (reused.get_child(0) as CollisionShape2D).disabled:
		_failures.append("Reacquire did not restore the same native collision shape.")
	pool.queue_free()
	area.queue_free()
	await _ticks()
