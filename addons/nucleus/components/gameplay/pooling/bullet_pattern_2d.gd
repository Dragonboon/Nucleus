class_name NucleusBulletPattern2D
extends Resource
## Immutable authoring data for simple mass-projectile emission.

enum Mode { RADIAL, FAN, LINE, LOTUS, SPIRAL }

@export var mode: Mode = Mode.RADIAL
@export_range(1, 20000, 1) var count: int = 12
@export_range(0.0, 100000.0, 1.0) var speed: float = 200.0
@export_range(0.001, 120.0, 0.001) var lifetime: float = 3.0
@export_range(0.0, 6.283185307, 0.01) var spread: float = PI / 2.0
@export var angle_offset: float = 0.0
@export_range(0.0, 1000.0) var line_spacing: float = 12.0
@export_range(1, 64) var petals: int = 6
@export_range(0.0, 1.0) var minimum_speed_ratio: float = 0.2
@export_range(0.0, 32.0) var spiral_turns: float = 2.0


func is_valid() -> bool:
	return (
		mode in [Mode.RADIAL, Mode.FAN, Mode.LINE, Mode.LOTUS, Mode.SPIRAL]
		and count > 0 and count <= 20000
		and is_finite(speed) and speed >= 0.0
		and is_finite(lifetime) and lifetime > 0.0
		and is_finite(spread) and spread >= 0.0
		and is_finite(angle_offset)
		and is_finite(line_spacing) and line_spacing >= 0.0
		and petals >= 1 and petals <= 64
		and is_finite(minimum_speed_ratio) and minimum_speed_ratio >= 0.0
		and minimum_speed_ratio <= 1.0
		and is_finite(spiral_turns) and spiral_turns >= 0.0 and spiral_turns <= 32.0
	)


func emit_into(
	field: NucleusBulletField2D,
	local_position: Vector2,
	local_direction: Vector2 = Vector2.RIGHT,
	phase: float = 0.0,
) -> int:
	if not is_instance_valid(field) or not is_valid() or not local_position.is_finite():
		return 0
	if not local_direction.is_finite() or not is_finite(phase):
		return 0
	var emitted := 0
	for index in mini(count, field.available_spawns()):
		var origin := local_position + offset_at(index, local_direction, phase)
		if field.spawn(origin, velocity_at(index, local_direction, phase), lifetime) < 0:
			break
		emitted += 1
	return emitted


## Samples assume a validated profile and index in [0, count); no per-shot allocations.
func velocity_at(index: int, direction: Vector2 = Vector2.RIGHT, phase: float = 0.0) -> Vector2:
	var angle := direction.angle() + angle_offset + phase
	var ratio := 1.0
	var t := 0.5 if count == 1 else float(index) / float(count - 1)
	match mode:
		Mode.RADIAL:
			angle += TAU * float(index) / float(count)
		Mode.FAN:
			angle += (t - 0.5) * spread
		Mode.LOTUS:
			var theta := TAU * float(index) / float(count)
			angle += theta
			ratio = lerpf(minimum_speed_ratio, 1.0, absf(cos(float(petals) * theta * 0.5)))
		Mode.SPIRAL:
			angle += TAU * spiral_turns * t
			ratio = lerpf(minimum_speed_ratio, 1.0, t)
	return Vector2.from_angle(angle) * speed * ratio


func offset_at(index: int, direction: Vector2 = Vector2.RIGHT, phase: float = 0.0) -> Vector2:
	if mode != Mode.LINE:
		return Vector2.ZERO
	var normal := Vector2.from_angle(direction.angle() + angle_offset + phase + PI / 2.0)
	return normal * (float(index) - float(count - 1) * 0.5) * line_spacing
