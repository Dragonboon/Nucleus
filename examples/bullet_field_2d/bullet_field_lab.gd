extends Node2D
## Visual stress fixture, not a frame-rate certification.

@export_range(1, 200000, 1) var target_bullet_count: int = 12000
@export_range(1, 20000, 1) var emission_per_frame: int = 500
@export var projectile_speed: float = 80.0
@export var projectile_lifetime: float = 20.0

var _field: NucleusBulletField2D
@export var pattern_mode: NucleusBulletPattern2D.Mode = NucleusBulletPattern2D.Mode.LOTUS
@export var petals: int = 6
var _emitter: NucleusBulletEmitter2D
var _report_elapsed: float = 0.0


func _ready() -> void:
	_field = NucleusBulletField2D.new()
	_field.name = "BulletField"
	_field.capacity = maxi(target_bullet_count, 1)
	_field.max_spawns_per_frame = maxi(emission_per_frame, 1)
	_field.projectile_radius = 2.0
	_field.position = get_viewport_rect().size * 0.5
	_field.draw_enabled = false
	_field.reserve_storage()
	add_child(_field)
	var renderer := NucleusBulletMultiMesh2D.new()
	renderer.bullet_field = _field
	renderer.max_instances = _field.capacity
	add_child(renderer)
	_emitter = NucleusBulletEmitter2D.new()
	_emitter.bullet_field = _field
	_emitter.position = _field.position
	_emitter.pattern = NucleusBulletPattern2D.new()
	_emitter.pattern.mode = pattern_mode
	_emitter.pattern.petals = petals
	_emitter.pattern.count = emission_per_frame
	_emitter.pattern.speed = projectile_speed
	_emitter.pattern.lifetime = projectile_lifetime
	_emitter.angular_speed = 1.5
	_emitter.interval = 1.0 / 60.0
	add_child(_emitter)


func _process(delta: float) -> void:
	_report_elapsed += maxf(delta, 0.0)
	if _report_elapsed >= 2.0:
		print(
			"Bullet field: active=%d fps=%.1f"
			% [_field.active_count(), Engine.get_frames_per_second()]
		)
		_report_elapsed = 0.0
