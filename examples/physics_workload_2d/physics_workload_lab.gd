extends Node2D
## Repeatable live workload. Native physics, AI and exact bullet queries remain separate.

@export_range(1, 2000, 1) var target_count: int = 128
@export_range(1, 200000, 1) var bullet_capacity: int = 4096
@export var clustered: bool = false
@export var scheduled_decisions: bool = true
@export var approximate_separation: bool = true
@export var automatic_exit_ticks: int = 0

var field: NucleusBulletField2D
var scheduler: NucleusUpdateScheduler
var sampler: NucleusPerformanceSampler
var pool: NucleusObjectPool
var _batch := NucleusBulletTargetBatch2D.new()
var _points := NucleusSpatialPointIndex2D.new()
var _hits: Array[Vector2i] = []
var _label: Label
var _ticks: int = 0
var _decisions: int = 0
var _queries_usec: int = 0
var _recycled: int = 0
var _positions: PackedVector2Array = []
var _live_bodies: Array[Node] = []
var _report: String = ""
var _walkers: Array[CharacterBody2D] = []
var _destination: Node2D
var _path_requests: int = 0


func _ready() -> void:
	process_physics_priority = 30
	scheduler = NucleusUpdateScheduler.new()
	scheduler.max_callbacks_per_frame = 32
	scheduler.frame_budget_usec = 1500
	add_child(scheduler)
	sampler = NucleusPerformanceSampler.new()
	sampler.debug_build_only = false
	add_child(sampler)
	sampler.register_probe(&"workload/query_steering_ms", func() -> float:
		return float(_queries_usec) / 1000.0)
	sampler.register_probe(&"workload/hit_pairs", func() -> int: return _hits.size())
	field = NucleusBulletField2D.new()
	field.capacity = bullet_capacity
	field.max_spawns_per_frame = 64
	field.draw_enabled = false
	field.reserve_storage()
	add_child(field)
	var renderer := NucleusBulletMultiMesh2D.new()
	renderer.bullet_field = field
	renderer.max_instances = bullet_capacity
	add_child(renderer)
	var emitter := NucleusBulletEmitter2D.new()
	emitter.bullet_field = field
	emitter.position = Vector2(576, 324)
	emitter.pattern = NucleusBulletPattern2D.new()
	emitter.pattern.count = 64
	emitter.pattern.lifetime = 2.0
	emitter.pattern.speed = 180
	emitter.interval = 0.05
	emitter.angular_speed = 1.3
	add_child(emitter)
	for id in target_count:
		var selector := NucleusTargetingAgent.new()
		selector.update_scheduler = scheduler if scheduled_decisions else null
		selector.selection_refreshed.connect(_on_selection)
		add_child(selector)
		var target := NucleusTargetable.new()
		add_child(target)
		selector.register_candidate(target)
		var brain := NucleusAIUtilityBrain.new()
		brain.update_scheduler = scheduler if scheduled_decisions else null
		add_child(brain)
	var body := RigidBody2D.new()
	body.gravity_scale = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	shape.owner = body
	var packed := PackedScene.new()
	packed.pack(body)
	body.free()
	pool = NucleusObjectPool.new()
	pool.packed_scene = packed
	pool.maximum_size = 64
	pool.prewarm_count = 64
	pool.allow_growth = false
	pool.auto_prewarm_instances_per_frame = 4
	add_child(pool)
	_create_navigation_workload()
	_label = Label.new()
	_label.position = Vector2(16, 16)
	add_child(_label)


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_destination.position = Vector2(576, 324) + Vector2.from_angle(_ticks * 0.01) * 180
	_positions.resize(target_count)
	for id in target_count:
		var angle := float(id) * 2.399963 + float(_ticks) * 0.002
		var radius := 20.0 if clustered else 60.0 + float(id % 15) * 14.0
		var center := Vector2(576, 324) + Vector2.from_angle(angle) * radius
		_positions[id] = center
		_batch.upsert_circle(id, center, 8)
		_points.upsert(id, center)
	var started := Time.get_ticks_usec()
	_batch.query_bullet_hits_into(field, _hits)
	for id in target_count:
		NucleusCrowdSeparation2D.calculate(id, _positions[id], _points, 32, 24,
			96 if approximate_separation else 0)
	_queries_usec = Time.get_ticks_usec() - started
	if _ticks % 12 == 0:
		for instance: Node in _live_bodies:
			pool.release(instance)
		_live_bodies.clear()
		for index in 16:
			var instance := pool.acquire()
			if instance != null:
				(instance as Node2D).position = Vector2(100 + index * 35, 580)
				_live_bodies.append(instance)
				_recycled += 1
	_label.text = (
		"Physics workload | Space: density | S: save report\n"
		+ "bullets=%d targets=%d pairs=%d queries+steering=%dus\n"
		+ "decisions=%d pool=%d reused=%d clustered=%s\n%s"
	) % [field.active_count(), target_count, _hits.size(), _queries_usec,
		_decisions, pool.get_total_count(), _recycled, clustered, _report]
	queue_redraw()
	if automatic_exit_ticks > 0 and _ticks >= automatic_exit_ticks:
		var valid := _decisions > 0 and _recycled > 0 and pool.get_total_count() == 64
		valid = valid and field.active_count() > 0 and not _hits.is_empty()
		valid = valid and _path_requests > 0 and _walkers[0].position.distance_to(
			Vector2(120, 180)) > 10
		print("Physics workload composition: ", "PASS" if valid else "FAIL")
		get_tree().quit(0 if valid else 1)


