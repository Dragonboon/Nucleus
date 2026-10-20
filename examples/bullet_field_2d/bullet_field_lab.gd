extends Node2D
## Visual stress fixture, not a frame-rate certification.

@export_range(1, 200000, 1) var target_bullet_count: int = 12000
@export_range(1, 20000, 1) var emission_per_frame: int = 500
@export var projectile_speed: float = 80.0
@export var projectile_lifetime: float = 20.0

var _field: NucleusBulletField2D
var _frame_count: int = 0
var _report_elapsed: float = 0.0


func _ready() -> void:
	_field = NucleusBulletField2D.new()
	_field.name = "BulletField"
	_field.capacity = maxi(target_bullet_count, 1)
	_field.max_spawns_per_frame = maxi(emission_per_frame, 1)
	_field.projectile_radius = 2.0
	_field.position = get_viewport_rect().size * 0.5
	add_child(_field)


func _process(delta: float) -> void:
	_report_elapsed += maxf(delta, 0.0)
	if _report_elapsed >= 2.0:
		print(
			"Bullet field: active=%d fps=%.1f"
			% [_field.active_count(), Engine.get_frames_per_second()]
		)
		_report_elapsed = 0.0


func _physics_process(_delta: float) -> void:
	if _field == null or _field.active_count() >= target_bullet_count:
		return
	_frame_count += 1
	var remaining := target_bullet_count - _field.active_count()
	var count := mini(remaining, emission_per_frame)
	var angle := float(_frame_count) * 0.17
	_field.spawn_radial(Vector2.ZERO, projectile_speed, count, projectile_lifetime, angle)
