class_name NucleusCameraImpulseProfile3D
extends Resource
## Reusable 3D camera impulse authored as transform/FOV amplitudes + noise.

@export_range(0.001, 10.0, 0.001, "or_greater")
var duration: float = 0.25

@export_group("Kick")
@export var position_kick: Vector3 = Vector3.ZERO
@export var rotation_kick_degrees: Vector3 = Vector3.ZERO
@export_range(-90.0, 90.0, 0.01)
var fov_kick_degrees: float = 0.0

@export_group("Shake")
@export var position_amplitude: Vector3 = Vector3(0.03, 0.03, 0.02)
@export var rotation_degrees: Vector3 = Vector3(1.0, 0.6, 0.5)
@export_range(0.0, 45.0, 0.01, "or_greater")
var fov_noise_degrees: float = 0.0
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