func _draw() -> void:
	for walker in _walkers:
		draw_circle(walker.position, 5, Color.CYAN)
	for point in _positions:
		draw_circle(point, 8, Color(0.9, 0.4, 0.2, 0.5))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_SPACE:
		clustered = not clustered
		sampler.clear_history()
	if event.keycode == KEY_S:
		var path := "user://physics_workload_%d.json" % Time.get_ticks_msec()
		var report := sampler.build_report()
		report["workload"] = {
			"targets": target_count, "capacity": bullet_capacity, "clustered": clustered,
			"scheduled": scheduled_decisions, "approximate": approximate_separation,
			"ticks": _ticks, "last_query_usec": _queries_usec,
		}
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			_report = ProjectSettings.globalize_path(path)
		else:
			_report = "Report write failed: %s" % FileAccess.get_open_error()


func _on_selection(_target: NucleusTargetable) -> void:
	_decisions += 1


func _create_navigation_workload() -> void:
	var region := NavigationRegion2D.new()
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(0, 648),
	])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
	add_child(region)
	_destination = Node2D.new()
	_destination.position = Vector2(750, 324)
	add_child(_destination)
	for id in 32:
		var walker := CharacterBody2D.new()
		walker.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		walker.position = Vector2(120, 180 + id * 9)
		# Separate native workload layer; collision policy is fixture-owned.
		walker.collision_layer = 2
		walker.collision_mask = 2
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		(shape.shape as CircleShape2D).radius = 4
		walker.add_child(shape)
		var agent := NavigationAgent2D.new()
		walker.add_child(agent)
		var follower := NucleusNavigationFollower2D.new()
		follower.agent = agent
		follower.origin = walker
		follower.target_node = _destination
		follower.update_scheduler = scheduler if scheduled_decisions else null
		follower.target_changed.connect(func(_point: Vector2) -> void: _path_requests += 1)
		walker.add_child(follower)
		var source := NucleusNavigationMotionSource2D.new()
		source.follower = follower
		walker.add_child(source)
		var motor := NucleusCharacterMotor2D.new()
		motor.body = walker
		motor.motion_source = source
		motor.speed = 90
		motor.process_physics_priority = 1
		walker.add_child(motor)
		add_child(walker)
		_walkers.append(walker)
