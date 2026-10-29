class_name NucleusCameraImpulseProfile2D
extends Resource
## Reusable 2D camera impulse authored as amplitude + procedural noise.

@export_range(0.001, 10.0, 0.001, "or_greater")
var duration: float = 0.25

@export_group("Kick")
@export var position_kick: Vector2 = Vector2.ZERO
@export_range(-45.0, 45.0, 0.01)
var rotation_kick_degrees: float = 0.0

@export_group("Shake")
@export var position_amplitude: Vector2 = Vector2(6.0, 4.0)
@export_range(0.0, 45.0, 0.01, "or_greater")
var rotation_degrees: float = 1.5
@export_range(0.01, 200.0, 0.01, "or_greater")
var frequency: float = 24.0
@export_range(0.01, 10.0, 0.01, "or_greater")
var decay_power: float = 2.0

@export_group("Accessibility")
@export var respect_reduced_motion: bool = true
@export_range(0.0, 1.0, 0.01)
var reduced_motion_scale: float = 0.20

@export_group("Noise")
@export var seed: int = 0
