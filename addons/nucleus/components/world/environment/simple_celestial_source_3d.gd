@tool
class_name NucleusSimpleCelestialSource3D
extends NucleusCelestialSource3D
## Cheap 24-hour sun/moon orbit used by the generic Nucleus environment path.
##
## The source intentionally models an art-directable fictional orbit rather than
## Earth astronomy. Noon places the sun at its highest point, midnight the moon.

@export_group("Sun")
@export var sun_rotation_offset_degrees: float = 90.0
@export var sun_yaw_degrees: float = -30.0
@export var sun_roll_degrees: float = 0.0

@export_group("Moon")
@export var moon_rotation_offset_degrees: float = 270.0
@export var moon_yaw_degrees: float = -30.0
@export var moon_roll_degrees: float = 0.0


func sample_state(
	normalized_day_time: float,
	target: NucleusCelestialState3D,
) -> Error:
	if target == null:
		return ERR_INVALID_PARAMETER

	var normalized: float = fposmod(normalized_day_time, 1.0)
	var phase: float = TAU * normalized
	var sun_height: float = -cos(phase)
	var moon_height: float = -sun_height
	var sun_azimuth: float = deg_to_rad(sun_yaw_degrees)
	var moon_azimuth: float = deg_to_rad(
		moon_yaw_degrees + 180.0
	)

	target.normalized_day_time = normalized
	target.sun_rotation_degrees = Vector3(
		sun_rotation_offset_degrees + normalized * 360.0,
		sun_yaw_degrees,
		sun_roll_degrees,
	)
	target.moon_rotation_degrees = Vector3(
		moon_rotation_offset_degrees + normalized * 360.0,
		moon_yaw_degrees,
		moon_roll_degrees,
	)

	target.sun_elevation_radians = asin(
		clampf(sun_height, -1.0, 1.0)
	)
	target.moon_elevation_radians = asin(
		clampf(moon_height, -1.0, 1.0)
	)
	target.sun_azimuth_radians = sun_azimuth
	target.moon_azimuth_radians = moon_azimuth
	target.sun_direction = _direction_from_elevation(
		target.sun_elevation_radians,
		sun_azimuth,
	)
	target.moon_direction = _direction_from_elevation(
		target.moon_elevation_radians,
		moon_azimuth,
	)

	target.daylight_factor = maxf(sun_height, 0.0)
	target.night_factor = maxf(-sun_height, 0.0)
	target.sun_above_horizon = sun_height > 0.0
	target.moon_above_horizon = moon_height > 0.0
	return OK


func _direction_from_elevation(
	elevation: float,
	azimuth: float,
) -> Vector3:
	var horizontal: float = cos(elevation)
	return Vector3(
		sin(azimuth) * horizontal,
		sin(elevation),
		cos(azimuth) * horizontal,
	).normalized()
