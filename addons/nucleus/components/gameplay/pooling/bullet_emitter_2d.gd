class_name NucleusBulletEmitter2D
extends Node2D
## Optional continuous cadence. Field owns capacity/simulation; game owns damage and activation.

signal burst_emitted(admitted: int, requested: int)

@export var bullet_field: NucleusBulletField2D
@export var pattern: NucleusBulletPattern2D
@export var emitting: bool = true
@export_range(0.001, 60.0) var interval: float = 0.1
@export var angular_speed: float = 0.0
@export_range(1, 64) var maximum_bursts_per_tick: int = 4
var _elapsed: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	# Field's default priority is zero: reset admission and integrate before emission.
	process_physics_priority = 10


func _physics_process(delta: float) -> void:
	advance(delta)


func reset_emission() -> void:
	_elapsed = 0.0
	_phase = 0.0


func advance(delta: float) -> int:
	if not emitting or not is_instance_valid(bullet_field) or not bullet_field.simulation_enabled:
		return 0
	if (pattern == null or not pattern.is_valid() or not is_finite(delta) or delta < 0.0
		or not is_finite(interval) or interval <= 0.0 or not is_finite(angular_speed)
		or maximum_bursts_per_tick < 1 or maximum_bursts_per_tick > 64):
		return 0
	if not is_inside_tree() or not bullet_field.is_inside_tree():
		return 0
	if is_zero_approx(bullet_field.global_transform.determinant()):
		return 0
	_phase = fposmod(_phase + angular_speed * delta, TAU)
	_elapsed += delta
	var due := mini(int(minf(floor(_elapsed / interval), 64.0)), maximum_bursts_per_tick)
	if due <= 0:
		return 0
	# Drop excessive catch-up debt: a hitch must not create an unbounded future queue.
	_elapsed = fmod(_elapsed, interval)
	var total := 0
	for burst in due:
		if (not is_instance_valid(bullet_field) or not emitting or pattern == null
			or not pattern.is_valid() or not bullet_field.simulation_enabled):
			break
		var origin := bullet_field.to_local(global_position)
		var direction := bullet_field.global_transform.basis_xform_inv(global_transform.x)
		var requested := pattern.count
		var phase := _phase - angular_speed * float(due - 1 - burst) * interval
		var admitted := pattern.emit_into(bullet_field, origin, direction, phase)
		total += admitted
		burst_emitted.emit(admitted, requested)
	return total
