@tool
class_name NucleusMotionSource2D
extends Node
## Optional world-space movement intent for CharacterBody2D motors.
##
## Input, navigation, replay and remote control can supply velocity without
## taking ownership of CharacterBody2D.move_and_slide().

@export var enabled: bool = true


func get_desired_velocity(
	_body: CharacterBody2D,
	_max_speed: float,
) -> Vector2:
	return Vector2.ZERO
