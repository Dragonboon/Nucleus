class_name NucleusBulletPattern2D
extends Resource
## Immutable authoring data for simple mass-projectile emission.

enum Mode { RADIAL, FAN }

@export var mode: Mode = Mode.RADIAL
@export_range(1, 20000, 1) var count: int = 12
@export_range(0.0, 100000.0, 1.0) var speed: float = 200.0
@export_range(0.001, 120.0, 0.001) var lifetime: float = 3.0
@export_range(0.0, 6.283185307, 0.01) var spread: float = PI / 2.0
@export var angle_offset: float = 0.0


func is_valid() -> bool:
	return (
		count > 0 and count <= 20000
		and is_finite(speed) and speed >= 0.0
		and is_finite(lifetime) and lifetime > 0.0
		and is_finite(spread) and spread >= 0.0
		and is_finite(angle_offset)
	)


func emit_into(
	field: NucleusBulletField2D,
	local_position: Vector2,
	local_direction: Vector2 = Vector2.RIGHT,
) -> int:
	if field == null or not is_valid() or not local_position.is_finite():
		return 0
	if not local_direction.is_finite():
		return 0
	var angle := local_direction.angle() + angle_offset
	if mode == Mode.RADIAL:
		return field.spawn_radial(local_position, speed, count, lifetime, angle)
	return field.spawn_fan(local_position, speed, count, lifetime, angle, spread)
