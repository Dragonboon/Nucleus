@tool
class_name NucleusPlanarMotionSource3D
extends Node
## Optional world-space planar movement-intent source for CharacterMotor3D.
##
## Player input can keep using NucleusMotionInput directly. This contract exists
## for AI, autopilot, replay, cutscenes, network proxies, and similar producers.

@export var enabled: bool = true


func get_desired_velocity(
	_body: CharacterBody3D,
	_max_planar_speed: float,
) -> Vector3:
	return Vector3.ZERO
