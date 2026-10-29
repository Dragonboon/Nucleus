class_name NucleusUIVisualStateProfile
extends Resource
## Additive visual state for reusable UI microinteractions.
##
## Theme remains authoritative for fonts, icons, colors and StyleBoxes. This
## profile only describes lightweight transform/opacity feedback around an
## authored base Control state.

@export var motion: NucleusUIMotionProfile

@export_group("Transform")
@export var scale_multiplier: Vector2 = Vector2.ONE
@export var offset: Vector2 = Vector2.ZERO

@export_range(-360.0, 360.0, 0.1)
var rotation_degrees: float = 0.0

@export_group("Opacity")
@export_range(0.0, 2.0, 0.01, "or_greater")
var alpha_multiplier: float = 1.0


func get_motion(
	fallback: NucleusUIMotionProfile,
) -> NucleusUIMotionProfile:
	if motion:
		return motion

	return fallback if fallback else NucleusUIMotionProfile.new()


func get_scale(
	base_scale: Vector2,
	amplitude_scale: float = 1.0,
) -> Vector2:
	var full_scale: Vector2 = base_scale * scale_multiplier
	return base_scale.lerp(
		full_scale,
		clampf(amplitude_scale, 0.0, 1.0),
	)


func get_position(
	base_position: Vector2,
	amplitude_scale: float = 1.0,
) -> Vector2:
	return base_position + offset * clampf(
		amplitude_scale,
		0.0,
		1.0,
	)


func get_rotation(
	base_rotation: float,
	amplitude_scale: float = 1.0,
) -> float:
	return base_rotation + deg_to_rad(rotation_degrees) * clampf(
		amplitude_scale,
		0.0,
		1.0,
	)


func get_alpha(base_alpha: float) -> float:
	return clampf(
		base_alpha * maxf(0.0, alpha_multiplier),
		0.0,
		1.0,
	)
