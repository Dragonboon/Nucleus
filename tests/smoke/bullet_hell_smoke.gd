extends Node2D
## Sustained composition/lifecycle probe, not a GPU benchmark.

var _field: NucleusBulletField2D
var _renderer: NucleusBulletMultiMesh2D
var _emitter: NucleusBulletEmitter2D
var _ticks: int = 0
var _admitted: int = 0


func _ready() -> void:
	_field = NucleusBulletField2D.new()
	_field.capacity = 4096
	_field.max_spawns_per_frame = 256
	_field.draw_enabled = false
	_field.reserve_storage()
	add_child(_field)
	_renderer = NucleusBulletMultiMesh2D.new()
	_renderer.bullet_field = _field
	_renderer.max_instances = _field.capacity
	add_child(_renderer)
	_emitter = NucleusBulletEmitter2D.new()
	_emitter.bullet_field = _field
	_emitter.pattern = NucleusBulletPattern2D.new()
	_emitter.pattern.mode = NucleusBulletPattern2D.Mode.LOTUS
	_emitter.pattern.count = 256
	_emitter.pattern.lifetime = 0.1
	_emitter.interval = 1.0 / 60.0
	_emitter.angular_speed = 2.0
	_emitter.burst_emitted.connect(func(admitted: int, _requested: int) -> void:
		_admitted += admitted)
	add_child(_emitter)
	process_physics_priority = 20


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _field.active_count() > 4096 or _field.storage_count() != 4096:
		_fail("Capacity/storage invariant failed during continuous spawning.")
		return
	if _ticks < 180:
		return
	_emitter.emitting = false
	_renderer.sync_bullets()
	if _admitted < 20000 or _renderer.multimesh.visible_instance_count != _field.active_count():
		_fail("Sustained emission or renderer composition failed.")
		return
	var targets := NucleusBulletTargetBatch2D.new()
	targets.upsert_circle(7, Vector2.ZERO, 100)
	if targets.query_bullet_hits(_field, 16).size() != 16:
		_fail("Indexed swept hits must honor their result budget.")
		return
	_field.clear_bullets()
	_renderer.sync_bullets()
	if _renderer.multimesh.visible_instance_count != 0:
		_fail("Reset left visible instances.")
		return
	print("Nucleus bullet hell composition: PASS (%d admissions, 4096 retained slots)." % _admitted)
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
