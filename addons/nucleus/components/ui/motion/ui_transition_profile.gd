class_name NucleusUITransitionProfile
extends Resource
## Declarative enter/exit state for one presentation Control.
##
## This profile describes the hidden presentation state relative to the target's
## authored base transform. It does not own layout or Theme styling.

@export var motion: NucleusUIMotionProfile

@export_group("Opacity")
@export var fade: bool = true
@export_range(0.0, 1.0, 0.01)
var hidden_alpha: float = 0.0

@export_group("Transform")
@export var use_scale: bool = true
@export var hidden_scale: Vector2 = Vector2(0.96, 0.96)

@export var use_offset: bool = false
@export var hidden_offset: Vector2 = Vector2.ZERO

@export var use_rotation: bool = false
@export_range(-360.0, 360.0, 0.1)
var hidden_rotation_degrees: float = 0.0

@export var pivot_ratio: Vector2 = Vector2(0.5, 0.5)


func get_motion() -> NucleusUIMotionProfile:
	return motion if motion else NucleusUIMotionProfile.new()


func get_hidden_scale(
	base_scale: Vector2,
	amplitude_scale: float = 1.0,
) -> Vector2:
	if not use_scale:
		return base_scale

	var full_hidden: Vector2 = base_scale * hidden_scale
	return base_scale.lerp(
		full_hidden,
		clampf(amplitude_scale, 0.0, 1.0),
	)


func get_hidden_position(
	base_position: Vector2,
	amplitude_scale: float = 1.0,
) -> Vector2:
	if not use_offset:
		return base_position

	return base_position + hidden_offset * clampf(
		amplitude_scale,
		0.0,
		1.0,
	)


func get_hidden_rotation(
	base_rotation: float,
	amplitude_scale: float = 1.0,
) -> float:
	if not use_rotation:
		return base_rotation

	return base_rotation + deg_to_rad(hidden_rotation_degrees) * clampf(
		amplitude_scale,
		0.0,
		1.0,
	)


func get_pivot_ratio() -> Vector2:
	return Vector2(
		clampf(pivot_ratio.x, 0.0, 1.0),
		clampf(pivot_ratio.y, 0.0, 1.0),
	)


static func fade_only(
	duration: float = 0.18,
) -> NucleusUITransitionProfile:
	var profile := NucleusUITransitionProfile.new()
	profile.motion = _motion(duration)
	profile.use_scale = false
	return profile


static func pop(
	duration: float = 0.18,
	hidden_scale_factor: Vector2 = Vector2(0.94, 0.94),
) -> NucleusUITransitionProfile:
	var profile := NucleusUITransitionProfile.new()
	profile.motion = _motion(duration)
	profile.hidden_scale = hidden_scale_factor
	return profile


static func slide(
	offset: Vector2,
	duration: float = 0.18,
	include_fade: bool = true,
) -> NucleusUITransitionProfile:
	var profile := NucleusUITransitionProfile.new()
	profile.motion = _motion(duration)
	profile.fade = include_fade
	profile.use_scale = false
	profile.use_offset = true
	profile.hidden_offset = offset
	return profile


static func _motion(duration: float) -> NucleusUIMotionProfile:
	var result := NucleusUIMotionProfile.new()
	result.duration = maxf(0.0, duration)
	return result
