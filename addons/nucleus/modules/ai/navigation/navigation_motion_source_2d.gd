@tool
class_name NucleusNavigationMotionSource2D
extends NucleusMotionSource2D
## Translates NavigationFollower2D output to the existing CharacterBody2D motor.
## Navigation decides intent; the motor still owns actual physics movement.

@export var follower: NucleusNavigationFollower2D:
	set(value):
		follower = value
		update_configuration_warnings()

@export_group("Synchronization")
@export var synchronize_follower_speed: bool = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if follower == null:
		warnings.append("Assign a NucleusNavigationFollower2D.")
	return warnings


func get_desired_velocity(
	_body: CharacterBody2D,
	_max_speed: float,
) -> Vector2:
	if not enabled or follower == null:
		return Vector2.ZERO

	var resolved_speed := maxf(_max_speed, 0.0)
	if synchronize_follower_speed:
		synchronize_speed(resolved_speed)

	if resolved_speed <= 0.0:
		return Vector2.ZERO

	return follower.output_velocity.limit_length(resolved_speed)


func synchronize_speed(max_speed: float) -> void:
	if follower == null:
		return

	var resolved_speed := maxf(max_speed, 0.0)
	if not is_equal_approx(follower.movement_speed, resolved_speed):
		follower.movement_speed = resolved_speed

	if (
		follower.agent != null
		and follower.synchronize_agent_max_speed
		and not is_equal_approx(follower.agent.max_speed, resolved_speed)
	):
		follower.agent.max_speed = resolved_speed
