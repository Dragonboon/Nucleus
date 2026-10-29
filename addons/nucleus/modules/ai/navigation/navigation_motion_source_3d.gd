@tool
class_name NucleusNavigationMotionSource3D
extends NucleusPlanarMotionSource3D
## Adapts NavigationFollower3D output into CharacterMotor3D movement intent.
##
## Navigation owns path/avoidance intent. CharacterMotor3D remains the physical
## movement owner.

@export var follower: NucleusNavigationFollower3D:
	set(value):
		follower = value
		update_configuration_warnings()

@export_group("Synchronization")
@export var synchronize_follower_speed: bool = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if follower == null:
		warnings.append("Assign a NucleusNavigationFollower3D.")

	return warnings


func get_desired_velocity(
	body: CharacterBody3D,
	max_planar_speed: float,
) -> Vector3:
	if not enabled or follower == null:
		return Vector3.ZERO

	var resolved_speed := maxf(max_planar_speed, 0.0)

	if synchronize_follower_speed:
		_sync_speed(resolved_speed)

	var velocity := follower.output_velocity

	if body != null:
		velocity = NucleusMotionMath.planar_component_3d(
			velocity,
			body.up_direction,
		)

	if resolved_speed <= 0.0:
		return Vector3.ZERO

	if velocity.length() > resolved_speed:
		velocity = velocity.normalized() * resolved_speed

	return velocity


func synchronize_speed(max_planar_speed: float) -> void:
	_sync_speed(maxf(max_planar_speed, 0.0))


func _sync_speed(max_planar_speed: float) -> void:
	if follower == null:
		return

	if not is_equal_approx(
		follower.movement_speed,
		max_planar_speed,
	):
		follower.movement_speed = max_planar_speed

	if (
		follower.agent != null
		and follower.synchronize_agent_max_speed
		and not is_equal_approx(
			follower.agent.max_speed,
			max_planar_speed,
		)
	):
		follower.agent.max_speed = max_planar_speed
